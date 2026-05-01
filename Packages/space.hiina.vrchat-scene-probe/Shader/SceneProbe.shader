Shader "Hiinaspace/VrchatSceneProbe" {
Properties {
    [Header(Probe)]
    [ToggleUI] _AutoHide ("AutoHide (only visible in cameras with farClip=0)", Float) = 0
    _PixelSize ("Pixel size (screen pixels per slot)", Float) = 1
    _OriginX ("Origin X (screen pixels from left)", Float) = 0
    _OriginY ("Origin Y (screen pixels from bottom)", Float) = 0
}
SubShader {
    Tags { "Queue"="Overlay" "RenderType"="Overlay" "PreviewType"="Plane" "IgnoreProjector"="True" }
    Pass {
        Tags { "LightMode"="ForwardBase" }
        Cull Off
        ZTest Always
        ZWrite Off
CGPROGRAM
#pragma target 4.0
#pragma vertex Vert
#pragma geometry Geom
#pragma fragment Frag

#include "UnityCG.cginc"
#include "SceneProbe.hlsl"

ENDCG
    }
}
}
