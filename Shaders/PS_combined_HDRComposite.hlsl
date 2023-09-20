// These are defined at compile time (shaders permutations)
//#define APPLY_BLOOM
//#define APPLY_TONEMAPPING
//#define APPLY_CINEMATICS
//#define APPLY_MERGED_COLOR_GRADING_LUT

// Also in "ps_4105314757"
#define ENABLE_HDR 1
#define HDR_GAME_PAPER_WHITE 2.5f
#define SDR_USE_GAMMA_2_2 0
#define FIX_WRONG_SRGB_GAMMA 1
// Also in "cs_580663709"
#define FIX_LUT_GAMMA_MAPPING 1
#define LUT_SIZE 16.f
#define DISABLE_TONEMAP 0
#define DISABLE_LUT 0

struct ResolutionBlock
{
    float2 f2_0;
    float2 f2_1;
    float2 f2_2;
    float2 f2_3;
    int4   i4_0;
    float2 f2_4;
    float2 f2_5;
    float2 f2_6;
    float2 f2_7;
    float2 f2_8;
    int2   i2_0;
    int4   i4_1;
    float  f_0;
    int    i_0;
    int    i_1;
    int    i_2;
};

struct CameraBlock
{
    float3   f3_0;
    int      i_1;
    float4x4 f4x4_0;
    float4x4 f4x4_1;
    float4x4 f4x4_2;
    float4x4 f4x4_3;
    float4x4 f4x4_4;
    float4x4 f4x4_5;
    float3   f3_1;
    int      i_0;
    float4x4 f4x4_6;
    float4x4 f4x4_7;
    float4x4 f4x4_8;
    float4   f4_0;
    float4   f4_1;
    float4   f4_2;
    float4   f4_3;
    float2   f2_0;
    float    f_0;
    float    f_1;
};

struct CameraBlockArray
{
    CameraBlock     cb0;
    CameraBlock     cb1;
    CameraBlock     cb2;
    ResolutionBlock rb0;
    ResolutionBlock rb1;
    ResolutionBlock rb2;
    ResolutionBlock rb3;
    ResolutionBlock rb4;
};

struct TonemappingParams
{
    float AcesParam0;
    float AcesParam1;
    float HableParam0;
    float HableParam1;
    float HableParam2;
    float HableParam3;
    float HableParam4;
    int   param7; //unused
};

struct SPerSceneConstants
{
    CameraBlockArray cba;
//    WindData;
//    CameraExposureData;
//    GlobalLightData;
//    GlobalShadowData;
//    ReflectionProbeDescData;
//    ReflectionProbeExposureData;
//    SIndirectLightingData;
//    ProbeRenderData;
//    PlanetConstantsData;
//    float pcs0;
//    int   pcs1;
//    int   pcs2;
//    float pcs3;
//    TiledBinning_idTech7FrameData;
//    float pcs4;
//    float pcs5;
//    float pcs6;
//    float pcs7;
//    float pcs8;
//    float pcs9;
//    float pcs10;
//    float pcs11;
//    float pcs12;
//    int   pcs13;
//    int   pcs14;
//    int   pcs15;
//    HairConstantData;
//    FogParams;
//    VolumetricLightingApplyParameters;
//    PrecomputeTransmittanceParameters;
//    HeightfieldData;
//    MomentBasedOITSettings;
//    TiledLightingDebug;
//    GPUDebugGeometrySettings;
//    TonemappingParams;
//    EffectsAlphaThresholdParams;
};

struct PushConstantWrapper_HDRComposite
{
    uint  HdrCmpDatIndex;
    uint  Tmo; //tone mapping operator
    float BloomMultiplier;
};

struct FrameDebug { int2 u1; int2 u2; int2 u3; int u4; int u5; float u6; int u7; int u8; int u9; int u10; int u11; int u12; int u13; };
struct FrameData { int u1; int u2; float2 u3; float u4; float u5; float u6; float Gamma; FrameDebug u8; float4 u9; float u10; float u11; int u12; int u13; };

struct HDRCompositeData
{
    float4 HighlightsColourFilter;
    float4 ColourFilter;
    float HableSaturation;
    float BrightnessMultiplier;
    float ContrastIntensity;
    int    i_0; //unused
};

cbuffer SharedFrameData : register(b0, space6)
{
	FrameData SharedFrameData;
}

cbuffer PerSceneConstants : register(b0, space7)
{
    float4 PerSceneConstants[3269] : packoffset(c0);
};

cbuffer PushConstantWrapper_HDRComposite : register(b0, space0)
{
    PushConstantWrapper_HDRComposite PcwHdrComposite : packoffset(c0);
};


Texture2D<float3> InputColour : register(t0, space9);

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

static float LUTStrenght = 0.f;
static float RestorePreLUTLuminance = 1.f;

float gamma_linear_to_sRGB(float channel)
{
    [flatten]
    if (channel <= 0.0031308f)
    {
        channel = channel * 12.92f;
    }
    else
    {
        channel = 1.055f * pow(channel, 1.0f / 2.4f) - 0.055f;
    }
    return channel;
}

float3 gamma_linear_to_sRGB(float3 Color)
{
    return float3(gamma_linear_to_sRGB(Color.r),
                  gamma_linear_to_sRGB(Color.g),
                  gamma_linear_to_sRGB(Color.b));
}

float gamma_sRGB_to_linear(float channel)
{
    [flatten]
    if (channel <= 0.04045f)
    {
        channel = channel / 12.92f;
    }
    else
    {
        channel = pow((channel + 0.055f) / 1.055f, 2.4f);
    }
    return channel;
}

float3 gamma_sRGB_to_linear(float3 Color)
{
    return float3(gamma_sRGB_to_linear(Color.r),
                  gamma_sRGB_to_linear(Color.g),
                  gamma_sRGB_to_linear(Color.b));
}

float Luminance(float3 Color)
{
    // Fixed from "wrong" values: 0.2125 0.7154 0.0721f
    return dot(Color, float3(0.2126f, 0.7152f, 0.0722f));
}

static const float ACES_a = 2.51f;
static const float ACES_b = 0.03f;
static const float ACES_c = 2.43f;
static const float ACES_d = 0.59f;
static const float ACES_e = 0.14f;

float3 ACES(float3 Colour, bool Clamp, float modE, float modA)
{
    Colour = (Colour * (modA * Colour + ACES_b)) / ((Colour * (ACES_c * Colour + ACES_d)) + modE);
    return Clamp ? saturate(Colour) : Colour;
}

// ACESFilm by Krzysztof Narkowicz (https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/)
// (color * ((a * color) + b)) / (color * ((c * color) + d) + e)
float3 ACESReference(float3 Colour, bool Clamp)
{
    return ACES(Colour, Clamp, ACES_e, ACES_a);
}

// ACESFilm "per scene"
float3 ACESParametric(in float3 Colour, in bool Clamp, inout float modE, inout float modA)
{
    const float AcesParam0 = PerSceneConstants[3266u].x;
    const float AcesParam1 = PerSceneConstants[3266u].y;
    modE = AcesParam1;
    modA = ((0.56f / AcesParam0) + ACES_b) + (AcesParam1 / (AcesParam0 * AcesParam0));
    return ACES(Colour, Clamp, modE, modA);
}

float3 ACES_Inverse(float3 Colour, float modE, float modA)
{
    float3 fixed0 = (-ACES_d * Colour) + ACES_b;
    float3 fixed1 = (ACES_c * Colour) - modA;

    float3 variable_numerator_part0 = -fixed0;
    float3 variable_numerator = sqrt((variable_numerator_part0 * variable_numerator_part0) - (4.f * modE * Colour * fixed1));

    float3 denominator = 2.f * fixed1;

    float3 result0 = (fixed0 + variable_numerator) / denominator;
    float3 result1 = (fixed0 - variable_numerator) / denominator;

    return max(result0, result1);
}

float3 ACESReference_Inverse(float3 Colour)
{
    return ACES_Inverse(Colour, ACES_e, ACES_a);
}

float3 ACESParametric_Inverse(float3 Colour, float modE, float modA)
{
    return ACES_Inverse(Colour, modE, modA);
}

// https://github.com/johnhable/fw-public
float3 Hable(
  in float3 InputColour,
  inout float params_y0,
  inout float params_y1,
  inout float dstParams_W,
  inout float toeSegment_lnA,
  inout float toeSegment_B,
  inout float midSegment_offsetX,
  inout float midSegment_lnA,
  inout float shoulderSegment_offsetX,
  inout float shoulderSegment_offsetY,
  inout float shoulderSegment_scaleX,
  inout float shoulderSegment_lnA,
  inout float shoulderSegment_B)
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

    float dstParams_overshootX = 2.f * shoulderAngle * shoulderStrength;  // "* W" was optimised away by DXIL->SPIRV->HLSL conversion
    float dstParams_overshootY = 0.5f * shoulderAngle * shoulderStrength; // as down the line there is a "/ W"

    // https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L87

    //dstCurve
    float dstCurve_invW = 1.f / dstParams_W;
    //params
    float params_x0 = dstParams_x0 / dstParams_W;
    float params_x1 = dstParams_x1 / dstParams_W;
    params_y0 = max(EPSILON, dstParams_y0);
    params_y1 = max(EPSILON, dstParams_y1);
    float dx = y1_offset / dstParams_W;

    // AsSlopeIntercept https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L67
    float m = (abs(dx) < EPSILON) ? 1.f : (y1_offset / dx);
    m += EPSILON;
    float b = dstParams_y0 - (m * params_x0);

    midSegment_offsetX = (b / m); //no minus
    midSegment_lnA = log2(m);

    // EvalDerivativeLinearGamma https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L81
    float toeM = exp2(log2(dstParams_y0)); // is pow(x, 1) because gamma = 1
    toeM = max(EPSILON, toeM);
    float shoulderM = exp2(log2(dstParams_y1)); // is pow(x, 1) because gamma = 1
    shoulderM = max(EPSILON, shoulderM);

    float params_overshootY = exp2(log2(1.f + dstParams_overshootY)); // is pow(x, 1) because gamma = 1

    // toe section
    // SolveAB https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L60
    toeSegment_B = (m * params_x0) / (toeM + EPSILON);
    float _410 = log2(toeM); //doesn't belong to SolveAB
    toeSegment_lnA = toeSegment_B * (-log(params_x0));
    // toe section end

    // shoulder section
    float shoulderSection_x0 = 1.f + dstParams_overshootX - params_x1;
    float shoulderSection_y0 = params_overshootY - shoulderM;
    shoulderSegment_offsetX = 1.f + dstParams_overshootX;
    shoulderSegment_offsetY = 1.f + dstParams_overshootY;
    shoulderSegment_scaleX = -1.f; // could be optimised away if we move this outside of the PS
    // SolveAB
    shoulderSegment_B   = ((m * shoulderSection_x0) / (shoulderSection_y0 + EPSILON));
    shoulderSegment_lnA = (log2(shoulderSection_y0) * RCP_LOG2_E) - (shoulderSegment_B * log2(shoulderSection_x0));
    float shoulderSegment_B_optimised = shoulderSegment_B * RCP_LOG2_E;

    // https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L6
    // Eval
    float evalY0 = 0.f;
    if (dstParams_overshootX > 0.f)
    {
        evalY0 = -exp2(((shoulderSegment_B_optimised * log2(dstParams_overshootX)) + shoulderSegment_lnA) * LOG2_E);
    }
    // Eval end
    float invScale = 1.f / (evalY0 + params_overshootY);

    float3 toneMapped;

    for (uint channel = 0; channel < 3; channel++)
    {
        float normX = InputColour[channel] * dstCurve_invW;
        bool isToeSegment = normX < params_x0;
        float returnChannel = 0.f;

        if (isToeSegment && normX > 0.f)
        {
            returnChannel = exp2(((((log2(normX) * toeSegment_B) + _410) * RCP_LOG2_E) + toeSegment_lnA) * LOG2_E);
        }
        else if (normX < params_x1)
        {
            float evalMidSegment_y0 = normX + midSegment_offsetX; //is -(-midSegment_offsetX)
            if (evalMidSegment_y0 > 0.f)
            {
                returnChannel = exp2(log2(evalMidSegment_y0) + midSegment_lnA);
            }
        }
        else
        {
            //float evalShoulderSegment_y0 = ((-1.f) - dstParams_overshootX) + normX;
            float evalShoulderSegment_y0 = (normX - shoulderSegment_offsetX) * shoulderSegment_scaleX;
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
float HableEvalInverse(
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
  float3 InputColour,
  float params_y0,
  float params_y1,
  float dstParams_W,
  float toeSegment_lnA,
  float toeSegment_B,
  float midSegment_offsetX,
  float midSegment_lnA,
  float shoulderSegment_offsetX,
  float shoulderSegment_offsetY,
  float shoulderSegment_scaleX,
  float shoulderSegment_lnA,
  float shoulderSegment_B)
{
    float3 itmColour;

    for (uint channel = 0; channel < 3; channel++)
    {
        if (InputColour[channel] < params_y0)
        {
            itmColour[channel] = HableEvalInverse(InputColour[channel],
                                                  0.f,
                                                  0.f,
                                                  1.f,
                                                  1.f,
                                                  toeSegment_lnA,
                                                  toeSegment_B);
        }
        else if (InputColour[channel] < params_y1)
        {
            itmColour[channel] = HableEvalInverse(InputColour[channel],
                                                  -midSegment_offsetX, // minus was optimised away
                                                  0.f,
                                                  1.f,
                                                  1.f,
                                                  midSegment_lnA,
                                                  1.f);
        }
        else
        {
            itmColour[channel] = HableEvalInverse(InputColour[channel],
                                                  shoulderSegment_offsetX,
                                                  shoulderSegment_offsetY,
                                                  shoulderSegment_scaleX,
                                                  -1.f,
                                                  shoulderSegment_lnA,
                                                  shoulderSegment_B);
        }
    }

    return itmColour * dstParams_W;
}

float3 inv_tonemap_RestoreLuminance(float3 color, float tonemapLostLuminance, float preColorCorrectionLuminance, float postColorCorrectionLuminance)
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
    const float luminanceCCInvChange = 1.0f - (preColorCorrectionLuminance - postColorCorrectionLuminance);
    const float currentLum = postColorCorrectionLuminance; // Should be equal to "Luminance(color)"
    const float targetLum = currentLum + tonemapLostLuminance;
    float3 targetColor = color;
    if (currentLum != 0.f)
        targetColor *= targetLum / currentLum;
#if 0
	return lerp(color, targetColor, luminanceCCInvChange);
#else // Clamp the CC change ratio to avoid extreme values
    return lerp(color, targetColor, clamp(luminanceCCInvChange, 0.0f, 2.0f));
#endif
}

float3 PostProcess(float3 Color)
{
    const uint hdrCmpDatIndex = PcwHdrComposite.HdrCmpDatIndex;
    const float4 highlightsColorFilter = HdrCmpDat[hdrCmpDatIndex].HighlightsColourFilter;
    const float4 colorFilter = HdrCmpDat[hdrCmpDatIndex].ColourFilter;
    const float hableSaturation = HdrCmpDat[hdrCmpDatIndex].HableSaturation;
    const float brightnessMultiplier = HdrCmpDat[hdrCmpDatIndex].BrightnessMultiplier; // Neutral at 1
    const float contrastIntensity = HdrCmpDat[hdrCmpDatIndex].ContrastIntensity; // Neutral at 1
    const float contrastMidPoint = PerSceneConstants[316u].z;
    
    float colorLuminance = Luminance(Color);
        
    // saturation adjustment a la Hable
    // https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicColorGrading.cpp#L307-L309
    Color = ((Color - colorLuminance) * hableSaturation) + colorLuminance;
    // Blend in another color based on the luminance.
    Color += lerp(float3(0.f, 0.f, 0.f), colorLuminance * highlightsColorFilter.rgb, highlightsColorFilter.a);
    Color *= brightnessMultiplier;
        
    // Contrast adjustment (shift the colors from 0<->1 to (e.g.) -0.5<->0.5 range, multiply and shift back).
    // The higher the distance from the contrast middle point, the more contrast will change the color.
    Color = ((Color - contrastMidPoint) * contrastIntensity) + contrastMidPoint;
        
    Color = ((colorFilter.rgb - Color) * colorFilter.a) + Color;
    return Color;
}

PSOutput PS(PSInput psInput)
{    
    float3 inputColour = InputColour.Load(int3(int2(psInput.SV_Position.xy), 0));
    // Remove any negative value caused by using R16G16B16A16F buffers (originally this was R11G11B10F, which has no negative values).
    // Doing gamut mapping, or keeping the colors outside of BT.709 doesn't seem to be right, as they seem to be just be accidentally coming out of some shader math.
    inputColour = max(inputColour, 0.f);

#if defined(APPLY_BLOOM)

    float3 bloom = Bloom.Sample(Sampler0, psInput.TEXCOORD);

    float bloomMultiplier = PcwHdrComposite.BloomMultiplier;

    inputColour = (bloomMultiplier * bloom) + inputColour;

#endif // APPLY_BLOOM

    float3 tonemappedColor;
    float3 unclampedTonemappedColor;

#if DISABLE_TONEMAP
    tonemappedColor = inputColour;
    unclampedTonemappedColor = inputColour;
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
    float hable_shoulderSegment_scaleX;
    float hable_shoulderSegment_lnA;
    float hable_shoulderSegment_B;

    const bool clampACES = false;
    if (PcwHdrComposite.Tmo == 1u)
    {
        // ACESFilm by Krzysztof Narkowicz
        unclampedTonemappedColor = ACESReference(inputColour, clampACES);
        tonemappedColor = saturate(unclampedTonemappedColor);
    }
    else if (PcwHdrComposite.Tmo == 2u)
    {
        // ACESFilm "per scene"
        unclampedTonemappedColor = ACESParametric(inputColour,
                                                    clampACES,
                                                    acesParam_modE,
                                                    acesParam_modA);
        tonemappedColor = saturate(unclampedTonemappedColor);
    }
    else if (PcwHdrComposite.Tmo == 3u)
    {
        unclampedTonemappedColor = Hable(inputColour,
                                           hable_params_y0,
                                           hable_params_y1,
                                           hable_dstParams_W,
                                           hable_toeSegment_lnA,
                                           hable_toeSegment_B,
                                           hable_midSegment_offsetX,
                                           hable_midSegment_lnA,
                                           hable_shoulderSegment_offsetX,
                                           hable_shoulderSegment_offsetY,
                                           hable_shoulderSegment_scaleX,
                                           hable_shoulderSegment_lnA,
                                           hable_shoulderSegment_B);
        tonemappedColor = unclampedTonemappedColor; // Hable was never clamped
    }
    else
    {
        // what a tone mapper!
        unclampedTonemappedColor = inputColour;
        tonemappedColor = saturate(unclampedTonemappedColor);
    }
    
    tonemappedColor = PostProcess(tonemappedColor);
    // Repeat on unclamped tonemapped color to later retrieve the lost luminance
    unclampedTonemappedColor = PostProcess(unclampedTonemappedColor);
#endif // DISABLE_TONEMAP
    
    tonemappedColor = saturate(tonemappedColor);
    
    // This is the luminance lost by clamping SDR tonemappers to the 0-1 range, and again by the fact that LUTs only take 0-1 range input.
    const float tonemapLostLuminance = Luminance(unclampedTonemappedColor - tonemappedColor); //TODO: clip any negative values here? The unclamped tonemapper might actually have negative "lost" luminance.
    
    const float preColorCorrectionLuminance = Luminance(tonemappedColor);
    
    float3 colour = tonemappedColor;
    
#if defined(APPLY_MERGED_COLOR_GRADING_LUT) && !DISABLE_TONEMAP && !DISABLE_LUT

#if FIX_WRONG_SRGB_GAMMA
    float3 LUTEncodedColour = gamma_linear_to_sRGB(colour);
#else
    //read gamma ini value, defaulting at 2.4 (makes little sense)
    float inverseGamma = 1.f / (max(SharedFrameData.Gamma, 0.001f));
    //weird linear -> sRGB conversion that clips values just above 0, and raises blacks.
    float3 LUTEncodedColour = (pow(colour, inverseGamma) * 1.055f) - 0.055f;
    LUTEncodedColour = max(LUTEncodedColour, 0.f); // Unnecessary as the LUT sampling is already clamped.
#endif // FIX_WRONG_SRGB_GAMMA
    
    float3 LUTColor = Lut.Sample(Sampler0, LUTEncodedColour * (1.f - (1.f / LUT_SIZE)) + ((1.f / LUT_SIZE) / 2.f));
#if !FIX_LUT_GAMMA_MAPPING
    LUTColor = gamma_sRGB_to_linear(LUTColor);
#endif // FIX_LUT_GAMMA_MAPPING
    float LUTMaskAlpha = saturate(LutMask.Sample(Sampler0, psInput.TEXCOORD).x + (1.f - LUTStrenght));
    colour = lerp(LUTColor, colour, LUTMaskAlpha);
#else

#endif // APPLY_MERGED_COLOR_GRADING_LUT
    
    const float postColorCorrectionLuminance = Luminance(colour);
    
#if ENABLE_HDR
    // Restore any luminance beyond 1 that ended up clipped by HDR->SDR tonemappers and any subsequent image manipulation
    colour = inv_tonemap_RestoreLuminance(colour, tonemapLostLuminance, preColorCorrectionLuminance, postColorCorrectionLuminance);
    
#if !DISABLE_TONEMAP && 0
    if (PcwHdrComposite.Tmo == 1u)
    {
        colour = ACESReference_Inverse(colour);
    }
    else if (PcwHdrComposite.Tmo == 2u)
    {
        colour = ACESParametric_Inverse(colour, acesParam_modE, acesParam_modA);
    }
    else if (PcwHdrComposite.Tmo == 3u)
    {
        colour = Hable_Inverse(colour,
                                hable_params_y0,
                                hable_params_y1,
                                hable_dstParams_W,
                                hable_toeSegment_lnA,
                                hable_toeSegment_B,
                                hable_midSegment_offsetX,
                                hable_midSegment_lnA,
                                hable_shoulderSegment_offsetX,
                                hable_shoulderSegment_offsetY,
                                hable_shoulderSegment_scaleX,
                                hable_shoulderSegment_lnA,
                                hable_shoulderSegment_B);
    }
    else
    {
        // Any luminance lost by this tonemap case would have already been restored above with "tonemapLostLuminance".
    }
#endif // !DISABLE_TONEMAP
    
    colour *= HDR_GAME_PAPER_WHITE;
    
    //TODO: do DICE tonemapping to display nits, or some Hable like HDR tonemapper.
#else
#if SDR_USE_GAMMA_2_2 //TODO: enable this for SDR? It would make sense if we change the LUTs
    colour = pow(colour, 1.f / 2.2f);
#else
    // Do sRGB gamma even if we'd be playing on gamma 2.2 screens, as the game was already calibrated for 2.2 gamma
    colour = gamma_linear_to_sRGB(colour);
#endif // SDR_USE_GAMMA_2_2
#endif // ENABLE_HDR
    
    PSOutput psOutput;
    psOutput.SV_Target.rgb = colour;
    psOutput.SV_Target.a = 1.f;

	return psOutput;
}
