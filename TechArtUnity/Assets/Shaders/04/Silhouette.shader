Shader "Tutorial/Silhouette"
{
    Properties
    {
        _ForegroundColor("Foreground Color", Color) = (0, 0, 0, 0)
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
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _ForegroundColor;
                float4 _BackgroundColor;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varying
            {
                float4 positionCS : SV_POSITION;
                float4 positionSS : TEXCOORD0;
            };

            Varying vert(Attributes IN)
            {
                Varying OUT = (Varying)0;

                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.positionSS = ComputeScreenPos(OUT.positionCS);

                return OUT;
            }

            float4 frag(Varying IN) : SV_TARGET
            {
                float2 screenUV = IN.positionSS.xy / IN.positionSS.w;
                float rawDepth = SampleSceneDepth(screenUV);
                float linearDepth = Linear01Depth(rawDepth, _ZBufferParams);

                return lerp(_ForegroundColor, _BackgroundColor, linearDepth);
            }

            ENDHLSL
        }
    }
}