Shader "Custom/Vertex/PaperCurl_20x20Plane"
{
    Properties
    {
        _MainTex ("Main Texture (正面贴图)", 2D) = "white" {}
        _BackTex ("Back Texture (背面贴图)", 2D) = "white" {}
        _Progress ("Curl Progress (卷曲进度 0-1.2)", Range(0, 1.2)) = 0.0
        _Radius ("Curl Radius (卷曲半径)", Range(0.1, 3.0)) = 1.0
        _Angle ("Curl Angle (卷曲角度)", Range(-45, 45)) = 0.0
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        
        // 双面渲染，确保翻起后能看到背面
        Cull Off

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
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            sampler2D _BackTex;
            float _Progress;
            float _Radius;
            float _Angle;

            v2f vert (appdata v)
            {
                v2f o;
                float3 localPos = v.vertex.xyz;

                // 1. 角度转换为 XZ 平面上的方向向量
                float rad = radians(_Angle);
                float2 dir = float2(cos(rad), sin(rad));

                // 2. 基于 UV (0~1) 和生成的 10x10 Plane 尺寸计算实际卷曲距离
                float planeSize = 10.0;
                float dist = (dot(v.uv, dir) - _Progress) * planeSize;

                // 3. 超过卷曲轴线的顶点进行圆柱形弯曲
                if (dist > 0.0)
                {
                    float theta = dist / _Radius;

                    float deltaDist = dist - _Radius * sin(theta);
                    float height = _Radius * (1.0 - cos(theta));

                    // 【核心修正】：在 XZ 平面上卷缩，沿 Y 轴向上抬高
                    localPos.xz -= dir * deltaDist;
                    localPos.y += height;
                }

                o.vertex = UnityObjectToClipPos(float4(localPos, 1.0));
                o.uv = v.uv;
                return o;
            }

            // 【核心修正】：使用 SV_IsFrontFace 由 GPU 硬件精准判断正背面
            fixed4 frag (v2f i, bool isFrontFace : SV_IsFrontFace) : SV_Target
            {
                if (isFrontFace)
                {
                    return tex2D(_MainTex, i.uv);
                }
                else
                {
                    // 背面采样 (镜像 UV)
                    float2 backUV = float2(1.0 - i.uv.x, i.uv.y);
                    return tex2D(_BackTex, backUV);
                }
            }
            ENDCG
        }
    }
}