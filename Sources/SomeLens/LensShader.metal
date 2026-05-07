//
//  LensShader.metal
//  SomeLens
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

[[stitchable]] half4 magnification(float2 position,
                                   SwiftUI::Layer layer,
                                   float centerX,
                                   float centerY,
                                   float radius,
                                   float scale,
                                   float falloff,
                                   float centerRadius)
{
    float2 center = float2(centerX, centerY);
    float2 toCenter = position - center;
    float dist = length(toCenter);
    float nd = dist / max(radius, 1e-5);

    float clampedScale = max(scale, 0.05);
    float clampedFalloff = max(falloff, 0.05);
    float clampedCenterRadius = clamp(centerRadius, 0.0, 0.95);
    float edgeProgress = smoothstep(clampedCenterRadius, 1.0, nd);
    float magnifyBlend = pow(1.0 - edgeProgress, clampedFalloff);
    float localScale = mix(1.0, 1.0 / clampedScale, magnifyBlend);
    float2 samplePosition = center + toCenter * localScale;

    return layer.sample(samplePosition);
}

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

[[stitchable]] half4 twirl(float2 position,
                           SwiftUI::Layer layer,
                           float centerX,
                           float centerY,
                           float radius,
                           float angle,
                           float falloff,
                           float centerRadius)
{
    float2 center = float2(centerX, centerY);
    float2 toCenter = position - center;
    float dist = length(toCenter);
    float nd = dist / max(radius, 1e-5);

    float clampedFalloff = max(falloff, 0.05);
    float clampedCenterRadius = clamp(centerRadius, 0.0, 0.95);
    float edgeProgress = smoothstep(clampedCenterRadius, 1.0, nd);
    float strength = pow(1.0 - edgeProgress, clampedFalloff);
    float localAngle = -angle * strength;
    float s = sin(localAngle);
    float c = cos(localAngle);
    float2 rotated = float2(
        toCenter.x * c - toCenter.y * s,
        toCenter.x * s + toCenter.y * c
    );

    return layer.sample(center + rotated);
}

[[stitchable]] half4 caustics(float2 position,
                              SwiftUI::Layer layer,
                              float centerX,
                              float centerY,
                              float radius,
                              float intensity,
                              float scale,
                              float falloff)
{
    float2 center = float2(centerX, centerY);
    float2 toCenter = position - center;
    float dist = length(toCenter);
    float nd = dist / max(radius, 1e-5);
    float2 uv = toCenter / max(radius, 1e-5);

    float clampedScale = max(scale, 0.1);
    float clampedFalloff = max(falloff, 0.05);
    float radialFade = pow(saturate(1.0 - nd), clampedFalloff);
    float rimFade = 1.0 - smoothstep(0.88, 1.0, nd);

    float waveA = sin((uv.x * 1.7 + uv.y * 0.7) * clampedScale + nd * 5.3);
    float waveB = sin((uv.x * -0.8 + uv.y * 1.9) * clampedScale - nd * 4.1);
    float streaks = pow(saturate((waveA + waveB) * 0.25 + 0.5), 5.0);
    float highlight = saturate(intensity) * streaks * radialFade * rimFade;

    half4 base = layer.sample(position);
    half3 tint = half3(1.0h, 0.94h, 0.78h);
    base.rgb += tint * half(highlight);
    return base;
}

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

[[stitchable]] half4 rimGlow(float2 position,
                             SwiftUI::Layer layer,
                             float centerX,
                             float centerY,
                             float radius,
                             float intensity,
                             float width,
                             float softness)
{
    float2 center = float2(centerX, centerY);
    float2 toCenter = position - center;
    float dist = length(toCenter);
    float nd = dist / max(radius, 1e-5);

    float clampedWidth = clamp(width, 0.01, 0.5);
    float clampedSoftness = max(softness, 0.01);
    float visibleEdge = 0.70710678;
    float inner = max(visibleEdge - clampedWidth - clampedSoftness, 0.0);
    float peak = visibleEdge - clampedWidth * 0.25;
    float outer = visibleEdge + clampedSoftness * 0.75;
    float glowIn = smoothstep(inner, peak, nd);
    float glowOut = 1.0 - smoothstep(peak, outer, nd);
    float glow = saturate(glowIn * glowOut) * saturate(intensity);

    half4 base = layer.sample(position);
    half3 warmEdge = half3(1.0h, 0.96h, 0.82h);
    half3 coolEdge = half3(0.58h, 0.78h, 1.0h);
    half colorShift = half(saturate((nd - 0.52) * 4.0));
    half3 glowColor = mix(warmEdge, coolEdge, colorShift);
    half3 lifted = mix(base.rgb, glowColor, half(glow * 0.55));
    base.rgb = lifted + glowColor * half(glow * 0.35);
    return base;
}

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
