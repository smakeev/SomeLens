#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[stitchable]] half4 soapBubble(float2 position,
                                SwiftUI::Layer layer,
                                float centerX,
                                float centerY,
                                float radius,
                                float intensity,
                                float scale,
                                float phase)
{
    float2 center = float2(centerX, centerY);
    float2 toCenter = position - center;
    float dist = length(toCenter);
    float nd = dist / max(radius, 1e-5);
    float angle = atan2(toCenter.y, toCenter.x);
    float clampedScale = max(scale, 0.1);
    float visibleFade = smoothstep(0.05, 0.3, nd) * (1.0 - smoothstep(0.74, 0.92, nd));
    float film = sin(nd * clampedScale * 6.2831853 + sin(angle * 3.0 + phase) * 1.2 + phase);
    float bands = film * 0.5 + 0.5;
    float3 bubbleColor = 0.5 + 0.5 * cos(6.2831853 * (bands + float3(0.0, 0.33, 0.67)));
    float strength = saturate(intensity) * visibleFade;

    half4 base = layer.sample(position);
    half3 color = half3(half(bubbleColor.x), half(bubbleColor.y), half(bubbleColor.z));
    base.rgb = mix(base.rgb, color, half(strength * 0.42));
    base.rgb += color * half(strength * 0.18);
    return base;
}
