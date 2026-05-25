Shader "Tutorial/Silhouette"
{
	Properties
	{
		_ForegroundColor("Foreground Color", Color) = (0, 0, 0, 1)
		_BackgroundColor("Background Color", Color) = (1, 1, 1, 1)

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
            // THIS IS WHERE THE ACTUAL "C SHADER CODE" LIVES.
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

			// SRP-BATCHER COMPATIBILITY, CONSTANT BUFFER.
			CBUFFER_START(UnityPerMaterial)
				float4 _ForegroundColor;
				float4 _BackgroundColor;
			CBUFFER_END

			struct Attributes
			{
				// OBJECT SPACE.
				float4 positionOS : POSITION;

				// SCREEN SPACE.
				float4 positionSS : TEXCOORD0;
			};

			struct Varyings
			{
				// CLIP SPACE.
				float4 positionCS : SV_POSITION;

				// SCREEN SPACE.
				float4 positionSS : TEXCOORD0;
			};

			Varyings vert(Attributes IN)
			{
				// INITIALIZE TO DEFAULT.
				Varyings OUT = (Attributes)0;

				OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
				OUT.positionSS = ComputeScreenPos(OUT.positionCS);

				return OUT;
			}

            float linearizeDepth(float depth)
            {
            	float near = 0.1f;
            	float far = 100.0f;
				return (2.0f * near * far) / (far + near - (depth * 2.0f - 1.0f) * (far - near));
            }
            
            float logisticDepth(float depth, float steepness, float offset)
            {
            	float zVal = linearizeDepth(depth);
            	return (1.0f / (1.0f + exp(-steepness * (zVal - offset))));
            }

			float4 frag(Varyings IN) : SV_TARGET
			{
				float2 screenUv = IN.positionSS.xy / IN.positionSS.w;
				float rawDepth = SampleSceneDepth(screenUv);
				// float depth = logisticDepth(rawDepth, 0.22f, 78.0f);
				return lerp(_ForegroundColor, _BackgroundColor, rawDepth);
			}

			ENDHLSL
		}
	}
}