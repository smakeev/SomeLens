# SomeLens

SomeLens is a SwiftUI glass UI component library focused on lens-like visual effects for Apple platforms.

The package is intended to provide reusable glass components that can be dropped into SwiftUI interfaces on iOS and macOS. Its first direction is a movable optical lens effect with configurable size, path, refraction, edge reflection, rim styling, and magnification.

## Goals

- Provide polished SwiftUI glass components with a small, expressive API.
- Use platform-native rendering so effects feel integrated with Apple UI.
- Keep components configurable without requiring callers to understand shader internals.
- Support iOS and macOS through Swift Package Manager.
- Make visual effects reusable across production interfaces, prototypes, and interaction experiments.

## Planned Usage

```swift
import SwiftUI
import SomeLens

struct ExampleView: View {
    @State private var lensCenter = CGPoint(x: 160, y: 240)

    var body: some View {
        ZStack {
            content

            GlassLens(
                center: lensCenter,
                settings: GlassLensSettings.circle(
                    diameter: 160,
                    refraction: 1.2
                )
            )
        }
    }

    private var content: some View {
        LinearGradient(
            colors: [.blue, .pink, .orange],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
```

The public API is still being shaped. Names and configuration points may change before the first stable release.

## Installation

SomeLens is intended to be installed with Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/SomeLens.git", from: "0.1.0")
]
```

Then add `SomeLens` to the target that uses the components.

## Requirements

- SwiftUI
- Swift Package Manager
- iOS and macOS support planned

Exact minimum platform versions will be documented once the package target is finalized.

## Status

SomeLens is in early development. The first stable milestone is to extract the reusable glass lens implementation into a Swift Package with clear platform support, documentation, examples, and tests.

## License

SomeLens is available under the MIT License. See [LICENSE](LICENSE).
