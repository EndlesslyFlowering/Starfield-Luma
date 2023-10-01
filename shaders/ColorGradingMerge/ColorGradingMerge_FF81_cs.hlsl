#include "../shared.hlsl"
#include "../color.hlsl"
#include "../math.hlsl"

// 0 None, 1 ShortFuse technique (normalization), 2 luminance preservation (doesn't look so good and it's kinda broken in SDR)
#define LUT_IMPROVEMENT_TYPE 1
#define FORCE_SDR_LUTS 0
// Make some small quality cuts for the purpose of optimization
#define OPTIMIZE_LUT_ANALYSIS true
// For future development
#define UNUSED_PARAMS 0
#define LUT__DEBUG_VALUES true

#define LUT__CLAMP_HIGHLIGHTS_IN_HDR false
#define LUT__CLAMP_HIGHLIGHTS_IN_HDR false

// Enum: {0: AS_IS, 1: ORIGINAL, 2:WHITE, 3: MAX_HUE, 4: CLAMP }
#define LUT__SDR__ON_CLIP 1
#define LUT__HDR__ON_CLIP 0


static float AdditionalNeutralLUTPercentage = 0.f; // ~0.25 might be a good compromise
static float LUTCorrectionPercentage = 1.f;

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
	Analysis.black = gamma_sRGB_to_linear(LUT.Load(ThreeToTwoDimensionCoordinates(0u)).rgb);
	Analysis.blackY = Luminance(Analysis.black);
	Analysis.white = gamma_sRGB_to_linear(LUT.Load(ThreeToTwoDimensionCoordinates(LUT_SIZE_UINT - 1u)).rgb);
	Analysis.whiteY = Luminance(Analysis.white);
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
				float3 LUTColor = gamma_sRGB_to_linear(LUT.Load(ThreeToTwoDimensionCoordinates(uint3(x, y, z))).rgb);

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

	//TODO: either store min/max channels merged or separately, but not both
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

// Analyzes each LUT texel and normalize their range.
// Slow but effective.
float3 PatchLUTColor(Texture2D<float3> LUT, uint3 UVW, float3 neutralLUTColor, bool SDRRange = false)
{
	LUTAnalysis analysis;
	AnalyzeLUT(LUT, analysis);

	float3 color = gamma_sRGB_to_linear(LUT.Load(UVW));
	const float3 originalColor = color;

	// TODO: Remove if branching

	// If LUT is inversed (eg: photo negative) don't do anything
	if (analysis.whiteY < analysis.blackY) return originalColor; // Inversed LUT
	
	// If LUT is full range already nothing to do
	if (analysis.whiteY - analysis.blackY >= 1.f) return lerp(originalColor, color, LUTCorrectionPercentage);

	// Return black on (0,0,0)
	if (!any(originalColor)) return float3(0.f, 0.f, 0.f);

	// Return white on (1,1,1)
	const float3 white = float3(1.f,1.f,1.f);
	if (dot(originalColor, white) >= 3.f) return white;

#if LUT__DEBUG_VALUES
	float3 DEBUG_COLOR = float3(1.f,0,1.f); // Magenta
#endif


	const float currentY = Luminance(color);

	// While it unclear how exactly the floor was raised, remove the tint to floor
	// the values to 0. Then we can reapply the tint back up.
	// This will give us a hue shifted value that we can then use as a basis for 
	// the new darkened Y value.
	const float3 reduceFactor = linearNormalization<float3>(
		neutralLUTColor, 
		0.f,
		1.f,
		1.f / (1.f - analysis.black),
		1.f);

	const float3 increaseFactor = linearNormalization<float3>(
			neutralLUTColor,
			0.f,
			1.f,
			1.f + analysis.black,
			1.f);

	float3 retintedColor = (1.f - ((1.f - color) * reduceFactor)) * increaseFactor;

	// Floor channels that went under 0 (invalid channels produces wrong Y values)
	retintedColor = max(retintedColor, 0.f);

	const float retintedColorY = Luminance(retintedColor);

#if LUT__DEBUG_VALUES
  // retintedColorY should never be negative
	if (retintedColorY < 0) return DEBUG_COLOR;
#endif

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

#if LUT__DEBUG_VALUES
  // whiteY most always be > 0
	if (analysis.whiteY <= 0) return DEBUG_COLOR;
#endif

	// Increase the luminance by how much white is reduced

	const float inverseWhiteClamp = 1.f / analysis.whiteY;

	// Apply inverse clamp relative to how much whiteDistance makes up of total range
	// If whiteDistance takes up whole range (eg: black) then apply all of inverseClamp)
	// If whiteDistance takes up none of the whole range (eg: white) then apply 1
	// Interpolate values between
	const float increaseY = linearNormalization(whiteDistance, 0.f, totalRange, inverseWhiteClamp, 1.f);

#if LUT__DEBUG_VALUES
  // increaseY must always be >= 1
	if (increaseY < 1) return DEBUG_COLOR;
#endif

  float newY = retintedColorY * increaseY;

	// If brightenedY is less than the decreaseY, newY will become negative.
	// This occurs if the black point isn't the darkest point on the cube.

	// When darkening luminance on the LUT, we may find colors that have a
	// luminance darker than the previous black point
	// To ensure a smooth gradient, we should handle this new shadow section
	// of the cube manually. 
	// This is only done to the newly created shadow section (if any).
	// This range never existed before so we're free to pick new values for Y

	if (newY < analysis.blackY) {
		// Take the shadow section and apply a linear ramp from 0 to blackY
		const float shadowCompensationPercentage = 1.f - analysis.blackY;
		// If newY is at 0, apply maximum scaling
		// If newY is at blackY, apply no change (1)
		// Interpolate between
		newY *= linearNormalization(newY, 0.f, analysis.blackY, 1.f + shadowCompensationPercentage, 1.f);
	}

#if LUT__SDR__ON_CLIP > 0 || LUT__HDR__ON_CLIP > 0
	if (newY >= 1.f) {
	#if LUT__SDR__ON_CLIP > 0 && LUT__SDR__ON_CLIP != LUT__HDR__ON_CLIP 
		if (SDRRange) {
	#endif

	#if LUT__SDR__ON_CLIP == 1
		// Original (do nothing)
	#elif LUT__SDR__ON_CLIP == 2
		// White
		color = white;
	#elif LUT__SDR__ON_CLIP == 3
		// TODO MAX_HUE
	#elif LUT__SDR__ON_CLIP == 4
		color *= max(newY / min(currentY, 1.f), 1.f);
	#endif

	#if LUT__SDR__ON_CLIP > 0 && LUT__SDR__ON_CLIP != LUT__HDR__ON_CLIP 
		}
		#if LUT__HDR__ON_CLIP > 0
		else {
		#endif
	#endif

	#if LUT__SDR__ON_CLIP == 0 && LUT__HDR__ON_CLIP > 0
		if (!SDRRange) {
	#endif

	#if LUT__HDR__ON_CLIP != LUT__SDR_ON_CLIP
		#if LUT__HDR__ON_CLIP == 1
			// Original (do nothing)
		#elif LUT__HDR__ON_CLIP == 2
			// White
			color = white;
		#elif LUT__HDR__ON_CLIP == 3
 			// TODO MAX_HUE
		#elif LUT__HDR__ON_CLIP == 4
			color *= max(newY / min(currentY, 1.f), 1.f);
		#endif
	#endif
	#if LUT__HDR__ON_CLIP > 0 && LUT__SDR__ON_CLIP != LUT__HDR__ON_CLIP
		}
	#endif
	} else {
		color *= newY / min(currentY, 1.f); // Avoid divide by zero
	}
#elif
	color *= newY / min(currentY, 1.f); // Avoid divide by zero
#endif

	// Optional step to keep colors in the SDR range.
	if (SDRRange) {
		color = saturate(color);
	}

	color = lerp(originalColor, color, LUTCorrectionPercentage);

	return color;
}

// Dispatch size is 1 1 16 (x and y have one thread and one thread group, while z has 16 thread groups with a thread each)
[numthreads(LUT_SIZE_UINT, LUT_SIZE_UINT, 1)]
void CS(uint3 SV_DispatchThreadID : SV_DispatchThreadID)
{
	const uint3 inUVW = ThreeToTwoDimensionCoordinates(SV_DispatchThreadID);
	const uint3 outUVW = SV_DispatchThreadID;

	float3 neutralLUTColor = float3(outUVW) / (LUT_SIZE - 1.f); // The neutral LUT is automatically generated by the coordinates, but it's baked with sRGB gamma
	neutralLUTColor = gamma_sRGB_to_linear(neutralLUTColor);

#if LUT_IMPROVEMENT_TYPE != 1

	float3 LUT1Color = LUT1.Load(inUVW);
	float3 LUT2Color = LUT2.Load(inUVW);
	float3 LUT3Color = LUT3.Load(inUVW);
	float3 LUT4Color = LUT4.Load(inUVW);
	LUT1Color = gamma_sRGB_to_linear(LUT1Color);
	LUT2Color = gamma_sRGB_to_linear(LUT2Color);
	LUT3Color = gamma_sRGB_to_linear(LUT3Color);
	LUT4Color = gamma_sRGB_to_linear(LUT4Color);

#endif // LUT_IMPROVEMENT_TYPE

	const bool SDRRange = !((bool)ENABLE_HDR) || (bool)FORCE_SDR_LUTS;
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
		LUT1Color *= lerp(1.f, neutralLUTLuminance / LUT1Luminance, LUTCorrectionPercentage);
		if (SDRRange)
		{
			LUT1Color = saturate(LUT1Color);
		}
	}
	if (LUT2Luminance != 0.f)
	{
		LUT2Color *= lerp(1.f, neutralLUTLuminance / LUT2Luminance, LUTCorrectionPercentage);
		if (SDRRange)
		{
			LUT2Color = saturate(LUT2Color);
		}
	}
	if (LUT3Luminance != 0.f)
	{
		LUT3Color *= lerp(1.f, neutralLUTLuminance / LUT3Luminance, LUTCorrectionPercentage);
		if (SDRRange)
		{
			LUT3Color = saturate(LUT3Color);
		}
	}
	if (LUT4Luminance != 0.f)
	{
		LUT4Color *= lerp(1.f, neutralLUTLuminance / LUT4Luminance, LUTCorrectionPercentage);
		if (SDRRange)
		{
			LUT4Color = saturate(LUT4Color);
		}
	}
#endif // LUT_IMPROVEMENT_TYPE

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
