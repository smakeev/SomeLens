import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public struct GlassLens: View, Loggable {
    public let center: CGPoint
    public let settings: GlassLensSettings

    @EnvironmentObject private var snapshotProvider: LensSnapshotProvider
    @Environment(\.lensContainerSafeAreaInsets) private var safeInsets

    var log: SomeLensLog.Scope {
        SomeLensLog.lens
    }

    public init(center: CGPoint, settings: GlassLensSettings = GlassLensSettings()) {
        self.center = center
        self.settings = settings
    }

    private var diameter: CGFloat {
        settings.radius * 2
    }

    public var body: some View {
        let snapshot = snapshotProvider.snapshot
        let snapshotVersion = snapshotProvider.snapshotVersion
        let hasSnapshot = snapshot != nil

        ZStack {
            Group {
                if let snapshot, let cropped = cropCircle(snapshot: snapshot) {
                    platformImage(cropped)
                        .resizable()
                        .scaledToFill()
                        .frame(width: diameter, height: diameter)
                        .clipped()
                } else {
                    Color.clear
                }
            }
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
            .layerEffect(lensShader, maxSampleOffset: sampleOffset)

            Circle()
                .stroke(.white.opacity(0.45), lineWidth: settings.ringWidth)
                .blur(radius: 0.2)
                .frame(width: diameter, height: diameter)
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                        .frame(width: diameter, height: diameter)
                )
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
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

    private func cropCircle(snapshot: SomeLensPlatformImage) -> SomeLensPlatformImage? {
        #if os(iOS)
        let diameter = max(settings.radius * 2, 1)
        let verticalCorrection: CGFloat = 1.5
        let originX = center.x - settings.radius - safeInsets.leading
        let originY = center.y - settings.radius - safeInsets.top + verticalCorrection
        d("crop snapshotSize=\(format(snapshot.size)) version=\(snapshotProvider.snapshotVersion) origin=\(format(CGPoint(x: originX, y: originY))) diameter=\(Int(diameter))")

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = snapshot.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter), format: format)
        return renderer.image { context in
            context.cgContext.setFillColor(UIColor.systemOrange.withAlphaComponent(0.3).cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 0, width: diameter, height: diameter))
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: diameter, height: diameter)).addClip()
            snapshot.draw(at: CGPoint(x: -originX, y: -originY))
        }
        #elseif os(macOS)
        let diameter = max(settings.radius * 2, 1)
        let verticalCorrection: CGFloat = 1.5
        let originX = center.x - settings.radius - safeInsets.leading
        let originY = center.y - settings.radius - safeInsets.top + verticalCorrection
        d("crop snapshotSize=\(format(snapshot.size)) version=\(snapshotProvider.snapshotVersion) origin=\(format(CGPoint(x: originX, y: originY))) diameter=\(Int(diameter))")

        let scale = snapshot.backingScale
        let pixelWidth = max(Int((diameter * scale).rounded(.up)), 1)
        let pixelHeight = max(Int((diameter * scale).rounded(.up)), 1)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            i("crop failed: could not allocate macOS bitmap")
            return nil
        }

        bitmap.size = CGSize(width: diameter, height: diameter)
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            i("crop failed: could not create macOS graphics context")
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let cgContext = context.cgContext
        cgContext.scaleBy(x: scale, y: scale)
        cgContext.translateBy(x: 0, y: diameter)
        cgContext.scaleBy(x: 1, y: -1)
        cgContext.setFillColor(NSColor.systemOrange.withAlphaComponent(0.3).cgColor)
        cgContext.fill(CGRect(x: 0, y: 0, width: diameter, height: diameter))
        cgContext.addEllipse(in: CGRect(x: 0, y: 0, width: diameter, height: diameter))
        cgContext.clip()
        snapshot.draw(
            in: CGRect(x: -originX, y: -originY, width: snapshot.size.width, height: snapshot.size.height),
            from: CGRect(origin: .zero, size: snapshot.size),
            operation: .sourceOver,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: CGSize(width: diameter, height: diameter))
        image.addRepresentation(bitmap)
        return image
        #else
        return nil
        #endif
    }

    private var lensShader: Shader {
        let localCenter = SIMD2<Float>(Float(settings.radius), Float(settings.radius))
        let arguments: [Shader.Argument] = [
            .float(localCenter.x),
            .float(localCenter.y),
            .float(Float(settings.radius)),
            .float(Float(settings.refraction)),
            .float(Float(settings.edgeReflection))
        ]

        let library = ShaderLibrary.default
        let function = library[dynamicMember: "lensRefraction"]
        return Shader(function: function, arguments: arguments)
    }

    private var sampleOffset: CGSize {
        let effectRadius = settings.radius * 1.15
        return CGSize(
            width: effectRadius * settings.refraction + 10,
            height: effectRadius * settings.refraction + 10
        )
    }

    private func format(_ point: CGPoint) -> String {
        "(\(Int(point.x)),\(Int(point.y)))"
    }

    private func format(_ size: CGSize) -> String {
        "\(Int(size.width))x\(Int(size.height))"
    }
}

private func platformImage(_ image: SomeLensPlatformImage) -> Image {
    #if os(iOS)
    Image(uiImage: image)
    #elseif os(macOS)
    Image(nsImage: image)
    #endif
}

#if os(macOS)
private extension NSImage {
    var backingScale: CGFloat {
        representations
            .compactMap { representation -> CGFloat? in
                guard representation.size.width > 0 else { return nil }
                return CGFloat(representation.pixelsWide) / representation.size.width
            }
            .max() ?? NSScreen.main?.backingScaleFactor ?? 1
    }
}
#endif
