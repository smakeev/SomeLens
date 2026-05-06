//
//  ContentView.swift
//  Lens
//
//  Created by Sergey Makeev on 10.11.2025.
//

import SwiftUI
import UIKit
import MetalKit
import Combine

// Tunables for the lens look
private struct LensConfig {
    var radius: CGFloat = 80       // Lens radius
    var refract: CGFloat = 1.2     // Refraction strength
    var edge: CGFloat = 0.8        // Edge reflection strength
    var ringWidth: CGFloat = 1.0   // White rim stroke width
    var zoom: CGFloat = 1.05       // Magnification applied to the snapshot
}

@MainActor
final class SnapshotCoordinator: ObservableObject {
    @Published var snapshot: UIImage?

    private struct SnapshotContext {
        let counterValue: Int
        let safeInsets: EdgeInsets
        let size: CGSize
        let scale: CGFloat
    }

    private var needsSnapshot: Bool = false
    private var pendingTask: DispatchWorkItem?
    private var scheduledFireDate: Date?
    private var lastCaptureDate: Date = .distantPast
    private let minimumInterval: TimeInterval = 0.2
    private var latestContext: SnapshotContext?

    func requestSnapshot(counterValue: Int, safeInsets: EdgeInsets, size: CGSize, scale: CGFloat) {
        latestContext = SnapshotContext(counterValue: counterValue, safeInsets: safeInsets, size: size, scale: scale)
        needsSnapshot = true
        scheduleCapture()
    }

    private func scheduleCapture() {
        guard needsSnapshot, latestContext != nil else { return }

        let now = Date()
        let earliest = max(lastCaptureDate.addingTimeInterval(minimumInterval), now)
        if let scheduledFireDate, let pendingTask = pendingTask {
            if scheduledFireDate <= earliest { return }
            pendingTask.cancel()
        }

        let delay = max(earliest.timeIntervalSince(now), 0)
        scheduledFireDate = now.addingTimeInterval(delay)

        let task = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingTask = nil
            self.scheduledFireDate = nil
            self.captureIfNeeded()
        }
        pendingTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: task)
    }

    private func captureIfNeeded() {
        guard needsSnapshot, let context = latestContext else { return }
        needsSnapshot = false

        let view = DemoBackgroundView(counterValue: context.counterValue, safeInsets: context.safeInsets)
            .frame(width: context.size.width, height: context.size.height)

        let renderer = ImageRenderer(content: view)
        renderer.scale = context.scale
        renderer.isOpaque = false
        renderer.proposedSize = ProposedViewSize(width: context.size.width, height: context.size.height)

        if let image = renderer.uiImage {
            print("[Snapshot] captured at \(Date()) counter=\(context.counterValue) size=\(image.size)")
            snapshot = image
            lastCaptureDate = Date()
        }

        if needsSnapshot {
            scheduleCapture()
        }
    }
}

struct ContentView: View {
    var body: some View {
        LensDemoScreen()
    }
}

private struct DemoBackgroundView: View {
    let counterValue: Int
    let safeInsets: EdgeInsets

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.purple, .pink, .orange, .yellow],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("\(counterValue)")
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .shadow(color: .white.opacity(0.3), radius: 4, y: 2)

                VStack(spacing: 24) {
                    Text("Glass Lens Demo")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)

                    Text("""
                             Drag the small circle.
                             The lens refracts and slightly reflects edges.
                             """)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .opacity(0.9)
                }
                .foregroundStyle(.white)
            }
            .shadow(radius: 12)
            .padding(.horizontal, 24)
            .padding(.top, safeInsets.top + 24)
            .padding(.bottom, max(24, safeInsets.bottom + 12))
        }
    }
}

struct LensDemoScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var lensCenter: CGPoint = CGPoint(x: 200, y: 300)
    @State private var isInitialPlacementDone = false
    @StateObject private var snapshotCoordinator = SnapshotCoordinator()
    @State private var counterValue: Double = 0
    @State private var counterDirection: Double = 1
    private let counterTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    private let cfg = LensConfig()

    var body: some View {
        GeometryReader { geo in
            let safeInsets = geo.safeAreaInsets
            let size = geo.size
            let scale = UIScreen.main.scale
            let currentCounter = Int(counterValue)

            ZStack {
                DemoBackgroundView(counterValue: currentCounter, safeInsets: safeInsets)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .overlay(
                        GlassLensView(
                            center: $lensCenter,
                            config: cfg,
                            containerSize: size,
                            safeInsets: safeInsets,
                            snapshot: snapshotCoordinator.snapshot
                        )
                    )
            }
            .ignoresSafeArea()
            .onAppear {
                if !isInitialPlacementDone {
                    lensCenter = CGPoint(x: size.width / 2, y: size.height / 2)
                    isInitialPlacementDone = true
                }
                snapshotCoordinator.requestSnapshot(
                    counterValue: currentCounter,
                    safeInsets: safeInsets,
                    size: size,
                    scale: scale
                )
            }
            .onReceive(counterTimer) { _ in
                var next = counterValue + counterDirection * 1
                if next > 100 {
                    next = 100
                    counterDirection = -1
                } else if next < 0 {
                    next = 0
                    counterDirection = 1
                }
                counterValue = next
                snapshotCoordinator.requestSnapshot(
                    counterValue: Int(counterValue),
                    safeInsets: safeInsets,
                    size: size,
                    scale: scale
                )
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    snapshotCoordinator.requestSnapshot(
                        counterValue: currentCounter,
                        safeInsets: safeInsets,
                        size: size,
                        scale: scale
                    )
                }
            }
        }
    }
}

/// A circular lens that refracts the underlying layer using a Metal shader.
/// - Note: Uses `.layerEffect` with maxSampleOffset based on radius and refract.
struct GlassLensView: View {
    struct LensParams {
        var center: SIMD2<Float> // float2 - 8 bytes
        var radius: Float        // float - 4 bytes
        var refract: Float       // float - 4 bytes
        var edge: Float          // float - 4 bytes
        var _pad1: Float = 0     // padding - 4 bytes
        var _pad2: Float = 0     // padding - 4 bytes
        var _pad3: Float = 0     // padding - 4 bytes
    }

    @Binding var center: CGPoint
    fileprivate let config: LensConfig
    let containerSize: CGSize
    let safeInsets: EdgeInsets
    let snapshot: UIImage?

    // Gesture state
    @State private var lastCommittedCenter: CGPoint = .zero

    private var diameter: CGFloat { config.radius * 2 }

    var body: some View {
        let hasSnapshot = snapshot != nil
        ZStack {
            Group {
                if let snapshot, let cropped = cropCircle(snapshot: snapshot) {
                    Image(uiImage: cropped)
                        .resizable()
                        .scaledToFill()
                        .frame(width: diameter, height: diameter)
                        .clipped()
                } else {
                    Color.clear
                }
            }
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
            .layerEffect(lensShader, maxSampleOffset: sampleOffset)
            
            Circle()
                .stroke(.white.opacity(0.45), lineWidth: config.ringWidth)
                .blur(radius: 0.2)
                .frame(width: diameter, height: diameter)
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                        .frame(width: diameter, height: diameter)
                )
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle()) // Required for correct gesture hit testing
        .position(x: center.x, y: center.y)
        .gesture(dragGesture)
        .onAppear { lastCommittedCenter = center }
        .opacity(hasSnapshot ? 1 : 0)
        .allowsHitTesting(hasSnapshot)
        .accessibilityLabel("Movable glass lens")
    }

    private func crop(snapshot: UIImage) -> UIImage? {
        let sidePoints = max(config.radius * 2, 1)
        let halfPoints = sidePoints / 2
        let scale = snapshot.scale

        let totalWidth = containerSize.width + safeInsets.leading + safeInsets.trailing
        let totalHeight = containerSize.height + safeInsets.top + safeInsets.bottom

        let originX = center.x - halfPoints + safeInsets.leading
        let originY = center.y - halfPoints + safeInsets.top

        let clampedX = min(max(originX, 0), totalWidth - sidePoints)
        let clampedY = min(max(originY, 0), totalHeight - sidePoints)

        let rectPx = CGRect(
            x: clampedX * scale,
            y: clampedY * scale,
            width: sidePoints * scale,
            height: sidePoints * scale
        ).integral

        if let image = snapshot.cgImage {
            let rect = rectPx.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
            print("[Crop] rect=\(rect) center=\(center) safeInsets=\(safeInsets)")
            guard let cg = image.cropping(to: rect) else { return nil }
            return UIImage(cgImage: cg, scale: scale, orientation: .up)
        }
        return nil
    }

    private func cropCircle(snapshot: UIImage) -> UIImage? {
        let diameter = max(config.radius * 2, 1)
        let verticalCorrection: CGFloat = 1.5
        let originX = center.x - config.radius - safeInsets.leading
        let originY = center.y - config.radius - safeInsets.top + verticalCorrection

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = snapshot.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter), format: format)
        return renderer.image { ctx in
            ctx.cgContext.setFillColor(UIColor.systemOrange.withAlphaComponent(0.3).cgColor)
            ctx.cgContext.fill(CGRect(x: 0, y: 0, width: diameter, height: diameter))
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: diameter, height: diameter)).addClip()
            snapshot.draw(at: CGPoint(x: -originX, y: -originY))
        }
    }

    private var lensShader: Shader {
        // The shader receives local coordinates within the circular snapshot
        let localCenter = SIMD2<Float>(Float(config.radius), Float(config.radius))
        let arguments: [Shader.Argument] = [
            .float(localCenter.x),
            .float(localCenter.y),
            .float(Float(config.radius)),
            .float(Float(config.refract)),
            .float(Float(config.edge))
        ]
        
        let library = ShaderLibrary.default
        let function = library[dynamicMember: "lensRefraction"]
        return Shader(function: function, arguments: arguments)
    }

    private var sampleOffset: CGSize {
        let effectRadius = config.radius * 1.15
        return CGSize(
            width: effectRadius * config.refract + 10,
            height: effectRadius * config.refract + 10
        )
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let proposed = CGPoint(
                    x: lastCommittedCenter.x + value.translation.width,
                    y: lastCommittedCenter.y + value.translation.height
                )
                let minX = safeInsets.leading + config.radius
                let maxX = containerSize.width - safeInsets.trailing - config.radius
                let minY = safeInsets.top + config.radius
                // Visual margin that keeps roughly 20 pt from the device edge on large bottom insets
                let visualMargin: CGFloat = 6
                let maxY = containerSize.height + safeInsets.bottom - visualMargin - config.radius
                let clamped = CGPoint(
                    x: min(max(proposed.x, minX), maxX),
                    y: min(max(proposed.y, minY), maxY)
                )
                center = clamped
            }
            .onEnded { _ in
                lastCommittedCenter = center
            }
    }
}


extension Data {
    init<T>(from value: T) {
        var value = value
        self = Swift.withUnsafeBytes(of: &value) { Data($0) }
    }
}

#Preview {
    ContentView()
}
