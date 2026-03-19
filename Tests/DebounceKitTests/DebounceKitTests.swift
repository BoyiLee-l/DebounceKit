import Testing
@testable import DebounceKit

@Test func debouncerOnlyExecutesTheLatestSubmittedValue() async throws {
    let recorder = Recorder<String>()
    let debouncer = Debouncer<String>(delay: .milliseconds(40)) { value in
        await recorder.record(value)
    }

    await debouncer.submit("s")
    await debouncer.submit("sw")
    await debouncer.submit("swift")

    try await Task.sleep(for: .milliseconds(120))

    let values = await recorder.values()
    #expect(values == ["swift"])
}

@Test func debouncerCancelDropsPendingWork() async throws {
    let recorder = Recorder<String>()
    let debouncer = Debouncer<String>(delay: .milliseconds(60)) { value in
        await recorder.record(value)
    }

    await debouncer.submit("swift")
    await debouncer.cancel()

    try await Task.sleep(for: .milliseconds(100))

    let values = await recorder.values()
    #expect(values.isEmpty)
}

@Test func debouncerFlushExecutesLatestValueImmediately() async throws {
    let recorder = Recorder<String>()
    let debouncer = Debouncer<String>(delay: .seconds(1)) { value in
        await recorder.record(value)
    }

    await debouncer.submit("swift")
    await debouncer.flush()

    try await Task.sleep(for: .milliseconds(30))

    let values = await recorder.values()
    #expect(values == ["swift"])
}

@Test func finishCurrentThenRunLatestWaitsForRunningTaskToComplete() async throws {
    let recorder = Recorder<String>()
    let firstStarted = Signal()
    let releaseFirst = Signal()

    let debouncer = Debouncer<String>(
        delay: .milliseconds(20),
        policy: .finishCurrentThenRunLatest
    ) { value in
        await recorder.record("start:\(value)")

        if value == "first" {
            await firstStarted.signal()
            await releaseFirst.wait()
        }

        await recorder.record("finish:\(value)")
    }

    await debouncer.submit("first")
    await firstStarted.wait()

    await debouncer.submit("second")
    try await Task.sleep(for: .milliseconds(60))

    let valuesWhileBlocked = await recorder.values()
    #expect(valuesWhileBlocked == ["start:first"])

    await releaseFirst.signal()
    try await Task.sleep(for: .milliseconds(80))

    let finalValues = await recorder.values()
    #expect(finalValues == ["start:first", "finish:first", "start:second", "finish:second"])
}

@Test func cancelPreviousReplacesRunningTaskWithLatestValue() async throws {
    let recorder = Recorder<String>()
    let firstStarted = Signal()

    let debouncer = Debouncer<String>(
        delay: .milliseconds(20),
        policy: .cancelPrevious
    ) { value in
        await recorder.record("start:\(value)")

        if value == "first" {
            await firstStarted.signal()

            do {
                try await Task.sleep(for: .seconds(1))
                await recorder.record("finish:\(value)")
            } catch {
                await recorder.record("cancel:\(value)")
                return
            }
        } else {
            await recorder.record("finish:\(value)")
        }
    }

    await debouncer.submit("first")
    await firstStarted.wait()

    await debouncer.submit("second")
    try await Task.sleep(for: .milliseconds(120))

    let values = await recorder.values()
    #expect(values.contains("cancel:first"))
    #expect(Array(values.suffix(2)) == ["start:second", "finish:second"])
}

@Test func keyedDebouncerDebouncesEachKeyIndependently() async throws {
    let recorder = Recorder<String>()
    let debouncer = KeyedDebouncer<String, Int>(delay: .milliseconds(30)) { key, value in
        await recorder.record("\(key):\(value)")
    }

    await debouncer.submit(1, for: "search")
    await debouncer.submit(2, for: "search")
    await debouncer.submit(10, for: "profile")
    await debouncer.submit(20, for: "profile")

    try await Task.sleep(for: .milliseconds(100))

    let values = Set(await recorder.values())
    #expect(values == Set(["search:2", "profile:20"]))
}

actor Recorder<Value: Sendable> {
    private var storage: [Value] = []

    func record(_ value: Value) {
        storage.append(value)
    }

    func values() -> [Value] {
        storage
    }
}

actor Signal {
    private var hasSignaled = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if hasSignaled {
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func signal() {
        guard !hasSignaled else {
            return
        }

        hasSignaled = true
        let currentWaiters = waiters
        waiters.removeAll()

        for waiter in currentWaiters {
            waiter.resume()
        }
    }
}
