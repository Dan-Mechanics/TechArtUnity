Shader "Custom/FresnelPulsar"
{
    Properties
    {
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _FresnelColor("Fresnel Color", Color) = (1, 1, 1, 1)
        _BaseMap("Base Map", 2D) = "white" {}
        _NormalTexture("Normal Texture", 2D) = "bump" {}
        _NormalStrength("Normal Strength", Range(0.0, 2.0)) = 1.0
        _FresnelPower("Fresnel Power", Range(1.0, 20.0)) = 4.0
        _FresnelStrength("Fresnel Strength", Float) = 0.15
        _FresnelAmplitude("_FresnelAmplitude", Float) = 1
        _FresnelPeriod("_FresnelPeriod", Float) = 1
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
            #pragma multi_compile _ _FORWARD_PLUS 

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half4 _FresnelColor;
                float4 _BaseMap_ST;
                float _NormalStrength;
                float _FresnelPower;
                float _FresnelStrength;
                float _FresnelPeriod;
                float _FresnelAmplitude;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            TEXTURE2D(_NormalTexture);
            SAMPLER(sampler_NormalTexture);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
                float3 viewWS : TEXCOORD3;
                float4 tangentWS : TEXCOORD4;
            };

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.viewWS = GetWorldSpaceViewDir(output.positionWS);
                output.tangentWS = float4(TransformObjectToWorldDir(input.tangentOS.xyz), input.tangentOS.w);

                return output;
            }

            half4 frag(Varyings input) : SV_TARGET
            {
                float3 normalWS = NormalizeNormalPerPixel(input.normalWS);
                float3 viewWS = normalize(input.viewWS);
                float3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalTexture, sampler_NormalTexture, input.uv), _NormalStrength);
                float3 binormalWS = cross(normalWS, input.tangentWS.xyz) * input.tangentWS.w * unity_WorldTransformParams.w;
                normalWS = normalize(
                    normalTS.x * input.tangentWS.xyz +
                    normalTS.y * binormalWS +
                    normalTS.z * normalWS);

                float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                half3 lightColor = mainLight.distanceAttenuation * mainLight.shadowAttenuation * mainLight.color;

                half3 diffuseLighting = saturate(dot(normalWS, mainLight.direction)) * lightColor;
 
                float pi = 3.14159265359f;
                float b = (2.0f * pi) / _FresnelPeriod;
                float fresnelOffset = sin(_Time.y * b) * _FresnelAmplitude;
                half3 fresnelLighting = pow(1.0f - saturate(dot(normalWS, viewWS)), _FresnelPower + fresnelOffset) * _FresnelStrength;
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;
                half3 litColor = diffuseLighting * baseColor.rgb + fresnelLighting * _FresnelColor.rgb;

                return half4(litColor, baseColor.a);
            }

            ENDHLSL
        }

        Pass
        {
            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            #pragma vertex shadowPassVert
            #pragma fragment shadowPassFrag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            float3 _LightDirection;
            float3 _LightPosition;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
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

            Varyings shadowPassVert(Attributes input)
            {
                Varyings output = (Varyings)0;
                output.positionCS = GetShadowPositionHClip(input.positionOS.xyz, input.normalOS);
                return output;
            }

            float4 shadowPassFrag(Varyings i) : SV_TARGET
            {
                return 0;
            }

            ENDHLSL
        }

        Pass
        {
            Tags
            {
                "LightMode" = "DepthOnly"
            }

            ZWrite On
            ColorMask R

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                return output;
            }

            float frag(Varyings input) : SV_TARGET
            {
                return input.positionCS.z;
            }

            ENDHLSL
        }

        Pass
        {
            Tags
            {
                "LightMode" = "DepthNormals"
            }

            ZWrite On

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half4 _FresnelColor;
                float4 _BaseMap_ST;
                float _NormalStrength;
                float _FresnelPower;
                float _FresnelStrength;
                float _FresnelPeriod;
                float _FresnelAmplitude;
            CBUFFER_END

            TEXTURE2D(_NormalTexture);
            SAMPLER(sampler_NormalTexture);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 tangentWS : TEXCOORD2;
            };

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.normalWS = NormalizeNormalPerVertex(normalWS);
                output.tangentWS = float4(TransformObjectToWorldDir(input.tangentOS.xyz), input.tangentOS.w);

                return output;
            }

            float4 frag(Varyings input) : SV_TARGET
            {
                float3 normalWS = NormalizeNormalPerPixel(input.normalWS);
                float3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalTexture, sampler_NormalTexture, input.uv), _NormalStrength);
                float3 binormalWS = cross(normalWS, input.tangentWS.xyz) * input.tangentWS.w * unity_WorldTransformParams.w;
                normalWS = normalize(
                    normalTS.x * input.tangentWS.xyz +
                    normalTS.y * binormalWS +
                    normalTS.z * normalWS);

                return float4(normalWS, 0.0f);
            }

            ENDHLSL
        }
    }
}