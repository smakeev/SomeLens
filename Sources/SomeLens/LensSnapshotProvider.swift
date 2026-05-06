import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import Combine

@MainActor
final class LensSnapshotProvider: ObservableObject, Loggable {
    @Published var snapshot: SomeLensPlatformImage?
    @Published var snapshotVersion: Int = 0
    let snapshotRequests = PassthroughSubject<Date, Never>()
    private var captureCount: Int = 0

    nonisolated var log: SomeLensLog.Scope {
        SomeLensLog.snapshot
    }

    // The timer lives in this StateObject-backed provider instead of LensContainer's
    // View value. LensContainer can be recreated on every parent update, while this
    // object stays alive long enough for refresh ticks to fire.
    private var timerCancellable: AnyCancellable?
    private var activeRefreshRate: SnapshotRefreshRate?

    func startTimer(refreshRate: SnapshotRefreshRate) {
        guard activeRefreshRate != refreshRate else { return }
        stopTimer()
        activeRefreshRate = refreshRate

        guard let interval = refreshRate.interval else {
            i("timer disabled rate=never")
            return
        }

        i("timer start interval=\(String(format: "%.3f", interval))")
        timerCancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                guard let self else { return }
                self.d("timer tick")
                self.snapshotRequests.send(date)
            }
    }

    func stopTimer() {
        guard timerCancellable != nil || activeRefreshRate != nil else { return }
        i("timer stop")
        timerCancellable?.cancel()
        timerCancellable = nil
        activeRefreshRate = nil
    }

    func capture<Content: View>(
        content: Content,
        size: CGSize,
        scale: CGFloat,
        reason: String
    ) {
        guard size.width > 0, size.height > 0 else {
            i("skip capture reason=\(reason) invalid size=\(format(size))")
            return
        }

        captureCount += 1
        d("capture #\(captureCount) start reason=\(reason) size=\(format(size)) scale=\(scale)")
        let renderer = ImageRenderer(content: content)
        renderer.scale = scale
        renderer.isOpaque = false
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)

        if let image = renderer.platformImage {
            snapshot = image
            snapshotVersion += 1
            d("capture #\(captureCount) published version=\(snapshotVersion) image=\(format(image.size))")
        } else {
            i("capture #\(captureCount) failed: renderer returned nil")
        }
    }

    private func format(_ size: CGSize) -> String {
        "\(Int(size.width))x\(Int(size.height))"
    }
}

private extension ImageRenderer {
    @MainActor
    var platformImage: SomeLensPlatformImage? {
        #if os(iOS)
        uiImage
        #elseif os(macOS)
        nsImage
        #else
        nil
        #endif
    }
}
