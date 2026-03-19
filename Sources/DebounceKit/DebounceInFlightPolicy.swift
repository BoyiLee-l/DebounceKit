/// Controls how a debouncer behaves when a new debounced value becomes ready
/// while a previous async operation is still executing.
public enum DebounceInFlightPolicy: Sendable {
    /// Requests cancellation of the running task and starts the latest value
    /// once the current operation finishes unwinding.
    case cancelPrevious

    /// Lets the current task finish, then executes only the latest queued value.
    case finishCurrentThenRunLatest
}
