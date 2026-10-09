Shader "Custom/2D/WaterDistortion"
{
    Properties
    {
        [PerRendererData] _MainTex ("Sprite Texture", 2D) = "white" {}
        _Color ("Tint", Color) = (1,1,1,1)

        [Header(Distortion Settings)]
        _SpeedX ("Speed X (Horizontal)", Range(-10, 10)) = 2.0
        _SpeedY ("Speed Y (Vertical)", Range(-10, 10)) = 1.0
        _Frequency ("Wave Frequency", Range(0, 50)) = 12.0
        _Strength ("Distortion Strength", Range(0, 0.1)) = 0.02
    }

    SubShader
    {
        Tags
        {
            "Queue"="Transparent"
            "IgnoreProjector"="True"
            "RenderType"="Transparent"
            "PreviewType"="Plane"
            "CanUseSpriteAtlas"="True"
        }

        Cull Off
        Lighting Off
        ZWrite Off
        Blend One OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex   : POSITION;
                float4 color    : COLOR;
                float2 texcoord : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex   : SV_POSITION;
                fixed4 color    : COLOR;
                float2 texcoord : TEXCOORD0;
            };

            sampler2D _MainTex;
            fixed4 _Color;

            float _SpeedX;
            float _SpeedY;
            float _Frequency;
            float _Strength;

            v2f vert(appdata IN)
            {
                v2f OUT;
                OUT.vertex = UnityObjectToClipPos(IN.vertex);
                OUT.texcoord = IN.texcoord;
                OUT.color = IN.color * _Color;
                return OUT;
            }

            fixed4 frag(v2f IN) : SV_Target
            {
                float2 uv = IN.texcoord;

                // 1. 获取 Unity 内置时间变量 (_Time.y 代表以秒为单位的时间)
                float time = _Time.y;

                // 2. 利用正弦波 (sin) 和余弦波 (cos) 计算 UV 坐标的偏移量
                // X 轴的偏移量取决于 Y 坐标和时间，产生横向 S 型水波
                float offsetX = sin(uv.y * _Frequency + time * _SpeedX) * _Strength;
                // Y 轴的偏移量取决于 X 坐标和时间，补充纵向轻微起伏
                float offsetY = cos(uv.x * _Frequency + time * _SpeedY) * _Strength;

                // 3. 将偏移量叠加到原始 UV 坐标上
                float2 distortedUV = uv + float2(offsetX, offsetY);

                // 4. 使用扭曲后的 UV 采样精灵贴图
                fixed4 c = tex2D(_MainTex, distortedUV) * IN.color;

                // 5. 2D Sprite 预乘透明度处理
                c.rgb *= c.a;

                return c;
            }
            ENDCG
        }
    }
}