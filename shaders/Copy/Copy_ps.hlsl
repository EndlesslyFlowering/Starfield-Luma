#include "../shared.hlsl"
#include "../color.hlsl"
#include "RootSignature.hlsl"

Texture2D<float4> inputTexture  : register(t0, space8);
SamplerState inputSampler : register(s0, space8);

struct PSInputs
{
    float2 uv : TEXCOORD0;
	float4 pos : SV_Position;
};

[RootSignature(ShaderRootSignature)]
float4 PS(PSInputs inputs) : SV_Target
{
	float4 color = inputTexture.Sample(inputSampler, float2(inputs.uv.x, inputs.uv.y));

    if (HdrDllPluginConstants.IsAtEndOfFrame)
	{
        // There is no need to clamp if "CLAMP_INPUT_OUTPUT" is true here as the output buffer is int so it will clip anything beyond 0-1.
        if (HdrDllPluginConstants.DisplayMode == 1)
        {
            color.rgb = linear_to_PQ(BT709_To_BT2020(color.rgb));
        }
#if SDR_LINEAR_INTERMEDIARY
        else if (HdrDllPluginConstants.DisplayMode == 0)
        {
#if SDR_USE_GAMMA_2_2
		    color.rgb = pow(color.rgb, 1.f / 2.2f);
#else
		    color.rgb = gamma_linear_to_sRGB(color.rgb);
#endif // SDR_USE_GAMMA_2_2
        }
#else // SDR_LINEAR_INTERMEDIARY
        else if (HdrDllPluginConstants.DisplayMode == 0)
        {
#if SDR_USE_GAMMA_2_2
		    color.rgb = pow(color.rgb, 2.2f);
#else
		    color.rgb = gamma_sRGB_to_linear(color.rgb);
#endif // SDR_USE_GAMMA_2_2
        }
#endif // SDR_LINEAR_INTERMEDIARY
        if (HdrDllPluginConstants.DisplayMode == -1)
        {
#if 1
		    color.rgb = saturate(color.rgb); // Remove any non SDR color, this mode is just meant for debugging SDR in HDR
#endif
	    	const float paperWhite = HdrDllPluginConstants.HDRGamePaperWhiteNits / WhiteNits_sRGB;
            color.rgb *= paperWhite;
        }
    }

    return color;
}


//--

// Texture2D<float4> _8 : register(t0, space8);
// SamplerState _11 : register(s0, space8);

// static float4 TEXCOORD;
// static float4 SV_Target;

// struct SPIRV_Cross_Input
// {
//     float4 TEXCOORD : TEXCOORD0;
// };

// struct SPIRV_Cross_Output
// {
//     float4 SV_Target : SV_Target0;
// };

// void frag_main()
// {
//     float4 _31 = _8.Sample(_11, float2(TEXCOORD.x, TEXCOORD.y));
//     SV_Target.x = _31.x;
//     SV_Target.y = _31.y;
//     SV_Target.z = _31.z;
//     SV_Target.w = _31.w;
// }

// SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
// {
//     TEXCOORD = stage_input.TEXCOORD;
//     frag_main();
//     SPIRV_Cross_Output stage_output;
//     stage_output.SV_Target = SV_Target;
//     return stage_output;
// }
