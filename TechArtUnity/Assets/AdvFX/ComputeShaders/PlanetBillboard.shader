// PlanetBillboard.shader
// Simple billboard for the single central planet object.
// Rendered with a separate DrawMesh call (not instanced).

Shader "Custom/PlanetBillboard"
{
    Properties
    {
        _Color       ("Colour",       Color)  = (0.3, 0.9, 0.4, 1)
        _Radius      ("World Radius", Float)  = 1.0
    }

    SubShader
    {
        Tags
        {
            "RenderType"     = "Transparent"
            "Queue"          = "Transparent+1"
            "RenderPipeline" = "UniversalPipeline"
        }

        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off

        Pass
        {
            Name "PlanetBillboard"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float  _Radius;
            CBUFFER_END

            struct Attributes { 
                float3 posOS : POSITION; 
                float2 uv : TEXCOORD0; 
            };
            struct Varyings   { 
                float4 posCS : SV_POSITION; 
                float2 uv : TEXCOORD0; 
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 worldCenter = TransformObjectToWorld(float3(0,0,0));

                float3 camRight = UNITY_MATRIX_V[0].xyz;
                float3 camUp    = UNITY_MATRIX_V[1].xyz;

                float3 worldPos = worldCenter
                    + camRight * IN.posOS.x * _Radius * 2.0
                    + camUp    * IN.posOS.y * _Radius * 2.0;

                OUT.posCS = TransformWorldToHClip(worldPos);
                OUT.uv    = IN.uv;
                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                float2 c    = IN.uv * 2.0 - 1.0;
                float  dist = length(c);
                clip(1.0 - dist);

                float  alpha     = smoothstep(1.0, 0.88, dist);
                float  highlight = smoothstep(0.5, 0.0, dist) * 0.5;
                float4 col       = _Color;
                col.rgb         += highlight;
                col.a           *= alpha;
                return col;
            }
            ENDHLSL
        }
    }
}
