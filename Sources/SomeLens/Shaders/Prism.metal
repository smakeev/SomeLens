#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[stitchable]] half4 prism(float2 position,
                           SwiftUI::Layer layer,
                           float centerX,
                           float centerY,
                           float radius,
                           float amount,
                           float facets,
                           float falloff)
{
    float2 center = float2(centerX, centerY);
    float2 toCenter = position - center;
    float dist = length(toCenter);
    float nd = dist / max(radius, 1e-5);
    float angle = atan2(toCenter.y, toCenter.x);

    float facetCount = max(facets, 3.0);
    float facetAngle = floor((angle + 3.14159265) / (6.2831853 / facetCount)) * (6.2831853 / facetCount);
    float2 facetDirection = float2(cos(facetAngle), sin(facetAngle));
    float edgeFade = smoothstep(0.18, 0.72, nd) * (1.0 - smoothstep(0.82, 1.0, nd));
    float strength = amount * pow(saturate(nd), max(falloff, 0.05)) * edgeFade;
    float2 offset = facetDirection * strength;

    half4 base = layer.sample(position);
    half4 redSample = layer.sample(position + offset);
    half4 greenSample = layer.sample(position - offset * 0.35);
    half4 blueSample = layer.sample(position - offset);

    half4 color = base;
    color.r = redSample.r;
    color.g = greenSample.g;
    color.b = blueSample.b;
    color.a = base.a;
    return color;
}
