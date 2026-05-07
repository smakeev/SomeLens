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
