Shader "Custom/WorldLightingColors"
{
    Properties
    {
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _BaseMap("Base Map", 2D) = "white" {}
        [Toggle(_ALPHA_CLIPPING)] _AlphaClipping("Alpha Clipping", Integer) = 0
        _AlphaThreshold("Alpha Threshold", Range(0.1, 0.9)) = 0.5
        [Toggle(_HIDE_OUTLINE)] _HideOutline("Hide Outline", Integer) = 1
        _OutlineColor("Outline Color", Color) = (1, 1, 1, 1)
        _OutlineWidth("Outline Width", Float) = 0.01
        _LineDistance("Line Distance", Float) = 25
        _SunColor("Sun Color", Color) = (1, 1, 1, 1)
        _SkyColor("Sky Color", Color) = (0, 0, 1, 1)
        [NoScaleOffset] _EmissionMap("Emission Map", 2D) = "black" {}
        [NoScaleOffset] _ShadowMap("Shadow Map", 2D) = "white" {}
        [NoScaleOffset] _OutlineMap("Outline Map", 2D) = "white" {}
    }
    
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }
        
        // OUTLINE PASS.
        Cull Front
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog // DECLARE USING FOG.

            #pragma shader_feature_local _ _ALPHA_CLIPPING
            #pragma shader_feature_local _ _HIDE_OUTLINE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Unlit.hlsl"
 
            // UNIFORMS FROM WORLDLIGHTINGCOLORS.CS.
            half _ShadingThreshold;
            half _DiffuseBias;
            // STANDS FOR CONSTANT BUFFER,
            // IT IS USED FOR SPR-BATCHING.
            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST; // "ST" IS TILING AND OFFSET.
                half4 _SunColor; // THIS NEEDS TO BE HERE BECAUSE WITH UNIFORMS THE COLOR IS INACCURATE.
                half4 _SkyColor; 
                half4 _OutlineColor;
                float _OutlineWidth;
                float _LineDistance;
                half _AlphaThreshold;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            TEXTURE2D(_OutlineMap);

            struct Attributes
            {
                float4 positionOS : POSITION; 
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION; 
                float2 uv : TEXCOORD0;
                float fogCoord : TEXCOORD1;
            };

            Varyings vert(Attributes input)
            {
                // DEFAULT INITIALIZATION.
                Varyings output = (Varyings)0;

                #if defined(_HIDE_OUTLINE) || defined(_ALPHA_CLIPPING)
                    return output;
                #endif

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);

                // THIS IS THE OUTLINE FROM THE CLASS,
                // WITH ONE NOTABLE CHANGE OF DISCARDING BASED ON TEXTURE.
                float4 clip = vertexInput.positionCS;
                float3 worldPos = TransformObjectToWorld(input.positionOS.xyz);

                float depth = clip.w / _LineDistance;
                float falloff = 1.0 - saturate(depth);
                float width = _OutlineWidth * falloff;

                float3 worldNormal = TransformObjectToWorldNormal(input.normalOS);
                worldPos += normalize(worldNormal) * width * clip.w;

                output.positionCS = TransformWorldToHClip(worldPos);

                // GET UNITY FOGCOORD.
                #if defined(_FOG_FRAGMENT)
                    output.fogCoord = vertexInput.positionVS.z;
                #else
                    output.fogCoord = ComputeFogFactor(vertexInput.positionCS.z);
                #endif

                return output;
            }

            half4 frag(Varyings input) : SV_TARGET
            {
                #if defined(_HIDE_OUTLINE) || defined(_ALPHA_CLIPPING)
                    discard;
                #endif

                half4 alpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a;
                clip(alpha - _AlphaThreshold);

                half outlineAmount = SAMPLE_TEXTURE2D(_OutlineMap, sampler_BaseMap, input.uv).r;
                clip(outlineAmount - _AlphaThreshold);
                
                #if defined(_FOG_FRAGMENT)
                #if (defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2))
                    float viewZ = -input.fogCoord;
                    float nearToFarZ = max(viewZ - _ProjectionParams.y, 0);
                    half fogFactor = ComputeFogFactorZ0ToFar(nearToFarZ);
                #else
                    half fogFactor = 0;
                #endif
                #else
                    half fogFactor = input.fogCoord;
                #endif

                half4 litColor = _OutlineColor;
                litColor.rgb = MixFog(litColor.rgb, fogFactor * 0.5f);
                return litColor;
            }

            ENDHLSL
        }

        // LIT PASS.
        Cull Back
        Pass
        {
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // PREPARE MACRO SOUP.
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            #pragma multi_compile_fragment _ _LIGHT_COOKIES // THIS SHADER DOESN'T SUPPORT ADDITIONAL LIGHT,
            #pragma multi_compile _ _ADDITIONAL_LIGHTS // BUT IT MIGHT IN THE FUTURE SO I LEAVE IT IN.
			#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _FORWARD_PLUS // USE _CLUSTER_LIGHT_LOOP IN UNITY 6.1 AND ABOVE.
            #pragma multi_compile_fog // DECLARE USING FOG.

            #pragma shader_feature_local _ _ALPHA_CLIPPING

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Unlit.hlsl"
 
            // UNIFORMS FROM WORLDLIGHTINGCOLORS.CS.
            half _ShadingThreshold;
            half _DiffuseBias;
            // STANDS FOR CONSTANT BUFFER,
            // IT IS USED FOR SPR-BATCHING.
            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST; // "ST" IS TILING AND OFFSET.
                half4 _SunColor; // THIS NEEDS TO BE HERE BECAUSE WITH UNIFORMS THE COLOR IS INACCURATE.
                half4 _SkyColor; 
                half4 _OutlineColor;
                float _OutlineWidth;
                float _LineDistance;
                half _AlphaThreshold;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            // TEXTURE FILTER ( REPEAT, CLAMPED, ETC ).
            SAMPLER(sampler_BaseMap);

            TEXTURE2D(_EmissionMap);
            TEXTURE2D(_ShadowMap);

            // APPDATA.
            struct Attributes
            {
                float4 positionOS : POSITION; // OBJECT SPACE.
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
            };
            
            // VERT TO FRAG.
            struct Varyings
            {
                float4 positionCS : SV_POSITION; // CLIP SPACE.
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1; // WORLD SPACE.
                float3 positionWS : TEXCOORD2;
                float fogCoord : TEXCOORD3;
            };

            Varyings vert(Attributes input)
            {
                // DEFAULT INITIALIZATION.
                Varyings output = (Varyings)0;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInput.positionCS;
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);

                // GET UNITY FOGCOORD.
                #if defined(_FOG_FRAGMENT)
                    output.fogCoord = vertexInput.positionVS.z;
                #else
                    output.fogCoord = ComputeFogFactor(vertexInput.positionCS.z);
                #endif

                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                return output;
            }

            // HALF IS FOR COLORS, FLOAT IS FOR POSITIONS.
            half4 frag(Varyings input) : SV_TARGET
            {
                half4 textureColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                #ifdef _ALPHA_CLIPPING
                    clip(textureColor.a - _AlphaThreshold); // EARLY RETURN IF CLIPPED.
                #endif
                textureColor = textureColor * _BaseColor;

                float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                
                float3 normalWS = normalize(input.normalWS);
	            half diffuse = max(dot(normalWS, normalize(mainLight.direction)), 0.0f) - _DiffuseBias;

                half totalLight = diffuse * mainLight.shadowAttenuation * SAMPLE_TEXTURE2D(_ShadowMap, sampler_BaseMap, input.uv).r;
                totalLight = step(_ShadingThreshold, totalLight); // APPLY CEL SHADING.

                half4 lightColor = totalLight * _SunColor + _SkyColor;
                lightColor = saturate(lightColor); // MAKE SURE NOT BRIGHER THAN _BASEMAP.
                half4 litColor = textureColor * lightColor;

                // GET UNITY FOGFACTOR.
                #if defined(_FOG_FRAGMENT)
                #if (defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2))
                    float viewZ = -input.fogCoord;
                    float nearToFarZ = max(viewZ - _ProjectionParams.y, 0);
                    half fogFactor = ComputeFogFactorZ0ToFar(nearToFarZ);
                #else
                    half fogFactor = 0;
                #endif
                #else
                    half fogFactor = input.fogCoord;
                #endif
 
                // APPLY FOG.
                litColor.rgb = MixFog(litColor.rgb, fogFactor);

                
                half emmisive = SAMPLE_TEXTURE2D(_EmissionMap, sampler_BaseMap, input.uv).r; 
                litColor = lerp(litColor, textureColor, emmisive);

                return litColor;
            }

            ENDHLSL
        }
        
        // HANDLE THE SHADOWS. WE CAN'T USE LIT SHADOWCASTER 
        // BECAUSE IT DOESN'T WORK WITH ALPHA CLIPPING.
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

            #pragma shader_feature_local _ _ALPHA_CLIPPING

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            float3 _LightDirection;
            float3 _LightPosition;
            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST; // "ST" IS TILING AND OFFSET.
                half4 _SunColor; // THIS NEEDS TO BE HERE BECAUSE WITH UNIFORMS THE COLOR IS INACCURATE.
                half4 _SkyColor; 
                half4 _OutlineColor;
                float _OutlineWidth;
                float _LineDistance;
                half _AlphaThreshold;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                #ifdef _ALPHA_CLIPPING
                    float2 uv : TEXCOORD0;
                #endif
            };

            struct Varyings
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

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                output.positionCS = GetShadowPositionHClip(input.positionOS.xyz, input.normalOS);
                #ifdef _ALPHA_CLIPPING
                    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                #endif
                return output;
            }

            half4 frag(Varyings input) : SV_TARGET
            {
                #ifdef _ALPHA_CLIPPING
                    clip(SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a - _AlphaThreshold);
                #endif
                return 0;
            }

            ENDHLSL
        }
    }
}
