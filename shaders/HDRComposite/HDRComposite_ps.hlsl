#include "../shared.hlsl"
#include "../color.hlsl"
#include "../math.hlsl"
#include "Open_DRT.hlsl"
#include "RootSignature.hlsl"

// These are defined at compile time (shaders permutations),
// they are generally all on by default, you can undefine them manually below if necessary.
//#define APPLY_BLOOM
//#define APPLY_TONEMAPPING
// This is post processing
//#define APPLY_CINEMATICS
//#define APPLY_MERGED_COLOR_GRADING_LUT

// This disables most other features (post processing/cinematics, LUTs, ...)
#define ENABLE_TONEMAP 1
// 0 disable contrast adjustment
// 1 original (weak, generates values beyond 0-1)
// 2 improved (looks more natural, avoids values below 0, but will overshoot beyond 1 more often, and will raise blacks)
// 3 Sigmoidal inspired and biases contrast increases towards the lower and top end
#define POST_PROCESS_CONTRAST_TYPE (FORCE_VANILLA_LOOK ? 1 : 2)
// Similar to "APPLY_MERGED_COLOR_GRADING_LUT"
#define ENABLE_LUT 1
// LUTs are too low resolutions to resolve gradients smoothly if the LUT color suddenly changes between samples
#define ENABLE_LUT_TETRAHEDRAL_INTERPOLATION (FORCE_VANILLA_LOOK ? 0 : 1)
// 0 Disabled.
// 1 "Proper" LUT extrapolation done in conservative ways to determine colors outside of the LUT range as accurately as possible. It might look flat compared to other methods.
// 2 Fast LUT extrapolation that isn't hue conserving (works by rgb ratio) (generally looks good and is fairly accurate, though it generates hues that weren't there, even from "white").
// 3 Fast and hue conserving LUT extrapolation approach. It just scales the luminance/average up (it doesn't work LUTs that invert colors/brightness as we can't detect when to flip the luminance restoration direction).
// 4 Fast gamut compression (by max channel) before sampling and decompression after. This isn't accurate but generally looks good.
//   NOTE: this only compresses positive scRGB values, negative ones get clipped.
#define LUT_EXTRAPOLATION_TYPE (FORCE_VANILLA_LOOK ? 0 : 1)
// 0 Linear space - maintain hue and chroma. It looks pretty good and produces correct results.
// 1 Linear space. Gradients look wrong and there's a lot of invalid colors.
// 2 sRGB gamma. Looks best here, it produces the smoothest results with the least amount of invalid colors.
// 3 Oklab. Gradients look okish but there's a lot of invalid colors.
// 4 Oklch - maintain hue and chroma. It's the one that produces the most correct results (e.g. night vision LUT doesn't turn to pink, which is the inverse of green), but looks pretty desaturated on highlights.
// 5 Oklch - maintain hue. Gradients look off, not too many invalid colors.
#define DEFAULT_LUT_EXTRAPOLATION_COLOR_SPACE 5
// 0 inverts all of the range (the whole image), to then re-tonemap it with an HDR tonemapper.
// 1 keeps SDR toe/shadow, invert tonemap in the rest of the range.
// 2 keeps SDR toe/shadow and midtones, inverts highlights only.
// Only invert highlights is the suggested choice, as it helps conserve the SDR filmic look (shadow crush) and altered colors.
// The alternative is to keep the linear space image tonemapped by the lightweight DICE tonemapper,
// or to replicate the SDR tonemapper by luminance, though both would alter the look too much and break some scenes.
#define INVERT_TONEMAP_TYPE 2
// 0 per channel (also fallback)
// 1 on the luminance
// 2 in ICtCp
// If we are running in HDR, and we are keeping the SDR tonemapped shadow and midtones ("INVERT_TONEMAP_TYPE" >0),
// then if this is 1+, we replace the SDR tonemapped image with one tonemapped by channel instead than by luminance, to maintain more saturation.
#define HDR_TONEMAP_TYPE 2
// 0 restore SDR post process (and LUT) on the HDR tonemapped image. This makes bright saturated colors pop more, but doesn't always retain the right hue.
// 1 restore SDR post process (and LUT) on the HDR tonemapped image, and make sure we conserve the hue of the final SDR image.
// 2 directly apply the post process on the HDR tonemapped image, but we restore the LUT difference from the SDR image. Similar to 0.
// 3 directly apply the post process on the HDR tonemapped image, but we restore the LUT difference from the SDR image, and make sure we conserve the hue of the final SDR image. Similar to 1.
// 4 directly apply the post process (and LUT) on the HDR tonemapped image, with LUT extrapolation (the final result depends on "DEFAULT_LUT_EXTRAPOLATION_COLOR_SPACE").
//   This is probably the most "correct" one and closer to vanilla, even if it doesn't always pop as much as other inaccurate settings.
// 5 user setting between 2 and 4.
#define HDR_POST_PROCESS_TYPE 5
#define DRAW_LUT 0
#define DRAW_TONEMAPPER 0

// Enables our Luma custom HDR tonemapper
#define HDR_TONE_MAPPER_ENABLED 1

// 0 Ignored, 1 ACES Reference, 2 ACES Parametric, 3 Hable, 4+ Disable tonemapper
#define FORCE_TONE_MAPPER 0

#if FORCE_TONE_MAPPER > 0
	#define TONE_MAPPER_ENUM FORCE_TONE_MAPPER
#else
	#define TONE_MAPPER_ENUM PcwHdrComposite.Tmo
#endif


template<class T>
T TO_LUT_EXTRAPOLATION_SPACE(T x, uint LUTExtrapolationColorSpace)
{
	if (LUTExtrapolationColorSpace <= 1)
		return x;
	if (LUTExtrapolationColorSpace == 2)
		return gamma_linear_to_sRGB_mirrored(x);
	if (LUTExtrapolationColorSpace == 3)
		return linear_srgb_to_oklab(x);
	/*if (LUTExtrapolationColorSpace >= 4)*/
	return linear_srgb_to_oklch(x);
}
template<class T>
T FROM_LUT_EXTRAPOLATION_SPACE(T x, uint LUTExtrapolationColorSpace)
{
	if (LUTExtrapolationColorSpace <= 1)
		return x;
	if (LUTExtrapolationColorSpace == 2)
		return gamma_sRGB_to_linear_mirrored(x);
	if (LUTExtrapolationColorSpace == 3)
		return oklab_to_linear_srgb(x);
	/*if (LUTExtrapolationColorSpace >= 4)*/
	return oklch_to_linear_srgb(x);
}

cbuffer CSharedFrameData : register(b0, space6)
{
	FrameData SharedFrameData : packoffset(c0);
};

cbuffer CPerSceneConstants : register(b0, space7)
{
	float4 PerSceneConstants[3272] : packoffset(c0);
};

cbuffer CPushConstantWrapper_HDRComposite : register(b0, space0)
{
	PushConstantWrapper_HDRComposite PcwHdrComposite : packoffset(c0);
};


Texture2D<float3> InputColorTexture : register(t0, space9);

#if defined(APPLY_MERGED_COLOR_GRADING_LUT)

Texture2D<float3> LUTMaskTexture : register(t1, space9);
Texture3D<float3> LUTTexture     : register(t3, space9);

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
#if defined(APPLY_MERGED_COLOR_GRADING_LUT) || defined(APPLY_BLOOM)
	float2 TEXCOORD    : TEXCOORD0;
#endif // APPLY_MERGED_COLOR_GRADING_LUT || APPLY_BLOOM
};

struct PSOutput
{
	float4 SV_Target : SV_Target0;
};

struct ACESParametricParams
{
	float modE;
	float modA;
};

struct ToneMapperParams
{
	float3 inputColor; // Untonemapped color
	float inputLuminance; // Untonemapped color luminance
	float3 outputSDRColor;
	// The following parameters might not always be written/used/modified:
	float outputSDRLuminance;
	float3 outputHDRColor;
	float outputHDRLuminance;
	ACESParametricParams acesParametricParams;
	HableParams hableParams;
};

struct CompositeParams
{
	//TODO: rename these variables to input color, tonemapped color, post processed tonemapped color, color graded post processed tonemapped color etc etc?
	PSInput psInput;
	float3 renderedColor; // Source/input HDR linear color
	float3 outputColor; // Final output color (SDR or HDR), and also the color we usually work with for any operation
	float3 preLUTColor; // TM+PP
	float3 postLUTColor; // TM+PP+CG
	float3 finalSDRColor; // TM+PP+CG+GC - Final "original" (vanilla, ~unmodded) linear SDR color before output transform
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

static const float SDRTonemapHDRStrength = 1.f;
static const float PostProcessStrength = 1.f;
// 1 is neutral. Suggested range 0.5-1.5 though 1 is heavily suggested.
// Exposure to the user for more customization.
static const float HDRHighlightsModulation = 1.f;

static const float OklabGamma = 3.f;

static const float ACES_a = 2.51f;
static const float ACES_b = 0.03f;
static const float ACES_c = 2.43f;
static const float ACES_d = 0.59f;
static const float ACES_e = 0.14f;


template<class T>
T ACES(
	T Color,
	bool   Clamp,
	float  modE,
	float  modA)
{
	Color = (Color * (modA * Color + ACES_b)) / ((Color * (ACES_c * Color + ACES_d)) + modE);
	return Clamp ? saturate(Color) : Color;
}

// ACESFilm by Krzysztof Narkowicz (https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/)
// (color * ((a * color) + b)) / (color * ((c * color) + d) + e)
template<class T>
T ACESFitted(
	T Color,
	bool   Clamp)
{
	return ACES(Color, Clamp, ACES_e, ACES_a);
}

// ACESFilm "per scene"
template<class T>
T ACESParametric(
	in    T Color,
	in    bool   Clamp,
	inout ACESParametricParams params
)
{
	const float AcesParam0 = PerSceneConstants[3269u].x; // Constant is usually 11.2
	const float AcesParam1 = PerSceneConstants[3269u].y; // Constant is usually 0.022

	params.modE = AcesParam1;
	params.modA = ((0.56f / AcesParam0) + ACES_b) + (AcesParam1 / (AcesParam0 * AcesParam0));

	return ACES(Color, Clamp, params.modE, params.modA);
}

template<class T>
T ACES_Inverse(
	T     Color,
	float modE,
	float modA)
{
	// ACES is not defined for any values beyond 0-1, as they already represent the 0-INF range.
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
T ACESFitted_Inverse(T Color)
{
	return ACES_Inverse(Color, ACES_e, ACES_a);
}

template<class T>
T ACESParametric_Inverse(T Color, float modE, float modA)
{
	return ACES_Inverse(Color, modE, modA);
}

float HableEval(
	float           normX,
	HableEvalParams eParams)
{
	float channelOut = 0.f;

	// Toe
	if (normX < eParams.params_x0)
	{
		if (normX > 0.f)
		{
			channelOut = exp2(((((log2(normX) * eParams.toeSegment_B) + eParams.toeSegment_optimised) * RCP_LOG2_E) + eParams.toeSegment_lnA_optimised) * LOG2_E);
		}
	}
	// Mid
	else if (normX < eParams.params_x1)
	{
		float evalMidSegment_y0 = normX + eParams.midSegment_offsetX; // was -(-hableParams.midSegment.offsetX)
		if (evalMidSegment_y0 > 0.f)
		{
			channelOut = exp2(log2(evalMidSegment_y0) + eParams.midSegment_lnA_optimised);
		}
	}
	// Shoulder (highlight)
	else
	{
		// Note that this will "clip" to 1 way before +INF

		//float evalShoulderSegment_y0 = ((-1.f) - params_overshootX) + normX; // small optimisation from the original decompilation
		float evalShoulderSegment_y0 = (1.f + eParams.params_overshootX) - normX;
		float evalShoulderReturn = 0.f;
		if (evalShoulderSegment_y0 > 0.f)
		{
			evalShoulderReturn = exp2(((eParams.shoulderSegment_B_optimised * log2(evalShoulderSegment_y0)) + eParams.shoulderSegment_lnA) * LOG2_E);
		}
		channelOut = eParams.params_overshootY - evalShoulderReturn;
	}
	return channelOut;
}

// https://github.com/johnhable/fw-public
// http://filmicworlds.com/blog/filmic-tonemapping-with-piecewise-power-curves/
// This is NOT the Uncharted 2 tonemapper, which was also by Hable.
float3 Hable(
	in  float3      InputColor,
	out HableParams hableParams)
{
	// https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L202

	// Note that all these variables can vary depending on the level.
	// The 2.2 pow is so you don't have to input very small numbers, it's not related to gamma.
	const float toeLength        =   pow(saturate(PerSceneConstants[3269u].w), 2.2f); // Constant is usually 0.3, but can also be ~0
	const float toeStrength      =       saturate(PerSceneConstants[3269u].z); // Constant is usually 0.5
	const float shoulderLength   = clamp(saturate(PerSceneConstants[3270u].y), EPSILON, BTHCNST); // Constant is usually 0.8
	const float shoulderStrength =            max(PerSceneConstants[3270u].x, 0.f); // Constant is usually 9.9
	const float shoulderAngle    =       saturate(PerSceneConstants[3270u].z); // Constant is usually 0.3

	// Decent range found empirically. It's very extensive.
	static const float HableShadowModulationMax = 10.f;
	static const float HableShadowModulationMin = 0.f;
	const float shadowModulation = HdrDllPluginConstants.ToneMapperShadows + 0.5f;
	const float shadowModulationPow = shadowModulation >= 1.f ? linearNormalization(shadowModulation, 1.0f, 1.5f, 1.f, HableShadowModulationMax) : linearNormalization(shadowModulation, 0.5f, 1.0f, HableShadowModulationMin, 1.f);

	//dstParams
	float dstParams_x0 = toeLength * 0.5f;
	float dstParams_y0 = (1.f - pow(toeStrength, shadowModulationPow)) * dstParams_x0;

	float remainingY = 1.f - dstParams_y0;

	float y1_offset = (1.f - shoulderLength) * remainingY;
	//dstParams
	float dstParams_x1 = dstParams_x0 + y1_offset;
	float dstParams_y1 = dstParams_y0 + y1_offset;

	float extraW = exp2(shoulderStrength) - LFLT1;
	float initialW = dstParams_x0 + remainingY;
	hableParams.dstParams.W = initialW + extraW;

	const float shoulderAngleXshoulderStrength = shoulderAngle * shoulderStrength;
	// "W * " was optimised away by DXIL->SPIRV->HLSL conversion as down the line there was a "/ W"
	float dstParams_overshootX = 2.f  * shoulderAngleXshoulderStrength;
	float dstParams_overshootY = 0.5f * shoulderAngleXshoulderStrength;

	// https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L87

	//dstCurve
	float dstCurve_invW = 1.f / hableParams.dstParams.W;

	//params
	float params_x0 = dstParams_x0 / hableParams.dstParams.W;
	float params_x1 = dstParams_x1 / hableParams.dstParams.W;
	float dx        = y1_offset    / hableParams.dstParams.W;
	//float params_overshootX = dstParams_overshootX / hableParams.dstParams.W; // this step was optimised away
	const float params_overshootX = dstParams_overshootX;

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
	float toeSegment_optimised = log2(hableParams.params.y0);
	float toeSegment_lnA_optimised = -hableParams.toeSegment.B * log(params_x0);
	hableParams.toeSegment.lnA = toeSegment_optimised * RCP_LOG2_E + toeSegment_lnA_optimised;
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
	float evalY0 = params_overshootY;
	if (params_overshootX > 0.f) // log2(0) goes towards -INF, exp2(-INF) is 0. "params_overshootX" cannot be < 0 but it can occasionally be 0.
	{
		evalY0 -= exp2(((shoulderSegment_B_optimised * log2(params_overshootX)) + hableParams.shoulderSegment.lnA) * LOG2_E);
	}
	// Eval end
	hableParams.invScale = 1.f / evalY0;

	hableParams.toeEnd = (min(params_x0, params_x1) / dstCurve_invW) / hableParams.invScale;
	hableParams.shoulderStart = (max(params_x0, params_x1) / dstCurve_invW) / hableParams.invScale;

	HableEvalParams evalParams;

	evalParams.params_x0                   = params_x0;
	evalParams.params_x1                   = params_x1;
	evalParams.params_overshootX           = params_overshootX;
	evalParams.params_overshootY           = params_overshootY;
	evalParams.toeSegment_lnA_optimised    = toeSegment_lnA_optimised;
	evalParams.toeSegment_optimised        = toeSegment_optimised;
	evalParams.toeSegment_B                = hableParams.toeSegment.B;
	evalParams.midSegment_offsetX          = hableParams.midSegment.offsetX;
	evalParams.midSegment_lnA_optimised    = midSegment_lnA_optimised;
	evalParams.shoulderSegment_lnA         = hableParams.shoulderSegment.lnA;
	evalParams.shoulderSegment_B_optimised = shoulderSegment_B_optimised;

	float3 toneMapped;

	toneMapped = InputColor * dstCurve_invW; // = normX

	toneMapped.r = HableEval(toneMapped.r, evalParams);
	toneMapped.g = HableEval(toneMapped.g, evalParams);
	toneMapped.b = HableEval(toneMapped.b, evalParams);

	toneMapped *= hableParams.invScale;

	return toneMapped; // Note: this color needs no clamping, it's already implied to be between 0-1
}

// https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L21-L34
float HableEval_Inverse(
	float          Channel,
	HableItmParams hableItmParams)
{
	// clamp to smallest float
	float y0 = max((Channel - hableItmParams.offsetY) / hableItmParams.scaleY, asfloat(0x00000001));
	float x0 = exp((log(y0) - hableItmParams.lnA) / hableItmParams.B);
	return x0 / hableItmParams.scaleX + hableItmParams.offsetX;
}

float Hable_Inverse(
	float       ColorChannel,
	HableParams hableParams)
{
	// There's no inverse formula for colors beyond the 0-1 range
	ColorChannel = saturate(ColorChannel);

	// scaleY and offsetY setup: https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L187-L197
	// toe
	if (ColorChannel < hableParams.params.y0)
	{
		// scaleXY and offsetXY setup: https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L151-L154
		HableItmParams hableItmParams;

		hableItmParams.offsetX = 0.f;
		hableItmParams.offsetY = 0.f; // * hableParams.invScale;
		hableItmParams.scaleX  = 1.f;
		hableItmParams.scaleY  = hableParams.invScale; // 1.f * hableParams.invScale
		hableItmParams.lnA     = hableParams.toeSegment.lnA;
		hableItmParams.B       = hableParams.toeSegment.B;

		ColorChannel = HableEval_Inverse(ColorChannel, hableItmParams);
	}
	// mid (linear segment)
	else if (ColorChannel < hableParams.params.y1)
	{
		// scaleXY and offsetY setup: https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L125-L127
		HableItmParams hableItmParams;

		hableItmParams.offsetX = -hableParams.midSegment.offsetX; // minus was optimised away
		hableItmParams.offsetY =  0.f; // * hableParams.invScale
		hableItmParams.scaleX  =  1.f;
		hableItmParams.scaleY  =  hableParams.invScale; // 1.f * hableParams.invScale
		hableItmParams.lnA     =  hableParams.midSegment.lnA;
		hableItmParams.B       =  1.f;

		ColorChannel = HableEval_Inverse(ColorChannel, hableItmParams);
	}
	// shoulder
	else
	{
		// scaleXY setup: https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L175-L176
		HableItmParams hableItmParams;

		hableItmParams.offsetX =  hableParams.shoulderSegment.offsetX;
		hableItmParams.offsetY =  hableParams.shoulderSegment.offsetY * hableParams.invScale;
		hableItmParams.scaleX  = -1.f;
		hableItmParams.scaleY  = -hableParams.invScale; // -1.f * hableParams.invScale
		hableItmParams.lnA     =  hableParams.shoulderSegment.lnA;
		hableItmParams.B       =  hableParams.shoulderSegment.B;

		ColorChannel = HableEval_Inverse(ColorChannel, hableItmParams);
	}

	return ColorChannel * hableParams.dstParams.W;
}

// https://github.com/johnhable/fw-public/blob/37de36e662336415f5ef654d8edfc46b4ad025ed/FilmicCurve/FilmicToneCurve.cpp#L45-L52
// NOTE: the precision of this inverse formula is within an offset of 0.0005 on most pixels, with highlights struggling more to being recovered.
float3 Hable_Inverse(
	float3      InputColor,
	HableParams hableParams)
{
	InputColor.r = Hable_Inverse(InputColor.r, hableParams);
	InputColor.g = Hable_Inverse(InputColor.g, hableParams);
	InputColor.b = Hable_Inverse(InputColor.b, hableParams);

	return InputColor;
}

// Tonemapper inspired from DICE. Can work by luminance to maintain hue.
// "HighlightsShoulderStart" should be between 0 and 1. Determines where the highlights curve (shoulder) starts. Leaving at zero for now as it's a simple and good looking default.
float3 DICETonemap(
	float3 Color,
	float  MaxOutputLuminance,
	float  HighlightsShoulderStart = 0.f,
	float  HighlightsModulationPow = 1.f)
{
#if DEVELOPMENT && 0
	HighlightsModulationPow = linearNormalization(HdrDllPluginConstants.DevSetting04, 0.f, 1.f, 0.5f, 1.5f);
#endif

#if HDR_TONEMAP_TYPE == 1 // By luminance

	const float sourceLuminance = Luminance(Color);
	if (sourceLuminance > 0.0f)
	{
		const float compressedLuminance = luminanceCompress(sourceLuminance, MaxOutputLuminance, HighlightsShoulderStart, false, FLT_MAX, HighlightsModulationPow);
		Color *= compressedLuminance / sourceLuminance;
	}
	return Color;

#elif HDR_TONEMAP_TYPE == 2 // By ICtCp; I is the luminance encoded in PQ

	//optimisation needed to not execute this for every pixel...
	static const float TargetCllInPq     = Linear_to_PQ(MaxOutputLuminance, PQMaxWhitePoint);
	static const float ShoulderStartInPq = Linear_to_PQ(HighlightsShoulderStart, PQMaxWhitePoint);

	//to L'M'S' and normalize to 1 = 10000 nits
	float3 PQ_LMS = BT709_to_LMS(Color / PQMaxWhitePoint);
	PQ_LMS = Linear_to_PQ(PQ_LMS);

	//Intensity
	float i1 = 0.5f * PQ_LMS.x + 0.5f * PQ_LMS.y;

	// return untouched Color if no tone mapping is needed
	if (i1 <= ShoulderStartInPq)
	{
		return Color;
	}
	else
	{
		float i2 = luminanceCompress(i1, TargetCllInPq, ShoulderStartInPq, false, FLT_MAX, HighlightsModulationPow);

		//saturation adjustment to blow out highlights
		float minI = min(i1 / i2, i2 / i1);

		//to L'M'S'
		PQ_LMS = ICtCp_to_PQ_LMS(float3(i2,
			                              dot(PQ_LMS, PQ_LMS_2_ICtCp[1]) * minI,
			                              dot(PQ_LMS, PQ_LMS_2_ICtCp[2]) * minI));

		//to LMS
		float3 LMS = PQ_to_Linear(PQ_LMS);
		//to RGB
		return LMS_to_BT709(LMS) * PQMaxWhitePoint;
	}

#else // By channel

	Color.r = luminanceCompress(Color.r, MaxOutputLuminance, HighlightsShoulderStart, false, FLT_MAX, HighlightsModulationPow);
	Color.g = luminanceCompress(Color.g, MaxOutputLuminance, HighlightsShoulderStart, false, FLT_MAX, HighlightsModulationPow);
	Color.b = luminanceCompress(Color.b, MaxOutputLuminance, HighlightsShoulderStart, false, FLT_MAX, HighlightsModulationPow);
	return Color;

#endif
}

// don't set this above 1 as it will break the curve (turns into a double S curve instead of a single one)
// below 1 it increases the amount of additional contrast being applied
// only change this for testing
#define LOG_2_ADJUST_C 1

// bias towards smaller numbers
void Log2Adjust(inout float Channel)
{
	static const float den = log2(LOG_2_ADJUST_C + 1.f);

#if (LOG_2_ADJUST_C != 1)
	Channel = log2(max(Channel * c + 1.f, FLT_MIN)) / den;
#else
	Channel = log2(max(Channel + 1.f, FLT_MIN));
#endif
}

// sigmoidal inspired contrast adjustment using 2 power curves
// normalizes both lower and upper part which are divided by contrastMidPoint
// and then applies a power curve based off of contrastIntensity on each part
float SigmoidalContrastAdjustment(
	float Channel,
	float contrastMidPoint,
	float contrastIntensity,
	float normalizationFactorLower,
	float normalizationFactorUpper)
{
	if (Channel <= contrastMidPoint)
	{
		Channel *= normalizationFactorLower;

		// abs/sign to handle negative case
		float signChannel = sign(Channel);
		Channel = abs(Channel);

		//TODO: fix this. It causes colors to suddenly change when passing from contrastIntensity 1 to contrastIntensity >1
		// doing this for contrastIntensity below 1 greatly desaturates compared to not doing this
		// look into if contrastIntensity ever goes below 1
		// and remove this check if it does not
		if (contrastIntensity > 1.f)
		{
			Log2Adjust(Channel);
		}
		Channel = pow(Channel, contrastIntensity) * signChannel / normalizationFactorLower;
	}
	else
	{
		// protect against float issues
		Channel = max(1.f - ((Channel - contrastMidPoint) * normalizationFactorUpper), asfloat(0x00000001));
		// doing this for contrastIntensity below 1 greatly desaturates compared to not doing this
		// look into if contrastIntensity ever goes below 1
		// and remove this check if it does not
		if (contrastIntensity > 1.f)
		{
			Log2Adjust(Channel);
		}
		Channel = (1.f - pow(Channel, contrastIntensity)) / normalizationFactorUpper + contrastMidPoint;
	}

	return Channel;
}

// "MidGrayScale" is how much the mid gray shifted from the originally intended tonemapped input (e.g. if we run this function on the untonemapped image, we can remap the mid gray)
float3 PostProcess(
	      float3 Color,
	inout float  ColorLuminance,
	      float  MidGrayScale = 1.f)
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
	// NOTE: this can cause negative colors. Use "Aurora" drug for the worst in game case.
	Color = ((Color - ColorLuminance) * hableSaturation) + ColorLuminance;

	// Blend in another color based on the luminance.
	// NOTE: this could cause negative colors if the color filter had values below 0.
	Color += lerp(float3(0.f, 0.f, 0.f), ColorLuminance * highlightsColorFilter.rgb, highlightsColorFilter.a);
	Color *= brightnessMultiplier;

#if POST_PROCESS_CONTRAST_TYPE == 1

	// Contrast adjustment (shift the colors from 0<->1 to (e.g.) -0.5<->0.5 range, multiply and shift back).
	// The higher the distance from the contrast middle point, the more contrast will change the color.
	// This generates negative colors for contrast > 1, and LUT's can't take them, unless they have "LUT_EXTRAPOLATION_TYPE" > 0
	Color = ((Color - contrastMidPoint) * contrastIntensity) + contrastMidPoint;

#elif POST_PROCESS_CONTRAST_TYPE == 2

	// Empirical value to match the original game constrast formula look more.
	// This has been carefully researched and applies to both positive and negative contrast.
	const float adjustedcontrastIntensity = pow(contrastIntensity, 2.f);
	// Do abs() to avoid negative power, even if it doesn't make 100% sense, these formulas are fine as long as they look good
	Color = pow(abs(Color) / contrastMidPoint, adjustedcontrastIntensity) * contrastMidPoint * sign(Color);

#elif POST_PROCESS_CONTRAST_TYPE == 3

	if (contrastIntensity != 1.f) // worth to do performance wise
	{
		float cIn = contrastIntensity;
		// Emprical adjustment to match native better and make the curve be an S curve (too low intensity makes it a double S curve)
		// only do them when contrastIntensity is above 1 because 1 is neutral (no adjustment)
		// below 1 it matches native nicely (though idk if contrast is ever lowered)
		if (contrastIntensity > 1.f)
		{
			cIn = lerp(pow(contrastIntensity, 5.f), pow(contrastIntensity, 3.5f), saturate(contrastIntensity - 1.f));
		}
		float cMid = contrastMidPoint;

		// normalization factors for lower and upper power curve
		float normalizationFactorLower = 1.f / cMid;
		float normalizationFactorUpper = 1.f / (1.f - cMid);

		Color.r = SigmoidalContrastAdjustment(Color.r, cMid, cIn, normalizationFactorLower, normalizationFactorUpper);
		Color.g = SigmoidalContrastAdjustment(Color.g, cMid, cIn, normalizationFactorLower, normalizationFactorUpper);
		Color.b = SigmoidalContrastAdjustment(Color.b, cMid, cIn, normalizationFactorLower, normalizationFactorUpper);
	}

#endif

	Color = lerp(Color, colorFilter.rgb * MidGrayScale, colorFilter.a);
	return Color;
}

// Unused function to de-apply post process from the SDR tonemapped image after applying the LUT to then invert the SDR tonemapping and re-apply HDR tonemapping.
// The idea has been discared for better looking and faster alternatives.
float3 PostProcess_Inverse(
	float3 Color,
	float  OriginalColorLuminance,
	float  MidGrayScale = 1.f)
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

#if POST_PROCESS_CONTRAST_TYPE == 1

	Color = ((Color - contrastMidPoint) / contrastIntensity) + contrastMidPoint;

#elif POST_PROCESS_CONTRAST_TYPE == 2

	Color = pow(abs(Color) / contrastMidPoint, 1.f / contrastIntensity) * contrastMidPoint * sign(Color);

#elif POST_PROCESS_CONTRAST_TYPE == 3

	//TODO: implement

#endif

	Color /= brightnessMultiplier;

	Color -= lerp(float3(0.f, 0.f, 0.f), OriginalColorLuminance * highlightsColorFilter.rgb, highlightsColorFilter.a);

	Color = ((Color - OriginalColorLuminance) / hableSaturation) + OriginalColorLuminance;

	return Color;
}

// Takes any original color (before some post process is applied to it) and re-applies the same transformation the post process had applied to a different (but similar) color.
// The images are expected to have roughly the same mid gray.
float3 RestorePostProcess(float3 ColorToPostProcess, float3 SourceColor, float3 PostProcessedColor, bool ForceKeepHue = false)
{
#if 0
	// Alternative Oklab based version. This doesn't seem to work as nicely, mostly because in SDR highlights are all burned to white by LUTs, and by the Vanilla SDR tonemappers,
	// so the difference between the pre LUT and post LUT colors white in Oklch will be very big (or very small) on lightness and chroma,
	// thus if we re-apply the same difference on the HDR tonemapped image ("ColorToPostProcess"), while retaining the post LUT SDR hue, colors will shift randomly way too much.
	{
		const float3 derivedPostProcessedColor = linear_srgb_to_oklch(PostProcessedColor);
		const float3 derivedSourceColor = linear_srgb_to_oklch(SourceColor);
		const float3 derivedColorToPostProcess = linear_srgb_to_oklch(ColorToPostProcess);
		const float3 postProcessColorRatio = derivedPostProcessedColor / derivedSourceColor;
		const float3 postProcessColorOffset = derivedPostProcessedColor - derivedSourceColor;
		const float3 sourceColorRatio = ColorToPostProcess / SourceColor;
		const float restoreChromaRatio = saturate(1.f / sourceColorRatio.y); // Not sure about this logic
		// Restore lightness and chroma (some by ratio, some by offset)
		float3 restoredDerivedColorToPostProcess = (derivedColorToPostProcess + float3(0.f, postProcessColorOffset.y * restoreChromaRatio, 0.f) * float3(postProcessColorRatio.x, 1.f, 1.f));
		// Negative lightness and chroma are unwanted and can flip hue
		restoredDerivedColorToPostProcess.x = max(restoredDerivedColorToPostProcess.x, 0.f);
		restoredDerivedColorToPostProcess.y = max(restoredDerivedColorToPostProcess.y, 0.f);
		return oklch_to_linear_srgb(float3(restoredDerivedColorToPostProcess.x, restoredDerivedColorToPostProcess.y, derivedPostProcessedColor.z)); // Maintain original hue
	}
#endif

	const float3 postProcessColorRatio = safeDivision(PostProcessedColor, SourceColor);
	const float3 postProcessColorOffset = PostProcessedColor - SourceColor;
	const float3 postProcessedRatioColor = ColorToPostProcess * postProcessColorRatio;
	const float3 postProcessedOffsetColor = ColorToPostProcess + postProcessColorOffset;
// Near black, we prefer using the "offset" (sum) pp restoration method, as otherwise any raised black would not work,
// for example if any zero was shifted to a more raised color, "postProcessColorRatio" would not be able to replicate that shift due to a division by zero.
// Note: in case "INVERT_TONEMAP_TYPE" was 0, we might want to test the "postProcessedOffsetColor" blend in range more carefully.
// For the "INVERT_TONEMAP_TYPE" >0 case, this seems to work great, with the "MaxShadowsColor" setting that is there, anything more will raise colors.
#if 1
	float3 newPostProcessedColor = lerp(postProcessedOffsetColor, postProcessedRatioColor, max(saturate(ColorToPostProcess / MaxShadowsColor), saturate(SourceColor / MaxShadowsColor)));
#else // Doing the branching this way might not be so good, as near black colors could still end up with crazy value due to divisions between tiny values. Might not work with "HDR_TONEMAP_TYPE" > 1 (tonemap by luminance)
	float3 newPostProcessedColor = select(PostProcessedColor == 0.f, postProcessedOffsetColor, postProcessedRatioColor);
#endif

	// Force keep the original post processed color hue, this ends up shifting the hue too much, either looking too desaturated or too saturated
	if (ForceKeepHue)
	{
		newPostProcessedColor = linear_srgb_to_oklch(newPostProcessedColor);
		PostProcessedColor = linear_srgb_to_oklch(PostProcessedColor);
		newPostProcessedColor[2] = PostProcessedColor[2];
		return oklch_to_linear_srgb(newPostProcessedColor);
	}

	return newPostProcessedColor;
}

PSOutput GetPSOutput(float3 Color)
{
	PSOutput psOutput;
	psOutput.SV_Target.rgb = Color;
	psOutput.SV_Target.a = 1.f;
	return psOutput;
}

void ApplyUserSettingExtendGamut(inout float3 Color)
{
	// We do this after applying "midGrayScale" as otherwise the input values would be too high and shit colors too much,
	// also they'd end up messing up the application of LUTs too badly.
	if (HdrDllPluginConstants.HDRExtendGamut)
	{
		// Pow by 2 to make the 0-1 setting slider more perceptually linear
		Color = ExtendGamut(Color, pow(HdrDllPluginConstants.HDRExtendGamut, 2.0f));
	}
}

// Secondary user driven saturation.
// This is already placed in LUTs but it's only applied on LUTs normalization.
void ApplyUserSettingSaturation(inout float3 Color)
{
#if ENABLE_TONEMAP
	float saturation = HdrDllPluginConstants.ToneMapperSaturation;
#if defined(APPLY_MERGED_COLOR_GRADING_LUT) && ENABLE_LUT
	saturation = lerp(saturation, 1.f, HdrDllPluginConstants.ColorGradingStrength * HdrDllPluginConstants.LUTCorrectionStrength);
#endif // APPLY_MERGED_COLOR_GRADING_LUT && ENABLE_LUT
	Color = Saturation(Color, saturation);
#endif // ENABLE_TONEMAP
}

// Secondary user driven contrast.
void ApplyUserSettingContrast(inout float3 Color)
{
#if ENABLE_TONEMAP
	const float secondaryContrast = HdrDllPluginConstants.ToneMapperContrast;
#if 0 // By luminance (no hue shift) (looks off)
	float outputColorLuminance = Luminance(Color);
	Color *= safeDivision(pow(outputColorLuminance / MidGray, secondaryContrast) * MidGray, outputColorLuminance);
#else // By channel (also increases saturation)
	Color= pow(abs(Color) / MidGray, secondaryContrast) * MidGray * sign(Color);
#endif
#endif // ENABLE_TONEMAP
}

void PostInverseTonemapByChannel(
	float                         InputChannel,
	float                         TonemappedChannel,
	inout float                   InverseTonemappedColorChannel,
	const PostInverseTonemapByChannelData sPP)
{
#if 1 // Directly use the input/source non tonemapped color for comparisons against the highlights
	const bool isHighlight = InputChannel >= sPP.minHighlightsColorOut;
	static const float HighlightAlphaBlendMultiplier = 2.5f; // Found empirically, the best balance between fixing "banding" and not having the shift noticeable.
	const float highlightAlpha = saturate(((InputChannel - sPP.minHighlightsColorOut) / sPP.minHighlightsColorOut) * HighlightAlphaBlendMultiplier);
#elif 0
	const bool isHighlight = (sPP.needsInverseTonemap ? InverseTonemappedColorChannel : InputChannel) >= sPP.minHighlightsColorOut;
#else // The least precise of them all
	const bool isHighlight = TonemappedChannel >= sPP.minHighlightsColorIn;
#endif
	float sourceHighlightInverseTonemappedColorChannel = InverseTonemappedColorChannel;
	// Restore the SDR tonemapped colors for non highlights,
	// We scale all non highlights by the scale the smallest (first) highlight would have, so we keep the curves connected
	if (INVERT_TONEMAP_TYPE > 0)
	{
		sourceHighlightInverseTonemappedColorChannel = TonemappedChannel * (sPP.minHighlightsColorOut / sPP.minHighlightsColorIn);
		if (!isHighlight)
			InverseTonemappedColorChannel = sourceHighlightInverseTonemappedColorChannel;
	}
	// Restore any highlight clipped or just crushed by the direct tonemappers (Hable does that).
	if (isHighlight)
	{
		// Use alpha to smooth any gradient disconnects (not a perfect solution).
		// Note: if necessary we could do the lerp before the highlights begin, on mid tones.
		InverseTonemappedColorChannel = lerp(sourceHighlightInverseTonemappedColorChannel, InputChannel, highlightAlpha);
	}
}

float3 PostGradingGammaCorrect(float3 TonemappedPostProcessedGradedColor)
{
	// Note: we used the "custom" gamma formulas as we want to avoid applying gamma correction on colors beyond 1 range, it makes them go crazy as sRGB and 2.2 are too different there.
	// Though we do gamma correct colors below 0 (based on "ApplyGammaBelowZeroDefault"), as they are for the most part near zero, and as such we might want them to be
	// affected by the sRGB/2.2 gamma mismatch (which is near black).

	bool gammaCorrected = false;
// Do this even if "ENABLE_LUT" is false, for consistency
#if SDR_USE_GAMMA_2_2 && (!ENABLE_LUT || !GAMMA_CORRECTION_IN_LUTS)
	// This error was always built in the image if we assume Bethesda calibrated the game on gamma 2.2 displays.
	// Possibly, if there's no color grading LUT, there shouldn't be any gamma adjustment, as the error might have been exclusively baked into LUTs,
	// while a neutral LUT (or no LUT) image would have never been calibrated, so we couldn't say for sure there was a gamma mismatch in it, but for the sake of simplicity,
	// we don't care about that, and there's a setting exposed for users anyway (it does indeed seem like the world is too dark with gamma correction on if there's no color grading).
	TonemappedPostProcessedGradedColor = lerp(TonemappedPostProcessedGradedColor, gamma_to_linear_custom(gamma_linear_to_sRGB_custom(TonemappedPostProcessedGradedColor), 2.2f), HdrDllPluginConstants.GammaCorrection);
	gammaCorrected = true;
#elif SDR_USE_GAMMA_2_2 && !ENABLE_LUT && GAMMA_CORRECTION_IN_LUTS
	// If gamma correction is in LUTs but LUTs are disabled, do it here.
	// This is questionable as maybe we shouldn't correct gamma if we didn't apply any LUT? Though if we didn't, there would be a gamma difference between applying a neutral LUT and skipping the LUT completely, which is unexpected.
	// Users can always disable gamma correction alongside color grading if they wished so.
	TonemappedPostProcessedGradedColor = lerp(TonemappedPostProcessedGradedColor, gamma_to_linear_custom(gamma_linear_to_sRGB_custom(TonemappedPostProcessedGradedColor)), HdrDllPluginConstants.GammaCorrection * (1.f - HdrDllPluginConstants.ColorGradingStrength));
	gammaCorrected = true;
#endif // SDR_USE_GAMMA_2_2
	// Modulating colors around zero can create invalid luminances if there's negative scRGB colors
	if (ApplyGammaBelowZeroDefault && gammaCorrected && Luminance(TonemappedPostProcessedGradedColor) < 0.f)
		TonemappedPostProcessedGradedColor = 0.f;

	return TonemappedPostProcessedGradedColor;
}

// Takes input coordinates. Returns output color in linear space (also works in sRGB but it's not ideal).
float3 TetrahedralInterpolation(
	Texture3D<float3> LUTTextureIn,
	float3            LUTCoordinates)
{
	// We need to clip the input coordinates as LUT texure samples below are not clamped.
	const float3 coords = saturate(LUTCoordinates) * (LUT_SIZE - 1); // Pixel coords

	// baseInd is on [0,LUT_SIZE-1]
	const int3 baseInd = coords;
	const int3 nextInd = baseInd + 1;
	int3 indV2;
	int3 indV3;

	// fract is on [0,1]
	float3 fract = frac(coords);

	const float3 v1 = LUTTextureIn.Load(int4(baseInd, 0));
	const float3 v4 = LUTTextureIn.Load(int4(nextInd, 0));

	float3 f1, f2, f3, f4;

	if (fract.r >= fract.g)
	{
		if (fract.g >= fract.b)  // R > G > B
		{
			indV2 = int3(1, 0, 0);
			indV3 = int3(1, 1, 0);

			f1 = 1.f - fract.r;
			f4 = fract.b;

			f2 = fract.r - fract.g;
			f3 = fract.g - fract.b;
		}
		else if (fract.r >= fract.b)  // R > B > G
		{
			indV2 = int3(1, 0, 0);
			indV3 = int3(1, 0, 1);

			f1 = 1.f - fract.r;
			f4 = fract.g;

			f2 = fract.r - fract.b;
			f3 = fract.b - fract.g;
		}
		else  // B > R > G
		{
			indV2 = int3(0, 0, 1);
			indV3 = int3(1, 0, 1);

			f1 = 1.f - fract.b;
			f4 = fract.g;

			f2 = fract.b - fract.r;
			f3 = fract.r - fract.g;
		}
	}
	else
	{
		if (fract.g <= fract.b)  // B > G > R
		{
			indV2 = int3(0, 0, 1);
			indV3 = int3(0, 1, 1);

			f1 = 1.f - fract.b;
			f4 = fract.r;

			f2 = fract.b - fract.g;
			f3 = fract.g - fract.r;
		}
		else if (fract.r >= fract.b)  // G > R > B
		{
			indV2 = int3(0, 1, 0);
			indV3 = int3(1, 1, 0);

			f1 = 1.f - fract.g;
			f4 = fract.b;

			f2 = fract.g - fract.r;
			f3 = fract.r - fract.b;
		}
		else  // G > B > R
		{
			indV2 = int3(0, 1, 0);
			indV3 = int3(0, 1, 1);

			f1 = 1.f - fract.g;
			f4 = fract.r;

			f2 = fract.g - fract.b;
			f3 = fract.b - fract.r;
		}
	}

	//
	// Refactored:
	//
	// dxc.exe ends up generating a pseudo-LUT of the above if statements using phi nodes. Mainly indV2 and indV3. Not much more can be done.
	//
	//
	// This both minimizes the instruction count in divergent branches and guarantees all lanes (threads) will converge on
	// the following .Load()s. Since lanes run in lock step within a wave (warp), if two or more pixels take different branches,
	// they have to wait on individual loads. e.g.
	//
	// Lane 1, 3, 6:
	//   LUTTextureIn.Load(int4(nextInd, 0)); 					// branch taken when if(fract.g >= fract.b)
	//   LUTTextureIn.Load(int4(nextInd, 0));
	//   ...
	// Lane 2, 4, 9:
	//   LUTTextureIn.Load(int4(nextInd, 0)); 					// branch taken when if(fract.g <= fract.b) -- BUT we have to wait for the
	//   LUTTextureIn.Load(int4(nextInd, 0)); 					// previous Load() instructions to complete
	//   ...
	// Lane 1, 2, 3, 4, 6, 9:
	//   return (f2 * v2) + (f3 * v3) + (f1 * v1) + (f4 * v4);	// reconverge
	//
	//
	// When moving .Load() outside the if statements:
	//
	//
	// Lane 1, 2, 3, 4, 6, 9:
	//   LUTTextureIn.Load(int4(baseInd + indV2, 0));			// all lanes take the same path in the end. branches are still required to prepare indV2
	//   LUTTextureIn.Load(int4(baseInd + indV3, 0));			// and indV3, but arthmetic ops are negligible.
	//   ...
	//   return (f2 * v2) + (f3 * v3) + (f1 * v1) + (f4 * v4);
	//
	const float3 v2 = LUTTextureIn.Load(int4(baseInd + indV2, 0));
	const float3 v3 = LUTTextureIn.Load(int4(baseInd + indV3, 0));

	return (f1 * v1) + (f2 * v2) + (f3 * v3) + (f4 * v4);
}

#if defined(APPLY_MERGED_COLOR_GRADING_LUT)

// Samples the grading LUT at the specified coordinates. Supports coordinates outside of the 0-1 range through LUT extrapolation.
// In: LUT coordinates in sRGB (not clamped)
// Out: linear space
float3 SampleGradingLUT(float3 LUTCoordinates, bool NearestNeighbor = false, int LUTExtrapolationColorSpace = DEFAULT_LUT_EXTRAPOLATION_COLOR_SPACE, bool specifyOriginalColor = false, float3 originalColor = 0.f)
{
	const float3 unclampedNeutralLUTColor = specifyOriginalColor ? originalColor : gamma_sRGB_to_linear_mirrored(LUTCoordinates);
	const float3 unclampedLUTCoordinates = LUTCoordinates;
#if LUT_EXTRAPOLATION_TYPE == 4
	const float maxChannel = max(1.f, max(unclampedNeutralLUTColor.r, max(unclampedNeutralLUTColor.g, unclampedNeutralLUTColor.b)));
	LUTCoordinates = saturate(gamma_linear_to_sRGB(unclampedNeutralLUTColor / maxChannel));
#else // LUT_EXTRAPOLATION_TYPE
	LUTCoordinates = saturate(LUTCoordinates);
#if LUT_EXTRAPOLATION_TYPE >= 1
	const bool LUTCoordinatesClamped = length(unclampedLUTCoordinates - LUTCoordinates) > FLT_MIN; // Some threshold is needed here
	const float3 neutralLUTColor = specifyOriginalColor ? saturate(originalColor) : gamma_sRGB_to_linear_mirrored(LUTCoordinates);
#endif // LUT_EXTRAPOLATION_TYPE
#endif // LUT_EXTRAPOLATION_TYPE

	const float3 LUTCoordinatesScale = (LUT_SIZE - 1.f) / LUT_SIZE; // Also "1-(1/LUT_SIZE)"
	const float3 LUTCoordinatesOffset = 1.f / (2.f * LUT_SIZE); // Also "(1/LUT_SIZE)/2"
	float3 LUTColor;
	if (NearestNeighbor)
	{
		LUTColor = LUTTexture.Load(uint4((LUTCoordinates * LUT_MAX_UINT) + 0.5f, 0)).rgb;
	}
	else
	{
#if ENABLE_LUT_TETRAHEDRAL_INTERPOLATION
		LUTColor = TetrahedralInterpolation(LUTTexture, LUTCoordinates);
#else
		LUTColor = LUTTexture.Sample(Sampler0, (LUTCoordinates * LUTCoordinatesScale) + LUTCoordinatesOffset);
#endif // ENABLE_LUT_TETRAHEDRAL_INTERPOLATION
	}

#if LUT_MAPPING_TYPE == 0
	// We always work in linear space so convert to it.
	// We never acknowledge the original wrong gamma function here (we don't really care).
	LUTColor = gamma_sRGB_to_linear_mirrored(LUTColor);
#endif // LUT_MAPPING_TYPE

#if LUT_EXTRAPOLATION_TYPE == 1
	// Extrapolate colors beyond the 0-1 input coordinates by finding the closest color to the LUT cube edge,
	// and calculating the "color change" velocity in that direction.
	// This is the only way to make sure we extrapolate colors that reliably work with all types of LUTs,
	// for example, the "night vision" LUT, which changes all colors to green and white (we can't allow any other hue to come out of it),
	// or any LUT that clips highlights to 1 beyond the input color is 1 (in that case, we'd need input colors beyond 1 to also map to 1).
	//
	// We keep the LUT coordinates in sRGB gamma, which should roughly work even outside the 0-1 range (especially beyond 1, not as much below 0).
	if (LUTCoordinatesClamped && LUTExtrapolationColorSpace >= 0) // Theoretically an optimization. The result should be valid nonetheless.
	{
		// Find the "next" color in the same direction (LUTCoordinates) as the target clamped color.
		static const bool AccurateLUTCentering = HdrDllPluginConstants.DevSetting04 <= 0.5f; //TODOFT
		const float LUTCenteringMultiplier = AccurateLUTCentering ? 1.f : (LUT_SIZE / 2.f); // Neutral at 1 (~one texel)
		// We move the coordinates back by the normal of the coordinates in excess of 0-1, by a LUT texel.
		const float3 LUTCenteredCoordinates = LUTCoordinates - (normalize(unclampedLUTCoordinates - LUTCoordinates) * (1.f - (LUTCenteringMultiplier / LUT_MAX_UINT)));
		float3 LUTCenteredColor = LUTTexture.Sample(Sampler0, (LUTCenteredCoordinates * LUTCoordinatesScale) + LUTCoordinatesOffset);
#if LUT_MAPPING_TYPE == 0 // NOTE: this and the above gamma->linear conversion could be optimized away in the "LUTExtrapolationColorSpace" 3 case
		LUTCenteredColor = gamma_sRGB_to_linear_mirrored(LUTCenteredColor);
#endif // LUT_MAPPING_TYPE

		float extrapolationRatio;
		// Shift the color in the opposite direction of the centered one, by the ratio between the centered and the extra/external offset.
		if (LUTExtrapolationColorSpace == 1)
		{
			// "unclampedNeutralLUTColor" equals "gamma_sRGB_to_linear_mirrored(unclampedLUTCoordinates)" and "neutralLUTColor" equals "gamma_sRGB_to_linear_mirrored(LUTCoordinates)".
			extrapolationRatio = length(unclampedNeutralLUTColor - neutralLUTColor) / length(neutralLUTColor - gamma_sRGB_to_linear_mirrored(LUTCenteredCoordinates));
		}
		else if (LUTExtrapolationColorSpace >= 3)
		{
			// This ratio represents the color change in OKLAB gamma/perception space (pow 3).
			// Note: it seems like multiplying "extrapolationRatio" by 0.5 might provide smoother results (no sudden gradient shifts when we start extrapolating)
			if (HdrDllPluginConstants.DevSetting03 <= 0.5f || true) //TODOFT: protect both branches against division by 0
				extrapolationRatio = length(linear_to_gamma_mirrored(unclampedNeutralLUTColor, OklabGamma) - linear_to_gamma_mirrored(neutralLUTColor, OklabGamma)) / length(linear_to_gamma_mirrored(neutralLUTColor, OklabGamma) - linear_to_gamma_mirrored(gamma_sRGB_to_linear_mirrored(LUTCenteredCoordinates), OklabGamma));
			else
				extrapolationRatio = length(linear_to_gamma_mirrored(unclampedNeutralLUTColor, OklabGamma) - linear_to_gamma_mirrored(neutralLUTColor, OklabGamma)) / LUTCenteringMultiplier; //TODOFT: try
		}
		else
		{
			// This ratio represents the color change in sRGB gamma/perception space, not in linear space, so we could apply it on gamma space colors.
			extrapolationRatio = length(unclampedLUTCoordinates - LUTCoordinates) / length(LUTCoordinates - LUTCenteredCoordinates);
		}

		if (LUTExtrapolationColorSpace == 0)
		{
#if 1 // This looks a bit better (more balanced)
			LUTColor *= lerp(1.f, safeDivision(gamma_linear_to_sRGB(average(LUTColor)), gamma_linear_to_sRGB(average(LUTCenteredColor))), extrapolationRatio);
#else
			LUTColor *= lerp(1.f, safeDivision(gamma_linear_to_sRGB(Luminance(LUTColor)), gamma_linear_to_sRGB(Luminance(LUTCenteredColor))), extrapolationRatio);
#endif
		}
		else if (LUTExtrapolationColorSpace < 4)
		{
			LUTColor = FROM_LUT_EXTRAPOLATION_SPACE(lerp(TO_LUT_EXTRAPOLATION_SPACE(LUTCenteredColor, LUTExtrapolationColorSpace), TO_LUT_EXTRAPOLATION_SPACE(LUTColor, LUTExtrapolationColorSpace), extrapolationRatio + 1.f), LUTExtrapolationColorSpace);
		}
		else // This branch produces the same exact result as the lerp() above except in the "LUTExtrapolationColorSpace" 4 case
		{
			const float3 derivedLUTColor = TO_LUT_EXTRAPOLATION_SPACE(LUTColor, LUTExtrapolationColorSpace);
			const float3 derivedLUTCenteredColor = TO_LUT_EXTRAPOLATION_SPACE(LUTCenteredColor, LUTExtrapolationColorSpace);
			float3 derivedLUTColorChangeOffset = derivedLUTColor - derivedLUTCenteredColor;
#if 0 // This doesn't help enough to enable it
			// If the luminance/intensity changed in a direction, but the average LUT color went in the other direction,
			// ignore luminance changes, as they'd likely not be extrapolated correctly with high "extrapolationRatio" values.
			if (LUTExtrapolationColorSpace >= 4)
			{
				const float derivedLUTColorAverageChangeOffset = linear_to_gamma_mirrored(average(LUTColor), OklabGamma) - linear_to_gamma_mirrored(average(LUTCenteredColor), OklabGamma);
				const float derivedLUTColorChangeRatio = safeDivision(derivedLUTColorAverageChangeOffset, derivedLUTColorChangeOffset.x);
				// Multiply by two to allow for a 50% tolerance.
				derivedLUTColorChangeOffset.x *= saturate(derivedLUTColorChangeRatio * 2.f);
			}
#endif
			// Reproject the centererd color change ratio onto the full range
			const float3 extrapolatedDerivedLUTColorChangeOffset = derivedLUTColorChangeOffset * extrapolationRatio;
			float3 extrapolatedDerivedLUTColor = derivedLUTColor + extrapolatedDerivedLUTColorChangeOffset;
			if (LUTExtrapolationColorSpace >= 4)
			{
				// Avoid negative luminance. This can happen in case "derivedLUTColorChangeOffset" intensity/luminance was negative, even if we were at a bright/colorful LUT edge,
				// especially if the input color is extremely bright. We can't really fix the color from ending up as black though, unless we find a way to auto detect it.
				extrapolatedDerivedLUTColor.x = max(extrapolatedDerivedLUTColor.x, 0.f);
				// Avoid negative chroma, as it would likely flip the hue. Theoretically this breaks the accuracy of some "LUTExtrapolationColorSpace" modes but the results would be visually bad without it.
				extrapolatedDerivedLUTColor.y = max(extrapolatedDerivedLUTColor.y, 0.f);

				//TODOFT:
				//-Try to determine whether highlights are compressed with an S filmic curve in the LUT, and if so, increase the extrapolation ratio amount...
				//-Try increasing user saturation beyond mid tones.
				//-Normalize extrapolationRatio around the target offset???
				//-Try to multiply any color above 0.5 before feeding it to the LUT, if the og LUT tend to make highlights whites, we can avoid (or delay) that by lowering the LUT input color.
				// Alternatively we could apply LUTs with less intensity on highlights... Though that won't really work on some LUTs like inverted colors.
				if (LUTExtrapolationColorSpace == 4)
				{
					LUTColor = FROM_LUT_EXTRAPOLATION_SPACE(float3(extrapolatedDerivedLUTColor.x, derivedLUTColor.yz), LUTExtrapolationColorSpace);
				}
				else // "LUTExtrapolationColorSpace" 5 case
				{
#if 1
					// Increase chroma on colors outside the LUT range (in any direction)
					//extrapolatedDerivedLUTColor.y *= 1.f + (extrapolationRatio * HdrDllPluginConstants.DevSetting05 * 1.75f / lerp(1.f, LUTCenteringMultiplier, 0.5f)); //TODOFT: re-enable
					// Increase chroma on highlights outside the LUT range (based on perceived brightness)
					//extrapolatedDerivedLUTColor.y *= 1.f + (extrapolatedDerivedLUTColorChangeOffset.x * HdrDllPluginConstants.HDRExtendGamut * 3.333f); //TODO: expose 3.333
					//LUTColor = Saturation(LUTColor, 1.f + (extrapolatedDerivedLUTColorChangeOffset.x * HdrDllPluginConstants.DevSetting04)); //TODO: put this in other cases.
#endif

					// Shift luminance and chroma to the extrapolated values, keep the original LUT edge hue (we can't just apply the same hue change, hue isn't really scalable).
					// This has problems in case the LUT color was white, so basically the hue is picked at random.
					LUTColor = FROM_LUT_EXTRAPOLATION_SPACE(float3(extrapolatedDerivedLUTColor.xy, derivedLUTColor.z), LUTExtrapolationColorSpace);
				}
			}
			else
			{
				LUTColor = FROM_LUT_EXTRAPOLATION_SPACE(extrapolatedDerivedLUTColor, LUTExtrapolationColorSpace); //TODOFT: try more
			}
		}
		// LUT extrapolation could easily generate invalid colors.
		// We could not remove invalid colors and let them be clipped at the end, but we can't really keep the target hue here even if we wanted.
		if (Luminance(LUTColor) < 0.f)
			LUTColor = 0.f;
	}
#elif LUT_EXTRAPOLATION_TYPE == 2
	// Extrapolate colors beyond the 0-1 input coordinates by re-applying the same color offset ratio the LUT applied to the clamped color.
	// NOTE: this might slightly shift the output hues from what the LUT dictacted depending on how far the input is from the 0-1 range,
	// though we generally don't care about it as the positives outweight the negatives (edge cases).
	LUTColor = RestorePostProcess(unclampedNeutralLUTColor, neutralLUTColor, LUTColor);
#elif LUT_EXTRAPOLATION_TYPE == 3
	// "average()" could also be used here, though basing it on luminance seems more correct.
	// For some reason, multiplying by this ratio works even when the value is lower than zero, though it breaks with LUTs that invert colors.
	const float clampedNeutralLUTRatio = safeDivision(Luminance(unclampedNeutralLUTColor), Luminance(neutralLUTColor));
	LUTColor *= clampedNeutralLUTRatio;
#elif LUT_EXTRAPOLATION_TYPE == 4
	LUTColor *= maxChannel;
#endif // LUT_EXTRAPOLATION_TYPE

	return LUTColor;
}

// In/Out: linear space
float3 GradingLUT(float3 color /*neutralLUTColor*/, float2 uv, int LUTExtrapolationColorSpace = DEFAULT_LUT_EXTRAPOLATION_COLOR_SPACE)
{
// Overall, we don't really care about maintaining the wrong sRGB gamma formula as it broke LUT mapping, causing clipping, and just looked bad.
#if !FORCE_VANILLA_LOOK
	float3 LUTCoordinates = gamma_linear_to_sRGB_mirrored(color);
#else
	// Read gamma ini value, defaulting at 2.4 (makes little sense)
	float inverseGamma = 1.f / (max(SharedFrameData.Gamma, 0.001f));
	// Weird linear -> sRGB conversion that clips values just above 0.
	// There was a max() with 0 in the vanilla code here, but it's unnecessary as LUT sampling is already clamped.
	const float3 LUTCoordinates = gamma_linear_to_sRGB_Bethesda_Optimized(color, inverseGamma);
#endif // FORCE_VANILLA_LOOK

	float3 LUTColor = SampleGradingLUT(LUTCoordinates, false, LUTExtrapolationColorSpace, true, color);

#if MAINTAIN_CORRECTED_LUTS_TINT_AROUND_BLACK
	// If we have LUT correction ongoing, and the input/output LUT colors are dark/black and they fall within the closest LUT step around zero,
	// double the saturation to maintain color tint more effectively around black (0 0 0 black doesn't have a hue, and LUTs are corrected so their black point is always full black).
	// We can't do this in the LUT merge/mix shader as it would mess around with the LUT texture sampling.
	// To do this 100% correctly we should do additional LUT samples (e.g. the first texel on the grey LUT line), but we designed it in a way to avoid it, to optimize it.
	// Unless gamut mapping is enabled, We only do this in HDR as it creates a lot of colors beyond sRGB, which would clip in SDR unless we had gamut mapping on output. 
	if ((CLAMP_INPUT_OUTPUT_TYPE == 1 || HdrDllPluginConstants.DisplayMode > 0) && /*Optional check*/ HdrDllPluginConstants.LUTCorrectionStrength != 0.f)
	{
		const float3 neutralLUTColor = color;

		// The amount our color coordinates are within the first LUT sub cube (the one around the origin/black).
#if 1 // Pick the max LUT distance from zero, returning 1 if any coordinates touch the edges of the first LUT sub cube (we always project the LUT coordinates onto the subcube 3 outer sides and divide by that length)
		const float3 subCubeCoordinates = abs(LUTCoordinates) * LUT_SIZE;
		const float subCubeCoordinatesLength = length(subCubeCoordinates);
		bool subCubeCoordinatesClamped = false;
		// We normalize the vector and multiply it by 3, so it's guaranteed to touch one of the cube sides.
		const float3 clampedSubCubeCoordinates = clampCubeCoordinates(normalize(subCubeCoordinates) * 3.f, subCubeCoordinatesClamped, false);
		const float distanceFromZero = (subCubeCoordinatesLength <= FLT_MIN) ? 0.f : saturate(subCubeCoordinatesLength / length(clampedSubCubeCoordinates));
		const float3 distanceFromZero3D = saturate(subCubeCoordinates);
#elif 1 // Less accurate, but cheaper version of "clampCubeCoordinates()"
		const float3 distanceFromZero3D = saturate(abs(LUTCoordinates * LUT_SIZE));
		const float distanceFromZero = min(distanceFromZero3D.x, min(distanceFromZero3D.y, distanceFromZero3D.z));
#else // Find the distance based on a sphere around 0
	#if 0 // This makes the sphere circumscribed around the LUT first sub cube, meaning this returns values < 1 for coordinates like 1 0 0 or 0 1 1, which isn't great (we only want to correct the LUT sub cube closest to the origin)
		static const float LUTRadius = length(float3(1.f, 1.f, 1.f));
	#else // This makes the sphere inscribed within the LUT first sub cube, it should be better
		static const float LUTRadius = 1.f;
	#endif
		const float distanceFromZero = saturate((length(LUTCoordinates) * LUT_SIZE) / LUTRadius);
#endif
		const float closenessToZero = 1.f - distanceFromZero;

		// If the LUT color was highly deviated from black, don't correct saturation, this avoids false positive cases (e.g. inverted colors LUTs).
		// We only want to correct LUTs that had a near black tint. Theoretically we'd just branch on whether the LUT was corrected or not, but that's technically "impossible".
#if 1 // Branching is risky but it will probably work due to the high threshold
		const float luminanceDeviationFromNeutralLUT = abs(Luminance(LUTColor) - Luminance(neutralLUTColor)) > 0.5f ? 0.f : 1.f;
#else
		const float luminanceDeviationFromNeutralLUT = 1.f - saturate(abs(Luminance(LUTColor) - Luminance(neutralLUTColor)) * LUT_SIZE);
#endif

		// Don't correct LUTs that are close to the neutral one.
		// This basically represents how tinted the LUT is. If a LUT just moved the brightness around without shifting the hue or saturation, this shouldn't have any effect.
		//
		// We divide the LUT in and out colors to find their normalized value around one (a projection of their rate of change) (division by zero should be fine).
		// Given that our color correction always makes the LUT origin texel 0 0 0, we need to normalize by the distance from the LUT origin as well.
		// NOTE: to do this more accurately, we could use OKLCH, though it's too expensive.
#if 0 // We don't use the 3D distance as it would cause a hue shift in "normalizedDeviationFromNeutralLUT", given it's per channel
		const float3 normalizedDeviationFromNeutralLUT = (LUTColor / neutralLUTColor) / distanceFromZero3D;
#elif 0 // This is possibly more accurate, as it's all in gamma space instead of being a mix of linear and gamma spaces, though it's more expensive
		const float3 normalizedDeviationFromNeutralLUT = (gamma_linear_to_sRGB_mirrored(LUTColor) / LUTCoordinates) / distanceFromZero3D;
#else
        const float3 normalizedDeviationFromNeutralLUT = (LUTColor / neutralLUTColor) / distanceFromZero;
#endif
		// To find the tint (chroma) deviation from 1 1 1, we use this approximate but functional method (it's not really chroma):
#if 0 // Shift away from the average to increase the effect of outliers values (further helps to avoids brightness changes from accidentally affecting near black saturation). This seems detrimental for now
		const float maxNormalizedDeviationFromNeutralLUT = lerp(max(normalizedDeviationFromNeutralLUT.x, max(normalizedDeviationFromNeutralLUT.y, normalizedDeviationFromNeutralLUT.z)), average(normalizedDeviationFromNeutralLUT), -0.5f); 
		const float minNormalizedDeviationFromNeutralLUT = lerp(min(normalizedDeviationFromNeutralLUT.x, min(normalizedDeviationFromNeutralLUT.y, normalizedDeviationFromNeutralLUT.z)), average(normalizedDeviationFromNeutralLUT), -0.5f);
#else
		const float maxNormalizedDeviationFromNeutralLUT = max(normalizedDeviationFromNeutralLUT.x, max(normalizedDeviationFromNeutralLUT.y, normalizedDeviationFromNeutralLUT.z));
		const float minNormalizedDeviationFromNeutralLUT = min(normalizedDeviationFromNeutralLUT.x, min(normalizedDeviationFromNeutralLUT.y, normalizedDeviationFromNeutralLUT.z));
#endif
		static const float normalizationDeviationThreshold = 0.0001f; // Threshold to 0.01% to avoid false positives. Found empirically.
		const float minNormalizedDeviationFromNeutralLUTChroma = max(maxNormalizedDeviationFromNeutralLUT - minNormalizedDeviationFromNeutralLUT - normalizationDeviationThreshold, 0.f);
		static const float deviationFromNeutralLUTThreshold = 5.f; // Found empirically. Should be > 0. Too low values give a risk of adding saturation on netraul LUTs
		const float chromaDeviationFromNeutralLUT = minNormalizedDeviationFromNeutralLUTChroma != 0.f ? saturate(pow(minNormalizedDeviationFromNeutralLUTChroma, deviationFromNeutralLUTThreshold)) : 0.f; // Mid gray should have chroma at 0

		// Double the saturation because when near black, we are lerping between a color without hue (0 0 0 / origin) and a color with hue (the ones immediately after, > 0).
		// Thus only half of the colors in the lerp will have a hue, which means duplicating the color chroma/saturation strength will normalize the color "tint" amount.
		static const float saturationMultiplier = 2.f; // Anything more than 2 will cause disconnected gradients when the LUT coords shift from the first to the second texel
		// NOTE: it would be better to do this with Oklab chroma, but it would be much more expensive
		LUTColor = Saturation(LUTColor, lerp(1.f, saturationMultiplier, closenessToZero * luminanceDeviationFromNeutralLUT * chromaDeviationFromNeutralLUT * HdrDllPluginConstants.LUTCorrectionStrength));
#if 0 // Use this to visualize how what pixels get increased saturation, the brighter they are, the more saturation will increase. It should be all black with 100% neutral LUT.
		LUTColor = closenessToZero * luminanceDeviationFromNeutralLUT * chromaDeviationFromNeutralLUT;
#endif
	}
#endif // MAINTAIN_CORRECTED_LUTS_TINT_AROUND_BLACK

	// "ColorGradingStrength" is similar to "AdditionalNeutralLUTPercentage" from the LUT mixing shader, though this is more precise as it skips the precision loss induced by a neutral LUT
	const float LUTMaskAlpha = (1.f - LUTMaskTexture.Sample(Sampler0, uv).x) * HdrDllPluginConstants.ColorGradingStrength;
	LUTColor = lerp(color, LUTColor, LUTMaskAlpha);

	return LUTColor;
}

#if DRAW_LUT
float3 DrawLUTTexture(float2 PixelPosition, uint PixelScale, inout bool DrawnLUT)
{
	const uint LUTMin = 0;
	uint LUTMax = LUT_MAX_UINT;
	uint LUTSizeMultiplier = 1;
#if LUT_EXTRAPOLATION_TYPE >= 1
	LUTSizeMultiplier = 3; // This will end up multiplying the number of shown cube slices as well
	// Shift the LUT coordinates generation to account for 50% of extra area beyond 1 and 50% below 0,
	// so "LUTPixelPosition3D" would represent the LUT from -0.5 to 1.5 before being normalized.
	// The bottom and top 25% squares (cube sections) will be completely outside of the valid cube range and be completely extrapolated,
	// while for the middle 50% squares, only their outer half would be extrapolated.
	LUTMax += LUT_SIZE_UINT * (LUTSizeMultiplier - 1);
#endif
	PixelScale = pow(PixelScale, 1.f / LUTSizeMultiplier);

	const uint2 LUTPixelPosition2D = PixelPosition / PixelScale;
	const uint3 LUTPixelPosition3D = uint3(LUTPixelPosition2D.x % (LUT_SIZE_UINT * LUTSizeMultiplier), LUTPixelPosition2D.y, LUTPixelPosition2D.x / (LUT_SIZE_UINT * LUTSizeMultiplier));
	if (!any(LUTPixelPosition3D < LUTMin) && !any(LUTPixelPosition3D > LUTMax))
	{
		DrawnLUT = true;
		const int3 normalizedLUTPixelPosition3D = (int3)LUTPixelPosition3D - (int3)((LUTSizeMultiplier - 1) * LUT_SIZE_UINT / 2);

		const float2 LUTPixelPosition2DFloat = PixelPosition / (float)PixelScale;
		float3 LUTPixelPosition3DFloat = float3(fmod(LUTPixelPosition2DFloat.x, LUT_SIZE_UINT * LUTSizeMultiplier), LUTPixelPosition2DFloat.y, (uint)(LUTPixelPosition2DFloat.x / (LUT_SIZE_UINT * LUTSizeMultiplier)));
		LUTPixelPosition3DFloat.xy -= 0.5f; // Normalize the coordinates (haven't fully understood why this is needed yet)
		const float3 normalizedLUTPixelPosition3DFloat = LUTPixelPosition3DFloat - (int3)((LUTSizeMultiplier - 1) * LUT_SIZE_UINT / 2);

		const bool NearestNeighbor = false;
		// The color the neutral LUT would have, in sRGB gamma space
		const float3 LUTCoordinates = (NearestNeighbor ? normalizedLUTPixelPosition3D : normalizedLUTPixelPosition3DFloat) / float(LUT_MAX_UINT);
		const float3 LUTColor = SampleGradingLUT(LUTCoordinates, NearestNeighbor);
		// NOTE: we do not lerp with the neutral LUT based on "HdrDllPluginConstants.ColorGradingStrength" here, as it's too complicated to replicate all the settings,
		// use "AdditionalNeutralLUTPercentage" from the ColorGradingMerge shader to achieve the same.
		return LUTColor;
	}
	return 0;
}

float3 DrawLUTGradients(float2 PixelPosition, uint PixelScale, inout bool DrawnLUT)
{
	static const uint DrawLUTSquareSize = LUT_SIZE_UINT * PixelScale;
	float width;
	float height;
	// We draw this on the bottom left
	InputColorTexture.GetDimensions(width, height);
	if (PixelPosition.y < (height - DrawLUTSquareSize))
	{
		return 0;
	}

	const uint2 position = uint2(PixelPosition.x / PixelScale, (PixelPosition.y - (height - DrawLUTSquareSize)) / PixelScale);
	uint xPoint = position.x;
	uint yPoint = position.y;
	// NOTE: this is extremely slow.
	if ((xPoint <= LUT_MAX_UINT && yPoint >= 0 && yPoint <= LUT_MAX_UINT))
	{
		DrawnLUT = true;
		uint3 xyz;
		uint row = 0u;
		uint coord = xPoint;
		uint cmax = LUT_MAX_UINT;
		uint inverse = LUT_MAX_UINT - xPoint;
		if (yPoint == row++) xyz = uint3(coord  , coord  , coord  ); // Black => White

		else if (yPoint == row++) xyz = uint3(coord  , 0      , 0      ); // Black => Red
		else if (yPoint == row++) xyz = uint3(0      , coord  , 0      ); // Black => Green
		else if (yPoint == row++) xyz = uint3(0      , 0      , coord  ); // Black => Blue

		else if (yPoint == row++) xyz = uint3(0      , coord  , coord  ); // Black => Cyan
		else if (yPoint == row++) xyz = uint3(coord  , coord  , 0      ); // Black => Yellow
		else if (yPoint == row++) xyz = uint3(coord  , 0      , coord  ); // Black => Magenta

		else if (yPoint == row++) xyz = uint3(cmax   , coord  , coord  ); // Red to White
		else if (yPoint == row++) xyz = uint3(coord  , cmax   , coord  ); // Green to White
		else if (yPoint == row++) xyz = uint3(coord  , coord  , cmax   ); // Blue to White

		else if (yPoint == row++) xyz = uint3(coord  , cmax   , cmax   ); // Cyan to White
		else if (yPoint == row++) xyz = uint3(cmax   , cmax   , coord  ); // Yellow to White
		else if (yPoint == row++) xyz = uint3(cmax   , coord  , cmax   ); // Magenta to White

		else if (yPoint == row++) xyz = uint3(inverse, coord  , coord  ); // Red to Cyan
		else if (yPoint == row++) xyz = uint3(coord  , inverse, coord  ); // Green to Magenta
		else if (yPoint == row++) xyz = uint3(coord  , coord  , inverse); // Blue to Yellow

		float3 LUTColor = LUTTexture.Load(uint4(xyz.rgb, 0)).rgb;
#if LUT_MAPPING_TYPE == 0
		LUTColor = gamma_sRGB_to_linear_mirrored(LUTColor);
#endif // LUT_MAPPING_TYPE
		return LUTColor;
	}
	return 0;
}
#endif // DRAW_LUT
#endif // APPLY_MERGED_COLOR_GRADING_LUT

#if DRAW_TONEMAPPER
static const uint DrawToneMapperSize = 512;
static const uint ToneMapperPadding = 8;
static const uint ToneMapperBins = DrawToneMapperSize - (2 * ToneMapperPadding);
struct DrawToneMapperParams
{
	bool drawToneMapper;
	uint toneMapperY;
	float valueX;
};

DrawToneMapperParams DrawToneMapperStart(inout CompositeParams params)
{
	DrawToneMapperParams dtmParams = { false, -1u, 0 };
	float width;
	float height;
	InputColorTexture.GetDimensions(width, height);
	int2 offset = int2(
		params.psInput.SV_Position.x - (width - DrawToneMapperSize),
		(DrawToneMapperSize) - params.psInput.SV_Position.y
	);
	if (offset.x >= 0 && offset.y >= 0)
	{
		params.outputColor = float3(0.15f, 0.15f, 0.15f);
		if (
			offset.x >= ToneMapperPadding
			&& offset.y >= ToneMapperPadding
			&& offset.x < (DrawToneMapperSize - ToneMapperPadding)
			&& offset.y < (DrawToneMapperSize - ToneMapperPadding)
		)
		{
			dtmParams.drawToneMapper = true;
			uint toneMapperX = offset.x - ToneMapperPadding;
			dtmParams.toneMapperY = offset.y - ToneMapperPadding;

			// From 0.01 to Peak nits (in log)
			const float xMin = log10(0.01 / WhiteNits_sRGB);
			const float xMax = log10(PQMaxNits / WhiteNits_sRGB);
			const float xRange = xMax - xMin;
			dtmParams.valueX = (float(toneMapperX) / float(ToneMapperBins)) * (xRange) + xMin;
			dtmParams.valueX = pow(10.f, dtmParams.valueX);
			params.outputColor = float3(dtmParams.valueX,dtmParams.valueX,dtmParams.valueX);
		}
	}
	return dtmParams;
}

void DrawToneMapperEnd(inout CompositeParams params, inout DrawToneMapperParams dtmParams)
{
	if (dtmParams.drawToneMapper)
	{
		// From 0.01 to Peak nits (in log)
		const float yMin = log10(0.01);
		const float yMax = log10(PQMaxNits);
		const float yRange = yMax - yMin;
		float valueY = (float(dtmParams.toneMapperY) / float(ToneMapperBins)) * (yRange) + yMin;
		float peakNits = HdrDllPluginConstants.DisplayMode >=0
			? HdrDllPluginConstants.HDRPeakBrightnessNits
			: WhiteNits_sRGB;
		valueY = pow(10.f, valueY);
		valueY /= WhiteNits_sRGB;
		float outputY = Luminance(params.outputColor);
		if (outputY > valueY )
		{
			if (outputY < MidGray)
			{
				params.outputColor = float3(0.3f,0,0.3f);
			}
			else if (outputY > peakNits / WhiteNits_sRGB)
			{
				params.outputColor = float3(0, 0.3f, 0.3f);
			}
			else
			{
				params.outputColor = max(0.05f, valueY);
			}
		}
		else
		{
			if (dtmParams.valueX < MidGray)
			{
				params.outputColor = float3(0,0.3f,0);
			}
			else if (valueY >= peakNits / WhiteNits_sRGB)
			{
				params.outputColor = float3(0,0,0.3f);
			}
			else
			{
				params.outputColor = 0.05f;
			}
		}
	}
}
#endif // DRAW_TONEMAPPER

void ApplyCinematics(inout CompositeParams params)
{
#if defined(APPLY_CINEMATICS) && ENABLE_TONEMAP
	float prePostProcessColorLuminance;
	// NOTE: applying most of the post process before LUTs is not a very smart choice,
	// because there's multiple operations that can move the values outside of the 0-1 range,
	// so LUT mapping would clip and hue shift, but also, applying contrast/saturation before LUT
	// implies that LUTs will apply on a different baseline, which means even more hue shift
	// (e.g. if mid tones were tinted red and highlights blue, the tint would shift due to post processing).
	// We could move part of this after LUTs, but we want to retain the original game look more than anything else (depending on the scene settings, results could vary drastically).
	params.outputColor = lerp(params.outputColor, PostProcess(params.outputColor, prePostProcessColorLuminance), PostProcessStrength);
#endif // APPLY_CINEMATICS && ENABLE_TONEMAP
}

void ApplyColorGrading(inout float3 Color, out float3 NonGammaCorrectedColor, float2 UV)
{
	NonGammaCorrectedColor = Color;
#if ENABLE_TONEMAP
#if defined(APPLY_MERGED_COLOR_GRADING_LUT) && ENABLE_LUT
	// Theoretically we might not need a hue conserving (accurate) LUT extrapolation method here, a more loose method would be fine, but for now we are going for accurate.
	// Note that we also do LUT extrapolation in SDR, to avoid further runtime branches. //TODOFT: determine if we actually need accurate LUT extrapolation in SDR and maybe fall back on cheaper method 1 or 2
	const int LUTExtrapolationColorSpace = DEFAULT_LUT_EXTRAPOLATION_COLOR_SPACE;
	Color = GradingLUT(Color, UV, LUTExtrapolationColorSpace);
#endif // APPLY_MERGED_COLOR_GRADING_LUT && ENABLE_LUT
	NonGammaCorrectedColor = Color;
	// NOTE: for now we do this even if "APPLY_MERGED_COLOR_GRADING_LUT" is disabled.
	// This is because the game lighting and tonemapping has likely been built with this gamma mismatch
	// even when devs had a neutral LUT or no LUT pass at all.
	Color = PostGradingGammaCorrect(Color);
#endif // ENABLE_TONEMAP
}

void ApplyColorGrading(inout CompositeParams params)
{
#if defined(APPLY_MERGED_COLOR_GRADING_LUT)
	ApplyColorGrading(params.outputColor, params.postLUTColor, params.psInput.TEXCOORD);
#else
	const float2 unusedUV = 0.f;
	ApplyColorGrading(params.outputColor, params.postLUTColor, unusedUV);
#endif // APPLY_MERGED_COLOR_GRADING_LUT
}

#if HDR_TONE_MAPPER_ENABLED
void ApplyHDRToneMapperScaling(inout CompositeParams params, inout ToneMapperParams tmParams)
{
	// Replicate per-channel colors by clamping
	tmParams.inputColor = clamp(tmParams.inputColor, 0, 4.f);
	float postClampedY = Luminance(tmParams.inputColor);
	tmParams.inputColor *= postClampedY ? tmParams.inputLuminance / postClampedY : 0;
	tmParams.inputLuminance = postClampedY;

	//TODO: this should be lerping DRT tonemapper parameters based on the vanilla SDR tonemapper parameters, not branch on them (nor multiply the input color).
	if (PcwHdrComposite.Tmo != 3) { // ACESFitted/Parametric
		params.outputColor *= 3.5f; 
		tmParams.inputColor *= 3.5f;
		tmParams.inputLuminance *= 3.5f;
	}
	else if (PerSceneConstants[3269u].w == 0 || PerSceneConstants[3269u].z == 0) // 0-Toe Hable
	{
		params.outputColor *= 2.8f;
		tmParams.inputColor *= 2.8f;
		tmParams.inputLuminance *= 2.8f;
	}

}

void ApplyOpenDRTToneMap(inout CompositeParams params, inout ToneMapperParams tmParams)
{
	ApplyHDRToneMapperScaling(params, tmParams);

	// Don't use variables for constants, use them inline for runtime optimizations

	// outputHDRColor = display-toned
	tmParams.outputHDRColor = open_drt_transform_custom(
			tmParams.inputColor,
			(HdrDllPluginConstants.DisplayMode > 0)
				? HdrDllPluginConstants.HDRPeakBrightnessNits
				: ReferenceWhiteNits_BT2408,
			(HdrDllPluginConstants.DisplayMode > 0)
				? HdrDllPluginConstants.HDRGamePaperWhiteNits / ReferenceWhiteNits_BT2408
				: 1.f,
			HdrDllPluginConstants.ToneMapperContrast,
			HdrDllPluginConstants.ToneMapperHighlights * 2.f,
			HdrDllPluginConstants.ToneMapperShadows * 2.f
		);
	tmParams.outputHDRColor *= (HdrDllPluginConstants.DisplayMode > 0)
		? HdrDllPluginConstants.HDRPeakBrightnessNits / ReferenceWhiteNits_BT2408
		: 1.f;
	tmParams.outputHDRLuminance = Luminance(tmParams.outputHDRColor);

	// If not using color grading use display-toned
	// If using SDR-like settings that match Vanilla, use display-toned
	// If using strict, generate SDR with Vanilla params
	// If not using strict, generate SDR with user params

	// TODO: Support strict on SDR and loose on HDR
	const bool supportStrict = false;
	if (HdrDllPluginConstants.ColorGradingStrength == 0.f
		|| (!supportStrict && HdrDllPluginConstants.DisplayMode <= 0)
		|| (
			(
				HdrDllPluginConstants.DisplayMode <= 0
					|| (
						HdrDllPluginConstants.HDRGamePaperWhiteNits == ReferenceWhiteNits_BT2408
						&& HdrDllPluginConstants.HDRPeakBrightnessNits == ReferenceWhiteNits_BT2408
					)
			) // SDR or HDR with 203/203
			&& HdrDllPluginConstants.ToneMapperContrast == 1.f
			&& HdrDllPluginConstants.ToneMapperHighlights == 1.f
			&& HdrDllPluginConstants.ToneMapperShadows == 1.f
		)
	) { // Use display-toned single-pass
		tmParams.outputSDRColor = tmParams.outputHDRColor;
		tmParams.outputSDRLuminance = tmParams.outputHDRLuminance;
	} else if (
			!supportStrict
			|| HdrDllPluginConstants.StrictLUTApplication
		) { // Vanilla render
		tmParams.outputSDRColor = open_drt_transform_custom(tmParams.inputColor); 
		tmParams.outputSDRLuminance = Luminance(tmParams.outputSDRColor);
	} else { // SDR render with user params
		// TODO: Add support
		tmParams.outputSDRColor = open_drt_transform_custom(
			tmParams.inputColor,
			ReferenceWhiteNits_BT2408,
			1.f,
			HdrDllPluginConstants.ToneMapperContrast,
			HdrDllPluginConstants.ToneMapperHighlights * 2.f,
			HdrDllPluginConstants.ToneMapperShadows * 2.f
		);
		tmParams.outputSDRLuminance = Luminance(tmParams.outputSDRColor);
	}

	params.outputColor = tmParams.outputSDRColor;
}

void ApplyOpenDRTHDRUpgrade(inout CompositeParams params, in ToneMapperParams tmParams)
{
	// Instead of multiplying by the HDR/SDR Y ratio, add the difference.
	// This solves an issue of LUTs that cause heavy luminance shifts being
	// raised to extremely high values. (eg: low contrast + uncorrected LUTs)
	
	float scaledRatio = 1.f;
	float outputY = Luminance(params.postLUTColor); // Work around gamma correction
	if (tmParams.outputHDRLuminance < tmParams.outputSDRLuminance) {
		// If substracting (user contrast or paperwhite) scale down instead
		scaledRatio = tmParams.outputHDRLuminance / tmParams.outputSDRLuminance;
	} else {
		float deltaY = tmParams.outputHDRLuminance - tmParams.outputSDRLuminance;
		float newY = outputY + max(0, deltaY); // deltaY may be NaN?
		scaledRatio = outputY > 0 ? (newY / outputY) : 0;
	}

	params.outputColor *= scaledRatio;

	ApplyUserSettingExtendGamut(params.outputColor);
	ApplyUserSettingSaturation(params.outputColor);

	// Change paper white to default from 80 to 203.
	params.outputColor *= ReferenceWhiteNits_BT2408 / WhiteNits_sRGB;
}

#endif // HDR_TONE_MAPPER_ENABLED

void ApplySDRToneMapperHDRUpgrade(inout CompositeParams params, in ToneMapperParams tmParams)
{
	float3 tonemappedColor = tmParams.outputSDRColor;

	const float acesParam_modE = tmParams.acesParametricParams.modE;
	const float acesParam_modA = tmParams.acesParametricParams.modA;
	const HableParams hableParams = tmParams.hableParams;

	const float paperWhite = HdrDllPluginConstants.HDRGamePaperWhiteNits / WhiteNits_sRGB;

	const float midGrayIn = MidGray; // tonemapped SDR mid gray
	float midGrayOut = midGrayIn; // inverse tonemapped (linear/raw/HDR) mid gray

// NOTE: we should rename "minHighlightsColorIn" and "minHighlightsColorOut" to something more generic, as now we have "INVERT_TONEMAP_TYPE" (so it could be highlights or midtones, ...),
// but it's not really necessary, as this dictates the point where we might start using the HDR tonemapper, which is indeed related to highlights.
#if INVERT_TONEMAP_TYPE != 1 // invert highlights
	float minHighlightsColorIn = MinHighlightsColor; // We consider highlight the last ~33% of perception SDR space
#else // invert midtones and highlights
	float minHighlightsColorIn = MaxShadowsColor; // We consider shadow the first ~33% of perception SDR space
#endif
	float minHighlightsColorOut = minHighlightsColorIn;
#if DEVELOPMENT && 0
	const float localSDRTonemapHDRStrength = 1.f - HdrDllPluginConstants.DevSetting01;
#else
	const float localSDRTonemapHDRStrength = SDRTonemapHDRStrength;
#endif
	// If true, we need to calculate the inverse tonemap
	const bool needsInverseTonemap = (INVERT_TONEMAP_TYPE <= 0) || localSDRTonemapHDRStrength != 1.f;

	float3 inverseTonemappedColor = needsInverseTonemap ? tonemappedColor : tmParams.inputColor;

	// Restore a color very close to the original linear one (some information might get close in the direct tonemapper)
	switch (TONE_MAPPER_ENUM)
	{
		case 1:
		{
			if (needsInverseTonemap)
			{
				inverseTonemappedColor = ACESFitted_Inverse(inverseTonemappedColor);
				midGrayOut             = ACESFitted_Inverse(midGrayIn);
			}
			minHighlightsColorOut = ACESFitted_Inverse(minHighlightsColorIn);
		} break;

		case 2:
		{
			if (needsInverseTonemap)
			{
				inverseTonemappedColor = ACESParametric_Inverse(inverseTonemappedColor, acesParam_modE, acesParam_modA);
				midGrayOut             = ACESParametric_Inverse(midGrayIn, acesParam_modE, acesParam_modA);
			}
			minHighlightsColorOut = ACESParametric_Inverse(minHighlightsColorIn, acesParam_modE, acesParam_modA);
		} break;

		case 3:
		{
#if INVERT_TONEMAP_TYPE != 1
			// Setup highlights for Hable, we use the official param based highlights shoulder start for it, so that we switch tonemapper in the same place where the hable curve would change direction (or so I think)
			const float shoulderOutStart = max(hableParams.params.y0, hableParams.params.y1); // Check both toe and mid params for extra safety
			minHighlightsColorIn         = shoulderOutStart;
#else
			const float toeOutEnd        = min(hableParams.params.y0, hableParams.params.y1);
			minHighlightsColorIn         = toeOutEnd;
#endif

			if (needsInverseTonemap)
			{
				inverseTonemappedColor = Hable_Inverse(inverseTonemappedColor, hableParams);
				midGrayOut             = Hable_Inverse(midGrayIn, hableParams);
			}
#if INVERT_TONEMAP_TYPE != 1 // Optimized and more "accurate"
			minHighlightsColorOut = hableParams.shoulderStart;
#elif 1
			minHighlightsColorOut = hableParams.toeEnd;
#else
			minHighlightsColorOut = Hable_Inverse(minHighlightsColorIn, hableParams);
#endif
		} break;

		default:
			break;
	}

	PostInverseTonemapByChannelData sPP;
	sPP.minHighlightsColorIn  = minHighlightsColorIn;
	sPP.minHighlightsColorOut = minHighlightsColorOut;
	sPP.needsInverseTonemap   = needsInverseTonemap;

	PostInverseTonemapByChannel(tmParams.inputColor.r, tonemappedColor.r, inverseTonemappedColor.r, sPP);
	PostInverseTonemapByChannel(tmParams.inputColor.g, tonemappedColor.g, inverseTonemappedColor.g, sPP);
	PostInverseTonemapByChannel(tmParams.inputColor.b, tonemappedColor.b, inverseTonemappedColor.b, sPP);

	if (INVERT_TONEMAP_TYPE > 0)
	{
		// If we only inverted highlights, the mid gray in and out should follow the same scale of the highlightd in/out change, otherwise the curves wouldn't connect.
		// In the extremely unlikely case that "midGrayOut" was higher than "minHighlightsColorOut", this calculaton should still be ok.
		midGrayOut = lerp(midGrayOut, midGrayIn * (minHighlightsColorOut / minHighlightsColorIn), localSDRTonemapHDRStrength);
		// Shift back to the original linear color if we want to ignore the SDR tonemapper
		if (localSDRTonemapHDRStrength != 1.f)
		{
			inverseTonemappedColor = lerp(tmParams.inputColor, inverseTonemappedColor, localSDRTonemapHDRStrength);
			minHighlightsColorOut = lerp(minHighlightsColorIn, minHighlightsColorOut, localSDRTonemapHDRStrength);
		}
	}

	const float midGrayScale = midGrayOut / midGrayIn;

	// Bring back the color to the same range as SDR by matching the mid gray level.
	inverseTonemappedColor /= midGrayScale;
	minHighlightsColorOut  /= midGrayScale;

	float3 inverseTonemappedPostProcessedColor;
	const bool restorePostProcessForceKeepHue = HDR_POST_PROCESS_TYPE == 1 || HDR_POST_PROCESS_TYPE == 3; // If true, we force keeping the LUT hue to make sure they are always applied "correctly" (this actually can often look worse though)
#if HDR_POST_PROCESS_TYPE == 0 || HDR_POST_PROCESS_TYPE == 1
	inverseTonemappedPostProcessedColor = RestorePostProcess(inverseTonemappedColor, tonemappedColor, params.finalSDRColor, restorePostProcessForceKeepHue);
#else // HDR_POST_PROCESS_TYPE

#if defined(APPLY_CINEMATICS)
	float prePostProcessColorLuminance;
	inverseTonemappedPostProcessedColor = lerp(inverseTonemappedColor, PostProcess(inverseTonemappedColor, prePostProcessColorLuminance), PostProcessStrength);
#else
	inverseTonemappedPostProcessedColor = inverseTonemappedColor;
#endif // APPLY_CINEMATICS

	const bool strictLUTApplication = (HDR_POST_PROCESS_TYPE == 5) ? HdrDllPluginConstants.StrictLUTApplication : (HDR_POST_PROCESS_TYPE == 4);

#if defined(APPLY_MERGED_COLOR_GRADING_LUT)
	if (strictLUTApplication)
	{
		float3 unusedNonGammaCorrectedColor; 
		ApplyColorGrading(inverseTonemappedPostProcessedColor, unusedNonGammaCorrectedColor, params.psInput.TEXCOORD);
	}
	else
#endif // APPLY_MERGED_COLOR_GRADING_LUT
	{
		inverseTonemappedPostProcessedColor = RestorePostProcess(inverseTonemappedPostProcessedColor, params.preLUTColor, params.finalSDRColor, restorePostProcessForceKeepHue);
	}

#endif // HDR_POST_PROCESS_TYPE

#if 0 // Enable this if you want the highlights shoulder start to be affected by post processing. It doesn't seem like the right thing to do and having it off works just fine.
	minHighlightsColorOut = RestorePostProcess(minHighlightsColorOut, tonemappedColor, params.finalSDRColor); // NOTE: this is broken since refactoring the RestorePostProcess() logic
#endif

	params.outputColor = inverseTonemappedPostProcessedColor;
	ApplyUserSettingExtendGamut(params.outputColor);
	ApplyUserSettingSaturation(params.outputColor);
	ApplyUserSettingContrast(params.outputColor);

	params.outputColor *= paperWhite;
	minHighlightsColorOut *= paperWhite;

	const float maxOutputLuminance = HdrDllPluginConstants.HDRPeakBrightnessNits / WhiteNits_sRGB;
	// Never compress highlights before the top 2/3 of the image (the actual ratio is based on a user param), even if it means we have two separate mid tones sections,
	// one from the SDR tonemapped and one pure linear (hopefully the discontinuous curve won't be noticeable on gradients).
	const float highlightsModulationPow = HdrDllPluginConstants.ToneMapperHighlights >= 0.5f ? linearNormalization(HdrDllPluginConstants.ToneMapperHighlights, 0.5f, 1.f, 1.f / 3.f, 1.f) : linearNormalization(HdrDllPluginConstants.ToneMapperHighlights, 0.0f, 0.5f, 0.f, 1.f / 3.f);
	float highlightsShoulderStart = max(maxOutputLuminance * highlightsModulationPow, minHighlightsColorOut);
	highlightsShoulderStart = (INVERT_TONEMAP_TYPE > 0) ? lerp(0.f, highlightsShoulderStart, localSDRTonemapHDRStrength) : 0.f;

	params.outputColor = DICETonemap(params.outputColor, maxOutputLuminance, highlightsShoulderStart, HDRHighlightsModulation);
}

void ApplySDROutputTransforms(inout float3 Color)
{
#if !SDR_LINEAR_INTERMEDIARY
	// Note that gamma was never applied if LUTs were disabled, but we don't care about that as the affected shaders permutations were never used
	#if SDR_USE_GAMMA_2_2
		Color = pow(Color, 1.f / 2.2f);
	#else
		// Do sRGB gamma even if we'd be playing on gamma 2.2 screens, as the game was already calibrated for 2.2 gamma despite using the wrong formula
		Color = gamma_linear_to_sRGB(Color);
	#endif // SDR_USE_GAMMA_2_2
#endif // SDR_LINEAR_INTERMEDIARY

#if CLAMP_INPUT_OUTPUT_TYPE >= 3
	// To keep the UI blending behaviour the same as vanilla SDR, we should clamp the image,
	// though if we don't, we possibly retain more detail in transparent UI background colors (hopefully nothing will be bright enough to ruin the UI readability).
	Color = saturate(Color);
#endif
}

void ApplyHDROutputTransforms(inout float3 Color)
{
#if CLAMP_INPUT_OUTPUT_TYPE >= 3
	// move into custom BT.2020 that is a little wider than BT.2020 and clamp to that
	Color = BT709_To_WBT2020(Color);
	Color = max(Color, 0.f);
	Color = WBT2020_To_BT709(Color);
#endif
}

bool ApplyDebugLUT(inout CompositeParams params)
{
#if defined(APPLY_MERGED_COLOR_GRADING_LUT) && DRAW_LUT
	static const uint DrawLUTTextureScale = 10u; // Pixel scale
	static const uint DrawLUTGradientScale = 30u; // Pixel scale
	bool drawnLUT = false;
	float3 LUTColor = DrawLUTTexture(params.psInput.SV_Position.xy, DrawLUTTextureScale, drawnLUT);
	if (!drawnLUT) // Avoids drawing on top of each other
	{
		LUTColor = DrawLUTGradients(params.psInput.SV_Position.xy, DrawLUTGradientScale, drawnLUT);
	}

	if (drawnLUT)
	{
		float3 outputColor = LUTColor;
		if (HdrDllPluginConstants.DisplayMode <= 0) // SDR
		{
#if SDR_USE_GAMMA_2_2 && !GAMMA_CORRECTION_IN_LUTS
			// Note: this should use PostGradingGammaCorrect() though the function checks for some unrelated params (e.g. "GAMMA_CORRECT_SDR_RANGE_ONLY" isn't acknowledged here)
			outputColor = lerp(outputColor, gamma_to_linear_mirrored(gamma_linear_to_sRGB_mirrored(outputColor), 2.2f), HdrDllPluginConstants.GammaCorrection);
#endif // SDR_USE_GAMMA_2_2 && !GAMMA_CORRECTION_IN_LUTS
			ApplySDROutputTransforms(outputColor);
		}
		else
		{
			outputColor *= HdrDllPluginConstants.HDRGamePaperWhiteNits / WhiteNits_sRGB;
			ApplyHDROutputTransforms(outputColor);
		}

		params.outputColor = outputColor;
		return true;
	}
#endif // APPLY_MERGED_COLOR_GRADING_LUT && DRAW_LUT
	return false;
}

void ApplyBloom(inout CompositeParams params)
{
#if defined(APPLY_BLOOM)
	float3 bloom = Bloom.Sample(Sampler0, params.psInput.TEXCOORD);
	params.outputColor += PcwHdrComposite.BloomMultiplier * bloom * (2.f * HdrDllPluginConstants.ToneMapperBloom);
#endif // APPLY_BLOOM
}

static const bool CLAMP_BETHESDA_ACES = false;

void ApplyACESFitted(inout CompositeParams params, inout ToneMapperParams tmParams)
{
	tmParams.outputSDRColor = ACESFitted(abs(tmParams.inputColor), CLAMP_BETHESDA_ACES) * sign(tmParams.inputColor);
	params.outputColor = tmParams.outputSDRColor;
}

void ApplyACESParametric(inout CompositeParams params, inout ToneMapperParams tmParams)
{
	tmParams.outputSDRColor  = ACESParametric(abs(tmParams.inputColor), CLAMP_BETHESDA_ACES, tmParams.acesParametricParams) * sign(tmParams.inputColor);
	params.outputColor = tmParams.outputSDRColor;
}

void ApplyHable(inout CompositeParams params, inout ToneMapperParams tmParams)
{
	// NOTE: do abs() * sign() to keep scRGB negative values, it works fine with Hable and (simplified) ACES as they work completely per channel.
	// Still, there seems to be no scRGB negative value coming from the game rendering, which means the rendering is fully Rec.709.
	// This operation will force an input of 0 to return an output of zero, which should always be the case with Hable anyway.
	tmParams.outputSDRColor  = Hable(abs(tmParams.inputColor), tmParams.hableParams) * sign(tmParams.inputColor);
	params.outputColor = tmParams.outputSDRColor;
}

void ApplyDummyToneMap(inout CompositeParams params, inout ToneMapperParams tmParams)
{
	// noop
}

void ApplySDRBrightness(inout float3 Color)
{
#if ENABLE_TONEMAP
	// The dll makes sure "SDRSecondaryBrightness" is 1 when we are in HDR.
	// NOTE: this can produce values beyond 1, as Oklab isn't guaranteed to output colors within 0-1.
	if (HdrDllPluginConstants.SDRSecondaryBrightness != 1.f)
	{
		float3 oklabColor = linear_srgb_to_oklab(Color);
		// We make sure this doesn't have negative brightness with abs()*sign() (it might have been very unlikely anyway).
		// Note that this can generate rgb values beyond 1 which will then be clipped, though it doesn't happen enough for it to be a problem.
		oklabColor[0] = pow(abs(oklabColor[0]), linearNormalization(HdrDllPluginConstants.SDRSecondaryBrightness, 0.f, 2.f, 1.25f, 0.75f)) * sign(oklabColor[0]);
		Color = oklab_to_linear_srgb(oklabColor);
	}
#endif // ENABLE_TONEMAP
}

[RootSignature(ShaderRootSignature)]
PSOutput PS(PSInput psInput) // Main Entrypoint
{
	// Linear HDR color straight from the renderer (possibly with exposure pre-applied to it, assuming the game has some auto exposure mechanism)
	float3 renderedColor = InputColorTexture.Load(int3(int2(psInput.SV_Position.xy), 0));

#if CLAMP_INPUT_OUTPUT_TYPE >= 4
	// Remove any negative value caused by using R16G16B16A16F buffers (originally this was R11G11B10F, which has no negative values).
	// Doing gamut mapping, or keeping the colors outside of BT.709 doesn't seem to be right, as they seem to be just be accidentally coming out of some shader math.
	renderedColor = max(renderedColor, 0.f);
#endif // CLAMP_INPUT_OUTPUT_TYPE

	CompositeParams params =
	{
		psInput,
		renderedColor, // renderedColor
		renderedColor, // outputColor
		renderedColor, // preLUTColor
		renderedColor, // postLUTColor
		renderedColor, // finalSDRColor
	};

#if DEVELOPMENT
	if (ApplyDebugLUT(params))
		return GetPSOutput(params.outputColor);
#endif

	ApplyBloom(params);

#if DRAW_TONEMAPPER
	DrawToneMapperParams dtmParams = DrawToneMapperStart(params);
#endif

	const float tmParamsInputColorLuminance = Luminance(params.outputColor);
	ACESParametricParams acesParametricParams;
	HableParams hableParams;
	ToneMapperParams tmParams =
	{
		params.outputColor, tmParamsInputColorLuminance,
		params.outputColor, tmParamsInputColorLuminance,
		params.outputColor, tmParamsInputColorLuminance,
		acesParametricParams,
		hableParams
	};

#if ENABLE_TONEMAP
	switch(HdrDllPluginConstants.ToneMapperType)
	{
		case 0:
		default:
			switch (TONE_MAPPER_ENUM)
			{
				case 1:     ApplyACESFitted(params, tmParams); break;
				case 2: ApplyACESParametric(params, tmParams); break;
				case 3:          ApplyHable(params, tmParams); break;
				default:  ApplyDummyToneMap(params, tmParams);
			}
			break;
		#if HDR_TONE_MAPPER_ENABLED
		case 1:     ApplyOpenDRTToneMap(params, tmParams); break;
		#endif
	}
#endif // ENABLE_TONEMAP

	const bool strictLUTApplication = (HDR_POST_PROCESS_TYPE == 5) ? HdrDllPluginConstants.StrictLUTApplication : (HDR_POST_PROCESS_TYPE == 4); // Vanilla+ TM
	bool needsSDRPostProcess = !strictLUTApplication || HdrDllPluginConstants.DisplayMode <= 0;
#if HDR_TONE_MAPPER_ENABLED
	if (HdrDllPluginConstants.ToneMapperType > 0)
		needsSDRPostProcess = true;
#endif
	if (needsSDRPostProcess)
	{
		ApplyCinematics(params);
		params.preLUTColor = params.outputColor;

		ApplyColorGrading(params);
		params.finalSDRColor = params.outputColor;
	}
	else
	{
		params.preLUTColor = params.outputColor;
		params.postLUTColor = params.outputColor;
		params.finalSDRColor = params.outputColor;
	}

	if (HdrDllPluginConstants.DisplayMode > 0) // HDR
	{
#if ENABLE_TONEMAP
		switch(HdrDllPluginConstants.ToneMapperType)
		{
			default:
			case 0: ApplySDRToneMapperHDRUpgrade(params, tmParams); break;
			#if HDR_TONE_MAPPER_ENABLED
			case 1:       ApplyOpenDRTHDRUpgrade(params, tmParams); break;
			#endif
		}
#else
		params.outputColor *= HdrDllPluginConstants.HDRGamePaperWhiteNits / ReferenceWhiteNits_BT2408; // Don't use "HDRGamePaperWhiteNits" directly as it'd be too bright on an untonemapped image
#endif
#if DRAW_TONEMAPPER
		DrawToneMapperEnd(params, dtmParams);
#endif
		ApplyHDROutputTransforms(params.outputColor);
	}
	else // SDR
	{
		ApplySDRBrightness(params.outputColor);
		// If we allow out of gamut colors (e.g. colors beyond the 0-1 range, so chromas and brightnesses that are not available in Rec.709),
		// allow users to change the saturation and contrast
		if (CLAMP_INPUT_OUTPUT_TYPE == 1)
		{
			ApplyUserSettingSaturation(params.outputColor);
#if HDR_TONE_MAPPER_ENABLED
			// User contrast is already baked in the DRT TM
			if (HdrDllPluginConstants.ToneMapperType == 0)
#endif
			{
				ApplyUserSettingContrast(params.outputColor);
			}
		}
#if DRAW_TONEMAPPER
		DrawToneMapperEnd(params, dtmParams);
#endif
		ApplySDROutputTransforms(params.outputColor);
	}

	return GetPSOutput(params.outputColor);
}