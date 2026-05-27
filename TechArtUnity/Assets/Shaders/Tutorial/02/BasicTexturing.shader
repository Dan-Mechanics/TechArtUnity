Shader "Tutorial/BasicTexturing"
{
    Properties
    {
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _BaseTexture("Base Texture", 2D) = "white" {}
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
                "LightMode" = "SRPDefaultUnlit"
            }

            ZWrite On
            ZTest LEqual

            // THIS IS WHERE THE ACTUAL "C SHADER CODE" LIVES.
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // MEANS CONSTANT BUFFER,
            // IS FOR SPR-BATCHING.
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _BaseTexture_ST; // TILING AND OFFSET ( SCALING AND TRANSLATION ).
            CBUFFER_END

            TEXTURE2D(_BaseTexture);
            SAMPLER(sampler_BaseTexture);

            struct Attributes
            {
                // OBJECT SPACE.
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varying
            {
                // CLIP SPACE.
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Varying vert(Attributes IN)
            {
                // DEFAULT INTIALIZATION.
                Varying OUT = (Varying)0;

                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseTexture); // TILING AND OFFSET ( SCALING AND TRANSLATION ).

                return OUT;
            }

            float4 frag(Varying IN) : SV_TARGET
            {
                float4 textureColor = SAMPLE_TEXTURE2D(_BaseTexture, sampler_BaseTexture, IN.uv);
                return textureColor * _BaseColor;
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
            #pragma vertex depthOnlyVert
            #pragma fragment depthOnlyFrag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varying
            {
                float4 positionCS : SV_POSITION;
            };

            Varying depthOnlyVert(Attributes IN)
            {
                Varying OUT = (Varying)0;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                return OUT;
            }

            float depthOnlyFrag(Varying IN) : SV_TARGET
            {
                return IN.positionCS.z;
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

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varying
            {
                float4 positionCS : SV_POSITION;
                float3 normalWS : TEXCOORD0;
            };

            Varying depthNormalsVert(Attributes IN)
            {
                Varying OUT = (Varying)0;

                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(IN.normalOS);
                OUT.normalWS = NormalizeNormalPerVertex(normalWS);

                return OUT;
            }

            float4 depthNormalsFrag(Varying IN) : SV_TARGET
            {
                float3 normalWS = NormalizeNormalPerPixel(IN.normalWS);
                return float4(normalWS, 0.0f);
            }

            ENDHLSL
        }
    }
}