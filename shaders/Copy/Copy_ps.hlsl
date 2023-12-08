#include "../shared.hlsl"
#include "../math.hlsl"
#include "../color.hlsl"
#include "RootSignature.hlsl"

// clamp max brightness to a percentage of the user chosen peak brightness when not developing
// so it doesn't overshoot too much (film grain can go beyond the limit). Useful in case the user
// had set a lower peak than their display supports just because they don't want the game too bright.
#if !DEVELOPMENT
	#define PEAK_BRIGHTNESS_THRESHOLD       1.05f
	#define PEAK_BRIGHTNESS_THRESHOLD_SCRGB (PEAK_BRIGHTNESS_THRESHOLD / WhiteNits_sRGB)
	#define PEAK_BRIGHTNESS_THRESHOLD_HDR10 (PEAK_BRIGHTNESS_THRESHOLD / PQMaxNits)
#else
	#define PEAK_BRIGHTNESS_THRESHOLD       FLT_MAX
	#define PEAK_BRIGHTNESS_THRESHOLD_SCRGB FLT_MAX
	#define PEAK_BRIGHTNESS_THRESHOLD_HDR10 FLT_MAX
#endif


Texture2D<float4> inputTexture  : register(t0, space8);
SamplerState inputSampler : register(s0, space8);

struct PSInputs
{
	float2 uv  : TEXCOORD0;
	float4 pos : SV_Position;
};

#if SDR_USE_GAMMA_2_2 // NOTE: these gamma formulas should use their mirrored versions in the CLAMP_INPUT_OUTPUT_TYPE < 3 case
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

#if defined(OUTPUT_TO_R16G16B16A16_SFLOAT) || defined(OUTPUT_TO_R10G10B10A2)

	if (HdrDllPluginConstants.IsAtEndOfFrame)
	{
		color.a = 1.f; // Force alpha to 1 for extra safety

#if defined(OUTPUT_TO_R16G16B16A16_SFLOAT)
		if (HdrDllPluginConstants.DisplayMode == 2) // HDR scRGB
		{
			// safety clamp to BT.2020 as Windows may turn pixels that are low brightness (Rec.601 luminance <= 0) and outside of BT.2020 into black pixels
			// this only happens in software composition though (Composed Flip).
#if CLAMP_INPUT_OUTPUT_TYPE == 1
			//TODO: proper gamut mapping here and in the other cases
			color.rgb = gamut_clip_project_to_L_cusp(color.rgb, false, true, false);
#elif CLAMP_INPUT_OUTPUT_TYPE >= 2
			color.rgb = BT709_To_BT2020(color.rgb);
			// Note: this might cause a little hue shift
			color.rgb = clamp(color.rgb, 0.f, HdrDllPluginConstants.HDRPeakBrightnessNits * PEAK_BRIGHTNESS_THRESHOLD_SCRGB);
			color.rgb = BT2020_To_BT709(color.rgb);
#endif // CLAMP_INPUT_OUTPUT_TYPE
		}
		else if (HdrDllPluginConstants.DisplayMode == -1) // SDR on scRGB HDR (gamma to linear space conversion)
		{
#if !SDR_LINEAR_INTERMEDIARY
			color.rgb = GAMMA_TO_LINEAR(color.rgb);
#endif // !SDR_LINEAR_INTERMEDIARY

#if CLAMP_INPUT_OUTPUT_TYPE == 1
			color.rgb = gamut_clip_project_to_L_cusp(color.rgb, false, false, false);
#endif // CLAMP_INPUT_OUTPUT_TYPE
			color.rgb = saturate(color.rgb); // Remove any non SDR color (independently of CLAMP_INPUT_OUTPUT_TYPE), this mode is just meant for debugging SDR in HDR
			const float paperWhite = HdrDllPluginConstants.HDRGamePaperWhiteNits / WhiteNits_sRGB;
			color.rgb *= paperWhite;
		}
#endif // defined(OUTPUT_TO_R16G16B16A16_SFLOAT)

#if defined(OUTPUT_TO_R10G10B10A2)
		if (HdrDllPluginConstants.DisplayMode == 1) // HDR10 PQ BT.2020
		{
			// There is no need to clamp values above 1 here as the output buffer is unorm10 so it will clip anything beyond 0-1.
			// Negative values need to be clamped though to avoid doing pow on a negative values ("Linear_to_PQ()"" already does this).
			color.rgb /= PQMaxWhitePoint;
#if CLAMP_INPUT_OUTPUT_TYPE == 1
			color.rgb = gamut_clip_project_to_L_cusp(color.rgb, false, true, true);
#elif CLAMP_INPUT_OUTPUT_TYPE >= 2
            color.rgb = BT709_To_BT2020(color.rgb);
			// Note: this might cause a little hue shift
			color.rgb = min(color.rgb, HdrDllPluginConstants.HDRPeakBrightnessNits * PEAK_BRIGHTNESS_THRESHOLD_HDR10);
#endif // CLAMP_INPUT_OUTPUT_TYPE
			color.rgb = Linear_to_PQ(color.rgb);
		}
#if SDR_LINEAR_INTERMEDIARY
		else if (HdrDllPluginConstants.DisplayMode == 0) // SDR (linear to gamma space conversion)
		{
#if CLAMP_INPUT_OUTPUT_TYPE == 1
			color.rgb = gamut_clip_project_to_L_cusp(color.rgb, false, false, false);
#endif // CLAMP_INPUT_OUTPUT_TYPE
#if SDR_USE_GAMMA_2_2 // Avoid negative pow
			color.rgb = max(color.rgb, 0.f);
#endif
			// No need to clamp in SDR as the output buffer is unorm so it will clip anything beyond 0-1.
			color.rgb = LINEAR_TO_GAMMA(color.rgb);
		}
#endif // SDR_LINEAR_INTERMEDIARY

#endif // defined(OUTPUT_TO_R10G10B10A2)
	}

#endif // defined(OUTPUT_TO_R16G16B16A16_SFLOAT) || defined(OUTPUT_TO_R10G10B10A2)

	return color;
}
