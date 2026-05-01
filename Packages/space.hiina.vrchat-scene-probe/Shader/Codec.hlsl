// Adapted from ShaderMotion (https://github.com/lox9973/ShaderMotion) — see LICENSE.txt.
// snorm32 <-> RGBA8 packing + sRGB gamma helpers, used by SceneProbe.

#ifndef SCENEPROBE_CODEC_INCLUDED
#define SCENEPROBE_CODEC_INCLUDED

half3 LinearToGamma(half3 color) {
    return color <= 0.0031308 ? 12.92 * color : 1.055 * pow(color, 1.0/2.4) - 0.055;
}
half3 GammaToLinear(half3 color) {
    return color <= 0.04045 ? color / 12.92 : pow(color/1.055 + 0.055/1.055, 2.4);
}
#if defined(UNITY_COLORSPACE_GAMMA)
#define LinearToGamma(x) (x)
#define GammaToLinear(x) (x)
#endif

// Encodes x in [-1, 1] into an RGBA8 pixel as snorm32 (little-endian).
// The decoded byte values are b_i = floor(((x+1)/2) * 256^4) extracted in 8-bit chunks.
half4 EncodeSnorm32(float x) {
    float4 scale = 0.25 * (1 << uint4(0, 8, 16, 24));
    float4 v = frac(x * scale + scale);
    v.xyz -= v.yzw / (1 << 8);
    return v / (255.0/256);
}
float DecodeSnorm32(half4 v) {
    float4 scale = (255.0/256) / (1 << uint4(0, 8, 16, 24)) * 4;
    return dot(v, scale) - 1;
}

// Convert an arbitrary float into a framebuffer-ready linear RGBA color.
// `scale` maps the input range [-scale, scale] -> snorm [-1, 1].
// `GammaToLinear` ensures the linear->sRGB framebuffer write produces the literal byte we packed.
half4 EncodeFloatToLinearRGBA(float value, float scale) {
    half4 srgb = EncodeSnorm32(clamp(value / scale, -1.0, 1.0));
    return half4(GammaToLinear(srgb.rgb), srgb.a);
}

#endif
