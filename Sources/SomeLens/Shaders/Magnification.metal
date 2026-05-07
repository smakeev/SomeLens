#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[stitchable]] half4 magnification(float2 position,
                                   SwiftUI::Layer layer,
                                   float centerX,
                                   float centerY,
                                   float radius,
                                   float scale,
                                   float falloff,
                                   float centerRadius)
{
    float2 center = float2(centerX, centerY);
    float2 toCenter = position - center;
    float dist = length(toCenter);
    float nd = dist / max(radius, 1e-5);

    float clampedScale = max(scale, 0.05);
    float clampedFalloff = max(falloff, 0.05);
    float clampedCenterRadius = clamp(centerRadius, 0.0, 0.95);
    float edgeProgress = smoothstep(clampedCenterRadius, 1.0, nd);
    float magnifyBlend = pow(1.0 - edgeProgress, clampedFalloff);
    float localScale = mix(1.0, 1.0 / clampedScale, magnifyBlend);
    float2 samplePosition = center + toCenter * localScale;

    return layer.sample(samplePosition);
}
