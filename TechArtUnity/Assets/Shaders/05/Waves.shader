Shader "Tutorial/Waves"
{
	Properties
	{
		_BaseColor("Base Color", Color) = (1, 1, 1, 1)
		_BaseTexture("Base Texture", 2D) = "white" {}
		[Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Source Blend Mode", Integer) = 5
		[Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Destination Blend Mode", Integer) = 10
		_WaveHeigth("Wave Height", Range(0.0, 1.0)) = 0.25
		_WaveSpeed("Wave Speed", Range(0.0, 10.0)) = 1.0
	}
	
	SubShader
	{
		Tags
		{
			"RenderPipeline" = "UniversalPipeline"
			"RenderType" = "Transparent"
			"Queue" = "Transparent"
		}

		Pass
		{
			Blend [_SrcBlend] [_DstBlend]
			ZWrite Off

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
				float _WaveHeigth;
				float _WaveSpeed;
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
				Varyings OUT = (Varyings)0;

				float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
				float waveHeigth = sin(positionWS.x + positionWS.z + _Time.y * _WaveSpeed) * _WaveHeigth;
				float3 newPositionWS = float3(positionWS.x, positionWS.y + waveHeigth, positionWS.z);

				OUT.positionCS = TransformWorldToHClip(newPositionWS);



				// APPLY TILING AND OFFSET.
				OUT.uv = TRANSFORM_TEX(IN.uv, _BaseTexture);
				
				return OUT;
			}

			float4 frag(Varyings IN) : SV_TARGET
			{
				float4 textureColor = SAMPLE_TEXTURE2D(_BaseTexture, sampler_BaseTexture, IN.uv);
				return textureColor * _BaseColor;
			}

			ENDHLSL
		}
	}
}