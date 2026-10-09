Shader "Custom/Vertex/HitExtrusion"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Tint Color", Color) = (1,1,1,1)
        _ExtrudeAmount ("Extrude Amount (膨胀强度)", Range(0, 0.5)) = 0.1
        _Frequency ("Pulse Frequency (震动频率)", Range(0, 50)) = 20.0
        _HitProgress ("Hit Progress (受击进度 0-1)", Range(0, 1)) = 0.0
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;      // 获取顶点法线
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float hitFactor : TEXCOORD1; // 传递膨胀比例给 frag 处理发光
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _Color;
            float _ExtrudeAmount;
            float _Frequency;
            float _HitProgress;

            v2f vert (appdata v)
            {
                v2f o;

                // 1. 计算受击衰减曲线：受击瞬间(Progress=0)膨胀最大，随后迅速衰减至0
                // 结合 sin 产生受击震荡弹簧感
                float pulse = sin(_HitProgress * _Frequency) * (1.0 - _HitProgress);
                float currentExtrude = pulse * _ExtrudeAmount;

                // 2. 核心：沿着顶点法线方向偏移顶点位置
                // 如果是 2D 平面且没有法线，可用 normalize(v.vertex.xyz) 替代 v.normal
                v.vertex.xyz += v.normal * currentExtrude;

                // 3. 转换到裁剪空间
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.hitFactor = saturate(pulse); // 用于传给 frag 做闪白
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv) * _Color;
                return col;
            }
            ENDCG
        }
    }
}