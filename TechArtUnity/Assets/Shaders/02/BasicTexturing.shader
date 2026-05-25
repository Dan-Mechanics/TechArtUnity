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
                "LightMode" = "SPRDefaultUnlit"
            }
            
            ZWrite On
            ZTest LEqual

            // THIS IS WHERE THE ACTUAL "C SHADER CODE" LIVES.
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			
			// SRP-BATCHER COMPATIBILITY, CONSTANT BUFFER.
			CBUFFER_START(UnityPerMaterial)
				float4 _BaseColor;
				// TILING AND OFFSET ( SCALING AND TRANSLATION ).
				float4 _BaseTexture_ST;
			CBUFFER_END

			TEXTURE2D(_BaseTexture);
			SAMPLER(sampler_BaseTexture);

			struct Attributes
			{
				// OBJECT SPACE.
				float4 positionOS : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct Varyings
			{
				// CLIP SPACE.
				float4 positionCS : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

			Varyings vert(Attributes IN)
			{
				// INITIALIZE TO DEFAULT.
				Varyings OUT = (Attributes)0;

				// APPLY TILING AND OFFSET.
				OUT.uv = TRANSFORM_TEX(IN.uv, _BaseTexture);
				OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
				return OUT;
			}

			float4 frag(Varyings IN) : SV_TARGET
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

            ZWrite ON
            ColorMask R

            HLSLPROGRAM

            #pragma vertex depthOnlyVert
            #pragma fragment depthOnlyFrag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
			{
				// OBJECT SPACE.
				float4 positionOS : POSITION;
            };

			struct Varyings
			{
				// CLIP SPACE.
				float4 positionCS : SV_POSITION;
			};

			Varyings depthOnlyVert(Attributes IN)
			{
				// INITIALIZE TO DEFAULT.
				Varyings OUT = (Attributes)0;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);     
				return OUT;
			}

			float depthOnlyFrag(Varyings IN) : SV_TARGET
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

            ZWrite ON
            HLSLPROGRAM

            #pragma vertex depthNormalsVert
            #pragma fragment depthNormalsFrag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
			{
				// OBJECT SPACE.
				float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };
            
			struct Varyings
			{
				// CLIP SPACE.
				float4 positionCS : SV_POSITION;
                float3 normalsWS : TEXCOORD0;
			};

			Varyings depthNormalsVert(Attributes IN)
			{
				// INITIALIZE TO DEFAULT.
				Varyings OUT = (Attributes)0;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);     
                float3 normalsWS = TransformObjectToWorldNormal(IN.normalOS);
                OUT.normalsWS = NormalizeNormalPerVertex(normalsWS);
				return OUT;
			}

			float4 depthNormalsFrag(Varyings IN) : SV_TARGET
			{
				float3 normalsWS = NormalizeNormalPerPixel(IN.normalsWS);
                return float4(normalsWS, 0.0f);
			}

            ENDHLSL
        }
	}
}