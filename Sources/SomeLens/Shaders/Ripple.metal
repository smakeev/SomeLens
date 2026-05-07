#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[stitchable]] half4 ripple(float2 position,
                            SwiftUI::Layer layer,
                            float centerX,
                            float centerY,
                            float radius,
                            float amplitude,
                            float frequency,
                            float phase,
                            float falloff)
{
    float2 center = float2(centerX, centerY);
    float2 toCenter = position - center;
    float dist = length(toCenter);
    float nd = dist / max(radius, 1e-5);
    float2 direction = (dist > 1e-5) ? (toCenter / dist) : float2(0.0, 0.0);

    float clampedFalloff = max(falloff, 0.05);
    float edgeFade = 1.0 - smoothstep(0.82, 1.0, nd);
    float centerFade = smoothstep(0.0, 0.18, nd);
    float strength = pow(saturate(1.0 - nd), clampedFalloff) * edgeFade * centerFade;
    float wave = sin(nd * frequency * 6.2831853 + phase);
    float offset = amplitude * wave * strength;
    float2 samplePosition = position + direction * offset;

    return layer.sample(samplePosition);
}
