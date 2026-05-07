#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[stitchable]] half4 colorGlass(float2 position,
                                SwiftUI::Layer layer,
                                float red,
                                float green,
                                float blue,
                                float alpha)
{
    half4 base = layer.sample(position);
    half3 glassColor = half3(half(saturate(red)), half(saturate(green)), half(saturate(blue)));
    half amount = half(saturate(alpha));
    half luminance = dot(base.rgb, half3(0.2126h, 0.7152h, 0.0722h));
    half3 tinted = mix(base.rgb, glassColor * (0.55h + luminance * 0.65h), amount);
    base.rgb = tinted + glassColor * amount * 0.08h;
    return base;
}
