import SwiftUI
import Combine
#if os(macOS)
import AppKit
#endif

public struct LensContainer<Content: View, Lenses: View>: View, Loggable {
    private let content: () -> Content
    private let lenses: () -> Lenses
    private let snapshotRefreshRate: SnapshotRefreshRate
    @State private var latestSnapshotRequest: Date?
    @StateObject private var snapshotProvider = LensSnapshotProvider()

    var log: SomeLensLog.Scope {
        SomeLensLog.container
    }

    public init(
        snapshotRefreshRate: SnapshotRefreshRate = .automatic,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder lenses: @escaping () -> Lenses
    ) {
        self.snapshotRefreshRate = snapshotRefreshRate
        self.content = content
        self.lenses = lenses
    }

    public var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let safeInsets = geometry.safeAreaInsets
            let scale = displayScale
            ZStack {
                content()
                    .frame(width: size.width, height: size.height)

                lenses()
                    .environmentObject(snapshotProvider)
                    .environment(\.lensContainerSize, size)
                    .environment(\.lensContainerSafeAreaInsets, safeInsets)
            }
            .onAppear {
                i("appear size=\(format(size)) scale=\(scale) rate=\(snapshotRefreshRate.debugDescription)")
                captureSnapshot(reason: "appear", size: size, scale: scale)
                snapshotProvider.startTimer(refreshRate: snapshotRefreshRate)
            }
            .onDisappear {
                snapshotProvider.stopTimer()
            }
            .onReceive(snapshotProvider.snapshotRequests) { date in
                latestSnapshotRequest = date
                d("timer tick")
                captureSnapshot(reason: "timer", size: size, scale: scale)
            }
        }
    }

    private func captureSnapshot(reason: String, size: CGSize, scale: CGFloat) {
        d("capture requested reason=\(reason) size=\(format(size))")
        snapshotProvider.capture(
            content: content().frame(width: size.width, height: size.height),
            size: size,
            scale: scale,
            reason: reason
        )
    }

    private func format(_ size: CGSize) -> String {
        "\(Int(size.width))x\(Int(size.height))"
    }

    private var displayScale: CGFloat {
        #if os(iOS)
        UIScreen.main.scale
        #elseif os(macOS)
        NSScreen.main?.backingScaleFactor ?? 1
        #else
        1
        #endif
    }
}

private extension SnapshotRefreshRate {
    var debugDescription: String {
        switch self {
        case .never:
            "never"
        case .automatic:
            "automatic(0.200s)"
        case .fast:
            "fast(0.033s)"
        case .balanced:
            "balanced(0.100s)"
        case .relaxed:
            "relaxed(0.250s)"
        case .slow:
            "slow(0.500s)"
        }
    }
}
