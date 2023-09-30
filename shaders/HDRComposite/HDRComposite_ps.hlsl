#include "../shared.hlsl"
#include "../color.hlsl"
#include "../math.hlsl"

// These are defined at compile time (shaders permutations)
//#define APPLY_BLOOM
//#define APPLY_TONEMAPPING
//#define APPLY_CINEMATICS
//#define APPLY_MERGED_COLOR_GRADING_LUT

// This makes sense to use given we fix up (normalize) the LUTs colors and their gamma mapping, though the SDR tonemapper had still been developed with sRGB<->2.2 mismatch.
#define SDR_USE_GAMMA_2_2 1
// Suggested if "LUT_FIX_GAMMA_MAPPING" is true
#define FIX_WRONG_SRGB_GAMMA_FORMULA 1

// This disables most other features (post process, LUTs, ...)
#define ENABLE_TONEMAP 1
// Tweak the OG tonemappers to either look better in general, or simply be more compatible with HDR
#define ENABLE_TONEMAP_IMPROVEMENTS 1
#define ENABLE_POST_PROCESS 1
// 0 original (weak, generates values beyond 0-1 which then get clipped), 1 improved (looks more natural, avoids values below 0, but will overshoot beyond 1 more often, and will raise blacks), 2 Sigmoidal (smoothest looking, but harder to match)
#define POST_PROCESS_CONTRAST_TYPE 1
#define ENABLE_LUT 1
// LUTs are too low resolutions to resolve gradients smoothly if the LUT color suddenly changes between samples
#define ENABLE_LUT_TETRAHEDRAL_INTERPOLATION 1
// Applies LUTs after inverse tonemap, so we have HDR values in them (inv tonemappers only take 0-1 range)
#define ENABLE_APPLY_LUT_AFTER_INVERSE_TONEMAP 1
#define ENABLE_REPLACED_TONEMAP 1
// Invert tonemap by luminance (conserves SDR hue (and damped saturation look))
#define INVERT_TONEMAP_BY_LUMINANCE 0
// Only invert highlights, which helps conserve the SDR filmic look (shadow crush)
#define INVERT_TONEMAP_HIGHLIGHTS_ONLY 1
// Use AutoHDR as "inverse tonemapper" (maintains a look closer to the original)
#define ENABLE_AUTOHDR 0
#define ENABLE_INVERSE_POST_PROCESS 0
#define ENABLE_LUMINANCE_RESTORE 1
#define CLAMP_INPUT_OUTPUT 1


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
// 0 Ignored, 1 ACES Reference, 2 ACES Custom, 3 Hable, 4+ Disable tonemapper
static const uint ForceTonemapper = 0;

static const float ACES_a = 2.51f;
static const float ACES_b = 0.03f;
static const float ACES_c = 2.43f;
static const float ACES_d = 0.59f;
static const float ACES_e = 0.14f;


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
    const float AcesParam0 = PerSceneConstants[3266u].x; // Constant is usually 11.2
    const float AcesParam1 = PerSceneConstants[3266u].y; // Constant is usually 0.022
    modE = AcesParam1;
    modA = ((0.56f / AcesParam0) + ACES_b) + (AcesParam1 / (AcesParam0 * AcesParam0));
    return ACES(Color, Clamp, modE, modA);
}

template<class T>
T ACES_Inverse(T Color, float modE, float modA)
{
    //TODO: does this apply for `ACESParametric` as well? Probably
    //TODO: figure out if we could still use the unclamped color. There should be a way to invert it.
    // ACES is not defined for any values beyond 0-1
    Color = saturate(Color);

    T fixed0 = (-ACES_d * Color) + ACES_b;
    T fixed1 = (ACES_c * Color) - modA;

    T variable_numerator_part0 = -fixed0;
    T variable_numerator = sqrt((variable_numerator_part0 * variable_numerator_part0) - (4.f * modE * Color * fixed1));

    T denominator = 2.f * fixed1;

    T result0 = (fixed0 + variable_numerator) / denominator;
    T result1 = (fixed0 - variable_numerator) / denominator;

    // "result1" is likely what we always want
    return max(result0, result1);
}

template<class T>
T ACESReference_Inverse(T Color)
{
    return ACES_Inverse(Color, ACES_e, ACES_a);
}

template<class T>
T ACESParametric_Inverse(T Color, float modE, float modA)
{
    return ACES_Inverse(Color, modE, modA);
}

// https://github.com/johnhable/fw-public
// http://filmicworlds.com/blog/filmic-tonemapping-with-piecewise-power-curves/
// This is NOT the Uncharted 2 tonemapper, which was also by Hable.
float3 Hable(
  in  float3         InputColor,
  out HableParamters hableParams)
{
    // https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L202

    // the 2.2 is so you don't have to input very small numbers
    const float toeLength        = pow(saturate(PerSceneConstants[3266u].w), 2.2f); // Constant is usually 0.3
    const float toeStrength      = saturate(PerSceneConstants[3266u].z); // Constant is usually 0.5
    const float shoulderLength   = clamp(saturate(PerSceneConstants[3267u].y), EPSILON, BTHCNST); // Constant is usually 0.8
    const float shoulderStrength = max(PerSceneConstants[3267u].x, 0.f); // Constant is usually 9.9
    const float shoulderAngle    = saturate(PerSceneConstants[3267u].z); // Constant is usually 0.3

#if ENABLE_TONEMAP_IMPROVEMENTS
    //TODO: fix highlights
#endif

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
    hableParams.dstParams.W = initialW + extraW;

    // "W * " was optimised away by DXIL->SPIRV->HLSL conversion as down the line there is a "/ W"
    float dstParams_overshootX = 2.f * shoulderAngle * shoulderStrength;
    float dstParams_overshootY = 0.5f * shoulderAngle * shoulderStrength;

    // https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L87

    //dstCurve
    float dstCurve_invW = 1.f / hableParams.dstParams.W;

    //params
    float params_x0 = dstParams_x0 / hableParams.dstParams.W;
    float params_x1 = dstParams_x1 / hableParams.dstParams.W;
    //float params_overshootX = dstParams_overshootX / hableParams.dstParams.W; // this step was optimised away
    const float params_overshootX = dstParams_overshootX;
    float dx = y1_offset / hableParams.dstParams.W;

    // mid section
    // AsSlopeIntercept https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L67
    float m = (abs(dx) < EPSILON) ? 1.f : (y1_offset / dx);
    m += EPSILON;
    float b = dstParams_y0 - (m * params_x0);

    hableParams.midSegment.offsetX = (b / m); //no minus
    float midSegment_lnA_optimised = log2(m);
    hableParams.midSegment.lnA = RCP_LOG2_E * midSegment_lnA_optimised;
    // mid section end

    // toeM and shoulderM are missing because EvalDerivativeLinearGamma (https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L81-L85)
    // evaluates to gamma * m * pow(m * x + b, gamma - 1) with gamma being 1
    // this just returns m
    const float toeM = m;
    const float shoulderM = m;

    // https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L137-L138
    // max(EPSILON, pow(params_yX, gamma))
    hableParams.params.y0 = max(EPSILON, dstParams_y0); // is pow(x, gamma) with gamma = 1
    //OLD: hableParams.params.y0 = max(EPSILON, exp2(log2(dstParams_y0)));
    hableParams.params.y1 = max(EPSILON, dstParams_y1); // is pow(x, gamma) with gamma = 1
    //OLD: hableParams.params.y1 = max(EPSILON, exp2(log2(dstParams_y1)));

    // pow(1.f + dstParams_overshootY, gamma) - 1.f
    // -1 was optimised away as hableParams.shoulderSegment.offsetY is "params_overshootY + 1"
    float params_overshootY = 1.f + dstParams_overshootY; // is pow(x, gamma) with gamma = 1
    //OLD: float params_overshootY = exp2(log2(1.f + dstParams_overshootY));

    // toe section
    // SolveAB https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L60
    hableParams.toeSegment.B = (toeM * params_x0) / (hableParams.params.y0 + EPSILON);
    float _410 = log2(hableParams.params.y0); //doesn't belong to SolveAB (it might does)
    float toeSegment_lnA_optimised = -hableParams.toeSegment.B * log(params_x0);
    hableParams.toeSegment.lnA = _410 * RCP_LOG2_E + toeSegment_lnA_optimised;
    // toe section end

    // shoulder section
    float shoulderSection_x0 = 1.f + params_overshootX - params_x1;
    float shoulderSection_y0 = params_overshootY - hableParams.params.y1; // 1 + x was optimised away
    hableParams.shoulderSegment.offsetX = 1.f + params_overshootX;
    hableParams.shoulderSegment.offsetY = params_overshootY; // x + 1 was optimised away
    // SolveAB
    hableParams.shoulderSegment.B = ((shoulderM * shoulderSection_x0) / (shoulderSection_y0 + EPSILON));
    float shoulderSegment_B_optimised = hableParams.shoulderSegment.B * RCP_LOG2_E;
    hableParams.shoulderSegment.lnA = (log2(shoulderSection_y0) * RCP_LOG2_E) - (shoulderSegment_B_optimised * log2(shoulderSection_x0));
    // shoulder section end

    // https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L6
    // Eval
    float evalY0 = 0.f;
    if (params_overshootX > 0.f)
    {
        evalY0 = -exp2(((shoulderSegment_B_optimised * log2(params_overshootX)) + hableParams.shoulderSegment.lnA) * LOG2_E) + params_overshootY;
    }
    // Eval end
    hableParams.invScale = 1.f / evalY0;

    float3 toneMapped;

    for (uint channel = 0; channel < 3; channel++)
    {
        float normX = InputColor[channel] * dstCurve_invW;
        bool isToeSegment = normX < params_x0;
        float returnChannel = 0.f;

        if (isToeSegment && normX > 0.f)
        {
            returnChannel = exp2(((((log2(normX) * hableParams.toeSegment.B) + _410) * RCP_LOG2_E) + toeSegment_lnA_optimised) * LOG2_E);
        }
        else if (normX < params_x1)
        {
            float evalMidSegment_y0 = normX + hableParams.midSegment.offsetX; // was -(-hableParams.midSegment.offsetX)
            if (evalMidSegment_y0 > 0.f)
            {
                returnChannel = exp2(log2(evalMidSegment_y0) + midSegment_lnA_optimised);
            }
        }
        else
        {
            //float evalShoulderSegment_y0 = ((-1.f) - params_overshootX) + normX; // small optimisation from the original decompilation
            float evalShoulderSegment_y0 = (1.f + params_overshootX) - normX;
            float evalShoulderReturn = 0.f;
            if (evalShoulderSegment_y0 > 0.f)
            {
                evalShoulderReturn = exp2(((shoulderSegment_B_optimised * log2(evalShoulderSegment_y0)) + hableParams.shoulderSegment.lnA) * LOG2_E);
            }
            returnChannel = params_overshootY - evalShoulderReturn;
        }
        toneMapped[channel] = returnChannel * hableParams.invScale;
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
#if 0 //TODO: delete. This version might work better on Nvidia (to be investigated more before deleting the alternative branch)
    float y0 = max((Channel - offsetY) / scaleY, EPSILON);
    float x0 = exp((log(y0) - lnA) / B);

    return x0 / scaleX + offsetX;
#else
    float y0 = (Channel - offsetY) / scaleY;
    float x0 = 0.f;

    if (y0 > 0.f) // log(0) is invalid
    {
        x0 = exp((log(y0) - lnA) / B);
    }

    return x0 / scaleX + offsetX;
#endif
}

void Hable_Inverse_Channel(
  inout float          ColorChannel,
  in    HableParamters hableParams,
  in    bool           onlyInvertHighlights = false)
{
    // Scale all non highlights by the scale the smallest (first) highlight would have, so we keep the curves connected
    const float minHighlightsColor = max(hableParams.params.y0, hableParams.params.y1); // Check both toe and mid params for extra safety
    if (onlyInvertHighlights && ColorChannel < minHighlightsColor)
    {
        ColorChannel *= HableEval_Inverse(minHighlightsColor,
                                          hableParams.shoulderSegment.offsetX,
                                          hableParams.shoulderSegment.offsetY * hableParams.invScale,
                                          -1.f,
                                          -1.f * hableParams.invScale,
                                          hableParams.shoulderSegment.lnA,
                                          hableParams.shoulderSegment.B) / minHighlightsColor;
        return;
    }

    // scaleY and offsetY setup: https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L187-L197
    // toe
    if (ColorChannel < hableParams.params.y0)
    {
        // scaleXY and offsetXY setup: https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L151-L154
        ColorChannel = HableEval_Inverse(ColorChannel,
                                         0.f,
                                         0.f, // * hableParams.invScale
                                         1.f,
                                         1.f * hableParams.invScale,
                                         hableParams.toeSegment.lnA,
                                         hableParams.toeSegment.B);
    }
    // mid (linear segment)
    else if (ColorChannel < hableParams.params.y1)
    {
        // scaleXY and offsetY setup: https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L125-L127
        ColorChannel = HableEval_Inverse(ColorChannel,
                                         -hableParams.midSegment.offsetX, // minus was optimised away
                                         0.f, // * hableParams.invScale
                                         1.f,
                                         1.f * hableParams.invScale,
                                         hableParams.midSegment.lnA,
                                         1.f);
    }
    // shoulder
    else
    {
#if ENABLE_TONEMAP_IMPROVEMENTS //TODO: remove... temp workaround for broken shoulder
        ColorChannel = min(ColorChannel, 0.99999f);
#endif

        // scaleXY setup: https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L175-L176
        ColorChannel = HableEval_Inverse(ColorChannel,
                                         hableParams.shoulderSegment.offsetX,
                                         hableParams.shoulderSegment.offsetY * hableParams.invScale,
                                         -1.f,
                                         -1.f * hableParams.invScale,
                                         hableParams.shoulderSegment.lnA,
                                         hableParams.shoulderSegment.B);
    }
}

// https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L45-L52
template<class T>
T Hable_Inverse(
  T              InputColor,
  uint           Channels /*1 to 3*/, //there has to be better solution than this
  HableParamters hableParams,
  bool           onlyInvertHighlights = false)
{
    // There's no inverse formula for colors beyond the 0-1 range
    InputColor = saturate(InputColor);

    float3 itmColor = InputColor; // Make this float3 to make it compile for all cases

    if (Channels <= 1) // InputColor[channel] won't compile if T is float(1)
    {
        Hable_Inverse_Channel(itmColor.x,
                              hableParams,
                              onlyInvertHighlights);
    }
    else
    {
        for (uint channel = 0; channel < Channels; channel++)
        {
            Hable_Inverse_Channel(itmColor[channel],
                                  hableParams,
                                  onlyInvertHighlights);
        }
    }

    return (T)itmColor * hableParams.dstParams.W;
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

// AutoHDR pass to generate some HDR brightess out of an SDR signal (it has no effect if HDR is not engaged).
// This is hue conserving and only really affects highlights.
// https://github.com/Filoppi/PumboAutoHDR
float3 PumboAutoHDR(float3 Color, float MaxOutputNits, float PaperWhite)
{
    static const float AutoHDRShoulderPow = 3.5f; //TODO: exposure to user?

    const float SDRRatio = Luminance(Color);
	// Limit AutoHDR brightness, it won't look good beyond a certain level.
	// The paper white multiplier is applied later so we account for that.
    const float AutoHDRMaxWhite = max(MaxOutputNits / PaperWhite, WhiteNits_BT709) / WhiteNits_BT709;
    const float AutoHDRShoulderRatio = 1.f - max(1.f - SDRRatio, 0.f);
    const float AutoHDRExtraRatio = pow(AutoHDRShoulderRatio, AutoHDRShoulderPow) * (AutoHDRMaxWhite - 1.f);
    const float AutoHDRTotalRatio = SDRRatio + AutoHDRExtraRatio;

    return Color * (AutoHDRTotalRatio / SDRRatio);
}

float FindLuminanceToRestoreScale(float3 color, float tonemapLostLuminance, float preColorCorrectionLuminance, float postColorCorrectionLuminance, float midGrayScale = 1.f)
{
    // Try to restore any luminance that would have been lost during tone mapping (e.g. tonemapping, post process, LUTs, ... can all clip values).
    //
    // To achieve this, we re-apply the lost luminance, but only by the inverse amount the luminance changed during the color correction.
    // e.g. if the color correction fully changed the luminance, then we don't change it any further,
    // but if the color correction changed the luminance only by 25%, then we re-apply apply 75% of the lost luminance on top.
    // This will be "accurate" as long as the color correction scaled the luminance linearly in the output as it grew in the input,
    // but even if it didn't, it should still look fine.

    // This will re-apply an amount of lost luminance based on how much the CC (LUT) reduced it:
    // the more the CC reduced the luminance, the less we will apply.
    // If the CC increased the luminance though, we will apply even more than the base lost amount.
    const float currentLum = Luminance(color);
    if (currentLum > 0.f)
    {
        // Change the "tonemapLostLuminance" from being in the tonemapped SDR (0-1) range to the untonemapped HDR image range (by scaling it by the mid gray change, which is the best we can do).
        // This will also acknowledge any clipped luminance from the range beyond 0-1.
        tonemapLostLuminance = isnan(tonemapLostLuminance) ? 0.f : (tonemapLostLuminance * midGrayScale);

#if defined(APPLY_MERGED_COLOR_GRADING_LUT) && ENABLE_LUT && !ENABLE_APPLY_LUT_AFTER_INVERSE_TONEMAP && LUT_IMPROVEMENT_TYPE == 3 // Restore any luminance lost by the LUT
        float scale = 1.f;
        scale *= postColorCorrectionLuminance > 0.f ? lerp(1.f, preColorCorrectionLuminance / postColorCorrectionLuminance, LUTCorrectionPercentage) : 1.f;
#else
        const float luminanceCCInvChange = max(1.f - (preColorCorrectionLuminance - postColorCorrectionLuminance), 0.f);
        //const float luminanceCCInvChange = clamp(postColorCorrectionLuminance / preColorCorrectionLuminance, 0.f, 2.f); //TODO: try this, especially if brightness goes crazy high
        float scale = luminanceCCInvChange;
#endif

        const float targetLum = max(currentLum + tonemapLostLuminance, 0.f); //TODO: review max() math
        scale *= targetLum / currentLum;
        return scale;
    }
    return 1.f;
}

// "MidGrayScale" is how much the mid gray shifted from the originally intended tonemapped input (e.g. if we run this function on the untonemapped image, we can remap the mid gray)
float3 PostProcess(float3 Color, inout float ColorLuminance, float MidGrayScale = 1.f)
{
    const uint   hdrCmpDatIndex        = PcwHdrComposite.HdrCmpDatIndex;
    const float4 highlightsColorFilter = HdrCmpDat[hdrCmpDatIndex].HighlightsColorFilter;
    const float4 colorFilter           = HdrCmpDat[hdrCmpDatIndex].ColorFilter;
    const float  hableSaturation       = HdrCmpDat[hdrCmpDatIndex].HableSaturation;
    const float  brightnessMultiplier  = HdrCmpDat[hdrCmpDatIndex].BrightnessMultiplier; // Neutral at 1
    const float  contrastIntensity     = HdrCmpDat[hdrCmpDatIndex].ContrastIntensity; // Neutral at 1
    const float  contrastMidPoint      = PerSceneConstants[316u].z * MidGrayScale; // Game usually has this around 0.18 (mid gray)

    ColorLuminance = Luminance(Color);

    // saturation adjustment a la Hable
    // https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicColorGrading.cpp#L307-L309
    Color = ((Color - ColorLuminance) * hableSaturation) + ColorLuminance;
    // Blend in another color based on the luminance.
    Color += lerp(float3(0.f, 0.f, 0.f), ColorLuminance * highlightsColorFilter.rgb, highlightsColorFilter.a);
    Color *= brightnessMultiplier;

#if POST_PROCESS_CONTRAST_TYPE == 0

    // Contrast adjustment (shift the colors from 0<->1 to (e.g.) -0.5<->0.5 range, multiply and shift back).
    // The higher the distance from the contrast middle point, the more contrast will change the color.
    Color = ((Color - contrastMidPoint) * contrastIntensity) + contrastMidPoint;

#elif POST_PROCESS_CONTRAST_TYPE == 1

    Color = pow(Color / contrastMidPoint, contrastIntensity) * contrastMidPoint;

#elif POST_PROCESS_CONTRAST_TYPE == 2

    // sigmoidal contrast adjustment doesn't clip colors
    // https://www.imagemagick.org/Usage/color_mods/#sigmoidal

    // Multiplier to somewhat match the original contrast adjustment
    static const float sigmoidalContrastAdjustment = 2.5f; //TODO: we could probably find an even better default multiplication
    float c = max(contrastIntensity * sigmoidalContrastAdjustment, EPSILON); // protect against division by zero
    float s = contrastMidPoint; // can be set to 0.5 for better darkening of shadows

    float minus = -1 / (1 + exp(c * s));

    // there should be some optimisation left here
    Color = (1 / (1 + exp(c * (s - Color))) + minus)
          / (1 / (1 + exp(c * (s - 1)))     + minus);

#endif

    Color = lerp(Color, colorFilter.rgb * MidGrayScale, colorFilter.a);
    return Color;
}

float3 PostProcess_Inverse(float3 Color, float ColorLuminance, float MidGrayScale = 1.f)
{
    const uint   hdrCmpDatIndex        = PcwHdrComposite.HdrCmpDatIndex;
    const float4 highlightsColorFilter = HdrCmpDat[hdrCmpDatIndex].HighlightsColorFilter;
    const float4 colorFilter           = HdrCmpDat[hdrCmpDatIndex].ColorFilter;
    const float  hableSaturation       = HdrCmpDat[hdrCmpDatIndex].HableSaturation;
    const float  brightnessMultiplier  = HdrCmpDat[hdrCmpDatIndex].BrightnessMultiplier; // Neutral at 1
    const float  contrastIntensity     = HdrCmpDat[hdrCmpDatIndex].ContrastIntensity; // Neutral at 1
    const float  contrastMidPoint      = PerSceneConstants[316u].z * MidGrayScale;

    // We can't invert the color filter, so we will only inverse the post process by the unfiltered amount
    const float colorFilterInverse = 1.f - colorFilter.a;

#if POST_PROCESS_CONTRAST_TYPE == 0
    Color = ((Color - contrastMidPoint) / contrastIntensity) + contrastMidPoint;
#elif POST_PROCESS_CONTRAST_TYPE == 1
    Color = pow(Color / contrastMidPoint, 1.f / contrastIntensity) * contrastMidPoint;
#elif POST_PROCESS_CONTRAST_TYPE == 2
    //TODO: implement
#endif

    Color /= brightnessMultiplier;

    Color -= lerp(float3(0.f, 0.f, 0.f), ColorLuminance * highlightsColorFilter.rgb, highlightsColorFilter.a);

    Color = ((Color - ColorLuminance) / hableSaturation) + ColorLuminance;

    return Color;
}

// Takes input coordinates. Returns output color in linear space (also works in sRGB but it's not ideal).
float3 TetrahedralInterpolation(
    Texture3D<float3> Lut,
    float3            LUTCoordinates)
{
    // We need to clip the input coordinates as LUT texure samples below are not clamped.
    float3 coords = saturate(LUTCoordinates.rgb) * (LUT_SIZE - 1); // Pixel coords
    float3 color = 0;

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

            color = (f2 * v2) + (f3 * v3);
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

            color = (f2 * v2) + (f3 * v3);
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

            color = (f2 * v2) + (f3 * v3);
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

            color = (f2 * v2) + (f3 * v3);
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

            color = (f2 * v2) + (f3 * v3);
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

            color = (f2 * v2) + (f3 * v3);
        }
    }

    return color + (f1 * v1) + (f4 * v4);
}


PSOutput PS(PSInput psInput)
{
    float3 inputColor = InputColor.Load(int3(int2(psInput.SV_Position.xy), 0));

#if CLAMP_INPUT_OUTPUT

    // Remove any negative value caused by using R16G16B16A16F buffers (originally this was R11G11B10F, which has no negative values).
    // Doing gamut mapping, or keeping the colors outside of BT.709 doesn't seem to be right, as they seem to be just be accidentally coming out of some shader math.
    inputColor = max(inputColor, 0.f);

#endif // CLAMP_INPUT_OUTPUT

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

    HableParamters hableParams;

    const bool clampACES = false;

    int tonemapperIndex = ForceTonemapper > 0 ? ForceTonemapper : PcwHdrComposite.Tmo;

    switch (tonemapperIndex)
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
            tonemappedUnclampedColor = Hable(inputColor, hableParams);
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

    tonemappedColor = saturate(tonemappedColor);

#endif // ENABLE_TONEMAP

    // This is the luminance lost by clamping SDR tonemappers to the 0-1 range, and again by the fact that LUTs only take 0-1 range input.
    float tonemapLostLuminance = Luminance(tonemappedUnclampedColor - tonemappedColor);

    float3 color = tonemappedColor;

    const float preColorCorrectionLuminance = Luminance(color);

#if defined(APPLY_MERGED_COLOR_GRADING_LUT) && ENABLE_TONEMAP && ENABLE_LUT

#if FIX_WRONG_SRGB_GAMMA_FORMULA

    const float3 LUTCoordinates = gamma_linear_to_sRGB(color);

#else

    // Read gamma ini value, defaulting at 2.4 (makes little sense)
    float inverseGamma = 1.f / (max(SharedFrameData.Gamma, 0.001f));
    // Weird linear -> sRGB conversion that clips values just above 0, and raises blacks.
    const float3 LUTCoordinates = max((pow(color, inverseGamma) * 1.055f) - 0.055f, 0.f); // Does "max()" is unnecessary as LUT sampling is already clamped.

#endif // FIX_WRONG_SRGB_GAMMA_FORMULA

#if ENABLE_LUT_TETRAHEDRAL_INTERPOLATION

    float3 LUTColor = TetrahedralInterpolation(Lut, LUTCoordinates);

#else

    float3 LUTColor = Lut.Sample(Sampler0, LUTCoordinates * (1.f - (1.f / LUT_SIZE)) + ((1.f / LUT_SIZE) / 2.f));

#endif // ENABLE_LUT_TETRAHEDRAL_INTERPOLATION

#if !LUT_FIX_GAMMA_MAPPING

    // We always work in linear space so convert to it.
    // We never acknowledge the original wrong gamma function here (we don't really care).
    LUTColor = gamma_sRGB_to_linear(LUTColor);

#endif // !LUT_FIX_GAMMA_MAPPING

    const float LUTMaskAlpha = saturate(LutMask.Sample(Sampler0, psInput.TEXCOORD).x + (1.f - LUTStrength));

    LUTColor = lerp(LUTColor, color, LUTMaskAlpha);

#if ENABLE_APPLY_LUT_AFTER_INVERSE_TONEMAP && ENABLE_TONEMAP && ENABLE_REPLACED_TONEMAP
    float3 LUTColorShift = LUTColor / color;
    for (uint channel = 0; channel < 3; channel++)
    {
        if (color[channel] == 0.f)
            LUTColorShift[channel] = 1.f;
    }
#else
    color = LUTColor;
#endif

#endif // APPLY_MERGED_COLOR_GRADING_LUT

#if ENABLE_HDR

#if ENABLE_TONEMAP && ENABLE_REPLACED_TONEMAP

    float postColorCorrectionLuminance = Luminance(color);
    //TODO: this isn't hue conserving, though we don't really have a way of doing it in a hue conserving way, as then it would break the brightness mapping.
    const float postColorCorrectionClampedLuminance = Luminance(saturate(color));
    // Some inverse tonemapper formulas can't take any values beyond 0-1, so we'll need to clip them and restore their luminance.
    const float colorCorrectionHDRClippedLuminanceChange = postColorCorrectionClampedLuminance > 0.f ? (postColorCorrectionLuminance / postColorCorrectionClampedLuminance) : 1.f;

#if ENABLE_POST_PROCESS && ENABLE_INVERSE_POST_PROCESS

    //TODO: passing in the previous luminance might not be the best, though is there any other way really?
    //Should we at least shift it by how much the LUT shifted the luminance? To invert it more correctly.
    color = PostProcess_Inverse(color, prePostProcessColorLuminance);

#endif // ENABLE_POST_PROCESS && ENABLE_INVERSE_POST_PROCESS

    const float paperWhite = HDR_GAME_PAPER_WHITE;

    const float midGrayIn = MidGray;
    float midGrayOut = midGrayIn;
#if ENABLE_AUTOHDR
    if (tonemapperIndex == 1 || tonemapperIndex == 2 || tonemapperIndex == 3)
    {
        tonemapperIndex = 0;
        color = PumboAutoHDR(color, HDR_MAX_OUTPUT_NITS, paperWhite);
        midGrayOut = PumboAutoHDR(midGrayIn.xxx, HDR_MAX_OUTPUT_NITS, paperWhite).x;
    }
#endif // ENABLE_AUTOHDR

#if INVERT_TONEMAP_BY_LUMINANCE
    float preInverseTonemapColorLuminance = Luminance(color);
    float inverseTonemapColor = preInverseTonemapColorLuminance;
    const uint inverseTonemapColorComponents = 1;
#else
    float3 inverseTonemapColor = color;
    const uint inverseTonemapColorComponents = 3;
#endif // INVERT_TONEMAP_BY_LUMINANCE

    // Restore a color very close to the original linear one, but with all the other post process and LUT transformations baked in
    switch (tonemapperIndex)
    {
        //TODO: implement INVERT_TONEMAP_HIGHLIGHTS_ONLY for ACES

        case 1:
        {
            inverseTonemapColor = ACESReference_Inverse(inverseTonemapColor);
            midGrayOut = ACESReference_Inverse(midGrayIn);
            tonemapLostLuminance *= colorCorrectionHDRClippedLuminanceChange;
            postColorCorrectionLuminance = postColorCorrectionClampedLuminance;
        } break;

        case 2:
        {
            inverseTonemapColor = ACESParametric_Inverse(inverseTonemapColor, acesParam_modE, acesParam_modA);
            midGrayOut = ACESParametric_Inverse(midGrayIn, acesParam_modE, acesParam_modA);
            tonemapLostLuminance *= colorCorrectionHDRClippedLuminanceChange;
            postColorCorrectionLuminance = postColorCorrectionClampedLuminance;
        } break;

        case 3:
        {
            const bool onlyInvertHighlights = (bool)INVERT_TONEMAP_HIGHLIGHTS_ONLY;
            inverseTonemapColor = Hable_Inverse(inverseTonemapColor,
                                                inverseTonemapColorComponents,
                                                hableParams,
                                                onlyInvertHighlights);
            midGrayOut = Hable_Inverse(midGrayIn,
                                       1,
                                       hableParams,
                                       onlyInvertHighlights);
            tonemapLostLuminance *= colorCorrectionHDRClippedLuminanceChange;
            postColorCorrectionLuminance = postColorCorrectionClampedLuminance;
        } break;

        default:
            // Any luminance lost by this tonemap case would have already been restored above with "tonemapLostLuminance".
            break;
    }

#if INVERT_TONEMAP_BY_LUMINANCE
    color *= preInverseTonemapColorLuminance > 0.f ? (inverseTonemapColor / preInverseTonemapColorLuminance) : 1.f;
#else
    color = inverseTonemapColor;
#endif

    const float midGrayScale = midGrayOut / midGrayIn;

#if ENABLE_POST_PROCESS && ENABLE_INVERSE_POST_PROCESS

    color = PostProcess(color, prePostProcessColorLuminance, midGrayScale);

#endif // ENABLE_POST_PROCESS && ENABLE_INVERSE_POST_PROCESS

#if ENABLE_LUMINANCE_RESTORE //TODO: this will go beyond the max output nits if "ENABLE_AUTOHDR" is true, we need to fix a way to make them work together (maybe re-tonemap always at the end?)
    // Restore any luminance beyond 1 that ended up clipped by HDR->SDR tonemappers and any subsequent image manipulation.
    // It's important to do these after the inverse tonemappers, as they can't handle values beyond 0-1.
    color *= FindLuminanceToRestoreScale(color, tonemapLostLuminance, preColorCorrectionLuminance, postColorCorrectionLuminance, midGrayScale);
#endif // ENABLE_LUMINANCE_RESTORE

#if defined(APPLY_MERGED_COLOR_GRADING_LUT) && ENABLE_LUT && ENABLE_APPLY_LUT_AFTER_INVERSE_TONEMAP
    const float3 preLUTShiftedColor = color;
    color *= LUTColorShift;
#if LUT_IMPROVEMENT_TYPE == 3
    const float postLUTShiftedColorLuminance = Luminance(color);
    color *= postLUTShiftedColorLuminance > 0.f ? lerp(1.f, Luminance(preLUTShiftedColor) / postLUTShiftedColorLuminance, LUTCorrectionPercentage) : 1.f;
#endif // LUT_IMPROVEMENT_TYPE == 3
#endif // ENABLE_APPLY_LUT_AFTER_INVERSE_TONEMAP

    // Bring back the color to the same range as SDR by dividing by the mid gray change.
    color *= paperWhite / midGrayScale;

#if !ENABLE_AUTOHDR

    //TODO: find a tonemapper that looks more like Hable?
    const float maxOutputLuminance = HDR_MAX_OUTPUT_NITS / WhiteNits_BT709;
    color = DICETonemap(color, maxOutputLuminance);

#endif // !ENABLE_AUTOHDR

#else // ENABLE_TONEMAP && ENABLE_REPLACED_TONEMAP

    color *= HDR_GAME_PAPER_WHITE;

#endif // ENABLE_TONEMAP && ENABLE_REPLACED_TONEMAP

#if CLAMP_INPUT_OUTPUT

    color = clamp(color, 0.f, FLT16_MAX); // Avoid extremely high numbers turning into NaN in FP16

#endif // CLAMP_INPUT_OUTPUT

#else // ENABLE_HDR

#if SDR_USE_GAMMA_2_2

    color = pow(color, 1.f / 2.2f);

#else

    // Do sRGB gamma even if we'd be playing on gamma 2.2 screens, as the game was already calibrated for 2.2 gamma despite using the wrong formula
    color = gamma_linear_to_sRGB(color);

#endif // SDR_USE_GAMMA_2_2

#if CLAMP_INPUT_OUTPUT

    color = saturate(color);

#endif // CLAMP_INPUT_OUTPUT

#endif // ENABLE_HDR

    PSOutput psOutput;
    psOutput.SV_Target.rgb = color;
    psOutput.SV_Target.a = 1.f;

    return psOutput;
}
