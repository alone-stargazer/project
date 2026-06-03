Shader "Custom/ChestWood"
{
    Properties
    {
        //Main Maps
        [MainTexture] _BaseMap("Albedo (RGB) / Alpha (A)", 2D) = "white" {}
        [MainColor]   _BaseColor("Base Color Tint", Color) = (0.55, 0.35, 0.18, 1.0)

        [NoScaleOffset] _MetallicGlossMap("Metallic (R) / Smoothness (A)", 2D) = "white" {}
        _Metallic("Metallic Strength", Range(0, 1)) = 0.15
        _Smoothness("Smoothness Strength", Range(0, 1)) = 0.35

        [NoScaleOffset] _BumpMap("Normal Map", 2D) = "bump" {}
        _BumpScale("Normal Intensity", Range(0, 2)) = 1.0

        [NoScaleOffset] _OcclusionMap("Ambient Occlusion (G)", 2D) = "white" {}
        _OcclusionStrength("AO Strength", Range(0, 1)) = 1.0

        [HDR] _EmissionColor("Emission Color", Color) = (0, 0, 0, 0)
        [NoScaleOffset] _EmissionMap("Emission Map (RGB)", 2D) = "white" {}

        //Rendering
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull Mode", Float) = 2
        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [ToggleOff] _EnvironmentReflections("Environment Reflections", Float) = 1.0
        _Cutoff("Alpha Cutoff", Range(0, 1)) = 0.5

        //Stencil / Advanced
        [HideInInspector] _Surface("__surface", Float) = 0
        [HideInInspector] _Blend("__blend", Float) = 0
        [HideInInspector] _AlphaClip("__clip", Float) = 0
        [HideInInspector] _SrcBlend("__src", Float) = 1
        [HideInInspector] _DstBlend("__dst", Float) = 0
        [HideInInspector] _ZWrite("__zw", Float) = 1
        [HideInInspector] _QueueOffset("__queue_offset", Float) = 0
        [HideInInspector] _ReceiveShadows("__receive_shadows", Float) = 1
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "Lit"
            "IgnoreProjector" = "True"
        }

        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 4.5

            //Shader Keywords
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local _ENVIRONMENTREFLECTIONS_OFF

            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _ALPHAPREMULTIPLY_ON
            #pragma shader_feature_local_fragment _EMISSION
            #pragma shader_feature_local_fragment _OCCLUSIONMAP
            #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //URP Keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _FORWARD_PLUS
            #pragma multi_compile _ LOD_FADE_CROSSFADE

            //Vertex / Fragment
            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

            //URP Core Includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"

            //  CBUFFER — Material Properties
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half4 _EmissionColor;
                half _Metallic;
                half _Smoothness;
                half _BumpScale;
                half _OcclusionStrength;
                half _Cutoff;
            CBUFFER_END

            //  TEXTURES
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap);    
            SAMPLER(sampler_BumpMap);
            TEXTURE2D(_MetallicGlossMap); 
            SAMPLER(sampler_MetallicGlossMap);
            TEXTURE2D(_EmissionMap);
            SAMPLER(sampler_EmissionMap);
            TEXTURE2D(_OcclusionMap);
            SAMPLER(sampler_OcclusionMap);

            //  VERTEX INPUT
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
                float2 lightmapUV : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;

                // TBN (world-space) and view direction
                float3 positionWS : TEXCOORD1;
                half3  normalWS : TEXCOORD2;
                float4 tangentWS : TEXCOORD3;
                float3 viewDirWS : TEXCOORD4;

                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 5);

                #if defined(_ADDITIONAL_LIGHTS_VERTEX) || !defined(_ADDITIONAL_LIGHTS)
                    half4 fogFactorAndVertexLight : TEXCOORD6;
                #else
                    half  fogFactor : TEXCOORD6;
                #endif

                float4 shadowCoord : TEXCOORD7;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            //  VERTEX SHADER
            Varyings LitPassVertex(Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                //Object -> World
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs   normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                //Output
                output.positionCS = vertexInput.positionCS;
                output.positionWS = vertexInput.positionWS;
                output.normalWS = normalInput.normalWS;
                real sign = input.tangentOS.w * GetOddNegativeScale();
                output.tangentWS = half4(normalInput.tangentWS.xyz, sign);
                output.viewDirWS = GetWorldSpaceNormalizeViewDir(vertexInput.positionWS);

                output.uv            = input.uv;
                OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.lightmapUV);
                OUTPUT_SH(output.normalWS.xyz, output.vertexSH);

                //Fog + Vertex Lights
                #if defined(_ADDITIONAL_LIGHTS_VERTEX) || !defined(_ADDITIONAL_LIGHTS)
                    half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
                    half  fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
                    output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
                #else
                    output.fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
                #endif

                output.shadowCoord = TransformWorldToShadowCoord(vertexInput.positionWS);
                return output;
            }

            //  HELPER — Unpack Normal
            half3 UnpackNormalScale(Texture2D t, SamplerState s, float2 uv, half scale)
            {
                half4 packed = SAMPLE_TEXTURE2D(t, s, uv);
                #if defined(UNITY_NO_DXT5nm)
                    half3 normal = UnpackNormalRGB(packed, scale);
                #else
                    half3 normal = UnpackNormal(packed);
                    normal.xy *= scale;
                #endif

                return normal.z > 0.999h ? half3(0, 0, 1) : normal;
            }

            //  FRAGMENT SHADER — PBR Lighting
            half4 LitPassFragment(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                //Surface Data
                float2 uv = input.uv;

                //Albedo
                half4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
                albedoAlpha *= _BaseColor;

                #if defined(_ALPHATEST_ON)
                    clip(albedoAlpha.a - _Cutoff);
                #endif

                // Metallic / Smoothness
                #if defined(_METALLICSPECGLOSSMAP)
                    half4 metallicSmoothness = SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, uv);
                    half metallic = metallicSmoothness.r * _Metallic;
                    half smoothness = metallicSmoothness.a * _Smoothness;
                #else
                    half metallic = _Metallic;
                    half smoothness = _Smoothness;
                #endif

                // Normal
                #if defined(_NORMALMAP)
                    half3 normalTS = UnpackNormalScale(_BumpMap, sampler_BumpMap, uv, _BumpScale);
                #else
                    half3 normalTS = half3(0, 0, 1);
                #endif

                // Ambient Occlusion
                #if defined(_OCCLUSIONMAP)
                    half ao = lerp(1.0h, SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g, _OcclusionStrength);
                #else
                    half ao = 1.0h;
                #endif

                //Build InputData
                InputData inputData = (InputData)0;
                inputData.positionWS = input.positionWS;
                inputData.positionCS = input.positionCS;
                inputData.normalWS = normalize(input.normalWS);

                // Normal mapping (tangent -> world)
                #if defined(_NORMALMAP)
                    float sgn = input.tangentWS.w;
                    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
                    inputData.normalWS = TransformTangentToWorld(
                        normalTS, half3x3(input.tangentWS.xyz, bitangent, input.normalWS.xyz)
                    );
                    inputData.normalWS = normalize(inputData.normalWS);
                #endif

                inputData.viewDirectionWS = SafeNormalize(input.viewDirWS);
                inputData.shadowCoord = TransformWorldToShadowCoord(input.positionWS);

                //Fog
                #if defined(_ADDITIONAL_LIGHTS_VERTEX) || !defined(_ADDITIONAL_LIGHTS)
                    inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactorAndVertexLight.x);
                    inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
                #else
                    inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactor);
                #endif

                inputData.bakedGI = SAMPLE_GI(
                    input.lightmapUV,
                    input.vertexSH,
                    inputData.normalWS
                );

                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
                inputData.shadowMask = SAMPLE_SHADOWMASK(input.lightmapUV);

                //SurfaceData
                SurfaceData surfaceData = (SurfaceData)0;
                surfaceData.albedo = albedoAlpha.rgb;
                surfaceData.alpha = albedoAlpha.a;
                surfaceData.metallic = metallic;
                surfaceData.smoothness = smoothness;
                surfaceData.normalTS = float3(0, 0, 1); // already applied in world space
                surfaceData.occlusion = ao;

                #if defined(_EMISSION)
                    half3 emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, uv).rgb * _EmissionColor.rgb;
                    surfaceData.emission = emission;
                #else
                    surfaceData.emission = 0;
                #endif

                surfaceData.specular = half3(0.04, 0.04, 0.04); // default non-metal F0

                //PBR Lighting
                half4 color = UniversalFragmentPBR(inputData, surfaceData);

                //Fog + Output
                color.rgb = MixFog(color.rgb, inputData.fogCoord);
                return color;
            }
            ENDHLSL
        }

        //Shadow Caster
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 4.5
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            float3 _LightDirection;
            float3 _LightPosition;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            half _Cutoff;
            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);

            Varyings ShadowPassVertex(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);

                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                float4 positionCS;

                #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                    float3 lightDirectionWS = normalize(_LightPosition - positionWS);
                    positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
                #else
                    positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));
                #endif

                #if UNITY_REVERSED_Z
                    positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #else
                    positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #endif

                output.positionCS = positionCS;
                output.uv = input.uv;
                return output;
            }

            half4 ShadowPassFragment(Varyings input) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(input);
                #if defined(_ALPHATEST_ON)
                    half alpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a * _BaseColor.a;
                    clip(alpha - _Cutoff);
                #endif
                return 0;
            }
            ENDHLSL
        }

        //Depth Only
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask 0
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 4.5
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            half _Cutoff;
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            Varyings DepthOnlyVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;
                return output;
            }

            half4 DepthOnlyFragment(Varyings input) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(input);
                #if defined(_ALPHATEST_ON)
                    half alpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a * _BaseColor.a;
                    clip(alpha - _Cutoff);
                #endif
                return 0;
            }
            ENDHLSL
        }

        //Depth Normals
        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode" = "DepthNormals" }

            ZWrite On
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 4.5
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                half3  normalWS : TEXCOORD1;
                float4 tangentWS : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            half  _BumpScale;
            half  _Cutoff;
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap);
            SAMPLER(sampler_BumpMap);

            Varyings DepthNormalsVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;

                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                output.normalWS = normalInput.normalWS;
                real sign = input.tangentOS.w * GetOddNegativeScale();
                output.tangentWS = half4(normalInput.tangentWS.xyz, sign);

                return output;
            }

            half4 DepthNormalsFragment(Varyings input) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(input);

                #if defined(_ALPHATEST_ON)
                    half alpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a * _BaseColor.a;
                    clip(alpha - _Cutoff);
                #endif

                #if defined(_NORMALMAP)
                    half4 packed = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv);
                    half3 normalTS = UnpackNormal(packed);
                    normalTS.xy *= _BumpScale;

                    float sgn = input.tangentWS.w;
                    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
                    half3 normalWS = TransformTangentToWorld(
                        normalTS, half3x3(input.tangentWS.xyz, bitangent, input.normalWS.xyz)
                    );
                #else
                    half3 normalWS = normalize(input.normalWS);
                #endif

                return half4(normalize(normalWS), 0);
            }
            ENDHLSL
        }

        //Meta (for Lightmapping / GI)
        Pass
        {
            Name "Meta"
            Tags { "LightMode" = "Meta" }

            Cull Off

            HLSLPROGRAM
            #pragma target 4.5
            #pragma shader_feature_local_fragment _EMISSION
            #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma vertex UniversalVertexMeta
            #pragma fragment UniversalFragmentMetaLit

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MetaInput.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half4 _EmissionColor;
                half _Metallic;
                half _Smoothness;
                half _Cutoff;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_MetallicGlossMap);
            SAMPLER(sampler_MetallicGlossMap);
            TEXTURE2D(_EmissionMap);
            SAMPLER(sampler_EmissionMap);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float2 lightmapUV : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            Varyings UniversalVertexMeta(Attributes input)
            {
                Varyings output;
                output.positionCS = UnityMetaVertexPosition(input.positionOS.xyz, input.lightmapUV, input.lightmapUV);
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                return output;
            }

            half4 UniversalFragmentMetaLit(Varyings input) : SV_Target
            {
                float2 uv = input.uv;

                half4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv) * _BaseColor;
                #if defined(_ALPHATEST_ON)
                    clip(albedoAlpha.a - _Cutoff);
                #endif

                #if defined(_METALLICSPECGLOSSMAP)
                    half4 ms = SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, uv);
                    half metallic = ms.r * _Metallic;
                    half smoothness = ms.a * _Smoothness;
                #else
                    half metallic = _Metallic;
                    half smoothness = _Smoothness;
                #endif

                MetaInput metaInput;
                metaInput.Albedo = albedoAlpha.rgb;
                metaInput.Emission = half3(0, 0, 0);

                #if defined(_EMISSION)
                    metaInput.Emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, uv).rgb * _EmissionColor.rgb;
                #else
                    metaInput.Emission = 0;
                #endif

                return UnityMetaFragment(metaInput);
            }
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    CustomEditor "UnityEditor.Rendering.Universal.ShaderGUI.BaseShaderGUI"
}
