# DebounceKit

`DebounceKit` provides async-friendly debouncing primitives for Swift concurrency.

- `Debouncer<Input>` executes only the latest submitted value after a delay.
- `KeyedDebouncer<Key, Input>` debounces values independently per key.
- `DebounceInFlightPolicy` controls how new work interacts with an operation that is already running.

## Installation

### Swift Package Manager

Add `DebounceKit` to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/BoyiLee-l/DebounceKit.git", from: "0.1.0")
]
```

Then add the product to your target:

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "DebounceKit", package: "DebounceKit")
        ]
    )
]
```

In Xcode, you can also use `File > Add Package Dependencies...` and paste:

```text
https://github.com/BoyiLee-l/DebounceKit.git
```

Choose `Up to Next Major Version` and select the release you want to install.

### Requirements

- iOS 16+
- macOS 13+

## Usage

```swift
import DebounceKit

let debouncer = Debouncer<String>(delay: .milliseconds(300)) { value in
    await search(with: value)
}

await debouncer.submit("s")
await debouncer.submit("sw")
await debouncer.submit("swift")
```

## Release

Package releases are managed with Git tags. `Package.swift` does not contain the package's published version number.

### Release checklist

1. Confirm the working tree is clean.
2. Run tests.
3. Push the release commit to `main`.
4. Create an annotated semantic version tag.
5. Push the tag to GitHub.
6. Optionally create a GitHub Release note for the tag.

### Commands

For a patch release:

```bash
git status
swift test
git push origin main
git tag -a v0.1.1 -m "Release v0.1.1"
git push origin v0.1.1
```

### Versioning guide

- `v0.1.1`: bug fixes only
- `v0.2.0`: backward-compatible feature additions
- `v1.0.0`: first stable public API

Keep the tag format consistent. This repository already uses the `v` prefix, for example `v0.1.0`, so future releases should follow the same convention.
