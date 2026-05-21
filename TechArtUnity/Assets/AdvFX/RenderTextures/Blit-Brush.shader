Shader "Custom/Blit-Brush"
{
    Properties
    {
        _BrushTex    ("Brush",      2D)       = "black" {}
        _BrushUV     ("Brush Pos",  Vector)    = (0, 0, 0, 0)
        _BrushSize   ("Brush Size", Float)    = 0.05
        _BrushColor  ("Brush Color", Color)   = (1, 1, 1, 1)
        _Hardness    ("Hardness",   Range(0,1)) = 0.8
        _StampBias   ("StampBias", Range(0.01,0.5)) = 0.1
    }

    SubShader
    {
        // No culling or depth — we're writing to a 2D render texture
        Tags { "RenderType" = "Opaque"
               "RenderPipeline" = "UniversalPipeline" }
        Cull Off  ZWrite Off  ZTest Always

        Pass
        {
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            // Required SRP Blit includes
            #pragma vertex   Vert
            #pragma fragment Frag
            
            TEXTURE2D(_BrushTex);
            SAMPLER(sampler_BrushTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _BrushPos;      // xy = normalised screen pos (0-1)
                float  _BrushSize;    // radius in UV space
                float4 _BrushColor;
                float  _Hardness;     // 0 = soft feather, 1 = hard edge
                float _StampBias;
            CBUFFER_END

            half4 Frag(Varyings input) : SV_Target
            {
                float2 uv      = input.texcoord;
                // Sample the source
                half4  canvas  = SAMPLE_TEXTURE2D_X(_BlitTexture,
                                      sampler_LinearClamp, uv);

                // Distance from brush centre in UV space
                float2 delta   = uv - _BrushPos.xy;
                float  dist    = length(delta) / max(_BrushSize, 0.0001); // prevent divide by 0 or negative

                // Brush mask: smooth circle with hardness control
                float  edge    = lerp(0.5, 0.99, _Hardness);
                float  mask    = 1.0 - smoothstep(edge - 0.01, 1.0, dist);

                // Multiply by brush texture for custom stamp shapes
                float2 brushUV = (delta / _BrushSize) * 0.5 + 0.5;
                half4  stamp   = SAMPLE_TEXTURE2D(_BrushTex, sampler_BrushTex, brushUV);

                // 1 - stamp.r if brush is inverted
                mask *= saturate( stamp.r - _StampBias );   // bias to prevent bleeding

                // Alpha-composite brush colour onto the existing canvas
                half4 result = lerp(canvas, _BrushColor,
                                     mask * _BrushColor.a);

                return result;
            }
            ENDHLSL
        }
    }
}