Shader "Role/Nahida/Body3"
{
    Properties
    {
        [Header(Textures)]
        _BaseMap("Base Map",2D)="while"{}
        _LightMap("Light Map",2D)="white"{}

        [Toggle(_USE_LIGHTMAP_AO)]
        _UseLightMapAO ("Use LightMap AO", Range(0,1)) = 1

        [Header(RampShadow)]
        _RampTex ("Ramp Texture", 2D) = "white" {}
        [Toggle(_USE_RAMP_SHADOW)]
        _UseRampShadow ("Use Ramp Shadow", Range(0,1)) = 1
        _ShadowRampWidth ("Shadow Ramp Width",Float) = 1
        _ShadowPosition ("Shadow Position", Float) = 0.55
        _ShadowSoftness ("Shadow Softness", Float) = 0.5

        [Toggle] _UseRampShadow2 ("Use Ramp Shadow 2", Range(0,1)) = 1
        [Toggle] _UseRampShadow3 ("Use Ramp Shadow 3", Range(0,1)) = 1
        [Toggle] _UseRampShadow4 ("Use Ramp Shadow 4", Range(0,1)) = 1
        [Toggle] _UseRampShadow5 ("Use Ramp Shadow 5", Range(0,1)) = 1

        [Header(Lighting Options)]
        _DayorNight ("Day or Night", Range(0,1)) = 0

        [Header(Fresnel)]
        [Toggle(_USE_FRESNEL)]
        _FresnelSwitch ("Enable Fresnel", Float) = 1
        _FresnelColor ("Fresnel Color", Color) = (1, 0.95, 0.8, 1)
        _FresnelPower ("Fresnel Power", Range(0.1, 10)) = 3.5
        _FresnelIntensity ("Fresnel Intensity", Range(0, 3)) = 0.8

        [Header(Specular)]
        [Toggle(_USE_SPECULAR)]
        _SpecularSwitch ("Enable Specular", Float) = 1
        _SpecularColor ("Specular Color", Color) = (1, 1, 1, 1)
        _SpecularPower ("Specular Power", Range(1, 100)) = 30
        _SpecularIntensity ("Specular Intensity", Range(0, 3)) = 0.5
        _SpecularMask ("Specular Mask Source", Range(0, 1)) = 0

        [Header(Normal Map)]
        [Toggle(_USE_NORMAL_MAP)]
        _NormalMapSwitch ("Enable Normal Map", Float) = 1
        _NormalTex ("Normal Map", 2D) = "bump" {}
        _NormalIntensity ("Normal Intensity", Range(0, 2)) = 1

        [Header(Outline)]
        _OutlineColor ("Outline Color", Color) = (0, 0, 0, 1)
        _OutlineWidth ("Outline Width", Float) = 0.05
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

            #pragma shader_feature_local _USE_LIGHTMAP_AO
            #pragma shader_feature_local _USE_RAMP_SHADOW
            #pragma shader_feature_local _USE_FRESNEL
            #pragma shader_feature_local _USE_SPECULAR
            #pragma shader_feature_local _USE_NORMAL_MAP
            #pragma shader_feature_local _USE_POST_PROCESS

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                sampler2D _BaseMap;
                sampler2D _LightMap;
                sampler2D _RampTex;
                float _ShadowRampWidth;
                float _ShadowPosition;
                float _ShadowSoftness;
                float _UseRampShadow2;
                float _UseRampShadow3;
                float _UseRampShadow4;
                float _UseRampShadow5;
                float _DayorNight;
                float4 _FresnelColor;
                float _FresnelPower;
                float _FresnelIntensity;
                float4 _SpecularColor;
                float _SpecularPower;
                float _SpecularIntensity;
                float _SpecularMask;
                sampler2D _NormalTex;
                float _NormalIntensity;
                float4 _OutlineColor;
                float _OutlineWidth;
                float _OutlineVertexColorMask;

                float _PostEffectMode;
                float _EffectIntensity;
                float _BlurRadius;
                float _VignetteStrength;
                float4 _VignetteColor;
            CBUFFER_END

            float RampShadowID(float input, float useShadow2, float useShadow3, float useShadow4, float useShadow5,
            float shadowValue1, float shadowValue2, float shadowValue3, float shadowValue4, float shadowValue5)
            {
                float v1 = step(0.6, input) * step(input, 0.8);
                float v2 = step(0.4, input) * step(input, 0.6);
                float v3 = step(0.2, input) * step(input, 0.4);
                float v4 = step(input, 0.2);
                float blend12 = lerp(shadowValue1, shadowValue2, useShadow2);
                float blend13 = lerp(shadowValue1, shadowValue3, useShadow3);
                float blend14 = lerp(shadowValue1, shadowValue4, useShadow4);
                float blend15 = lerp(shadowValue1, shadowValue5, useShadow5);
                float result = blend12;
                result = lerp(result, blend15, v1);
                result = lerp(result, blend13, v2);
                result = lerp(result, blend14, v3);
                result = lerp(result, shadowValue1, v4);
                return result;
            }

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv0 : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float4 color : COLOR0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv0 : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 color : TEXCOORD2;
                float3 positionWS : TEXCOORD3;
                float4 tangentWS : TEXCOORD4;
                float4 screenUV : TEXCOORD5;
            };

            Varyings vert (Attributes input)
            {
                Varyings output;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInput.positionCS;
                VertexNormalInputs vni = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                output.normalWS = vni.normalWS;
                output.tangentWS = float4(vni.tangentWS, input.tangentOS.w);
                output.uv0 = input.uv0;
                output.color = input.color;
                output.positionWS = vertexInput.positionWS;
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

            half4 frag (Varyings input, bool isFront : SV_IsFrontFace) : SV_TARGET
            {
                Light light = GetMainLight();
                half4 vertexColor = input.color;

                half3 N = normalize(input.normalWS) * (isFront ? 1 : -1);
                half3 L = normalize(light.direction);
                half Nol = dot(N, L);

                half4 baseMap = tex2D(_BaseMap, input.uv0);
                half4 lightMap = tex2D(_LightMap, input.uv0);

                half Halflambert = Nol * 0.5 + 0.5;
                Halflambert *= pow(Halflambert, 2);
                half lambertstep = smoothstep(0.01, 0.4, Halflambert);
                half shadowFactor = lerp(0, Halflambert, lambertstep);

                #if _USE_LIGHTMAP_AO
                    half ambient = lightMap.g;
                #else
                    half ambient = Halflambert;
                #endif
                half shadow = (ambient + Halflambert) * 0.5;
                shadow = lerp(shadow, 1, step(0.95, ambient));
                shadow = lerp(shadow, 0, step(ambient, 0.05));

                half isShadowArea = step(shadow, _ShadowPosition);
                half shadowDepth = saturate((_ShadowPosition - shadow) / _ShadowPosition);
                shadowDepth = pow(shadowDepth, _ShadowSoftness);
                shadowDepth = min(shadowDepth, 1);
                half rampWidthFactor = vertexColor.g * 2 * _ShadowRampWidth;

                half RampU = 1 - saturate(shadowDepth / rampWidthFactor);
                half rampID = RampShadowID(lightMap.a, _UseRampShadow2, _UseRampShadow3, _UseRampShadow4, _UseRampShadow5, 1, 2, 3, 4, 5);
                half RampV = 0.45 - (rampID - 1) * 0.1;

                half2 rampDayUV = half2(RampU, RampV + 0.5);
                half3 rampDayColor = tex2D(_RampTex, rampDayUV);
                half2 rampNightUV = half2(RampU, RampV);
                half3 rampNightColor = tex2D(_RampTex, rampNightUV);
                half3 rampColor = lerp(rampDayColor, rampNightColor, _DayorNight);

                #if _USE_RAMP_SHADOW
                    half3 finalColor = baseMap.rgb * rampColor * (isShadowArea ? 1 : 1.2);
                #else
                    half3 finalColor = baseMap.rgb * Halflambert * (shadow + 0.2);
                #endif

                half3 V = normalize(_WorldSpaceCameraPos - input.positionWS);
                half3 H = normalize(L + V);

                #if _USE_FRESNEL
                    half NdotV = saturate(dot(N, V));
                    half fresnel = pow(1 - NdotV, _FresnelPower);
                    half3 fresnelColor = _FresnelColor.rgb * fresnel * _FresnelIntensity;
                    finalColor += fresnelColor;
                #endif

                #if _USE_SPECULAR
                    half NdotH = saturate(dot(N, H));
                    half spec = pow(NdotH, _SpecularPower);
                    half specMask = lerp(1, lightMap.a, _SpecularMask);
                    half3 specColor = _SpecularColor.rgb * spec * _SpecularIntensity * specMask;
                    finalColor += specColor;
                #endif

                // ========== Post Processing ==========
                #if _USE_POST_PROCESS
                    half intensity = _EffectIntensity;

                    // 0 = Grayscale, 1 = Blur + Vignette
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

        Pass
        {
            Name "UniversalForward"
            Tags { "LightMode"="UniversalForward" }
            Cull Off
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
                Varyings2 ShadowVS(Attributes2 input) { Varyings2 o; o.positionCS = GetShadowPositionHClip(input); return o; }
                half4 ShadowPS(Varyings2 input) : SV_TARGET { return 0; }
            ENDHLSL
        }
    }
}
