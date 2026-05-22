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

                // Normalize worldNormal
                float3 normal = abs(normalize(IN.normal));



                // Alpha Clipping
                // clip(color.a - 0.5);

                // Bypass GetMainLight entirely and sample raw shadow map
                float4 shadowCoord = TransformWorldToShadowCoord(IN.worldPos);
                Light mainLight = GetMainLight(shadowCoord);
                float light = dot(IN.normal, mainLight.direction) * .5 + .5 + _Offset;
                //float light = saturate(dot(IN.normal, mainLight.direction)) + _Offset;

                float lighting = light * mainLight.shadowAttenuation;
                //lighting = saturate(lighting);
                lighting = step(_Threshold, lighting);

                half4 lColor = half4(lighting * _SunColor.r, lighting * _SunColor.g, lighting * _SunColor.b, 1.0f);

                half4 outputColor = half4(lighting * mainLight.color.r, lighting * mainLight.color.g, lighting * mainLight.color.b, 1.0f);
                return lColor * texColor;
            }

            ENDHLSL
        }

        // Easy enough to add shadow!
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}
