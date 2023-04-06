Shader "Hidden/RayTraceShader"
{
    Properties
    {
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

            struct Ray
            {
                float3 origin;
                float3 dir;
            };

            struct RayMaterial
            {
                float4 color;
                float4 emitColor;
                float emitStrength;
                float specular;
            };

            struct Sphere
            {
                float3 position;
                float radius;
                RayMaterial material;
            };

            struct HitInfo
            {
                bool hit;
                float distance;
                float3 pos;
                float3 normal;
                RayMaterial material;
            };

            float3 NearClipParams;
            float2 ScreenParams;
            float4x4 CamLocalToWorldMatrix;

            int MaxBounce;
            int FrameIndex;
            int RaysPerPixel;
            int SpheresCount;
            StructuredBuffer<Sphere> Spheres;

            float Random(inout uint seed)
            {
                seed = seed * 747796405 + 2891336453;
                uint result = ((seed >> ((seed >> 28) + 4)) ^ seed) * 277803737;
                result = (result >> 22) ^ result;
                return result / 4294967295.0;
            }

            float RandomNormalDistribution(inout uint seed)
            {
                float theta = 2 * 3.1415926 * Random(seed);
                float rho = sqrt(-2 * log(Random(seed)));
                return rho * cos(theta);
            }

            float3 RandomDirection(inout uint seed)
            {
                float x = RandomNormalDistribution(seed);
                float y = RandomNormalDistribution(seed);
                float z = RandomNormalDistribution(seed);

                return normalize(float3(x, y, z));
            }

            float3 RandomDirectionInHemisphere(float3 normal, inout uint seed)
            {
                float3 dir = RandomDirection(seed);
                return dir * sign(dot(dir, normal));
            }

            HitInfo RaySphere(Ray ray, Sphere sphere)
            {
                HitInfo info = (HitInfo) 0;

                float3 oc = ray.origin - sphere.position;
                float a = dot(ray.dir, ray.dir);
                float b = 2 * dot(oc, ray.dir);
                float c = dot(oc, oc) - sphere.radius * sphere.radius;

                float d = b * b - 4 * a * c;

                if (d >= 0)
                {
                    float distance = (-b - sqrt(d)) / (2.0f * a);

                    if (distance >= 0)
                    {
                        float3 hit = ray.origin + ray.dir * distance;
                        float3 normal = normalize(hit - sphere.position);

                        info.hit = true;
                        info.distance = distance;
                        info.pos = hit;
                        info.normal = normal;
                        info.material = sphere.material;
                    }
                }

                return info;
            }

            HitInfo ClosestHit(Ray ray)
            {
                HitInfo closest = (HitInfo) 0;
                closest.distance = 1.0 / 0; // Infinity

                for (int i = 0; i < SpheresCount; i++)
                {
                    Sphere sphere = Spheres[i];
                    HitInfo info = RaySphere(ray, sphere);

                    if (info.hit && info.distance < closest.distance)
                        closest = info;
                }

                return closest;
            }

            float3 RayTrace(Ray ray, inout uint seed)
            {
                float3 result = 0;
                float3 color = 1;

                for (int i = 0; i <= MaxBounce; i++)
                {
                    HitInfo info = ClosestHit(ray);
                    if (!info.hit) { result += color; break; }

                    RayMaterial material = info.material;

                    // Change ray direction
                    ray.origin = info.pos;
                    float3 diffuseDir = RandomDirectionInHemisphere(info.normal, seed);
                    float3 specularDir = reflect(ray.dir, info.normal);
                    ray.dir = lerp(diffuseDir, specularDir, material.specular);

                    // Add result color based on material emission
                    float3 emitLight = material.emitColor * material.emitStrength;
                    float strength = dot(info.normal, ray.dir);
                    result += emitLight * color;
                    color *= material.color * strength * 2;
                }

                return result;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                uint2 numPixels = ScreenParams.xy;
                uint2 pixelCoord = i.uv * numPixels;
                uint seed = pixelCoord.y * numPixels.x + pixelCoord.x;
                seed += FrameIndex * 72156710;

                float3 p = float3(i.uv - 0.5, 1) * NearClipParams;
                p = mul(CamLocalToWorldMatrix, float4(p, 1));

                Ray ray;
                ray.origin = _WorldSpaceCameraPos;
                ray.dir = normalize(p - ray.origin);

                float3 average = 0;
                for (int i = 0; i < RaysPerPixel; i++)
                    average += RayTrace(ray, seed);

                return float4(average / RaysPerPixel, 1);
            }

            ENDCG
        }
    }
}
