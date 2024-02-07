#include "../shared.hlsl"
#include "../color.hlsl"
#include "../math.hlsl"
#include "RootSignature.hlsl"

#define FORCE_SDR_LUTS 0
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
	// No need to run "gamma_sRGB_to_linear_mirrored()" as there's no HDR source colors in LUTs.
	#define LINEARIZE(x) gamma_sRGB_to_linear(x)
	#define CORRECT_GAMMA(x) x
	#define POST_CORRECT_GAMMA(x)
#else
	// Follow the user setting (slower but it can probably help accross the whole range of LUTs and screens).
	// 
	// Note: if "GAMMA_CORRECTION_IN_LUTS" is false and "ApplyGammaBelowZeroDefault" is false and the gamma correction setting is changed, the output colors seem to wobble a bit (not a real problem probably).
	// This might be for 3 reasons:
	// 1) LUT correction already kind of corrected for raised blacks itself, so it partially already acted as gamma correction,
	//    thus applying gamma correction in the "LINEARIZE()" function or not won't change much, while undoing the gamma correction before output in "CORRECT_GAMMA()",
	//    will instead have a large effect and will either double down or undo gamma correction.
	// 2) RGB values not mapping "linearly" to Oklab: for example changing gamma correction from 33% to 34% might drastically change
	//    how the LUT correction plays out, and it's done in Oklab and maybe a small hue shift from gamma correction massively changes some Oklab values.
	// 3) Lerping linearly between sRGB and 2.2 gamma isn't really "correct" as they are different formulas.
	// To work around the issue, we could simply force LUTs to be intepreted with gamma 2.2 (and outputted in sRGB) at 100% if gamma correction was > 0,
	// or better, not undo intermediary gamma correction in "CORRECT_GAMMA()" if the LUT was corrected, though that's near impossible to determine.
	// Another alternative would be to apply gamma by average or luminance instead than by channel.
	#define LINEARIZE(x) lerp(gamma_sRGB_to_linear(x), pow(x, 2.2f), HdrDllPluginConstants.GammaCorrection)
	//#define LINEARIZE(x) pow(x, 2.2f) /*Version without "HdrDllPluginConstants.GammaCorrection"*/
	#if GAMMA_CORRECTION_IN_LUTS // 2.2->linear->LUT normalization
		// If we correct gamma in LUTs, there's nothing more to do than linearize (interpret) them as gamma 2.2, while the input coordinates keep using sRGB gamma.
		// This single difference will correct the gamma on output.
		#define CORRECT_GAMMA(x) x
		#define POST_CORRECT_GAMMA(x)
	#else // 2.2->linear->LUT normalization->sRGB->linear
		// If we don't correct gamma in LUTs, we convert them back to sRGB gamma at the end, so that it will match the input coordinates gamma, as they also use sRGB.
		// A further correction step will be done after that to acknowledge the gamma mismatch baked into the game look.
		// Use the custom gamma formulas to apply (and mirror) gamma on colors below 0 but not beyond 1 (based on "ApplyGammaBelowZeroDefault").
		#define CORRECT_GAMMA(x) (gamma_sRGB_to_linear_custom(lerp(gamma_linear_to_sRGB_custom(x), linear_to_gamma_custom(x), HdrDllPluginConstants.GammaCorrection)))
		//#define CORRECT_GAMMA(x) (gamma_sRGB_to_linear_custom(linear_to_gamma_custom(x))); if (Luminance(x) < 0.f) { x = 0.f } /*Version without "HdrDllPluginConstants.GammaCorrection"*/
		#define POST_CORRECT_GAMMA(x) if (ApplyGammaBelowZeroDefault && Luminance(x) < 0.f) { x = 0.f; }
	#endif // GAMMA_CORRECTION_IN_LUTS
#endif // SDR_USE_GAMMA_2_2

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
	float3 blackGamma;
	float3 blackLinear;
	float3 whiteGamma;
	float3 whiteLinear;
	float whiteY;
	float blackY;
	float3 whiteLab;
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
	Analysis.blackGamma = LUT.Load(ThreeToTwoDimensionCoordinates(0u)).rgb;
	Analysis.blackLinear = LINEARIZE(Analysis.blackGamma);
	Analysis.whiteGamma = LUT.Load(ThreeToTwoDimensionCoordinates(LUT_MAX_UINT)).rgb;
	Analysis.whiteLinear = LINEARIZE(Analysis.whiteGamma);
	Analysis.blackY = Luminance(Analysis.blackLinear);
	Analysis.whiteY = Luminance(Analysis.whiteLinear);
	Analysis.whiteLab = linear_srgb_to_oklab(Analysis.whiteLinear);
}

// Analyzes each LUT texel and normalizes their range.
// Slow but effective.
float3 PatchLUTColor(Texture2D<float3> LUT, uint3 UVW, float3 neutralGamma, float3 neutralLinear, bool SDRRange = false)
{
	LUTAnalysis analysis;
	AnalyzeLUT(LUT, analysis);

	const float3 originalGamma = LUT.Load(UVW);
	const float3 originalLinear = LINEARIZE(originalGamma);
	const float3 originalLab = linear_srgb_to_oklab(originalLinear);
	const float3 originalLCh = oklab_to_oklch(originalLab);

	if (analysis.whiteY < analysis.blackY) // If LUT is inversed (eg: photo negative) don't do anything
	{
#if LUT_MAPPING_TYPE == 2
		return originalLab;
#else
		return originalLinear;
#endif // LUT_MAPPING_TYPE
	}

	// LUT(0,0,0) is the black color, which is also the shadow fog color.
	// Fog color will be floored to black to normalize the range.
	// Colors near black should have the fog color removed will bring out the original color.
	// This should result in increased chrominance since the fog color may have
	// shifted the original color to become achromatic (gray). 
	//
	// Notes: Red + Cyan made Gray (eg: #CC0000 + #00CCCC = #CCCCCC)
	//
	// Fog color should be reapplied to retain smooth gradients, with less affect
	// the further from black
	//
	// Perceived delta is also important. For example, if the fog color
	// is #cc0000 than a dark blue tint #cc0005 would result in #000005
	// Special handling is needed for colors that are darker than the fog color
	// which is common around blue whic has low perceptual luminance (7%)
  //
	// If something was barely perceivable in the original game because it
	// diluted by the fog color, it would be consistent for it to be still barely
	// perceivable due to darkness (delta from black)

	const static float LUTDistanceNormalization = sqrt(3.f);
	const float blackDistance = length(neutralLinear) / LUTDistanceNormalization;
	const float whiteDistance = length(1.f - neutralLinear) / LUTDistanceNormalization;
	const float totalRange = blackDistance + whiteDistance;
	// The saturation multiplier in LUTs is restricted to HDR (or gamut mapped SDR) as it easily goes beyond Rec.709
	const float saturation = SDRRange ? 1.f : HdrDllPluginConstants.ToneMapperSaturation;

#if LUT_IMPROVEMENT_TYPE == 0
	float targetL = originalLCh[0];
	const float targetChroma = originalLCh[1] * saturation;
	const float targetHue = originalLCh[2];
#elif LUT_IMPROVEMENT_TYPE == 1

	// Note: Black scaling implements curve in the newly created shadow region
	// This gives it more contrast than if it were to be just restored
	// This could also drag down midtones
#if 0
	// TODO: expose these values or find the best defaults. For now we skip these when "HdrDllPluginConstants.GammaCorrection" is on as it's not necessary

	// An additional tweak on top of "HdrDllPluginConstants.LUTCorrectionStrength"
	float fixRaisedBlacksStrength = 1.f /*- HdrDllPluginConstants.DevSetting01*/; // Values between 0 and 1
	// TODO: improve the way "fixRaisedBlacksInputSmoothing" is applied, the curve isn't great now
	// Modulates how much we fix the raised blacks based on how raised they were.
	float fixRaisedBlacksInputSmoothing = lerp(1.f, 1.333f, HdrDllPluginConstants.GammaCorrection); // Values from 1 up, greater is smoother
	float fixRaisedBlacksOutputSmoothing = lerp(1.f, 0.666f, HdrDllPluginConstants.GammaCorrection); // Values from 0 up, smaller than 1 is smoother
	const float3 invertedBlack = 1.f - (pow(analysis.blackLinear, lerp(1.f, fixRaisedBlacksInputSmoothing, analysis.blackLinear)) * fixRaisedBlacksStrength);
	const float3 blackScaling = lerp(1.f / invertedBlack, 1.f, pow(neutralLinear, fixRaisedBlacksOutputSmoothing));
#elif 1 // Original implementation (we can't do this by luminance or in any other way really)
	const float3 blackScaling = lerp(1.f / (1.f - analysis.blackLinear), 1.f, neutralLinear);
#else // Disable for quick testing
	const float blackScaling = 1.f;
#endif

	// Create a detinted and darkened color.
	// On full black (neutralLinear coordinates 0 0 0) this will always result in 0 0 0.
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
	static const bool AlwaysClampDetintedColor = false;
	if (AlwaysClampDetintedColor || SDRRange) {
		detintedLinear = max(detintedLinear, 0.f);
	}
	// Should never happen (but it actually can?)
	else if (Luminance(detintedLinear) < 0.f) {
#if LUT_DEBUG_VALUES
		return DEBUG_COLOR;
#endif // LUT_DEBUG_VALUES
		detintedLinear = 0.f;
	}


	// Detint less near black, to avoid LUTs all going to grey/black
	const float detintedChroma = lerp(originalLCh[1], linear_srgb_to_oklch(detintedLinear)[1], blackDistance);

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
	const float targetChroma = detintedChroma * saturation;
	// Use hue from original LUT color
	const float targetHue = originalLCh[2];

#if LUT_DEBUG_VALUES
	if (targetL < 0.f) return DEBUG_COLOR;
#endif // LUT_DEBUG_VALUES

	// Texels exist as points in 3D cube. We are moving two heavily weighted
	// points and need to compute the net force to be applied.
	// Black texel is 0 from itself and sqrt(3) from white
	// White texel is 0 from itself and sqrt(3) from black
	// Values in between can be closer to one than the other.
	// This can also be represented as [-1 to 1] or [-B to +W].
	// For interpolation between 0 and a maximum, it become [0, ..., W, ..., W+B]
	// Distances do not always add up to sqrt(3) (eg: 1,0,0)

#if LUT_DEBUG_VALUES
	// whiteL most always be > 0
	if (analysis.whiteLab[0] <= 0.f) return DEBUG_COLOR;
#endif // LUT_DEBUG_VALUES

	// Boost lightness by how much white was reduced
	const float raiseL = linearNormalization(
		whiteDistance,
		0.f,
		totalRange,
		1.f / analysis.whiteLab[0],
		1.f);

#if LUT_DEBUG_VALUES
	// raiseL must always be >= 1
	if (raiseL < 1.f) return DEBUG_COLOR;
#endif // LUT_DEBUG_VALUES

	// On full white (neutralLinear coordinates 1 1 1) this will always result in 1 1 1.
	targetL *= raiseL;

#elif LUT_IMPROVEMENT_TYPE == 2

	float3 addedGamma = analysis.blackGamma;
	float3 removedGamma = 1.f - analysis.whiteGamma;

	float3 midGray = LUT.Load(ThreeToTwoDimensionCoordinates(LUT_MAX_UINT / 2.f)).rgb;
	float midGrayAvg = (midGray.r + midGray.g + midGray.b) / 3.f;

	float shadowLength = 1.f - midGrayAvg;
	float shadowStop = max(neutralGamma.r, max(neutralGamma.g, neutralGamma.b));
	float3 removeFog = addedGamma * max(0, shadowLength - shadowStop) / shadowLength;

	float highlightsStart = midGrayAvg;
	float highlightsStop = min(neutralGamma.r, min(neutralGamma.g, neutralGamma.b));
	float3 liftHighlights = removedGamma * ((max(highlightsStart, highlightsStop) - highlightsStart) / highlightsStart);

	// Use max(0) because some texels have some channels dip below 0 (eg: single-channel colors)
	float3 detintedInGamma = max(0, originalGamma - removeFog) + liftHighlights;

	float3 detintedInGammaLinear = LINEARIZE(detintedInGamma);

#if LUT_MAPPING_TYPE == 0
	// Mixing sRGB Gamma with OKLab and LUT sample causes crushing
	// Use linear instead
	float detintedInGammaY = max(0, Luminance(detintedInGammaLinear));
	float originalY = Luminance(originalLinear);
	float3 retintedLinear = originalLinear * (originalY > 0 ? detintedInGammaY / originalY : 0);
	float3 retintedLab = linear_srgb_to_oklab(retintedLinear);
#else
	float3 retintedLab = linear_srgb_to_oklab(detintedInGammaLinear);
	retintedLab[1] = originalLab[1];
	retintedLab[2] = originalLab[2];
#endif

	float3 retintedLCh = oklab_to_oklch(retintedLab);

	float targetL = retintedLCh[0];
	const float targetChroma = retintedLCh[1] * saturation;
	const float targetHue = retintedLCh[2];

#endif

	targetL = max(0, targetL);

	const float3 targetLCh = float3(targetL, targetChroma, targetHue);
	float3 outputLCh = targetLCh;

	
#if 0
	// Try to remove the S filmic tonemapper curve that is baked in inside some LUTs.
	// We do it by average because usually the S curve would have (very likely) been applied by channel, and not by luminance.
	// Don't do this in SDR as it can easily make LUTs go out of range.
	// NOTE: this doesn't always work as expected there's many LUTs that just boost or dim the whole range, not in a S curve fashion,
	// thus basically this acts as a way of transforming LUTs in color tint filters only, without changing the average brightness much.
	if (!SDRRange)
	{
		float3 targetLinear = oklch_to_linear_srgb(targetLCh);
#if DEVELOPMENT
		const float LUTFilmicTonemapCorrection = HdrDllPluginConstants.DevSetting04;
#else
		static const float LUTFilmicTonemapCorrection = 1.f;
#endif
		const float colorAverageRatio = safeDivision(average(neutralLinear), average(targetLinear));
		// (optional) Pivot adjustments around the center.
		// Not using length() as average seems more appropriate here (especially with negative coordinates being possible).
		const float distanceFromCenter = saturate(abs(average(neutralLinear) - 0.5f) * 2.f);
		targetLinear *= lerp(1.f, colorAverageRatio, LUTFilmicTonemapCorrection * distanceFromCenter);
		outputLCh = linear_srgb_to_oklch(targetLinear);
	}
#endif

#if LUT_DEBUG_VALUES // Debug black point
	// Refresh variables
	targetL = outputLCh[0];
	targetChroma = outputLCh[1];
	targetHue = outputLCh[2];
	
	float3 debugLinear = oklch_to_linear_srgb(outputLCh);

	bool isBlackPoint = neutralLinear.r == 0.f && neutralLinear.g == 0.f && neutralLinear.b == 0.f;

	bool wasBlack = !any(linearColor);

	// If neutralLinear is 0,0,0, force 0

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
	// Note: we partially ignore "SDRRange" clamping here (you can't simply clamp Oklab to SDR sRGB without gamut mapping)
	return float3(SDRRange ? min(outputLab.x, 1.f) : outputLab.x, outputLab.yz);
#else
	float3 outputLinear = oklab_to_linear_srgb(outputLab);
	if (SDRRange) {
		// Optional step to keep colors in the SDR range.
		outputLinear = saturate(outputLinear);
	}
#if 0 // Disabled out as this can cause "black dot issues" (???) (it just doesn't seem necessary)
	// To note, color channels may be negative, even if -0.00001, probably due to multiple color space conversions.
	else if (Luminance(outputLinear) < 0.f) {
		outputLinear = 0.f;
	}
#endif
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

	const float3 neutralGamma = float3(outUVW) / (LUT_SIZE - 1.f); // The neutral LUT is automatically generated by the coordinates, but it's baked with sRGB or 2.2 gamma
	float3 neutralLinear = LINEARIZE(neutralGamma); // Yes, we indeed this we want this pre-gamma corrected even on neutral LUT

#if LUT_IMPROVEMENT_TYPE == 0
	float3 LUT1Color = LUT1.Load(inUVW);
	float3 LUT2Color = LUT2.Load(inUVW);
	float3 LUT3Color = LUT3.Load(inUVW);
	float3 LUT4Color = LUT4.Load(inUVW);
	LUT1Color = LINEARIZE(LUT1Color);
	LUT2Color = LINEARIZE(LUT2Color);
	LUT3Color = LINEARIZE(LUT3Color);
	LUT4Color = LINEARIZE(LUT4Color);
#endif // LUT_IMPROVEMENT_TYPE

	// NOTE: ignore clamping to the SDR range if "CLAMP_INPUT_OUTPUT_TYPE" was set to do gamut mapping
	const bool SDRRange = (HdrDllPluginConstants.DisplayMode <= 0 && CLAMP_INPUT_OUTPUT_TYPE != 1) || (bool)FORCE_SDR_LUTS;
#if LUT_IMPROVEMENT_TYPE >= 1
	float3 LUT1Color = PatchLUTColor(LUT1, inUVW, neutralGamma, neutralLinear, SDRRange);
	float3 LUT2Color = PatchLUTColor(LUT2, inUVW, neutralGamma, neutralLinear, SDRRange);
	float3 LUT3Color = PatchLUTColor(LUT3, inUVW, neutralGamma, neutralLinear, SDRRange);
	float3 LUT4Color = PatchLUTColor(LUT4, inUVW, neutralGamma, neutralLinear, SDRRange);
#elif LUT_MAPPING_TYPE == 2
	LUT1Color = linear_srgb_to_oklab(LUT1Color);
	LUT2Color = linear_srgb_to_oklab(LUT2Color);
	LUT3Color = linear_srgb_to_oklab(LUT3Color);
	LUT4Color = linear_srgb_to_oklab(LUT4Color);
#endif // LUT_IMPROVEMENT_TYPE

#if LUT_MAPPING_TYPE == 2
	neutralLinear = linear_srgb_to_oklab(neutralLinear);
#endif // LUT_MAPPING_TYPE

	// Blend in linear space or Oklab space depending on "LUT_MAPPING_TYPE"
	float adjustedNeutralLUTPercentage = lerp(PcwColorGradingMerge.neutralLUTPercentage, 1.f, AdditionalNeutralLUTPercentage);
	float adjustedLUT1Percentage = lerp(PcwColorGradingMerge.LUT1Percentage, 0.f, AdditionalNeutralLUTPercentage);
	float adjustedLUT2Percentage = lerp(PcwColorGradingMerge.LUT2Percentage, 0.f, AdditionalNeutralLUTPercentage);
	float adjustedLUT3Percentage = lerp(PcwColorGradingMerge.LUT3Percentage, 0.f, AdditionalNeutralLUTPercentage);
	float adjustedLUT4Percentage = lerp(PcwColorGradingMerge.LUT4Percentage, 0.f, AdditionalNeutralLUTPercentage);

	float3 mixedLUT = (adjustedNeutralLUTPercentage * neutralLinear)
	                + (adjustedLUT1Percentage * LUT1Color)
	                + (adjustedLUT2Percentage * LUT2Color)
	                + (adjustedLUT3Percentage * LUT3Color)
	                + (adjustedLUT4Percentage * LUT4Color);

#if LUT_MAPPING_TYPE == 2
	mixedLUT = oklab_to_linear_srgb(mixedLUT);
	//TODO: make this case convert to sRGB as LUT mapping is more correct in sRGB
#endif // LUT_MAPPINT_TYPE

#if CLAMP_INPUT_OUTPUT_TYPE == 1 || CLAMP_INPUT_OUTPUT_TYPE == 2 && LUT_MAPPING_TYPE >= 1
	// Clamp to AP1 since OKLab colors may turn black when not clamped
	mixedLUT = mul(BT709_2_AP1D65, mixedLUT);
	mixedLUT = max(mixedLUT, 0.f);
	mixedLUT = mul(AP1D65_2_BT709, mixedLUT);
#endif

	// If necessary (!GAMMA_CORRECTION_IN_LUTS), shift from gamma 2.2 to sRGB interpretation, so the LUT input and output colors
	// are in the same gamma space, which should be more mathematically correct, and we can then instead do the gamma correction later.
	mixedLUT = CORRECT_GAMMA(mixedLUT);
	POST_CORRECT_GAMMA(mixedLUT);

// Convert to sRGB gamma after blending between LUTs, so the blends are done in linear space, which gives more consistent and correct results
#if LUT_MAPPING_TYPE == 0
	mixedLUT = gamma_linear_to_sRGB_mirrored(mixedLUT);
#endif // LUT_MAPPINT_TYPE

	OutMixedLUT[outUVW] = float4(mixedLUT, 1.f);
}
