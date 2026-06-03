Shader "Role/Nahida/Nahida_Face2"
{
    Properties
    {
        [Header(Textures)]
        _BaseMap("Base Map",2D)="while"{}

        [Header(Shadow Options)]
        [Toggle(_USE_SDF_SHADOW)] _UseSDFShadow("Use SDF Shadow", Range(0,1))=1 //sdf开关
        _SDF("SDF",2D) ="white"{} //距离场纹理
        _ShadowMask("ShadowMask",2D)="white"{} //阴影遮罩
        _ShadowColor ("Shadow Color", Color) = (1, 0.87, 0.87, 1) //阴影颜色
         
        [Header(Head Direction)]
        [HideInInspector] _HeadForward("Head Forward",Vector)=(0, 0, 1, 0)//面部前方
        [HideInInspector]_HeadRight("Head Right",Vector)=(1, 0, 0, 0)//面部右侧
        [HideInInspector] _HeadUp("Head Up",Vector)=(0, 1, 0, 0)//面部上方

        [Header(Face Blush)]
        //[Toggle(_USE_FACE_BLUSH)] _UseFaceBlush("Use Face Blush", Range(0,1)) = 1 //腮红开关]
        _FaceBlushColor("Face Blush Color", Color) = (1, 0.87, 0.87, 1) //腮红颜色
        _FaceBlushStrength("Face Blush Strength", Range(0,1))=0 //腮红强度

        [Header(Outline)]
        _OutlineColor ("Outline Color", Color) = (0, 0, 0, 1)
        _OutlineWidth ("Outline Width", Float) = 0.03
        _OutlineVertexColorMask ("Vertex Color Mask", Range(0, 1)) = 0
    }
    SubShader
    {
        Tags { 
        "RenderPipeline"="UniversalRenderPipeline" //渲染管线URP
        "RenderType"="Opaque" //不透明
        }
        
        HLSLINCLUDE
            #pragma multi_compile _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _MAIN_LIGHT_SHADOWS_SCREEN

            #pragma multi_compile_fragment _LIGHT_LAYERS
            #pragma multi_compile_fragment _LIGHT_COOKIES
            #pragma multi_compile_fragment _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _SHADOWS_SOFT

            #pragma shader_feature_local _USE_SDF_SHADOW //SDF开关
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


            
            CBUFFER_START(UnityPerMaterial)
                //Textures
                sampler2D _BaseMap; //基础纹理

                //Shadow Options
                sampler2D _SDF; //距离场纹理
                sampler2D _ShadowMask; //阴影遮罩
                float4 _ShadowColor; //阴影颜色

                //Head Direction
                float3 _HeadForward; //面部前方
                float3 _HeadRight; //面部右侧
                float3 _HeadUp; //面部上方

                //Face Blush
                float4 _FaceBlushColor; //腮红颜色
                float _FaceBlushStrength; //腮红强度

                //Outline
                float4 _OutlineColor;
                float _OutlineWidth;
                float _OutlineVertexColorMask;

            CBUFFER_END
            
        ENDHLSL


        Pass
        {
            Name "UniversalForward"
            Tags
            {
                "LightMode"="UniversalForward"
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            struct Attributes
            {
                float4 positionOS : POSITION; //本地空间顶点坐标
                float2 uv0 : TEXCOORD0; //第一套纹理坐标
                float3 normalOS : NORMAL; //本地坐标法线
                
            };

            //由顶点着色器返回,传递给片元着色器的输入参数
            struct Varyings
            {
                float4 positionCS : SV_POSITION; //裁剪空间顶点坐标
                float2 uv0 : TEXCOORD0; //第一套纹理坐标
                float3 normalWS : TEXCOORD1; //世界空间法线
                

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
                return output;
            }

            //片元着色器函数：返回颜色
            half4 frag (Varyings input) : SV_TARGET
            {
                Light light = GetMainLight(); //获取主光源
                
                //归一化
                half3 N = normalize(input.normalWS); //归一化世界空间法线
                half3 L = normalize(light.direction); //归一化光源方向
                half3 Nol = dot(N,L); //计算法线和光源方向的点积
                half3 headUpDir = normalize(_HeadUp); //归一化面部上方
                half3 headForwardDir = normalize(_HeadForward); //归一化面部前方
                half3 headRightDir = normalize(_HeadRight); //归一化面部右侧

                //获取贴图信息
                half4 baseMap = tex2D(_BaseMap,input.uv0); //采样纹理贴图
                half4 ShadowMask = tex2D(_ShadowMask,input.uv0); //采样阴影遮罩
                
                //Lambert
                half lambert = Nol; //兰伯特光照(-1~1),背后全黑无光照
                half Halflambert = Nol * 0.5 + 0.5; //半兰伯特光照(0~1),背后比正面稍暗
                Halflambert *=pow(Halflambert,2); //增强半兰伯特效果,背后更暗,正面更亮

                //Face Shadow
                half3 LpU = dot(L, headUpDir) / pow(length(headUpDir), 2) * headUpDir; // 计算光源方向在面部上方的投影
                half3 LpHeadHorizon = normalize(L- LpU); // 光照方向在头部水平面上的投影
                half value = acos(dot(LpHeadHorizon, headRightDir)) / 3.141592654; // 计算光照方向与面部右方的夹角
                half exposeRight = step(value, 0.5); // 判断光照是来自右侧还是左侧
                half valueR = pow(1 - value * 2, 3); // 右侧阴影强度
                half valueL = pow(value * 2 - 1, 3); // 左侧阴影强度
                half mixValue = lerp(valueL, valueR, exposeRight); // 混合阴影强度
                half sdfLeft = tex2D(_SDF, half2(1 - input.uv0.x, input.uv0.y)).r; // 左侧距离场
                half sdfRight = tex2D(_SDF, input.uv0).r; // 右侧距离场
                half mixSdf = lerp(sdfRight, sdfLeft, exposeRight); // 采样SDF纹理
                half sdf = step(mixValue, mixSdf); // 计算硬边界阴影
                sdf = lerp(0, sdf, step(0, dot(LpHeadHorizon, headForwardDir))); // 计算右侧阴影
                sdf *= ShadowMask.g; // 使用G通道控制阴影强度
                sdf = lerp(sdf, 1, ShadowMask.a); // 使用A通道作为阴影遮罩

                //Face Blush
                half blushStrength = lerp(0, baseMap.a, _FaceBlushStrength); //根据BaseMap的Alpha通道计算腮红强度
                
                //合并颜色
                #if _USE_SDF_SHADOW
                    half3 finalColor = lerp(_ShadowColor * baseMap.rgb, baseMap.rgb, sdf);
                #else
                    half3 finalColor = baseMap.rgb * Halflambert; //最终颜色
                #endif

                finalColor = lerp(finalColor, finalColor * _FaceBlushColor.rgb, blushStrength); //混合腮红颜色
                
                return float4(finalColor, 1);
                
            }

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
