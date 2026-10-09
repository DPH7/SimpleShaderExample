Shader "Custom/Shatter/3DPotShatter"
{
    Properties
    {
        _MainTex ("Outer Texture (罐子外壁贴图)", 2D) = "white" {}
        _Color ("Outer Tint", Color) = (1,1,1,1)
        _InnerColor ("Inner Clay Color (内壁陶土颜色)", Color) = (0.4, 0.25, 0.15, 1)
        _Progress ("Shatter Progress (打碎进度)", Range(0, 1)) = 0.0
        _ImpactPoint ("Hit Point WorldPos (击中世界坐标)", Vector) = (0,0,0,0)
        _ShardDensity ("Shard Density (碎片粗细:越小碎片越大)", Range(0.5, 10)) = 2.5
        _ExplosionForce ("Explosion Force (爆炸冲击力)", Float) = 4.0
        _Gravity ("Gravity (重力)", Float) = 8.0
        _SpinSpeed ("3D Spin Speed (旋转翻滚速度)", Float) = 12.0
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        Cull Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag
            #pragma target 4.0
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2g
            {
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
            };

            struct g2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
            };

            sampler2D _MainTex;
            fixed4 _Color;
            fixed4 _InnerColor;
            float _Progress;
            float4 _ImpactPoint;
            float _ShardDensity;
            float _ExplosionForce;
            float _Gravity;
            float _SpinSpeed;

            float rand(float3 seed)
            {
                return frac(sin(dot(seed, float3(12.9898, 78.233, 45.543))) * 43758.5453);
            }

            float3 rotateVector(float3 pos, float3 axis, float angle)
            {
                float cosA = cos(angle);
                float sinA = sin(angle);
                return pos * cosA + cross(axis, pos) * sinA + axis * dot(axis, pos) * (1.0 - cosA);
            }

            v2g vert (appdata v)
            {
                v2g o;
                o.vertex = v.vertex;
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.uv = v.uv;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            [maxvertexcount(3)]
            void geom(triangle v2g IN[3], inout TriangleStream<g2f> stream)
            {
                // 1. 三角形质心与法线
                float3 triCenter = (IN[0].worldPos + IN[1].worldPos + IN[2].worldPos) / 3.0;
                float3 triNormal = normalize(IN[0].normal + IN[1].normal + IN[2].normal);

                // 2. 3D 空间区块分组：将相近的三角形组合成大块陶片
                float3 cellID = floor(triCenter * _ShardDensity);
                float cellRand = rand(cellID); // 块的唯一随机特征
                float3 shardCenter = (cellID + 0.5) / _ShardDensity;

                // 3. 爆炸受击方向计算
                float3 hitDir = shardCenter - _ImpactPoint.xyz;
                float dist = length(hitDir);
                hitDir = dist < 0.001 ? triNormal : normalize(hitDir);

                // 爆炸混合矢量：受击点向外推力 + 面法线向外推力
                float3 explodeDir = normalize(hitDir * 0.7 + triNormal * 0.3);

                // 4. 碎片区分度设置：
                // 靠近击中点的碎片受力更大、飞得更快；远处的碎片块受力较小，呈沉重下落状
                float distanceAtten = saturate(1.5 - dist * 0.5); 
                float speedVariation = 0.4 + cellRand * 1.2; // 随机速度倍率，形成大小碎片的动感差异
                
                float3 offset = explodeDir * (_ExplosionForce * speedVariation * distanceAtten) * _Progress;
                offset.y -= _Gravity * (0.6 + cellRand * 0.8) * _Progress * _Progress;

                // 5. 旋转轴与旋转角（多三角形围绕大块中心 shardCenter 统一旋转）
                float3 randomAxis = normalize(float3(
                    rand(cellID + float3(1,0,0)) - 0.5,
                    rand(cellID + float3(0,1,0)) - 0.5,
                    rand(cellID + float3(0,0,1)) - 0.5
                ));
                float spinAngle = _SpinSpeed * _Progress * (cellRand * 2.0 - 1.0);

                for (int i = 0; i < 3; i++)
                {
                    g2f o;
                    float3 localPos = IN[i].worldPos - shardCenter;
                    
                    float3 rotatedPos = rotateVector(localPos, randomAxis, spinAngle);
                    float3 rotatedNormal = rotateVector(IN[i].normal, randomAxis, spinAngle);

                    float3 finalWorldPos = shardCenter + rotatedPos + offset;

                    o.vertex = mul(UNITY_MATRIX_VP, float4(finalWorldPos, 1.0));
                    o.uv = IN[i].uv;
                    o.normal = rotatedNormal;
                    o.worldPos = finalWorldPos;

                    stream.Append(o);
                }
                stream.RestartStrip();
            }

            fixed4 frag (g2f i, float face : VFACE) : SV_Target
            {
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz + float3(0.2, 1.0, 0.2));
                float NdotL = max(0.15, dot(i.normal, lightDir));

                fixed4 baseColor;
                if (face > 0) // 正面
                {
                    baseColor = tex2D(_MainTex, i.uv) * _Color;
                }
                else // 背面陶土
                {
                    baseColor = _InnerColor;
                    NdotL = max(0.2, dot(-i.normal, lightDir));
                }

                baseColor.rgb *= NdotL;
                return baseColor;
            }
            ENDCG
        }
    }
}