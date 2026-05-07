#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[stitchable]] half4 rimGlow(float2 position,
                             SwiftUI::Layer layer,
                             float centerX,
                             float centerY,
                             float radius,
                             float intensity,
                             float width,
                             float softness)
{
    float2 center = float2(centerX, centerY);
    float2 toCenter = position - center;
    float dist = length(toCenter);
    float nd = dist / max(radius, 1e-5);

    float clampedWidth = clamp(width, 0.01, 0.5);
    float clampedSoftness = max(softness, 0.01);
    float visibleEdge = 0.70710678;
    float inner = max(visibleEdge - clampedWidth - clampedSoftness, 0.0);
    float peak = visibleEdge - clampedWidth * 0.25;
    float outer = visibleEdge + clampedSoftness * 0.75;
    float glowIn = smoothstep(inner, peak, nd);
    float glowOut = 1.0 - smoothstep(peak, outer, nd);
    float glow = saturate(glowIn * glowOut) * saturate(intensity);

    half4 base = layer.sample(position);
    half3 warmEdge = half3(1.0h, 0.96h, 0.82h);
    half3 coolEdge = half3(0.58h, 0.78h, 1.0h);
    half colorShift = half(saturate((nd - 0.52) * 4.0));
    half3 glowColor = mix(warmEdge, coolEdge, colorShift);
    half3 lifted = mix(base.rgb, glowColor, half(glow * 0.55));
    base.rgb = lifted + glowColor * half(glow * 0.35);
    return base;
}
