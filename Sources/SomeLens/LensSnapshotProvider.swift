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
    let snapshotRequests = PassthroughSubject<LensSnapshotRequest, Never>()
    private var captureCount: Int = 0

    nonisolated var log: SomeLensLog.Scope {
        SomeLensLog.snapshot
    }

    // The snapshot loop lives in this StateObject-backed provider instead of
    // LensContainer's View value. LensContainer can be recreated on every parent
    // update, while this object stays alive long enough to pace captures.
    private var scheduledSnapshotTask: Task<Void, Never>?
    private var activeRefreshRate: SnapshotRefreshRate?
    private var isSnapshotPaused = false
    private var isSnapshotRequestPending = false
    private var isSnapshotInFlight = false
    private var isSnapshotNeeded = false
    private var lastSnapshotFinishedAt: Date?
    private var lastSnapshotDuration: TimeInterval = 0

    func startSnapshotLoop(refreshRate: SnapshotRefreshRate) {
        guard activeRefreshRate != refreshRate else { return }
        let interval = refreshRate.interval

        stopSnapshotLoop()
        activeRefreshRate = refreshRate

        if let interval {
            i("snapshot loop start minimumInterval=\(String(format: "%.3f", interval))")
        } else {
            i("snapshot loop disabled rate=never")
        }
    }

    func stopSnapshotLoop() {
        guard scheduledSnapshotTask != nil || activeRefreshRate != nil else { return }
        i("snapshot loop stop")
        scheduledSnapshotTask?.cancel()
        scheduledSnapshotTask = nil
        activeRefreshRate = nil
        isSnapshotNeeded = false
        isSnapshotRequestPending = false
    }

    func setSnapshotPaused(_ isPaused: Bool) {
        guard isSnapshotPaused != isPaused else { return }
        isSnapshotPaused = isPaused
        d("snapshot pause changed paused=\(isPaused)")

        if isPaused {
            isSnapshotNeeded = true
            return
        }

        requestSnapshot(reason: "resumed")
    }

    func requestSnapshot(reason: String) {
        guard !isSnapshotPaused else {
            d("snapshot coalesced reason=\(reason) paused=true")
            isSnapshotNeeded = true
            return
        }

        guard !isSnapshotInFlight, !isSnapshotRequestPending else {
            d("snapshot coalesced reason=\(reason) inFlight=\(isSnapshotInFlight) pending=\(isSnapshotRequestPending)")
            isSnapshotNeeded = true
            return
        }

        let now = Date()
        if let lastSnapshotFinishedAt {
            let elapsed = now.timeIntervalSince(lastSnapshotFinishedAt)
            let delay = effectiveInterval - elapsed
            guard delay <= 0 else {
                d("snapshot delayed reason=\(reason) remaining=\(String(format: "%.3f", delay))")
                isSnapshotNeeded = true
                scheduleNextSnapshot(after: delay, reason: reason)
                return
            }
        }

        isSnapshotRequestPending = true
        isSnapshotNeeded = false
        d("snapshot requested reason=\(reason)")
        snapshotRequests.send(LensSnapshotRequest(date: now, reason: reason))
    }

    #if os(iOS)
    func capture(
        view: UIView,
        size: CGSize,
        scale: CGFloat,
        reason: String
    ) {
        beginCapture()
        let startedAt = Date()
        defer {
            finishCapture(startedAt: startedAt)
        }

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
        beginCapture()
        let startedAt = Date()
        defer {
            finishCapture(startedAt: startedAt)
        }

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

    private var effectiveInterval: TimeInterval {
        max(activeRefreshRate?.interval ?? 0, lastSnapshotDuration * 1.5)
    }

    private func beginCapture() {
        scheduledSnapshotTask?.cancel()
        scheduledSnapshotTask = nil
        isSnapshotRequestPending = false
        isSnapshotInFlight = true
    }

    private func finishCapture(startedAt: Date) {
        let finishedAt = Date()
        lastSnapshotDuration = finishedAt.timeIntervalSince(startedAt)
        lastSnapshotFinishedAt = finishedAt
        isSnapshotInFlight = false

        d("capture finished duration=\(String(format: "%.3f", lastSnapshotDuration)) effectiveInterval=\(String(format: "%.3f", effectiveInterval))")

        guard activeRefreshRate?.interval != nil else { return }

        if isSnapshotNeeded {
            isSnapshotNeeded = false
            scheduleNextSnapshot(after: effectiveInterval, reason: "coalesced")
        } else {
            scheduleNextSnapshot(after: effectiveInterval, reason: "scheduled")
        }
    }

    private func scheduleNextSnapshot(after delay: TimeInterval, reason: String) {
        guard activeRefreshRate?.interval != nil else { return }

        let clampedDelay = max(delay, 0)
        scheduledSnapshotTask?.cancel()
        scheduledSnapshotTask = Task { @MainActor [weak self] in
            let nanoseconds = UInt64(clampedDelay * 1_000_000_000)
            if nanoseconds > 0 {
                try? await Task.sleep(nanoseconds: nanoseconds)
            }
            guard let self, !Task.isCancelled else { return }
            self.scheduledSnapshotTask = nil
            self.requestSnapshot(reason: reason)
        }
    }
}

struct LensSnapshotRequest {
    let date: Date
    let reason: String
}
