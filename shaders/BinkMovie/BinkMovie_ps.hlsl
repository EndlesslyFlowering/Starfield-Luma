#include "../shared.hlsl"
#include "../color.hlsl"
#include "RootSignature.hlsl"

Texture2D<float> TexY  : register(t0, space8);
Texture2D<float> TexCb : register(t2, space8);
Texture2D<float> TexCr : register(t1, space8);

SamplerState Sampler0 : register(s0, space8);

struct PSInputs
{
	float4 pos : SV_Position;
	float2 TEXCOORD : TEXCOORD0;
};

//TODO: expose to user? At least the on/off bool, and maybe the shoulder pow and max nits, but it's probably better to simply pick a default that looks nice on most movies.
static const bool BinkVideosAutoHDR = true;
static const float BinkVideosAutoHDRMaxOutputNits = 750.f;
// The higher it is, the "later" highlights start
static const float BinkVideosAutoHDRShoulderPow = 2.75f; // A somewhat conservative value

// AutoHDR pass to generate some HDR brightess out of an SDR signal (it has no effect if HDR is not engaged).
// This is hue conserving and only really affects highlights.
// https://github.com/Filoppi/PumboAutoHDR
float3 PumboAutoHDR(float3 Color, float MaxOutputNits, float PaperWhite)
{
	const float SDRRatio = Luminance(Color);
	// Limit AutoHDR brightness, it won't look good beyond a certain level.
	// The paper white multiplier is applied later so we account for that.
	const float AutoHDRMaxWhite = max(min(MaxOutputNits, BinkVideosAutoHDRMaxOutputNits) / PaperWhite, WhiteNits_sRGB) / WhiteNits_sRGB;
	const float AutoHDRShoulderRatio = 1.f - max(1.f - SDRRatio, 0.f);
	const float AutoHDRExtraRatio = pow(AutoHDRShoulderRatio, BinkVideosAutoHDRShoulderPow) * (AutoHDRMaxWhite - 1.f);
	const float AutoHDRTotalRatio = SDRRatio + AutoHDRExtraRatio;
	return Color * (AutoHDRTotalRatio / SDRRatio);
}

[RootSignature(ShaderRootSignature)]
float4 PS(PSInputs inputs) : SV_Target
{
	float Y = TexY.Sample(Sampler0, inputs.TEXCOORD.xy).x;
	float Cb = TexCb.Sample(Sampler0, inputs.TEXCOORD.xy).x;
	float Cr = TexCr.Sample(Sampler0, inputs.TEXCOORD.xy).x;

	float3 color;
	// usually in YCbCr the ranges are (in float):
	// Y:   0.0-1.0
	// Cb: -0.5-0.5
	// Cr: -0.5-0.5
	// but since this is a digital signal (in unsinged 8bit: 0-255) it's now:
	// Y:  0.0-1.0
	// Cb: 0.0-1.0
	// Cr: 0.0-1.0
	// the formula adjusts for that but was for BT.601 limited range while the video is definitely BT.709 full range
	// matrix paramters have been adjusted for BT.709 full range
	color.r = Y - 0.790487825870513916015625f + (Cr * 1.5748f);
	color.g = Y + 0.329009473323822021484375f - (Cb * 0.18732427060604095458984375f) - (Cr * 0.46812427043914794921875f);
	color.b = Y - 0.931438446044921875f       + (Cb * 1.8556f);

	// Clamp for safety as YCbCr<->RGB is not 100% accurate in float and can produce negative/invalid colors,
	// this breaks the UI pass if we are using R16G16B16A16F textures,
	// as UI blending produces invalid pixels if it's blended with an invalid color.
	// Also this is need for the gamma pow.
	color = max(color, 0.f);

#if !SDR_LINEAR_INTERMEDIARY
	if (HdrDllPluginConstants.DisplayMode > 0)
#endif // SDR_LINEAR_INTERMEDIARY
	{
#if SDR_USE_GAMMA_2_2
		color = pow(color, 2.2f);
#else
		color = gamma_sRGB_to_linear(color);
#endif // SDR_USE_GAMMA_2_2

		if (HdrDllPluginConstants.DisplayMode > 0)
		{
			color = BT709_To_WBT2020(color);

			const float paperWhite = HdrDllPluginConstants.HDRGamePaperWhiteNits / WhiteNits_sRGB;
			if (BinkVideosAutoHDR)
				color = PumboAutoHDR(color, HdrDllPluginConstants.HDRPeakBrightnessNits, paperWhite);

			color *= paperWhite; // Use the game brightness, not the UI one, as these are usually videos that are seamless with gameplay
		}
	}

	return float4(color, 1.0f);
}
