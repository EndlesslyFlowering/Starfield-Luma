#include "../shared.hlsl"
#include "../color.hlsl"
#include "../math.hlsl"

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
    float minChannel;
    float maxChannel;
    float3 black;
    float3 white;
#if UNUSED_PARAMS
    float minY;
    float maxY;
    float averageY;
    float range;
    float blackY;
    float whiteY;
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
    Analysis.black = gamma_sRGB_to_linear(LUT.Load(ThreeToTwoDimensionCoordinates(0)).rgb);
    Analysis.white = gamma_sRGB_to_linear(LUT.Load(ThreeToTwoDimensionCoordinates(LUT_SIZE_UINT - 1u)).rgb);
#if UNUSED_PARAMS
    Analysis.minY = FLT_MAX;
    Analysis.maxY = -FLT_MAX;
    Analysis.blackY = Luminance(Analysis.black);
    Analysis.whiteY = Luminance(Analysis.white);
#endif // UNUSED_PARAMS

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

#if UNUSED_PARAMS
                float Y = Luminance(LUTColor);
                Analysis.minY = min(Analysis.minY, Y);
                Analysis.maxY = max(Analysis.maxY, Y);
                Ys += Y;

                colors += LUTColor.r;
#endif // UNUSED_PARAMS
            }
        }
    }

    //TODO: either store min/max channels merged or separately, but not both
    Analysis.minChannel = min(minColor.r, min(minColor.g, minColor.b));
    Analysis.maxChannel = max(maxColor.r, max(maxColor.g, maxColor.b));

#if UNUSED_PARAMS
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

    // Black will be scaled by min channel
    float3 scaledBlack = 1.f - ((1.f - analysis.black) * (1.f / (1.f - analysis.minChannel)));
    // White will be scaled up by max channel
    float3 scaledWhite = analysis.white / analysis.maxChannel;
    float scaledBlackY = Luminance(scaledBlack);
    float scaledWhiteY = Luminance(scaledWhite);

#if 0 //TODO: delete once verified this works
    float scaleDown = (0.f - analysis.minChannel);
    float scaleUp = (1.f - analysis.maxChannel);
    if (saturate(scaleDown)    != scaleDown
     || saturate(scaleUp)      != scaleUp
     || saturate(scaledBlackY) != scaledBlackY
     || saturate(scaledWhiteY) != scaledWhiteY)
    {
        return 0;
    }
#endif

    float3 color = gamma_sRGB_to_linear(LUT.Load(UVW).rgb);
    const float3 originalColor = color;

    //TODO: convert to using lerp function???
    const float3 reducedColor = linearNormalization<float3>(neutralLUTColor, 0.f, 1.f, 1.f / (1.f - analysis.minChannel), 1.f);
    const float3 increasedColor = linearNormalization<float3>(neutralLUTColor, 0.f, 1.f, 1.f, 1.f / analysis.maxChannel);
    // Scale the color ("neutralLUTColor" here represents the coordinates of the point).
    color = (1.f - ((1.f - color) * reducedColor)) * increasedColor;

    const float blackDistance = hypot3(neutralLUTColor);
    const float whiteDistance = hypot3(1.f - neutralLUTColor);
    const float totalRange = (blackDistance + whiteDistance);

    const float sourceY = Luminance(color);
    if (sourceY > 0.f) // Black will always stay black (and should)
    {
        const float decreasedY = linearNormalization(blackDistance, 0.f, totalRange, 1.f / (1.f - scaledBlackY), 1.f);
        const float increasedY = linearNormalization(whiteDistance, 0.f, totalRange, 1.f / scaledWhiteY, 1.f);
        const float targetY = (1.f - ((1.f - sourceY) * decreasedY)) * increasedY;

        if (targetY >= 0.9999f && targetY <= 1.0005f)
        {
            color = 1.f; // Intentionally targeting pure white (1,1,1)
        }
        else if (SDRRange && targetY >= 0.999f)
        {
            color = 1.f; // Clamp
        }
        else
        {
            // targetY could be on LUTs (raised black point and dark blues)
            color *= max(targetY, 0.f) / sourceY;
        }
    }
    else
    {
        color = 0; // Color may have gone below 0 when scaling
    }

    // Optional step to keep colors in the SDR range.
    if (SDRRange)
    {
        color = saturate(color);
    }

    color = lerp(originalColor, color, LUTCorrectionPercentage);

    return color;
}


// Dispatch size is 1 1 16 (x and y have one thread and one thread group, while z has 16 thread groups with a thread each)
[numthreads(LUT_SIZE_UINT, LUT_SIZE_UINT, 1)]
void CS(uint3 SV_DispatchThreadID : SV_DispatchThreadID)
{
    const int3 inUVW = ThreeToTwoDimensionCoordinates(SV_DispatchThreadID);
    #define outUVW SV_DispatchThreadID

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
    const bool SDRRange = false;
    float3 LUT1Color = PatchLUTColor(LUT1, inUVW, neutralLUTColor, SDRRange);
    float3 LUT2Color = PatchLUTColor(LUT3, inUVW, neutralLUTColor, SDRRange);
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

#if LUT_ADDITIONAL_NEUTRAL_PERCENTAGE

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

#else

    float3 mixedLUT = (PcwColorGradingMerge.neutralLUTPercentage * neutralLUTColor)
                    + (PcwColorGradingMerge.LUT1Percentage * LUT1Color)
                    + (PcwColorGradingMerge.LUT2Percentage * LUT2Color)
                    + (PcwColorGradingMerge.LUT3Percentage * LUT3Color)
                    + (PcwColorGradingMerge.LUT4Percentage * LUT4Color);

#endif // LUT_ADDITIONAL_NEUTRAL_PERCENTAGE

// Convert to sRGB after blending between LUTs, so the blends are done in sRGB space
#if !LUT_FIX_GAMMA_MAPPING

    mixedLUT = gamma_linear_to_sRGB(mixedLUT);

#endif // !LUT_FIX_GAMMA_MAPPING

    OutMixetLUT[outUVW] = float4(mixedLUT, 1.f);
}
