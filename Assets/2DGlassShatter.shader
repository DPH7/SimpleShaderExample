Shader "Custom/Shatter/2DGlassShatter"
{
    Properties
    {
        _MainTex ("Sprite/Glass Texture", 2D) = "white" {}
        _Color ("Tint Color", Color) = (1,1,1,0.8)
        _Progress ("Explosion Progress (破碎进度)", Range(0, 1)) = 0.0
        _ImpactPoint ("Impact Point (冲击中心 2D)", Vector) = (0,0,0,0)
        _ShardDensity ("Shard Density (碎片数量/密度)", Range(1, 20)) = 6.0
        _ExplosionForce ("Explosion Force (爆炸力度)", Float) = 4.0
        _RotationSpeed ("Fragment Spin (碎片自转速度)", Float) = 10.0
        _Gravity ("Gravity (重力感)", Float) = 3.0
        [HDR] _EdgeGlow ("Edge Glow (碎片边缘闪光)", Color) = (2,2,2,1)
    }

    SubShader
    {
        Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }
        Cull Off
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off

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
                float2 uv : TEXCOORD0;
            };

            struct v2g
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
            };

            struct g2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float alpha : TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _Color;
            float _Progress;
            float4 _ImpactPoint;
            float _ShardDensity;
            float _ExplosionForce;
            float _RotationSpeed;
            float _Gravity;
            float4 _EdgeGlow;

            // 2D 随机数生成器
            float2 rand2(float2 p)
            {
                p = float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)));
                return frac(sin(p) * 43758.5453123);
            }

            // 【核心算法】Voronoi (泰森多边形) 区块计算
            // 给定一个 2D 位置，返回其所属的有机玻璃碎片中心与唯一 ID
            float2 getVoronoiCellID(float2 pos, float density)
            {
                float2 p = pos * density;
                float2 g = floor(p);
                float2 f = frac(p);

                float minDist = 100.0;
                float2 closestCell = g;

                // 遍历周边 3x3 的网格寻找最近的特征点，形成不规则多边形
                for (int y = -1; y <= 1; y++)
                {
                    for (int x = -1; x <= 1; x++)
                    {
                        float2 lattice = float2(x, y);
                        float2 cellPoint = rand2(g + lattice); // 随机偏移特征点位置
                        float2 diff = lattice + cellPoint - f;
                        float dist = dot(diff, diff);
                        if (dist < minDist)
                        {
                            minDist = dist;
                            closestCell = g + lattice;
                        }
                    }
                }
                return closestCell;
            }

            v2g vert (appdata v)
            {
                v2g o;
                o.vertex = v.vertex;
                o.uv = v.uv;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            [maxvertexcount(3)]
            void geom(triangle v2g IN[3], inout TriangleStream<g2f> stream)
            {
                // 1. 计算三角形质心
                float3 triCenter = (IN[0].worldPos + IN[1].worldPos + IN[2].worldPos) / 3.0;

                // 2. 利用 Voronoi 将空间分割为不规则多边形（解决纵向条纹的关键）
                float2 cellID = getVoronoiCellID(triCenter.xy, _ShardDensity);
                float2 cellRandom = rand2(cellID);
                float cellRandVal = cellRandom.x;

                // 碎片中心位置
                float3 shardCenter = float3(cellID / _ShardDensity, triCenter.z);

                // 3. 计算从 ImpactPoint 向外辐射的炸开方向
                float3 flyDir = shardCenter - _ImpactPoint.xyz;
                flyDir.z = 0;
                float distToImpact = length(flyDir);
                flyDir = distToImpact < 0.001 ? float3(0, 1, 0) : normalize(flyDir);

                // 4. 加入各向异性的随机偏转，使碎片向四周散开
                flyDir.x += (cellRandom.x - 0.5) * 0.6;
                flyDir.y += (cellRandom.y - 0.5) * 0.6;

                // 5. 速度与重力计算（大块/小块区分度）
                float pieceForce = _ExplosionForce * (0.5 + cellRandVal * 1.0);
                float3 offset = flyDir * pieceForce * _Progress;
                offset.y -= _Gravity * (0.4 + cellRandVal * 0.8) * _Progress * _Progress;

                // 6. 碎片整体围绕 Voronoi 中心旋转
                float angle = (cellRandVal - 0.5) * _RotationSpeed * _Progress;
                float cosA = cos(angle);
                float sinA = sin(angle);

                float currentAlpha = saturate(1.0 - _Progress * 1.1);

                for (int i = 0; i < 3; i++)
                {
                    g2f o;
                    // 绕整块多边形碎片的中心 shardCenter 进行旋转
                    float3 localPos = IN[i].worldPos - shardCenter;

                    float3 rotatedPos;
                    rotatedPos.x = localPos.x * cosA - localPos.y * sinA;
                    rotatedPos.y = localPos.x * sinA + localPos.y * cosA;
                    rotatedPos.z = localPos.z + (cellRandVal - 0.5) * _Progress * 0.2;

                    float3 finalWorldPos = shardCenter + rotatedPos + offset;

                    o.vertex = mul(UNITY_MATRIX_VP, float4(finalWorldPos, 1.0));
                    o.uv = IN[i].uv;
                    o.alpha = currentAlpha;

                    stream.Append(o);
                }
                stream.RestartStrip();
            }

            fixed4 frag (g2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv) * _Color;
                col.a *= i.alpha;
                col.rgb += _EdgeGlow.rgb * _Progress * 0.6;
                return col;
            }
            ENDCG
        }
    }
}