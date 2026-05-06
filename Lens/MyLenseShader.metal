//
//  MyLenseShader.metal
//  Lens
//
//  Created by Sergey Makeev on 10.11.2025.
//
#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// SwiftUI passes stitchable shader arguments individually rather than as structs
// float2 is represented as two separate floats
[[stitchable]] half4 lensRefraction(float2 position,
                                    SwiftUI::Layer layer,
                                    float centerX,
                                    float centerY,
                                    float radius,
                                    float refract,
                                    float edge)
{
    float2 center = float2(centerX, centerY);
    float2 toCenter = position - center;
    float dist = length(toCenter);

    // Extend effect area beyond visible radius for early visibility
    float effectRadius = radius * 1.15;
    if (dist >= effectRadius) {
        return half4(0.0, 0.0, 0.0, 0.0);
    }

    // Normalized distance from center (0 = center, 1 = rim, >1 = extended area)
    float nd = dist / max(radius, 1e-5);
    
    // Fade out alpha beyond the main radius
    half alphaFade = 1.0h;
    if (dist > radius) {
        float fadeStart = radius;
        float fadeEnd = effectRadius;
        alphaFade = half(1.0 - smoothstep(fadeStart, fadeEnd, dist));
    }

    // Direction from lens center to the sampled point
    float2 normal = (dist > 1e-5) ? (toCenter / dist) : float2(0.0, 0.0);

    // --- REFRACTION ---
    // Stronger magnification near the center with a narrow transition zone
    float magnifyStrength = refract * 0.5;
    float centerRegion = 0.55;
    float magnifyFalloff = smoothstep(0.0, centerRegion, nd);
    float scale = 1.0 - magnifyStrength * (1.0 - magnifyFalloff);

    float refractionRegionStart = centerRegion;
    float refractionBlend = smoothstep(refractionRegionStart, 0.95, nd);
    float refractScale = refract * radius * refractionBlend * 0.35;
    float2 refractPos = center + toCenter * scale - normal * refractScale;
    half4 refracted = layer.sample(refractPos);
    if (refracted.a < 0.001h) {
        refracted = layer.sample(center + toCenter * scale);
    }

    // --- REFLECTION ---
    // Narrow reflective rim
    float reflectScale = refract * radius * 0.02;
    float2 reflectPos = position + normal * reflectScale;
    half4 reflected = layer.sample(reflectPos);
    if (reflected.a < 0.001h) {
        reflected = refracted;
    }

    float clampedEdge = clamp(edge, 0.0, 1.0);
    float rimWidth = 0.003 + (1.0 - clampedEdge) * 0.01;
    float rimInner = 1.0 - rimWidth;
    float rimOuter = 1.0 - rimWidth * 0.25;
    half rimMix = half(smoothstep(rimInner, rimOuter, nd)) * half(clampedEdge);
    half4 mixed = mix(refracted, reflected, rimMix);

    half ring = half(smoothstep(0.99, 1.0, nd) * 0.06);
    mixed.rgb += ring;

    mixed.a = alphaFade;
    return mixed;
}
