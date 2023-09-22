#include "../shared.h"
#include "../color.h"
#include "../math.h"

// 0 None, 1 ShortFuse technique (normalization), 2 luminance preservation (doesn't look so good)
#define LUT_IMPROVEMENT_TYPE 1

static float additionalNeutralLUTPercentage = 0.0f;
static float LUTCorrectionPercentage = 1.0f;

struct PushConstantWrapper_ColorGradingMerge
{
    float LUT1Percentage;
    float LUT2Percentage;
    float LUT3Percentage;
    float LUT4Percentage;
    float neutralLUTPercentage;
};

cbuffer PushConstantWrapper_ColorGradingMerge : register(b0, space0)
{
    PushConstantWrapper_ColorGradingMerge PcwColorGradingMerge : packoffset(c0);
};

struct LUTAnalysis
{
    float minY;
    float maxY;
    float averageY;
    float range;
    float3 black;
    float3 white;
    float blackY;
    float whiteY;
    //float medianY;
    float minChannel;
    float averageChannel;
    float maxChannel;
    float averageRed;
    float averageGreen;
    float averageBlue;
    float maxRed;
    float maxGreen;
    float maxBlue;
    float minRed;
    float minGreen;
    float minBlue;
};

void AnalyzeLUT(Texture2D<float3> LUT, inout LUTAnalysis Analysis)
{
    Analysis.minY = FLT_MAX;
    Analysis.maxY = 0.f;
    Analysis.minRed = FLT_MAX;
    Analysis.minBlue = FLT_MAX;
    Analysis.minGreen = FLT_MAX;
    Analysis.maxRed = 0.f;
    Analysis.maxBlue = 0.f;
    Analysis.maxGreen = 0.f;
    Analysis.black = gamma_sRGB_to_linear(LUT.Load(int3(0, 0, 0)).rgb);
    Analysis.white = gamma_sRGB_to_linear(LUT.Load(int3(1, 1, 1)).rgb);
    Analysis.blackY = Luminance(Analysis.black);
    Analysis.whiteY = Luminance(Analysis.white);
    
    float reds = 0.f;
    float greens = 0.f;
    float blues = 0.f;
    float Ys = 0.f;
    
    const uint texelCount = LUT_SIZE * LUT_SIZE * LUT_SIZE;
    
    for (uint x = 0; x < (uint)LUT_SIZE; x++)
    {
        for (uint y = 0; y < (uint)LUT_SIZE; y++)
        {
            for (uint z = 0; z < (uint)LUT_SIZE; z++)
            {
                const uint inU = (z << 4u) + x;
                const uint3 inUVW = uint3(inU, y, 0u); // In pixels
                float3 LUTColor = gamma_sRGB_to_linear(LUT.Load(inUVW).rgb);
                
                float Y = Luminance(LUTColor);
                Analysis.minY = min(Analysis.minY, Y);
                Analysis.maxY = max(Analysis.maxY, Y);

                Analysis.minRed = min(Analysis.minRed, LUTColor.r);
                Analysis.minGreen = min(Analysis.minGreen, LUTColor.g);
                Analysis.minBlue = min(Analysis.minBlue, LUTColor.b);

                Analysis.maxRed = max(Analysis.maxRed, LUTColor.r);
                Analysis.maxGreen = max(Analysis.maxGreen, LUTColor.g);
                Analysis.maxBlue = max(Analysis.maxBlue, LUTColor.b);
                
                reds += LUTColor.r;
                greens += LUTColor.g;
                blues += LUTColor.b;
                Ys += Y;
            }
        }
    }
    
    //TODO: either store min/max channels merged or separately, but not both
    Analysis.minChannel = max(Analysis.minRed, max(Analysis.minGreen, Analysis.minBlue));
    Analysis.maxChannel = max(Analysis.maxRed, max(Analysis.maxGreen, Analysis.maxBlue));
    
    Analysis.averageY = Ys / texelCount;
    Analysis.averageRed = reds / texelCount;
    Analysis.averageGreen = greens / texelCount;
    Analysis.averageBlue = blues / texelCount;

    //TODO: necessary?
    Analysis.averageChannel = (Analysis.averageRed + Analysis.averageGreen + Analysis.averageBlue) / 3.f;
    //TODO: unncessary?
    Analysis.range = Analysis.maxY - Analysis.minY;
    
    //TODO: ??? Can't do this in shader but it's not needed
    //Ys.sort((a, b) => a - b);
    //Analysis.medianY = ((Ys[Math.floor(texelCount / 2)]) + (Ys[Math.ceil(texelCount / 2)])) / 2;
}

// Analyzes each LUT texel and normalize their range.
// Slow but effective.
float3 PatchLUTColor(Texture2D<float3> LUT, uint3 UVW, bool SDRRange = false)
{
    LUTAnalysis analysis;
    AnalyzeLUT(LUT, analysis);
    
    float scaleDown = (0.f - analysis.minChannel);
    float scaleUp = (1.f - analysis.maxChannel);
    // Black will be scaled by min channel
    float3 scaledBlack = analysis.black - analysis.minChannel;
    // White will be scaled up by max channel
    float3 scaledWhite = analysis.white + (1.f - analysis.maxChannel);
    float scaledBlackY = Luminance(scaledBlack);
    float scaledWhiteY = Luminance(scaledWhite);
    
#if 0 //TODO: delete once verified this works
    if (saturate(scaleDown) != scaleDown || saturate(scaleUp) != scaleUp
        || saturate(scaledBlackY) != scaledBlackY || saturate(scaledWhiteY) != scaledWhiteY)
    {
        return 0;
    }
#endif
    
    float3 color = gamma_sRGB_to_linear(LUT.Load(UVW).rgb);
    float3 originalColor = color;
    
    float blackDistance = hypot3(color);
    float whiteDistance = hypot3(1.f - color);
    float totalRange = (blackDistance + whiteDistance);

    float3 scaledColor = linearNormalization(color, 0.f, 1.f, scaleDown, scaleUp);
    color += scaledColor;

    float YChange = linearNormalization<float>(blackDistance, 0.f, totalRange, -scaledBlackY, 1.f - scaledWhiteY);
    float Y = Luminance(color);
    if (Y > 0.f) // Black will always stay black (and should)
    {
        float targetY = Y + YChange;
        if (SDRRange && targetY >= 1.f) // Retarget to pure white
            color = 1.f;
        else
            color *= targetY / Y;
    }
    
    // Optional step to keep colors in the SDR range.
    if (SDRRange)
        color = saturate(color);
    
    color = lerp(originalColor, color, LUTCorrectionPercentage);
    
    return color;
}

Texture2D<float3> LUT1 : register(t0, space8);
Texture2D<float3> LUT2 : register(t1, space8);
Texture2D<float3> LUT3 : register(t2, space8);
Texture2D<float3> LUT4 : register(t3, space8);
RWTexture3D<float4> outMixedLUT : register(u0, space8);

static uint3 gl_GlobalInvocationID;
struct SPIRV_Cross_Input
{
    uint3 gl_GlobalInvocationID : SV_DispatchThreadID;
};

void CS()
{
    const uint3 outUVW = uint3(gl_GlobalInvocationID.x, gl_GlobalInvocationID.y, gl_GlobalInvocationID.z); // In pixels
    const uint inU = (gl_GlobalInvocationID.z << 4u) + gl_GlobalInvocationID.x; // 4u is (LUT_SIZE / 4)
    const uint3 inUVW = uint3(inU, gl_GlobalInvocationID.y, 0u); // In pixels
    const float UVWScale = 1.f / (LUT_SIZE - 1.f); // Was "0.066666670143604278564453125", pixel coordinates 0-15 for a resolution of 16, which is half of LUTs size of 16x16x16
    
    float3 neutralLUTColor = float3(outUVW) * UVWScale; // The neutral LUT is automatically generated by the coordinates, but it's baked with sRGB gamma
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
    
#if LUT_IMPROVEMENT_TYPE == 0
    // Nothing to do
#elif LUT_IMPROVEMENT_TYPE == 1
    const bool SDRRange = false;
    float3 LUT1Color = PatchLUTColor(LUT1, inUVW, SDRRange);
    float3 LUT2Color = PatchLUTColor(LUT3, inUVW, SDRRange);
    float3 LUT3Color = PatchLUTColor(LUT3, inUVW, SDRRange);
    float3 LUT4Color = PatchLUTColor(LUT4, inUVW, SDRRange);
#elif LUT_IMPROVEMENT_TYPE == 2
    float neutralLUTLuminance = Luminance(neutralLUTColor);
    float LUT1Luminance = Luminance(LUT1Color);
    float LUT2Luminance = Luminance(LUT2Color);
    float LUT3Luminance = Luminance(LUT3Color);
    float LUT4Luminance = Luminance(LUT4Color);
    
    if (LUT1Luminance != 0.f)
        LUT1Color *= lerp(1.f, neutralLUTLuminance / LUT1Luminance, LUTCorrectionPercentage);
    if (LUT2Luminance != 0.f)
        LUT2Color *= lerp(1.f, neutralLUTLuminance / LUT2Luminance, LUTCorrectionPercentage);
    if (LUT3Luminance != 0.f)
        LUT3Color *= lerp(1.f, neutralLUTLuminance / LUT3Luminance, LUTCorrectionPercentage);
    if (LUT4Luminance != 0.f)
        LUT4Color *= lerp(1.f, neutralLUTLuminance / LUT4Luminance, LUTCorrectionPercentage);
#endif // LUT_IMPROVEMENT_TYPE
    
#if !FIX_LUT_GAMMA_MAPPING && 0 // Disabled as it's still preferable to do LUT blends in linear space
    neutralLUTColor = gamma_linear_to_sRGB(neutralLUTColor);
    LUT1Color = gamma_linear_to_sRGB(LUT1Color);
    LUT2Color = gamma_linear_to_sRGB(LUT2Color);
    LUT3Color = gamma_linear_to_sRGB(LUT3Color);
    LUT4Color = gamma_linear_to_sRGB(LUT4Color);
#endif // FIX_LUT_GAMMA_MAPPING
    
    PushConstantWrapper_ColorGradingMerge adjustedPcwColorGradingMerge = PcwColorGradingMerge;
    adjustedPcwColorGradingMerge.neutralLUTPercentage = lerp(adjustedPcwColorGradingMerge.neutralLUTPercentage, 1.f, additionalNeutralLUTPercentage);
    adjustedPcwColorGradingMerge.LUT1Percentage = lerp(adjustedPcwColorGradingMerge.LUT1Percentage, 0.f, additionalNeutralLUTPercentage);
    adjustedPcwColorGradingMerge.LUT2Percentage = lerp(adjustedPcwColorGradingMerge.LUT2Percentage, 0.f, additionalNeutralLUTPercentage);
    adjustedPcwColorGradingMerge.LUT3Percentage = lerp(adjustedPcwColorGradingMerge.LUT3Percentage, 0.f, additionalNeutralLUTPercentage);
    adjustedPcwColorGradingMerge.LUT4Percentage = lerp(adjustedPcwColorGradingMerge.LUT4Percentage, 0.f, additionalNeutralLUTPercentage);
    
    float3 mixedLUT = (adjustedPcwColorGradingMerge.neutralLUTPercentage * neutralLUTColor)
                          + (adjustedPcwColorGradingMerge.LUT1Percentage * LUT1Color)
                          + (adjustedPcwColorGradingMerge.LUT2Percentage * LUT2Color)
                          + (adjustedPcwColorGradingMerge.LUT3Percentage * LUT3Color)
                          + (adjustedPcwColorGradingMerge.LUT4Percentage * LUT4Color);
#if !FIX_LUT_GAMMA_MAPPING // Convert to linear after blending between LUTs, so the blends are done in linear space
    mixedLUT = gamma_linear_to_sRGB(mixedLUT);
#endif // FIX_LUT_GAMMA_MAPPING
    outMixedLUT[outUVW] = float4(mixedLUT, 1.f);
}

[numthreads(16, 16, 1)]
void main(SPIRV_Cross_Input stage_input)
{
    gl_GlobalInvocationID = stage_input.gl_GlobalInvocationID;
    CS();
}