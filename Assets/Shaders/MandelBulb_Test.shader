Shader "Unlit/Menger Spone"
{
    Properties
    {        
        [Header(Ambient Occlusion)]
        [Space(10)]
        [PowerSlider(3.0)] _AOStepSize ("AO Step Size", Range(0.01,10.0)) = 5.
        _AOIterations("AO Iterations", Range(1,5)) = 1 
        [PowerSlider(3.0)] _AOIntensity ("AO Intensity", Range(0.0,1.0)) = 0.
        
        
    }
    SubShader
    {
        Tags {"RenderType"="Opaque"}

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
                float2 uv : TEXCOORD0;
                
            };

                      
            struct v2f
            {                
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 ro : TEXCOORD1; 
                float3 hitPos : TEXCOORD2; 
            }; 

            //Ambient Occlusion
            float _AOStepSize, _AOIntensity;
            int _AOIterations;



            //SPHERE
            float GetSphere(float3 p,float4 sphere)
            {               
                float dsphere = length(p - sphere.xyz) - sphere.w;                
                return dsphere;

            }
            //CUBE
            float GetCube(float3 p, float3 scale)
            {
                return length(max(abs(p)-scale,0.));
            }
            
            float4 sceneMap4(float3 p)
            {
                //Initial cube
                float d = GetCube(p,float(20.0));
                float4 res = float4(d, 1.0, 0.0, 0.0);

                float s = 1.0;

                for (int m = 0; m < 4; m++)
                {
                    float3 a = fmod(p*s,2.0) -1.0;
                    s *= 3.0;
                    float3 r = abs(1.0 -3.0 * abs(a));

                    float da = max(r.x,r.y);
                    float db = max(r.y,r.z);
                    float dc = max(r.z,r.x);
                    
                    float c = (min(da,min(db,dc)) - 1.0)/s;
                    if (c > d)
                    {
                        d = c;
                        res = float4(d,0.2*da*db*dc,(1.0+float(m))/4.0,0.0);
                    }
                    
                }                
                return res;

            }
            //Get Normals (- The Art of Code)
            float3 GetNormal(float3 p)
            {
                float2 e = float2(1e-2,0); // a quick way to store value for calculating:
                //when you don't need any transformation you use Y and when you want the value you use X.
                //remember that you can sample the same channel multiple times or not at all by accessing them in this manner:
                float3 n = sceneMap4(p).x - float3(
                    sceneMap4(p-e.xyy).x, // slightly to the left
                    sceneMap4(p-e.yxy).x, // slightly below
                    sceneMap4(p-e.yyx).x //slightly behind
                    );
                return normalize(n);
            }
            //optimize cubes by instead of using a box, take a simple 2D plane and extrude it
            //Apparently is also better performing
            float sdBox(float2 p,float2 size)
            {
                float2 d = abs(p)-size;
                return length(max(d,0.0) + min(max(d.x,d.y),0.0));

            }
            float opExtrusion(float3 p, float sdf2d, float depth)
            {
                float2 w = float2(sdf2d,abs(p.z) -depth);
                return min(max(w.x,w.y),0.0) + length(max(w,0.0));
            }
            
            //FRACTALS - Menger Spone: https://iquilezles.org/articles/menger/ 
            
            bool intersect (inout float3 res ,float3 ro,float3 rd)
            {
                for(float t = 0.0; t<100000.0;)
                {
                    float3 h = sceneMap4(ro + rd*t);
                    //h is the distance
                    //y and z are colour data.
                    if(h.x < 0.001)
                    {
                        res = float3(t,h.yz);
                        return true;
                    } 
                    t += h;
                }
                
                return false;
                
            }
            //Ambient Occlusion
            float AmbientOcclusion(float3 position, float3 normal)
            {
                float stepSize = _AOStepSize;
                float aOTotal = 0.0; //Starting value for AmbOcc value
                float dist;
                for(int i = 1; i <= _AOIterations; i++ )
                {
                    dist = stepSize * i;
                    //if step is inside the SDF it return negative so use max:
                    aOTotal += max(0.0,(dist - sceneMap4(position + normal * dist)) /dist);
                }
                return (1.0 - aOTotal *_AOIntensity );

            }  
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.ro = _WorldSpaceCameraPos; 
                o.hitPos = mul(unity_ObjectToWorld,v.vertex);
                //in clip and convert it to world again
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                
                float4 col = .4; //return colour
                float3 ro =i.ro; //virtual camera                
                float3 rd = normalize(i.hitPos -ro ); //ray direction
            
                float3 hitdata;
                               

                bool hit = intersect(hitdata,ro,rd);
                if (!hit) discard;
                else
                {
                    float3 hitposition =  ro + rd * hitdata.x;  
                    float3 n = GetNormal ((hitposition));
                    float ambOcc = AmbientOcclusion(hitposition,n);                 
                    col.rgb =hitdata*ambOcc;
                    

                }               
                
                return col ;
                
            }
            
            ENDCG
        }
    }
    

}
