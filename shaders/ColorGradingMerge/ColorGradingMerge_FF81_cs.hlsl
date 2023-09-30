#include "../shared.hlsl"
#include "../color.hlsl"
#include "../math.hlsl"

// 0 None, 1 ShortFuse technique (normalization), 2 luminance preservation (doesn't look so good)
#define LUT_IMPROVEMENT_TYPE 1
#define FORCE_SDR_RANGE_LUTS 0
// Make some small quality cuts for the purpose of optimization
#define OPTIMIZE_LUT_ANALYSIS true
// For future development
#define UNUSED_PARAMS 0

static float additionalNeutralLUTPercentage = 0.0f;
static float LUTCorrectionPercentage = 1.0f;

cbuffer CPushConstantWrapper_ColorGradingMerge : register(b0, space0)
{
    PushConstantWrapper_ColorGradingMerge PcwColorGradingMerge : packoffset(c0);
};

Texture2D<float3> LUT1 : register(t0, space8);
Texture2D<float3> LUT2 : register(t1, space8);
Texture2D<float3> LUT3 : register(t2, space8);
Texture2D<float3> LUT4 : register(t3, space8);
RWTexture3D<float4> OutMixetLUT : register(u0, space8);

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

    // TODO: do we need these branches? Shaders are best without branches, especially when they could be replaced by min/max math.
    // Is the branch to prevent weird LUTs from being adjusted?
    if ((analysis.whiteY > analysis.blackY)
        && ((analysis.whiteY - analysis.blackY) < 1.f))
    {
        // Lower black floor (shadow pass):
        // In 3D space, drags all points towards 0 relative to how much black
        // point has moved (eg (on 256): -4, -10, -5)
        // Distance from 0 is factor to decide how much each pixel should move,
        // with (1) (white) not moving at all.
        // *Applying to each channel individually also removes tint
        const float3 reduceFactor = lerp(1.f / (1.f - analysis.black), 1.f, pow(neutralLUTColor, 2.f)); //TODO: test pow

        // Reapply tint without raising black floor:
        // In 3D space, shift points away from black **per channel** to
        // reintroduce tint back to the pixels. Use multiplication to avoid
        // raised black floor.
        const float3 increaseFactor = lerp(1.f + analysis.black, 1.f, neutralLUTColor);

        // color * reduce = [0,1] relative to XYZ:
        // result *= black tint
        // (0,0,0) must always compute to 0
        // (1,1,1) must remain unchanged
        // Scaling is strongest at 0, and weakest at 1 (none)
        color = (1.f - ((1.f - color) * reduceFactor)) * increaseFactor;
                
#if 0 // "Invalid" range analysis
        if (any(color > 1))
        {
            return 0;
        }
        else if (any(color < 0))
        {
            return 1;
        }
#endif
        
#if 0 // TODO: the above code introduces a lot of colors beyond the 0-1 range, which will then get clipped, causing a hue shift
        // Color may have gone negative
        // For example, if black is (3,3,3) and another value is (0,0,4), that
        // may result in (-3,-3,1)
        color = clamp(color, 0.f, FLT_MAX);
#endif
        
        static const float cubeNormalization = sqrt(3.f); // Normalize to 0-1 range
        // How distant are our LUT coordinates from black or white in 3D cube space?
        const float blackDistance = hypot3(neutralLUTColor) / cubeNormalization;
        const float whiteDistance = hypot3(1.f - neutralLUTColor) / cubeNormalization;
        const float totalRange = blackDistance + whiteDistance;

        const float currentY = Luminance(color); // In case this was negative, the shadows raise pass should bring it back to the >= 0 range
        
        // Brightness multiplier from shadows:
        // Because the amount the black level was raised is proportional to
        // the harshness of a linear gradient, a compensation must be made
        // to avoid black crushing, and maintain visibility at certain
        // points in the LUT. The scaling used will be relative to the
        // raised black floor level to ensure proportional consistency per
        // LUT. This is only done to the newly created shadow section (if any).
        // Simplified, if black started raised, a new shadow section was
        // created, and that needs extra luminance for visibility.
        const float shadowsRaise = linearNormalization(
            min(currentY, analysis.blackY),
            0.f,
            analysis.blackY,
            1.f + analysis.blackY, // Shadow compensation percentage ramp factor
            1.f);
        // TODO: Analyze grayscale for shadow raise. For example, if black shadow was raised
        // by 5%, then analyze the ramping from 5%-10% and apply that to
        // the new 0% - 5% raise.
        
        // TODO: apply both shadow and highlight raise to the whole image range, instead of a portion of it, to make its gradient smoother? Or maybe apply it in perceptual (gamma) space.
        // The functions could also be simplified a lot.
        
        // Brightness multiplier from highlights:
        // Boost luminance of all texels relative to their distance to white
        // and how much white is to be raised.
        // (ie: white drags everything towards it)
        float highlightsRaise = linearNormalization(
            whiteDistance,
            0.f,
            totalRange,
            1.f / analysis.whiteY,
            1.f);
        // Scale by the maximum value this could ever have, so it's normalized and we are guaranteed target luminance doesn't go beyond 1.
        highlightsRaise *= SDRRange ? analysis.whiteY : 1.f;
        const float targetY = currentY * highlightsRaise * shadowsRaise;

        // TODO: why are we clamping to full white here? luminance 1 (or beyond) might not match a white color at all, should we instead try to conserve the hue? Though that's much harder as we'd need to analyze more LUT pixels.
        if (SDRRange && targetY >= 1.f)
        {
            color = 1.f; // Clamp (clip to full white, it also looks great with external AutoHDR)
            // Or, limit to max luminance while maintaining hue, though may result in LUT max Y being below 1
            // Or, still target full white for (1,1,1), but scale others relative to whiteY
            // Or, don't adjust unless white point
        }
        else
        {
            color *= max(targetY, 0.f) / max(currentY, 0.f); // Clamp luminances to avoid a double negative creating a positive number
        }

        // Optional step to keep colors in the SDR range.
        if (SDRRange)
        {
            color = saturate(color);
        }
        // TODO: consider removing this if it's proven unnecessary on all LUTs
        // Some protection against invalid colors
        else if (Luminance(color) < 0.f)
        {
            color = 0.f;
        }
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

#if LUT_IMPROVEMENT_TYPE == 0 || LUT_IMPROVEMENT_TYPE == 2
    float3 LUT1Color = LUT1.Load(inUVW);
    float3 LUT2Color = LUT2.Load(inUVW);
    float3 LUT3Color = LUT3.Load(inUVW);
    float3 LUT4Color = LUT4.Load(inUVW);
    LUT1Color = gamma_sRGB_to_linear(LUT1Color);
    LUT2Color = gamma_sRGB_to_linear(LUT2Color);
    LUT3Color = gamma_sRGB_to_linear(LUT3Color);
    LUT4Color = gamma_sRGB_to_linear(LUT4Color);
#endif // LUT_IMPROVEMENT_TYPE

#if LUT_IMPROVEMENT_TYPE == 1
    const bool SDRRange = !((bool)ENABLE_HDR) || (bool)FORCE_SDR_RANGE_LUTS;
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
    }
    if (LUT2Luminance != 0.f)
    {
        LUT2Color *= lerp(1.f, neutralLUTLuminance / LUT2Luminance, LUTCorrectionPercentage);
    }
    if (LUT3Luminance != 0.f)
    {
        LUT3Color *= lerp(1.f, neutralLUTLuminance / LUT3Luminance, LUTCorrectionPercentage);
    }
    if (LUT4Luminance != 0.f)
    {
        LUT4Color *= lerp(1.f, neutralLUTLuminance / LUT4Luminance, LUTCorrectionPercentage);
    }
#endif // LUT_IMPROVEMENT_TYPE

    float adjustedNeutralLUTPercentage = lerp(PcwColorGradingMerge.neutralLUTPercentage, 1.f, additionalNeutralLUTPercentage);
    float adjustedLUT1Percentage = lerp(PcwColorGradingMerge.LUT1Percentage, 0.f, additionalNeutralLUTPercentage);
    float adjustedLUT2Percentage = lerp(PcwColorGradingMerge.LUT2Percentage, 0.f, additionalNeutralLUTPercentage);
    float adjustedLUT3Percentage = lerp(PcwColorGradingMerge.LUT3Percentage, 0.f, additionalNeutralLUTPercentage);
    float adjustedLUT4Percentage = lerp(PcwColorGradingMerge.LUT4Percentage, 0.f, additionalNeutralLUTPercentage);

    float3 mixedLUT = (adjustedNeutralLUTPercentage * neutralLUTColor)
                    + (adjustedLUT1Percentage * LUT1Color)
                    + (adjustedLUT2Percentage * LUT2Color)
                    + (adjustedLUT3Percentage * LUT3Color)
                    + (adjustedLUT4Percentage * LUT4Color);

// Convert to sRGB after blending between LUTs, so the blends are done in linear space, which gives more consistent and correct results
#if !LUT_FIX_GAMMA_MAPPING

    mixedLUT = gamma_linear_to_sRGB(mixedLUT);

#endif // !LUT_FIX_GAMMA_MAPPING

    OutMixetLUT[outUVW] = float4(mixedLUT, 1.f);
}
