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

    // TODO: add fog, add emmision, possibly add specualr thing
    SubShader
    {
        Tags {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }

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
                OUT.screenPos = ComputeScreenPos(clip);
                //OUT.screenPos = ComputeScreenPos(OUT.positionHCS);
                return OUT;
            }
            
            float near = 0.1f;
            float far = 100.0f;
            
            float linearizeDepth(float depth)
            {
            	return (2.0 * near * far) / (far + near - (depth * 2.0 - 1.0) * (far - near));
            }
            
            float logisticDepth(float depth, float steepness, float offset)
            {
            	float zVal = linearizeDepth(depth);
            	return (1 / (1 + exp(-steepness * (zVal - offset))));
            }
            
            half4 frag(Varyings IN) : SV_Target
            {
                //half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.worldPos.xy ) * _BaseColor;
                half4 texColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
                clip(texColor.a - 0.5);

                float4 shadowCoord = TransformWorldToShadowCoord(IN.worldPos);
                Light mainLight = GetMainLight(shadowCoord);
                
                float3 normal = normalize(IN.normal);
	            float diffuse = max(dot(normal, normalize(mainLight.direction)), 0.0f) + _Offset;

                float light = diffuse * mainLight.shadowAttenuation;
                light = step(_Threshold, light);
                half4 lightColor = light * _SunColor + _AmbientColor;
                lightColor = min(lightColor, 1.0f);

                half4 col = texColor * lightColor;
                float depth = logisticDepth(IN.screenPos.z, 0.22f, 78.0f);
                return lerp(col, _AmbientColor, 0.0f);
            }
            
            ENDHLSL
        }

        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}
