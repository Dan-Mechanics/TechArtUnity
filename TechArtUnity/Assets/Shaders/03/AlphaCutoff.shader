Shader "Tutorial/AlphaCutoff"
{
	Properties
	{
		_BaseColor("Base Color", Color) = (1, 1, 1, 1)
		_BaseTexture("Base Texture", 2D) = "white" {}
		_AlphaThreshold("Alpha Threshold", Range(0.0, 1.0)) = 0.5
	}
	
	SubShader
	{
		Tags
		{
			"RenderPipeline" = "UniversalPipeline"
			"RenderType" = "Transparent"
			"Queue" = "AlphaTest"
		}

		Pass
		{
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
				float _AlphaThreshold;
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
				clip(textureColor.a - _AlphaThreshold);
				return textureColor;
			}

			ENDHLSL
		}

		UsePass "Universal Render Pipeline/Lit/ShadowCaster"
	}
}