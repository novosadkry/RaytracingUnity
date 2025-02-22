Shader "Hidden/AccumulateShader"
{
    Properties
    {
        _MainTex ("Current pass", 2D) = "white" {}
        _Accumulation ("Old pass", 2D) = "white" {}
    }

    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            sampler2D _MainTex;
            sampler2D _OldRender;
            int FrameIndex;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float4 newRender = tex2D(_MainTex, i.uv);
                float4 oldRender = tex2D(_OldRender, i.uv);

                float weight = 1.0 / (FrameIndex + 1);
                return lerp(oldRender, newRender, weight);
            }

            ENDCG
        }
    }
}
