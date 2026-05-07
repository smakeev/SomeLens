import SwiftUI
import SomeLens

struct LensDemoShaderOption: Identifiable, Equatable {
    let id: String
    let title: String
    let shaders: [GlassLensShader]

    static func == (lhs: LensDemoShaderOption, rhs: LensDemoShaderOption) -> Bool {
        lhs.id == rhs.id
    }
}

extension LensDemoShaderOption {
    static let refraction = LensDemoShaderOption(
        id: "refraction",
        title: "Refraction",
        shaders: [
            .refraction(GlassLensRefractionShaderSettings())
        ]
    )

    static let chromatic = LensDemoShaderOption(
        id: "chromatic",
        title: "Chromatic",
        shaders: [
            .chromaticAberration(
                GlassLensChromaticAberrationShaderSettings(
                    amount: 16.0,
                    falloff: 1.8,
                    edgeOnly: true
                )
            )
        ]
    )

    static let frosted = LensDemoShaderOption(
        id: "frosted",
        title: "Frosted",
        shaders: [
            .frostedBlur(
                GlassLensFrostedBlurShaderSettings(
                    radius: 10.0,
                    intensity: 0.82,
                    edgeBias: 0.2
                )
            )
        ]
    )

    static let magnify = LensDemoShaderOption(
        id: "magnify",
        title: "Magnify",
        shaders: [
            .magnification(
                GlassLensMagnificationShaderSettings(
                    scale: 1.85,
                    falloff: 1.35,
                    centerRadius: 0.45
                )
            )
        ]
    )

    static let ripple = LensDemoShaderOption(
        id: "ripple",
        title: "Ripple",
        shaders: [
            .ripple(
                GlassLensRippleShaderSettings(
                    amplitude: 12.0,
                    frequency: 11.0,
                    phase: 0.6,
                    falloff: 0.85
                )
            )
        ]
    )

    static let twirl = LensDemoShaderOption(
        id: "twirl",
        title: "Twirl",
        shaders: [
            .twirl(
                GlassLensTwirlShaderSettings(
                    angle: 2.8,
                    falloff: 1.0,
                    centerRadius: 0.16
                )
            )
        ]
    )

    static let caustics = LensDemoShaderOption(
        id: "caustics",
        title: "Caustics",
        shaders: [
            .caustics(
                GlassLensCausticsShaderSettings(
                    intensity: 0.48,
                    scale: 10.0,
                    falloff: 0.9
                )
            )
        ]
    )

    static let vignette = LensDemoShaderOption(
        id: "vignette",
        title: "Vignette",
        shaders: [
            .vignette(
                GlassLensVignetteShaderSettings(
                    intensity: 0.78,
                    radius: 0.32,
                    softness: 0.42
                )
            )
        ]
    )

    static let rimGlow = LensDemoShaderOption(
        id: "rim-glow",
        title: "Rim Glow",
        shaders: [
            .rimGlow(
                GlassLensRimGlowShaderSettings(
                    intensity: 0.95,
                    width: 0.22,
                    softness: 0.18
                )
            )
        ]
    )

    static let sparkle = LensDemoShaderOption(
        id: "sparkle",
        title: "Sparkle",
        shaders: [
            .sparkle(
                GlassLensSparkleShaderSettings(
                    intensity: 0.72,
                    scale: 28.0,
                    threshold: 0.68
                )
            )
        ]
    )

    static let prism = LensDemoShaderOption(
        id: "prism",
        title: "Prism",
        shaders: [
            .prism(
                GlassLensPrismShaderSettings(
                    amount: 14.0,
                    facets: 7.0,
                    falloff: 0.9
                )
            )
        ]
    )

    static let colorGlass = LensDemoShaderOption(
        id: "color-glass",
        title: "Color Glass",
        shaders: [
            .colorGlass(
                GlassLensColorGlassShaderSettings(
                    red: 0.35,
                    green: 0.72,
                    blue: 1.0,
                    alpha: 0.42
                )
            )
        ]
    )

    static let noise = LensDemoShaderOption(
        id: "noise",
        title: "Noise",
        shaders: [
            .noise(
                GlassLensNoiseShaderSettings(
                    red: 0.9,
                    green: 0.96,
                    blue: 1.0,
                    alpha: 0.34,
                    density: 0.42
                )
            )
        ]
    )

    static let soapBubble = LensDemoShaderOption(
        id: "soap-bubble",
        title: "Soap",
        shaders: [
            .soapBubble(
                GlassLensSoapBubbleShaderSettings(
                    intensity: 0.72,
                    scale: 7.0,
                    phase: 0.4
                )
            )
        ]
    )

    static let all: [LensDemoShaderOption] = [
        .refraction,
        .chromatic,
        .frosted,
        .magnify,
        .ripple,
        .twirl,
        .caustics,
        .vignette,
        .rimGlow,
        .sparkle,
        .prism,
        .colorGlass,
        .noise,
        .soapBubble
    ]
}

struct LensShaderPicker: View {
    @Binding var selectedShaders: [LensDemoShaderOption]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(LensDemoShaderOption.all) { option in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        toggle(option)
                    }
                } label: {
                    HStack(spacing: 10) {
                        shaderOrderBadge(for: option)
                            .frame(width: 28, height: 24)

                        Text(option.title)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
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

    private func toggle(_ option: LensDemoShaderOption) {
        if let selectedIndex = selectedShaders.firstIndex(of: option) {
            selectedShaders.remove(at: selectedIndex)
        } else {
            selectedShaders.append(option)
        }
    }

    private func shaderOrderBadge(for option: LensDemoShaderOption) -> some View {
        ZStack {
            if let selectedIndex = selectedShaders.firstIndex(of: option) {
                Circle()
                    .fill(Color.accentColor)

                Text("\(selectedIndex + 1)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .stroke(Color.primary.opacity(0.45), lineWidth: 1.3)
            }
        }
    }

    static let buttonWidth: CGFloat = 118
}
