import SwiftUI

public struct GlassLensSettings {
    public typealias LensPathProvider = @Sendable (CGRect) -> Path

    public static let circlePath: LensPathProvider = { rect in
        Path(ellipseIn: rect)
    }

    public var width: CGFloat
    public var height: CGFloat
    public var path: LensPathProvider
    public var refraction: CGFloat
    public var edgeReflection: CGFloat
    public var ringWidth: CGFloat
    public var animatesPathChanges: Bool

    public init(
        width: CGFloat = 160,
        height: CGFloat = 160,
        path: @escaping @Sendable (CGRect) -> Path = GlassLensSettings.circlePath,
        refraction: CGFloat = 1.2,
        edgeReflection: CGFloat = 0.8,
        ringWidth: CGFloat = 1.0,
        animatesPathChanges: Bool = false
    ) {
        self.width = width
        self.height = height
        self.path = path
        self.refraction = refraction
        self.edgeReflection = edgeReflection
        self.ringWidth = ringWidth
        self.animatesPathChanges = animatesPathChanges
    }

    public static func circle(
        diameter: CGFloat = 160,
        refraction: CGFloat = 1.2,
        edgeReflection: CGFloat = 0.8,
        ringWidth: CGFloat = 1.0,
        animatesPathChanges: Bool = false
    ) -> GlassLensSettings {
        GlassLensSettings(
            width: diameter,
            height: diameter,
            path: circlePath,
            refraction: refraction,
            edgeReflection: edgeReflection,
            ringWidth: ringWidth,
            animatesPathChanges: animatesPathChanges
        )
    }
}
