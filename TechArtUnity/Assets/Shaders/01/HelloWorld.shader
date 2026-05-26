Shader "Tutorial/HelloWorld"
{
	Properties
	{
		_BaseColor("Base Color", Color) = (1, 1, 1, 1)
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
			// THIS IS WHERE THE ACTUAL "C SHADER CODE" LIVES.
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
		
			float4 _BaseColor;

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

			Varyings vert(Attributes IN)
			{
				// INITIALIZE TO DEFAULT.
				Varyings OUT = (Varyings)0;

				OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
				return OUT;
			}

			float4 frag(Varyings IN) : SV_TARGET
			{
				return _BaseColor;
			}

			ENDHLSL
		}
	}
}