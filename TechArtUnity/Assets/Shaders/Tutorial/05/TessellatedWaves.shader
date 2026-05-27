Shader "Tutorial/TessellatedWaves"
{
	Properties
	{
		_BaseColor("Base Color", Color) = (1, 1, 1, 1)
		_BaseTexture("Base Texture", 2D) = "white" {}
		[Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Source Blend Mode", Integer) = 5
		[Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Destination Blend Mode", Integer) = 10
		_WaveHeigth("Wave Height", Range(0.0, 1.0)) = 0.25
		_WaveSpeed("Wave Speed", Range(0.0, 10.0)) = 1.0
		_TessellationAmount("Tessellation Amount", Range(1.0, 64.0)) = 1.0
		_TessellationFadeStart("Tessellation Fade Start", Float) = 25
		_TessellationFadeEnd("Tessellation Fade End", Float) = 50
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
			#pragma hull hull
			#pragma domain domain
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			// SRP-BATCHER COMPATIBILITY, CONSTANT BUFFER.
			CBUFFER_START(UnityPerMaterial)
				float4 _BaseColor;
				// TILING AND OFFSET ( SCALING AND TRANSLATION ).
				float4 _BaseTexture_ST;
				float _WaveHeigth;
				float _WaveSpeed;
				float _TessellationAmount;
				float _TessellationFadeStart;
				float _TessellationFadeEnd;
			CBUFFER_END

			TEXTURE2D(_BaseTexture);
			SAMPLER(sampler_BaseTexture);

			struct Attributes
			{
				// OBJECT SPACE.
				float4 positionOS : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct TessControlPoint
			{
				float3 positionWS : INTERNALTESSPOS;
				float2 uv : TEXCOORD0;
			};

			struct TessFactors
			{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			struct Varyings
			{
				// CLIP SPACE.
				float4 positionCS : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

			TessControlPoint vert(Attributes IN)
			{
				// INITIALIZE TO DEFAULT.
				TessControlPoint OUT = (TessControlPoint)0;

				OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
				OUT.uv = TRANSFORM_TEX(IN.uv, _BaseTexture);
				
				return OUT;
			}

			[domain("tri")]
			[outputcontrolpoints(3)]
			[outputtopology("triangle_cw")]
			[partitioning("integer")]
			[patchconstantfunc("patchConstantFunc")]
			TessControlPoint hull(InputPatch<TessControlPoint, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}

			TessFactors patchConstantFunc(InputPatch<TessControlPoint, 3> patch)
			{
				TessFactors OUT = (TessFactors)0;
				float3 triPos0 = patch[0].positionWS;
				float3 triPos1 = patch[1].positionWS;
				float3 triPos2 = patch[2].positionWS;

				float3 edgePos0 = 0.5f * (triPos1 + triPos2);
				float3 edgePos1 = 0.5f * (triPos0 + triPos2);
				float3 edgePos2 = 0.5f * (triPos0 + triPos1);

				float3 camPos = _WorldSpaceCameraPos;
				float dist0 = distance(edgePos0, camPos);
				float dist1 = distance(edgePos1, camPos);
				float dist2 = distance(edgePos2, camPos);

				float fadeDist = _TessellationFadeEnd - _TessellationFadeStart;
				float edgeFactor0 = saturate(1.0f - (dist0 - _TessellationFadeStart) / fadeDist);
				float edgeFactor1 = saturate(1.0f - (dist1 - _TessellationFadeStart) / fadeDist);
				float edgeFactor2 = saturate(1.0f - (dist2 - _TessellationFadeStart) / fadeDist);

				// ALWAYS AT LEAST ONE ( MAX ).
				OUT.edge[0] = max(edgeFactor0 * _TessellationAmount, 1);
				OUT.edge[1] = max(edgeFactor1 * _TessellationAmount, 1);
				OUT.edge[2] = max(edgeFactor2 * _TessellationAmount, 1);

				OUT.inside = (OUT.edge[0] + OUT.edge[1] + OUT.edge[2]) / 3.0f;

				return OUT;
			}

			[domain("tri")]
			Varyings domain(TessFactors factors, OutputPatch<TessControlPoint, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
			{
				Varyings OUT = (Varyings)0;
				float3 positionWS = 
					patch[0].positionWS * barycentricCoordinates.x +
					patch[1].positionWS * barycentricCoordinates.y +
					patch[2].positionWS * barycentricCoordinates.z;

				float2 uv = 
					patch[0].uv * barycentricCoordinates.x +
					patch[1].uv * barycentricCoordinates.y +
					patch[2].uv * barycentricCoordinates.z;

				// ADD WAVES.
				float waveHeight = sin(positionWS.x + positionWS.z + _Time.y * _WaveSpeed) * _WaveHeigth;
				float3 newPositionWS = float3(positionWS.x, positionWS.y + waveHeight, positionWS.z);

				OUT.positionCS = TransformWorldToHClip(newPositionWS);
				OUT.uv = uv;

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