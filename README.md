# vrchat-scene-probe

A VPM-installable VRChat package that exposes scene info — camera pose and light-probe SH lighting — from a running VRChat client as encoded pixels in the left VR eye buffer, for use by external "AR over VR" overlays.

See [`CHARTER.md`](CHARTER.md) for the project intent and [`Packages/space.hiina.vrchat-scene-probe/README.md`](Packages/space.hiina.vrchat-scene-probe/README.md) for end-user usage and the pixel layout spec.

## Repository layout

This repo is both a Unity project (for developing the package) and the package itself.

- `Packages/space.hiina.vrchat-scene-probe/` — the package source.
  - `Shader/` — the encoder shader (`SceneProbe.shader`, `SceneProbe.hlsl`, `Codec.hlsl`).
  - `Editor/` — `SceneProbeAssetBootstrap.cs`, an `[InitializeOnLoad]` script that auto-generates the mesh, material, and prefab under `Runtime/` on first project open.
  - `Decoder/` — reference C# decoder (`SceneProbeDecoder.cs`); ports verbatim to non-Unity consumers.
- `Website/` — landing-page source for the GitHub Pages-hosted VPM repo listing (built by the template's actions on release).
- `.github/workflows/` — release/listing automation inherited from [vrchat-community/template-package](https://github.com/vrchat-community/template-package).

## Development

1. Clone the repo and open the root in Unity Hub (Unity 2022.3, with VRChat Creator Companion's package resolver). On first open, the resolver pulls VRChat SDK + Modular Avatar via VPM and `SceneProbeAssetBootstrap` creates `Runtime/SceneProbe.{mesh,mat,prefab}`.
2. Drag the prefab onto a humanoid avatar's hierarchy. The bundled MA Bone Proxy + Visible Head Accessory take care of head-mounting at build time.
3. Iterate on the shader / decoder; commit changes.

To regenerate the runtime assets after editing the bootstrap: **Tools → VRChat Scene Probe → Regenerate Assets**.

## Releasing

Inherited from the VRChat package template:

- Set the `PACKAGE_NAME` repository variable to `space.hiina.vrchat-scene-probe`.
- Run the `Build Release` GitHub Action; it tags a release using the version in `Packages/space.hiina.vrchat-scene-probe/package.json` and publishes a `.zip` + `.unitypackage`.
- The `Build Repo Listing` action then regenerates the VPM listing and serves it via GitHub Pages (Settings → Pages → Source: GitHub Actions).

## License

Code in `Packages/space.hiina.vrchat-scene-probe/Shader/Codec.hlsl` and the screen-rect emission in `SceneProbe.hlsl` are adapted from [ShaderMotion](https://github.com/lox9973/ShaderMotion) (MIT, © 2020-2021 lox9973).
