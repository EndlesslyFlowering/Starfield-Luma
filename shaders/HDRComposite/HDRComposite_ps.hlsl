#include "../shared.hlsl"
#include "../color.hlsl"
#include "../math.hlsl"
#include "RootSignature.hlsl"

// These are defined at compile time (shaders permutations),
// they are generally all on by default, you can undefine them manually below if necessary.
//#define APPLY_BLOOM
//#define APPLY_TONEMAPPING
//#define APPLY_CINEMATICS // this is post processing
//#define APPLY_MERGED_COLOR_GRADING_LUT

// This disables most other features (post processing/cinematics, LUTs, ...)
#define ENABLE_TONEMAP 1
// 0 disable contrast adjustment
// 1 original (weak, generates values beyond 0-1 which then might get clipped)
// 2 improved (looks more natural, avoids values below 0, but will overshoot beyond 1 more often, and will raise blacks)
// 3 Sigmoidal inspired and biases contrast increases towards the lower and top end
//   (optimisation left if "contrastIntensity" doesn't go below 1)
#define POST_PROCESS_CONTRAST_TYPE (FORCE_VANILLA_LOOK ? 1 : 3)
#define ENABLE_LUT 1
// LUTs are too low resolutions to resolve gradients smoothly if the LUT color suddenly changes between samples
#define ENABLE_LUT_TETRAHEDRAL_INTERPOLATION (FORCE_VANILLA_LOOK ? 0 : 1)
//TODO: WIP
#define ENABLE_LUT_EXTRAPOLATION (FORCE_VANILLA_LOOK ? 0 : 0)
#define ENABLE_REPLACED_TONEMAP 1
// Only invert highlights, which helps conserve the SDR filmic look (shadow crush) and altered colors.
// The alternative is to keep the linear space image tonemapped by the lightweight DICE tonemapper,
// or to replicate the SDR tonemapper by luminance, though both would alter the look too much and break some scenes.
#define INVERT_TONEMAP_HIGHLIGHTS_ONLY true
// If we are running in HDR, and we are keeping the SDR tonemapped shadow and midtones ("INVERT_TONEMAP_HIGHLIGHTS_ONLY" true),
// then if this is true, we replace the SDR tonemapped image with one tonemapped by channel instead than by luminance, to maintain more saturation.
// 0 per channel (also fallback)
// 1 on the luminance
// 2 in ICtCp
#define HDR_TONEMAP_TYPE 2
// Note: this could cause a disconnect in gradients, as LUTs shift colors by channel, not by luminance.
// It also dampens colors, making them darker and less saturation, especially bright colors.
#define HDR_INVERT_SDR_TONEMAP_BY_LUMINANCE 0
#define DRAW_LUT 0


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

static const float SDRTonemapHDRStrength = 1.f;
static const float PostProcessStrength = 1.f;
// 0 Ignored, 1 ACES Reference, 2 ACES Custom, 3 Hable, 4+ Disable tonemapper
static const uint ForceTonemapper = 0;
// 1 is neutral. Suggested range 0.5-1.5 though 1 is heavily suggested.
static const float HDRHighlightsModulation = 1.f;

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
	Color = (Color * (modA * Color + ACES_b))
	      / ((Color * (ACES_c * Color + ACES_d)) + modE);

	return Clamp ? saturate(Color) : Color;
}

// ACESFilm by Krzysztof Narkowicz (https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/)
// (color * ((a * color) + b)) / (color * ((c * color) + d) + e)
template<class T>
T ACESReference(
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
	inout float  modE,
	inout float  modA)
{
	const float AcesParam0 = PerSceneConstants[3266u].x; // Constant is usually 11.2
	const float AcesParam1 = PerSceneConstants[3266u].y; // Constant is usually 0.022

	modE = AcesParam1;
	modA = ((0.56f / AcesParam0) + ACES_b) + (AcesParam1 / (AcesParam0 * AcesParam0));

	return ACES(Color, Clamp, modE, modA);
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
T ACESReference_Inverse(T Color)
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
	const float toeLength        =   pow(saturate(PerSceneConstants[3266u].w), 2.2f); // Constant is usually 0.3
	const float toeStrength      =       saturate(PerSceneConstants[3266u].z); // Constant is usually 0.5
	const float shoulderLength   = clamp(saturate(PerSceneConstants[3267u].y), EPSILON, BTHCNST); // Constant is usually 0.8
	const float shoulderStrength =            max(PerSceneConstants[3267u].x, 0.f); // Constant is usually 9.9
	const float shoulderAngle    =       saturate(PerSceneConstants[3267u].z); // Constant is usually 0.3

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

// Applies exponential "Photographic" luminance compression
float RangeCompress(float x)
{
	return 1.f - exp(-x);
}

float LuminanceCompress(
	float Channel,
	float TargetCllInPq,
	float ShoulderStartInPq)
{
	return (TargetCllInPq - ShoulderStartInPq)
	     * RangeCompress((Channel       - ShoulderStartInPq) /
	                     (TargetCllInPq - ShoulderStartInPq))
	     + ShoulderStartInPq;
}

// Tonemapper inspired from DICE. Can work by luminance to maintain hue.
// "HighlightsShoulderStart" should be between 0 and 1. Determines where the highlights curve (shoulder) starts. Leaving at zero for now as it's a simple and good looking default.
float3 DICETonemap(
	float3 Color,
	float  MaxOutputLuminance,
	float  HighlightsShoulderStart = 0.f,
	float  HighlightsModulationPow = 1.f)
{
#if HDR_TONEMAP_TYPE == 1

	const float sourceLuminance = Luminance(Color);
	if (sourceLuminance > 0.0f)
	{
		const float compressedLuminance = luminanceCompress(sourceLuminance, MaxOutputLuminance, HighlightsShoulderStart, FLT_MAX, HighlightsModulationPow);
		Color *= compressedLuminance / sourceLuminance;
	}
	return Color;

#elif HDR_TONEMAP_TYPE == 2

	//optimisation needed to not execute this for every pixel...
	static const float TargetCllInPq     = Linear_to_PQ(MaxOutputLuminance, PQMaxWhitePoint);
	//hardcode to 0.5 for now as that gets better results
	static const float ShoulderStartInPq = Linear_to_PQ(MaxOutputLuminance * 0.5, PQMaxWhitePoint);

	//to L'M'S' and normalize to 1 = 10000 nits
	float3 PQ_LMS = Linear_to_PQ(BT709_to_LMS(Color / PQMaxWhitePoint));

	//Intensity
	float i1 = 0.5f * PQ_LMS.x + 0.5f * PQ_LMS.y;

	// return untouched Color if no tone mapping is needed
	if (i1 < ShoulderStartInPq)
	{
	  return Color;
	}
	else
	{
		float i2 = LuminanceCompress(i1, TargetCllInPq, ShoulderStartInPq);

		//saturation adjustment to blow out highlights
		float minI = min((i1 / i2), (i2 / i1));

		//to L'M'S'
		PQ_LMS = ICtCp_to_PQ_LMS(float3(i2,
			                              dot(PQ_LMS, PQ_LMS_2_ICtCp[1]) * minI,
			                              dot(PQ_LMS, PQ_LMS_2_ICtCp[2]) * minI));

		//to LMS
		float3 LMS = max(PQ_to_Linear(PQ_LMS), 0.f);
		//to RGB
		return LMS_to_BT709(LMS) * PQMaxWhitePoint;
	}

#else

	Color.r = luminanceCompress(Color.r, MaxOutputLuminance, HighlightsShoulderStart, FLT_MAX, HighlightsModulationPow);
	Color.g = luminanceCompress(Color.g, MaxOutputLuminance, HighlightsShoulderStart, FLT_MAX, HighlightsModulationPow);
	Color.b = luminanceCompress(Color.b, MaxOutputLuminance, HighlightsShoulderStart, FLT_MAX, HighlightsModulationPow);
	return Color;

#endif
}

// don't set this above 1 as it will break the curve (turns into a double S curve instead of a single one)
// below 1 it increases the amount of additional contrast being applied
// only change this for testing
#define C 1

static const float den = log2(C + 1.f);

// bias towards smaller numbers
void Log2Adjust(inout float Channel)
{
#if (C != 1)
	Channel = log2(Channel * c + 1.f)
	        / den;
	return;
#else
	Channel = log2(Channel + 1.f);
	return;
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
	[flatten]
	if (Channel <= contrastMidPoint)
	{
		Channel *= normalizationFactorLower;
		// doing this for contrastIntensity below 1 greatly desaturates compared to not doing this
		// look into if contrastIntensity ever goes below 1
		// and remove this check if it does not
		if (contrastIntensity > 1.f)
		{
			Log2Adjust(Channel);
		}
		Channel = pow(Channel, contrastIntensity)
		        / normalizationFactorLower;
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
		Channel = (1.f - pow(Channel, contrastIntensity))
		        / normalizationFactorUpper + contrastMidPoint;
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
	Color = ((Color - ColorLuminance) * hableSaturation) + ColorLuminance;

	// Blend in another color based on the luminance.
	Color += lerp(float3(0.f, 0.f, 0.f), ColorLuminance * highlightsColorFilter.rgb, highlightsColorFilter.a);
	Color *= brightnessMultiplier;

#if POST_PROCESS_CONTRAST_TYPE == 1

	// Contrast adjustment (shift the colors from 0<->1 to (e.g.) -0.5<->0.5 range, multiply and shift back).
	// The higher the distance from the contrast middle point, the more contrast will change the color.
	// This generates negative colors for contrast > 1, and LUT's can't take them, unless they have "ENABLE_LUT_EXTRAPOLATION"
	Color = ((Color - contrastMidPoint) * contrastIntensity) + contrastMidPoint;

#elif POST_PROCESS_CONTRAST_TYPE == 2

	// Do abs() to avoid negative power, even if it doesn't make 100% sense, these formulas are fine as long as they look good
	Color = pow(abs(Color) / contrastMidPoint, contrastIntensity) * contrastMidPoint * sign(Color);

#elif POST_PROCESS_CONTRAST_TYPE == 3

	if (contrastIntensity != 1.f) // worth to do performance wise
	{
		float cIn = contrastIntensity;
		// adjustment to match native better and make the curve be an S curve (too low intensity makes it a double S curve)
		// only do them when contrastIntensity is above 1 because 1 is neutral (no adjustment)
		// below 1 it matches native nicely (though idk if contrast is ever lowered)
		if (contrastIntensity > 1.f)
		{
			cIn = contrastIntensity * (4.f / 3.f);
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

// In/Out linear space
float3 GradingLUT(float3 color, float2 uv)
{
// Overall, we don't really care about maintaining the wrong sRGB gamma formula as it broke LUT mapping, causing clipping, and just looked bad.
#if !FORCE_VANILLA_LOOK
	const float3 LUTCoordinates = gamma_linear_to_sRGB(color);
#else
	// Read gamma ini value, defaulting at 2.4 (makes little sense)
	float inverseGamma = 1.f / (max(SharedFrameData.Gamma, 0.001f));
	// Weird linear -> sRGB conversion that clips values just above 0.
	const float3 LUTCoordinates = max(gamma_linear_to_sRGB_Bethesda_Optimized(color, inverseGamma), 0.f); // Does "max()" is probably unnecessary as LUT sampling is already clamped.
#endif // FORCE_VANILLA_LOOK

#if ENABLE_LUT_TETRAHEDRAL_INTERPOLATION
	float3 LUTColor = TetrahedralInterpolation(LUTTexture, LUTCoordinates);
#else
	float3 LUTCoordinatesScale = (LUT_SIZE - 1.0f) / LUT_SIZE; // Also "1-(1/LUT_SIZE)"
	float3 LUTCoordinatesOffset = 1.0f / (2.0f * LUT_SIZE); // Also "(1/LUT_SIZE)/2"
	float3 LUTColor = LUTTexture.Sample(Sampler0, (LUTCoordinates * LUTCoordinatesScale) + LUTCoordinatesOffset);
#endif // ENABLE_LUT_TETRAHEDRAL_INTERPOLATION

#if LUT_MAPPING_TYPE == 2
	LUTColor = oklab_to_linear_srgb(LUTColor);
	if (HdrDllPluginConstants.DisplayMode <= 0 || (bool)FORCE_SDR_LUTS)
	{
		LUTColor = saturate(LUTColor);
	}
#elif LUT_MAPPING_TYPE == 0
	// We always work in linear space so convert to it.
	// We never acknowledge the original wrong gamma function here (we don't really care).
	LUTColor = gamma_sRGB_to_linear(LUTColor);
#endif // LUT_MAPPING_TYPE

#if ENABLE_LUT_EXTRAPOLATION //TODO: does it even make sense given that "LUTCoordinates" is in sRGB? Negative numbers would be fkep up
	// Extrapolate colors beyond the 0-1 input coordinates by finding the closest color to the LUT cube edge,
	// and calculating the "color change" acceleration in that direction.
	const float3 LUTCenterCoordinates = 0.5f;
	//TODO: this should probably take into account the direction of our color and only move to the center of the closest 3D LUT texel
	const float colorCenteringOffset = length((LUT_SIZE / 2.f) - 1.f) / length(LUT_SIZE / 2.f);
	const float3 LUTCenteredCoordinates = ((saturate(LUTCoordinates) - LUTCenterCoordinates) * colorCenteringOffset) + LUTCenterCoordinates;

#if ENABLE_LUT_TETRAHEDRAL_INTERPOLATION
	float3 LUTCenterColor = TetrahedralInterpolation(LUTTexture, LUTCenteredCoordinates);
#else
	float3 LUTCenterColor = LUTTexture.Sample(Sampler0, LUTCenteredCoordinates * (1.f - (1.f / LUT_SIZE)) + ((1.f / LUT_SIZE) / 2.f));
#endif // ENABLE_LUT_TETRAHEDRAL_INTERPOLATION

	// Shift the color in the opposite direction of the centered one, by the ratio between the centered and the extra/external offset
	LUTColor = lerp(LUTColor, LUTCenterColor, -abs(LUTCoordinates - saturate(LUTCoordinates)) / abs(saturate(LUTCoordinates) - LUTCenteredCoordinates));
	//TODO: clip negative luminance colors?
#endif // ENABLE_LUT_EXTRAPOLATION

	// "ColorGradingStrength" is similar to "AdditionalNeutralLUTPercentage" from the LUT mixing shader, though this is more precise as it skips the precision loss induced by a neutral LUT
	const float LUTMaskAlpha = (1.f - LUTMaskTexture.Sample(Sampler0, uv).x) * HdrDllPluginConstants.ColorGradingStrength;
	LUTColor = lerp(color, LUTColor, LUTMaskAlpha);

	return LUTColor;
}

#endif // APPLY_MERGED_COLOR_GRADING_LUT

// Takes a linear space untonemapped HDR color and a linear space tonemapped SDR color.
float3 RestorePostProcess(float3 inverseTonemappedColor, float3 postProcessColorRatio, float3 postProcessColorOffset, float3 tonemappedColor)
{
	float3 postProcessedRatioColor = inverseTonemappedColor;
	float3 postProcessedOffsetColor = inverseTonemappedColor;
	postProcessedRatioColor *= postProcessColorRatio;
	postProcessedOffsetColor += postProcessColorOffset;
// Near black, we prefer using the "offset" (sum) pp restoration method, as otherwise any raised black would not work,
// for example if any zero was shifted to a more raised color, "postProcessColorRatio" would not be able to replicate that shift due to a division by zero.
// Note: in case "INVERT_TONEMAP_HIGHLIGHTS_ONLY" was false, we might want to test the "postProcessedOffsetColor" blend in range more carefully.
// For the "INVERT_TONEMAP_HIGHLIGHTS_ONLY" true case, this seems to work great, with the "MaxShadowsColor" setting that is there, anything more will raise colors.
#if 1
	return lerp(postProcessedOffsetColor, postProcessedRatioColor, saturate(tonemappedColor / MaxShadowsColor));
#else // Doing the branching this way might not be so good, as near black colors could still end up with crazy value due to divisions between tiny values. Might not work with "HDR_TONEMAP_TYPE == 1" (tonemap by luminance)
	return select(tonemappedColor == 0.f, postProcessedOffsetColor, postProcessedRatioColor);
#endif
}

void SDRTonemapByLuminancePostProcessing(
	inout float                   InputChannel,
	inout float                   TonemappedChannel,
	inout float                   InverseTonemappedColorChannel,
	const SDRTonemapByLuminancePP sPP)
{
#if 1 // Directly use the input/source non tonemapped color for comparisons against the highlights, hopefully this won't cause any gradients disconnects
	const bool isHighlight = InputChannel >= sPP.minHighlightsColorOut;
#elif 0
	const bool isHighlight = (sPP.needsInverseTonemap ? InverseTonemappedColorChannel : InputChannel) >= sPP.minHighlightsColorOut;
#else // The least precise of them all
	const bool isHighlight = TonemappedChannel >= sPP.minHighlightsColorIn;
#endif
	// Restore the SDR tonemapped colors for non highlights,
	// We scale all non highlights by the scale the smallest (first) highlight would have, so we keep the curves connected
	if (INVERT_TONEMAP_HIGHLIGHTS_ONLY && !isHighlight)
	{
		InverseTonemappedColorChannel = TonemappedChannel * (sPP.minHighlightsColorOut / sPP.minHighlightsColorIn);
	}
	// Restore any highlight clipped or just crushed by the direct tonemappers (Hable does that).
	if (sPP.needsInverseTonemap && isHighlight)
	{
		InverseTonemappedColorChannel = InputChannel;
	}
}

#if defined(APPLY_MERGED_COLOR_GRADING_LUT) && DRAW_LUT
float3 DrawLUTTexture(float2 PixelPosition, uint PixelScale, inout bool DrawnLUT) {
	const uint2 LUTPixelPosition2D = PixelPosition / PixelScale;
	const uint3 LUTPixelPosition3D = uint3(LUTPixelPosition2D.x % LUT_SIZE_UINT, LUTPixelPosition2D.y, LUTPixelPosition2D.x / LUT_SIZE_UINT);
	if (!any(LUTPixelPosition3D < 0u) && !any(LUTPixelPosition3D > LUT_MAX_UINT))
	{
		DrawnLUT = true;
		float3 loadedColor = LUTTexture.Load(uint4(LUTPixelPosition3D, 0)).rgb;
#if LUT_MAPPING_TYPE == 2
		loadedColor = oklab_to_linear_srgb(loadedColor);
#elif LUT_MAPPING_TYPE == 0
		loadedColor = gamma_sRGB_to_linear(loadedColor);
#endif // LUT_MAPPING_TYPE
		//TODO1: this (LUTPixelPosition3D) and the one underneath are probably broken as we need to linearize the neutral LUT color?
		loadedColor = lerp(float3(LUTPixelPosition3D) / float(LUT_MAX_UINT), loadedColor, HdrDllPluginConstants.ColorGradingStrength); // Blend in neutral LUT
		return loadedColor;
	}
	return 0;
}

float3 DrawLUTGradients(float2 PixelPosition, uint PixelScale, inout bool DrawnLUT) {
	static const uint DrawLUTSquareSize = (LUT_SIZE_UINT * LUT_SIZE_UINT * PixelScale);
	float width;
	float height;
	InputColorTexture.GetDimensions(width, height);
	if (PixelPosition.y < (height - DrawLUTSquareSize))
		return 0;

	const uint2 position = uint2(PixelPosition.x / PixelScale, (PixelPosition.y - (height - DrawLUTSquareSize)) / PixelScale);
	uint xPoint = position.x / LUT_SIZE_UINT;
	uint yPoint = position.y / LUT_SIZE_UINT;
	// NOTE: this is extremely slow.
	if ((xPoint <= LUT_MAX_UINT && yPoint >=0 && yPoint <= LUT_MAX_UINT))
	{
		DrawnLUT = true;
		float3 xyz;
		uint row = 0u;
		float coord = float(xPoint) / float(LUT_MAX_UINT);
		float inverse = float(LUT_MAX_UINT - xPoint) / float(LUT_MAX_UINT);
		if (yPoint == row++) xyz = float3(coord  , coord  , coord  ); // Black => White

		else if (yPoint == row++) xyz = float3(coord  , 0      , 0      ); // Black => Red
		else if (yPoint == row++) xyz = float3(0      , coord  , 0      ); // Black => Green
		else if (yPoint == row++) xyz = float3(0      , 0      , coord  ); // Black => Blue

		else if (yPoint == row++) xyz = float3(0      , coord  , coord  ); // Black => Cyan
		else if (yPoint == row++) xyz = float3(coord  , coord  , 0      ); // Black => Yellow
		else if (yPoint == row++) xyz = float3(coord  , 0      , coord  ); // Black => Magenta

		else if (yPoint == row++) xyz = float3(1u     , coord  , coord  ); // Red to White
		else if (yPoint == row++) xyz = float3(coord  , 1u     , coord  ); // Green to White
		else if (yPoint == row++) xyz = float3(coord  , coord  , 1u     ); // Blue to White

		else if (yPoint == row++) xyz = float3(coord  , 1u     , 1u     ); // Cyan to White
		else if (yPoint == row++) xyz = float3(1u     , 1u     , coord  ); // Yellow to White
		else if (yPoint == row++) xyz = float3(1u     , coord  , 1u     ); // Magenta to White

		else if (yPoint == row++) xyz = float3(inverse, coord  , coord  ); // Red to Cyan
		else if (yPoint == row++) xyz = float3(coord  , inverse, coord  ); // Green to Magenta
		else if (yPoint == row++) xyz = float3(coord  , coord  , inverse); // Blue to Yellow

		float3 loadedColor = LUTTexture.Load(uint4(xyz.rgb * LUT_MAX_UINT, 0)).rgb;
#if LUT_MAPPING_TYPE == 2
		loadedColor = oklab_to_linear_srgb(loadedColor);
#elif LUT_MAPPING_TYPE == 0
		loadedColor = gamma_sRGB_to_linear(loadedColor);
#endif // LUT_MAPPING_TYPE
		loadedColor = lerp(xyz.rgb, loadedColor, HdrDllPluginConstants.ColorGradingStrength); // Blend in neutral LUT
		return loadedColor;
	}
	return 0;
}
#endif // APPLY_MERGED_COLOR_GRADING_LUT && DRAW_LUT

[RootSignature(ShaderRootSignature)]
PSOutput PS(PSInput psInput)
{
#if defined(APPLY_MERGED_COLOR_GRADING_LUT) && DRAW_LUT
	static const uint DrawLUTScale = 10u; // Pixel scale
	bool drawnLUT = false;
	float3 LUTColor = DrawLUTTexture(psInput.SV_Position.xy, DrawLUTScale, drawnLUT);
	if (!drawnLUT)
	{
		LUTColor = DrawLUTGradients(psInput.SV_Position.xy, DrawLUTScale / 5u, drawnLUT);
	}
	if (drawnLUT)
	{
		float3 outputColor = LUTColor;
		if (HdrDllPluginConstants.DisplayMode <= 0) // SDR
		{
			//TODO1: apply gamma correction here?
#if !SDR_LINEAR_INTERMEDIARY
#if SDR_USE_GAMMA_2_2
			outputColor = pow(outputColor, 1.f / 2.2f);
#else
			outputColor = gamma_linear_to_sRGB(outputColor);
#endif // SDR_USE_GAMMA_2_2
#endif // SDR_LINEAR_INTERMEDIARY
		}
		else
		{
			outputColor *= HdrDllPluginConstants.HDRGamePaperWhiteNits / WhiteNits_sRGB;
		}

		PSOutput psOutput;
		psOutput.SV_Target.rgb = outputColor;
		psOutput.SV_Target.a = 1.f;
		return psOutput;
	}
#endif

	// Linear HDR color straight from the renderer (possibly with exposure pre-applied to it, assuming the game has some auto exposure mechanism)
	float3 inputColor = InputColorTexture.Load(int3(int2(psInput.SV_Position.xy), 0));

#if CLAMP_INPUT_OUTPUT
	// Remove any negative value caused by using R16G16B16A16F buffers (originally this was R11G11B10F, which has no negative values).
	// Doing gamut mapping, or keeping the colors outside of BT.709 doesn't seem to be right, as they seem to be just be accidentally coming out of some shader math.
	inputColor = max(inputColor, 0.f);
#else
	if (Luminance(inputColor) < 0.f)
		inputColor = 0.f;
#endif // CLAMP_INPUT_OUTPUT

#if defined(APPLY_BLOOM)

	float3 bloom = Bloom.Sample(Sampler0, psInput.TEXCOORD);
	inputColor += PcwHdrComposite.BloomMultiplier * bloom;

#endif // APPLY_BLOOM

	float3 outputColor = inputColor;

	float3 tonemappedColor;
	float3 tonemappedByLuminanceColor;

#if !ENABLE_TONEMAP
	tonemappedColor = inputColor;
	tonemappedByLuminanceColor = inputColor;
	float3 tonemappedPostProcessedColor = tonemappedColor;
#else

	float acesParam_modE;
	float acesParam_modA;

	HableParams hableParams;

	const bool clampACES = false;

	int tonemapperIndex = ForceTonemapper > 0 ? ForceTonemapper : PcwHdrComposite.Tmo;

	const float untonemappedColorLuminance = Luminance(inputColor);
	float tonemappedColorLuminance;

	switch (tonemapperIndex)
	{
		case 1:
		{
			tonemappedColor          = ACESReference(inputColor, clampACES);
			tonemappedColorLuminance = ACESReference(untonemappedColorLuminance, clampACES);
		} break;

		case 2:
		{
			tonemappedColor          = ACESParametric(inputColor, clampACES, acesParam_modE, acesParam_modA);
			tonemappedColorLuminance = ACESParametric(untonemappedColorLuminance, clampACES, acesParam_modE, acesParam_modA);
		} break;

		case 3:
		{
			tonemappedColor          = Hable(inputColor, hableParams);
			tonemappedColorLuminance = Hable(untonemappedColorLuminance.xxx, hableParams).x; //TODO: make hable templatable
		} break;

		default:
		{
			tonemappedColor          = inputColor;
			tonemappedColorLuminance = untonemappedColorLuminance;
		} break;
	}

	tonemappedByLuminanceColor = inputColor * safeDivision(tonemappedColorLuminance, untonemappedColorLuminance);

#if defined(APPLY_CINEMATICS)
	float prePostProcessColorLuminance;
	float3 tonemappedPostProcessedColor = lerp(tonemappedColor, PostProcess(tonemappedColor, prePostProcessColorLuminance), PostProcessStrength);
#else
	float3 tonemappedPostProcessedColor = tonemappedColor; // No need to do anything (not even a saturate here)
#endif //APPLY_CINEMATICS

#endif // ENABLE_TONEMAP

	float3 tonemappedPostProcessedGradedColor = tonemappedPostProcessedColor;

#if defined(APPLY_MERGED_COLOR_GRADING_LUT) && ENABLE_TONEMAP

#if ENABLE_LUT
	tonemappedPostProcessedGradedColor = GradingLUT(tonemappedPostProcessedColor, psInput.TEXCOORD);
#endif // ENABLE_LUT

#if GAMMA_CORRECT_SDR_RANGE_ONLY
	const float3 tonemappedPostProcessedGradedSDRColors = saturate(tonemappedPostProcessedGradedColor);
	const float3 tonemappedPostProcessedGradedSDRExcessColors = tonemappedPostProcessedGradedColor - tonemappedPostProcessedGradedSDRColors;
	tonemappedPostProcessedGradedColor = tonemappedPostProcessedGradedSDRColors;
#endif // GAMMA_CORRECT_SDR_RANGE_ONLY

// Do this even if "ENABLE_LUT" is false, for consistency
#if SDR_USE_GAMMA_2_2 && (!ENABLE_LUT || !GAMMA_CORRECTION_IN_LUTS) //TODO1
	// This error was always built in the image if we assume Bethesda calibrated the game on gamma 2.2 displays.
	// If there's no color grading, we don't do this adjustment, as we assume the error was part of the LUTs setup, including on neutral LUTs
	// (this is not entirely true, but the world is too black with this adjustment if there's no color grading).
	tonemappedPostProcessedGradedColor = lerp(tonemappedPostProcessedGradedColor, pow(gamma_linear_to_sRGB(tonemappedPostProcessedGradedColor), 2.2f), HdrDllPluginConstants.ColorGradingStrength * HdrDllPluginConstants.GammaCorrection);
#endif // SDR_USE_GAMMA_2_2

	// The dll makes sure this is 1 when we are in HDR.
	if (HdrDllPluginConstants.SDRSecondaryBrightness != 1.f)
	{
		float3 oklabColor = linear_srgb_to_oklab(tonemappedPostProcessedGradedColor);
		oklabColor[0] = pow(oklabColor[0], linearNormalization(HdrDllPluginConstants.SDRSecondaryBrightness, 0.f, 2.f, 1.25f, 0.75f));
		tonemappedPostProcessedGradedColor = oklab_to_linear_srgb(oklabColor);
	}

#if GAMMA_CORRECT_SDR_RANGE_ONLY
	tonemappedPostProcessedGradedColor += tonemappedPostProcessedGradedSDRExcessColors;
#endif // GAMMA_CORRECT_SDR_RANGE_ONLY

#endif // APPLY_MERGED_COLOR_GRADING_LUT

	const float3 finalOriginalColor = tonemappedPostProcessedGradedColor; // Final "original" (vanilla, ~unmodded) linear SDR color before output transform

#if ENABLE_TONEMAP && ENABLE_REPLACED_TONEMAP
	const bool SDRTonemapByLuminance = (bool)HDR_TONEMAP_TYPE && (bool)HDR_INVERT_SDR_TONEMAP_BY_LUMINANCE;
#if 1 // This is delicate and could make things worse, especially within "RestorePostProcess()", but without it, highlights have uncontiguos gradients that shift color (due to strong LUTs)
	if (SDRTonemapByLuminance)
	{
		tonemappedColor = tonemappedByLuminanceColor;
	}
#endif

	const float3 postProcessColorRatio = safeDivision(finalOriginalColor, tonemappedColor);
	const float3 postProcessColorOffset = finalOriginalColor - tonemappedColor;
#endif

	if (HdrDllPluginConstants.DisplayMode > 0) // HDR
	{
#if ENABLE_TONEMAP && ENABLE_REPLACED_TONEMAP

		const float paperWhite = HdrDllPluginConstants.HDRGamePaperWhiteNits / WhiteNits_sRGB;

		const float midGrayIn = MidGray;
		float midGrayOut = midGrayIn;

		float minHighlightsColorIn = MinHighlightsColor; // We consider highlight the last ~33% of perception SDR space
		float minHighlightsColorOut = minHighlightsColorIn;
#if DEVELOPMENT
		const float localSDRTonemapHDRStrength = 1.f - HdrDllPluginConstants.DevSetting01;
#else
		const float localSDRTonemapHDRStrength = SDRTonemapHDRStrength;
#endif
		// If true, we need to calculate the inverse tonemap
		const bool needsInverseTonemap = !INVERT_TONEMAP_HIGHLIGHTS_ONLY || localSDRTonemapHDRStrength != 1.f;

		float3 inverseTonemappedColor = needsInverseTonemap ? tonemappedColor : inputColor;

		// Restore a color very close to the original linear one (some information might get close in the direct tonemapper)
		switch (tonemapperIndex)
		{
			case 1:
			{
				if (needsInverseTonemap)
				{
					inverseTonemappedColor = ACESReference_Inverse(inverseTonemappedColor);
					midGrayOut             = ACESReference_Inverse(midGrayIn);
				}
				minHighlightsColorOut = ACESReference_Inverse(minHighlightsColorIn);
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
				// Setup highlights for Hable, we use the official param based highlights shoulder start for it, so that we switch tonemapper in the same place where the hable curve would change direction (or so I think)
				const float shoulderOutStart = max(hableParams.params.y0, hableParams.params.y1); // Check both toe and mid params for extra safety
				minHighlightsColorIn         = shoulderOutStart;

				if (needsInverseTonemap)
				{
					inverseTonemappedColor = Hable_Inverse(inverseTonemappedColor, hableParams);
					midGrayOut             = Hable_Inverse(midGrayIn, hableParams);
				}
#if 1 // Optimized and more "accurate"
				minHighlightsColorOut = hableParams.shoulderStart;
#else
				minHighlightsColorOut = Hable_Inverse(minHighlightsColorIn, hableParams);
#endif
			} break;

			default:
				break;
		}

		if (!SDRTonemapByLuminance)
		{
			SDRTonemapByLuminancePP sPP;

			sPP.minHighlightsColorIn  = minHighlightsColorIn;
			sPP.minHighlightsColorOut = minHighlightsColorOut;
			sPP.needsInverseTonemap   = needsInverseTonemap;

			SDRTonemapByLuminancePostProcessing(inputColor.r, tonemappedColor.r, inverseTonemappedColor.r, sPP);
			SDRTonemapByLuminancePostProcessing(inputColor.g, tonemappedColor.g, inverseTonemappedColor.g, sPP);
			SDRTonemapByLuminancePostProcessing(inputColor.b, tonemappedColor.b, inverseTonemappedColor.b, sPP);
		}
		else
		{
#if 1
			const bool isHighlight = untonemappedColorLuminance >= minHighlightsColorOut;
#else
			const bool isHighlight = (needsInverseTonemap ? Luminance(inverseTonemappedColor) : untonemappedColorLuminance) >= minHighlightsColorOut;
#endif
			if (INVERT_TONEMAP_HIGHLIGHTS_ONLY && !isHighlight)
			{
				inverseTonemappedColor = tonemappedByLuminanceColor * (minHighlightsColorOut / minHighlightsColorIn);
			}
			if (needsInverseTonemap && isHighlight)
			{
				inverseTonemappedColor = inputColor;
			}
		}

		if (INVERT_TONEMAP_HIGHLIGHTS_ONLY)
		{
			// If we only inverted highlights, the mid gray in and out should follow the same scale of the highlightd in/out change, otherwise the curves wouldn't connect.
			// In the extremely unlikely case that "midGrayOut" was higher than "minHighlightsColorOut", this calculaton should still be ok.
			midGrayOut = lerp(midGrayOut, midGrayIn * (minHighlightsColorOut / minHighlightsColorIn), localSDRTonemapHDRStrength);
			// Shift back to the original linear color if we want to ignore the SDR tonemapper
			if (localSDRTonemapHDRStrength != 1.f)
			{
				inverseTonemappedColor = lerp(inputColor, inverseTonemappedColor, localSDRTonemapHDRStrength);
				minHighlightsColorOut = lerp(minHighlightsColorIn, minHighlightsColorOut, localSDRTonemapHDRStrength);
			}
		}

		//TODO1 (add define and maybe move after "midGrayScale")
		// We do this before applying "midGrayScale" as otherwise the input values would be too low.
		if (HdrDllPluginConstants.DevSetting05 > 0.f)
		{
			inverseTonemappedColor = ExtendGamut(inverseTonemappedColor, HdrDllPluginConstants.DevSetting05);
		}

		const float midGrayScale = midGrayOut / midGrayIn;

		// Bring back the color to the same range as SDR by matching the mid gray level.
		inverseTonemappedColor /= midGrayScale;
		minHighlightsColorOut  /= midGrayScale;

		float3 inverseTonemappedPostProcessedColor = RestorePostProcess(inverseTonemappedColor, postProcessColorRatio, postProcessColorOffset, tonemappedColor);
#if 0 // Enable this if you want the highlights should start to be affected by post processing. It doesn't seem like the right thing to do and having it off works just fine.
		minHighlightsColorOut = RestorePostProcess(minHighlightsColorOut, postProcessColorRatio, postProcessColorOffset, tonemappedColor);
#endif

		// Secondary user driven saturation. This is already placed in LUTs but it's only applied on LUTs normalization (in HDR).
		float saturation = linearNormalization(HdrDllPluginConstants.HDRSaturation, 0.f, 2.f, 0.5f, 1.5f);
#if defined(APPLY_MERGED_COLOR_GRADING_LUT) && ENABLE_LUT
		saturation = lerp(saturation, 1.f, HdrDllPluginConstants.ColorGradingStrength * HdrDllPluginConstants.LUTCorrectionStrength);
#endif
		inverseTonemappedPostProcessedColor = Saturation(inverseTonemappedPostProcessedColor, saturation);

		// Secondary user driven contrast
		const float secondaryContrast = linearNormalization(HdrDllPluginConstants.HDRSecondaryContrast, 0.f, 2.f, 0.5f, 1.5f);
#if 0 // By luminance (no hue shift) (looks off)
		float inverseTonemappedPostProcessedColorLuminance = Luminance(inverseTonemappedPostProcessedColor);
		inverseTonemappedPostProcessedColor *= safeDivision(pow(inverseTonemappedPostProcessedColorLuminance / MidGray, secondaryContrast) * MidGray, inverseTonemappedPostProcessedColorLuminance);
#else // By channel (also increases saturation)
		inverseTonemappedPostProcessedColor = pow(abs(inverseTonemappedPostProcessedColor) / MidGray, secondaryContrast) * MidGray * sign(inverseTonemappedPostProcessedColor);
#endif

		inverseTonemappedPostProcessedColor *= paperWhite;
		minHighlightsColorOut *= paperWhite;

		const float maxOutputLuminance = HdrDllPluginConstants.HDRPeakBrightnessNits / WhiteNits_sRGB;
		// The highlights shoulder (compression) curve should never start beyond 33.33% of the max output brightness (found empircally)
		const float highlightsShoulderStart = INVERT_TONEMAP_HIGHLIGHTS_ONLY ? lerp(0.f, min(maxOutputLuminance * (1.f / 3.f), minHighlightsColorOut), localSDRTonemapHDRStrength) : 0.f;

		outputColor = DICETonemap(inverseTonemappedPostProcessedColor, maxOutputLuminance, highlightsShoulderStart, HDRHighlightsModulation);

#else // ENABLE_TONEMAP && ENABLE_REPLACED_TONEMAP

		outputColor = finalOriginalColor * (HdrDllPluginConstants.HDRGamePaperWhiteNits / ReferenceWhiteNits_BT2408); // Don't use "HDRGamePaperWhiteNits" directly as it'd be too bright on an untonemapped image

#endif // ENABLE_TONEMAP && ENABLE_REPLACED_TONEMAP

#if CLAMP_INPUT_OUTPUT
		outputColor = clamp(outputColor, 0.f, FLT16_MAX); // Avoid extremely high numbers turning into NaN in FP16
#endif // CLAMP_INPUT_OUTPUT
	}
	else // SDR
	{
		outputColor = finalOriginalColor;

#if !SDR_LINEAR_INTERMEDIARY
		// Note that gamma was never applied if LUTs were disabled, but we don't care about that as the affected shaders permutations were never used
#if SDR_USE_GAMMA_2_2
		outputColor = pow(outputColor, 1.f / 2.2f);
#else
		// Do sRGB gamma even if we'd be playing on gamma 2.2 screens, as the game was already calibrated for 2.2 gamma despite using the wrong formula
		outputColor = gamma_linear_to_sRGB(outputColor);
#endif // SDR_USE_GAMMA_2_2
#endif // SDR_LINEAR_INTERMEDIARY

#if CLAMP_INPUT_OUTPUT
		outputColor = saturate(outputColor);
#endif // CLAMP_INPUT_OUTPUT
	}

#if !CLAMP_INPUT_OUTPUT
	if (Luminance(outputColor) < 0.f) // Remove invalid colors
		outputColor = 0.f;
#endif // CLAMP_INPUT_OUTPUT

	PSOutput psOutput;
	psOutput.SV_Target.rgb = outputColor;
	psOutput.SV_Target.a = 1.f;
	return psOutput;
}
