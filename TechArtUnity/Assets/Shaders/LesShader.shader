Shader "Custom/LesShader"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        _LightRamp("Light Ramp", 2D) = "white" {}
        _AmbientOffset("Light Ramp Ambient Offset", Range(0,1)) = 0
    }

    SubShader
    {
        Tags {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }

        /* IETS * src + IETS * dst */
        
        // Additive
        // Blend One One

        // Soft Additive
        // Blend One OneMinusSrcColor

        // Multiply
        // Blend DstColor Zero

        // Double Multiply
        // Blend DstColor SrcColor

        // Alpha Blending
        // Blend SrcAlpha OneMinusSrcAlpha

        Cull Front

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" // Lighting & Shadows
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float3 normal       : NORMAL;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            TEXTURE2D(_LightRamp);
            SAMPLER(sampler_LightRamp);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;
            CBUFFER_END

            float _AmbientOffset;

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                // Object Space Animation
                float3 pos = IN.positionOS.xyz;

                // pos.y += sin(_Time.y + pos.x * 4);

                // World Space
                float3 worldPos = TransformObjectToWorld(pos);

                float waveCount = 4;
                float amplitude = .15;
                float offset = pos.x;

                float3 worldNormal = TransformObjectToWorldNormal(IN.normal);


                float4 clipPos = TransformWorldToHClip(worldPos);

                // world space animation
                worldPos += worldNormal * 0.1 * clipPos.w; // sin(_Time.y + offset * waveCount) * amplitude;

                
                OUT.positionHCS = clipPos;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                return float4(0,0,0,1);
            }
            ENDHLSL
        }

        Cull Back

        Pass
        {
            Tags { "LightMode"="UniversalForward" }

            Name "MyAmazingPass"
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" // Lighting & Shadows
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float3 normal       : NORMAL;
                float2 uv           : TEXCOORD0;
                float4 screenPos    : TEXCOORD1;
                float3 worldPos     : TEXCOORD2;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            TEXTURE2D(_LightRamp);
            SAMPLER(sampler_LightRamp);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;
            CBUFFER_END

            float _AmbientOffset;

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                // Object Space Animation
                float3 pos = IN.positionOS.xyz;

                // pos.y += sin(_Time.y + pos.x * 4);

                // World Space
                float3 worldPos = TransformObjectToWorld(pos);

                float waveCount = 4;
                float amplitude = .15;
                float offset = pos.x;

                float3 worldNormal = TransformObjectToWorldNormal(IN.normal);

                // world space animation
                // worldPos += worldNormal * sin(_Time.y + offset * waveCount) * amplitude;

                float4 clipPos = TransformWorldToHClip(worldPos);
                float4 screenPos = ComputeScreenPos(clipPos);

                OUT.worldPos = worldPos;
                OUT.screenPos = screenPos;
                OUT.normal = worldNormal;
                OUT.positionHCS = clipPos;
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float2 screenUV = IN.screenPos.xy / IN.screenPos.w;

                float3 worldNormal = pow(normalize(IN.normal), 16);
                worldNormal /= worldNormal.x + worldNormal.y + worldNormal.z;

                half4 xySample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.worldPos.xy) * _BaseColor;
                half4 xzSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.worldPos.xz) * _BaseColor;
                half4 zySample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.worldPos.zy) * _BaseColor;

                half4 color = xySample * worldNormal.z + xzSample * worldNormal.y + zySample * worldNormal.x;

                // clip(color.a - 0.5);
                //  Doet dit:
                //if ( color.a - 0.5 < 0 )
                //    discard;

                // Dot Product Lighting
                Light mainLight = GetMainLight();
                float light = dot(mainLight.direction, IN.normal) * .5 + .5 + _AmbientOffset;

                float rampV = dot(IN.normal, normalize(GetWorldSpaceViewDir(IN.worldPos))) * .5 + .5;

                half4 lightRamp = SAMPLE_TEXTURE2D(_LightRamp, sampler_LightRamp, float2(light + sin(_Time.y + rampV * .25) * .025, rampV + frac(_Time.x)));
                

                return color * float4(max( lightRamp.rgb, .05) * light, 1);
            }
            ENDHLSL
        }

        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}
