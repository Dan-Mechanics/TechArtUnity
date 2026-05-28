Shader "Custom/WorldLightingColors"
{
    Properties
    {
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _BaseTexture("Base Texture", 2D) = "white" {}
        _NormalTexture("Normal Texture", 2D) = "bump" {}
        _NormalStrength("Normal Strength", Range(0.0, 2.0)) = 1.0
        _AmbientLighting("Ambient Lighting", Color) = (0.2, 0.2, 0.2, 1)
        _Glossiness("Glossiness", Float) = 1
        _FresnelPower("Fresnel Power", Range(1.0, 20.0)) = 4.0
        _FresnelStrength("Fresnel Strength", Range(0.0, 1.0)) = 0.15
        _Threshold("_Threshold", Range(0, 1)) = 0.5
        _Offset ("Offset", Range(-1.0, 1.0)) = 0.0 
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

         //   ZWrite On
          //  ZTest LEqual

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

            //float4 _Threshold;
            // YOU WANT TO KEEP THIS AS SMALL AS POSSIBLE.
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseTexture_ST;
                float4 _BaseColor;
                float _NormalStrength;
                float _Threshold;
                float _Offset;
                float4 _SunColor;
                float4 _SkyColor;
            CBUFFER_END

            TEXTURE2D(_BaseTexture);
            SAMPLER(sampler_BaseTexture);

            TEXTURE2D(_NormalTexture);
            SAMPLER(sampler_NormalTexture);

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

               // o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _BaseTexture);
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                o.positionWS = TransformObjectToWorld(v.positionOS.xyz);
               // o.viewWS = GetWorldSpaceViewDir(o.positionWS);
              //  o.tangentWS = float4(TransformObjectToWorldDir(v.tangentOS.xyz), v.tangentOS.w);
              //  o.dynamicLightmapUV = v.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;

                return o;
            }

            half4 frag(v2f i) : SV_TARGET
            {
                //float3 normalWS = NormalizeNormalPerPixel(i.normalWS);
                //float3 viewWS = normalize(i.viewWS);

                float4 shadowCoord = TransformWorldToShadowCoord(i.positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                
                float3 normalWS = normalize(i.normalWS);
	            float diffuse = max(dot(normalWS, normalize(mainLight.direction)), 0.0f) + _Offset;

                float light = diffuse * mainLight.shadowAttenuation;
                light = step(_Threshold, light);
                half4 lightColor = light * _SunColor + _SkyColor;
                lightColor = min(lightColor, 1.0f);

                float4 baseColor = SAMPLE_TEXTURE2D(_BaseTexture, sampler_BaseTexture, i.uv) * _BaseColor;
                half4 col = baseColor * lightColor;
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
            #pragma vertex shadowPassVert
            #pragma fragment shadowPassFrag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            float3 _LightDirection;
            float3 _LightPosition;

            struct appdata
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct v2f
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

            v2f shadowPassVert(appdata v)
            {
                v2f o = (v2f)0;

                o.positionCS = GetShadowPositionHClip(v.positionOS, v.normalOS);

                return o;
            }

            float4 shadowPassFrag(v2f i) : SV_TARGET
            {
                return 0;
            }

            ENDHLSL
        }

        // DepthOnly and DepthNormals passes added in Part 4.

        Pass
        {
            Tags
            {
                "LightMode" = "DepthOnly"
            }

            ZWrite On
            ColorMask R

            HLSLPROGRAM
            #pragma vertex depthOnlyVert
            #pragma fragment depthOnlyFrag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct appdata
            {
                float4 positionOS : POSITION;
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
            };

            v2f depthOnlyVert(appdata v)
            {
                v2f o = (v2f)0;

                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);

                return o;
            }

            float depthOnlyFrag(v2f i) : SV_TARGET
            {
                return i.positionCS.z;
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
            #pragma vertex depthNormalsVert
            #pragma fragment depthNormalsFrag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _BaseTexture_ST;
                float _NormalStrength;
                float3 _AmbientLighting;
                float _Glossiness;
                float _FresnelPower;
                float _FresnelStrength;
            CBUFFER_END

            TEXTURE2D(_NormalTexture);
            SAMPLER(sampler_NormalTexture);

            struct appdata
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 tangentWS : TEXCOORD2;
            };

            v2f depthNormalsVert(appdata v)
            {
                v2f o = (v2f)0;

                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _BaseTexture);
                float3 normalWS = TransformObjectToWorldNormal(v.normalOS);
                o.normalWS = NormalizeNormalPerVertex(normalWS);
                o.tangentWS = float4(TransformObjectToWorldDir(v.tangentOS.xyz), v.tangentOS.w);

                return o;
            }

            float4 depthNormalsFrag(v2f i) : SV_TARGET
            {
                float3 normalWS = NormalizeNormalPerPixel(i.normalWS);

                float3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalTexture, sampler_NormalTexture, i.uv), _NormalStrength);

                float3 binormalWS = cross(normalWS, i.tangentWS.xyz) * i.tangentWS.w * unity_WorldTransformParams.w;
                normalWS = normalize(
                    normalTS.x * i.tangentWS.xyz +
                    normalTS.y * binormalWS +
                    normalTS.z * normalWS);

                return float4(normalWS, 0.0f);
            }

            ENDHLSL
        }
    }
}