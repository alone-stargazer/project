Shader "Role/Nahida/Nahida_Body"
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
                float4 color : COLOR0; //顶点颜色
            };

            //由顶点着色器返回,传递给片元着色器的输入参数
            struct Varyings
            {
                float4 positionCS : SV_POSITION; //裁剪空间顶点坐标
                float2 uv0 : TEXCOORD0; //第一套纹理坐标
                float3 normalWS : TEXCOORD1; //世界空间法线
                float4 color : TEXCOORD2; //顶点颜色

            };
           
           //顶点着色器函数：返回裁剪空间
            Varyings vert (Attributes input)
            {
                Varyings output; //定义顶点着色器返回值

                //position
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz); //转换顶点空间
                output.positionCS=vertexInput.positionCS; //获取裁剪空间顶点坐标

                //normal
                VertexNormalInputs VertexNormalInputs = GetVertexNormalInputs(input.normalOS); //转换法线空间
                output.normalWS = VertexNormalInputs.normalWS; //获取世界空间法线

                //uv
                output.uv0 = input.uv0; //获取纹理坐标
                
                //color
                output.color = input.color; //获取顶点颜色

                return output;
            }

            //片元着色器函数：返回颜色
            half4 frag (Varyings input) : SV_TARGET
            {
                Light light = GetMainLight(); //获取主光源
                half4 vertexColor = input.color; //获取顶点颜色

                //归一化
                half3 N = normalize(input.normalWS); //归一化世界空间法线
                half3 L = normalize(light.direction); //归一化光源方向
                half3 Nol = dot(N,L); //计算法线和光源方向的点积

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
                
                return float4(finalColor.rgb,1);
                
            }

            
        ENDHLSL //公共代码结束


        Pass
        {
            Name "UniversalForward" //通道名
            Tags //标签
            {
                "LightMode"="UniversalForward" //光照模型：向前渲染
            }

            Cull Back //剔除模式

            HLSLPROGRAM //着色器程序开始
            #pragma vertex vert
            #pragma fragment frag

            
            ENDHLSL //着色器程序结束
        }

        Pass // 背面渲染通道
        {
            Name "UniversalForward"
            Tags
            {
                "LightMode" = "SRPDefaultUnlit"  // 改用 UniversalForward 以获得主光源等数据
                "Queue" = "Geometry + 1"          // 确保在正面之后渲染，避免深度冲突
            }

            Cull Front  // 剔除正面，渲染背面

             HLSLPROGRAM
            #pragma vertex BackVert
            #pragma fragment frag   // 复用正面的片元着色器

            // 背面顶点着色器：基于正面顶点处理，但切换UV并反转法线
            Varyings BackVert(Attributes input)
            {
                Varyings output = vert(input);       // 调用原有的正面顶点变换逻辑
                output.uv0 = input.uv1;              // 使用第二套UV（通常用于背面纹理映射）
                output.normalWS = -output.normalWS;  // 反转法线，使背面光照正确
                return output;
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

