import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public struct GlassLens: View, Loggable {
    public let center: CGPoint
    public let settings: GlassLensSettings

    @State private var displayedSettings: GlassLensSettings?
    @State private var morphStartSettings: GlassLensSettings?
    @State private var morphEndSettings: GlassLensSettings?
    @State private var morphProgress: CGFloat = 1
    @State private var displayedSignature: GlassLensSettings.PathAnimationSignature?

    var log: SomeLensLog.Scope {
        SomeLensLog.lens
    }

    public init(center: CGPoint, settings: GlassLensSettings = GlassLensSettings()) {
        self.center = center
        self.settings = settings
    }

    public var body: some View {
        GlassLensRenderer(
            center: center,
            startSettings: morphStartSettings ?? displayedSettings ?? settings,
            endSettings: morphEndSettings ?? displayedSettings ?? settings,
            progress: morphEndSettings == nil ? 1 : morphProgress
        )
        .task(id: settings.pathAnimationSignature) {
            updateDisplayedSettings()
        }
    }

    private func updateDisplayedSettings() {
        let nextSignature = settings.pathAnimationSignature

        guard displayedSignature != nil else {
            displayedSettings = settings
            morphStartSettings = nil
            morphEndSettings = nil
            morphProgress = 1
            displayedSignature = nextSignature
            return
        }

        guard nextSignature != displayedSignature else {
            displayedSettings = settings
            return
        }

        guard settings.animatesPathChanges else {
            displayedSettings = settings
            displayedSignature = nextSignature
            morphStartSettings = nil
            morphEndSettings = nil
            morphProgress = 1
            return
        }

        let startSettings = displayedSettings ?? settings
        displayedSettings = settings
        displayedSignature = nextSignature
        morphStartSettings = startSettings
        morphEndSettings = settings
        morphProgress = 0

        Task {
            await MainActor.run {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    morphProgress = 1
                }
            }
        }
    }
}

private struct GlassLensRenderer: View, Animatable, Loggable {
    let center: CGPoint
    let startSettings: GlassLensSettings
    let endSettings: GlassLensSettings
    var progress: CGFloat

    @EnvironmentObject private var snapshotProvider: LensSnapshotProvider
    @Environment(\.lensContainerSafeAreaInsets) private var safeInsets

    var animatableData: CGFloat {
        get {
            progress
        }
        set {
            progress = newValue
        }
    }

    var log: SomeLensLog.Scope {
        SomeLensLog.lens
    }

    private var settings: GlassLensSettings {
        GlassLensSettings.interpolated(from: startSettings, to: endSettings, progress: progress)
    }

    private var lensSize: CGSize {
        CGSize(width: max(settings.width, 1), height: max(settings.height, 1))
    }

    private var shaderRadius: CGFloat {
        hypot(lensSize.width, lensSize.height) / 2
    }

    private var lensShape: LensPathShape {
        LensPathShape(path: settings.path)
    }

    var body: some View {
        let snapshot = snapshotProvider.snapshot
        let snapshotVersion = snapshotProvider.snapshotVersion
        let hasSnapshot = snapshot != nil

        ZStack {
            Group {
                if let snapshot {
                    cropPath(snapshot: snapshot)
                } else {
                    Color.clear
                }
            }
            .frame(width: lensSize.width, height: lensSize.height)
            .applyingGlassLensShaders(
                settings.shaders,
                lensSize: lensSize,
                shaderRadius: shaderRadius
            )
            .clipShape(lensShape)

            lensShape
                .stroke(.white.opacity(0.45), lineWidth: settings.ringWidth)
                .blur(radius: 0.2)
                .frame(width: lensSize.width, height: lensSize.height)
                .overlay(
                    lensShape
                        .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                        .frame(width: lensSize.width, height: lensSize.height)
                )
        }
        .frame(width: lensSize.width, height: lensSize.height)
        .contentShape(lensShape)
        .position(x: center.x, y: center.y)
        .opacity(hasSnapshot ? 1 : 0)
        .allowsHitTesting(hasSnapshot)
        .accessibilityLabel("Glass lens")
        .onAppear {
            i("appear center=\(format(center)) hasSnapshot=\(hasSnapshot) version=\(snapshotVersion)")
        }
        .onChange(of: snapshotVersion) { _, newVersion in
            d("received snapshot version=\(newVersion); lens view will re-render and apply shader")
        }
        .onChange(of: center) { _, newCenter in
            d("center changed to \(format(newCenter))")
        }
    }

    private func cropPath(snapshot: SomeLensPlatformImage) -> some View {
        let verticalCorrection: CGFloat = 1.5
        let cropSize = lensSize
        let originX = center.x - cropSize.width / 2 - safeInsets.leading
        let originY = center.y - cropSize.height / 2 - safeInsets.top + verticalCorrection
        let cropRect = CGRect(origin: .zero, size: cropSize)
        let cropPath = settings.path(cropRect).cgPath

        #if os(macOS)
        d("macOS crop snapshotSize=\(format(snapshot.size)) version=\(snapshotProvider.snapshotVersion) origin=\(format(CGPoint(x: originX, y: originY))) size=\(format(cropSize)) offset=\(format(CGPoint(x: -originX, y: -originY)))")

        let cropped = NSImage(size: cropSize, flipped: true) { rect in
            NSColor.systemOrange.withAlphaComponent(0.3).setFill()
            rect.fill()
            NSGraphicsContext.current?.cgContext.addPath(cropPath)
            NSGraphicsContext.current?.cgContext.clip()
            snapshot.draw(
                in: CGRect(
                    x: -originX,
                    y: -originY,
                    width: snapshot.size.width,
                    height: snapshot.size.height
                ),
                from: CGRect(origin: .zero, size: snapshot.size),
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.high]
            )
            return true
        }

        return platformImage(cropped)
            .resizable()
            .scaledToFill()
            .frame(width: cropSize.width, height: cropSize.height)
            .clipped()
        #elseif os(iOS)
        d("crop snapshotSize=\(format(snapshot.size)) version=\(snapshotProvider.snapshotVersion) origin=\(format(CGPoint(x: originX, y: originY))) size=\(format(cropSize))")

        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = snapshot.scale
        rendererFormat.opaque = false
        let renderer = UIGraphicsImageRenderer(size: cropSize, format: rendererFormat)
        let cropped = renderer.image { context in
            context.cgContext.setFillColor(UIColor.systemOrange.withAlphaComponent(0.3).cgColor)
            context.cgContext.fill(cropRect)
            context.cgContext.addPath(cropPath)
            context.cgContext.clip()
            snapshot.draw(at: CGPoint(x: -originX, y: -originY))
        }

        return platformImage(cropped)
            .resizable()
            .scaledToFill()
            .frame(width: cropSize.width, height: cropSize.height)
            .clipped()
        #endif
    }

    private func format(_ point: CGPoint) -> String {
        "(\(Int(point.x)),\(Int(point.y)))"
    }

    private func format(_ size: CGSize) -> String {
        "\(Int(size.width))x\(Int(size.height))"
    }
}

private extension View {
    func applyingGlassLensShaders(
        _ shaders: [GlassLensShader],
        lensSize: CGSize,
        shaderRadius: CGFloat
    ) -> AnyView {
        shaders.reduce(AnyView(self)) { view, shader in
            AnyView(
                view.layerEffect(
                    shader.shader(lensSize: lensSize, shaderRadius: shaderRadius),
                    maxSampleOffset: shader.sampleOffset(shaderRadius: shaderRadius)
                )
            )
        }
    }
}

private extension GlassLensShader {
    func shader(lensSize: CGSize, shaderRadius: CGFloat) -> Shader {
        switch self {
        case .refraction(let settings):
            refractionShader(
                settings: settings,
                lensSize: lensSize,
                shaderRadius: shaderRadius
            )

        case .chromaticAberration(let settings):
            chromaticAberrationShader(
                settings: settings,
                lensSize: lensSize,
                shaderRadius: shaderRadius
            )

        case .frostedBlur(let settings):
            frostedBlurShader(
                settings: settings,
                lensSize: lensSize,
                shaderRadius: shaderRadius
            )

        case .magnification(let settings):
            magnificationShader(
                settings: settings,
                lensSize: lensSize,
                shaderRadius: shaderRadius
            )

        case .ripple(let settings):
            rippleShader(
                settings: settings,
                lensSize: lensSize,
                shaderRadius: shaderRadius
            )

        case .twirl(let settings):
            twirlShader(
                settings: settings,
                lensSize: lensSize,
                shaderRadius: shaderRadius
            )

        case .caustics(let settings):
            causticsShader(
                settings: settings,
                lensSize: lensSize,
                shaderRadius: shaderRadius
            )

        case .vignette(let settings):
            vignetteShader(
                settings: settings,
                lensSize: lensSize,
                shaderRadius: shaderRadius
            )

        case .rimGlow(let settings):
            rimGlowShader(
                settings: settings,
                lensSize: lensSize,
                shaderRadius: shaderRadius
            )

        case .sparkle(let settings):
            sparkleShader(
                settings: settings,
                lensSize: lensSize,
                shaderRadius: shaderRadius
            )

        case .prism(let settings):
            prismShader(
                settings: settings,
                lensSize: lensSize,
                shaderRadius: shaderRadius
            )

        case .colorGlass(let settings):
            colorGlassShader(settings: settings)

        case .noise(let settings):
            noiseShader(
                settings: settings,
                lensSize: lensSize,
                shaderRadius: shaderRadius
            )

        case .soapBubble(let settings):
            soapBubbleShader(
                settings: settings,
                lensSize: lensSize,
                shaderRadius: shaderRadius
            )
        }
    }

    func sampleOffset(shaderRadius: CGFloat) -> CGSize {
        switch self {
        case .refraction(let settings):
            let effectRadius = shaderRadius * 1.15
            return CGSize(
                width: effectRadius * settings.refraction + 10,
                height: effectRadius * settings.refraction + 10
            )

        case .chromaticAberration(let settings):
            let offset = max(settings.amount, 0) + 2
            return CGSize(width: offset, height: offset)

        case .frostedBlur(let settings):
            let offset = max(settings.radius, 0) + 2
            return CGSize(width: offset, height: offset)

        case .magnification:
            return CGSize(width: 2, height: 2)

        case .ripple(let settings):
            let offset = max(abs(settings.amplitude), 0) + 2
            return CGSize(width: offset, height: offset)

        case .twirl(let settings):
            let angle = min(max(abs(settings.angle), 0), .pi)
            let offset = shaderRadius * angle * 0.35 + 2
            return CGSize(width: offset, height: offset)

        case .caustics:
            return CGSize(width: 2, height: 2)

        case .vignette:
            return CGSize(width: 2, height: 2)

        case .rimGlow:
            return CGSize(width: 2, height: 2)

        case .sparkle:
            return CGSize(width: 2, height: 2)

        case .prism(let settings):
            let offset = max(settings.amount, 0) + 2
            return CGSize(width: offset, height: offset)

        case .colorGlass:
            return CGSize(width: 2, height: 2)

        case .noise:
            return CGSize(width: 2, height: 2)

        case .soapBubble:
            return CGSize(width: 2, height: 2)
        }
    }

    private func refractionShader(
        settings: GlassLensRefractionShaderSettings,
        lensSize: CGSize,
        shaderRadius: CGFloat
    ) -> Shader {
        let localCenter = SIMD2<Float>(Float(lensSize.width / 2), Float(lensSize.height / 2))
        let arguments: [Shader.Argument] = [
            .float(localCenter.x),
            .float(localCenter.y),
            .float(Float(shaderRadius)),
            .float(Float(settings.refraction)),
            .float(Float(settings.edgeReflection))
        ]

        let library = ShaderLibrary.bundle(.module)
        let function = library[dynamicMember: "lensRefraction"]
        return Shader(function: function, arguments: arguments)
    }

    private func chromaticAberrationShader(
        settings: GlassLensChromaticAberrationShaderSettings,
        lensSize: CGSize,
        shaderRadius: CGFloat
    ) -> Shader {
        let localCenter = SIMD2<Float>(Float(lensSize.width / 2), Float(lensSize.height / 2))
        let arguments: [Shader.Argument] = [
            .float(localCenter.x),
            .float(localCenter.y),
            .float(Float(shaderRadius)),
            .float(Float(settings.amount)),
            .float(Float(settings.falloff)),
            .float(settings.edgeOnly ? 1 : 0)
        ]

        let library = ShaderLibrary.bundle(.module)
        let function = library[dynamicMember: "chromaticAberration"]
        return Shader(function: function, arguments: arguments)
    }

    private func frostedBlurShader(
        settings: GlassLensFrostedBlurShaderSettings,
        lensSize: CGSize,
        shaderRadius: CGFloat
    ) -> Shader {
        let localCenter = SIMD2<Float>(Float(lensSize.width / 2), Float(lensSize.height / 2))
        let arguments: [Shader.Argument] = [
            .float(localCenter.x),
            .float(localCenter.y),
            .float(Float(shaderRadius)),
            .float(Float(settings.radius)),
            .float(Float(settings.intensity)),
            .float(Float(settings.edgeBias))
        ]

        let library = ShaderLibrary.bundle(.module)
        let function = library[dynamicMember: "frostedBlur"]
        return Shader(function: function, arguments: arguments)
    }

    private func magnificationShader(
        settings: GlassLensMagnificationShaderSettings,
        lensSize: CGSize,
        shaderRadius: CGFloat
    ) -> Shader {
        let localCenter = SIMD2<Float>(Float(lensSize.width / 2), Float(lensSize.height / 2))
        let arguments: [Shader.Argument] = [
            .float(localCenter.x),
            .float(localCenter.y),
            .float(Float(shaderRadius)),
            .float(Float(settings.scale)),
            .float(Float(settings.falloff)),
            .float(Float(settings.centerRadius))
        ]

        let library = ShaderLibrary.bundle(.module)
        let function = library[dynamicMember: "magnification"]
        return Shader(function: function, arguments: arguments)
    }

    private func rippleShader(
        settings: GlassLensRippleShaderSettings,
        lensSize: CGSize,
        shaderRadius: CGFloat
    ) -> Shader {
        let localCenter = SIMD2<Float>(Float(lensSize.width / 2), Float(lensSize.height / 2))
        let arguments: [Shader.Argument] = [
            .float(localCenter.x),
            .float(localCenter.y),
            .float(Float(shaderRadius)),
            .float(Float(settings.amplitude)),
            .float(Float(settings.frequency)),
            .float(Float(settings.phase)),
            .float(Float(settings.falloff))
        ]

        let library = ShaderLibrary.bundle(.module)
        let function = library[dynamicMember: "ripple"]
        return Shader(function: function, arguments: arguments)
    }

    private func twirlShader(
        settings: GlassLensTwirlShaderSettings,
        lensSize: CGSize,
        shaderRadius: CGFloat
    ) -> Shader {
        let localCenter = SIMD2<Float>(Float(lensSize.width / 2), Float(lensSize.height / 2))
        let arguments: [Shader.Argument] = [
            .float(localCenter.x),
            .float(localCenter.y),
            .float(Float(shaderRadius)),
            .float(Float(settings.angle)),
            .float(Float(settings.falloff)),
            .float(Float(settings.centerRadius))
        ]

        let library = ShaderLibrary.bundle(.module)
        let function = library[dynamicMember: "twirl"]
        return Shader(function: function, arguments: arguments)
    }

    private func causticsShader(
        settings: GlassLensCausticsShaderSettings,
        lensSize: CGSize,
        shaderRadius: CGFloat
    ) -> Shader {
        let localCenter = SIMD2<Float>(Float(lensSize.width / 2), Float(lensSize.height / 2))
        let arguments: [Shader.Argument] = [
            .float(localCenter.x),
            .float(localCenter.y),
            .float(Float(shaderRadius)),
            .float(Float(settings.intensity)),
            .float(Float(settings.scale)),
            .float(Float(settings.falloff))
        ]

        let library = ShaderLibrary.bundle(.module)
        let function = library[dynamicMember: "caustics"]
        return Shader(function: function, arguments: arguments)
    }

    private func vignetteShader(
        settings: GlassLensVignetteShaderSettings,
        lensSize: CGSize,
        shaderRadius: CGFloat
    ) -> Shader {
        let localCenter = SIMD2<Float>(Float(lensSize.width / 2), Float(lensSize.height / 2))
        let arguments: [Shader.Argument] = [
            .float(localCenter.x),
            .float(localCenter.y),
            .float(Float(shaderRadius)),
            .float(Float(settings.intensity)),
            .float(Float(settings.radius)),
            .float(Float(settings.softness))
        ]

        let library = ShaderLibrary.bundle(.module)
        let function = library[dynamicMember: "vignette"]
        return Shader(function: function, arguments: arguments)
    }

    private func rimGlowShader(
        settings: GlassLensRimGlowShaderSettings,
        lensSize: CGSize,
        shaderRadius: CGFloat
    ) -> Shader {
        let localCenter = SIMD2<Float>(Float(lensSize.width / 2), Float(lensSize.height / 2))
        let arguments: [Shader.Argument] = [
            .float(localCenter.x),
            .float(localCenter.y),
            .float(Float(shaderRadius)),
            .float(Float(settings.intensity)),
            .float(Float(settings.width)),
            .float(Float(settings.softness))
        ]

        let library = ShaderLibrary.bundle(.module)
        let function = library[dynamicMember: "rimGlow"]
        return Shader(function: function, arguments: arguments)
    }

    private func sparkleShader(
        settings: GlassLensSparkleShaderSettings,
        lensSize: CGSize,
        shaderRadius: CGFloat
    ) -> Shader {
        let localCenter = SIMD2<Float>(Float(lensSize.width / 2), Float(lensSize.height / 2))
        let arguments: [Shader.Argument] = [
            .float(localCenter.x),
            .float(localCenter.y),
            .float(Float(shaderRadius)),
            .float(Float(settings.intensity)),
            .float(Float(settings.scale)),
            .float(Float(settings.threshold))
        ]

        let library = ShaderLibrary.bundle(.module)
        let function = library[dynamicMember: "sparkle"]
        return Shader(function: function, arguments: arguments)
    }

    private func prismShader(
        settings: GlassLensPrismShaderSettings,
        lensSize: CGSize,
        shaderRadius: CGFloat
    ) -> Shader {
        let localCenter = SIMD2<Float>(Float(lensSize.width / 2), Float(lensSize.height / 2))
        let arguments: [Shader.Argument] = [
            .float(localCenter.x),
            .float(localCenter.y),
            .float(Float(shaderRadius)),
            .float(Float(settings.amount)),
            .float(Float(settings.facets)),
            .float(Float(settings.falloff))
        ]

        let library = ShaderLibrary.bundle(.module)
        let function = library[dynamicMember: "prism"]
        return Shader(function: function, arguments: arguments)
    }

    private func colorGlassShader(settings: GlassLensColorGlassShaderSettings) -> Shader {
        let arguments: [Shader.Argument] = [
            .float(Float(settings.red)),
            .float(Float(settings.green)),
            .float(Float(settings.blue)),
            .float(Float(settings.alpha))
        ]

        let library = ShaderLibrary.bundle(.module)
        let function = library[dynamicMember: "colorGlass"]
        return Shader(function: function, arguments: arguments)
    }

    private func noiseShader(
        settings: GlassLensNoiseShaderSettings,
        lensSize: CGSize,
        shaderRadius: CGFloat
    ) -> Shader {
        let localCenter = SIMD2<Float>(Float(lensSize.width / 2), Float(lensSize.height / 2))
        let arguments: [Shader.Argument] = [
            .float(localCenter.x),
            .float(localCenter.y),
            .float(Float(shaderRadius)),
            .float(Float(settings.red)),
            .float(Float(settings.green)),
            .float(Float(settings.blue)),
            .float(Float(settings.alpha)),
            .float(Float(settings.density))
        ]

        let library = ShaderLibrary.bundle(.module)
        let function = library[dynamicMember: "noise"]
        return Shader(function: function, arguments: arguments)
    }

    private func soapBubbleShader(
        settings: GlassLensSoapBubbleShaderSettings,
        lensSize: CGSize,
        shaderRadius: CGFloat
    ) -> Shader {
        let localCenter = SIMD2<Float>(Float(lensSize.width / 2), Float(lensSize.height / 2))
        let arguments: [Shader.Argument] = [
            .float(localCenter.x),
            .float(localCenter.y),
            .float(Float(shaderRadius)),
            .float(Float(settings.intensity)),
            .float(Float(settings.scale)),
            .float(Float(settings.phase))
        ]

        let library = ShaderLibrary.bundle(.module)
        let function = library[dynamicMember: "soapBubble"]
        return Shader(function: function, arguments: arguments)
    }
}

private func platformImage(_ image: SomeLensPlatformImage) -> Image {
    #if os(iOS)
    Image(uiImage: image)
    #elseif os(macOS)
    Image(nsImage: image)
    #endif
}

private struct LensPathShape: InsettableShape {
    let path: GlassLensSettings.LensPathProvider
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        return path(insetRect)
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}
