Shader "Custom/PostProcess/Grayscale"
{   
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        ZWrite Off Cull Off
        Pass
        {
            Name "Grayscale"

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            
            #pragma vertex Vert
            #pragma fragment Frag

            CBUFFER_START(UnityPerMaterial)
                float _Intensity;
            CBUFFER_END

            float4 Frag (Varyings input) : SV_Target
            {
                float4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord).rgba;
                
                // BT.709 luma coefficients
                half luma = dot(color.rgb, half3(.2126, .7152, .0722));
                color.rgb = lerp(color.rgb, half3(luma, luma, luma), _Intensity);
                
                return color;
            }
            
            ENDHLSL
        }

        UsePass "Custom/PostProcess/GrabPass/GrabPass"
    }
}
