import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

#if os(iOS)
struct LensContentSnapshotHost<Content: View>: UIViewControllerRepresentable {
    let content: Content
    let size: CGSize
    let scale: CGFloat
    let snapshotRequestID: Int
    let snapshotReason: String
    @ObservedObject var snapshotProvider: LensSnapshotProvider

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> UIHostingController<Content> {
        let controller = UIHostingController(rootView: content)
        controller.view.backgroundColor = .clear
        controller.view.isOpaque = false
        return controller
    }

    func updateUIViewController(_ controller: UIHostingController<Content>, context: Context) {
        controller.rootView = content
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        if context.coordinator.lastSnapshotRequestID != snapshotRequestID {
            context.coordinator.lastSnapshotRequestID = snapshotRequestID
            if let view = controller.view {
                context.coordinator.captureTask?.cancel()
                context.coordinator.captureTask = Task { @MainActor in
                    await Task.yield()
                    snapshotProvider.capture(
                        view: view,
                        size: size,
                        scale: scale,
                        reason: snapshotReason
                    )
                }
            }
        }
    }

    final class Coordinator {
        var lastSnapshotRequestID: Int?
        var captureTask: Task<Void, Never>?
    }
}
#elseif os(macOS)
struct LensContentSnapshotHost<Content: View>: NSViewRepresentable {
    let content: Content
    let size: CGSize
    let scale: CGFloat
    let snapshotRequestID: Int
    let snapshotReason: String
    @ObservedObject var snapshotProvider: LensSnapshotProvider

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSHostingView<Content> {
        let view = NSHostingView(rootView: content)
        view.wantsLayer = true
        view.layer?.contentsScale = scale
        return view
    }

    func updateNSView(_ view: NSHostingView<Content>, context: Context) {
        view.rootView = content
        view.frame = CGRect(origin: .zero, size: size)
        view.bounds = CGRect(origin: .zero, size: size)
        view.layer?.contentsScale = scale
        view.layoutSubtreeIfNeeded()

        if context.coordinator.lastSnapshotRequestID != snapshotRequestID {
            context.coordinator.lastSnapshotRequestID = snapshotRequestID
            context.coordinator.captureTask?.cancel()
            context.coordinator.captureTask = Task { @MainActor in
                await Task.yield()
                snapshotProvider.capture(
                    view: view,
                    size: size,
                    scale: scale,
                    reason: snapshotReason
                )
            }
        }
    }

    final class Coordinator {
        var lastSnapshotRequestID: Int?
        var captureTask: Task<Void, Never>?
    }
}
#endif
