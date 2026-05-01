using UnityEngine;

namespace Hiinaspace.VrchatSceneProbe
{
    public struct SceneProbeFrame
    {
        public Vector3 cameraPosition;
        public Quaternion cameraRotation;
        public float tanHalfFovY;
        public float aspect;
        public float nearClip;
        public float farClip;
        public Vector4 shAr, shAg, shAb, shBr, shBg, shBb, shC;
    }

    // Reference decoder for the SceneProbe pixel layout.
    // The shader emits SlotCount RGBA8 pixels in a 1×SlotCount horizontal strip starting
    // at the bottom-left of the desktop view. Each pixel is one snorm32 value packed
    // little-endian (R = byte 0, G = 1, B = 2, A = 3); the linear ↔ sRGB framebuffer
    // conversion is undone in the shader so the bytes you read are the bytes that were packed.
    //
    // Non-Unity consumers: port the layout below verbatim.
    public static class SceneProbeDecoder
    {
        public const int SlotCount = 39;

        // Slot ranges — keep in sync with Shader/SceneProbe.hlsl.
        public const int SlotCamPos = 0;   // 3 floats: x, y, z
        public const int SlotCamRot = 3;   // 4 floats: quaternion (x, y, z, w)
        public const int SlotProj   = 7;   // 4 floats: tan(fovY/2), aspect, near, far
        public const int SlotSHAr   = 11;  // 4 floats
        public const int SlotSHAg   = 15;
        public const int SlotSHAb   = 19;
        public const int SlotSHBr   = 23;
        public const int SlotSHBg   = 27;
        public const int SlotSHBb   = 31;
        public const int SlotSHC    = 35;

        // Encoding scales — keep in sync with Shader/SceneProbe.hlsl.
        public const float ScalePos  = 1024f;
        public const float ScaleQuat = 1f;
        public const float ScaleFov  = 16f;
        public const float ScaleAsp  = 16f;
        public const float ScaleNear = 1024f;
        public const float ScaleFar  = 65536f;
        public const float ScaleSH   = 4f;

        // Decode SlotCount pixels starting at `offset` in `pixels`.
        public static SceneProbeFrame Decode(Color32[] pixels, int offset = 0)
        {
            if (pixels == null || pixels.Length - offset < SlotCount)
                throw new System.ArgumentException($"need at least {SlotCount} pixels at offset {offset}");

            float Slot(int i, float scale) => DecodeSnorm32(pixels[offset + i]) * scale;

            var f = new SceneProbeFrame
            {
                cameraPosition = new Vector3(
                    Slot(SlotCamPos + 0, ScalePos),
                    Slot(SlotCamPos + 1, ScalePos),
                    Slot(SlotCamPos + 2, ScalePos)),
                cameraRotation = new Quaternion(
                    Slot(SlotCamRot + 0, ScaleQuat),
                    Slot(SlotCamRot + 1, ScaleQuat),
                    Slot(SlotCamRot + 2, ScaleQuat),
                    Slot(SlotCamRot + 3, ScaleQuat)),
                tanHalfFovY = Slot(SlotProj + 0, ScaleFov),
                aspect      = Slot(SlotProj + 1, ScaleAsp),
                nearClip    = Slot(SlotProj + 2, ScaleNear),
                farClip     = Slot(SlotProj + 3, ScaleFar),
                shAr = ReadVec4(pixels, offset + SlotSHAr, ScaleSH),
                shAg = ReadVec4(pixels, offset + SlotSHAg, ScaleSH),
                shAb = ReadVec4(pixels, offset + SlotSHAb, ScaleSH),
                shBr = ReadVec4(pixels, offset + SlotSHBr, ScaleSH),
                shBg = ReadVec4(pixels, offset + SlotSHBg, ScaleSH),
                shBb = ReadVec4(pixels, offset + SlotSHBb, ScaleSH),
                shC  = ReadVec4(pixels, offset + SlotSHC,  ScaleSH),
            };
            return f;
        }

        static Vector4 ReadVec4(Color32[] pixels, int start, float scale)
        {
            return new Vector4(
                DecodeSnorm32(pixels[start + 0]) * scale,
                DecodeSnorm32(pixels[start + 1]) * scale,
                DecodeSnorm32(pixels[start + 2]) * scale,
                DecodeSnorm32(pixels[start + 3]) * scale);
        }

        // Inverse of Shader/Codec.hlsl `EncodeSnorm32`. Treats the RGBA bytes as a little-endian
        // unsigned 32-bit integer mapped linearly from [0, 2^32 - 1] onto [-1, 1 - 2/2^32].
        public static float DecodeSnorm32(Color32 c)
        {
            uint u = (uint)c.r | ((uint)c.g << 8) | ((uint)c.b << 16) | ((uint)c.a << 24);
            // Map [0, 2^32) -> [-1, 1)
            return (float)((double)u / 4294967296.0 * 2.0 - 1.0);
        }
    }
}
