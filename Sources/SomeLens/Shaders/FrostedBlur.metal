#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[stitchable]] half4 frostedBlur(float2 position,
                                 SwiftUI::Layer layer,
                                 float centerX,
                                 float centerY,
                                 float radius,
                                 float blurRadius,
                                 float intensity,
                                 float edgeBias)
{
    float2 center = float2(centerX, centerY);
    float2 toCenter = position - center;
    float dist = length(toCenter);
    float nd = dist / max(radius, 1e-5);

    float clampedIntensity = saturate(intensity);
    float clampedEdgeBias = saturate(edgeBias);
    float blurRamp = mix(1.0, smoothstep(0.15, 1.0, nd), clampedEdgeBias);
    float spread = max(blurRadius, 0.0) * blurRamp;

    half4 base = layer.sample(position);
    half4 sum = base * 0.20h;
    sum += layer.sample(position + float2(spread, 0.0)) * 0.10h;
    sum += layer.sample(position + float2(-spread, 0.0)) * 0.10h;
    sum += layer.sample(position + float2(0.0, spread)) * 0.10h;
    sum += layer.sample(position + float2(0.0, -spread)) * 0.10h;

    float diagonalSpread = spread * 0.70710678;
    sum += layer.sample(position + float2(diagonalSpread, diagonalSpread)) * 0.10h;
    sum += layer.sample(position + float2(-diagonalSpread, diagonalSpread)) * 0.10h;
    sum += layer.sample(position + float2(diagonalSpread, -diagonalSpread)) * 0.10h;
    sum += layer.sample(position + float2(-diagonalSpread, -diagonalSpread)) * 0.10h;

    half mixAmount = half(clampedIntensity);
    half4 color = mix(base, sum, mixAmount);
    color.a = base.a;
    return color;
}
