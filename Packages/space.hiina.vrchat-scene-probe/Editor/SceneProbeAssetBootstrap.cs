#if UNITY_EDITOR
using System.IO;
using nadena.dev.modular_avatar.core;
using UnityEditor;
using UnityEngine;

namespace Hiinaspace.VrchatSceneProbe.Editor
{
    // One-time generator for the SceneProbe mesh, material, and prefab. Runs on editor load and
    // creates any missing assets so the package can be shipped without binary dependencies on
    // a Unity authoring session. Also exposes a menu item to regenerate from scratch.
    [InitializeOnLoad]
    internal static class SceneProbeAssetBootstrap
    {
        const string PackageRoot = "Packages/space.hiina.vrchat-scene-probe";
        const string MeshPath    = PackageRoot + "/Runtime/SceneProbe.mesh";
        const string MatPath     = PackageRoot + "/Runtime/SceneProbe.mat";
        const string PrefabPath  = PackageRoot + "/Runtime/SceneProbe.prefab";
        const string ShaderName  = "Hiinaspace/VrchatSceneProbe";
        const int SlotCount      = 39;

        static SceneProbeAssetBootstrap()
        {
            EditorApplication.delayCall += EnsureAssets;
        }

        [MenuItem("Tools/VRChat Scene Probe/Regenerate Assets")]
        static void Regenerate()
        {
            AssetDatabase.DeleteAsset(MeshPath);
            AssetDatabase.DeleteAsset(MatPath);
            AssetDatabase.DeleteAsset(PrefabPath);
            EnsureAssets();
            EditorUtility.DisplayDialog("VRChat Scene Probe", "Regenerated mesh, material, and prefab.", "OK");
        }

        static void EnsureAssets()
        {
            Directory.CreateDirectory(PackageRoot + "/Runtime");

            var mesh = AssetDatabase.LoadAssetAtPath<Mesh>(MeshPath);
            if (mesh == null) mesh = CreateAndSaveMesh();

            var mat = AssetDatabase.LoadAssetAtPath<Material>(MatPath);
            if (mat == null) mat = CreateAndSaveMaterial();

            var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(PrefabPath);
            if (prefab == null) CreateAndSavePrefab(mesh, mat);
        }

        static Mesh CreateAndSaveMesh()
        {
            // 39 line pairs: each pair is two vertices carrying the same slot index in uv.x.
            // Topology = Lines, so the geometry shader gets each pair as a `line` primitive.
            var verts = new Vector3[SlotCount * 2];
            var uvs   = new Vector2[SlotCount * 2];
            var idx   = new int[SlotCount * 2];
            for (int slot = 0; slot < SlotCount; slot++)
            {
                int i0 = slot * 2;
                int i1 = i0 + 1;
                verts[i0] = Vector3.zero;
                verts[i1] = Vector3.zero;
                uvs[i0]   = new Vector2(slot, 0);
                uvs[i1]   = new Vector2(slot, 0);
                idx[i0]   = i0;
                idx[i1]   = i1;
            }

            var mesh = new Mesh { name = "SceneProbe" };
            mesh.SetVertices(verts);
            mesh.SetUVs(0, uvs);
            mesh.SetIndices(idx, MeshTopology.Lines, 0);
            // Mesh bounds count toward VRChat's avatar performance rank (≤1m for "Excellent").
            // The renderer is parented 1m in front of the head via MA, so a 0.5m AABB at the
            // origin covers a half-meter ball around that point — well within any eye camera's
            // view but still in the "Excellent" bounds bucket.
            mesh.bounds = new Bounds(Vector3.zero, new Vector3(0.5f, 0.5f, 0.5f));
            mesh.UploadMeshData(false);

            AssetDatabase.CreateAsset(mesh, MeshPath);
            AssetDatabase.SaveAssets();
            return mesh;
        }

        static Material CreateAndSaveMaterial()
        {
            var shader = Shader.Find(ShaderName);
            if (shader == null)
            {
                Debug.LogError($"[SceneProbe] Shader '{ShaderName}' not found. Cannot create material.");
                return null;
            }
            var mat = new Material(shader) { name = "SceneProbe" };
            AssetDatabase.CreateAsset(mat, MatPath);
            AssetDatabase.SaveAssets();
            return mat;
        }

        static void CreateAndSavePrefab(Mesh mesh, Material mat)
        {
            if (mesh == null || mat == null) return;
            // The prefab attaches itself to the avatar's Head bone via Modular Avatar and offsets
            // 1m forward so the mesh sits in front of the user's face — guaranteed to be in the
            // VR eye frustum regardless of head pose. The Visible Head Accessory component
            // exempts it from the first-person head-shrink trick so the eye cameras still see it.
            var go = new GameObject("SceneProbe");
            try
            {
                go.transform.localPosition = new Vector3(0f, 0f, 1f);

                var mf = go.AddComponent<MeshFilter>();
                mf.sharedMesh = mesh;
                var mr = go.AddComponent<MeshRenderer>();
                mr.sharedMaterial = mat;
                // The shader writes via SV_Position so light probes / shadows are irrelevant.
                mr.lightProbeUsage = UnityEngine.Rendering.LightProbeUsage.Off;
                mr.reflectionProbeUsage = UnityEngine.Rendering.ReflectionProbeUsage.Off;
                mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
                mr.receiveShadows = false;
                mr.allowOcclusionWhenDynamic = false;

                var boneProxy = go.AddComponent<ModularAvatarBoneProxy>();
                boneProxy.boneReference = HumanBodyBones.Head;
                boneProxy.subPath = string.Empty;
                boneProxy.attachmentMode = BoneProxyAttachmentMode.AsChildKeepPosition;

                go.AddComponent<ModularAvatarVisibleHeadAccessory>();

                PrefabUtility.SaveAsPrefabAsset(go, PrefabPath);
            }
            finally
            {
                Object.DestroyImmediate(go);
            }
        }
    }
}
#endif
