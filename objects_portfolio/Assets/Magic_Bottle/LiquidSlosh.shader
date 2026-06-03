Shader "bottle/LiquidSlosh"
{
    Properties
    {
        [Header(Liquid)]
        _LiquidColor ("Surface Color", Color) = (0.05, 0.35, 0.75, 0.85)
        _DeepColor ("Deep Color", Color) = (0.0, 0.12, 0.35, 0.95)
        _FillLevel ("Fill Level", Range(0.0, 1.0)) = 0.5

        [Header(Surface)]
        _Smoothness ("Smoothness", Range(0.0, 1.0)) = 0.6
        _WaveHeight ("Wave Height", Range(0.0, 0.1)) = 0.015
        _WaveFreq ("Wave Frequency", Float) = 8.0
        _WaveSpeed ("Wave Speed", Float) = 1.5
        _Meniscus ("Meniscus Height", Range(0.0, 0.05)) = 0.01

        [Header(Slosh)]
        _SloshSpeed ("Slosh Speed", Float) = 1.2
        _SloshAmount ("Slosh Amount", Range(0.0, 0.3)) = 0.08
        _SloshFreq ("Slosh Frequency", Float) = 2.0

        [Header(Glass)]
        _GlassColor ("Glass Color", Color) = (0.9, 0.92, 0.95, 0.12)
        _FresnelPower ("Fresnel Power", Range(0.5, 8.0)) = 3.0
        _GlassReflect ("Glass Reflectivity", Range(0.0, 0.5)) = 0.04

        [Header(Refraction)]
        [Toggle]_UseRefraction ("Use Refraction", Float) = 1.0
        _RefractionStrength ("Refraction Strength", Range(0.0, 0.05)) = 0.015
    }

    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "RenderPipeline"="UniversalPipeline" }
        LOD 100

        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off

        Pass
        {
            Name "Liquid"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float4 tangentWS : TEXCOORD3;
                float4 screenPos : TEXCOORD4;
                float3 positionOS : TEXCOORD5;
                float3 viewDirWS : TEXCOORD6;
            };

            CBUFFER_START(UnityPerMaterial)
            half4 _LiquidColor;
            half4 _DeepColor;
            half _FillLevel;
            half _Smoothness;
            half _WaveHeight;
            half _WaveFreq;
            half _WaveSpeed;
            half _Meniscus;
            half _SloshSpeed;
            half _SloshAmount;
            half _SloshFreq;
            half4 _GlassColor;
            half _FresnelPower;
            half _GlassReflect;
            half _UseRefraction;
            half _RefractionStrength;
            CBUFFER_END

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;

                VertexPositionInputs positionInputs = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = positionInputs.positionCS;
                o.positionWS = positionInputs.positionWS;
                o.screenPos = positionInputs.positionNDC;

                o.normalWS = TransformObjectToWorldNormal(v.normalOS);

                real sign = v.tangentOS.w * GetOddNegativeScale();
                half4 tangentWS = half4(TransformObjectToWorldDir(v.tangentOS.xyz), sign);
                o.tangentWS = tangentWS;

                o.viewDirWS = GetWorldSpaceNormalizeViewDir(o.positionWS);
                o.positionOS = v.positionOS.xyz;

                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                half3 worldUp = half3(0, 1, 0);
                half3 localUpWS = TransformObjectToWorldDir(half3(0, 1, 0));

                half tilt = 1.0 - saturate(dot(localUpWS, worldUp));

                half3 tiltDir = half3(0, 0, 0);
                if (tilt > 0.001)
                {
                    half3 upProj = localUpWS - worldUp * dot(localUpWS, worldUp);
                    tiltDir = normalize(upProj);
                }

                half sloshPhase = _Time.y * _SloshSpeed;
                half slosh = sin(sloshPhase + tilt * _SloshFreq) * tilt * _SloshAmount;

                half3 liquidNormalWS = normalize(worldUp + tiltDir * slosh);

                half fillHeight = (_FillLevel * 2.0 - 1.0) * 0.5;
                half3 liquidOriginWS = TransformObjectToWorld(half3(0, fillHeight, 0));

                half distToLiquid = dot(i.positionWS - liquidOriginWS, liquidNormalWS);

                half2 waveUV = i.positionWS.xz * _WaveFreq + _Time.y * _WaveSpeed * half2(1.0, 0.7);
                half wave = sin(waveUV.x) * cos(waveUV.y) * _WaveHeight;
                distToLiquid += wave;

                half meshNormalDotLiquid = abs(dot(normalize(i.normalWS), liquidNormalWS));
                half meniscus = saturate(1.0 - meshNormalDotLiquid) * _Meniscus;
                meniscus *= exp(-abs(distToLiquid) * 40.0);
                distToLiquid -= meniscus;

                if (distToLiquid > 0.0)
                {
                    half3 V = normalize(i.viewDirWS);
                    half3 N = normalize(i.normalWS);
                    half fresnel = pow(1.0 - saturate(dot(N, V)), _FresnelPower);

                    half3 glassColor = _GlassColor.rgb + fresnel * _GlassReflect;
                    half alpha = _GlassColor.a + fresnel * _GlassReflect * 0.5;

                    return half4(glassColor, saturate(alpha));
                }

                half depth = saturate(-distToLiquid * 3.0);
                half3 liquidColor = lerp(_LiquidColor.rgb, _DeepColor.rgb, depth);
                half alpha = lerp(_LiquidColor.a, _DeepColor.a, depth);

                half3 N = liquidNormalWS;
                half3 T = normalize(i.tangentWS.xyz);
                half3 B = normalize(cross(N, T) * i.tangentWS.w);

                half2 wavePerturb = half2(
                    cos(waveUV.x) * cos(waveUV.y) * _WaveHeight * _WaveFreq,
                    -sin(waveUV.x) * sin(waveUV.y) * _WaveHeight * _WaveFreq
                ) * 0.5;

                N = normalize(N + T * wavePerturb.x + B * wavePerturb.y);

                half3 V = normalize(i.viewDirWS);
                half NdotV = saturate(dot(N, V));

                Light mainLight = GetMainLight();
                half3 L = mainLight.direction;
                half3 lightColor = mainLight.color;

                half NdotL = saturate(dot(N, L));
                half3 diffuse = liquidColor * lightColor * NdotL;

                half3 ambient = SampleSH(N) * liquidColor * 0.4;

                half3 H = normalize(L + V);
                half NdotH = saturate(dot(N, H));
                half spec = pow(NdotH, _Smoothness * 128.0 + 1.0);
                half3 specColor = lightColor * spec * 0.3;

                half liquidFresnel = pow(1.0 - NdotV, 4.0);
                half3 specFresnel = liquidFresnel * 0.05;

                half3 finalColor = ambient + diffuse + specColor + specFresnel;

                if (_UseRefraction > 0.5)
                {
                    half2 screenUV = i.screenPos.xy / i.screenPos.w;
                    half2 refractionOffset = (N.xz * (1.0 - NdotV)) * _RefractionStrength;
                    half3 sceneColor = SampleSceneColor(screenUV + refractionOffset);
                    finalColor = lerp(sceneColor, finalColor, alpha);
                    alpha = 1.0;
                }

                return half4(finalColor, alpha);
            }
            ENDHLSL
        }
    }
}
