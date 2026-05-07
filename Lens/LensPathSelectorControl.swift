import SwiftUI
import SomeLens

struct LensDemoPathOption: Identifiable, Equatable {
    let id: String
    let title: String
    let settings: GlassLensSettings

    var path: GlassLensSettings.LensPathProvider {
        settings.path
    }

    init(
        id: String,
        title: String,
        width: CGFloat,
        height: CGFloat,
        path: @escaping @Sendable (CGRect) -> Path
    ) {
        self.id = id
        self.title = title
        self.settings = GlassLensSettings(
            width: width,
            height: height,
            path: path,
            animatesPathChanges: true
        )
    }

    static func == (lhs: LensDemoPathOption, rhs: LensDemoPathOption) -> Bool {
        lhs.id == rhs.id
    }
}

extension LensDemoPathOption {
    static let circle = LensDemoPathOption(
        id: "circle",
        title: "Circle",
        width: 160,
        height: 160,
        path: GlassLensSettings.circlePath
    )

    static let ellipse = LensDemoPathOption(
        id: "ellipse",
        title: "Ellipse",
        width: 190,
        height: 130,
        path: { Path(ellipseIn: $0) }
    )

    static let square = LensDemoPathOption(
        id: "square",
        title: "Square",
        width: 150,
        height: 150,
        path: { Path($0) }
    )

    static let rectangle = LensDemoPathOption(
        id: "rectangle",
        title: "Rectangle",
        width: 200,
        height: 130,
        path: { Path($0) }
    )

    static let rounded = LensDemoPathOption(
        id: "rounded",
        title: "Rounded",
        width: 180,
        height: 140,
        path: { rect in
            Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) * 0.24)
        }
    )

    static let capsule = LensDemoPathOption(
        id: "capsule",
        title: "Capsule",
        width: 210,
        height: 110,
        path: { rect in
            Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) / 2)
        }
    )

    static let diamond = LensDemoPathOption(
        id: "diamond",
        title: "Diamond",
        width: 160,
        height: 160,
        path: { rect in
            Path { path in
                path.move(to: CGPoint(x: rect.midX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
                path.closeSubpath()
            }
        }
    )

    static let custom = LensDemoPathOption(
        id: "custom-path",
        title: "Custom(Path)",
        width: 190,
        height: 170,
        path: { rect in
            let x = rect.minX
            let y = rect.minY
            let w = rect.width
            let h = rect.height

            return Path { path in
                path.move(to: CGPoint(x: x + w * 0.50, y: y + h * 0.02))
                path.addCurve(
                    to: CGPoint(x: x + w * 0.93, y: y + h * 0.25),
                    control1: CGPoint(x: x + w * 0.72, y: y - h * 0.06),
                    control2: CGPoint(x: x + w * 0.92, y: y + h * 0.06)
                )
                path.addCurve(
                    to: CGPoint(x: x + w * 0.82, y: y + h * 0.72),
                    control1: CGPoint(x: x + w * 1.05, y: y + h * 0.42),
                    control2: CGPoint(x: x + w * 0.94, y: y + h * 0.61)
                )
                path.addCurve(
                    to: CGPoint(x: x + w * 0.48, y: y + h * 0.96),
                    control1: CGPoint(x: x + w * 0.70, y: y + h * 0.87),
                    control2: CGPoint(x: x + w * 0.62, y: y + h * 1.00)
                )
                path.addCurve(
                    to: CGPoint(x: x + w * 0.13, y: y + h * 0.77),
                    control1: CGPoint(x: x + w * 0.33, y: y + h * 0.91),
                    control2: CGPoint(x: x + w * 0.18, y: y + h * 0.95)
                )
                path.addCurve(
                    to: CGPoint(x: x + w * 0.11, y: y + h * 0.28),
                    control1: CGPoint(x: x + w * -0.03, y: y + h * 0.61),
                    control2: CGPoint(x: x + w * 0.02, y: y + h * 0.39)
                )
                path.addCurve(
                    to: CGPoint(x: x + w * 0.50, y: y + h * 0.02),
                    control1: CGPoint(x: x + w * 0.19, y: y + h * 0.10),
                    control2: CGPoint(x: x + w * 0.33, y: y + h * 0.14)
                )
                path.closeSubpath()
            }
        }
    )

    static let all: [LensDemoPathOption] = [
        .circle,
        .ellipse,
        .square,
        .rectangle,
        .rounded,
        .capsule,
        .diamond,
        .custom
    ]
}

struct LensDemoShaderOption: Identifiable, Equatable {
    let id: String
    let title: String
    let shaders: [GlassLensShader]

    static func == (lhs: LensDemoShaderOption, rhs: LensDemoShaderOption) -> Bool {
        lhs.id == rhs.id
    }
}

extension LensDemoShaderOption {
    static let none = LensDemoShaderOption(
        id: "none",
        title: "No shader",
        shaders: []
    )

    static let refraction = LensDemoShaderOption(
        id: "refraction",
        title: "Refraction",
        shaders: [
            .refraction(GlassLensRefractionShaderSettings())
        ]
    )

    static let chain = LensDemoShaderOption(
        id: "chain",
        title: "Chain",
        shaders: [
            .refraction(
                GlassLensRefractionShaderSettings(
                    refraction: 1.2,
                    edgeReflection: 0.8
                )
            ),
            .refraction(
                GlassLensRefractionShaderSettings(
                    refraction: 0.45,
                    edgeReflection: 0.35
                )
            )
        ]
    )

    static let all: [LensDemoShaderOption] = [
        .none,
        .refraction,
        .chain
    ]
}

struct LensPathSelectorControl: View {
    @Binding private var selectedPath: LensDemoPathOption
    @Binding private var isInteractionBlocked: Bool
    private let safeInsets: EdgeInsets
    @State private var isPickerPresented = false

    init(
        selectedPath: Binding<LensDemoPathOption>,
        isInteractionBlocked: Binding<Bool> = .constant(false),
        safeInsets: EdgeInsets = EdgeInsets()
    ) {
        self._selectedPath = selectedPath
        self._isInteractionBlocked = isInteractionBlocked
        self.safeInsets = safeInsets
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            button

            if isPickerPresented {
                SnapshotRefreshRatePickerShade {
                    withAnimation {
                        isPickerPresented = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)

                LensPathPicker(
                    selectedPath: $selectedPath,
                    onSelect: {
                        withAnimation {
                            isPickerPresented = false
                        }
                    }
                )
                .padding(.leading, buttonLeading)
                .padding(.top, safeInsets.top + 54)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topLeading)))
                .zIndex(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.2), value: isPickerPresented)
        .onAppear {
            updateInteractionBlock()
        }
        .onChange(of: isPickerPresented) { _, _ in
            updateInteractionBlock()
        }
    }

    private var button: some View {
        Button {
            withAnimation {
                isPickerPresented.toggle()
            }
        } label: {
            Text(selectedPath.title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(width: Self.buttonWidth)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
        .padding(.leading, buttonLeading)
        .padding(.top, safeInsets.top + 12)
    }

    private var buttonLeading: CGFloat {
        safeInsets.leading + 12 + SnapshotRefreshRateControl.buttonWidth + 8
    }

    private func updateInteractionBlock() {
        isInteractionBlocked = isPickerPresented
    }

    static let buttonWidth: CGFloat = 128
}

struct LensPathPicker: View {
    @Binding var selectedPath: LensDemoPathOption
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(LensDemoPathOption.all) { option in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        selectedPath = option
                        onSelect()
                    }
                } label: {
                    HStack(spacing: 10) {
                        optionPreview(option)
                            .frame(width: 28, height: 24)

                        Text(option.title)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
            }
        }
        .font(.system(size: 14, weight: .medium, design: .rounded))
        .foregroundStyle(.primary)
        .frame(width: 190)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
    }

    private func optionPreview(_ option: LensDemoPathOption) -> some View {
        GeometryReader { geometry in
            option.path(CGRect(origin: .zero, size: geometry.size))
                .stroke(
                    option == selectedPath ? Color.accentColor : Color.primary.opacity(0.55),
                    lineWidth: option == selectedPath ? 2 : 1.3
                )
        }
    }
}

struct LensShaderPicker: View {
    @Binding var selectedShader: LensDemoShaderOption
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(LensDemoShaderOption.all) { option in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        selectedShader = option
                        onSelect()
                    }
                } label: {
                    HStack(spacing: 10) {
                        shaderPreview(option)
                            .frame(width: 28, height: 24)

                        Text(option.title)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
            }
        }
        .font(.system(size: 14, weight: .medium, design: .rounded))
        .foregroundStyle(.primary)
        .frame(width: 190)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
    }

    private func shaderPreview(_ option: LensDemoShaderOption) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<previewDotCount(for: option), id: \.self) { index in
                Circle()
                    .fill(option == selectedShader ? Color.accentColor : Color.primary.opacity(0.55))
                    .opacity(index < option.shaders.count ? 1 : 0.25)
            }
        }
    }

    private func previewDotCount(for option: LensDemoShaderOption) -> Int {
        max(option.shaders.count, 1)
    }

    static let buttonWidth: CGFloat = 104
}
