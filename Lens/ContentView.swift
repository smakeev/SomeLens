//
//  ContentView.swift
//  Lens
//
//  Created by Sergey Makeev on 10.11.2025.
//

import SwiftUI
import Combine

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
    @State private var lensCenter: CGPoint = CGPoint(x: 200, y: 300)
    @State private var isInitialPlacementDone = false
    @State private var counterValue: Double = 0
    @State private var counterDirection: Double = 1
    @State private var lastCommittedLensCenter: CGPoint = .zero
    private let counterTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private let lensSettings = GlassLensSettings()

    var body: some View {
        GeometryReader { geo in
            let safeInsets = geo.safeAreaInsets
            let size = geo.size
            let currentCounter = Int(counterValue)

            LensContainer(snapshotRefreshRate: .automatic) {
                DemoBackgroundView(counterValue: currentCounter, safeInsets: safeInsets)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
            } lenses: {
                GlassLens(center: lensCenter, settings: lensSettings)
                    .gesture(lensDragGesture(containerSize: size, safeInsets: safeInsets))
            }
            .ignoresSafeArea()
            .onAppear {
                if !isInitialPlacementDone {
                    lensCenter = CGPoint(x: size.width / 2, y: size.height / 2)
                    lastCommittedLensCenter = lensCenter
                    isInitialPlacementDone = true
                }
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
                let proposed = CGPoint(
                    x: lastCommittedLensCenter.x + value.translation.width,
                    y: lastCommittedLensCenter.y + value.translation.height
                )
                let minX = safeInsets.leading + lensSettings.radius
                let maxX = containerSize.width - safeInsets.trailing - lensSettings.radius
                let minY = safeInsets.top + lensSettings.radius
                let visualMargin: CGFloat = 6
                let maxY = containerSize.height + safeInsets.bottom - visualMargin - lensSettings.radius
                let clamped = CGPoint(
                    x: min(max(proposed.x, minX), maxX),
                    y: min(max(proposed.y, minY), maxY)
                )
                lensCenter = clamped
            }
            .onEnded { _ in
                lastCommittedLensCenter = lensCenter
            }
    }
}

#Preview {
    ContentView()
}
