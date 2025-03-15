#pragma once

#include "math.hlsl"

// This is technically more correct as true, though it's not guaranteed to look better.
// Note: this might start to look bad if any of the negative colors goes beyond 1 (which usually shouldn't happen with ~SDR colors)
// Note: can generate scRGB colors with negative luminance if there's negative scRGB values to begin with, at least if this is true (and maybe also if it's false?);
// either way we can snap them to black in that case, even if it doesn't always look as good as clipping them to AP0, it's "mathematically" correct
// Note: bring back "GAMMA_CORRECT_SDR_RANGE_ONLY" if this always stays false, as it was more optimized (it did clamps just once for the whole gamma correction pass)
static const bool ApplyGammaBelowZeroDefault = true;
// This should be true for correctness, but most calls to the functions that use it need it false, so for simplicity we left it to false.
static const bool ApplyGammaBeyondOneDefault = false;

// sRGB SDR white is meant to be mapped to 80 nits (not 100, even if some game engine (UE) and consoles (PS5) interpret it as such).
static const float WhiteNits_sRGB = 80.f;
static const float ReferenceWhiteNits_BT2408 = 203.f;

// SDR linear mid gray.
// This is based on the commonly used value, though perception space mid gray (0.5) in sRGB or Gamma 2.2 would theoretically be ~0.2155 in linear.
static const float MidGray = 0.18f;

// Start of the highlights shoulder (empirical)
static const float MinHighlightsColor = pow(2.f / 3.f, 2.2f);
static const float MaxShadowsColor = pow(1.f / 3.f, 2.2f);

// SMPTE ST 2084 (Perceptual Quantization) is only defined until this amount of nits.
// This is also the max each color channel can have in HDR10.
static const float PQMaxNits = 10000.0f;
// SMPTE ST 2084 is defined as using BT.2020 white point.
static const float PQMaxWhitePoint = PQMaxNits / WhiteNits_sRGB;

// These have been calculated to be as accurate as possible
static const float3x3 BT709_2_BT2020 = {
	0.627403914928436279296875f,      0.3292830288410186767578125f,  0.0433130674064159393310546875f,
	0.069097287952899932861328125f,   0.9195404052734375f,           0.011362315155565738677978515625f,
	0.01639143936336040496826171875f, 0.08801330626010894775390625f, 0.895595252513885498046875f };

static const float3x3 BT2020_2_BT709 = {
	 1.66049098968505859375f,          -0.58764111995697021484375f,     -0.072849862277507781982421875f,
	-0.12455047667026519775390625f,     1.13289988040924072265625f,     -0.0083494223654270172119140625f,
	-0.01815076358616352081298828125f, -0.100578896701335906982421875f,  1.11872971057891845703125f };

static const half3x3 BT709_2_BT2020_half = {
	0.62744140625h,     0.329345703125h,  0.043304443359375h,
	0.069091796875h,    0.91943359375h,   0.01136016845703125h,
	0.016387939453125h, 0.0880126953125h, 0.8955078125h };

static const half3x3 BT2020_2_BT709_half = {
	 1.66015625h,        -0.58740234375h, -0.0728759765625h,
	-0.12457275390625h,   1.1328125h,     -0.0083465576171875h,
	-0.018157958984375h, -0.1005859375h,   1.119140625h };

// this is BT.2020 but a little wider so that we have some headroom for processing
// primaries:
// r: 0.7219375, 0.2887625
// g: 0.1637625, 0.8127
// b: 0.1233,    0.0335375
static const float3x3 BT709_2_WBT2020 = {
	0.610571384429931640625f,         0.3318304717540740966796875f,  0.0575981400907039642333984375f,
	0.075206600129604339599609375f,   0.896992862224578857421875f,   0.02780056186020374298095703125f,
	0.02199115790426731109619140625f, 0.09672014415264129638671875f, 0.881288707256317138671875f };

static const float3x3 WBT2020_2_BT709 = {
	 1.71820735931396484375f, -0.625647246837615966796875f, -0.0925601422786712646484375f,
	-0.14321804046630859375f, 1.17079079151153564453125f, -0.02757274545729160308837890625f,
	-0.027157165110111236572265625f, -0.112880535423755645751953125f, 1.14003765583038330078125f };

static const float3x3 WBT2020_2_BT2020 = {
	 1.029674530029296875f,             -0.011901193298399448394775390625f, -0.0177733041346073150634765625f,
	-0.01327986083924770355224609375f,   1.032076358795166015625f,          -0.0187964402139186859130859375f,
	-0.008763029240071773529052734375f, -0.008305363357067108154296875f,     1.017068386077880859375f };

static const float PQ_constant_M1 =  0.1593017578125f;
static const float PQ_constant_M2 = 78.84375f;
static const float PQ_constant_C1 =  0.8359375f;
static const float PQ_constant_C2 = 18.8515625f;
static const float PQ_constant_C3 = 18.6875f;

float3 BT709_To_BT2020(float3 color)
{
	return mul(BT709_2_BT2020, color);
}

float3 BT2020_To_BT709(float3 color)
{
	return mul(BT2020_2_BT709, color);
}

half3 BT709_To_BT2020_half(half3 color)
{
	return mul(BT709_2_BT2020_half, color);
}

half3 BT2020_To_BT709_half(half3 color)
{
	return mul(BT2020_2_BT709_half, color);
}

float3 BT709_To_WBT2020(float3 color)
{
	return mul(BT709_2_WBT2020, color);
}

float3 WBT2020_To_BT709(float3 color)
{
	return mul(WBT2020_2_BT709, color);
}

float3 WBT2020_To_BT2020(float3 color)
{
	return mul(WBT2020_2_BT2020, color);
}

float gamma_linear_to_sRGB(float channel)
{
	if (channel <= 0.0031308f)
	{
		channel = channel * 12.92f;
	}
	else
	{
		channel = 1.055f * pow(channel, 1.f / 2.4f) - 0.055f;
	}
	return channel;
}

float3 gamma_linear_to_sRGB(float3 Color)
{
	return float3(gamma_linear_to_sRGB(Color.r),
	              gamma_linear_to_sRGB(Color.g),
	              gamma_linear_to_sRGB(Color.b));
}

// Mirroring gamma on negative colors makes this closer to gamma 2.2 and perception space in general,
// it's sometimes easier to work with these values.
float3 gamma_linear_to_sRGB_mirrored(float3 Color)
{
	return gamma_linear_to_sRGB(abs(Color)) * sign(Color);
}

template<class T>
T linear_to_gamma(T Color, float Gamma = 2.2f)
{
	return pow(Color, 1.f / Gamma);
}

template<class T>
T linear_to_gamma_mirrored(T Color, float Gamma = 2.2f)
{
	return linear_to_gamma(abs(Color), Gamma) * sign(Color);
}

float gamma_sRGB_to_linear(float channel)
{
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

float3 gamma_sRGB_to_linear_mirrored(float3 Color)
{
	return gamma_sRGB_to_linear(abs(Color)) * sign(Color);
}

template<class T>
T gamma_to_linear(T Color, float Gamma = 2.2f)
{
	return pow(Color, Gamma);
}

template<class T>
T gamma_to_linear_mirrored(T Color, float Gamma = 2.2f)
{
	return gamma_to_linear(abs(Color), Gamma) * sign(Color);
}

float3 gamma_linear_to_sRGB_custom(float3 Color, bool MirrorBelowZero = true, bool ApplyBelowZero = ApplyGammaBelowZeroDefault, bool ApplyBeyondOne = ApplyGammaBeyondOneDefault)
{
	const float3 SDRColor = saturate(Color);
	const float3 BeyondZeroColor = max(Color, 0.f);
	const float3 BelowOneColor = min(Color, 1.f);
	const float3 SDRExcessColor = Color - SDRColor;
	const float3 BelowZeroColor = Color - BeyondZeroColor;
	const float3 BeyondOneColor = Color - BelowOneColor;

	if (!ApplyBelowZero && !ApplyBeyondOne)
		Color = SDRColor;
	else if (!ApplyBelowZero)
		Color = BeyondZeroColor;
	else if (!ApplyBeyondOne)
		Color = BelowOneColor;

	if (MirrorBelowZero && ApplyBelowZero)
		Color = gamma_linear_to_sRGB_mirrored(Color);
	else
		Color = gamma_linear_to_sRGB(Color);

	if (!ApplyBelowZero && !ApplyBeyondOne)
		Color += SDRExcessColor;
	else if (!ApplyBelowZero)
		Color += BelowZeroColor;
	else if (!ApplyBeyondOne)
		Color += BeyondOneColor;

	return Color;
}

float3 gamma_sRGB_to_linear_custom(float3 Color, bool MirrorBelowZero = true, bool ApplyBelowZero = ApplyGammaBelowZeroDefault, bool ApplyBeyondOne = ApplyGammaBeyondOneDefault)
{
	const float3 SDRColor = saturate(Color);
	const float3 BeyondZeroColor = max(Color, 0.f);
	const float3 BelowOneColor = min(Color, 1.f);
	const float3 SDRExcessColor = Color - SDRColor;
	const float3 BelowZeroColor = Color - BeyondZeroColor;
	const float3 BeyondOneColor = Color - BelowOneColor;

	if (!ApplyBelowZero && !ApplyBeyondOne)
		Color = SDRColor;
	else if (!ApplyBelowZero)
		Color = BeyondZeroColor;
	else if (!ApplyBeyondOne)
		Color = BelowOneColor;

	if (MirrorBelowZero && ApplyBelowZero)
		Color = gamma_sRGB_to_linear_mirrored(Color);
	else
		Color = gamma_sRGB_to_linear(Color);

	if (!ApplyBelowZero && !ApplyBeyondOne)
		Color += SDRExcessColor;
	else if (!ApplyBelowZero)
		Color += BelowZeroColor;
	else if (!ApplyBeyondOne)
		Color += BeyondOneColor;

	return Color;
}

float3 linear_to_gamma_custom(float3 Color, float Gamma = 2.2f, bool ApplyBelowZero = ApplyGammaBelowZeroDefault, bool ApplyBeyondOne = ApplyGammaBeyondOneDefault)
{
	const float3 SDRColor = saturate(Color);
	const float3 BeyondZeroColor = max(Color, 0.f);
	const float3 BelowOneColor = min(Color, 1.f);
	const float3 SDRExcessColor = Color - SDRColor;
	const float3 BelowZeroColor = Color - BeyondZeroColor;
	const float3 BeyondOneColor = Color - BelowOneColor;

	if (!ApplyBelowZero && !ApplyBeyondOne)
		Color = SDRColor;
	else if (!ApplyBelowZero)
		Color = BeyondZeroColor;
	else if (!ApplyBeyondOne)
		Color = BelowOneColor;

	if (ApplyBelowZero)
		Color = linear_to_gamma_mirrored(Color, Gamma);
	else
		Color = linear_to_gamma(Color, Gamma);

	if (!ApplyBelowZero && !ApplyBeyondOne)
		Color += SDRExcessColor;
	else if (!ApplyBelowZero)
		Color += BelowZeroColor;
	else if (!ApplyBeyondOne)
		Color += BeyondOneColor;

	return Color;
}

float3 gamma_to_linear_custom(float3 Color, float Gamma = 2.2f, bool ApplyBelowZero = ApplyGammaBelowZeroDefault, bool ApplyBeyondOne = ApplyGammaBeyondOneDefault)
{
	const float3 SDRColor = saturate(Color);
	const float3 BeyondZeroColor = max(Color, 0.f);
	const float3 BelowOneColor = min(Color, 1.f);
	const float3 SDRExcessColor = Color - SDRColor;
	const float3 BelowZeroColor = Color - BeyondZeroColor;
	const float3 BeyondOneColor = Color - BelowOneColor;

	if (!ApplyBelowZero && !ApplyBeyondOne)
		Color = SDRColor;
	else if (!ApplyBelowZero)
		Color = BeyondZeroColor;
	else if (!ApplyBeyondOne)
		Color = BelowOneColor;

	if (ApplyBelowZero)
		Color = gamma_to_linear_mirrored(Color, Gamma);
	else
		Color = gamma_to_linear(Color, Gamma);

	if (!ApplyBelowZero && !ApplyBeyondOne)
		Color += SDRExcessColor;
	else if (!ApplyBelowZero)
		Color += BelowZeroColor;
	else if (!ApplyBeyondOne)
		Color += BeyondOneColor;
		
	return Color;
}

// PQ (Perceptual Quantizer - ST.2084) encode/decode used for HDR10 BT.2100
template<class T>
T Linear_to_PQ(T LinearColor)
{
	LinearColor = max(LinearColor, 0.f);
	T colorPow = pow(LinearColor, PQ_constant_M1);
	T numerator = PQ_constant_C1 + PQ_constant_C2 * colorPow;
	T denominator = 1.f + PQ_constant_C3 * colorPow;
	T pq = pow(numerator / denominator, PQ_constant_M2);
	return pq;
}

template<class T>
T Linear_to_PQ(T LinearColor, const float PQMaxValue)
{
	LinearColor /= PQMaxValue;
	return Linear_to_PQ(LinearColor);
}

template<class T>
T PQ_to_Linear(T ST2084Color)
{
	ST2084Color = max(ST2084Color, 0.f);
	T colorPow = pow(ST2084Color, 1.f / PQ_constant_M2);
	T numerator = max(colorPow - PQ_constant_C1, 0.f);
	T denominator = PQ_constant_C2 - (PQ_constant_C3 * colorPow);
	T linearColor = pow(numerator / denominator, 1.f / PQ_constant_M1);
	return linearColor;
}

template<class T>
T PQ_to_Linear(T ST2084Color, const float PQMaxValue)
{
	T linearColor = PQ_to_Linear(ST2084Color);
	linearColor *= PQMaxValue;
	return linearColor;
}

// sRGB/BT.709
float Luminance(float3 color)
{
	// Fixed from "wrong" BT.709-1 values: 0.2125 0.7154 0.0721
	// Note: this might not sum up to exactly 1, but it's pretty much fine either way,
	// 0.2126 0.7152 0.0722 are the values that are most commonly used 
	return dot(color, float3(0.2126390039920806884765625f, 0.715168654918670654296875f, 0.072192318737506866455078125f));
}

float3 Saturation(float3 color, float saturation)
{
	float luminance = Luminance(color);
	return lerp(luminance, color, saturation);
}

//RGB linear BT.709/sRGB -> OKLab's LMS
static const float3x3 srgb_to_oklms = {
	0.4122214708f, 0.5363325363f, 0.0514459929f,
	0.2119034982f, 0.6806995451f, 0.1073969566f,
	0.0883024619f, 0.2817188376f, 0.6299787005f};

//RGB linear BT.2020 -> OKLab's LMS
static const float3x3 bt2020_to_oklms = {
	0.616688430309295654296875f,  0.3601590692996978759765625f, 0.0230432935059070587158203125f,
	0.2651402056217193603515625f, 0.63585650920867919921875f,   0.099030233919620513916015625f,
	0.100150644779205322265625f,  0.2040043175220489501953125f, 0.69632470607757568359375f };

//OKLab's (_) L'M'S' -> OKLab
static const float3x3 oklms__to_oklab = {
	0.2104542553f,  0.7936177850f, -0.0040720468f,
	1.9779984951f, -2.4285922050f,  0.4505937099f,
	0.0259040371f,  0.7827717662f, -0.8086757660f};

//OKLab -> OKLab's L'M'S' (_)
//the 1s get optimized away by the compiler
static const float3x3 oklab_to_oklms_ = {
	1.f,  0.3963377774f,  0.2158037573f,
	1.f, -0.1055613458f, -0.0638541728f,
	1.f, -0.0894841775f, -1.2914855480f};

//OKLab's LMS -> RGB linear BT.709/sRGB
static const float3x3 oklms_to_srgb = {
	 4.0767416621f, -3.3077115913f,  0.2309699292f,
	-1.2684380046f,  2.6097574011f, -0.3413193965f,
	-0.0041960863f, -0.7034186147f,  1.7076147010f};

//OKLab's LMS -> RGB linear BT.2020
static const float3x3 oklms_to_bt2020 = {
	 2.1401402950286865234375f,      -1.24635589122772216796875f, 0.1064317226409912109375f,
	-0.884832441806793212890625f,     2.16317272186279296875f,   -0.2783615887165069580078125f,
	-0.048579059541225433349609375f, -0.4544909000396728515625f,  1.5023562908172607421875f };

// (in) linear sRGB/BT.709
// (out) OKLab
// L - perceived lightness
// a - how green/red the color is
// b - how blue/yellow the color is
float3 linear_srgb_to_oklab(float3 rgb) {
	//LMS
	float3 lms = mul(srgb_to_oklms, rgb);

	// Not sure whether the pow(abs())*sign() is technically correct, but if we pass in scRGB negative colors (or better, colors outside the Oklab gamut),
	// this might break, and we think this might work fine
	//L'M'S'
	float3 lms_ = pow(abs(lms), 1.f/3.f) * sign(lms);

	return mul(oklms__to_oklab, lms_);
}

// (in) linear BT.2020
// (out) OKLab
float3 linear_bt2020_to_oklab(float3 rgb) {
	//LMS
	float3 lms = mul(bt2020_to_oklms, rgb);

	//L'M'S'
	float3 lms_ = pow(abs(lms), 1.f/3.f) * sign(lms);

	return mul(oklms__to_oklab, lms_);
}

// (in) OKLab
// (out) linear sRGB/BT.709
float3 oklab_to_linear_srgb(float3 lab) {
	//L'M'S'
	float3 lms_ = mul(oklab_to_oklms_, lab);

	//LMS
	float3 lms = lms_ * lms_ * lms_;

	return mul(oklms_to_srgb, lms);
}

// (in) OKLab
// (out) linear BT.2020
float3 oklab_to_linear_bt2020(float3 lab) {
	//L'M'S'
	float3 lms_ = mul(oklab_to_oklms_, lab);

	//LMS
	float3 lms = lms_ * lms_ * lms_;

	return mul(oklms_to_bt2020, lms);
}

float3 oklab_to_oklch(float3 lab) {
	float L = lab[0];
	float a = lab[1];
	float b = lab[2];
	return float3(
		L,
		sqrt((a*a) + (b*b)), // The length of the color ab (or xy) offset, which represents saturation. Range 0+.
		atan2(b, a) // Hue. Range is -π/+π, and it can loop around.
	);
}

float3 oklch_to_oklab(float3 lch) {
	float L = lch[0];
	float C = lch[1];
	float h = lch[2];
	return float3(
		L,
		C * cos(h),
		C * sin(h)
	);
}

// (in) linear sRGB/BT.709
// (out) OKLch
// L – perceived lightness (identical to OKLAB)
// c – chroma (saturation)
// h – hue
float3 linear_srgb_to_oklch(float3 rgb) {
	return oklab_to_oklch(
		linear_srgb_to_oklab(rgb)
	);
}

// (in) linear BT.2020
// (out) OKLch
float3 linear_bt2020_to_oklch(float3 rgb) {
	return oklab_to_oklch(
		linear_bt2020_to_oklab(rgb)
	);
}

// (in) OKLch
// (out) sRGB/BT.709
float3 oklch_to_linear_srgb(float3 lch) {
	return oklab_to_linear_srgb(
			oklch_to_oklab(lch)
	);
}

// (in) OKLch
// (out) BT.2020
float3 oklch_to_linear_bt2020(float3 lch) {
	return oklab_to_linear_bt2020(
			oklch_to_oklab(lch)
	);
}

// This is almost a perfect approximation of sRGB gamma, but it clips any color below 0.055.
float3 gamma_linear_to_sRGB_Bethesda_Optimized(float3 Color, float InverseGamma = 1.f / 2.4f)
{
	return (pow(Color, InverseGamma) * 1.055f) - 0.055f;
}

// Original exact inverse formula, this is heavily broken, especially in its inverse form
float3 gamma_sRGB_to_linear_Bethesda_Optimized(float3 Color, float Gamma = 2.4f)
{
	return (pow(Color, Gamma) / 1.055f) + 0.055f;
}

//L'M'S'->ICtCp
static const float3x3 PQ_LMS_2_ICtCp = {
	0.5f,             0.5f,             0.f,
	1.61376953125f,  -3.323486328125f,  1.709716796875f,
	4.378173828125f, -4.24560546875f,  -0.132568359375f};

//ICtCp->L'M'S'
//the 1s get optimized away by the compiler
static const float3x3 ICtCp_2_PQ_LMS = {
	1.f,  0.008609036915004253387451171875f,  0.11102962493896484375f,
	1.f, -0.008609036915004253387451171875f, -0.11102962493896484375f,
	1.f,  0.560031354427337646484375f,       -0.3206271827220916748046875f};

//RGB BT.709->LMS
static const float3x3 BT709_2_LMS = {
	0.295654296875f, 0.623291015625f, 0.0810546875f,
	0.156005859375f, 0.7275390625f,   0.116455078125f,
	0.03515625f,     0.15673828125f,  0.807861328125f};

//LMS->RGB BT.709
static const float3x3 LMS_2_BT709 = {
	 6.171343326568603515625f,          -5.318845272064208984375f,      0.14753799140453338623046875f,
	-1.3213660717010498046875f,          2.5573856830596923828125f,    -0.23607718944549560546875f,
	-0.012195955030620098114013671875f, -0.2647107541561126708984375f,  1.27721846103668212890625f};

//ICtCp->L'M'S'
float3 ICtCp_to_PQ_LMS(float3 Colour)
{
	return mul(ICtCp_2_PQ_LMS, Colour);
}

//L'M'S'->ICtCp
float3 PQ_LMS_to_ICtCp(float3 Colour)
{
	return mul(PQ_LMS_2_ICtCp, Colour);
}

//RGB BT.709->LMS
float3 BT709_to_LMS(float3 Colour)
{
	return mul(BT709_2_LMS, Colour);
}

//LMS->RGB BT.709
float3 LMS_to_BT709(float3 Colour)
{
	return mul(LMS_2_BT709, Colour);
}

float3 BT709_to_ICtCp(float3 Colour)
{
	// Keep division by "PQMaxWhitePoint" here (BT709_to_LMS()) instead of in "Linear_to_PQ()" for floating point accuracy
	float3 LMS = BT709_to_LMS(Colour / PQMaxWhitePoint);
	float3 PQ_LMS = Linear_to_PQ(LMS);
	return PQ_LMS_to_ICtCp(PQ_LMS);
}

float3 ICtCp_to_BT709(float3 Colour)
{
	float3 PQ_LMS = ICtCp_to_PQ_LMS(Colour);
	// max should be save as LMS should be only positive
	float3 LMS = max(PQ_to_Linear(PQ_LMS), 0.f);
	float3 RGB = LMS_to_BT709(LMS);
	return RGB * PQMaxWhitePoint;
}

static const float3x3 BT709_2_AP1D65 = {
	0.61702883243560791015625f,       0.333867609500885009765625f,    0.04910354316234588623046875f,
	0.069922320544719696044921875f,   0.91734969615936279296875f,     0.012727967463433742523193359375f,
	0.02054978720843791961669921875f, 0.107552029192447662353515625f, 0.871898174285888671875f };

static const float3x3 AP1D65_2_BT709 = {
	 1.69219148159027099609375f,      -0.6057331562042236328125f,   -0.08645831048488616943359375f,
	-0.1286492049694061279296875f,     1.13801670074462890625f,     -0.00936750136315822601318359375f,
	-0.0240139178931713104248046875f, -0.1261022388935089111328125f, 1.1501162052154541015625f };

static const float3x3 AP1D65_2_XYZ = {
	 0.647507190704345703125f,         0.13437913358211517333984375f,     0.1685695946216583251953125f,
	 0.266086399555206298828125f,      0.67596781253814697265625f,        0.057945795357227325439453125f,
	-0.00544886849820613861083984375f, 0.004072095267474651336669921875f, 1.090434551239013671875f };

static const float3x3 WIDE_2_AP1D65 = {
	0.8346002101898193359375f,           0.16017483174800872802734375f, 0.0052249575965106487274169921875f,
	0.02556082420051097869873046875f,    0.97308480739593505859375f,    0.001354344072751700878143310546875f,
	0.00192553340457379817962646484375f, 0.0303490459918975830078125f,  0.96772539615631103515625f };

// Expand bright saturated BT.709 colors onto BT.2020 to achieve a fake HDR look.
// Input (and output) needs to be in sRGB linear space. The white point (paper white) is expected to be ~80-100 nits.
// Calling this with a value of 0 still results in changes (avoid doing so, it might produce invalid colors).
// Calling this with values above 1 yields diminishing returns.
float3 ExtendGamut(float3 Color, float ExtendGamutAmount = 1.f)
{
	float3 ColorAP1    = mul(BT709_2_AP1D65, Color);
	float3 ColorExpand = mul(WIDE_2_AP1D65,  Color);

	float  LumaAP1   = dot(ColorAP1, AP1D65_2_XYZ[1]);
	float3 ChromaAP1 = ColorAP1 / LumaAP1;
	if (LumaAP1 <= 0.f) // Skip invalid colors
		return Color;

	float3 ChromaAP1Minus1  = ChromaAP1 - 1.f;
	float  ChromaDistSqr    = dot(ChromaAP1Minus1, ChromaAP1Minus1);
	float  ExtendGamutAlpha = (1.f - exp2(-4.f * ChromaDistSqr)) * (1.f - exp2(-4.f * ExtendGamutAmount * LumaAP1 * LumaAP1));

	ColorAP1 = lerp(ColorAP1, ColorExpand, ExtendGamutAlpha);

	Color = mul(AP1D65_2_BT709, ColorAP1);
	return Color;
}

float3 bt2446_hdr_to_sdr(float3 linRGB, float lHDR, float lSDR) {
	const float3 rgb = pow(linRGB, 1.f/2.4f);

	const float pHDR = 1.f + (32.f * pow(lHDR / 10000.0f, 1.f / 2.4f));
	const float pSDR = 1.f + (32.f * pow(lSDR / 10000.0f, 1.f / 2.4f));

	const float Y = Luminance(rgb); // Luma

	const float Yp = log(1.f + (pHDR - 1.0) * Y) / log(pHDR);

	const float Yc = (Yp < 0.7399f) ? 1.0770f * max(0, Yp)
		: (Yp < 0.9909f) ? (-1.1510f * Yp * Yp) + (2.7811f * Yp) - 0.6302f
		: 0.5000f * min(Yp, 1.f) + 0.5000f;

	const float Ysdr = (pow(pSDR, Yc) - 1.f) / (pSDR - 1.f);

	const float fYsdr = Ysdr / (1.1f * Y);
	const float Cbtmo = fYsdr * ((rgb.b - Y) / 1.8556);
	const float Crtmo = fYsdr * ((rgb.r - Y) / 1.5748);
	const float Ytmo = Ysdr - max(0.1f * Crtmo, 0);

	float3 outRGB = float3(
			Ytmo + (1.5748f * Crtmo),
			Ytmo - (0.2126f * 1.5748f / 0.7152f) * Crtmo - (0.0722f * 1.8556f / 1.5748f) * Cbtmo,
			Ytmo + (1.8556 * Cbtmo)
	);
	float3 outLinRgb = pow(max(0, outRGB), 2.4f);
	return outLinRgb;
}

float toneMapGainBT2446a(float Y_HDR, float L_HDR, float L_SDR) {
	float rho_hdr = 1.0 + 32.0 * pow(L_HDR / 10000.0, 1.0/2.4);
	float rho_sdr = 1.0 + 32.0 * pow(L_SDR / 10000.0, 1.0/2.4);

	// Y_HDR is "A normalized full-range linear display-light HDR signal"
	float Yprime = pow(Y_HDR / L_HDR, 1.0/2.4);

	float Yp_prime = log(1.0 + (rho_hdr - 1.0) * Yprime) / log(rho_hdr);
	float Yc_prime = 0.0;
	if (Yp_prime < 0.0) {
		Yc_prime = 0.0;
	} else if (Yp_prime < 0.7399) {
		Yc_prime = 1.0770 * Yp_prime;
	} else if (Yp_prime < 0.9909) {
		Yc_prime = -1.1510 * pow(Yp_prime, 2.0) + 2.7811*Yp_prime - 0.6302;
	} else if (Yp_prime <= 1.0) {
		Yc_prime = 0.5 * Yp_prime + 0.5;
	} else {
		Yc_prime = 1.0;
	}
	float Ysdr_prime = (pow(rho_sdr, Yc_prime) - 1.0) / (rho_sdr - 1.0);

	float Ysdr = pow(Ysdr_prime, 2.4);
	return (Ysdr * L_SDR) / Y_HDR;
}

// From Chromium dev
float3 bt2446_bt709(float3 linRGB, float lHDR, float lSDR) {
	float3 tonemap_input = BT709_To_BT2020(linRGB);
	float3 gain = float3(toneMapGainBT2446a(tonemap_input.r, lHDR, lSDR),
                      toneMapGainBT2446a(tonemap_input.g, lHDR, lSDR),
                      toneMapGainBT2446a(tonemap_input.b, lHDR, lSDR));
	tonemap_input *= gain;
	return BT2020_To_BT709(tonemap_input);
}

// Finds the maximum saturation possible for a given hue that fits in sRGB/BT.2020
// Saturation here is defined as S = C/L
// a and b must be normalized so a^2 + b^2 == 1
float oklab_compute_max_saturation(float a, float b, bool BT2020)
{
    // Max saturation will be when one of r, g or b goes below zero.

	const float3x3 oklms_to_rgb = BT2020 ? oklms_to_bt2020 : oklms_to_srgb;

    // Select different coefficients depending on which component goes below zero first
    float k0, k1, k2, k3, k4, wl, wm, ws;

    if (-1.88170328f * a - 0.80936493f * b > 1)
    {
        // Red component
        k0 = +1.19086277f; k1 = +1.76576728f; k2 = +0.59662641f; k3 = +0.75515197f; k4 = +0.56771245f; //TODO: find k components for BT.2020 (these are for sRGB?)
        wl = oklms_to_rgb[0][0]; wm = oklms_to_rgb[0][1]; ws = oklms_to_rgb[0][2];
    }
    else if (1.81444104f * a - 1.19445276f * b > 1)
    {
        // Green component
        k0 = +0.73956515f; k1 = -0.45954404f; k2 = +0.08285427f; k3 = +0.12541070f; k4 = +0.14503204f;
        wl = oklms_to_rgb[1][0]; wm = oklms_to_rgb[1][1]; ws = oklms_to_rgb[1][2];
    }
    else
    {
        // Blue component
        k0 = +1.35733652f; k1 = -0.00915799f; k2 = -1.15130210f; k3 = -0.50559606f; k4 = +0.00692167f;
        wl = oklms_to_rgb[2][0]; wm = oklms_to_rgb[2][1]; ws = oklms_to_rgb[2][2];
    }

    // Approximate max saturation using a polynomial:
    float S = k0 + k1 * a + k2 * b + k3 * a * a + k4 * a * b;

    // Do one step Halley's method to get closer
    // this gives an error less than 10e6, except for some blue hues where the dS/dh is close to infinite
    // this should be sufficient for most applications, otherwise do two/three steps

	float3 k_lms = mul(oklab_to_oklms_, float3(0.f, a, b));
	float3 lms_ = 1.f + S * k_lms;
	float3 lms = lms_ * lms_ * lms_;

	float3 lms_dS = 3.f * k_lms * lms_ * lms_;
	float3 lms_dS2 = 6.f * k_lms * k_lms * lms_;

	float f  = wl * lms[0]     + wm * lms[1]     + ws * lms[2];
	float f1 = wl * lms_dS[0]  + wm * lms_dS[1]  + ws * lms_dS[2];
	float f2 = wl * lms_dS2[0] + wm * lms_dS2[1] + ws * lms_dS2[2];

	S = S - f * f1 / (f1*f1 - 0.5f * f * f2);

    return S;
}

// finds L_cusp and C_cusp for a given hue
// a and b must be normalized so a^2 + b^2 == 1
struct LC { float L; float C; };
LC oklab_find_cusp(float a, float b, bool BT2020)
{
	// First, find the maximum saturation (saturation S = C/L)
	float S_cusp = oklab_compute_max_saturation(a, b, BT2020);

	// Convert to linear sRGB/BT.2020 to find the first point where at least one of r,g or b >= 1:
	float3 lab = float3(1.f, S_cusp * a, S_cusp * b);
	float3 rgb_at_max = BT2020 ? oklab_to_linear_bt2020(lab) : oklab_to_linear_srgb(lab);
	float L_cusp = pow(1.f / max(max(rgb_at_max.r, rgb_at_max.g), rgb_at_max.b), 1.f / 3.f);
	float C_cusp = L_cusp * S_cusp;

	LC cusp;
	cusp.L = L_cusp;
	cusp.C = C_cusp;
	return cusp;
}

// Finds intersection of the line defined by
// L = L0 * (1 - t) + t * L1;
// C = t * C1;
// a and b must be normalized so a^2 + b^2 == 1
static const LC defaultCusp = (LC)0;
float oklab_find_gamut_intersection(float a, float b, float L1, float C1, float L0, bool BT2020, bool overrideCusp = false, LC overriddenCusp = defaultCusp)
{
	const float3x3 oklms_to_rgb = BT2020 ? oklms_to_bt2020 : oklms_to_srgb;

	// Find the cusp of the gamut triangle
	LC cusp;
	if (overrideCusp)
		cusp = overriddenCusp;
	else
		cusp = oklab_find_cusp(a, b, BT2020);

	// Find the intersection for upper and lower half seprately
	float t;
	if (((L1 - L0) * cusp.C - (cusp.L - L0) * C1) <= 0.f)
	{
		// Lower half

		t = cusp.C * L0 / (C1 * cusp.L + cusp.C * (L0 - L1));
	}
	else
	{
		// Upper half

		// First intersect with triangle
		t = cusp.C * (L0 - 1.f) / (C1 * (cusp.L - 1.f) + cusp.C * (L0 - L1));

		// Then one step Halley's method
		{
			float dL = L1 - L0;
			float dC = C1;

			float3 k_lms = mul(oklab_to_oklms_, float3(0.f, a, b));

			float3 lms_dt = dL + dC * k_lms;

			// If higher accuracy is required, 2 or 3 iterations of the following block can be used:
			{
				float L = L0 * (1.f - t) + t * L1;
				float C = t * C1;

				float3 lms_ = L + C * k_lms;
				float3 lms = lms_ * lms_ * lms_;

				float3 lmsdt = 3.f * lms_dt * lms_ * lms_;
				float3 lmsdt2 = 6.f * lms_dt * lms_dt * lms_;

				// NOTE: these could possibly be optimized?
				float r = oklms_to_rgb[0][0] * lms[0] + oklms_to_rgb[0][1] * lms[1] + oklms_to_rgb[0][2] * lms[2] - 1.f;
				float r1 = oklms_to_rgb[0][0] * lmsdt[0] + oklms_to_rgb[0][1] * lmsdt[1] + oklms_to_rgb[0][2] * lmsdt[2];
				float r2 = oklms_to_rgb[0][0] * lmsdt2[0] + oklms_to_rgb[0][1] * lmsdt2[1] + oklms_to_rgb[0][2] * lmsdt2[2];

				float u_r = r1 / (r1 * r1 - 0.5f * r * r2);
				float t_r = -r * u_r;

				float g = oklms_to_rgb[1][0] * lms[0] + oklms_to_rgb[1][1] * lms[1] + oklms_to_rgb[1][2] * lms[2] - 1.f;
				float g1 = oklms_to_rgb[1][0] * lmsdt[0] + oklms_to_rgb[1][1] * lmsdt[1] + oklms_to_rgb[1][2] * lmsdt[2];
				float g2 = oklms_to_rgb[1][0] * lmsdt2[0] + oklms_to_rgb[1][1] * lmsdt2[1] + oklms_to_rgb[1][2] * lmsdt2[2];

				float u_g = g1 / (g1 * g1 - 0.5f * g * g2);
				float t_g = -g * u_g;

				float b = oklms_to_rgb[2][0] * lms[0] + oklms_to_rgb[2][1] * lms[1] + oklms_to_rgb[2][2] * lms[2] - 1.f;
				float b1 = oklms_to_rgb[2][0] * lmsdt[0] + oklms_to_rgb[2][1] * lmsdt[1] + oklms_to_rgb[2][2] * lmsdt[2];
				float b2 = oklms_to_rgb[2][0] * lmsdt2[0] + oklms_to_rgb[2][1] * lmsdt2[1] + oklms_to_rgb[2][2] * lmsdt2[2];

				float u_b = b1 / (b1 * b1 - 0.5f * b * b2);
				float t_b = -b * u_b;

				t_r = u_r >= 0.f ? t_r : FLT_MAX;
				t_g = u_g >= 0.f ? t_g : FLT_MAX;
				t_b = u_b >= 0.f ? t_b : FLT_MAX;

				t += min(t_r, min(t_g, t_b));
			}
		}
	}

	return t;
}

// This only works in the SDR 0-1 range, thus it's hardcoded for sRGB
float3 gamut_clip_preserve_chroma(float3 rgb)
{
	const bool isInSDRRange = rgb.r <= 1.f && rgb.g <= 1.f && rgb.b <= 1.f && rgb.r >= 0.f && rgb.g >= 0.f && rgb.b >= 0.f;
	if (isInSDRRange)
		return rgb;

	float3 lab = linear_srgb_to_oklab(rgb);

	float L = lab.x;
	float C = max(FLT_MIN, sqrt(lab.y * lab.y + lab.z * lab.z));
	float a_ = lab.y / C;
	float b_ = lab.z / C;

	// This step can't be skipped, we are forced to stay in the SDR range
	float L0 = clamp(L, 0.f, 1.f);

	float t = oklab_find_gamut_intersection(a_, b_, L, C, L0, false);
	float L_clipped = L0 * (1.f - t) + t * L;
	float C_clipped = t * C;

	lab = float3(L_clipped, C_clipped * a_, C_clipped * b_);
	return oklab_to_linear_srgb(lab);
}

float3 gamut_clip_project_to_L_cusp(float3 rgb, bool in_BT2020, bool clamp_BT2020, bool out_BT2020)
{
	const bool isInSDRRange = rgb.r <= 1.f && rgb.g <= 1.f && rgb.b <= 1.f && rgb.r >= 0.f && rgb.g >= 0.f && rgb.b >= 0.f;
	const bool isFullySRGB = !in_BT2020 && !clamp_BT2020 && !out_BT2020;
	if (isInSDRRange && isFullySRGB)
		return rgb; //TODO (this one and the one above). BT2020 HDR10 isn't limited by the 0-1 range.

	float3 lab = in_BT2020 ? linear_bt2020_to_oklab(rgb) : linear_srgb_to_oklab(rgb);

	float L = lab.x;
	float C = max(FLT_MIN, sqrt(lab.y * lab.y + lab.z * lab.z));
	float a_ = lab.y / C;
	float b_ = lab.z / C;

	LC cusp = oklab_find_cusp(a_, b_, clamp_BT2020);
	float L0 = cusp.L;
	float t = oklab_find_gamut_intersection(a_, b_, L, C, L0, clamp_BT2020, true, cusp);

	float L_clipped = L0 * (1.f - t) + t * L;
	float C_clipped = t * C;

	lab = float3(L_clipped, C_clipped * a_, C_clipped * b_);
	return out_BT2020 ? oklab_to_linear_bt2020(lab) : oklab_to_linear_srgb(lab);
}

// linear (or perceptual?) sRGB to HSV: hue, saturation, value
float3 srgb_to_hsv(float3 rgb)
{
	float M = max(rgb.r, max(rgb.g, rgb.b));
	float m = min(rgb.r, min(rgb.g, rgb.b));
	float C = M - m;
	float invertedC = C == 0.f ? 0.f : rcp(C);
	float h1 = 0.f;
	if (M == rgb.r)
		h1 = (rgb.g - rgb.b) * invertedC;
	else if (M == rgb.g)
		h1 = (rgb.b - rgb.r) * invertedC + 2.f;
	else if (M == rgb.b)
		h1 = (rgb.r - rgb.g) * invertedC + 4.f;
	if (h1 < 0.f)
		h1 += 6.f;
	float h = h1 / 6.f;
	float v = M;
	float s = (v == 0.f) ? 0.f : (C / v);
	return float3(h, s, v);
}


static const float2 D65xy = float2(0.3127f, 0.3290f);

static const float2 R2020xy = float2(0.708f, 0.292f);
static const float2 G2020xy = float2(0.170f, 0.797f);
static const float2 B2020xy = float2(0.131f, 0.046f);

static const float2 R709xy = float2(0.64f, 0.33f);
static const float2 G709xy = float2(0.30f, 0.60f);
static const float2 B709xy = float2(0.15f, 0.06f);

static const float3x3 BT2020_To_XYZ = {
	0.636958062648773193359375f, 0.144616901874542236328125f,    0.1688809692859649658203125f,
	0.26270020008087158203125f,  0.677998065948486328125f,       0.0593017153441905975341796875f,
	0.f,                         0.028072692453861236572265625f, 1.060985088348388671875f};

static const float3x3 XYZ_To_BT2020 = {
	 1.7166512012481689453125f,       -0.3556707799434661865234375f,   -0.253366291522979736328125f,
	-0.666684329509735107421875f,      1.61648118495941162109375f,      0.0157685466110706329345703125f,
	 0.0176398567855358123779296875f, -0.0427706129848957061767578125f, 0.9421031475067138671875f };

static const float3x3 BT709_To_XYZ = {
	0.4123907983303070068359375f,    0.3575843274593353271484375f,   0.18048079311847686767578125f,
	0.2126390039920806884765625f,    0.715168654918670654296875f,    0.072192318737506866455078125f,
	0.0193308182060718536376953125f, 0.119194783270359039306640625f, 0.950532138347625732421875f };

static const float3x3 XYZ_To_BT709 = {
	 3.2409698963165283203125f,      -1.53738319873809814453125f,  -0.4986107647418975830078125f,
	-0.96924364566802978515625f,      1.875967502593994140625f,     0.0415550582110881805419921875f,
	 0.055630080401897430419921875f, -0.2039769589900970458984375f, 1.05697154998779296875f };

float3 XYZToxyY(float3 XYZ)
{
  const float xyz = XYZ.x + XYZ.y + XYZ.z;

	float x = XYZ.x / xyz;
	float y = XYZ.y / xyz;

  return float3(x,
                y,
                XYZ.y);
}

float3 xyYToXYZ(float3 xyY)
{
	float X = (xyY.x / xyY.y) * xyY.z;
	float Z = ((1.f - xyY.x - xyY.y) / xyY.y) * xyY.z;

  return float3(X,
                xyY.z,
                Z);
}

float GetM(float2 A, float2 B)
{
	return (B.y - A.y)
	     / (B.x - A.x);
}

//other way to check for segment intersection
//
//https://bryceboe.com/2006/10/23/line-segment-intersection-algorithm/
//is counter clock wise?
bool CCW(float2 A, float2 B, float2 C)
{
	return (C.y - A.y) * (B.x - A.x) > (B.y - A.y) * (C.x - A.x);
}

bool SegmentIntersects(float2 A, float2 B, float2 C, float2 D)
{
	return CCW(A, C, D) != CCW(B, C, D) && CCW(A, B, C) != CCW(A, B, D);
}

float2 LineIntercept(float MP, float2 FromXYCoords, float2 ToXYCoords, float2 WhitePointXYCoords = D65xy)
{
	const float m = GetM(FromXYCoords, ToXYCoords);
	const float m_mul_xyx = m * FromXYCoords.x;

	const float m_minus_MP = m - MP;
	const float MP_mul_WhitePoint_xyx = MP * WhitePointXYCoords.x;

	float x = (-MP_mul_WhitePoint_xyx + WhitePointXYCoords.y - FromXYCoords.y + m_mul_xyx) / m_minus_MP;
	float y = (-WhitePointXYCoords.y * m + m * MP_mul_WhitePoint_xyx + FromXYCoords.y * MP - m_mul_xyx * MP) / -m_minus_MP;
	return float2(x, y);
}

// Not 100% hue conservering but better than just max(color, 0.f), this maps the color on the closest humanly visible xy location on th CIE graph.
// This doesn't break gradients. The color luminance is not considered, so invalid luminances still get gamut mapped through the same math.
// Supports either BT.2020 or BT.709 (sRGB/scRGB) clamping (input and output need to be in the same color space). Hardcoded for D65 white point.
float3 SimpleGamutClip(float3 Color, bool BT2020, bool ClampToSDRRange = false)
{
	const bool3 isNegative = Color < 0.f;
	const bool allArePositive = !any(isNegative);
	const bool allAreNegative = all(isNegative);

	if (allArePositive)
	{
	}
	// Clip to black as the hue of an all negative color is invalid
	else if (allAreNegative)
	{
		return 0.f;
	}
	else
	{
		float3 XYZ = mul(BT2020 ? BT2020_To_XYZ : BT709_To_XYZ, Color);
		float3 xyY = XYZToxyY(XYZ);
		float m = GetM(xyY.xy, D65xy);
		const float2 Rxy = BT2020 ? R2020xy : R709xy;
		const float2 Gxy = BT2020 ? G2020xy : G709xy;
		const float2 Bxy = BT2020 ? B2020xy : B709xy;

		float2 gamutClippedXY;
		// we can determine on which side we need to do the intercept based on where the negative number/s is/are
		// the intercept needs to happen on the opposite side of where the primary of the smallest negative number is
		// with 2 negative numbers the smaller one determines the side to check
		if (all(isNegative.rg))
		{
			if (Color.r <= Color.g)
				gamutClippedXY = LineIntercept(m, Gxy, Bxy); // GB
			else
				gamutClippedXY = LineIntercept(m, Bxy, Rxy); // BR
		}
		else if (all(isNegative.rb))
		{
			if (Color.r <= Color.b)
				gamutClippedXY = LineIntercept(m, Gxy, Bxy); // GB
			else
				gamutClippedXY = LineIntercept(m, Rxy, Gxy); // RG
		}
		else if (all(isNegative.gb))
		{
			if (Color.g <= Color.b)
				gamutClippedXY = LineIntercept(m, Bxy, Rxy); // BR
			else
				gamutClippedXY = LineIntercept(m, Rxy, Gxy); // RG
		}
		else if (isNegative.r)
			gamutClippedXY = LineIntercept(m, Gxy, Bxy); // GB
		else if (isNegative.g)
			gamutClippedXY = LineIntercept(m, Bxy, Rxy); // BR
		else //if (isNegative.b)
			gamutClippedXY = LineIntercept(m, Rxy, Gxy); // RG

		float3 gamutClippedXYZ = xyYToXYZ(float3(gamutClippedXY, xyY.z)); // Maintains the old luminance
		Color = mul(BT2020 ? XYZ_To_BT2020 : XYZ_To_BT709, gamutClippedXYZ);
	}
	// Reduce brightness instead of reducing saturation
	if (ClampToSDRRange)
	{
		const float maxChannel = max(1.f, max(Color.r, max(Color.g, Color.b)));
		Color /= maxChannel;
	}
	return Color;
}
