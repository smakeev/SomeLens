#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[stitchable]] half4 vignette(float2 position,
                              SwiftUI::Layer layer,
                              float centerX,
                              float centerY,
                              float radius,
                              float intensity,
                              float vignetteRadius,
                              float softness)
{
    float2 center = float2(centerX, centerY);
    float2 toCenter = position - center;
    float dist = length(toCenter);
    float nd = dist / max(radius, 1e-5);

    float inner = clamp(vignetteRadius, 0.0, 0.98);
    float outer = clamp(inner + max(softness, 0.01), inner + 0.01, 1.05);
    float edge = smoothstep(inner, outer, nd);
    float darken = saturate(intensity) * edge * edge;
    float contrast = 1.0 + darken * 0.18;

    half4 base = layer.sample(position);
    half3 shadow = half3(0.22h, 0.28h, 0.36h);
    half3 contrasted = (base.rgb - 0.5h) * half(contrast) + 0.5h;
    base.rgb = mix(contrasted, shadow, half(darken * 0.72));
    return base;
}
