public actor KeyedDebouncer<Key: Hashable & Sendable, Input: Sendable> {
    public typealias Operation = @Sendable (Key, Input) async -> Void

    private let delay: Duration
    private let policy: DebounceInFlightPolicy
    private let sleeper: Debouncer<Input>.Sleeper
    private let operation: Operation

    private var debouncers: [Key: Debouncer<Input>] = [:]

    /// Creates per-key debouncers that share the same configuration.
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
        sleeper: @escaping Debouncer<Input>.Sleeper,
        operation: @escaping Operation
    ) {
        self.delay = delay
        self.policy = policy
        self.sleeper = sleeper
        self.operation = operation
    }

    /// Schedules a value for the provided key.
    public func submit(_ input: Input, for key: Key) async {
        let debouncer = debouncers[key] ?? makeDebouncer(for: key)
        debouncers[key] = debouncer
        await debouncer.submit(input)
    }

    /// Immediately runs the latest queued value for the provided key.
    public func flush(for key: Key) async {
        guard let debouncer = debouncers[key] else {
            return
        }

        await debouncer.flush()
    }

    /// Immediately runs all currently queued values.
    public func flushAll() async {
        let activeDebouncers = Array(debouncers.values)
        for debouncer in activeDebouncers {
            await debouncer.flush()
        }
    }

    /// Cancels pending and running work for a single key.
    public func cancel(for key: Key) async {
        guard let debouncer = debouncers.removeValue(forKey: key) else {
            return
        }

        await debouncer.cancel()
    }

    /// Cancels every pending and running keyed debouncer.
    public func cancelAll() async {
        let activeDebouncers = Array(debouncers.values)
        debouncers.removeAll()

        for debouncer in activeDebouncers {
            await debouncer.cancel()
        }
    }

    private func makeDebouncer(for key: Key) -> Debouncer<Input> {
        Debouncer(
            delay: delay,
            policy: policy,
            sleeper: sleeper,
            operation: { [operation] input in
                await operation(key, input)
            }
        )
    }
}
