Shader "Custom/URP_StonePillar_PBR"
{
    Properties
    {
        //Albedo
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        [MainColor]  _BaseColor("Color Tint", Color) = (0.8, 0.75, 0.65, 1)

        //Metallic / Smoothness (R=Metallic, A=Smoothness)
        [NoScaleOffset] _MetallicGlossMap("Metallic(R) Smoothness(A)", 2D) = "white" {}
        _Smoothness("Smoothness Scale", Range(0, 1)) = 1.0
        _Metallic("Metallic Scale", Range(0, 1)) = 1.0

        //Normal
        [NoScaleOffset][Normal] _BumpMap("Normal Map", 2D) = "bump" {}
        _BumpScale("Normal Strength", Range(0, 2)) = 1.0

        //Emission
        [NoScaleOffset] _EmissionMap("Emission", 2D) = "black" {}
        [HDR] _EmissionColor("Emission Tint", Color) = (0, 0, 0, 1)

        //Ambient Occlusion
        [NoScaleOffset] _OcclusionMap("Ambient Occlusion", 2D) = "white" {}
        _OcclusionStrength("AO Strength", Range(0, 1)) = 1.0

        //RenderState (hidden)
        [HideInInspector] _Surface("__surface", Float) = 0
        [HideInInspector] _Blend("__blend", Float) = 0
        [HideInInspector] _Cull("__cull", Float) = 2
        [HideInInspector] _AlphaClip("__clip", Float) = 0
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "Lit"
            "IgnoreProjector" = "True"
            "ShaderModel" = "4.5"
        }

        LOD 300

        //  Pass 0 每 Forward Lit
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            Cull Back
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM
            #pragma target 4.5

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            #pragma vertex   vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv  : TEXCOORD0;
                float2 lightmapUV : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv  : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float4 tangentWS : TEXCOORD3;                
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 5);
                half3  fogFactor : TEXCOORD6;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_MetallicGlossMap);
            SAMPLER(sampler_MetallicGlossMap);
            TEXTURE2D(_BumpMap);
            SAMPLER(sampler_BumpMap);
            TEXTURE2D(_EmissionMap);
            SAMPLER(sampler_EmissionMap);
            TEXTURE2D(_OcclusionMap);
            SAMPLER(sampler_OcclusionMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half4 _EmissionColor;
                half _BumpScale;
                half _Smoothness;
                half _Metallic;
                half _OcclusionStrength;
            CBUFFER_END

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);

                VertexPositionInputs posInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs   nrmInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                output.positionCS = posInput.positionCS;
                output.positionWS = posInput.positionWS;
                output.normalWS = nrmInput.normalWS;
                output.tangentWS = float4(nrmInput.tangentWS, input.tangentOS.w);
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                output.fogFactor = ComputeFogFactor(posInput.positionCS.z);

                OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.lightmapUV);
                OUTPUT_SH(output.normalWS.xyz, output.vertexSH);

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);

                half4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half4 albedo  = albedoAlpha * _BaseColor;

                half4 metalSmooth = SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, input.uv);
                half  metallic = metalSmooth.r * _Metallic;
                half  smoothness = metalSmooth.a * _Smoothness;

                half4 normalTS = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv);
                half3 normal = UnpackNormalScale(normalTS, _BumpScale);
                float3 bitangent = input.tangentWS.w * cross(input.normalWS, input.tangentWS.xyz);
                half3 normalWS = normalize(
                    normal.x * input.tangentWS.xyz +
                    normal.y * bitangent +
                    normal.z * input.normalWS
                );

                half4 emissionTex = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, input.uv);
                half3 emission = emissionTex.rgb * _EmissionColor.rgb;

                half aoRaw = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, input.uv).g;
                half ao = lerp(1.0, aoRaw, _OcclusionStrength);

                half oneMinusRefl = 1.0 - smoothness;
                half roughness = oneMinusRefl * oneMinusRefl;

                half3 specular = lerp(kDieletricSpec.rgb, albedo.rgb, metallic);
                half3 diffuse = albedo.rgb * (1.0 - metallic);

                diffuse  *= ao;
                emission *= ao;

                InputData inputData = (InputData)0;
                inputData.positionWS = input.positionWS;
                inputData.normalWS = normalWS;
                inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                inputData.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                inputData.fogCoord  = input.fogFactor;
                inputData.vertexLighting = half3(0, 0, 0);
                inputData.bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, normalWS);
                inputData.normalizedScreenSpaceUV  = GetNormalizedScreenSpaceUV(input.positionCS);
                inputData.shadowMask = SAMPLE_SHADOWMASK(input.lightmapUV);

                SurfaceData surfaceData = (SurfaceData)0;
                surfaceData.albedo  = diffuse;
                surfaceData.specular = specular;
                surfaceData.metallic = metallic;
                surfaceData.smoothness = smoothness;
                surfaceData.normalTS = normal;
                surfaceData.emission = emission;
                surfaceData.occlusion = ao;
                surfaceData.alpha = albedoAlpha.a * _BaseColor.a;
                surfaceData.clearCoatMask = 0;
                surfaceData.clearCoatSmoothness = 0;

                half4 color = UniversalFragmentPBR(inputData, surfaceData);
                color.rgb = MixFog(color.rgb, inputData.fogCoord);

                return color;
            }

            ENDHLSL
        }

        //  Pass 1 每 Shadow Caster (simplified, no LerpWhiteTo)
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM
            #pragma target 4.5
            #pragma multi_compile_instancing

            #pragma vertex   ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct AttributesShadow
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VaryingsShadow
            {
                float4 positionCS : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            VaryingsShadow ShadowPassVertex(AttributesShadow input)
            {
                VaryingsShadow output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                return output;
            }

            half4 ShadowPassFragment(VaryingsShadow input) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(input);
                return 0;
            }
            ENDHLSL
        }

        //  Pass 2 每 Depth Only
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask 0
            Cull Back

            HLSLPROGRAM
            #pragma target 4.5
            #pragma multi_compile_instancing

            #pragma vertex   DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct AttributesDepth
            {
                float4 positionOS : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VaryingsDepth
            {
                float4 positionCS : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            VaryingsDepth DepthOnlyVertex(AttributesDepth input)
            {
                VaryingsDepth output = (VaryingsDepth)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                return output;
            }

            half4 DepthOnlyFragment(VaryingsDepth input) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(input);
                return 0;
            }
            ENDHLSL
        }

        //  Pass 3 每 Meta (lightmap baking, no SpecularColor)
        Pass
        {
            Name "Meta"
            Tags { "LightMode" = "Meta" }

            Cull Off

            HLSLPROGRAM
            #pragma target 4.5
            #pragma multi_compile_instancing

            #pragma vertex MetaVertex
            #pragma fragment MetaPassFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MetaInput.hlsl"

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_MetallicGlossMap);
            SAMPLER(sampler_MetallicGlossMap);
            TEXTURE2D(_EmissionMap);
            SAMPLER(sampler_EmissionMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half4 _EmissionColor;
                half _Smoothness;
                half _Metallic;
            CBUFFER_END

            struct AttributesMeta
            {
                float4 positionOS : POSITION;
                float2 uv0 : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float2 uv2 : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VaryingsMeta
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            VaryingsMeta MetaVertex(AttributesMeta input)
            {
                VaryingsMeta output = (VaryingsMeta)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                output.positionCS = MetaVertexPosition(input.positionOS, input.uv1, input.uv2,
                    unity_LightmapST, unity_DynamicLightmapST);
                output.uv = TRANSFORM_TEX(input.uv0, _BaseMap);
                return output;
            }

            half4 MetaPassFragment(VaryingsMeta input) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(input);

                half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;
                half4 emissionTex = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, input.uv);

                MetaInput metaInput;
                metaInput.Albedo = albedo.rgb;
                metaInput.Emission = emissionTex.rgb * _EmissionColor.rgb;

                return MetaFragment(metaInput);
            }
            ENDHLSL
        }
    }

    FallBack "Universal Render Pipeline/Lit"
}
