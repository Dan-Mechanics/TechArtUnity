Shader "Custom/WorldLightingColors"
{
    Properties
    {
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _BaseMap("Base Map", 2D) = "white" {}
        _Threshold("Threshold", Range(0, 1)) = 0.5
        _Offset ("Offset", Range(-1.0, 1.0)) = 0.0
        _ShadowMap("Shadow Map", 2D) = "white" {}
        _EmissiveMap("Emissive Map", 2D) = "white" {}
    }
    
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }

        Pass
        {
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            ZWrite On
            ZTest LEqual

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
			#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _FORWARD_PLUS   // Use _CLUSTER_LIGHT_LOOP in Unity 6.1 and above.
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Unlit.hlsl"

            // UNIFORMS FROM Shader.SetGlobalColor("_SunColor", sunColor);
           // half4 _SunColor;
          //  half4 _SkyColor;

            // CONSTANT BUFFER FOR SPR-BATCHING.
            // YOU WANT TO KEEP THIS AS SMALL AS POSSIBLE.
            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;
                float _Offset;
                float _Threshold;
                // where does this go ??
                half4 _SunColor;
                half4 _SkyColor;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
                
            TEXTURE2D(_ShadowMap);
            SAMPLER(sampler_ShadowMap);

            TEXTURE2D(_EmissiveMap);
            SAMPLER(sampler_EmissiveMap);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL0;
                float fogCoord : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
            };

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

                output.positionCS = vertexInput.positionCS;
                output.positionWS = TransformObjectToWorld(output.positionCS.xyz);
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                #if defined(_FOG_FRAGMENT)
                output.fogCoord = vertexInput.positionVS.z;
                #else
                output.fogCoord = ComputeFogFactor(vertexInput.positionCS.z);
                #endif

                //output.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                output.normal = TransformObjectToWorldNormal(input.normal);

                return output;
            }

            half4 frag(Varyings input) : SV_TARGET
            {
                float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                
                float3 normal = normalize(input.normal);
	            half diffuse = max(dot(normal, normalize(mainLight.direction)), 0.0f) + _Offset;

                half lightAmount = diffuse * mainLight.shadowAttenuation;
                lightAmount = step(_Threshold, lightAmount); // ADD CELL-SHADING
                half4 lightColor = lightAmount * _SunColor + _SkyColor;
                lightColor = saturate(lightColor); // CLAMP LIGHT OUTPUT.

                half4 albedoColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;
                half4 outputColor = albedoColor * lightColor;

                // GET THE FOGFACTOR FROM UNITY.
                #if defined(_FOG_FRAGMENT)
                #if (defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2))
                    float viewZ = -input.fogCoord;
                    float nearToFarZ = max(viewZ - _ProjectionParams.y, 0.0f);
                    half fogFactor = ComputeFogFactorZ0ToFar(nearToFarZ);
                #else
                    half fogFactor = 0.0f;
                #endif
                #else
                    half fogFactor = input.fogCoord;
                #endif

                // APPLY FOG
                outputColor.rgb = MixFog(outputColor.rgb, fogFactor);
                return outputColor;
            }

            ENDHLSL
        }

        // ADD STANDARD SHADOWS ( NOT CLIPPED ).
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}