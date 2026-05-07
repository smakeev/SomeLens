#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[stitchable]] half4 caustics(float2 position,
                              SwiftUI::Layer layer,
                              float centerX,
                              float centerY,
                              float radius,
                              float intensity,
                              float scale,
                              float falloff)
{
    float2 center = float2(centerX, centerY);
    float2 toCenter = position - center;
    float dist = length(toCenter);
    float nd = dist / max(radius, 1e-5);
    float2 uv = toCenter / max(radius, 1e-5);

    float clampedScale = max(scale, 0.1);
    float clampedFalloff = max(falloff, 0.05);
    float radialFade = pow(saturate(1.0 - nd), clampedFalloff);
    float rimFade = 1.0 - smoothstep(0.88, 1.0, nd);

    float waveA = sin((uv.x * 1.7 + uv.y * 0.7) * clampedScale + nd * 5.3);
    float waveB = sin((uv.x * -0.8 + uv.y * 1.9) * clampedScale - nd * 4.1);
    float streaks = pow(saturate((waveA + waveB) * 0.25 + 0.5), 5.0);
    float highlight = saturate(intensity) * streaks * radialFade * rimFade;

    half4 base = layer.sample(position);
    half3 tint = half3(1.0h, 0.94h, 0.78h);
    base.rgb += tint * half(highlight);
    return base;
}
