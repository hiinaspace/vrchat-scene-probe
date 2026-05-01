// SceneProbe encoding logic.
// Each input vertex carries a slot index in uv.x. The geometry shader emits one screen-space
// quad per slot covering exactly one pixel of the desktop view, with the slot index passed
// through to the fragment shader. The fragment computes the slot's float value from
// shader uniforms and packs it into the output pixel via EncodeFloatToLinearRGBA.

#ifndef SCENEPROBE_INCLUDED
#define SCENEPROBE_INCLUDED

#include "Codec.hlsl"

// Total number of pixels written. Must match SceneProbeDecoder.SlotCount.
static const uint kSlotCount = 39;

// Per-category slot ranges (start indices, inclusive).
static const uint kSlotCamPos = 0;     // 3 floats: x, y, z (world)
static const uint kSlotCamRot = 3;     // 4 floats: quaternion (x, y, z, w)
static const uint kSlotProj   = 7;     // 4 floats: tan(fovY/2), aspect, near, far
static const uint kSlotSHAr   = 11;    // 4 floats: unity_SHAr
static const uint kSlotSHAg   = 15;    // 4 floats: unity_SHAg
static const uint kSlotSHAb   = 19;    // 4 floats: unity_SHAb
static const uint kSlotSHBr   = 23;    // 4 floats: unity_SHBr
static const uint kSlotSHBg   = 27;    // 4 floats: unity_SHBg
static const uint kSlotSHBb   = 31;    // 4 floats: unity_SHBb
static const uint kSlotSHC    = 35;    // 4 floats: unity_SHC

// Encoding scales — keep in sync with SceneProbeDecoder.
static const float kScalePos  = 1024.0;  // ±1024 m world position range
static const float kScaleQuat = 1.0;     // unit quaternion components
static const float kScaleFov  = 16.0;    // tan(fovY/2) — handles fov up to ~175°
static const float kScaleAsp  = 16.0;    // aspect ratio
static const float kScaleNear = 1024.0;  // near clip
static const float kScaleFar  = 65536.0; // far clip
static const float kScaleSH   = 4.0;     // SH coefficients

uniform float _AutoHide;
uniform float _PixelSize;     // size of each output pixel in screen pixels (default 1)
uniform float _OriginX;       // bottom-left corner of strip, in screen pixels
uniform float _OriginY;

struct VertInput {
    float3 vertex : POSITION;
    float2 uv     : TEXCOORD0;       // uv.x = slot index, uv.y unused
    UNITY_VERTEX_INPUT_INSTANCE_ID
};
struct GeomInput {
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};
struct FragInput {
    nointerpolation uint slot : TEXCOORD0;
    float4 pos : SV_Position;
    UNITY_VERTEX_OUTPUT_STEREO
};

void Vert(VertInput i, out GeomInput o) {
    UNITY_SETUP_INSTANCE_ID(i);
    o.uv = i.uv;
    UNITY_TRANSFER_INSTANCE_ID(i, o);
}

// Emit a single pixel-sized quad covering the slot's pixel in the desktop view.
// Hides in stereo (VR), in mirror cameras, and (if _AutoHide) in cameras with non-zero far clip.
[maxvertexcount(4)]
void Geom(line GeomInput i[2], inout TriangleStream<FragInput> stream) {
    FragInput o;
    UNITY_SETUP_INSTANCE_ID(i[0]);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

    uint slot = (uint)round(i[0].uv.x);

    // Compute pixel rect in NDC.
    float2 screenSize = _ScreenParams.xy;
    float pixelSize = max(_PixelSize, 1.0);
    float2 originPx = float2(_OriginX, _OriginY);
    float2 minPx = originPx + float2(slot, 0) * pixelSize;
    float2 maxPx = minPx + pixelSize;

    // Convert pixels -> NDC [-1, 1]. Snap to pixel grid to guarantee exact byte readback.
    float4 rect; // (xmin, ymin, xmax, ymax) in NDC
    rect.xy = round(minPx) / screenSize * 2.0 - 1.0;
    rect.zw = round(maxPx) / screenSize * 2.0 - 1.0;

    #if UNITY_UV_STARTS_AT_TOP
        rect.yw = -rect.yw;
    #endif

    // Show only in the left eye of a VR stereo pass. Desktop view, right eye, and mirrors
    // are all hidden. The consumer reads from the SteamVR left-eye buffer.
    bool hidden = false;
    #if defined(USING_STEREO_MATRICES)
        if (unity_StereoEyeIndex != 0) hidden = true; // right eye
    #else
        hidden = true; // desktop / non-stereo cameras
    #endif
    if (any(UNITY_MATRIX_P[2].xy)) hidden = true;       // hide in mirrors (skewed near plane)
    if (_AutoHide && _ProjectionParams.z != 0) hidden = true;
    if (hidden) return;

    o.slot = slot;
    o.pos = float4(rect.xy, UNITY_NEAR_CLIP_VALUE, 1); stream.Append(o);
    o.pos = float4(rect.xw, UNITY_NEAR_CLIP_VALUE, 1); stream.Append(o);
    o.pos = float4(rect.zy, UNITY_NEAR_CLIP_VALUE, 1); stream.Append(o);
    o.pos = float4(rect.zw, UNITY_NEAR_CLIP_VALUE, 1); stream.Append(o);
}

// Extract a unit quaternion from a 3x3 rotation matrix (column-major).
// Standard "max diagonal" method, robust to all rotations.
float4 RotMatrixToQuat(float3 c0, float3 c1, float3 c2) {
    float trace = c0.x + c1.y + c2.z;
    float4 q;
    if (trace > 0) {
        float s = sqrt(trace + 1.0) * 2.0;
        q.w = 0.25 * s;
        q.x = (c1.z - c2.y) / s;
        q.y = (c2.x - c0.z) / s;
        q.z = (c0.y - c1.x) / s;
    } else if (c0.x > c1.y && c0.x > c2.z) {
        float s = sqrt(1.0 + c0.x - c1.y - c2.z) * 2.0;
        q.w = (c1.z - c2.y) / s;
        q.x = 0.25 * s;
        q.y = (c1.x + c0.y) / s;
        q.z = (c2.x + c0.z) / s;
    } else if (c1.y > c2.z) {
        float s = sqrt(1.0 + c1.y - c0.x - c2.z) * 2.0;
        q.w = (c2.x - c0.z) / s;
        q.x = (c1.x + c0.y) / s;
        q.y = 0.25 * s;
        q.z = (c2.y + c1.z) / s;
    } else {
        float s = sqrt(1.0 + c2.z - c0.x - c1.y) * 2.0;
        q.w = (c0.y - c1.x) / s;
        q.x = (c2.x + c0.z) / s;
        q.y = (c2.y + c1.z) / s;
        q.z = 0.25 * s;
    }
    return q;
}

float SlotValue(uint slot) {
    // Camera position
    if (slot < kSlotCamRot) {
        return _WorldSpaceCameraPos[slot - kSlotCamPos] / kScalePos;
    }
    // Camera rotation as quaternion. unity_CameraToWorld is the inverse view matrix
    // expressed with +Z as forward (Unity flips view-space Z; CameraToWorld doesn't),
    // so its 3x3 upper-left is the camera->world rotation.
    if (slot < kSlotProj) {
        float4 q = RotMatrixToQuat(unity_CameraToWorld._m00_m10_m20,
                                   unity_CameraToWorld._m01_m11_m21,
                                   unity_CameraToWorld._m02_m12_m22);
        return q[slot - kSlotCamRot] / kScaleQuat;
    }
    // Projection: tan(fovY/2), aspect, near, far.
    if (slot < kSlotSHAr) {
        // Standard perspective Unity matrix: P[1][1] = 1/tan(fovY/2), P[0][0] = P[1][1]/aspect.
        float invTanHalfFovY = UNITY_MATRIX_P._m11;
        float tanHalfFovY = 1.0 / max(invTanHalfFovY, 1e-6);
        float aspect = invTanHalfFovY / max(UNITY_MATRIX_P._m00, 1e-6);
        float nearC = _ProjectionParams.y;
        float farC  = _ProjectionParams.z;
        uint k = slot - kSlotProj;
        float v = (k == 0) ? tanHalfFovY
              : (k == 1) ? aspect
              : (k == 2) ? nearC
              :            farC;
        float s = (k == 0) ? kScaleFov
              : (k == 1) ? kScaleAsp
              : (k == 2) ? kScaleNear
              :            kScaleFar;
        return v / s;
    }
    // SH coefficients (4 floats per uniform).
    if (slot < kSlotSHAg) return unity_SHAr[slot - kSlotSHAr] / kScaleSH;
    if (slot < kSlotSHAb) return unity_SHAg[slot - kSlotSHAg] / kScaleSH;
    if (slot < kSlotSHBr) return unity_SHAb[slot - kSlotSHAb] / kScaleSH;
    if (slot < kSlotSHBg) return unity_SHBr[slot - kSlotSHBr] / kScaleSH;
    if (slot < kSlotSHBb) return unity_SHBg[slot - kSlotSHBg] / kScaleSH;
    if (slot < kSlotSHC ) return unity_SHBb[slot - kSlotSHBb] / kScaleSH;
    return unity_SHC[slot - kSlotSHC] / kScaleSH;
}

half4 Frag(FragInput i) : SV_Target {
    float v = SlotValue(i.slot);
    half4 srgb = EncodeSnorm32(clamp(v, -1.0, 1.0));
    return half4(GammaToLinear(srgb.rgb), srgb.a);
}

#endif
