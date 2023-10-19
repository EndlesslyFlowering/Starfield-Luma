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
		color.a = 1.f; // Force alpha to 1 for extra safety

#if defined(OUTPUT_TO_R16G16B16A16_SFLOAT)
		if (HdrDllPluginConstants.DisplayMode == 2) // HDR scRGB
		{
			color.rgb = WBT2020_To_BT2020(color.rgb);
			color.rgb = clamp(color.rgb, 0.f, HdrDllPluginConstants.HDRPeakBrightnessNits / IntermediateNormalizationFactor * 1.05f);
			color.rgb = BT2020_To_BT709(color.rgb);
			color.rgb *= 1.25f;
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
			color.rgb = WBT2020_To_BT2020(color.rgb);
			color.rgb /= IntermediateNormalizationFactor;
			color.rgb = clamp(color.rgb, 0.f, HdrDllPluginConstants.HDRPeakBrightnessNits / IntermediateNormalizationFactor * 0.0105f);
			color.rgb = Linear_to_PQ(color.rgb);
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
