#include "../shared.hlsl"
#include "../color.hlsl"
#include "../math.hlsl"

// These are defined at compile time (shaders permutations)
//#define APPLY_BLOOM
//#define APPLY_TONEMAPPING
//#define APPLY_CINEMATICS
//#define APPLY_MERGED_COLOR_GRADING_LUT

#define SDR_USE_GAMMA_2_2 0
#define FIX_WRONG_SRGB_GAMMA 1

// Also sets "ENABLE_LUT", "ENABLE_POST_PROCESS" and "ENABLE_INVERSE_TONEMAP"
#define ENABLE_TONEMAP 1
#define ENABLE_POST_PROCESS 1
#define ENABLE_PP_CONTRAST_ADJUSTMENT 1
#define ENABLE_LUT 1
#define ENABLE_REPLACED_TONEMAP 1
#define ENABLE_INVERSE_POST_PROCESS 0
#define CLAMP_INPUT_OUTPUT 1

#define LUT_USE_TETRAHEDRAL_INTERPOLATION 1

cbuffer CSharedFrameData : register(b0, space6)
{
    FrameData SharedFrameData : packoffset(c0);
};

cbuffer CPerSceneConstants : register(b0, space7)
{
    float4 PerSceneConstants[3269] : packoffset(c0);
};

cbuffer CPushConstantWrapper_HDRComposite : register(b0, space0)
{
    PushConstantWrapper_HDRComposite PcwHdrComposite : packoffset(c0);
};


Texture2D<float3> InputColor : register(t0, space9);

#if defined(APPLY_MERGED_COLOR_GRADING_LUT)

Texture2D<float3> LutMask : register(t1, space9);
Texture3D<float3> Lut     : register(t3, space9);

#endif

#if defined(APPLY_BLOOM)

Texture2D<float3> Bloom : register(t2, space9);

#endif

StructuredBuffer<HDRCompositeData> HdrCmpDat : register(t4, space9);

#if (defined(APPLY_MERGED_COLOR_GRADING_LUT) || defined(APPLY_BLOOM))

SamplerState Sampler0 : register(s0, space9); // Clamped Bilinear

#endif

struct PSInput
{
    float4 SV_Position : SV_Position0;
    float2 TEXCOORD    : TEXCOORD0;
};

struct PSOutput
{
    float4 SV_Target : SV_Target0;
};

// 1.1920928955078125e-07
#define EPSILON asfloat(0x34000000)
// LFLT = largest float less than 1 (actually the 2nd largest)
// 0.99999988079071044921875
#define LFLT1   asfloat(0x3F7FFFFE)
// 0.999989986419677734375
#define BTHCNST asfloat(0x3F7FFF58)

// 1.44269502162933349609375
#define LOG2_E     asfloat(0x3FB8AA3B)
// 0.693147182464599609375
#define RCP_LOG2_E asfloat(0x3F317218)

// 0.693147182464599609375f * log2(x) is the same as log(x)

// exp2(x * 1.44269502162933349609375f) is the same as exp(x)

static const float LUTStrength = 1.f;
static const float RestorePreLUTLuminance = 1.f;

static const float ACES_a = 2.51f;
static const float ACES_b = 0.03f;
static const float ACES_c = 2.43f;
static const float ACES_d = 0.59f;
static const float ACES_e = 0.14f;


static const float3x3 Bt709ToXYZ = float3x3(
    0.412135323426798,  0.357675002654190, 0.180356796374193,
    0.212507276141942,  0.715350005308380, 0.0721427185496773,
    0.0193188432856311, 0.119225000884730, 0.949879127570751);

static const float3x3 XYZToBt709 = float3x3(
     3.24297896532120,   -1.53833617585749,  -0.498919840818647,
    -0.968997952917093,   1.87549198225861,   0.0415445240532242,
     0.0556683243682128, -0.204117189350113,  1.05769816299604);


float3 ACES(float3 Color, bool Clamp, float modE, float modA)
{
    Color = (Color * (modA * Color + ACES_b)) / ((Color * (ACES_c * Color + ACES_d)) + modE);
    return Clamp ? saturate(Color) : Color;
}

// ACESFilm by Krzysztof Narkowicz (https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/)
// (color * ((a * color) + b)) / (color * ((c * color) + d) + e)
float3 ACESReference(float3 Color, bool Clamp)
{
    return ACES(Color, Clamp, ACES_e, ACES_a);
}

// ACESFilm "per scene"
float3 ACESParametric(in float3 Color, in bool Clamp, inout float modE, inout float modA)
{
    const float AcesParam0 = PerSceneConstants[3266u].x;
    const float AcesParam1 = PerSceneConstants[3266u].y;
    modE = AcesParam1;
    modA = ((0.56f / AcesParam0) + ACES_b) + (AcesParam1 / (AcesParam0 * AcesParam0));
    return ACES(Color, Clamp, modE, modA);
}

float3 ACES_Inverse(float3 Color, float modE, float modA)
{
    //TODO: does this apply for `ACESParametric` as well? Probably
    //TODO: figure out if we could still use the unclamped color. There should be a way to invert it.
    // ACES is not defined for any values beyond 0-1
    Color = saturate(Color);

    float3 fixed0 = (-ACES_d * Color) + ACES_b;
    float3 fixed1 = (ACES_c * Color) - modA;

    float3 variable_numerator_part0 = -fixed0;
    float3 variable_numerator = sqrt((variable_numerator_part0 * variable_numerator_part0) - (4.f * modE * Color * fixed1));

    float3 denominator = 2.f * fixed1;

    float3 result0 = (fixed0 + variable_numerator) / denominator;
    float3 result1 = (fixed0 - variable_numerator) / denominator;

    // "result1" is likely what we always want
    return max(result0, result1);
}

float3 ACESReference_Inverse(float3 Color)
{
    return ACES_Inverse(Color, ACES_e, ACES_a);
}

float3 ACESParametric_Inverse(float3 Color, float modE, float modA)
{
    return ACES_Inverse(Color, modE, modA);
}

// https://github.com/johnhable/fw-public
float3 Hable(
  in  float3 InputColor,
  out float  params_y0,
  out float  params_y1,
  out float  dstParams_W,
  out float  toeSegment_lnA,
  out float  toeSegment_B,
  out float  midSegment_offsetX,
  out float  midSegment_lnA,
  out float  shoulderSegment_offsetX,
  out float  shoulderSegment_offsetY,
  out float  shoulderSegment_lnA,
  out float  shoulderSegment_B,
  out float  invScale)
{
    // https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L202

    float toeLength        = pow(saturate(PerSceneConstants[3266u].w), 2.2f);
    float toeStrength      = saturate(PerSceneConstants[3266u].z);
    float shoulderLength   = clamp(saturate(PerSceneConstants[3267u].y), EPSILON, BTHCNST);
    float shoulderStrength = max(PerSceneConstants[3267u].x, 0.f);
    float shoulderAngle    = saturate(PerSceneConstants[3267u].z);

    //dstParams
    float dstParams_x0 = toeLength * 0.5f;
    float dstParams_y0 = (1.f - toeStrength) * dstParams_x0;

    float remainingY = 1.f - dstParams_y0;

    float y1_offset = (1.f - shoulderLength) * remainingY;
    //dstParams
    float dstParams_x1 = dstParams_x0 + y1_offset;
    float dstParams_y1 = dstParams_y0 + y1_offset;

    float extraW = exp2(shoulderStrength) - LFLT1;
    float initialW = dstParams_x0 + remainingY;
    dstParams_W = initialW + extraW;

    // "W * " was optimised away by DXIL->SPIRV->HLSL conversion as down the line there is a "/ W"
    float dstParams_overshootX = 2.f * shoulderAngle * shoulderStrength;
    float dstParams_overshootY = 0.5f * shoulderAngle * shoulderStrength;

    // https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L87

    //dstCurve
    float dstCurve_invW = 1.f / dstParams_W;
    //params
    float params_x0 = dstParams_x0 / dstParams_W;
    float params_x1 = dstParams_x1 / dstParams_W;
    //float params_overshootX = dstParams_overshootX / dstParams_W; // this step was optimised away
    #define params_overshootX dstParams_overshootX
    float dx = y1_offset / dstParams_W;

    // mid section
    // AsSlopeIntercept https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L67
    float m = (abs(dx) < EPSILON) ? 1.f : (y1_offset / dx);
    m += EPSILON;
    float b = dstParams_y0 - (m * params_x0);

    midSegment_offsetX = (b / m); //no minus
    float midSegment_lnA_optimised = log2(m);
    midSegment_lnA = RCP_LOG2_E * midSegment_lnA_optimised;
    // mid section end

    // https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L137-L138
    // max(EPSILON, pow(params_yX, gamma))
    params_y0 = max(EPSILON, dstParams_y0); // is pow(x, gamma) with gamma = 1
    //OLD: params_y0 = max(EPSILON, exp2(log2(dstParams_y0)));
    params_y1 = max(EPSILON, dstParams_y1); // is pow(x, gamma) with gamma = 1
    //OLD: params_y1 = max(EPSILON, exp2(log2(dstParams_y1)));

    // pow(1.f + dstParams_overshootY, gamma) - 1.f
    // -1 was optimised away as shoulderSegment_offsetY is params_overshootY + 1
    float params_overshootY = 1.f + dstParams_overshootY; // is pow(x, gamma) with gamma = 1
    //OLD: float params_overshootY = exp2(log2(1.f + dstParams_overshootY));

    // toe section
    // SolveAB https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L60
    toeSegment_B = (m * params_x0) / (params_y0 + EPSILON);
    float _410 = log2(params_y0); //doesn't belong to SolveAB (it might does)
    float toeSegment_lnA_optimised = -toeSegment_B * log(params_x0);
    toeSegment_lnA = _410 * RCP_LOG2_E + toeSegment_lnA_optimised;
    // toe section end

    // shoulder section
    float shoulderSection_x0 = 1.f + params_overshootX - params_x1;
    float shoulderSection_y0 = params_overshootY - params_y1; // 1 + x was optimised away
    shoulderSegment_offsetX = 1.f + params_overshootX;
    shoulderSegment_offsetY = params_overshootY; // x + 1 was optimised away
    // SolveAB
    shoulderSegment_B = ((m * shoulderSection_x0) / (shoulderSection_y0 + EPSILON));
    float shoulderSegment_B_optimised = shoulderSegment_B * RCP_LOG2_E;
    shoulderSegment_lnA = (log2(shoulderSection_y0) * RCP_LOG2_E) - (shoulderSegment_B_optimised * log2(shoulderSection_x0));
    // shoulder section end

    // https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L6
    // Eval
    float evalY0 = 0.f;
    if (params_overshootX > 0.f)
    {
        evalY0 = -exp2(((shoulderSegment_B_optimised * log2(params_overshootX)) + shoulderSegment_lnA) * LOG2_E) + params_overshootY;
    }
    // Eval end
    invScale = 1.f / (evalY0);

    float3 toneMapped;

    for (uint channel = 0; channel < 3; channel++)
    {
        float normX = InputColor[channel] * dstCurve_invW;
        bool isToeSegment = normX < params_x0;
        float returnChannel = 0.f;

        if (isToeSegment && normX > 0.f)
        {
            returnChannel = exp2(((((log2(normX) * toeSegment_B) + _410) * RCP_LOG2_E) + toeSegment_lnA_optimised) * LOG2_E);
        }
        else if (normX < params_x1)
        {
            float evalMidSegment_y0 = normX + midSegment_offsetX; //is -(-midSegment_offsetX)
            if (evalMidSegment_y0 > 0.f)
            {
                returnChannel = exp2(log2(evalMidSegment_y0) + midSegment_lnA_optimised);
            }
        }
        else
        {
            //float evalShoulderSegment_y0 = ((-1.f) - params_overshootX) + normX;
            // small optimisation from the original decompilation
            float evalShoulderSegment_y0 = (1.f + params_overshootX) - normX;
            float evalShoulderReturn = 0.f;
            if (evalShoulderSegment_y0 > 0.f)
            {
                evalShoulderReturn = exp2(((shoulderSegment_B_optimised * log2(evalShoulderSegment_y0)) + shoulderSegment_lnA) * LOG2_E);
            }
            returnChannel = params_overshootY - evalShoulderReturn;
        }
        toneMapped[channel] = returnChannel * invScale;
    }
    return toneMapped;
}

// https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L21-L34
float HableEval_Inverse(
  float Channel,
  float offsetX,
  float offsetY,
  float scaleX,
  float scaleY,
  float lnA,
  float B)
{
    float y0 = (Channel - offsetY) / scaleY;
    float x0 = 0.f;

    if (y0 > 0.f)
    {
        x0 = exp((log(y0) - lnA) / B);
    }

    return x0 / scaleX + offsetX;
}

// https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L45-L52
float3 Hable_Inverse(
  float3 InputColor,
  float  params_y0,
  float  params_y1,
  float  dstParams_W,
  float  toeSegment_lnA,
  float  toeSegment_B,
  float  midSegment_offsetX,
  float  midSegment_lnA,
  float  shoulderSegment_offsetX,
  float  shoulderSegment_offsetY,
  float  shoulderSegment_lnA,
  float  shoulderSegment_B,
  float  invScale)
{
    float3 itmColor;

    for (uint channel = 0; channel < 3; channel++)
    {
        // scaleY and offsetY setup: https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L187-L197
        // toe
        if (InputColor[channel] < params_y0)
        {
            // scaleXY and offsetXY setup: https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L151-L154
            itmColor[channel] = HableEval_Inverse(InputColor[channel],
                                                  0.f,
                                                  0.f, // * invScale
                                                  1.f,
                                                  1.f * invScale,
                                                  toeSegment_lnA,
                                                  toeSegment_B);
        }
        // mid
        else if (InputColor[channel] < params_y1)
        {
            // scaleXY and offsetY setup: https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L125-L127
            itmColor[channel] = HableEval_Inverse(InputColor[channel],
                                                  -midSegment_offsetX, // minus was optimised away
                                                  0.f, // * invScale
                                                  1.f,
                                                  1.f * invScale,
                                                  midSegment_lnA,
                                                  1.f);
        }
        // shoulder
        else
        {
            // scaleXY setup: https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L175-L176
            itmColor[channel] = HableEval_Inverse(InputColor[channel],
                                                  shoulderSegment_offsetX,
                                                  shoulderSegment_offsetY * invScale,
                                                  -1.f,
                                                  -1.f * invScale,
                                                  shoulderSegment_lnA,
                                                  shoulderSegment_B);
        }
    }

    return itmColor * dstParams_W;
}

// Tonemapper inspired from DICE. Works on luminance to maintain hue, not per channel.
float3 DICETonemap(float3 Color, float MaxOutputLuminance)
{
    // Between 0 and 1. Determines where the highlights curve (shoulder) starts.
    // Leaving at zero for now as it's a simple and good looking default.
    const float highlightsShoulderStart = 0.f;

    const float sourceLuminance = Luminance(Color);
    if (sourceLuminance > 0.0f)
    {
        const float compressedLuminance = luminanceCompress(sourceLuminance, MaxOutputLuminance, highlightsShoulderStart);
        Color *= compressedLuminance / sourceLuminance;
    }
    return Color;
}

float FindLuminanceToRestore(float tonemapLostLuminance, float preColorCorrectionLuminance, float postColorCorrectionLuminance)
{
    // Try to restore any luminance above "color", as it would have been lost during tone mapping.
    //
    // To achieve this, we re-apply the lost luminance, but only by the inverse amount the luminance changed during the color correction.
    // e.g. if the color correction fully changed the luminance, then we don't change it any further,
    // but if the color correction changed the luminance only by 25%, then we re-apply apply 75% of the lost luminance on top.
    // This will be "accurate" as long as the color correction scaled the luminance linearly in the output as it grew in the input,
    // but even if it didn't, it should still look fine.

    // This will re-apply an amount of lost luminance based on how much the CC reduced it:
    // the more the CC reduced the luminance, the less we will apply.
    // If the CC increased the luminance though, we will apply even more than the base lost amount.
    tonemapLostLuminance = isnan(tonemapLostLuminance) ? 0.f : tonemapLostLuminance;
    const float luminanceCCInvChange = max(1.f - (preColorCorrectionLuminance - postColorCorrectionLuminance), 0.f);
    //const float luminanceCCInvChange = clamp(postColorCorrectionLuminance / preColorCorrectionLuminance, 0.f, 2.f); //TODO: try this
    const float currentLum = postColorCorrectionLuminance; // Should be equal to "Luminance(color)"
    const float targetLum = max(currentLum + tonemapLostLuminance, 0.f);
    float scale = luminanceCCInvChange;

    if (currentLum > 0.f)
    {
        scale *= targetLum / currentLum;
        return scale;
    }
    return 1.f;
}

float3 PostProcess(float3 Color, inout float ColorLuminance)
{
    const uint hdrCmpDatIndex = PcwHdrComposite.HdrCmpDatIndex;
    const float4 highlightsColorFilter = HdrCmpDat[hdrCmpDatIndex].HighlightsColorFilter;
    const float4 colorFilter = HdrCmpDat[hdrCmpDatIndex].ColorFilter;
    const float hableSaturation = HdrCmpDat[hdrCmpDatIndex].HableSaturation;
    const float brightnessMultiplier = HdrCmpDat[hdrCmpDatIndex].BrightnessMultiplier; // Neutral at 1
    const float contrastIntensity = HdrCmpDat[hdrCmpDatIndex].ContrastIntensity; // Neutral at 1
    const float contrastMidPoint = PerSceneConstants[316u].z;

    ColorLuminance = Luminance(Color);

    // saturation adjustment a la Hable
    // https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicColorGrading.cpp#L307-L309
    Color = ((Color - ColorLuminance) * hableSaturation) + ColorLuminance;
    // Blend in another color based on the luminance.
    Color += lerp(float3(0.f, 0.f, 0.f), ColorLuminance * highlightsColorFilter.rgb, highlightsColorFilter.a);
    Color *= brightnessMultiplier;


#if ENABLE_PP_CONTRAST_ADJUSTMENT

    // Contrast adjustment (shift the colors from 0<->1 to (e.g.) -0.5<->0.5 range, multiply and shift back).
    // The higher the distance from the contrast middle point, the more contrast will change the color.
    Color = ((Color - contrastMidPoint) * contrastIntensity) + contrastMidPoint;

#endif

    Color = lerp(Color, colorFilter.rgb, colorFilter.a);
    return Color;
}

float3 PostProcess_Inverse(float3 Color, float ColorLuminance)
{
    const uint hdrCmpDatIndex = PcwHdrComposite.HdrCmpDatIndex;
    const float4 highlightsColorFilter = HdrCmpDat[hdrCmpDatIndex].HighlightsColorFilter;
    const float4 colorFilter = HdrCmpDat[hdrCmpDatIndex].ColorFilter;
    const float hableSaturation = HdrCmpDat[hdrCmpDatIndex].HableSaturation;
    const float brightnessMultiplier = HdrCmpDat[hdrCmpDatIndex].BrightnessMultiplier; // Neutral at 1
    const float contrastIntensity = HdrCmpDat[hdrCmpDatIndex].ContrastIntensity; // Neutral at 1
    const float contrastMidPoint = PerSceneConstants[316u].z;

    // We can't invert the color filter, so we will only inverse the post process by the unfiltered amount
    const float colorFilterInverse = 1.f - colorFilter.a;

    Color = ((Color - contrastMidPoint) / contrastIntensity) + contrastMidPoint;

    Color /= brightnessMultiplier;

    Color -= lerp(float3(0.f, 0.f, 0.f), ColorLuminance * highlightsColorFilter.rgb, highlightsColorFilter.a);

    Color = ((Color - ColorLuminance) / hableSaturation) + ColorLuminance;

    return Color;
}


float3 TetrahedralInterpolation(
    Texture3D<float3> Lut,
    float3            Color)
{
    float3 coords = Color.rgb * (LUT_SIZE - 1);

    // baseInd is on [0,LUT_SIZE-1]
    int3 baseInd = coords;
    int3 nextInd = baseInd + 1;

    // fract is on [0,1]
    float3 fract = frac(coords);

    float3 f1, f4;

    float3 v1 = Lut.Load(int4(baseInd, 0)).rgb;
    float3 v4 = Lut.Load(int4(nextInd, 0)).rgb;

    if (fract.r >= fract.g)
    {
        if (fract.g >= fract.b)  // R > G > B
        {
            nextInd = baseInd + int3(1, 0, 0);
            float3 v2 = Lut.Load(int4(nextInd, 0)).rgb;

            nextInd = baseInd + int3(1, 1, 0);
            float3 v3 = Lut.Load(int4(nextInd, 0)).rgb;

            f1 = 1.f - fract.r;
            f4 = fract.b;
            float3 f2 = fract.r - fract.g;
            float3 f3 = fract.g - fract.b;

            Color = (f2 * v2) + (f3 * v3);
        }
        else if (fract.r >= fract.b)  // R > B > G
        {
            nextInd = baseInd + int3(1, 0, 0);
            float3 v2 = Lut.Load(int4(nextInd, 0)).rgb;

            nextInd = baseInd + int3(1, 0, 1);
            float3 v3 = Lut.Load(int4(nextInd, 0)).rgb;

            f1 = 1.f - fract.r;
            f4 = fract.g;
            float3 f2 = fract.r - fract.b;
            float3 f3 = fract.b - fract.g;

            Color.rgb = (f2 * v2) + (f3 * v3);
        }
        else  // B > R > G
        {
            nextInd = baseInd + int3(0, 0, 1);
            float3 v2 = Lut.Load(int4(nextInd, 0)).rgb;

            nextInd = baseInd + int3(1, 0, 1);
            float3 v3 = Lut.Load(int4(nextInd, 0)).rgb;

            f1 = 1.f - fract.b;
            f4 = fract.g;
            float3 f2 = fract.b - fract.r;
            float3 f3 = fract.r - fract.g;

            Color = (f2 * v2) + (f3 * v3);
        }
    }
    else
    {
         if (fract.g <= fract.b)  // B > G > R
        {
            nextInd = baseInd + int3(0, 0, 1);
            float3 v2 = Lut.Load(int4(nextInd, 0)).rgb;

            nextInd = baseInd + int3(0, 1, 1);
            float3 v3 = Lut.Load(int4(nextInd, 0)).rgb;

            f1 = 1.f - fract.b;
            f4 = fract.r;
            float3 f2 = fract.b - fract.g;
            float3 f3 = fract.g - fract.r;

            Color = (f2 * v2) + (f3 * v3);
        }
        else if (fract.r >= fract.b)  // G > R > B
        {
            nextInd = baseInd + int3(0, 1, 0);
            float3 v2 = Lut.Load(int4(nextInd, 0)).rgb;

            nextInd = baseInd + int3(1, 1, 0);
            float3 v3 = Lut.Load(int4(nextInd, 0)).rgb;

            f1 = 1.f - fract.g;
            f4 = fract.b;
            float3 f2 = fract.g - fract.r;
            float3 f3 = fract.r - fract.b;

            Color = (f2 * v2) + (f3 * v3);
        }
        else  // G > B > R
        {
            nextInd = baseInd + int3(0, 1, 0);
            float3 v2 = Lut.Load(int4(nextInd, 0)).rgb;

            nextInd = baseInd + int3(0, 1, 1);
            float3 v3 = Lut.Load(int4(nextInd, 0)).rgb;

            f1 = 1.f - fract.g;
            f4 = fract.r;
            float3 f2 = fract.g - fract.b;
            float3 f3 = fract.b - fract.r;

            Color = (f2 * v2) + (f3 * v3);
        }
    }

    return Color + (f1 * v1) + (f4 * v4);
}


PSOutput PS(PSInput psInput)
{
    float3 inputColor = InputColor.Load(int3(int2(psInput.SV_Position.xy), 0));

#if CLAMP_INPUT_OUTPUT

    // Remove any negative value caused by using R16G16B16A16F buffers (originally this was R11G11B10F, which has no negative values).
    // Doing gamut mapping, or keeping the colors outside of BT.709 doesn't seem to be right, as they seem to be just be accidentally coming out of some shader math.
    inputColor = max(inputColor, 0.f);

#endif

#if defined(APPLY_BLOOM)

    float3 bloom = Bloom.Sample(Sampler0, psInput.TEXCOORD);
    float bloomMultiplier = PcwHdrComposite.BloomMultiplier;
    inputColor = (bloomMultiplier * bloom) + inputColor;

#endif // APPLY_BLOOM

    float3 tonemappedColor;
    float3 tonemappedUnclampedColor;

#if !ENABLE_TONEMAP

    tonemappedColor = inputColor;
    tonemappedUnclampedColor = inputColor;

#else

    float acesParam_modE;
    float acesParam_modA;

    float hable_params_y0;
    float hable_params_y1;
    float hable_dstParams_W;
    float hable_toeSegment_lnA;
    float hable_toeSegment_B;
    float hable_midSegment_offsetX;
    float hable_midSegment_lnA;
    float hable_shoulderSegment_offsetX;
    float hable_shoulderSegment_offsetY;
    float hable_shoulderSegment_lnA;
    float hable_shoulderSegment_B;
    float hable_invScale;

    const bool clampACES = false;

    switch (PcwHdrComposite.Tmo)
    {
        case 1:
        {
            tonemappedUnclampedColor = ACESReference(inputColor, clampACES);
            tonemappedColor = saturate(tonemappedUnclampedColor);
        } break;

        case 2:
        {
            tonemappedUnclampedColor = ACESParametric(inputColor, clampACES, acesParam_modE, acesParam_modA);
            tonemappedColor = saturate(tonemappedUnclampedColor);
        } break;

        case 3:
        {
            tonemappedUnclampedColor = Hable(inputColor,
                                             hable_params_y0,
                                             hable_params_y1,
                                             hable_dstParams_W,
                                             hable_toeSegment_lnA,
                                             hable_toeSegment_B,
                                             hable_midSegment_offsetX,
                                             hable_midSegment_lnA,
                                             hable_shoulderSegment_offsetX,
                                             hable_shoulderSegment_offsetY,
                                             hable_shoulderSegment_lnA,
                                             hable_shoulderSegment_B,
                                             hable_invScale);
            tonemappedColor = tonemappedUnclampedColor; // Hable was never clamped
        } break;

        default:
        {
            tonemappedUnclampedColor = inputColor;
            tonemappedColor = saturate(tonemappedUnclampedColor);
        } break;
    }

#if ENABLE_POST_PROCESS

    float prePostProcessColorLuminance;
    float prePostProcessUnclampedColorLuminance;
    tonemappedColor = PostProcess(tonemappedColor, prePostProcessColorLuminance);
    // Repeat on unclamped tonemapped color to later retrieve the lost luminance
    tonemappedUnclampedColor = PostProcess(tonemappedUnclampedColor, prePostProcessUnclampedColorLuminance);

#endif //ENABLE_POST_PROCESS

#endif // ENABLE_TONEMAP

    tonemappedColor = saturate(tonemappedColor);

    // This is the luminance lost by clamping SDR tonemappers to the 0-1 range, and again by the fact that LUTs only take 0-1 range input.
    const float tonemapLostLuminance = Luminance(tonemappedUnclampedColor - tonemappedColor); //TODO: clip any negative values here? The unclamped tonemapper might actually have negative "lost" luminance.

    const float preColorCorrectionLuminance = Luminance(tonemappedColor);

    float3 color = tonemappedColor;

    float3 lutColor = color;

#if defined(APPLY_MERGED_COLOR_GRADING_LUT) && ENABLE_TONEMAP && ENABLE_LUT

#if FIX_WRONG_SRGB_GAMMA

    lutColor = gamma_linear_to_sRGB(lutColor);

#elif LUT_FIX_GAMMA_MAPPING

    //read gamma ini value, defaulting at 2.4 (makes little sense)
    float inverseGamma = 1.f / (max(SharedFrameData.Gamma, 0.001f));
    //weird linear -> sRGB conversion that clips values just above 0, and raises blacks.
    lutColor = (pow(lutColor, inverseGamma) * 1.055f) - 0.055f;
    lutColor = max(lutColor, 0.f); // Unnecessary as the LUT sampling is already clamped.

#endif // FIX_WRONG_SRGB_GAMMA

#if LUT_USE_TETRAHEDRAL_INTERPOLATION

    lutColor = TetrahedralInterpolation(Lut, lutColor);

#else

    lutColor = Lut.Sample(Sampler0, lutColor * (1.f - (1.f / LUT_SIZE)) + ((1.f / LUT_SIZE) / 2.f));

#endif //LUT_USE_TETRAHEDRAL_INTERPOLATION

#if !LUT_FIX_GAMMA_MAPPING

    lutColor = gamma_sRGB_to_linear(lutColor);

#endif // !LUT_FIX_GAMMA_MAPPING

#if LUT_CUSTOM_STRENGTH

    float LutMaskAlpha = saturate(LutMask.Sample(Sampler0, psInput.TEXCOORD).x + (1.f - LUTStrength));

#else

    float LutMaskAlpha = LutMask.Sample(Sampler0, psInput.TEXCOORD).x;

#endif // LUT_CUSTOM_STRENGTH

    color = lerp(lutColor, color, LutMaskAlpha);

#endif // APPLY_MERGED_COLOR_GRADING_LUT

    const float postColorCorrectionLuminance = Luminance(color);

#if ENABLE_HDR

    // Restore any luminance beyond 1 that ended up clipped by HDR->SDR tonemappers and any subsequent image manipulation
    color *= FindLuminanceToRestore(tonemapLostLuminance, preColorCorrectionLuminance, postColorCorrectionLuminance);

#if ENABLE_TONEMAP && ENABLE_REPLACED_TONEMAP

#if ENABLE_POST_PROCESS && ENABLE_INVERSE_POST_PROCESS

    //TODO: passing in the previous luminance might not be the best, though is there any other way really?
    //Should we at least shift it by how much the LUT shifted the luminance? To invert it more correctly.
    color = PostProcess_Inverse(color, prePostProcessColorLuminance);

#endif // ENABLE_POST_PROCESS && ENABLE_INVERSE_POST_PROCESS

    // Restore a color very close to the original linear one, but with all the other post process and LUT transformations baked in
    switch(PcwHdrComposite.Tmo)
    {
        case 1:
        {
            color = ACESReference_Inverse(color);
        } break;

        case 2:
        {
            color = ACESParametric_Inverse(color, acesParam_modE, acesParam_modA);
        } break;

        case 3:
        {
            color = Hable_Inverse(color,
                                  hable_params_y0,
                                  hable_params_y1,
                                  hable_dstParams_W,
                                  hable_toeSegment_lnA,
                                  hable_toeSegment_B,
                                  hable_midSegment_offsetX,
                                  hable_midSegment_lnA,
                                  hable_shoulderSegment_offsetX,
                                  hable_shoulderSegment_offsetY,
                                  hable_shoulderSegment_lnA,
                                  hable_shoulderSegment_B,
                                  hable_invScale);
        } break;

        default:
            break;
            // Any luminance lost by this tonemap case would have already been restored above with "tonemapLostLuminance".
    }

#if ENABLE_POST_PROCESS && ENABLE_INVERSE_POST_PROCESS

    //TODO: ... this has no use now, and also, it won't work in the HDR range
    color = PostProcess(color, prePostProcessColorLuminance);

#endif // ENABLE_POST_PROCESS && ENABLE_INVERSE_POST_PROCESS

    color *= HDR_GAME_PAPER_WHITE;

    //const float maxOutputLuminance = HDR_MAX_OUTPUT_NITS / WhiteNits_BT709;
    //TODO: find a tonemapper that looks more like Hable?
    //color = DICETonemap(color, maxOutputLuminance);

#else

    color *= HDR_GAME_PAPER_WHITE;

#endif // ENABLE_TONEMAP && ENABLE_REPLACED_TONEMAP

#if CLAMP_INPUT_OUTPUT

    color = clamp(color, 0.f, FLT16_MAX); // Avoid extremely high numbers turning into NaN in FP16

#endif

#else

#if SDR_USE_GAMMA_2_2 //TODO: This makes sense to have if we fix up the LUTs, though the SDR tonemapper had still been developed with sRGB<->2.2 mismatch

    color = pow(color, 1.f / 2.2f);

#else

    // Do sRGB gamma even if we'd be playing on gamma 2.2 screens, as the game was already calibrated for 2.2 gamma
    color = gamma_linear_to_sRGB(color);

#if CLAMP_INPUT_OUTPUT

    color = saturate(color);

#endif // CLAMP_INPUT_OUTPUT

#endif // SDR_USE_GAMMA_2_2

#endif // ENABLE_HDR

    PSOutput psOutput;
    psOutput.SV_Target.rgb = color;
    psOutput.SV_Target.a = 1.f;

    return psOutput;
}
