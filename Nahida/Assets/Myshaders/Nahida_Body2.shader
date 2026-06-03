Shader "Role/Nahida/Nahida_Body2"
{
    Properties
    {
        [Header(Textures)]
        _BaseMap("Base Map",2D)="while"{}
        _LightMap("Light Map",2D)="while"{}

        [Toggle(_USE_LIGHTMAP_AO)]
        _UseLightMapAO ("Use LightMap AO", Range(0,1)) = 1 //AO开关

        [Header(RampShadow)]
        _RampTex ("Ramp Texture", 2D) = "white" {} //色阶阴影(Ramp)贴图
        [Toggle(_USE_RAMP_SHADOW)]
        _UseRampShadow ("Use Ramp Shadow", Range(0,1)) = 1 //色阶阴影开关
        _ShadowRampWidth ("Shadow Ramp Width",Float) = 1 //阴影边缘宽度
        _ShadowPosition ("Shadow Position", Float) = 0.55 //阴影位置
        _ShadowSoftness ("Shadow Softness", Float) = 0.5 //阴影柔和度

        [Toggle] _UseRampShadow2 ("Use Ramp Shadow 2", Range(0,1)) = 1 //是否使用第2行色阶阴影
        [Toggle] _UseRampShadow3 ("Use Ramp Shadow 3", Range(0,1)) = 1 //是否使用第3行色阶阴影
        [Toggle] _UseRampShadow4 ("Use Ramp Shadow 4", Range(0,1)) = 1 //是否使用第4行色阶阴影
        [Toggle] _UseRampShadow5 ("Use Ramp Shadow 5", Range(0,1)) = 1 //是否使用第5行色阶阴影

        [Header(Lighting Options)]
        _DayorNight ("Day or Night", Range(0,1)) = 0 //白天或黑夜,控制主光源强度

        [Header(Fresnel)] //菲涅尔边缘光
        [Toggle(_USE_FRESNEL)]
        _FresnelSwitch ("Enable Fresnel", Float) = 1
        _FresnelColor ("Fresnel Color", Color) = (1, 0.95, 0.8, 1)
        _FresnelPower ("Fresnel Power", Range(0.1, 10)) = 3.5
        _FresnelIntensity ("Fresnel Intensity", Range(0, 3)) = 0.8

        [Header(Specular)] //Blinn-Phong高光
        [Toggle(_USE_SPECULAR)]
        _SpecularSwitch ("Enable Specular", Float) = 1
        _SpecularColor ("Specular Color", Color) = (1, 1, 1, 1)
        _SpecularPower ("Specular Power", Range(1, 100)) = 30
        _SpecularIntensity ("Specular Intensity", Range(0, 3)) = 0.5
        _SpecularMask ("Specular Mask Source", Range(0, 1)) = 0 //0=全区域, 1=仅LightMap.a控制

        [Header(Normal Map)] //法线贴图
        [Toggle(_USE_NORMAL_MAP)]
        _NormalMapSwitch ("Enable Normal Map", Float) = 1
        _NormalTex ("Normal Map", 2D) = "bump" {}
        _NormalIntensity ("Normal Intensity", Range(0, 2)) = 1

        [Header(Outline)] //描边
        _OutlineColor ("Outline Color", Color) = (0, 0, 0, 1)
        _OutlineWidth ("Outline Width", Float) = 0.05
        _OutlineVertexColorMask ("Vertex Color Mask", Range(0, 1)) = 0
    }
    SubShader
    {
        Tags { 
        "RenderPipeline"="UniversalRenderPipeline" //渲染管线URP
        "RenderType"="Opaque" //不透明
        }
        
        HLSLINCLUDE //公共代码
            #pragma multi_compile _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _MAIN_LIGHT_SHADOWS_SCREEN

            #pragma multi_compile_fragment _LIGHT_LAYERS
            #pragma multi_compile_fragment _LIGHT_COOKIES
            #pragma multi_compile_fragment _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _SHADOWS_SOFT

            #pragma shader_feature_local _USE_LIGHTMAP_AO //AO开关
            #pragma shader_feature_local _USE_RAMP_SHADOW //色阶阴影开关
            #pragma shader_feature_local _USE_FRESNEL //菲涅尔开关
            #pragma shader_feature_local _USE_SPECULAR //高光开关
            #pragma shader_feature_local _USE_NORMAL_MAP //法线贴图开关

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
                //Textures
                sampler2D _BaseMap; //基础纹理
                sampler2D _LightMap; //光照贴图

                //Ramp Shadow
                sampler2D _RampTex; //色阶阴影贴图
                float _ShadowRampWidth; //阴影边缘宽度
                float _ShadowPosition; //阴影位置
                float _ShadowSoftness; //阴影柔和度
                float _UseRampShadow2; //是否使用第2行色阶阴影
                float _UseRampShadow3; //是否使用第3行色阶阴影
                float _UseRampShadow4; //是否使用第4行色阶阴影
                float _UseRampShadow5; //是否使用第5行色阶阴影

                //Lighting Options
                float _DayorNight; //日夜变化参数

                //Fresnel
                float4 _FresnelColor;
                float _FresnelPower;
                float _FresnelIntensity;

                //Specular
                float4 _SpecularColor;
                float _SpecularPower;
                float _SpecularIntensity;
                float _SpecularMask;

                //Normal Map
                sampler2D _NormalTex;
                float _NormalIntensity;

                //Outline
                float4 _OutlineColor;
                float _OutlineWidth;
                float _OutlineVertexColorMask;

            CBUFFER_END

            //根据lightMap的Alpha通道选择Ramp行
            //half RampShadowID(half input)
            //{
                //half row =0.1; //默认第1行

                //if(input > 0.8) row = 0.9; //第5行
                //else if(input > 0.6) row = 0.7; //第4行
                //else if(input > 0.4) row = 0.5; //第3行
                //else if(input > 0.2) row = 0.3; //第2行

                //return row;
            //}
            
            
            // 官方版本的RampShadowID函数
            float RampShadowID(float input, float useShadow2, float useShadow3, float useShadow4, float useShadow5, 
            float shadowValue1, float shadowValue2, float shadowValue3, float shadowValue4, float shadowValue5)
            {
                // 根据input值将模型分为5个区域
                float v1 = step(0.6, input) * step(input, 0.8); // 0.6-0.8区域
                float v2 = step(0.4, input) * step(input, 0.6); // 0.4-0.6区域
                float v3 = step(0.2, input) * step(input, 0.4); // 0.2-0.4区域
                float v4 = step(input, 0.2);                    // 0-0.2区域

                // 根据开关控制是否使用不同材质的值
                float blend12 = lerp(shadowValue1, shadowValue2, useShadow2);
                float blend13 = lerp(shadowValue1, shadowValue3, useShadow3);
                float blend14 = lerp(shadowValue1, shadowValue4, useShadow4);
                float blend15 = lerp(shadowValue1, shadowValue5, useShadow5);
                

                // 根据区域选择对应的材质值
                float result = blend12;                // 默认使用材质1或2
                result = lerp(result, blend15, v1);    // 0.6-0.8区域使用材质5
                result = lerp(result, blend13, v2);    // 0.4-0.6区域使用材质3
                result = lerp(result, blend14, v3);    // 0.2-0.4区域使用材质4
                result = lerp(result, shadowValue1, v4); // 0-0.2区域使用材质1

                return result;
            }

            struct Attributes
            {
                float4 positionOS : POSITION; //本地空间顶点坐标
                float2 uv0 : TEXCOORD0; //第一套纹理坐标
                float2 uv1 : TEXCOORD1; //第二套纹理坐标
                float3 normalOS : NORMAL; //本地坐标法线
                float4 tangentOS : TANGENT; //本地空间切线
                float4 color : COLOR0; //顶点颜色
            };

            //由顶点着色器返回,传递给片元着色器的输入参数
            struct Varyings
            {
                float4 positionCS : SV_POSITION; //裁剪空间顶点坐标
                float2 uv0 : TEXCOORD0; //第一套纹理坐标
                float3 normalWS : TEXCOORD1; //世界空间法线
                float4 color : TEXCOORD2; //顶点颜色
                float3 positionWS : TEXCOORD3; //世界空间顶点位置
                float4 tangentWS : TEXCOORD4; //世界空间切线(xyz)+方向(w)

            };
           
           //顶点着色器函数：返回裁剪空间
            Varyings vert (Attributes input)
            {
                Varyings output; //定义顶点着色器返回值

                //position
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz); //转换顶点空间
                output.positionCS=vertexInput.positionCS; //获取裁剪空间顶点坐标

                //normal
                VertexNormalInputs VertexNormalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS); //转换法线空间
                output.normalWS = VertexNormalInputs.normalWS; //获取世界空间法线
                output.tangentWS = float4(VertexNormalInputs.tangentWS, input.tangentOS.w); //获取世界空间切线+方向

                //uv
                output.uv0 = input.uv0; //获取纹理坐标
                
                //color
                output.color = input.color; //获取顶点颜色
                output.positionWS = vertexInput.positionWS; //获取世界空间顶点位置

                return output;
            }

            //片元着色器函数：返回颜色
            half4 frag (Varyings input, bool isFront : SV_IsFrontFace) : SV_TARGET
            {
                Light light = GetMainLight(); //获取主光源
                half4 vertexColor = input.color; //获取顶点颜色

                //归一化，背面法线反转
                half3 N = normalize(input.normalWS) * (isFront ? 1 : -1);
                half3 L = normalize(light.direction); //归一化光源方向
                half3 Nol = dot(N,L); //计算法线和光源方向的点积

                //Normal Map
                #if _USE_NORMAL_MAP
                    half3 normalTS = UnpackNormal(tex2D(_NormalTex, input.uv0));
                    normalTS.xy *= _NormalIntensity;
                    normalTS.z = sqrt(1 - saturate(dot(normalTS.xy, normalTS.xy)));
                    half3 tangentWS = input.tangentWS.xyz * (isFront ? 1 : -1);
                    half3 normalWS = N;
                    half3 bitangentWS = cross(normalWS, tangentWS) * input.tangentWS.w;
                    half3x3 tangentToWorld = half3x3(tangentWS, bitangentWS, normalWS);
                    N = normalize(mul(normalTS, tangentToWorld));
                    Nol = dot(N, L);
                #endif

                //获取贴图信息
                half4 baseMap = tex2D(_BaseMap,input.uv0); //采样纹理贴图
                half4 lightMap = tex2D(_LightMap,input.uv0); //采样光照贴图

                
                //Lambert
                half lambert = Nol; //兰伯特光照(-1~1),背后全黑无光照
                half Halflambert = Nol * 0.5 + 0.5; //半兰伯特光照(0~1),背后比正面稍暗
                Halflambert *=pow(Halflambert,2); //增强半兰伯特效果,背后更暗,正面更亮
                half lambertstep = smoothstep(0.01,0.4,Halflambert); //在[0.01,0.4]范围内进行平滑插值
                half shadowFactor = lerp(0, Halflambert, lambertstep); //计算阴影因子

                //AO
                #if _USE_LIGHTMAP_AO
                    half ambient = lightMap.g; //环境光
                #else
                    half ambient = Halflambert; //不使用AO时,shadow计算后仍为Halflambert
                #endif
                half shadow = (ambient + Halflambert) * 0.5; //环境光遮蔽
                //shadow = 0.95 <= ambient ? 1 : shadow; //环境光过亮时,关闭AO遮蔽
                //ambient = shadow <=0.05 ? 0 : ambient; //环境光过暗时,关闭环境光
                shadow = lerp(shadow,1,step(0.95,ambient));
                shadow = lerp(shadow,0,step(ambient,0.05));

                half isShadowArea = step(shadow,_ShadowPosition); //是否在阴影范围内
                half shadowDepth = saturate((_ShadowPosition - shadow) / _ShadowPosition); //计算阴影深度
                shadowDepth = pow(shadowDepth, _ShadowSoftness); //根据柔和度, 调整阴影深度)
                shadowDepth = min(shadowDepth,1); //限制阴影深度最大值为1
                half rampWidthFactor = vertexColor.g * 2 * _ShadowRampWidth; //使用顶点颜色G通道控制Ramp宽度
                half shadowPosition = (_ShadowPosition - shadowFactor) / _ShadowPosition; //带入阴影因子计算阴影位置

                //Ramp
                half RampU = 1 - saturate(shadowDepth / rampWidthFactor); //计算Ramp采样的横坐标
                half rampID = RampShadowID(lightMap.a,_UseRampShadow2,_UseRampShadow3,_UseRampShadow4,_UseRampShadow5,1,2,3,4,5); //根据LightMap的Alpha通道选择Ramp行
                half RampV = 0.45 - (rampID - 1) * 0.1; //根据rampID计算v坐标
                //half2 RampUV = half2(RampU,RampV); //Ramp采样UV坐标

                half2 rampDayUV = half2(RampU,RampV + 0.5); //构建Ramp的白天UV坐标
                half3 rampDayColor = tex2D(_RampTex,rampDayUV); //采样白天Ramp贴图
                half2 rampNightUV = half2(RampU,RampV); //构建Ramp的夜晚UV坐标
                half3 rampNightColor = tex2D(_RampTex,rampNightUV); //采样夜晚Ramp贴图获取阴影颜色
                half3 rampColor = lerp(rampDayColor, rampNightColor, _DayorNight); //根据日夜切换参数选择Ramp颜色

                //合并颜色
                #if _USE_RAMP_SHADOW //使用Ramp阴影
                    half3 finalColor = baseMap.rgb * rampColor * (isShadowArea ? 1 : 1.2); //采用Ramp阴影
                #else
                    half3 finalColor = baseMap.rgb * Halflambert * (shadow + 0.2); //采用兰伯特阴影
                #endif

                //View Direction
                half3 V = normalize(_WorldSpaceCameraPos - input.positionWS);
                half3 H = normalize(L + V);

                //Fresnel
                #if _USE_FRESNEL
                    half NdotV = saturate(dot(N, V));
                    half fresnel = pow(1 - NdotV, _FresnelPower);
                    half3 fresnelColor = _FresnelColor.rgb * fresnel * _FresnelIntensity;
                    finalColor += fresnelColor;
                #endif

                //Blinn-Phong Specular
                #if _USE_SPECULAR
                    half NdotH = saturate(dot(N, H));
                    half spec = pow(NdotH, _SpecularPower);
                    half specMask = lerp(1, lightMap.a, _SpecularMask);
                    half3 specColor = _SpecularColor.rgb * spec * _SpecularIntensity * specMask;
                    finalColor += specColor;
                #endif
                
                return float4(finalColor.rgb,1);
                
            }

            
        ENDHLSL //公共代码结束


        Pass
        {
            Name "UniversalForward"
            Tags
            {
                "LightMode"="UniversalForward"
            }

            Cull Off // 双面渲染

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            
            ENDHLSL
        }

        Pass
        {
            Name "Outline"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            Cull Front
            ZWrite On

            HLSLPROGRAM
            #pragma vertex OutlineVert
            #pragma fragment OutlineFrag

            struct AttributesOutline
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 color : COLOR0;
            };

            struct VaryingsOutline
            {
                float4 positionCS : SV_POSITION;
            };

            VaryingsOutline OutlineVert(AttributesOutline input)
            {
                VaryingsOutline output;
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = normalize(TransformObjectToWorldNormal(input.normalOS));
                float width = _OutlineWidth * lerp(1, input.color.a, _OutlineVertexColorMask);
                positionWS += normalWS * width;
                output.positionCS = TransformWorldToHClip(positionWS);
                return output;
            }

            half4 OutlineFrag(VaryingsOutline input) : SV_TARGET
            {
                return _OutlineColor;
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
                Tags
                {
                    "LightMode" = "ShadowCaster" //光照模式：阴影投射
                }

                ZWrite On //写入深度缓冲区
                ZTest LEqual //速度测试：<=
                ColorMask 0 //不写入颜色缓冲区
                Cull Off //不裁剪

                HLSLINCLUDE

                    #pragma multi_compile_instancing // 启用GPU实例化编译
                    #pragma multi_compile _ DOTS_INSTANCING_ON // 启用DOTS实例化编译
                    #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW // 启用点光源阴影

                    float3 _LightDirection; //光源方向
                    float3 _LightPosition; //光源位置

                    struct Attributes2
                    {
                        float4 positionOS : POSITION; //本地空间顶点坐标
                        float3 normalOS : NORMAL; //本地坐标法线
                    };

                    //由顶点着色器返回,传递给片元着色器的输入参数
                    struct Varyings2
                    {
                        float4 positionCS : SV_POSITION; //裁剪空间顶点坐标
                    };

                    // 将阴影的世界空间顶点位置转换为适合阴影投射的裁剪空间位置
                    float4 GetShadowPositionHClip(Attributes2 input)
                    {
                        float3 positionWS = TransformObjectToWorld(input.positionOS.xyz); // 将本地空间顶点坐标转换为世界空间顶点坐标
                        float3 normalWS = TransformObjectToWorldNormal(input.normalOS); // 将本地空间法线转换为世界空间法线

                        #if _CASTING_PUNCTUAL_LIGHT_SHADOW // 点光源
                            float3 lightDirectionWS = normalize(_LightPosition - positionWS); // 计算光源方向
                        #else // 平行光
                            float3 lightDirectionWS = _LightDirection; // 使用预定义的光源方向
                        #endif

                        float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS)); // 应用阴影偏移

                        // 根据平台的Z缓冲区方向调整Z值
                        #if UNITY_REVERSED_Z // 反转Z缓冲区
                            positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE); // 限制Z值在近裁剪平面以下
                        #else // 正向Z缓冲区
                            positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE); // 限制Z值在远裁剪平面以上
                        #endif

                        return positionCS; // 返回裁剪空间顶点坐标
                    }

                    Varyings2 ShadowVS(Attributes2 input)
                    {
                        Varyings2 output; //定义顶点着色器返回值
                        output.positionCS = GetShadowPositionHClip(input); // 获取裁剪空间顶点坐标
                        return output;
                    }

                    half4 ShadowPS(Varyings2 input) : SV_TARGET
                    {
                        return half4(0, 0, 0, 0); // 阴影颜色（不写入颜色缓冲区）
                    }


                ENDHLSL

            }
    }
}
