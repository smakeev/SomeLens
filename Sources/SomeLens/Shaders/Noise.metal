#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[stitchable]] half4 noise(float2 position,
                           SwiftUI::Layer layer,
                           float centerX,
                           float centerY,
                           float radius,
                           float red,
                           float green,
                           float blue,
                           float alpha,
                           float density)
{
    float2 center = float2(centerX, centerY);
    float2 toCenter = position - center;
    float dist = length(toCenter);
    float nd = dist / max(radius, 1e-5);
    float visibleFade = 1.0 - smoothstep(0.72, 0.9, nd);
    float grain = fract(sin(dot(floor(position), float2(12.9898, 78.233))) * 43758.5453);
    float mask = smoothstep(1.0 - saturate(density), 1.0, grain) * visibleFade;
    float signedNoise = (grain * 2.0 - 1.0) * mask * saturate(alpha);

    half4 base = layer.sample(position);
    half3 noiseColor = half3(half(saturate(red)), half(saturate(green)), half(saturate(blue)));
    base.rgb = mix(base.rgb, noiseColor, half(abs(signedNoise) * 0.65));
    base.rgb += noiseColor * half(signedNoise * 0.28);
    return base;
}
