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
    @State private var snapshotRequestID: Int = 0
    @State private var snapshotReason: String = "initial"
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
                LensContentSnapshotHost(
                    content: content().frame(width: size.width, height: size.height),
                    size: size,
                    scale: scale,
                    snapshotRequestID: snapshotRequestID,
                    snapshotReason: snapshotReason,
                    snapshotProvider: snapshotProvider
                )
                .frame(width: size.width, height: size.height)

                lenses()
                    .environmentObject(snapshotProvider)
                    .environment(\.lensContainerSize, size)
                    .environment(\.lensContainerSafeAreaInsets, safeInsets)
            }
            .onAppear {
                i("appear size=\(format(size)) scale=\(scale) rate=\(snapshotRefreshRate.debugDescription)")
                requestSnapshot(reason: "appear", size: size)
                snapshotProvider.startTimer(refreshRate: snapshotRefreshRate)
            }
            .onChange(of: snapshotRefreshRate) { _, newRefreshRate in
                i("rate changed rate=\(newRefreshRate.debugDescription)")
                requestSnapshot(reason: "rateChanged", size: size)
                snapshotProvider.startTimer(refreshRate: newRefreshRate)
            }
            .onDisappear {
                snapshotProvider.stopTimer()
            }
            .onReceive(snapshotProvider.snapshotRequests) { date in
                latestSnapshotRequest = date
                d("timer tick")
                requestSnapshot(reason: "timer", size: size)
            }
        }
    }

    private func requestSnapshot(reason: String, size: CGSize) {
        d("capture requested reason=\(reason) size=\(format(size))")
        snapshotReason = reason
        snapshotRequestID += 1
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
        case .custom(let milliseconds):
            "custom(\(milliseconds)ms)"
        }
    }
}
