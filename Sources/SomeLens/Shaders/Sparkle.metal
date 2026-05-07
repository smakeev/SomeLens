#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[stitchable]] half4 sparkle(float2 position,
                             SwiftUI::Layer layer,
                             float centerX,
                             float centerY,
                             float radius,
                             float intensity,
                             float scale,
                             float threshold)
{
    float2 center = float2(centerX, centerY);
    float2 toCenter = position - center;
    float dist = length(toCenter);
    float nd = dist / max(radius, 1e-5);
    float2 uv = toCenter / max(radius, 1e-5);

    float clampedScale = max(scale, 1.0);
    float2 cell = floor((uv + 1.0) * clampedScale);
    float cellHash = fract(sin(dot(cell, float2(12.9898, 78.233))) * 43758.5453);
    float2 local = ((uv + 1.0) * clampedScale) - cell - 0.5;
    float starShape = 1.0 - smoothstep(0.0, 0.42, length(local));
    starShape *= max(abs(local.x), abs(local.y)) < 0.36 ? 1.0 : 0.0;

    float rimBias = smoothstep(0.18, 0.72, nd) * (1.0 - smoothstep(0.78, 1.0, nd));
    float sparkleMask = smoothstep(clamp(threshold, 0.0, 0.98), 1.0, cellHash);
    float glint = starShape * sparkleMask * rimBias * saturate(intensity);

    half4 base = layer.sample(position);
    half3 sparkleColor = half3(1.0h, 0.98h, 0.88h);
    base.rgb = mix(base.rgb, sparkleColor, half(glint * 0.65)) + sparkleColor * half(glint * 0.45);
    return base;
}
