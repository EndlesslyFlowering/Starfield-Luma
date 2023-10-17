#include "../shared.hlsl"
#include "../color.hlsl"
#include "RootSignature.hlsl"

Texture2D<float4> inputTexture  : register(t0, space8);
SamplerState inputSampler : register(s0, space8);

struct PSInputs
{
	float2 uv  : TEXCOORD0;
	float4 pos : SV_Position;
};

#if SDR_USE_GAMMA_2_2
	#define GAMMA_TO_LINEAR(x) pow(x, 2.2f)
	#define LINEAR_TO_GAMMA(x) pow(x, 1.f / 2.2f)
#else
	#define GAMMA_TO_LINEAR(x) gamma_sRGB_to_linear(x)
	#define LINEAR_TO_GAMMA(x) gamma_linear_to_sRGB(x)
#endif

[RootSignature(ShaderRootSignature)]
float4 PS(PSInputs inputs) : SV_Target
{
	float4 color = inputTexture.Sample(inputSampler, inputs.uv);

#if defined(OUTPUT_TO_R16G16B16A16_SFLOAT) \
 || defined(OUTPUT_TO_R10G10B10A2)

	if (HdrDllPluginConstants.IsAtEndOfFrame)
	{
#if defined(OUTPUT_TO_R16G16B16A16_SFLOAT)
		if (HdrDllPluginConstants.DisplayMode == 2) // HDR scRGB
		{
#if 1
			// Clamp to AP0D65 to avoid invalid colors
			color.rgb = BT709_To_AP0D65(color.rgb);
			color.rgb = max(color.rgb, 0.f);
			color.rgb = AP0D65_To_BT709(color.rgb);
#endif
		}
		else if (HdrDllPluginConstants.DisplayMode == -1) // SDR on scRGB HDR (gamma to linear space conversion)
		{
#if !SDR_LINEAR_INTERMEDIARY
			color.rgb = GAMMA_TO_LINEAR(color.rgb);
#endif // !SDR_LINEAR_INTERMEDIARY

#if CLAMP_INPUT_OUTPUT || 1
			color.rgb = saturate(color.rgb); // Remove any non SDR color, this mode is just meant for debugging SDR in HDR
#endif // CLAMP_INPUT_OUTPUT || 1
			const float paperWhite = HdrDllPluginConstants.HDRGamePaperWhiteNits / WhiteNits_sRGB;
			color.rgb *= paperWhite;
		}
#endif // defined(OUTPUT_TO_R16G16B16A16_SFLOAT)

#if defined(OUTPUT_TO_R10G10B10A2)
		if (HdrDllPluginConstants.DisplayMode == 1) // HDR10 PQ BT.2020
		{
			// There is no need to clamp values above 1 here as the output buffer is unorm10 so it will clip anything beyond 0-1.
			// Negative values need to be clamped though to avoid doing pow on a negative values.
			color.rgb = BT709_To_BT2020(color.rgb);
			color.rgb = max(color.rgb, 0.f);
			color.rgb = Linear_to_PQ(color.rgb, PQMaxWhitePoint);
		}
#if SDR_LINEAR_INTERMEDIARY
		else if (HdrDllPluginConstants.DisplayMode == 0) // SDR (linear to gamma space conversion)
		{

			color.rgb = LINEAR_TO_GAMMA(color.rgb);
		}
#endif // SDR_LINEAR_INTERMEDIARY

#endif // defined(OUTPUT_TO_R10G10B10A2)

	}

#endif // defined(OUTPUT_TO_R16G16B16A16_SFLOAT) || defined(OUTPUT_TO_R10G10B10A2)

	return color;
}
