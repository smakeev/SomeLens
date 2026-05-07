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
    case ripple(GlassLensRippleShaderSettings)
    case twirl(GlassLensTwirlShaderSettings)
    case caustics(GlassLensCausticsShaderSettings)
    case vignette(GlassLensVignetteShaderSettings)
    case rimGlow(GlassLensRimGlowShaderSettings)
    case sparkle(GlassLensSparkleShaderSettings)
    case prism(GlassLensPrismShaderSettings)
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

public struct GlassLensRippleShaderSettings: Equatable, Sendable {
    public var amplitude: CGFloat
    public var frequency: CGFloat
    public var phase: CGFloat
    public var falloff: CGFloat

    public init(
        amplitude: CGFloat = 9.0,
        frequency: CGFloat = 9.0,
        phase: CGFloat = 0.0,
        falloff: CGFloat = 1.1
    ) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.phase = phase
        self.falloff = falloff
    }
}

public struct GlassLensTwirlShaderSettings: Equatable, Sendable {
    public var angle: CGFloat
    public var falloff: CGFloat
    public var centerRadius: CGFloat

    public init(
        angle: CGFloat = 2.2,
        falloff: CGFloat = 1.15,
        centerRadius: CGFloat = 0.18
    ) {
        self.angle = angle
        self.falloff = falloff
        self.centerRadius = centerRadius
    }
}

public struct GlassLensCausticsShaderSettings: Equatable, Sendable {
    public var intensity: CGFloat
    public var scale: CGFloat
    public var falloff: CGFloat

    public init(
        intensity: CGFloat = 0.32,
        scale: CGFloat = 8.0,
        falloff: CGFloat = 1.25
    ) {
        self.intensity = intensity
        self.scale = scale
        self.falloff = falloff
    }
}

public struct GlassLensVignetteShaderSettings: Equatable, Sendable {
    public var intensity: CGFloat
    public var radius: CGFloat
    public var softness: CGFloat

    public init(
        intensity: CGFloat = 0.55,
        radius: CGFloat = 0.38,
        softness: CGFloat = 0.42
    ) {
        self.intensity = intensity
        self.radius = radius
        self.softness = softness
    }
}

public struct GlassLensRimGlowShaderSettings: Equatable, Sendable {
    public var intensity: CGFloat
    public var width: CGFloat
    public var softness: CGFloat

    public init(
        intensity: CGFloat = 0.72,
        width: CGFloat = 0.16,
        softness: CGFloat = 0.2
    ) {
        self.intensity = intensity
        self.width = width
        self.softness = softness
    }
}

public struct GlassLensSparkleShaderSettings: Equatable, Sendable {
    public var intensity: CGFloat
    public var scale: CGFloat
    public var threshold: CGFloat

    public init(
        intensity: CGFloat = 0.42,
        scale: CGFloat = 34.0,
        threshold: CGFloat = 0.78
    ) {
        self.intensity = intensity
        self.scale = scale
        self.threshold = threshold
    }
}

public struct GlassLensPrismShaderSettings: Equatable, Sendable {
    public var amount: CGFloat
    public var facets: CGFloat
    public var falloff: CGFloat

    public init(
        amount: CGFloat = 10.0,
        facets: CGFloat = 8.0,
        falloff: CGFloat = 1.1
    ) {
        self.amount = amount
        self.facets = facets
        self.falloff = falloff
    }
}
