#if os(macOS)
import AppKit
import AVFoundation
import AVKit
import CoreImage

/// Draws the video that `cacheDisplay` cannot see into a container snapshot.
///
/// `NSView.cacheDisplay(in:to:)` re-runs the view tree's *drawing*. A video
/// layer draws nothing: its frames are handed to the window server by the media
/// pipeline and composited there, so a snapshot of a view hierarchy containing
/// an `AVPlayerView` comes back with a hole where the picture is, and a lens
/// over it refracts that hole instead of the film.
///
/// This capture fills the hole. It finds every player under the snapshotted
/// view, pulls the frame it is showing straight from its player item, and
/// composites it into the snapshot at the rectangle the picture actually
/// occupies, so letterboxing and `videoGravity` are already accounted for.
///
/// Both ways of showing video are found. `AVPlayerView` is looked for by view,
/// not by layer: on current macOS AVKit renders it out of process and there is
/// no `AVPlayerLayer` anywhere in the host's layer tree, so a layer walk finds
/// nothing at all. A view backed directly by an `AVPlayerLayer` is found too.
///
/// Frames are pulled through one `AVPlayerItemVideoOutput` per item, created on
/// demand and cached. The last frame of every item is kept, so a paused player
/// - the final frame of a round, held while the result is read - keeps
/// compositing instead of blinking out.
@MainActor
final class LensVideoLayerCapture: Loggable {
    nonisolated var log: SomeLensLog.Scope {
        SomeLensLog.video
    }

    private struct Tap {
        let output: AVPlayerItemVideoOutput
        weak var item: AVPlayerItem?
        var lastFrame: CGImage?
    }

    private var taps: [ObjectIdentifier: Tap] = [:]
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    deinit {
        for tap in taps.values {
            tap.item?.remove(tap.output)
        }
    }

    /// Composite every video layer under `view` into `bitmap`.
    ///
    /// Returns the number of layers drawn, so the caller can log a capture that
    /// carried video without having to walk the tree itself.
    @discardableResult
    func composite(into bitmap: NSBitmapImageRep, from view: NSView, size: CGSize) -> Int {
        let sources = videoSources(under: view)
        guard !sources.isEmpty else {
            releaseUnusedTaps(keeping: [])
            return 0
        }
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            i("cannot composite video: no context for the snapshot bitmap")
            return 0
        }

        var used: Set<ObjectIdentifier> = []
        var drawn = 0

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        for source in sources {
            guard let item = source.player.currentItem else { continue }
            used.insert(ObjectIdentifier(item))
            guard let frame = frame(of: item),
                  let rect = destination(of: source, in: view, size: size) else { continue }
            // The snapshot is laid out from the top; a bitmap context draws
            // from the bottom.
            let flipped = CGRect(x: rect.minX, y: size.height - rect.maxY,
                                 width: rect.width, height: rect.height)
            context.cgContext.draw(frame, in: flipped)
            drawn += 1
            d("composited video rect=\(format(flipped)) frame=\(frame.width)x\(frame.height)")
        }
        NSGraphicsContext.restoreGraphicsState()

        releaseUnusedTaps(keeping: used)
        return drawn
    }

    // MARK: Finding the video

    /// A player on screen, and the rectangle its picture fills in its own view.
    private struct VideoSource {
        let player: AVPlayer
        let view: NSView
        let rect: CGRect
    }

    private func videoSources(under root: NSView) -> [VideoSource] {
        var found: [VideoSource] = []
        var pending: [NSView] = [root]
        while let view = pending.popLast() {
            if let playerView = view as? AVPlayerView, let player = playerView.player {
                // `videoBounds` is empty until the first frame is ready.
                let bounds = playerView.videoBounds
                found.append(VideoSource(player: player, view: playerView,
                                         rect: bounds.isEmpty ? playerView.bounds : bounds))
                continue
            }
            if let layer = view.layer as? AVPlayerLayer, let player = layer.player {
                let rect = layer.videoRect
                found.append(VideoSource(player: player, view: view,
                                         rect: rect.isEmpty ? view.bounds : rect))
                continue
            }
            pending.append(contentsOf: view.subviews)
        }
        return found
    }

    /// Where the picture sits in the snapshot, measured from the top left the
    /// way the snapshot bitmap is.
    private func destination(of source: VideoSource, in root: NSView, size: CGSize) -> CGRect? {
        let rect = source.view.convert(source.rect, to: root)
        guard rect.width > 0, rect.height > 0,
              rect.intersects(CGRect(origin: .zero, size: size)) else { return nil }

        return root.isFlipped ? rect
            : CGRect(x: rect.minX, y: size.height - rect.maxY,
                     width: rect.width, height: rect.height)
    }

    // MARK: Pulling frames

    /// The frame an item is showing, or the last one it showed.
    private func frame(of item: AVPlayerItem) -> CGImage? {
        let key = ObjectIdentifier(item)
        let output = tap(for: item, key: key)
        let time = item.currentTime()

        guard output.hasNewPixelBuffer(forItemTime: time) else {
            return taps[key]?.lastFrame
        }
        guard let buffer = output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) else {
            return taps[key]?.lastFrame
        }

        let image = CIImage(cvPixelBuffer: buffer)
        guard let frame = ciContext.createCGImage(image, from: image.extent) else {
            return taps[key]?.lastFrame
        }
        taps[key]?.lastFrame = frame
        return frame
    }

    private func tap(for item: AVPlayerItem, key: ObjectIdentifier) -> AVPlayerItemVideoOutput {
        if let existing = taps[key]?.output { return existing }

        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any]
        ])
        item.add(output)
        taps[key] = Tap(output: output, item: item, lastFrame: nil)
        i("video tap added for item \(key)")
        return output
    }

    /// Items that are no longer on screen give their output back. An output
    /// left on a finished item keeps decoding frames nobody draws.
    private func releaseUnusedTaps(keeping used: Set<ObjectIdentifier>) {
        for (key, tap) in taps where !used.contains(key) {
            tap.item?.remove(tap.output)
            taps[key] = nil
            i("video tap removed for item \(key)")
        }
    }

    private func format(_ rect: CGRect) -> String {
        "\(Int(rect.origin.x)),\(Int(rect.origin.y)) \(Int(rect.width))x\(Int(rect.height))"
    }
}
#endif
