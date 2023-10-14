#include "../shared.hlsl"
#include "../color.hlsl"
#include "../math.hlsl"
#include "RootSignature.hlsl"

// 0 None, 1 ShortFuse technique (normalization), 2 luminance preservation (doesn't look so good and it's kinda broken in SDR)
#define LUT_IMPROVEMENT_TYPE (FORCE_VANILLA_LOOK ? 0 : 1)
#define FORCE_SDR_LUTS 0
// Make some small quality cuts for the purpose of optimization
#define OPTIMIZE_LUT_ANALYSIS true
// For future development
#define UNUSED_PARAMS 0
#define LUT_DEBUG_VALUES false
#define DEBUG_COLOR float3(1.f, 0.f, 1.f) /*Magenta*/

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

//TODO: try to make the LUTs return OKLCH values so there's chroma and hue even if the luminance is 0

// Behaviour when the color luminance goes beyond 1
// -0: As is, keep the normalized value that could be beyond the 0-1
// -1: Keep orignal (non normalized) color
// -2: "Clip" to full white
// -3: Max Hue
// -4: Clamp
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
#if UNUSED_PARAMS
	float minChannel;
	float maxChannel;
	float minY;
	float maxY;
	float averageY;
	float range;
	float medianY;
	float averageChannel;
	float averageRed;
	float averageGreen;
	float averageBlue;
	float maxRed;
	float maxGreen;
	float maxBlue;
	float minRed;
	float minGreen;
	float minBlue;
#endif // UNUSED_PARAMS
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
	Analysis.white = LINEARIZE(LUT.Load(ThreeToTwoDimensionCoordinates(LUT_SIZE_UINT - 1u)).rgb);
	Analysis.whiteY = Luminance(Analysis.white);
	Analysis.whiteL = linear_srgb_to_oklab(Analysis.white)[0];
#if UNUSED_PARAMS
	Analysis.minY = FLT_MAX;
	Analysis.maxY = -FLT_MAX;

	float3 colors = 0.f;
	float Ys = 0.f;

	float3 minColor = FLT_MAX;
	float3 maxColor = -FLT_MAX;

	const uint texelCount = LUT_SIZE_UINT * LUT_SIZE_UINT * LUT_SIZE_UINT;

	// TODO: this loops on every LUT pixel for every output pixel.
	// given we only need the min/max color channels here, to optimize we could:
	//  -Just iterate on the last (e.g.) 3 pixels of each axis, which should guarantee to find the max for all normal LUTs.
	//   According to ShortFuse some LUTs don't have their min and max in the edges, but it could be in the middle or close to it.
	//   It's arguable we'd care about this cases, and it's also arguable to correct them by global min instead of edges min, as the result could actually be worse?
	//  -Work with atomic (shared variables), group sync and thread/thread group to only calculate this once.
	//  -Add a new post LUT mixing compute shader pass that does this once.
	const uint analyzeTexelFrequency = OPTIMIZE_LUT_ANALYSIS ? (LUT_SIZE_UINT - 1u) : 1u; // Set to 1 for all. Set to "LUT_SIZE_UINT - 1u" for edges only.
	for (uint x = 0; x < LUT_SIZE_UINT; x += analyzeTexelFrequency)
	{
		for (uint y = 0; y < LUT_SIZE_UINT; y += analyzeTexelFrequency)
		{
			for (uint z = 0; z < LUT_SIZE_UINT; z += analyzeTexelFrequency)
			{
				float3 LUTColor = LINEARIZE(LUT.Load(ThreeToTwoDimensionCoordinates(uint3(x, y, z))).rgb);

				minColor = min(minColor, LUTColor);
				maxColor = max(maxColor, LUTColor);

				float Y = Luminance(LUTColor);
				Analysis.minY = min(Analysis.minY, Y);
				Analysis.maxY = max(Analysis.maxY, Y);
				Ys += Y;

				colors += LUTColor.r;
			}
		}
	}

	// TODO: either store min/max channels merged or separately, but not both
	Analysis.minChannel = min(minColor.r, min(minColor.g, minColor.b));
	Analysis.maxChannel = max(maxColor.r, max(maxColor.g, maxColor.b));
	Analysis.minRed = minRed;
	Analysis.minGreen = minGreen;
	Analysis.minBlue = minBlue;
	Analysis.maxRed = maxRed;
	Analysis.maxGreen = maxGreen;
	Analysis.maxBlue = maxBlue;

	Analysis.averageY = Ys / texelCount;
	Analysis.averageRed = colors.r / texelCount;
	Analysis.averageGreen = colors.g / texelCount;
	Analysis.averageBlue = colors.b / texelCount;

	Analysis.averageChannel = (Analysis.averageRed + Analysis.averageGreen + Analysis.averageBlue) / 3.f;
	Analysis.range = Analysis.maxY - Analysis.minY;

	//TODO: ??? Can't do this in shader but it's not needed
	//Ys.sort((a, b) => a - b);
	//Analysis.medianY = ((Ys[Math.floor(texelCount / 2)]) + (Ys[Math.ceil(texelCount / 2)])) / 2;
#endif // UNUSED_PARAMS
}

// Analyzes each LUT texel and normalizes their range.
// Slow but effective.
float3 PatchLUTColor(Texture2D<float3> LUT, uint3 UVW, float3 neutralLUTColor, bool SDRRange = false)
{
	LUTAnalysis analysis;
	AnalyzeLUT(LUT, analysis);

	float3 color = LINEARIZE(LUT.Load(UVW));
	const float3 originalColor = color;

	if (analysis.whiteY < analysis.blackY // If LUT is inversed (eg: photo negative) don't do anything
		|| analysis.whiteY - analysis.blackY >= 1.f) // If LUT is full range already nothing to do
	{
		return color;
	}

	// While it unclear how exactly the floor was raised, remove the tint to floor
	// the values to 0. This will remove the haze and tint giving a fuller chroma
	// Sample and hold targetChroma

#if 0
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

	float3 detintedColor = 1.f - ((1.f - color) * blackScaling);

	// Must be done because if channels go negative othwerise it'll become
	// amplified when gain is applied back, causing L to be lower than it should.
	// Even if Y or L is positive before gain, a negative channel being multiplied
	// will hurt visiblity.
	// (eg: (-2,0,1) * 2 = (-4, 0, 2) instead of (0,0,2)
	// Trade off here is, near black, more visibility vs smoother gradients
	detintedColor = max(detintedColor, 0.f);
	
#if LUT_DEBUG_VALUES
	// Should never happen
	if (Luminance(detintedColor) < 0.f) {
		return DEBUG_COLOR;
	}
#endif // LUT_DEBUG_VALUES
	
	// The saturation multiplier in LUTs is restricted to HDR as it easily goes beyond Rec.709
	const float saturation = linearNormalization(HdrDllPluginConstants.HDRSaturation, 0.f, 2.f, 0.5f, 1.5f);
	const float targetChroma = linear_srgb_to_oklch(detintedColor)[1] * (SDRRange ? 1.f : saturation);

	// Adjust the value back to recreate a smooth Y gradient since 0 is floored
	// Sample and hold targetL

	// We fork a bit from Normalized LUTs 2.0.0 here, because the scaling will
	// now be symmetrical to avoid an extra lerp.
	// Max shift in any channel is +0.00015736956998746443f
	// In RGB8 this only shifts 8653 / 794,624 (1%) of texels enough to
	// change one channel by 1/255 (and likely from rounding).
	// None of those RGB8 values are near black or white
	// At worse, it's 0.01% brighter

	const float extraLBoost = 1.f; // Replace with user option? 
	const float3 retintedColor = detintedColor * blackScaling * extraLBoost;

	float targetL = linear_srgb_to_oklab(retintedColor)[0];

#if LUT_DEBUG_VALUES
	if (targetL < 0) return DEBUG_COLOR;
#endif // LUT_DEBUG_VALUES

	// Texels exista as points in 3D cube. We are moving two heavily weighted
	// points and need to compute the net force to be applied.
	// Black texel is 0 from itself and sqrt(3) from white
	// White texel is 0 from itself and sqrt(3) from black
	// Values in between can be closer to one than the other.
	// This can also be represented as [-1 to 1] or [-B to +W].
	// For interpolation between 0 and a maximum, it become [0, ..., W, ..., W+B]
	// Distances do not always add up to sqrt(3) (eg: 1,0,0)

	const float blackDistance = hypot3(neutralLUTColor);
	const float whiteDistance = hypot3(1.f - neutralLUTColor);
	const float totalRange = blackDistance + whiteDistance;

#if LUT_DEBUG_VALUES
	// whiteY most always be > 0
	if (analysis.whiteL <= 0) return DEBUG_COLOR;
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
	if (raiseL < 1) return DEBUG_COLOR;
#endif // LUT_DEBUG_VALUES

	targetL *= raiseL;

	// Use hue from LUT cube color
	const float targetHue = linear_srgb_to_oklch(color)[2];

	if (targetL >= 1.f) {
		const uint clipBehavior = SDRRange ? LUT_SDR_ON_CLIP : LUT_HDR_ON_CLIP;
		if (clipBehavior == 0) // As is (treat it the same as any other color)
			color = oklch_to_linear_srgb(float3(targetL, targetChroma, targetHue));
		else if (clipBehavior == 1) { } // Keep original color (do nothing)
		else if (clipBehavior == 2) // White
			color = 1.f;
		else if (clipBehavior == 3) // Max Hue
		{
			// TODO: can we even do anything about this? if the lightness is >= 1, then the color is white?
		}
		else if (clipBehavior == 4) // Clamp
			color = oklch_to_linear_srgb(float3(1.f, targetChroma, targetHue)); // TODO: isn't this the same as the "White" setting?
	}
	else {
		color = oklch_to_linear_srgb(float3(targetL, targetChroma, targetHue));
	}

#if LUT_DEBUG_VALUES // Debug black point
	bool isBlackPoint = neutralLUTColor.r == 0.f && neutralLUTColor.g == 0.f && neutralLUTColor.b == 0.f;

	bool wasBlack = !any(color);

	// If neutralLutColor is 0,0,0, force 0
	
	color *= (!isBlackPoint);

	bool nowBlack = !any(color);

	if (isBlackPoint) {
		if (wasBlack) {
			// color = float3(0.f,1.f, 0.f); // Green (OK)
		} else if (nowBlack) {
			// L has recorded upto `0.000004829726509479252`
			// If below 0.000005, ignore it
			if (targetL >= 0.01f) {
				color = float3(1.f,1.f, 0.f); // Yellow (Bad L)
			}
		}
	} else if (nowBlack || targetL < 0.000005f) {
		if (!wasBlack) {
			color = float3(0.f,1.f, 1.f); // Cyan (Crush)
		}
	}
#endif // LUT_DEBUG_VALUES

	if (SDRRange) {
		// Optional step to keep colors in the SDR range.
		color = saturate(color);
	}

#if LUT_DEBUG_VALUES
	// Should never happen
	if (Luminance(color) < 0.f) {
		return DEBUG_COLOR;
	}
#endif // LUT_DEBUG_VALUES

	// To note, color channels may be negative, even if -0.00001f

#if 0 // Print all HDR colors
	if (any(color != saturate(color))) {
		return DEBUG_COLOR;
	}
#endif

	color = lerp(originalColor, color, HdrDllPluginConstants.LUTCorrectionStrength);

	return color;
}

// Dispatch size is 1 1 16 (x and y have one thread and one thread group, while z has 16 thread groups with a thread each)
[RootSignature(ShaderRootSignature)]
[numthreads(LUT_SIZE_UINT, LUT_SIZE_UINT, 1)]
void CS(uint3 SV_DispatchThreadID : SV_DispatchThreadID)
{
	const uint3 inUVW = ThreeToTwoDimensionCoordinates(SV_DispatchThreadID);
	const uint3 outUVW = SV_DispatchThreadID;

	float3 neutralLUTColor = float3(outUVW) / (LUT_SIZE - 1.f); // The neutral LUT is automatically generated by the coordinates, but it's baked with sRGB or 2.2 gamma
	neutralLUTColor = LINEARIZE(neutralLUTColor); //TODO1

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
#elif LUT_IMPROVEMENT_TYPE == 2
	float neutralLUTLuminance = Luminance(neutralLUTColor);
	float LUT1Luminance = Luminance(LUT1Color);
	float LUT2Luminance = Luminance(LUT2Color);
	float LUT3Luminance = Luminance(LUT3Color);
	float LUT4Luminance = Luminance(LUT4Color);

	if (LUT1Luminance != 0.f)
	{
		LUT1Color *= lerp(1.f, neutralLUTLuminance / LUT1Luminance, HdrDllPluginConstants.LUTCorrectionStrength);
		if (SDRRange)
			LUT1Color = saturate(LUT1Color);
	}
	if (LUT2Luminance != 0.f)
	{
		LUT2Color *= lerp(1.f, neutralLUTLuminance / LUT2Luminance, HdrDllPluginConstants.LUTCorrectionStrength);
		if (SDRRange)
			LUT2Color = saturate(LUT2Color);
	}
	if (LUT3Luminance != 0.f)
	{
		LUT3Color *= lerp(1.f, neutralLUTLuminance / LUT3Luminance, HdrDllPluginConstants.LUTCorrectionStrength);
		if (SDRRange)
			LUT3Color = saturate(LUT3Color);
	}
	if (LUT4Luminance != 0.f)
	{
		LUT4Color *= lerp(1.f, neutralLUTLuminance / LUT4Luminance, HdrDllPluginConstants.LUTCorrectionStrength);
		if (SDRRange)
			LUT4Color = saturate(LUT4Color);
	}
#endif // LUT_IMPROVEMENT_TYPE

	neutralLUTColor = CORRECT_GAMMA(neutralLUTColor);
	LUT1Color = CORRECT_GAMMA(LUT1Color);
	LUT2Color = CORRECT_GAMMA(LUT2Color);
	LUT3Color = CORRECT_GAMMA(LUT3Color);
	LUT4Color = CORRECT_GAMMA(LUT4Color);

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

// Convert to sRGB after blending between LUTs, so the blends are done in linear space, which gives more consistent and correct results
#if !LUT_FIX_GAMMA_MAPPING

	mixedLUT = gamma_linear_to_sRGB(mixedLUT);

#endif // !LUT_FIX_GAMMA_MAPPING

	OutMixedLUT[outUVW] = float4(mixedLUT, 1.f);
}
