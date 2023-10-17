#include "../shared.hlsl"
#include "../color.hlsl"
#include "../math.hlsl"
#include "RootSignature.hlsl"

// 0 None, 1 ShortFuse technique (normalization)
#define LUT_IMPROVEMENT_TYPE (FORCE_VANILLA_LOOK ? 0 : 1)
#define LUT_DEBUG_VALUES false
#if LUT_MAPPING_TYPE == 2
#define DEBUG_COLOR linear_srgb_to_oklab(float3(1.f, 0.f, 1.f)) /*Magenta*/
#else
#define DEBUG_COLOR float3(1.f, 0.f, 1.f) /*Magenta*/
#endif // LUT_MAPPING_TYPE

// These settings goes to influence the LUTs correction process, by determining how LUTs are linearized and how to correct the gamma mismatch baked into the game's look.
// There's many ways these LUTs could have been generated (designed, made):
// -They were made outside of the game on sRGB screens (this assumes that in the game they didn't look as the artists intended them) (sRGB raises blacks compared to 2.2)
// -They were made outside of the game on 2.2 screens (this assumes that in the game they didn't look as the artists intended them)
// -They were made inside of the game with the broken/optimized Bethesda sRGB gamma formula and outputting on sRGB screens
// -They were made inside of the game with the broken/optimized Bethesda sRGB gamma formula and outputting on 2.2 gamma screens (see "SDR_USE_GAMMA_2_2")
//
// Ultimately, it doesn't really matter too much how they were intended by the artists, as what matters is how they appeared in game,
// and we base our LUT correction/normalization process on that.
// Some of these options make LUTs too bright, and some other crush detail around shadow.
#if !SDR_USE_GAMMA_2_2 // sRGB->linear->LUT normalization
	// This assumes the game used the sRGB gamma formula and was meant to be viewed on sRGB gamma displays.
	#define LINEARIZE(x) gamma_sRGB_to_linear(x)
	#define CORRECT_GAMMA(x) x
#else
	#define LINEARIZE(x) pow(x, 2.2f)
	#if GAMMA_CORRECTION_IN_LUTS // 2.2->linear->LUT normalization
		// If we correct gamma in LUTs, there's nothing more to do than linearize (interpret) them as gamma 2.2, while the input coordinates keep using sRGB gamma.
		// This single difference will correct the gamma on output.
		#define CORRECT_GAMMA(x) x
	#else // 2.2->linear->LUT normalization->sRGB->linear
		// If we don't correct gamma in LUTs, we convert them back to sRGB gamma at the end, so that it will match the input coordinates gamma, as they also use sRGB.
		// A further correction step will be done after that to acknowledge the gamma mismatch baked into the game look.
		#if GAMMA_CORRECT_SDR_RANGE_ONLY
			#define CORRECT_GAMMA(x) (gamma_sRGB_to_linear(pow(saturate(x), 1.f / 2.2f)) + (x - saturate(x)))
		#else
			// NOTE: to somehow conserve some HDR colors and not generate NaNs, we are doing inverse pow as gamma on negative numbers.
			// Alternatively we could try to do this in BT.2020, so there's no negative colors.
			#define CORRECT_GAMMA(x) (gamma_sRGB_to_linear(pow(abs(x), 1.f / 2.2f) * (sign(x))))
		#endif // GAMMA_CORRECT_SDR_RANGE_ONLY
	#endif // GAMMA_CORRECTION_IN_LUTS
#endif // SDR_USE_GAMMA_2_2

// Behaviour when the color Lightness goes beyond 1
// -0: Allow lightness above 1
// -1: Revert to original (non-normalized) color
// -2: Clamp lightness to 1
#define LUT_SDR_ON_CLIP 1u
#define LUT_HDR_ON_CLIP 0u

static const float AdditionalNeutralLUTPercentage = 0.f; // ~0.25 might be a good compromise, but this is mostly replaced by "HdrDllPluginConstants.LUTCorrectionStrength"

cbuffer CPushConstantWrapper_ColorGradingMerge : register(b0, space0)
{
	PushConstantWrapper_ColorGradingMerge PcwColorGradingMerge : packoffset(c0);
};

Texture2D<float3> LUT1 : register(t0, space8);
Texture2D<float3> LUT2 : register(t1, space8);
Texture2D<float3> LUT3 : register(t2, space8);
Texture2D<float3> LUT4 : register(t3, space8);
RWTexture3D<float4> OutMixedLUT : register(u0, space8);

struct LUTAnalysis
{
	float3 black;
	float blackY;
	float3 white;
	float whiteY;
	float whiteL;
};

static const uint LUTSizeLog2 = (uint)log2(LUT_SIZE);

// In/Out in pixels
uint3 ThreeToTwoDimensionCoordinates(uint3 UVW)
{
	// 2D LUT extends horizontally.
	const uint U = (UVW.z << LUTSizeLog2) + UVW.x;
	return uint3(U, UVW.y, 0);
}

void AnalyzeLUT(Texture2D<float3> LUT, inout LUTAnalysis Analysis)
{
	Analysis.black = LINEARIZE(LUT.Load(ThreeToTwoDimensionCoordinates(0u)).rgb);
	Analysis.blackY = Luminance(Analysis.black);
	Analysis.white = LINEARIZE(LUT.Load(ThreeToTwoDimensionCoordinates(LUT_MAX_UINT)).rgb);
	Analysis.whiteY = Luminance(Analysis.white);
	Analysis.whiteL = linear_srgb_to_oklab(Analysis.white)[0];
}

// Analyzes each LUT texel and normalizes their range.
// Slow but effective.
float3 PatchLUTColor(Texture2D<float3> LUT, uint3 UVW, float3 neutralLUTColor, bool SDRRange = false)
{
	LUTAnalysis analysis;
	AnalyzeLUT(LUT, analysis);

	const float3 originalLinear = LINEARIZE(LUT.Load(UVW));
	const float3 originalLab = linear_srgb_to_oklab(originalLinear);
	const float3 originalLCh = oklab_to_oklch(originalLab);

	if (analysis.whiteY < analysis.blackY // If LUT is inversed (eg: photo negative) don't do anything
		|| analysis.whiteY - analysis.blackY >= 1.f) // If LUT is full range already nothing to do
	{
#if LUT_MAPPING_TYPE == 2
		return originalLab;
#else
		return originalLinear;
#endif // LUT_MAPPING_TYPE
	}

	// While it unclear how exactly the floor was raised, remove the tint to floor
	// the values to 0. This will remove the haze and tint giving a fuller chroma
	// Sample and hold targetChroma

#if 0 // TODO: Expose or delete
	//TODO: expose these values or find the best defaults. For now we skip these when "HdrDllPluginConstants.GammaCorrection" is on as it's not necessary

	// An additional tweak on top of "HdrDllPluginConstants.LUTCorrectionStrength"
	float fixRaisedBlacksStrength = 1.f /*- HdrDllPluginConstants.DevSetting01*/; // Values between 0 and 1
	//TODO: improve the way "fixRaisedBlacksInputSmoothing" is applied, the curve isn't great now
	// Modulates how much we fix the raised blacks based on how raised they were.
	float fixRaisedBlacksInputSmoothing = lerp(1.f, 1.333f, HdrDllPluginConstants.GammaCorrection); // Values from 1 up, greater is smoother
	float fixRaisedBlacksOutputSmoothing = lerp(1.f, 0.666f, HdrDllPluginConstants.GammaCorrection); // Values from 0 up, smaller than 1 is smoother
	const float3 invertedBlack = 1.f - (pow(analysis.black, lerp(1.f, fixRaisedBlacksInputSmoothing, analysis.black)) * fixRaisedBlacksStrength);
	const float3 blackScaling = lerp(1.f / invertedBlack, 1.f, pow(neutralLUTColor, fixRaisedBlacksOutputSmoothing));
#elif 1 // Original implementation
	const float3 blackScaling = lerp(1.f / (1.f - analysis.black), 1.f, neutralLUTColor);
#elif 0 // Alternative implementation, generates slightly smoother shadow gradients but it hasn't been tested around the game much, and still crushes blacks
	const float3 blackScaling = lerp(1.f + analysis.black, 1.f, neutralLUTColor);
#else // Disable for quick testing
	const float3 blackScaling = 1.f;
#endif

	// On full black (neutralLUTColor coordinates 0 0 0) this will always result in 0 0 0.
	float3 detintedLinear = 1.f - ((1.f - originalLinear) * blackScaling);

	// It might seem that "detintedColor" couldn't go below 0 by looking at the math,
	// but if Bethesda made luts that have solor LUT pixels that are much darker than the neutral LUT, this could happen.
	// It must be done because if channels go negative otherwise it'll become
	// amplified when gain is applied back, causing L to be lower than it should.
	// Even if Y or L is positive before gain, a negative channel being multiplied
	// will hurt visiblity.
	// (eg: (-2,0,1) * 2 = (-4, 0, 2) instead of (0,0,2)
	// Trade off here is, near black, more visibility vs smoother gradients.
	// Basically without this, the output might be overly dark.
	static const bool AlwaysClampDetintedColor = true;
	if (AlwaysClampDetintedColor || SDRRange) {
		detintedLinear = max(detintedLinear, 0.f);
	}

#if LUT_DEBUG_VALUES
	// Should never happen, especially if "AlwaysClampDetintedColor" is true
	if (Luminance(detintedColor) < 0.f) {
		return DEBUG_COLOR;
	}
#endif // LUT_DEBUG_VALUES

	// The saturation multiplier in LUTs is restricted to HDR as it easily goes beyond Rec.709
	const float detintedChroma = linear_srgb_to_oklch(detintedLinear)[1];
	const float saturation = linearNormalization(HdrDllPluginConstants.HDRSaturation, 0.f, 2.f, 0.5f, 1.5f);
	const float targetChroma = detintedChroma * (SDRRange ? 1.f : saturation);

	// Adjust the value back to recreate a smooth Y gradient since 0 is floored
	// Sample and hold "targetL"

	// We fork a bit from Normalized LUTs 2.0.0 here, because the scaling will
	// now be symmetrical to avoid an extra lerp.
	// Max shift in any channel is +0.00015736956998746443f
	// In RGB8 this only shifts 8653 / 794,624 (1%) of texels enough to
	// change one channel by 1/255 (and likely from rounding).
	// None of those RGB8 values are near black or white
	// At worse, it's 0.01% brighter

#if 0 // TODO: enable this? It would only work in HDR though, and this brightness boost for the moment is meant for SDR.
	const float ExtraLuminanceBoost = linearNormalization(HdrDllPluginConstants.SDRSecondaryBrightness, 0.f, 2.f, 0.75f, 1.25f);
#else
	static const float ExtraLuminanceBoost = 1.f;
#endif
	const float3 retintedLinear = detintedLinear * blackScaling * ExtraLuminanceBoost;

	float targetL = linear_srgb_to_oklab(retintedLinear)[0];

#if LUT_DEBUG_VALUES
	if (targetL < 0.f) return DEBUG_COLOR;
#endif // LUT_DEBUG_VALUES

	// Texels exista as points in 3D cube. We are moving two heavily weighted
	// points and need to compute the net force to be applied.
	// Black texel is 0 from itself and sqrt(3) from white
	// White texel is 0 from itself and sqrt(3) from black
	// Values in between can be closer to one than the other.
	// This can also be represented as [-1 to 1] or [-B to +W].
	// For interpolation between 0 and a maximum, it become [0, ..., W, ..., W+B]
	// Distances do not always add up to sqrt(3) (eg: 1,0,0)

	const float blackDistance = length(neutralLUTColor);
	const float whiteDistance = length(1.f - neutralLUTColor);
	const float totalRange = blackDistance + whiteDistance;

#if LUT_DEBUG_VALUES
	// whiteL most always be > 0
	if (analysis.whiteL <= 0.f) return DEBUG_COLOR;
#endif // LUT_DEBUG_VALUES

	// Boost lightness by how much white was reduced
	const float raiseL = linearNormalization(
		whiteDistance,
		0.f,
		totalRange,
		1.f / analysis.whiteL,
		1.f);

#if LUT_DEBUG_VALUES
	// increaseY must always be >= 1
	if (raiseL < 1.f) return DEBUG_COLOR;
#endif // LUT_DEBUG_VALUES

	// On full white (neutralLUTColor coordinates 1 1 1) this will always result in 1 1 1.
	targetL *= raiseL;

	// Use hue from original LUT color
	const float targetHue = originalLCh[2];

	float3 outputLCh;

	if (targetL >= 1.f) {
		const uint clipBehavior = SDRRange ? LUT_SDR_ON_CLIP : LUT_HDR_ON_CLIP;
		if (clipBehavior == 0) // As is (treat it the same as any other color)
			outputLCh = float3(targetL, targetChroma, targetHue);
		else if (clipBehavior == 1) {
			outputLCh = originalLCh; // Keep original color (do nothing)
		} else if (clipBehavior == 2) {
			outputLCh = float3(1.f, targetChroma, targetHue);
		}
	}
	else {
		outputLCh = float3(targetL, targetChroma, targetHue);
	}

#if LUT_DEBUG_VALUES // Debug black point
	float3 debugLinear = oklch_to_linear_srgb(outputLCh);

	bool isBlackPoint = neutralLUTColor.r == 0.f && neutralLUTColor.g == 0.f && neutralLUTColor.b == 0.f;

	bool wasBlack = !any(linearColor);

	// If neutralLutColor is 0,0,0, force 0

	debugLinear *= (!isBlackPoint);

	bool nowBlack = !any(debugLinear);

	if (isBlackPoint) {
		if (wasBlack) {
			// color = float3(0.f,1.f, 0.f); // Green (OK)
		} else if (nowBlack) {
			// L has recorded upto `0.000004829726509479252`
			// If below 0.000005, ignore it
			if (targetL >= 0.01f) {
				debugLinear = float3(1.f,1.f, 0.f); // Yellow (Bad L)
			}
		}
	} else if (nowBlack || targetL < 0.01f) {
		if (!wasBlack) {
			debugLinear = float3(0.f,1.f, 1.f); // Cyan (Crush)
		}
	}
	outputLCh = linear_srgb_to_oklch(debugLinear);

	// Should never happen
	if (Luminance(debugLinear) < 0.f) {
		return DEBUG_COLOR;
	}

	// Print all HDR colors
	if (any(debugLinear != saturate(debugLinear))) {
		return DEBUG_COLOR;
	}
#endif // LUT_DEBUG_VALUES

	float3 outputLab = oklch_to_oklab(outputLCh);
	// Blending in Oklab should even better than doing it in linear
	outputLab = lerp(originalLab, outputLab, HdrDllPluginConstants.LUTCorrectionStrength);

#if LUT_MAPPING_TYPE == 2
	return outputLab;
#else
	float3 outputLinear = oklab_to_linear_srgb(outputLab);
	if (SDRRange) {
		// Optional step to keep colors in the SDR range.
		outputLinear = saturate(outputLinear);
	}
	// To note, color channels may be negative, even if -0.00001, probably due to multiple color space conversions.
//	else if (Luminance(outputLinear) < 0.f) {
//		outputLinear = 0.f;
//	}
// commented out as this can cause "black dot issues"
	return outputLinear;
#endif
}

// Dispatch size is 1 1 16 (x and y have one thread and one thread group, while z has 16 thread groups with a thread each)
[RootSignature(ShaderRootSignature)]
[numthreads(LUT_SIZE_UINT, LUT_SIZE_UINT, 1)]
void CS(uint3 SV_DispatchThreadID : SV_DispatchThreadID)
{
	const uint3 inUVW = ThreeToTwoDimensionCoordinates(SV_DispatchThreadID);
	const uint3 outUVW = SV_DispatchThreadID;

	float3 neutralLUTColor = float3(outUVW) / (LUT_SIZE - 1.f); // The neutral LUT is automatically generated by the coordinates, but it's baked with sRGB or 2.2 gamma
	neutralLUTColor = LINEARIZE(neutralLUTColor);

#if LUT_IMPROVEMENT_TYPE != 1
	float3 LUT1Color = LUT1.Load(inUVW);
	float3 LUT2Color = LUT2.Load(inUVW);
	float3 LUT3Color = LUT3.Load(inUVW);
	float3 LUT4Color = LUT4.Load(inUVW);
	LUT1Color = LINEARIZE(LUT1Color);
	LUT2Color = LINEARIZE(LUT2Color);
	LUT3Color = LINEARIZE(LUT3Color);
	LUT4Color = LINEARIZE(LUT4Color);
#endif // LUT_IMPROVEMENT_TYPE

	const bool SDRRange = HdrDllPluginConstants.DisplayMode <= 0 || (bool)FORCE_SDR_LUTS;
#if LUT_IMPROVEMENT_TYPE == 1
	float3 LUT1Color = PatchLUTColor(LUT1, inUVW, neutralLUTColor, SDRRange);
	float3 LUT2Color = PatchLUTColor(LUT2, inUVW, neutralLUTColor, SDRRange);
	float3 LUT3Color = PatchLUTColor(LUT3, inUVW, neutralLUTColor, SDRRange);
	float3 LUT4Color = PatchLUTColor(LUT4, inUVW, neutralLUTColor, SDRRange);
#else
	LUT1Color = linear_srgb_to_oklab(LUT1Color);
	LUT2Color = linear_srgb_to_oklab(LUT2Color);
	LUT3Color = linear_srgb_to_oklab(LUT3Color);
	LUT4Color = linear_srgb_to_oklab(LUT4Color);
#endif // LUT_IMPROVEMENT_TYPE

#if LUT_MAPPING_TYPE == 2
	neutralLUTColor = linear_srgb_to_oklab(neutralLUTColor);
#endif // LUT_MAPPING_TYPE

	// Blend in linear space or Oklab space depending on "LUT_MAPPING_TYPE"
	float adjustedNeutralLUTPercentage = lerp(PcwColorGradingMerge.neutralLUTPercentage, 1.f, AdditionalNeutralLUTPercentage);
	float adjustedLUT1Percentage = lerp(PcwColorGradingMerge.LUT1Percentage, 0.f, AdditionalNeutralLUTPercentage);
	float adjustedLUT2Percentage = lerp(PcwColorGradingMerge.LUT2Percentage, 0.f, AdditionalNeutralLUTPercentage);
	float adjustedLUT3Percentage = lerp(PcwColorGradingMerge.LUT3Percentage, 0.f, AdditionalNeutralLUTPercentage);
	float adjustedLUT4Percentage = lerp(PcwColorGradingMerge.LUT4Percentage, 0.f, AdditionalNeutralLUTPercentage);

	float3 mixedLUT = (adjustedNeutralLUTPercentage * neutralLUTColor)
	                + (adjustedLUT1Percentage * LUT1Color)
	                + (adjustedLUT2Percentage * LUT2Color)
	                + (adjustedLUT3Percentage * LUT3Color)
	                + (adjustedLUT4Percentage * LUT4Color);

// If necessary (!GAMMA_CORRECTION_IN_LUTS), shift from gamma 2.2 to sRGB interpretation, so the LUT input and output colors
// are in the same gamma space, which should be more mathematically correct, and we can then instead do the gamma correction later.
#if LUT_MAPPING_TYPE != 2
	mixedLUT = CORRECT_GAMMA(mixedLUT);
#endif // LUT_MAPPING_TYPE

// Convert to sRGB gamma after blending between LUTs, so the blends are done in linear space, which gives more consistent and correct results
#if LUT_MAPPING_TYPE == 0
	mixedLUT = gamma_linear_to_sRGB(mixedLUT);
#endif // LUT_MAPPING_TYPE

	OutMixedLUT[outUVW] = float4(mixedLUT, 1.f);
}
