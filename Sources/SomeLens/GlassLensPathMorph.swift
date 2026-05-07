import SwiftUI

extension GlassLensSettings {
    struct PathAnimationSignature: Hashable {
        let width: Int
        let height: Int
        let refraction: Int
        let edgeReflection: Int
        let ringWidth: Int
        let animatesPathChanges: Bool
        let outline: [QuantizedPoint]
    }

    struct QuantizedPoint: Hashable {
        let x: Int
        let y: Int
    }

    var pathAnimationSignature: PathAnimationSignature {
        PathAnimationSignature(
            width: Self.quantized(width),
            height: Self.quantized(height),
            refraction: Self.quantized(refraction),
            edgeReflection: Self.quantized(edgeReflection),
            ringWidth: Self.quantized(ringWidth),
            animatesPathChanges: animatesPathChanges,
            outline: normalizedOutline(sampleCount: Self.signatureSampleCount).map {
                QuantizedPoint(x: Self.quantized($0.x), y: Self.quantized($0.y))
            }
        )
    }

    static func interpolated(
        from start: GlassLensSettings,
        to end: GlassLensSettings,
        progress: CGFloat
    ) -> GlassLensSettings {
        let clampedProgress = min(max(progress, 0), 1)

        guard clampedProgress > 0 else {
            return start
        }

        guard clampedProgress < 1 else {
            return end
        }

        let startPoints = start.normalizedOutline(sampleCount: morphSampleCount)
        let endPoints = end.normalizedOutline(sampleCount: morphSampleCount)
        let points = zip(startPoints, endPoints).map { startPoint, endPoint in
            CGPoint(
                x: interpolate(startPoint.x, endPoint.x, progress: clampedProgress),
                y: interpolate(startPoint.y, endPoint.y, progress: clampedProgress)
            )
        }

        return GlassLensSettings(
            width: interpolate(start.width, end.width, progress: clampedProgress),
            height: interpolate(start.height, end.height, progress: clampedProgress),
            path: { rect in
                Self.path(for: points, in: rect)
            },
            refraction: interpolate(start.refraction, end.refraction, progress: clampedProgress),
            edgeReflection: interpolate(start.edgeReflection, end.edgeReflection, progress: clampedProgress),
            ringWidth: interpolate(start.ringWidth, end.ringWidth, progress: clampedProgress),
            animatesPathChanges: end.animatesPathChanges
        )
    }

    private func normalizedOutline(sampleCount: Int) -> [CGPoint] {
        Self.resampled(points: flattenedNormalizedPath(), sampleCount: sampleCount)
    }

    private func flattenedNormalizedPath() -> [CGPoint] {
        var points: [CGPoint] = []
        var currentPoint = CGPoint.zero
        var subpathStart = CGPoint.zero
        let unitPath = path(CGRect(x: 0, y: 0, width: 1, height: 1)).cgPath

        unitPath.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            let elementPoints = element.points

            switch element.type {
            case .moveToPoint:
                currentPoint = elementPoints[0]
                subpathStart = currentPoint
                points.append(currentPoint)

            case .addLineToPoint:
                currentPoint = elementPoints[0]
                points.append(currentPoint)

            case .addQuadCurveToPoint:
                let start = currentPoint
                let control = elementPoints[0]
                let end = elementPoints[1]
                for step in 1...Self.curveStepCount {
                    let t = CGFloat(step) / CGFloat(Self.curveStepCount)
                    points.append(Self.quadPoint(start: start, control: control, end: end, t: t))
                }
                currentPoint = end

            case .addCurveToPoint:
                let start = currentPoint
                let control1 = elementPoints[0]
                let control2 = elementPoints[1]
                let end = elementPoints[2]
                for step in 1...Self.curveStepCount {
                    let t = CGFloat(step) / CGFloat(Self.curveStepCount)
                    points.append(Self.cubicPoint(start: start, control1: control1, control2: control2, end: end, t: t))
                }
                currentPoint = end

            case .closeSubpath:
                currentPoint = subpathStart
                points.append(subpathStart)

            @unknown default:
                break
            }
        }

        return points.isEmpty ? Self.rectangleOutline : points
    }

    private static func resampled(points: [CGPoint], sampleCount: Int) -> [CGPoint] {
        guard sampleCount > 0 else {
            return []
        }

        guard points.count > 1 else {
            return Array(repeating: points.first ?? .zero, count: sampleCount)
        }

        let closedPoints = points.last == points.first ? points : points + [points[0]]
        let segmentLengths = zip(closedPoints, closedPoints.dropFirst()).map { distance($0, $1) }
        let totalLength = segmentLengths.reduce(0, +)

        if totalLength <= 0 {
            return Array(repeating: closedPoints[0], count: sampleCount)
        }

        return (0..<sampleCount).map { index in
            let targetDistance = totalLength * CGFloat(index) / CGFloat(sampleCount)
            return point(at: targetDistance, in: closedPoints, segmentLengths: segmentLengths)
        }
    }

    private static func point(
        at targetDistance: CGFloat,
        in points: [CGPoint],
        segmentLengths: [CGFloat]
    ) -> CGPoint {
        var remainingDistance = targetDistance

        for index in segmentLengths.indices {
            let segmentLength = segmentLengths[index]
            if remainingDistance <= segmentLength || index == segmentLengths.indices.last {
                let start = points[index]
                let end = points[index + 1]
                let progress = segmentLength > 0 ? remainingDistance / segmentLength : 0
                return CGPoint(
                    x: interpolate(start.x, end.x, progress: progress),
                    y: interpolate(start.y, end.y, progress: progress)
                )
            }
            remainingDistance -= segmentLength
        }

        return points[0]
    }

    nonisolated private static func path(for points: [CGPoint], in rect: CGRect) -> Path {
        Path { path in
            if points.isEmpty {
                path.addRect(rect)
                return
            }

            let first = points[0]
            path.move(to: scaled(first, in: rect))
            for point in points.dropFirst() {
                path.addLine(to: scaled(point, in: rect))
            }
            path.closeSubpath()
        }
    }

    nonisolated private static func scaled(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + point.x * rect.width,
            y: rect.minY + point.y * rect.height
        )
    }

    private static func distance(_ start: CGPoint, _ end: CGPoint) -> CGFloat {
        hypot(end.x - start.x, end.y - start.y)
    }

    private static func quadPoint(start: CGPoint, control: CGPoint, end: CGPoint, t: CGFloat) -> CGPoint {
        let oneMinusT = 1 - t
        return CGPoint(
            x: oneMinusT * oneMinusT * start.x + 2 * oneMinusT * t * control.x + t * t * end.x,
            y: oneMinusT * oneMinusT * start.y + 2 * oneMinusT * t * control.y + t * t * end.y
        )
    }

    private static func cubicPoint(
        start: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        end: CGPoint,
        t: CGFloat
    ) -> CGPoint {
        let oneMinusT = 1 - t
        return CGPoint(
            x: oneMinusT * oneMinusT * oneMinusT * start.x
                + 3 * oneMinusT * oneMinusT * t * control1.x
                + 3 * oneMinusT * t * t * control2.x
                + t * t * t * end.x,
            y: oneMinusT * oneMinusT * oneMinusT * start.y
                + 3 * oneMinusT * oneMinusT * t * control1.y
                + 3 * oneMinusT * t * t * control2.y
                + t * t * t * end.y
        )
    }

    private static func interpolate(_ start: CGFloat, _ end: CGFloat, progress: CGFloat) -> CGFloat {
        start + (end - start) * progress
    }

    private static func quantized(_ value: CGFloat) -> Int {
        Int((value * 10_000).rounded())
    }

    private static let signatureSampleCount = 64
    private static let morphSampleCount = 96
    private static let curveStepCount = 12

    private static let rectangleOutline = [
        CGPoint(x: 0, y: 0),
        CGPoint(x: 1, y: 0),
        CGPoint(x: 1, y: 1),
        CGPoint(x: 0, y: 1)
    ]
}
