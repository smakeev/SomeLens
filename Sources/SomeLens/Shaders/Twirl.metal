#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[stitchable]] half4 twirl(float2 position,
                           SwiftUI::Layer layer,
                           float centerX,
                           float centerY,
                           float radius,
                           float angle,
                           float falloff,
                           float centerRadius)
{
    float2 center = float2(centerX, centerY);
    float2 toCenter = position - center;
    float dist = length(toCenter);
    float nd = dist / max(radius, 1e-5);

    float clampedFalloff = max(falloff, 0.05);
    float clampedCenterRadius = clamp(centerRadius, 0.0, 0.95);
    float edgeProgress = smoothstep(clampedCenterRadius, 1.0, nd);
    float strength = pow(1.0 - edgeProgress, clampedFalloff);
    float localAngle = -angle * strength;
    float s = sin(localAngle);
    float c = cos(localAngle);
    float2 rotated = float2(
        toCenter.x * c - toCenter.y * s,
        toCenter.x * s + toCenter.y * c
    );

    return layer.sample(center + rotated);
}
