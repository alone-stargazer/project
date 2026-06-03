Shader "bottle/RealisticGlass"
{
    Properties
    {
        [Header(Refraction)]
        _RefractionStrength ("Refraction Strength", Range(0.0, 0.1)) = 0.02
        _IndexOfRefraction ("Index of Refraction", Range(1.0, 2.5)) = 1.45

        [Header(Reflection)]
        [NoScaleOffset]_CubeMap ("Environment Cubemap", CUBE) = "" {}
        _Reflectivity ("Reflectivity", Range(0.0, 1.0)) = 0.3
        _FresnelPower ("Fresnel Power", Range(0.5, 8.0)) = 3.0

        [Header(Specular)]
        _Smoothness ("Smoothness", Range(0.0, 1.0)) = 0.95
        _SpecularIntensity ("Specular Intensity", Range(0.0, 2.0)) = 0.6

        [Header(Glass Body)]
        _GlassTint ("Glass Tint", Color) = (0.85, 0.92, 0.95, 1.0)
        _ThicknessScale ("Thickness Scale", Range(0.0, 2.0)) = 0.5
        _AbsorptionColor ("Absorption Color", Color) = (0.1, 0.3, 0.2, 1.0)
        _AbsorptionStrength ("Absorption Strength", Range(0.0, 1.0)) = 0.3

        [Header(Normal Map)]
        [NoScaleOffset]_NormalMap ("Normal Map", 2D) = "bump" {}
        _NormalStrength ("Normal Strength", Range(0.0, 2.0)) = 0.3

        [Header(Rim)]
        _RimColor ("Rim Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _RimPower ("Rim Power", Range(0.5, 8.0)) = 2.5
        _RimIntensity ("Rim Intensity", Range(0.0, 1.0)) = 0.2
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "IgnoreProjector" = "True"
        }
        LOD 200

        // Refraction pass: writes into depth so opaque texture excludes glass itself
        Pass
        {
            Name "DepthWrite"
            Tags { "LightMode" = "DepthOnly" }
            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            #pragma vertex DepthVert
            #pragma fragment DepthFrag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

            Varyings DepthVert(Attributes v)
            {
                Varyings o;
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                return o;
            }

            half4 DepthFrag(Varyings i) : SV_Target
            {
                return 0;
            }
            ENDHLSL
        }

        // Main glass pass
        Pass
        {
            Name "Glass"
            Tags { "LightMode" = "UniversalForward" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            TEXTURECUBE(_CubeMap);
            SAMPLER(sampler_CubeMap);

            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);

            CBUFFER_START(UnityPerMaterial)
            half _RefractionStrength;
            half _IndexOfRefraction;
            half _Reflectivity;
            half _FresnelPower;
            half _Smoothness;
            half _SpecularIntensity;
            half4 _GlassTint;
            half _ThicknessScale;
            half4 _AbsorptionColor;
            half _AbsorptionStrength;
            half _NormalStrength;
            half4 _RimColor;
            half _RimPower;
            half _RimIntensity;
            CBUFFER_END

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
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 tangentWS : TEXCOORD2;
                float3 viewDirWS : TEXCOORD3;
                float3 viewDirOS : TEXCOORD4;
                float4 screenPos : TEXCOORD5;
                float2 uv : TEXCOORD6;
            };

            // Schlick Fresnel
            half3 FresnelSchlick(half cosTheta, half3 F0)
            {
                return F0 + (1.0 - F0) * pow(max(1.0 - cosTheta, 0.0), _FresnelPower);
            }

            // GGX Normal Distribution Function
            half D_GGX(half NdotH, half roughness)
            {
                half a = roughness * roughness;
                half a2 = a * a;
                half denom = NdotH * NdotH * (a2 - 1.0) + 1.0;
                return a2 / (PI * denom * denom + 0.0001);
            }

            // Smith-Schlick Geometry function
            half G_SmithSchlick(half NdotV, half NdotL, half roughness)
            {
                half k = (roughness + 1.0) * (roughness + 1.0) / 8.0;
                half G1V = NdotV / (NdotV * (1.0 - k) + k);
                half G1L = NdotL / (NdotL * (1.0 - k) + k);
                return G1V * G1L;
            }

            Varyings vert(Attributes v)
            {
                Varyings o;

                VertexPositionInputs positionInputs = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = positionInputs.positionCS;
                o.positionWS = positionInputs.positionWS;
                o.screenPos = ComputeScreenPos(o.positionCS);

                VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normalOS, v.tangentOS);
                o.normalWS = normalInputs.normalWS;
                o.tangentWS = float4(normalInputs.tangentWS, v.tangentOS.w);

                o.viewDirWS = GetWorldSpaceNormalizeViewDir(o.positionWS);
                o.viewDirOS = GetObjectSpaceNormalizeViewDir(v.positionOS);
                o.uv = v.uv;

                return o;
            }

            // Approximate thickness: higher when view direction is perpendicular to the surface normal
            half EstimateThickness(float3 viewDirOS, float3 normalOS)
            {
                half3 backDir = -normalize(viewDirOS);
                half edgeFactor = 1.0 - abs(dot(backDir, normalize(normalOS)));
                return edgeFactor * _ThicknessScale;
            }

            half4 frag(Varyings i) : SV_Target
            {
                // --- Normals ---
                half3 N_ws = normalize(i.normalWS);
                half3 V_ws = normalize(i.viewDirWS);

                // Sample normal map & transform to world space
                half3 normalTS = UnpackNormalScale(
                    SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.uv),
                    _NormalStrength
                );
                half3 B_ws = cross(i.normalWS, i.tangentWS.xyz) * i.tangentWS.w;
                half3x3 TBN = half3x3(i.tangentWS.xyz, B_ws, i.normalWS);
                half3 N = normalize(mul(normalTS, TBN));

                half NdotV = saturate(dot(N, V_ws));

                // --- Fresnel ---
                half F0_glass = ((_IndexOfRefraction - 1.0) / (_IndexOfRefraction + 1.0));
                F0_glass *= F0_glass;
                half3 F0 = half3(F0_glass, F0_glass, F0_glass) * _Reflectivity;
                half3 fresnel = FresnelSchlick(NdotV, F0);

                // --- Refraction ---
                half2 screenUV = i.screenPos.xy / i.screenPos.w;
                half2 refractionOffset = N_ws.xz * _RefractionStrength * (1.0 - NdotV);
                half3 refractedColor = SampleSceneColor(screenUV + refractionOffset);

                // --- Specular (GGX) ---
                Light mainLight = GetMainLight();
                half3 L = mainLight.direction;
                half3 lightColor = mainLight.color;
                half NdotL = saturate(dot(N, L));
                half3 H = normalize(L + V_ws);
                half NdotH = saturate(dot(N, H));

                half roughness = 1.0 - _Smoothness;
                half D = D_GGX(NdotH, roughness);
                half G = G_SmithSchlick(NdotV, NdotL, roughness);
                half3 specular = fresnel * D * G * _SpecularIntensity / max(4.0 * NdotV * NdotL, 0.001);
                half3 directSpecular = specular * lightColor * NdotL * PI;

                // --- Environment Reflection (Cubemap) ---
                half3 reflectDir = reflect(-V_ws, N);
                half3 envReflection = SAMPLE_TEXTURECUBE(_CubeMap, sampler_CubeMap, reflectDir).rgb;
                // Glossy mip for rougher glass
                half mipLevel = roughness * 7.0;
                half3 glossyReflection = SAMPLE_TEXTURECUBE_LOD(
                    _CubeMap, sampler_CubeMap, reflectDir, mipLevel
                ).rgb;
                envReflection = lerp(glossyReflection, envReflection, _Smoothness);
                envReflection *= fresnel * _Reflectivity;

                // --- Thickness-based Absorption (Beer-Lambert) ---
                half thickness = EstimateThickness(i.viewDirOS, i.normalWS);
                half3 absorption = exp(-_AbsorptionColor.rgb * thickness * _AbsorptionStrength * 3.0);
                half3 glassTint = _GlassTint.rgb * absorption;

                // --- Rim Lighting ---
                half rim = pow(1.0 - NdotV, _RimPower) * _RimIntensity;
                half3 rimColor = _RimColor.rgb * rim;

                // --- Compose ---
                half3 baseColor = refractedColor * glassTint;
                half3 finalColor = baseColor + envReflection + directSpecular + rimColor;

                // Alpha: edges more opaque (fresnel-driven)
                half alpha = saturate(lerp(0.15, 0.75, fresnel.r + rim * 0.3));

                return half4(finalColor, alpha);
            }
            ENDHLSL
        }
    }

    FallBack "Universal Render Pipeline/Lit"
}
