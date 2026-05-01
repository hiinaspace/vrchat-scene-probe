# VRChat Scene Probe

A VRChat avatar shader that exposes scene information — camera pose and local light-probe SH lighting — as encoded pixels in the **left VR eye buffer**. An external "AR over VR" overlay app captures those pixels (e.g. through the SteamVR mirror or by reading the left-eye texture directly) and uses them to keep virtual objects fixed in the VRChat world and lit to match the local environment.

The screen-space rect technique is borrowed from [ShaderMotion](https://github.com/lox9973/ShaderMotion): an avatar shader uses `SV_Position` to write directly to fixed screen pixels during the avatar's normal render pass. Compared to ShaderMotion, the visibility logic is inverted — Scene Probe shows **only** in the left eye (and not on desktop, mirrors, or the right eye), since the consumer is a SteamVR mirror reader rather than a desktop video stream.

## Usage

Requires [Modular Avatar](https://modular-avatar.nadena.dev/) (already a VPM dependency).

1. Open this Unity project. On first load, the Scene Probe assets (mesh, material, prefab) are auto-generated under `Runtime/`.
2. Drag `Packages/space.hiina.vrchat-scene-probe/Runtime/SceneProbe.prefab` onto your VRChat avatar (any depth in the hierarchy works). The bundled `ModularAvatarBoneProxy` reparents the renderer under the avatar's Head bone at build time, with a 1 m forward offset so the mesh always sits in the eye-camera frustum. A `ModularAvatarVisibleHeadAccessory` keeps it visible to the first-person head cameras.
3. Upload the avatar. The encoded pixels render only into **the left VR eye** — they're hidden on the VRChat desktop view, the right eye, and in mirrors. The consumer reads them from the SteamVR left-eye buffer (or the SteamVR full mirror window).

### Inspector knobs (on `SceneProbe.mat`)

- **AutoHide** — if on, only renders in cameras with farClip == 0. Default off.
- **PixelSize** — width/height of each encoded pixel in screen pixels. Default 1.
- **OriginX / OriginY** — bottom-left corner of the strip in screen pixels. Default (0, 0).

## Pixel layout

39 RGBA8 pixels in a 1×39 horizontal strip (or `PixelSize × PixelSize` per slot) at the bottom-left of the left VR eye buffer. Each pixel encodes one float as snorm32 little-endian: `R` = byte 0, `G` = 1, `B` = 2, `A` = 3. The shader applies `GammaToLinear` so the linear→sRGB framebuffer conversion produces the bytes you packed.

| Slot | Field | Scale |
|---|---|---|
| 0–2 | Camera world position xyz | ±1024 m |
| 3–6 | Camera world rotation quaternion (x, y, z, w) | ±1 |
| 7 | tan(fovY/2) | ±16 |
| 8 | aspect | ±16 |
| 9 | near clip | ±1024 |
| 10 | far clip | ±65536 |
| 11–14 | `unity_SHAr` | ±4 |
| 15–18 | `unity_SHAg` | ±4 |
| 19–22 | `unity_SHAb` | ±4 |
| 23–26 | `unity_SHBr` | ±4 |
| 27–30 | `unity_SHBg` | ±4 |
| 31–34 | `unity_SHBb` | ±4 |
| 35–38 | `unity_SHC` | ±4 |

Decode each pixel with `value = (uint32_le(rgba) / 2^32) * 2 - 1` then multiply by the slot's scale. See [`Decoder/SceneProbeDecoder.cs`](Decoder/SceneProbeDecoder.cs) for the reference implementation.

## Status

v1: camera pose + light-probe SH only. Depth and realtime directional light are deferred — adding depth requires a depth-light + ShadowCaster pass on the avatar.

## Attribution

The screen-space rect emission, snorm32-RGBA8 packing, and gamma helpers are adapted from [ShaderMotion](https://github.com/lox9973/ShaderMotion) by lox9973, used under the MIT license. See [`Shader/Codec.hlsl`](Shader/Codec.hlsl) and [`Shader/SceneProbe.hlsl`](Shader/SceneProbe.hlsl).
