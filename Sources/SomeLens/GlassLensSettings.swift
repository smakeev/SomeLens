import CoreGraphics

public struct GlassLensSettings {
    public var radius: CGFloat
    public var refraction: CGFloat
    public var edgeReflection: CGFloat
    public var ringWidth: CGFloat

    public init(
        radius: CGFloat = 80,
        refraction: CGFloat = 1.2,
        edgeReflection: CGFloat = 0.8,
        ringWidth: CGFloat = 1.0
    ) {
        self.radius = radius
        self.refraction = refraction
        self.edgeReflection = edgeReflection
        self.ringWidth = ringWidth
    }
}
