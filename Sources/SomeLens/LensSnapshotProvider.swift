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
        let interval = refreshRate.interval

        stopTimer()
        activeRefreshRate = refreshRate

        if let interval {
            i("timer start interval=\(String(format: "%.3f", interval))")
            timerCancellable = Timer.publish(every: interval, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] date in
                    guard let self else { return }
                    self.d("timer tick")
                    self.snapshotRequests.send(date)
                }
        } else {
            i("timer disabled rate=never")
        }
    }

    func stopTimer() {
        guard timerCancellable != nil || activeRefreshRate != nil else { return }
        i("timer stop")
        timerCancellable?.cancel()
        timerCancellable = nil
        activeRefreshRate = nil
    }

    #if os(iOS)
    func capture(
        view: UIView,
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

        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = scale
        rendererFormat.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: rendererFormat)
        let image = renderer.image { _ in
            view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }

        snapshot = image
        snapshotVersion += 1
        d("capture #\(captureCount) published version=\(snapshotVersion) image=\(format(image.size))")
    }
    #elseif os(macOS)
    func capture(
        view: NSView,
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

        view.layoutSubtreeIfNeeded()
        let bounds = CGRect(origin: .zero, size: size)
        view.bounds = bounds

        if let bitmap = view.bitmapImageRepForCachingDisplay(in: bounds) {
            bitmap.size = size
            view.cacheDisplay(in: bounds, to: bitmap)

            let image = NSImage(size: size)
            image.addRepresentation(bitmap)
            snapshot = image
            snapshotVersion += 1
            d("capture #\(captureCount) published version=\(snapshotVersion) image=\(format(image.size))")
        } else {
            i("capture #\(captureCount) failed: bitmap renderer returned nil")
        }
    }
    #endif

    private func format(_ size: CGSize) -> String {
        "\(Int(size.width))x\(Int(size.height))"
    }
}
