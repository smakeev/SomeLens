//
//  ContentView.swift
//  Lens
//
//  Created by Sergey Makeev on 10.11.2025.
//

import SwiftUI
import Combine
import SomeLens

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
    @State private var lensCenterRatio: CGPoint = CGPoint(x: 0.5, y: 0.5)
    @State private var counterValue: Double = 0
    @State private var counterDirection: Double = 1
    @State private var lastCommittedLensCenterRatio: CGPoint = CGPoint(x: 0.5, y: 0.5)
    @State private var snapshotRefreshRate: SnapshotRefreshRate = .automatic
    @State private var selectedPath: LensDemoPathOption = .circle
    @State private var isRefreshRateControlActive = false
    @State private var isPathControlActive = false
    private let counterTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    private var lensSettings: GlassLensSettings {
        selectedPath.settings
    }

    var body: some View {
        GeometryReader { geo in
            let safeInsets = geo.safeAreaInsets
            let size = geo.size
            let currentCounter = Int(counterValue)
            let lensCenter = clampedLensCenter(
                ratio: lensCenterRatio,
                containerSize: size,
                safeInsets: safeInsets
            )

            ZStack(alignment: .topLeading) {
                LensContainer(snapshotRefreshRate: snapshotRefreshRate) {
                    DemoBackgroundView(counterValue: currentCounter, safeInsets: safeInsets)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                } lenses: {
                    GlassLens(center: lensCenter, settings: lensSettings)
                        .gesture(lensDragGesture(containerSize: size, safeInsets: safeInsets))
                }
                .ignoresSafeArea()
                .disabled(isRefreshRateControlActive || isPathControlActive)

                SnapshotRefreshRateControl(
                    refreshRate: $snapshotRefreshRate,
                    isInteractionBlocked: $isRefreshRateControlActive,
                    safeInsets: safeInsets
                )

                LensPathSelectorControl(
                    selectedPath: $selectedPath,
                    isInteractionBlocked: $isPathControlActive,
                    safeInsets: safeInsets
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
            }
        }
    }

    private func lensDragGesture(containerSize: CGSize, safeInsets: EdgeInsets) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let lastCommittedLensCenter = clampedLensCenter(
                    ratio: lastCommittedLensCenterRatio,
                    containerSize: containerSize,
                    safeInsets: safeInsets
                )
                let proposed = CGPoint(
                    x: lastCommittedLensCenter.x + value.translation.width,
                    y: lastCommittedLensCenter.y + value.translation.height
                )
                lensCenterRatio = lensCenterRatio(
                    for: clampedLensCenter(
                        proposed,
                        containerSize: containerSize,
                        safeInsets: safeInsets
                    ),
                    containerSize: containerSize,
                    safeInsets: safeInsets
                )
            }
            .onEnded { _ in
                lastCommittedLensCenterRatio = lensCenterRatio
            }
    }

    private func clampedLensCenter(
        ratio: CGPoint,
        containerSize: CGSize,
        safeInsets: EdgeInsets
    ) -> CGPoint {
        let bounds = movementBounds(containerSize: containerSize, safeInsets: safeInsets)

        return clampedLensCenter(
            CGPoint(
                x: bounds.minX + ratio.x * bounds.width,
                y: bounds.minY + ratio.y * bounds.height
            ),
            containerSize: containerSize,
            safeInsets: safeInsets
        )
    }

    private func clampedLensCenter(
        _ proposed: CGPoint,
        containerSize: CGSize,
        safeInsets: EdgeInsets
    ) -> CGPoint {
        let bounds = movementBounds(containerSize: containerSize, safeInsets: safeInsets)

        return CGPoint(
            x: min(max(proposed.x, bounds.minX), bounds.maxX),
            y: min(max(proposed.y, bounds.minY), bounds.maxY)
        )
    }

    private func lensCenterRatio(
        for center: CGPoint,
        containerSize: CGSize,
        safeInsets: EdgeInsets
    ) -> CGPoint {
        let bounds = movementBounds(containerSize: containerSize, safeInsets: safeInsets)

        return CGPoint(
            x: (center.x - bounds.minX) / max(bounds.width, 1),
            y: (center.y - bounds.minY) / max(bounds.height, 1)
        )
    }

    private func movementBounds(containerSize: CGSize, safeInsets: EdgeInsets) -> CGRect {
        let halfLensWidth = lensSettings.width / 2
        let halfLensHeight = lensSettings.height / 2
        let minX = safeInsets.leading + halfLensWidth
        let maxX = max(minX, containerSize.width - safeInsets.trailing - halfLensWidth)
        let minY = safeInsets.top + halfLensHeight
        let visualMargin: CGFloat = 6
        let maxY = max(minY, containerSize.height + safeInsets.bottom - visualMargin - halfLensHeight)

        return CGRect(
            x: minX,
            y: minY,
            width: max(maxX - minX, 1),
            height: max(maxY - minY, 1)
        )
    }
}

#Preview {
    ContentView()
}
