Shader "Unlit/Raymarcher Final"
{
    Properties
    {
        // [Header(Raymarcher Properties)]
        // //Add max steps and max distance
        // [Space(10)]
        
        // [Header(RayMarch Properties)]
        // [Space(10)]

        [Space(10)]
        [Header(SDF Colours and Textures)]
        [Space(10)]
        _SphereColour ("Material Default",Color) = (1,1,1,1)
        _ReflectionCube("Reflection Cube",Cube) = "white" {}
        [Space(10)]

        [Header(Ambient Occlusion)]
        [Space(10)]
        [PowerSlider(3.0)] _AOStepSize ("AO Step Size", Range(0.01,10.0)) = 5.
        _AOIterations("AO Iterations", Range(1,5)) = 1 
        [PowerSlider(3.0)] _AOIntensity ("AO Intensity", Range(0.0,1.0)) = 0.
        [Space(10)]


        

        [Header(Reflections  Metallic)]
        [Space(10)]

        
        [IntRange] _ReflectionCount ("Reflection Count", Range (0, 2)) = 0
        _ReflectionIntensity("Reflection Intensity",Range(0.0,1)) = 0.5
        [PowerSlider(3.0)] _ReflectionMet("Reflection Metallic",Range(0,1)) = 0
        [IntRange] _ReflectionDet ("Reflection Detail",Range(1,9)) = 1
        [PowerSlider(3.0)] _ReflectionExp ("Reflection Exposure",Range(1,3)) = 1
        _SpecularInt("Specular Intensity", Range(0,1)) = 1
        _SpecularPow("Specular Power" , Range(16,256)) = 64 
        [PowerSlider(3.0)] _MetalicTint("Metallic Tint",Range(0,1)) = 0.
        
        [PowerSlider(3.0)] _Fresnel("Fresnel Intensity",Range(0.,1.)) = 1.
        [PowerSlider(3.0)] _FresnelPow("Fresnel",Range(0,16)) = 0

         
        [Space(10)]

        [Header(SDF Positions)]
        [Space(10)]
        _Sphere("Sphere",Vector) = (0,0,0,1)
        _GroundY ("Ground Heigth", float)  = 0.1 
        [Space(10)]

        [Header(Lights)]
        [Space(10)]
        _LightPos ("Light Position",Vector) = (0,0,0,0)       
        _LightCol ("Light Colour",Color) = (1,1,1,1)
        
        
        
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
            #include "Lighting.cginc" //to get directional light
            
            #define MAX_STEPS 1000
            #define MAX_DIST 1000.
            #define SURF_DIST 1e-3
            
           
            //Struct definition:
            //In each struct we define a register to store data that's going to
            //Written and Read as its passed along from each shader to another


            //  struct appdata
            //Struct used to pass in data from the mesh to the vertex shader:
            //Here we only passing:

            //Vertex position data - float4 vertex : POSITION;
            //Uv texture data - float2 uv : TEXCOORD0;  // not really nessearcy since we don't need the uv's          
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                
            };

            // struct v2f 
            //The struct that passes data from the vertex shader to the fragment shader
            //Literay v2f stands for (VERTEX TO FRAG)
            //Ultimatly this is the data structure that will be used in the fragment shader            
            struct v2f
            {                
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                //Define new float3 blocks that will later need as vectors
                //TextureCoord works for this since they can hold up to float4 (usually colour data)
                float3 ro : TEXCOORD1; //Ray origin registed to TEXCOORD1
                float3 hitPos : TEXCOORD2; //The hit position needs to also be stored 
            };

            //Shader Variables
            float4 _Sphere;   
            float4 _LightPos; //Positional Light 
            float4 _LightCol;  

            //Ambient Occlusion
            float _AOStepSize, _AOIntensity;
            int _AOIterations;

            half4 _GlossyEnvironmentColor; // the averaged colour value of ambient
            half4 _SphereColour;
            float _GroundY;
            //Variables for reflections:            
            int _ReflectionCount;            
            float _ReflectionIntensity;
            half _ReflectionDet;
            float _ReflectionExp;
            float _ReflectionMet;
            float _MetalicTint;
            
            samplerCUBE _ReflectionCube; //Texture Cube Sampler


            //Reflection Testing (Specular)
            float _SpecularInt;            
            float _SpecularPow;
            //
            float _Fresnel;
            float _FresnelPow;

            //SDF PRIMITIVES:

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
            
            //SDF OPERATIONS
            //Smooth min 
            float smin( float a, float b, float k )
            {
                k *= 1.0;
                float r = exp2(-a/k) + exp2(-b/k);
                return -k*log2(r);
            }
            
    
            //Scene SDF. Ouputs the distance values the scene
            //The final output is always a float distance the scene
            float SceneSDF(float3 p)
            {
                float groundPlane = p.y + _GroundY;
                float spheredis = GetSphere(p,_Sphere);
                float boxdis = GetCube(p - float3(-2,0,2),float3(1,1,1));
                float boxdis2 = GetCube(p - float3(5,0,5),float3(2,1,1));
                
                
                float smoothboxen = smin(spheredis,boxdis,0.43);
                              
                float smooth2 = smin(smoothboxen,boxdis2,0.6);
                float ob1 =  min (smoothboxen,smooth2);
                return min(groundPlane,ob1);
                
            }
               
            //RAYMARCHER LOOPS - DIFFERENT IMPLEMENTATIONS
            
            //Raymarcher Loop (- The Art of Code) - the first one
            float RayMarch(float3 ro, float3 rd )
            {
                float dO = 0.;                
                float dS; 
                for (int i =0; i <MAX_STEPS; i++ )
                {
                    float3 p = ro + dO * rd;
                    dS = SceneSDF(p); 
                    dO += dS; 
                    if(dS < SURF_DIST || dO > MAX_DIST) break;
                   
                }
                return dO;
            }
            //changed baded on the penumbra function from "iquilezles"
            //Only used with the soft shadows
            float RayMarchSoft(float3 ro, float3 rd,float maxDistance,float k)
            {
                float result = 1.0;
                float dO = 0.0;                
                float dS; 
                for (int i =0; i <MAX_STEPS && dO <maxDistance ; i++ )
                {            
                    float3 p = ro + dO * rd;        
                    dS = SceneSDF(p); 
                    if(dS < SURF_DIST) return 0.01;
                    if(dO == 0.0) dO = SURF_DIST /10;
                    result = min(result,k*dS/dO);
                    dO += dS; 
                   
                }
                return result;
            }
    
            //RayMarcher now converted to test for hits, returns bool:
            //to get the position of the hit out we will use the "inout" statement
            bool RayMarchHit(float3 ro, float3 rd,float maxDistance,int maxIterations,inout float3 p )
            {
                bool hit;

                float dO = 0.;                
                float dS; 
                for (int i =0; i <maxIterations; i++ )
                {
                    p = ro + dO * rd;
                    dS = SceneSDF(p); 
                    dO += dS; 
                    if(dO > maxDistance) 
                    {
                        hit = false;
                        break;
                    }
                    if (dS < SURF_DIST)
                    {
                        hit = true;
                        break;
                    }
                    
                }
                return hit;
            }
            //Get Normals (- The Art of Code)
            float3 GetNormal(float3 p)
            {
                float2 e = float2(1e-2,0); // a quick way to store value for calculating:
                //when you don't need any transformation you use Y and when you want the value you use X.
                //remember that you can sample the same channel multiple times or not at all by accessing them in this manner:
                float3 n = SceneSDF(p) - float3(
                    SceneSDF(p-e.xyy), // slightly to the left
                    SceneSDF(p-e.yxy), // slightly below
                    SceneSDF(p-e.yyx) //slightly behind
                    );
                return normalize(n);
            }

            //Lighting model (- The Art of Code)
            //take input we want to shade as input
            //This outputs a single float value so it doesnt have any colour
            float3 GetLight(float3 p)
            {
                //light position -- (have that be pooled from lights via keyword) or referenced in
                float3 lightPos = _LightPos;
                float3 l = normalize (lightPos - p); //light vector;
                float3 n = GetNormal(p); // p normal
                
                //float sd = clamp((dot(n,l),0.0,1.0)*ambin);// remeber that dotproduct returns -1 on the opposite side. So clamp it.
                float dif = clamp(dot(n,l),0.0,1.0);
                float d = RayMarch(p+n*SURF_DIST*2,l);
                if (d < length(lightPos-p)) dif *= .01;
                return dif;

            }
            //Used for light rays that arent parallel
            float3 GetLightsSpotPoint(float3 p)
            {
                //Pass in light position, externally
                float3 lightPos = _LightPos;
                //Get ray direction vector to start a march towards the light
                float3 l = normalize (lightPos - p);                
                float3 n = GetNormal(p); // p normal
                
                float dif = saturate(dot(n,l));
                float d = RayMarch(p+n*SURF_DIST*2,l);
                if (d < length(lightPos-p)) dif *= .01;
                
                return dif * _LightCol;

            }
            //Implementation of the above but also adding soft shadows
            float3 GetLightsSpotPointSoftShadows(float3 p)
            {
                float3 lightPos = _LightPos;                
                float3 l = normalize (lightPos - p);                
                float3 n = GetNormal(p); 
                //Pass w factor by getting _LightPos .w
                float dif = saturate(dot(n,l));
                float d = RayMarchSoft(p+n*SURF_DIST*2,l,MAX_DIST,_LightPos.w);
                return dif * d * _LightCol;

            }            
           
            //Directional light and shadow contribution
            fixed4 GetLightDirectional(float3 p)
            {   
                float3 n = GetNormal(p); 
                float dif = saturate(dot(_WorldSpaceLightPos0, n));                
                
                //d is distance to nearest hit surface
                //if its bellow max distance we hit something
                //otherwise it means it went back to the athmosphere unabstructed.
                float d = RayMarch(p+n*SURF_DIST*2,_WorldSpaceLightPos0);               
                if (d < MAX_DIST) dif *= .01;            
                
                return dif *_LightColor0;

            } 
            //Directional light contribution but hard shadows
            fixed4 GetLightDirectionalHardShadows(float3 p)
            {   
                float3 n = GetNormal(p); 
                float dif = 1.;  
                float d = RayMarch(p+n*SURF_DIST*2,_WorldSpaceLightPos0);               
                if (d < MAX_DIST) dif *= .01;               
                
                return dif *_LightColor0;

            }                
            //Not used - Uses unity's ambient colours and lerps between them using world up
            //Opted for using cubemap instead, Since i need that for metallic
            fixed4 GetAmbientColour(float3 p)
            {
                fixed4 sky = unity_AmbientSky;
                fixed4 equator = unity_AmbientEquator;
                fixed4 ground = unity_AmbientGround;
                
                float3 lightPos = float3(0,1,0); //world up               
                float3 n = GetNormal(p); 
                float dif = dot(n,lightPos);              
                //bleding between the 3 grandients using y gradient             

                //flood with middle colour first
                fixed4 outgradient = equator; 
                outgradient = lerp(outgradient,unity_AmbientSky,clamp(dif,0.0,1.0));
                outgradient = lerp(outgradient,unity_AmbientGround,clamp(-dif,0.0,1.0)); 

                //A bit bootleg but atleast the enviroment entensity has some effect:
                return outgradient *_GlossyEnvironmentColor.x;

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
                    aOTotal += max(0.0,(dist - SceneSDF(position + normal * dist)) /dist);
                }
                return (1.0 - aOTotal *_AOIntensity );

            }
            //Specular - Bling - Phong Model
            float3 SpecularShading (float3 colReflect,float specInt,float specPow,float3 normal,float3 lightDir,float3 viewDir)
            {                
                float3 halfway = normalize(lightDir + viewDir);
                return colReflect * specInt * pow(max(0,dot(normal,halfway)),specPow);

            }
            //Everything has fresnel
            void Fresnel(float3 normal,float3 viewDir,float fresPow,out float Out)
            {
                Out = pow((1 - saturate(dot(normal,viewDir))),fresPow);
            }
            
            //Sample CUBEMAP - REPLACE THIS LATER WITH THE GLOBAL VARIABLE SO IT GETS THE CUBEMAP AUTOMATICLY FROM THE CURRENT SCENE
            float3 AmbientCubeReflections(samplerCUBE cube,float reflectnInt,half reflectDet,float3 normal,float3 viewDir,float reflectionExp)
            {
                float3 reflectedWorld = reflect (viewDir,normal);
                float4 cubeMap = texCUBElod(cube,float4(reflectedWorld,reflectDet));
                
                return reflectnInt * cubeMap.rgb * (cubeMap.a * reflectionExp);
            }
            
            //FinalLightModel - Using CubeMap and 1 point Light         
            float4 RunLightModel(float3 p,float3 normal)
            {
                float4 final = 1; //Initialize final colour at 1 (white);
                float fresnel = 0;  //Initialize fresnel at 0;              
                //View Vectors
                //Get View Direction in worldspace
                float3 LightDirection = normalize (_LightPos.xyz - p);
                //View Direction
                float3 viewDir = normalize(_WorldSpaceCameraPos - p);  

                float ambOcc = AmbientOcclusion(p,normal);
                
                //SpecularShading
                float3 spec = SpecularShading(_LightCol.xyz,_SpecularInt,_SpecularPow,normal,LightDirection,viewDir);
                //Fresnel
                Fresnel(normal,viewDir,_FresnelPow,fresnel);                
                //CubeMapReflections
                half3 cubereflection = AmbientCubeReflections(_ReflectionCube,_ReflectionIntensity,_ReflectionDet,normal,-viewDir,_ReflectionExp);

                //Final ouput:
                //Tint Cube with albedo colour, 
                half3 tintCube = lerp (cubereflection,cubereflection*_SphereColour,_MetalicTint);

                //Non Metallic              
                float3 Lambertian = _SphereColour * GetLightsSpotPointSoftShadows(p) * (1-_ReflectionMet) + fresnel*_Fresnel;
                //Metallic
                float3 CubeD = (tintCube * fresnel*_Fresnel * _ReflectionMet) ;                
                
                //Blend together and spec
                final.rgb = lerp(Lambertian,CubeD,_ReflectionMet) + spec;
                final *= ambOcc; //Add Ambient Occlusion
                return final;                
            }

            //This function receives an appdata processes it and then returns a v2f 
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.ro = _WorldSpaceCameraPos; //Wold space
                o.hitPos = mul(unity_ObjectToWorld,v.vertex); //take the position of the vertex
                //in clip and convert it to world again
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                
                float4 col = .4; //return colour
                float3 ro =i.ro; //virtual camera                
                float3 rd = normalize(i.hitPos -ro ); //ray direction
            
                float3 hitpos;                

                //Raymarch 1 - return inital distances
                bool hit = RayMarchHit(ro,rd,MAX_DIST,MAX_STEPS,hitpos);
                
                if (!hit)
                //if nothing is hit discard current pixel:
                    discard;
                else
                {     
                    float3 n = GetNormal(hitpos); 
                    //If anything is hit, run the lighting model
                    col = RunLightModel(hitpos,n);
                    
                    //REFLECTIONS (Raymarch 2 - 3):
                    //If reflections are enabled. Raymarch and RunLightModel again to get first reflection contribution              
                    if (_ReflectionCount > 0)
                    {   //We start "off" from the hit surfaces. Using reflect witch inverts the direction vector 
                        rd = normalize(reflect(rd,n));
                        ro = hitpos + (rd * 0.01);
                        
                        bool hit = RayMarchHit(ro,rd,MAX_DIST*0.5,MAX_STEPS/2,hitpos);
                        
                        if (hit)
                        {
                            float3 n = GetNormal(hitpos); 
                            col += fixed4(RunLightModel(hitpos,n).xyz*_ReflectionIntensity,0);

                            //for a second round of reflections
                            if(_ReflectionCount > 1)
                            {
                                rd = normalize(reflect(rd,n));
                                ro = hitpos + (rd * 0.01);
                                bool hit = RayMarchHit(ro,rd,MAX_DIST*0.25,MAX_STEPS/4,hitpos);
                                
                                if (hit)
                                {
                                    float3 n = GetNormal(hitpos); 
                                    col += fixed4(RunLightModel(hitpos,n).xyz*_ReflectionIntensity * 0.5,0);
                                }
                            }

                        }
                    }                  
                    
                    
                }
                return col ;
                
            }
            
            ENDCG
        }
    }
    

}
