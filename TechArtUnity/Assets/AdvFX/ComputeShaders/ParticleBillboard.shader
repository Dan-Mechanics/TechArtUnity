// ParticleBillboard.shader
// URP unlit billboard shader.
// Each particle is rendered as a camera-facing quad.
// The fragment shader clips to a circle and tints by mass.

Shader "Custom/ParticleBillboard"
{
    Properties
    {
        _CoreColor   ("Core colour",  Color) = (1, 0.85, 0.4, 1)
        _RimColor    ("Rim colour",   Color) = (0.2, 0.5, 1.0, 1)
    }

    SubShader
    {
        Tags
        {
            "RenderType"      = "Transparent"
            "Queue"           = "Transparent"
            "RenderPipeline"  = "UniversalPipeline"
            "IgnoreProjector" = "True"
        }

        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off

        Pass
        {
            Name "ParticleBillboard"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // Per-instance data from the structured buffer
            struct Particle
            {
                float3 position;
                float3 velocity;
                float  mass;
                float  _pad;
            };

            StructuredBuffer<Particle> _Particles;

            // Uniforms set from C#
            float  _MassScale;          // radius = sqrt(mass) * _MassScale
            float  _MaxMass;            // used to normalise colour

            CBUFFER_START(UnityPerMaterial)
                float4 _CoreColor;
                float4 _RimColor;
            CBUFFER_END

            struct Attributes
            {
                float3 positionOS : POSITION;   // quad vertex in [-0.5, 0.5]
                float2 uv         : TEXCOORD0;
                uint instanceID   : SV_InstanceID;
                // Causes issue, but is present in the tutorial video (???)
                // UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                float  mass       : TEXCOORD1;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                float3 worldPos;
                float  radius;
                float  mass;
                float  planet;

                // Particle instances
                Particle p = _Particles[IN.instanceID];
                worldPos = p.position;
                radius   = sqrt(p.mass) * _MassScale;
                mass     = p.mass;

                // Billboard: offset the quad vertex in camera right/up
                float3 camRight = UNITY_MATRIX_V[0].xyz;
                float3 camUp    = UNITY_MATRIX_V[1].xyz;

                float3 vertexWorld = worldPos
                    + camRight * IN.positionOS.x * radius * 2.0
                    + camUp    * IN.positionOS.y * radius * 2.0;

                OUT.positionCS = TransformWorldToHClip(vertexWorld);
                OUT.uv         = IN.uv;
                OUT.mass       = mass;
                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                // UV in [-1, 1]; clip outside circle
                float2 centered = IN.uv * 2.0 - 1.0;
                float  dist     = length(centered);
                clip(1.0 - dist);           // discard outside circle

                // Soft edge
                float alpha = smoothstep(1.0, 0.85, dist);

                // Colour: lerp from core to rim, planet gets its own colour
                float  t      = saturate(IN.mass / _MaxMass);
                float4 color  = lerp(_CoreColor, _RimColor, dist);

                // Bright centre highlight
                float highlight = smoothstep(0.6, 0.0, dist) * 0.4;
                color.rgb += highlight;

                color.a *= alpha;
                return color;
            }
            ENDHLSL
        }
    }
}
