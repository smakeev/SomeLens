#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[stitchable]] half4 chromaticAberration(float2 position,
                                         SwiftUI::Layer layer,
                                         float centerX,
                                         float centerY,
                                         float radius,
                                         float amount,
                                         float falloff,
                                         float edgeOnly)
{
    float2 center = float2(centerX, centerY);
    float2 toCenter = position - center;
    float dist = length(toCenter);
    float nd = dist / max(radius, 1e-5);
    float2 direction = (dist > 1e-5) ? (toCenter / dist) : float2(0.0, 0.0);

    float clampedFalloff = max(falloff, 0.05);
    float edgeRamp = pow(saturate(nd), clampedFalloff);
    float fullRamp = edgeOnly > 0.5 ? smoothstep(0.55, 1.0, nd) * edgeRamp : edgeRamp;
    float offset = amount * fullRamp;
    float2 channelOffset = direction * offset;

    half4 base = layer.sample(position);
    half4 redSample = layer.sample(position + channelOffset);
    half4 blueSample = layer.sample(position - channelOffset);

    half4 color = base;
    color.r = redSample.r;
    color.b = blueSample.b;
    color.a = base.a;
    return color;
}
