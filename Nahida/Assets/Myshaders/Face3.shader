Shader "Role/Nahida/Face3"
{
    Properties
    {
        [Header(Textures)]
        _BaseMap("Base Map",2D)="white"{}

        [Header(Shadow Options)]
        [Toggle(_USE_SDF_SHADOW)] _UseSDFShadow("Use SDF Shadow", Range(0,1))=1
        _SDF("SDF",2D) ="white"{}
        _ShadowMask("ShadowMask",2D)="white"{}
        _ShadowColor ("Shadow Color", Color) = (1, 0.87, 0.87, 1)
         
        [Header(Head Direction)]
        [HideInInspector] _HeadForward("Head Forward",Vector)=(0, 0, 1, 0)
        [HideInInspector]_HeadRight("Head Right",Vector)=(1, 0, 0, 0)
        [HideInInspector] _HeadUp("Head Up",Vector)=(0, 1, 0, 0)

        [Header(Face Blush)]
        _FaceBlushColor("Face Blush Color", Color) = (1, 0.87, 0.87, 1)
        _FaceBlushStrength("Face Blush Strength", Range(0,1))=0

        [Header(Outline)]
        _OutlineColor ("Outline Color", Color) = (0, 0, 0, 1)
        _OutlineWidth ("Outline Width", Float) = 0.03
        _OutlineVertexColorMask ("Vertex Color Mask", Range(0, 1)) = 0

        [Header(Post Processing)]
        [Space]
        [Toggle(_USE_POST_PROCESS)]
        _PostProcessSwitch ("Enable Post Processing", Float) = 0
        _PostEffectMode ("Effect Mode", Range(0, 1)) = 0
        _EffectIntensity ("Effect Intensity", Range(0, 1)) = 0.5
        _BlurRadius ("Blur Radius", Range(0, 0.05)) = 0.01
        _VignetteStrength ("Vignette Strength", Range(0, 1)) = 0.3
        _VignetteColor ("Vignette Color", Color) = (0, 0, 0, 1)
    }
    SubShader
    {
        Tags { 
            "RenderPipeline"="UniversalRenderPipeline"
            "RenderType"="Opaque"
        }
        
        HLSLINCLUDE
            #pragma multi_compile _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _LIGHT_LAYERS _LIGHT_COOKIES _SCREEN_SPACE_OCCLUSION _ADDITIONAL_LIGHT_SHADOWS _SHADOWS_SOFT

            #pragma shader_feature_local _USE_SDF_SHADOW
            #pragma shader_feature_local _USE_POST_PROCESS

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                sampler2D _BaseMap;
                sampler2D _SDF;
                sampler2D _ShadowMask;
                float4 _ShadowColor;
                float3 _HeadForward;
                float3 _HeadRight;
                float3 _HeadUp;
                float4 _FaceBlushColor;
                float _FaceBlushStrength;
                float4 _OutlineColor;
                float _OutlineWidth;
                float _OutlineVertexColorMask;

                float _PostEffectMode;
                float _EffectIntensity;
                float _BlurRadius;
                float _VignetteStrength;
                float4 _VignetteColor;
            CBUFFER_END
        ENDHLSL

        Pass
        {
            Name "UniversalForward"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv0 : TEXCOORD0;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv0 : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 screenUV : TEXCOORD2;
            };

            Varyings vert (Attributes input)
            {
                Varyings output;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInput.positionCS;
                VertexNormalInputs vni = GetVertexNormalInputs(input.normalOS);
                output.normalWS = vni.normalWS;
                output.uv0 = input.uv0;
                output.screenUV = vertexInput.positionNDC;
                return output;
            }

            half3 BlurTexture(sampler2D tex, float2 uv, float2 texelSize, int radius)
            {
                half3 color = 0;
                int count = 0;
                for (int x = -radius; x <= radius; x++)
                {
                    for (int y = -radius; y <= radius; y++)
                    {
                        color += tex2D(tex, uv + float2(x, y) * texelSize).rgb;
                        count++;
                    }
                }
                return color / count;
            }

            half4 frag (Varyings input) : SV_TARGET
            {
                Light light = GetMainLight();

                half3 N = normalize(input.normalWS);
                half3 L = normalize(light.direction);
                half Nol = dot(N, L);
                half3 headUpDir = normalize(_HeadUp);
                half3 headForwardDir = normalize(_HeadForward);
                half3 headRightDir = normalize(_HeadRight);

                half4 baseMap = tex2D(_BaseMap, input.uv0);
                half4 ShadowMask = tex2D(_ShadowMask, input.uv0);

                half lambert = Nol;
                half Halflambert = Nol * 0.5 + 0.5;
                Halflambert *= pow(Halflambert, 2);

                half3 LpU = dot(L, headUpDir) / pow(length(headUpDir), 2) * headUpDir;
                half3 LpHeadHorizon = normalize(L - LpU);
                half value = acos(dot(LpHeadHorizon, headRightDir)) / 3.141592654;
                half exposeRight = step(value, 0.5);
                half valueR = pow(1 - value * 2, 3);
                half valueL = pow(value * 2 - 1, 3);
                half mixValue = lerp(valueL, valueR, exposeRight);
                half sdfLeft = tex2D(_SDF, half2(1 - input.uv0.x, input.uv0.y)).r;
                half sdfRight = tex2D(_SDF, input.uv0).r;
                half mixSdf = lerp(sdfRight, sdfLeft, exposeRight);
                half sdf = step(mixValue, mixSdf);
                sdf = lerp(0, sdf, step(0, dot(LpHeadHorizon, headForwardDir)));
                sdf *= ShadowMask.g;
                sdf = lerp(sdf, 1, ShadowMask.a);

                half blushStrength = lerp(0, baseMap.a, _FaceBlushStrength);

                #if _USE_SDF_SHADOW
                    half3 finalColor = lerp(_ShadowColor * baseMap.rgb, baseMap.rgb, sdf);
                #else
                    half3 finalColor = baseMap.rgb * Halflambert;
                #endif

                finalColor = lerp(finalColor, finalColor * _FaceBlushColor.rgb, blushStrength);

                // ========== Post Processing ==========
                #if _USE_POST_PROCESS
                    half intensity = _EffectIntensity;

                    if (_PostEffectMode < 0.5)
                    {
                        half3 gray = dot(finalColor.rgb, half3(0.299, 0.587, 0.114));
                        finalColor.rgb = lerp(finalColor.rgb, gray, intensity);
                    }
                    else
                    {
                        float2 texelSize = float2(_BlurRadius, _BlurRadius);
                        half3 blurColor = BlurTexture(_BaseMap, input.uv0, texelSize, 1);
                        finalColor.rgb = lerp(finalColor.rgb, blurColor, intensity);

                        float2 ndc = input.screenUV.xy / max(input.screenUV.w, 0.001);
                        float2 vignetteUV = abs(ndc - 0.5) * 2;
                        half vignette = saturate(1 - max(vignetteUV.x, vignetteUV.y));
                        vignette = lerp(1, vignette, _VignetteStrength);
                        finalColor.rgb = lerp(_VignetteColor.rgb, finalColor.rgb, vignette);
                    }
                #endif

                return float4(finalColor.rgb, 1);
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
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Off

            HLSLINCLUDE
                #pragma multi_compile_instancing
                #pragma multi_compile _ DOTS_INSTANCING_ON
                #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

                float3 _LightDirection;
                float3 _LightPosition;

                struct Attributes2 { float4 positionOS : POSITION; float3 normalOS : NORMAL; };
                struct Varyings2 { float4 positionCS : SV_POSITION; };

                float4 GetShadowPositionHClip(Attributes2 input)
                {
                    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                    float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                    #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                        float3 lightDirectionWS = normalize(_LightPosition - positionWS);
                    #else
                        float3 lightDirectionWS = _LightDirection;
                    #endif
                    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
                    #if UNITY_REVERSED_Z
                        positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
                    #else
                        positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
                    #endif
                    return positionCS;
                }

                Varyings2 ShadowVS(Attributes2 input)
                {
                    Varyings2 o;
                    o.positionCS = GetShadowPositionHClip(input);
                    return o;
                }

                half4 ShadowPS(Varyings2 input) : SV_TARGET
                {
                    return 0;
                }
            ENDHLSL
        }
    }
}
