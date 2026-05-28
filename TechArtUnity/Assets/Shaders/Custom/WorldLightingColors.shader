Shader "Custom/WorldLightingColors"
{
    Properties
    {
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _BaseTexture("Base Texture", 2D) = "white" {}
        _AlphaThreshold("Alpha Threshold", Range(0, 1)) = 0.5
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
            // DEFINE WHAT KIND OF PASS THIS IS.
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

            float _ShadingThreshold;
            float _DiffuseBias;
            float4 _SunColor;
            float4 _SkyColor;
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _BaseTexture_ST;
                float _AlphaThreshold; 
            CBUFFER_END

            TEXTURE2D(_BaseTexture);
            SAMPLER(sampler_BaseTexture);

            struct appdata
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
                float fogCoord : TEXCOORD3;
            };

            v2f vert(appdata v)
            {
                v2f o = (v2f)0;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = vertexInput.positionCS;
                o.uv = TRANSFORM_TEX(v.uv, _BaseTexture);
                #if defined(_FOG_FRAGMENT)
                o.fogCoord = vertexInput.positionVS.z;
                #else
                o.fogCoord = ComputeFogFactor(vertexInput.positionCS.z);
                #endif

                o.uv = TRANSFORM_TEX(v.uv, _BaseTexture);
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                o.positionWS = TransformObjectToWorld(v.positionOS.xyz);
                return o;
            }

            half4 frag(v2f i) : SV_TARGET
            {
                float4 baseColor = SAMPLE_TEXTURE2D(_BaseTexture, sampler_BaseTexture, i.uv);
                clip(baseColor.a - _AlphaThreshold);
                
                //float3 normalWS = NormalizeNormalPerPixel(i.normalWS);
                //float3 viewWS = normalize(i.viewWS);

                float4 shadowCoord = TransformWorldToShadowCoord(i.positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                
                float3 normalWS = normalize(i.normalWS);
	            float diffuse = max(dot(normalWS, normalize(mainLight.direction)), 0.0f) - _DiffuseBias;

                float light = diffuse * mainLight.shadowAttenuation;
                light = step(_ShadingThreshold, light);
                half4 lightColor = light * _SunColor + _SkyColor;
                lightColor = saturate(lightColor);

                //float4 baseColor = SAMPLE_TEXTURE2D(_BaseTexture, sampler_BaseTexture, i.uv) * _BaseColor;
                half4 col = baseColor * _BaseColor * lightColor;
                //float depth = logisticDepth(IN.screenPos.z, 0.22f, 78.0f);
                //return lerp(col, _AmbientColor, 0.0f);
                // Combine Base Color with lighting.


               // float3 finalColor = (ambientLighting + diffuseLighting) * baseColor.rgb + specularLighting + fresnelLighting;
                //float3 finalColor = (ambientLighting + diffuseLighting) * _BaseColor.rgb + specularLighting + fresnelLighting;

 

                #if defined(_FOG_FRAGMENT)
                #if (defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2))
                float viewZ = -i.fogCoord;
                float nearToFarZ = max(viewZ - _ProjectionParams.y, 0);
                half fogFactor = ComputeFogFactorZ0ToFar(nearToFarZ);
                #else
                half fogFactor = 0;
                #endif
                #else
                half fogFactor = i.fogCoord;
                #endif

                col.rgb = MixFog(col.rgb, fogFactor);
                return half4(col.rgb, 1.0f);
            }

            ENDHLSL
        }
        
        // ShadowCaster pass added in Part 6.
        Pass
        {
            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            float3 _LightDirection;
            float3 _LightPosition;
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _BaseTexture_ST;
                float _AlphaThreshold; 
            CBUFFER_END

            TEXTURE2D(_BaseTexture);
            SAMPLER(sampler_BaseTexture);

            struct appdata
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            float4 GetShadowPositionHClip(float3 positionOS, float3 normalOS)
            {
                float3 positionWS = TransformObjectToWorld(positionOS);
                float3 normalWS = TransformObjectToWorldNormal(normalOS);

                #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                    float3 lightDirectionWS = normalize(_LightPosition - positionWS);
                #else
                    float3 lightDirectionWS = _LightDirection;
                #endif

                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
                positionCS = ApplyShadowClamping(positionCS);
                return positionCS;
            }

            v2f vert(appdata v)
            {
                v2f o = (v2f)0;
                o.positionCS = GetShadowPositionHClip(v.positionOS, v.normalOS);
                o.uv = TRANSFORM_TEX(v.uv, _BaseTexture);
                return o;
            }

            half4 frag(v2f i) : SV_TARGET
            {
                clip(SAMPLE_TEXTURE2D(_BaseTexture, sampler_BaseTexture, i.uv).a - _AlphaThreshold);
                return 0;
            }

            ENDHLSL
        }
    }
}