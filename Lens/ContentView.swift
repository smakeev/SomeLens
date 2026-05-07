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
    @State private var selectedShaders: [LensDemoShaderOption] = [.refraction]
    @State private var animatesPathChanges = true
    @State private var isRefreshRatePickerPresented = false
    @State private var isCustomRefreshRateEditorPresented = false
    @State private var customMillisecondsText = "200"
    @State private var isPathPickerPresented = false
    @State private var isShaderPickerPresented = false
    private let counterTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    private var lensSettings: GlassLensSettings {
        var settings = selectedPath.settings
        settings.animatesPathChanges = animatesPathChanges
        settings.shaders = selectedShaders.flatMap(\.shaders)
        return settings
    }

    private var isControlMenuActive: Bool {
        isRefreshRatePickerPresented
            || isCustomRefreshRateEditorPresented
            || isPathPickerPresented
            || isShaderPickerPresented
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
                    ZStack(alignment: .topLeading) {
                        DemoBackgroundView(counterValue: currentCounter, safeInsets: safeInsets)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .ignoresSafeArea()

                        LensDemoControlsRow(
                            refreshRate: snapshotRefreshRate,
                            selectedPath: selectedPath,
                            selectedShaders: selectedShaders,
                            animatesPathChanges: $animatesPathChanges,
                            safeInsets: safeInsets,
                            onRefreshRateTap: {
                                withAnimation {
                                    isPathPickerPresented = false
                                    isShaderPickerPresented = false
                                    isRefreshRatePickerPresented.toggle()
                                }
                            },
                            onPathTap: {
                                withAnimation {
                                    isRefreshRatePickerPresented = false
                                    isCustomRefreshRateEditorPresented = false
                                    isShaderPickerPresented = false
                                    isPathPickerPresented.toggle()
                                }
                            },
                            onShaderTap: {
                                withAnimation {
                                    isRefreshRatePickerPresented = false
                                    isCustomRefreshRateEditorPresented = false
                                    isPathPickerPresented = false
                                    isShaderPickerPresented.toggle()
                                }
                            }
                        )
                    }
                } lenses: {
                    GlassLens(center: lensCenter, settings: lensSettings)
                        .gesture(lensDragGesture(containerSize: size, safeInsets: safeInsets))
                }
                .ignoresSafeArea()
                .disabled(isControlMenuActive)

                LensDemoControlsPresentationLayer(
                    refreshRate: $snapshotRefreshRate,
                    selectedPath: $selectedPath,
                    selectedShaders: $selectedShaders,
                    isRefreshRatePickerPresented: $isRefreshRatePickerPresented,
                    isCustomRefreshRateEditorPresented: $isCustomRefreshRateEditorPresented,
                    customMillisecondsText: $customMillisecondsText,
                    isPathPickerPresented: $isPathPickerPresented,
                    isShaderPickerPresented: $isShaderPickerPresented,
                    safeInsets: safeInsets,
                    containerSize: size
                )
                .zIndex(10)
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

private struct LensDemoControlsRow: View {
    let refreshRate: SnapshotRefreshRate
    let selectedPath: LensDemoPathOption
    let selectedShaders: [LensDemoShaderOption]
    @Binding var animatesPathChanges: Bool
    let safeInsets: EdgeInsets
    let onRefreshRateTap: () -> Void
    let onPathTap: () -> Void
    let onShaderTap: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    onRefreshRateTap()
                } label: {
                    controlLabel(refreshRate.displayTitle, width: SnapshotRefreshRateControl.buttonWidth)
                }
                .buttonStyle(.plain)

                Button {
                    onPathTap()
                } label: {
                    controlLabel(selectedPath.title, width: LensPathSelectorControl.buttonWidth)
                }
                .buttonStyle(.plain)

                Button {
                    onShaderTap()
                } label: {
                    controlLabel(shaderButtonTitle, width: LensShaderPicker.buttonWidth)
                }
                .buttonStyle(.plain)

                HStack(spacing: 8) {
                    Text("Animate")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Toggle("Animate path changes", isOn: $animatesPathChanges)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                .frame(width: Self.animationToggleWidth)
                .padding(.vertical, 7)
                .background(Self.controlBackground, in: Capsule())
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            }
            .padding(.leading, safeInsets.leading + 12)
            .padding(.trailing, 12)
        }
        .padding(.top, safeInsets.top + 12)
    }

    private func controlLabel(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .frame(width: width)
            .padding(.vertical, 8)
            .background(Self.controlBackground, in: Capsule())
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }

    private var shaderButtonTitle: String {
        if selectedShaders.isEmpty {
            "Shaders 0"
        } else {
            "Shaders \(selectedShaders.count)"
        }
    }

    private static let controlBackground = Color.white.opacity(0.36)
    private static let animationToggleWidth: CGFloat = 132
}

private struct LensDemoControlsPresentationLayer: View {
    @Binding var refreshRate: SnapshotRefreshRate
    @Binding var selectedPath: LensDemoPathOption
    @Binding var selectedShaders: [LensDemoShaderOption]
    @Binding var isRefreshRatePickerPresented: Bool
    @Binding var isCustomRefreshRateEditorPresented: Bool
    @Binding var customMillisecondsText: String
    @Binding var isPathPickerPresented: Bool
    @Binding var isShaderPickerPresented: Bool
    let safeInsets: EdgeInsets
    let containerSize: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            if isRefreshRatePickerPresented || isPathPickerPresented || isShaderPickerPresented {
                SnapshotRefreshRatePickerShade {
                    withAnimation {
                        isRefreshRatePickerPresented = false
                        isPathPickerPresented = false
                        isShaderPickerPresented = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }

            if isRefreshRatePickerPresented {
                SnapshotRefreshRatePicker(
                    selectedRate: $refreshRate,
                    onSelect: {
                        withAnimation {
                            isRefreshRatePickerPresented = false
                        }
                    },
                    onSelectCustom: {
                        customMillisecondsText = currentCustomMillisecondsText
                        withAnimation {
                            isRefreshRatePickerPresented = false
                            isCustomRefreshRateEditorPresented = true
                        }
                    }
                )
                .padding(.leading, refreshRatePickerLeading)
                .padding(.top, safeInsets.top + 54)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topLeading)))
                .zIndex(2)
            }

            if isPathPickerPresented {
                LensPathPicker(
                    selectedPath: $selectedPath,
                    onSelect: {
                        withAnimation {
                            isPathPickerPresented = false
                        }
                    }
                )
                .padding(.leading, pathPickerLeading)
                .padding(.top, safeInsets.top + 54)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topLeading)))
                .zIndex(2)
            }

            if isShaderPickerPresented {
                LensShaderPicker(
                    selectedShaders: $selectedShaders
                )
                .padding(.leading, shaderPickerLeading)
                .padding(.top, safeInsets.top + 54)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topLeading)))
                .zIndex(2)
            }

            if isCustomRefreshRateEditorPresented {
                SnapshotRefreshRateCustomIntervalEditor(
                    millisecondsText: $customMillisecondsText,
                    onCommit: commitCustomRefreshRate
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.2), value: isRefreshRatePickerPresented)
        .animation(.easeInOut(duration: 0.2), value: isCustomRefreshRateEditorPresented)
        .animation(.easeInOut(duration: 0.2), value: isPathPickerPresented)
        .animation(.easeInOut(duration: 0.2), value: isShaderPickerPresented)
    }

    private var currentCustomMillisecondsText: String {
        if case .custom(let milliseconds) = refreshRate {
            "\(milliseconds)"
        } else {
            customMillisecondsText
        }
    }

    private var refreshRatePickerLeading: CGFloat {
        let ideal = safeInsets.leading + 12
        return adjustedLeading(ideal)
    }

    private var pathPickerLeading: CGFloat {
        let ideal = safeInsets.leading + 12 + SnapshotRefreshRateControl.buttonWidth + 8
        return adjustedLeading(ideal)
    }

    private var shaderPickerLeading: CGFloat {
        let ideal = pathPickerLeading + LensPathSelectorControl.buttonWidth + 8
        return adjustedLeading(ideal)
    }

    private func adjustedLeading(_ ideal: CGFloat) -> CGFloat {
        let pickerWidth: CGFloat = 190
        let horizontalMargin: CGFloat = 12
        return min(ideal, containerSize.width - pickerWidth - horizontalMargin)
    }

    private func commitCustomRefreshRate(_ milliseconds: Int) {
        refreshRate = .custom(milliseconds: milliseconds)
        withAnimation {
            isCustomRefreshRateEditorPresented = false
        }
    }
}

#Preview {
    ContentView()
}
