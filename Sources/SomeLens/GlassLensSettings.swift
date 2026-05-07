import SwiftUI

public struct GlassLensSettings {
    public typealias LensPathProvider = @Sendable (CGRect) -> Path

    public static let circlePath: LensPathProvider = { rect in
        Path(ellipseIn: rect)
    }

    public var width: CGFloat
    public var height: CGFloat
    public var path: LensPathProvider
    public var ringWidth: CGFloat
    public var animatesPathChanges: Bool
    public var shaders: [GlassLensShader]

    public init(
        width: CGFloat = 160,
        height: CGFloat = 160,
        path: @escaping @Sendable (CGRect) -> Path = GlassLensSettings.circlePath,
        ringWidth: CGFloat = 1.0,
        animatesPathChanges: Bool = false,
        shaders: [GlassLensShader] = [.refraction(GlassLensRefractionShaderSettings())]
    ) {
        self.width = width
        self.height = height
        self.path = path
        self.ringWidth = ringWidth
        self.animatesPathChanges = animatesPathChanges
        self.shaders = shaders
    }

    public static func circle(
        diameter: CGFloat = 160,
        ringWidth: CGFloat = 1.0,
        animatesPathChanges: Bool = false,
        shaders: [GlassLensShader] = [.refraction(GlassLensRefractionShaderSettings())]
    ) -> GlassLensSettings {
        GlassLensSettings(
            width: diameter,
            height: diameter,
            path: circlePath,
            ringWidth: ringWidth,
            animatesPathChanges: animatesPathChanges,
            shaders: shaders
        )
    }
}

public enum GlassLensShader: Equatable, Sendable {
    case refraction(GlassLensRefractionShaderSettings)
    case chromaticAberration(GlassLensChromaticAberrationShaderSettings)
    case frostedBlur(GlassLensFrostedBlurShaderSettings)
    case magnification(GlassLensMagnificationShaderSettings)
}

public struct GlassLensRefractionShaderSettings: Equatable, Sendable {
    public var refraction: CGFloat
    public var edgeReflection: CGFloat

    public init(
        refraction: CGFloat = 1.2,
        edgeReflection: CGFloat = 0.8
    ) {
        self.refraction = refraction
        self.edgeReflection = edgeReflection
    }
}

public struct GlassLensChromaticAberrationShaderSettings: Equatable, Sendable {
    public var amount: CGFloat
    public var falloff: CGFloat
    public var edgeOnly: Bool

    public init(
        amount: CGFloat = 12.0,
        falloff: CGFloat = 1.8,
        edgeOnly: Bool = true
    ) {
        self.amount = amount
        self.falloff = falloff
        self.edgeOnly = edgeOnly
    }
}

public struct GlassLensFrostedBlurShaderSettings: Equatable, Sendable {
    public var radius: CGFloat
    public var intensity: CGFloat
    public var edgeBias: CGFloat

    public init(
        radius: CGFloat = 8.0,
        intensity: CGFloat = 0.72,
        edgeBias: CGFloat = 0.35
    ) {
        self.radius = radius
        self.intensity = intensity
        self.edgeBias = edgeBias
    }
}

public struct GlassLensMagnificationShaderSettings: Equatable, Sendable {
    public var scale: CGFloat
    public var falloff: CGFloat
    public var centerRadius: CGFloat

    public init(
        scale: CGFloat = 1.55,
        falloff: CGFloat = 1.25,
        centerRadius: CGFloat = 0.42
    ) {
        self.scale = scale
        self.falloff = falloff
        self.centerRadius = centerRadius
    }
}
