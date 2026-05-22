Shader "Custom/TimShader"
{
    Properties
    {
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        [MainColor] _BaseColor("Tint", Color) = (1, 1, 1, 1)
        _Offset ("Offset", Range(-1.0, 1.0)) = 0.0
        _Threshold ("Threshold", Range(0.0, 1.0)) = 0.5
        _SunColor ("Sun Color", Color) = (1, 1, 1, 1)
        _AmbientColor ("Ambient Color", Color) = (1, 1, 1, 1)
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "Queue"="Transparent" "RenderPipeline" = "UniversalPipeline" }
        Cull Back
        Pass
        {
            Tags { "LightMode" = "UniversalForward" }
            HLSLPROGRAM

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL0;
                float3 worldPos : TEXCOORD1;
                float4 screenPos : TEXCOORD2;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            TEXTURE2D(_LightRamp);
            SAMPLER(sampler_LightRamp);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;
                float _Offset;
                float _Threshold;
                half4 _SunColor;
                half4 _AmbientColor;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                
                float3 pos = IN.positionOS.xyz;

                // object space animation

                float3 worldPos = TransformObjectToWorld(pos);

                // world space animation
                // worldPos = VertexAnimation(worldPos, IN.normal, IN.uv);
                
                OUT.worldPos = worldPos;
                OUT.positionHCS = TransformWorldToHClip(worldPos);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.normal = TransformObjectToWorldNormal(IN.normal);

                float4 clip = TransformObjectToHClip(OUT.positionHCS);
                OUT.screenPos = ComputeScreenPos(OUT.positionHCS);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                //half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.worldPos.xy ) * _BaseColor;
                half4 texColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);

                float3 normal = normalize(IN.normal);
	            float diffuse = max(dot(normal, normalize(mainLight.direction)), 0.0f);
                
                
                half4 light = diffuse * (1.0f - shadow) * _SunColor + _AmbientColor;
	            light.x = min(light.x, 1.0f);
	            light.y = min(light.y, 1.0f);
	            light.z = min(light.z, 1.0f);

                return texColor * light;
            }

            ENDHLSL
        }

        // Easy enough to add shadow!
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}
