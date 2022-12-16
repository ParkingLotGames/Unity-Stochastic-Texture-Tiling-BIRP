Shader "UnTilerable BIRP"
{
    Properties
    {
    _MainTex("RGB 01", 2D) = "white" {}
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }

        Pass
        {
            // Name "Universal Forward"
            // Tags {"LightMode" = "UniversalForward"}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #pragma glsl
            #pragma optimize 3

            #include "UnityCG.cginc"

            // #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct VertexInput
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct VertexOutput
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1;
            };

            float4 _MainTex_ST;
            sampler2D _MainTex;

            VertexOutput vert(VertexInput v)
            {
                VertexOutput o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                return o;
            }

            float4 hash4fast(float2 gridcell)
            {
                const float2 OFFSET = float2(26.0, 161.0);
                const float DOMAIN = 71.0;
                const float SOMELARGEFIXED = 951.135664;
                float4 P = float4(gridcell.xy, gridcell.xy + 1);
                P = frac(P * (1 / DOMAIN)) * DOMAIN;
                P += OFFSET.xyxy;
                P *= P;
                return frac(P.xzxz * P.yyww * (1 / SOMELARGEFIXED));
            }

            inline float3 textureNoTile(sampler2D samp, in float2 uv)
            {
                float2 iuv = floor(uv);
                float2 fuv = frac(uv);

                // generate per-tile transform
                float4 ofa = hash4fast(iuv + float2(0, 0));
                float4 ofb = hash4fast(iuv + float2(1, 0));
                float4 ofc = hash4fast(iuv + float2(0, 1));
                float4 ofd = hash4fast(iuv + float2(1, 1));

                float2 dx = ddx(uv);
                float2 dy = ddy(uv);

                // transform per-tile uvs
                ofa.zw = sign(ofa.zw - 0.5);
                ofb.zw = sign(ofb.zw - 0.5);
                ofc.zw = sign(ofc.zw - 0.5);
                ofd.zw = sign(ofd.zw - 0.5);            

                // uv's, and derivatives (for correct mipmapping)
                float2 uva = ofa.zw * fuv.xy + ofa.xy;
                float2 uvb = ofb.zw * fuv.xy + ofb.xy;
                float2 uvc = ofc.zw * fuv.xy + ofc.xy;
                float2 uvd = ofd.zw * fuv.xy + ofd.xy;          

                float2 ddx_uva = ofa.zw * dx + (ofb.zw - ofa.zw) * fuv.x;
                float2 ddx_uvb = ofb.zw * dx + (ofb.zw - ofa.zw) * fuv.x;
                float2 ddx_uvc = ofc.zw * dx + (ofd.zw - ofc.zw) * fuv.x;
                float2 ddx_uvd = ofd.zw * dx + (ofd.zw - ofc.zw) * fuv.x;           

                float2 ddy_uva = ofa.zw * dy + (ofc.zw - ofa.zw) * fuv.y;
                float2 ddy_uvb = ofb.zw * dy + (ofd.zw - ofb.zw) * fuv.y;
                float2 ddy_uvc = ofc.zw * dy + (ofc.zw - ofa.zw) * fuv.y;
                float2 ddy_uvd = ofd.zw * dy + (ofd.zw - ofb.zw) * fuv.y;           

                // sample
                float4 tex00 = tex2Dlod(_MainTex, float4(uva, 0, 0));
                float4 tex10 = tex2Dlod(_MainTex, float4(uvb, 0, 0));
                float4 tex01 = tex2Dlod(_MainTex, float4(uvc, 0, 0));
                float4 tex11 = tex2Dlod(_MainTex, float4(uvd, 0, 0));           

                // weight samples
                float4 tex0 = lerp(tex00, tex01, fuv.y);
                float4 tex1 = lerp(tex10, tex11, fuv.y);
                float4 tex = lerp(tex0, tex1, fuv.x);           

                // these lines return an error idk why, maybe require a SRP feature 
                // correct mipmapping
                // #if !defined(UNITY_NO_DXT5nm) && !defined(UNITY_NO_RGBM)
                // tex.rgb = DecodeHDR(tex, _MainTex);
                // #endif
                tex.rgb = tex.rgb * tex.a + tex.rgb * tex.rgb * (1 - tex.a);            

                return tex.rgb;
                }

                float4 frag(VertexOutput i) : SV_TARGET
                {
                return float4(textureNoTile(_MainTex, i.uv).rgb, 1);
                }

            ENDCG
        }
    }
}
