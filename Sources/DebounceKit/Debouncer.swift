public actor Debouncer<Input: Sendable> {
    public typealias Operation = @Sendable (Input) async -> Void
    typealias Sleeper = @Sendable (Duration) async throws -> Void

    private let delay: Duration
    private let policy: DebounceInFlightPolicy
    private let sleeper: Sleeper
    private let operation: Operation

    private var pendingInput: Input?
    private var pendingReady = false
    private var submissionID: UInt64 = 0

    private var timerTask: Task<Void, Never>?
    private var runningTask: Task<Void, Never>?
    private var runningTaskID: UInt64 = 0
    private var activeRunningTaskID: UInt64?

    /// Creates a debouncer that executes only the latest submitted value after
    /// the configured delay has elapsed.
    public init(
        delay: Duration,
        policy: DebounceInFlightPolicy = .cancelPrevious,
        operation: @escaping Operation
    ) {
        self.init(
            delay: delay,
            policy: policy,
            sleeper: { duration in
                try await Task.sleep(for: duration)
            },
            operation: operation
        )
    }

    init(
        delay: Duration,
        policy: DebounceInFlightPolicy = .cancelPrevious,
        sleeper: @escaping Sleeper,
        operation: @escaping Operation
    ) {
        self.delay = delay
        self.policy = policy
        self.sleeper = sleeper
        self.operation = operation
    }

    /// Schedules a new value. Any still-waiting value is replaced immediately.
    public func submit(_ input: Input) {
        submissionID &+= 1
        let currentSubmissionID = submissionID

        pendingInput = input
        pendingReady = false

        timerTask?.cancel()
        timerTask = Task {
            do {
                try await sleeper(delay)
            } catch {
                return
            }

            await markPendingReady(submissionID: currentSubmissionID)
        }
    }

    /// Immediately runs the latest queued value, respecting the in-flight policy.
    public func flush() async {
        timerTask?.cancel()
        timerTask = nil

        guard pendingInput != nil else {
            return
        }

        pendingReady = true
        await startReadyOperationIfPossible()
    }

    /// Cancels any waiting value and requests cancellation of the running task.
    public func cancel() {
        timerTask?.cancel()
        timerTask = nil

        pendingInput = nil
        pendingReady = false

        runningTask?.cancel()
    }

    private func markPendingReady(submissionID: UInt64) async {
        guard submissionID == self.submissionID else {
            return
        }

        timerTask = nil
        pendingReady = true
        await startReadyOperationIfPossible()
    }

    private func startReadyOperationIfPossible() async {
        guard pendingReady, let input = pendingInput else {
            return
        }

        if runningTask != nil {
            if policy == .cancelPrevious {
                runningTask?.cancel()
            }
            return
        }

        pendingInput = nil
        pendingReady = false

        runningTaskID &+= 1
        let currentRunningTaskID = runningTaskID
        activeRunningTaskID = currentRunningTaskID

        runningTask = Task { [operation] in
            await operation(input)
            await finishRunningTask(taskID: currentRunningTaskID)
        }
    }

    private func finishRunningTask(taskID: UInt64) async {
        guard activeRunningTaskID == taskID else {
            return
        }

        runningTask = nil
        activeRunningTaskID = nil

        await startReadyOperationIfPossible()
    }
}
