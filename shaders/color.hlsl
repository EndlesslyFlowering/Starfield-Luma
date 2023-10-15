#pragma once

// sRGB SDR white is meant to be mapped to 80 nits (not 100, even if some game engine (UE) and consoles (PS5) interpret it as such).
static const float WhiteNits_sRGB = 80.f;
static const float ReferenceWhiteNits_BT2408 = 203.f;

// SDR mid gray.
// This is based on the commonly used value, though perception space mid gray in sRGB or Gamma 2.2 would theoretically be ~0.2155
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
static const float3x3 BT709_2_BT2020 = float3x3(
	0.62722527980804443359375f,       0.329476892948150634765625f, 0.04329781234264373779296875f,
	0.0690418779850006103515625f,     0.919605672359466552734375f, 0.011352437548339366912841796875f,
	0.01639117114245891571044921875f, 0.0880887508392333984375f,   0.89552009105682373046875f);

static const float3x3 BT2020_2_BT709 = float3x3(
	 1.6609637737274169921875f,       -0.58811271190643310546875f,    -0.072851054370403289794921875f,
	-0.124477200210094451904296875f,   1.1328194141387939453125f,     -0.00834227167069911956787109375f,
	-0.0181571580469608306884765625f, -0.10066641867160797119140625f,  1.118823528289794921875f);

static const half3x3 BT709_2_BT2020_half = half3x3(
	0.62744140625h,     0.32958984375h,    0.043304443359375h,
	0.06903076171875h,  0.91943359375h,    0.0113525390625h,
	0.016387939453125h, 0.08807373046875h, 0.8955078125h);

static const half3x3 BT2020_2_BT709_half = half3x3(
	 1.6611328125h,      -0.587890625h,      -0.0728759765625h,
	-0.12445068359375h,   1.1328125h,        -0.00833892822265625h,
	-0.018157958984375h, -0.10064697265625h,  1.119140625h);

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

float gamma_linear_to_sRGB(float channel)
{
	[flatten]
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

// PQ (Perceptual Quantizer - ST.2084) encode/decode used for HDR10 BT.2100
float3 linear_to_PQ(float3 LinearColor, const float PQMaxValue = PQMaxWhitePoint)
{
    LinearColor /= PQMaxValue;
    float3 colorPow = pow(LinearColor, PQ_constant_M1);
    float3 numerator = PQ_constant_C1 + PQ_constant_C2 * colorPow;
    float3 denominator = 1.f + PQ_constant_C3 * colorPow;
    float3 pq = pow(numerator / denominator, PQ_constant_M2);
    return pq;
}

float3 PQ_to_Linear(float3 ST2084Color, const float PQMaxValue = PQMaxWhitePoint)
{
    float3 colorPow = pow(ST2084Color, 1.f / PQ_constant_M2 );
    float3 numerator = max(colorPow - PQ_constant_C1, 0.f);
    float3 denominator = PQ_constant_C2 - (PQ_constant_C3 * colorPow);
    float3 linearColor = pow(numerator / denominator, 1.f / PQ_constant_M1);
    linearColor *= PQMaxValue;
    return linearColor;
}

float Luminance(float3 color)
{
	// Fixed from "wrong" values: 0.2125 0.7154 0.0721f
	return dot(color, float3(0.2125072777271270751953125f, 0.71535003185272216796875f, 0.07214272022247314453125f));
}

float3 Saturation(float3 color, float saturation)
{
    float luminance = Luminance(color);
    return lerp(luminance, color, saturation);
}

// sRGB/Rec.709
float3 linear_srgb_to_oklab(float3 rgb) {
	float l = (0.4122214708f * rgb.r) + (0.5363325363f * rgb.g) + (0.0514459929f * rgb.b);
	float m = (0.2119034982f * rgb.r) + (0.6806995451f * rgb.g) + (0.1073969566f * rgb.b);
	float s = (0.0883024619f * rgb.r) + (0.2817188376f * rgb.g) + (0.6299787005f * rgb.b);

	// Not sure whether the pow(abs())*sign() is technically correct, but if we pass in scRGB negative colors, this breaks,
	// and we think this might work fine (we could convert to BT.2020 first otherwise)
	float l_ = pow(abs(l), 1.f/3.f) * sign(l);
	float m_ = pow(abs(m), 1.f/3.f) * sign(m);
	float s_ = pow(abs(s), 1.f/3.f) * sign(s);

	return float3(
		(0.2104542553f * l_) + (0.7936177850f * m_) - (0.0040720468f * s_),
		(1.9779984951f * l_) - (2.4285922050f * m_) + (0.4505937099f * s_),
		(0.0259040371f * l_) + (0.7827717662f * m_) - (0.8086757660f * s_)
	);
}

// sRGB/Rec.709
float3 oklab_to_linear_srgb(float3 lab) {
	float L = lab[0];
	float a = lab[1];
	float b = lab[2];
	float l_ = L + (0.3963377774f * a) + (0.2158037573f * b);
	float m_ = L - (0.1055613458f * a) - (0.0638541728f * b);
	float s_ = L - (0.0894841775f * a) - (1.2914855480f * b);

	float l = l_ * l_ * l_;
	float m = m_ * m_ * m_;
	float s = s_ * s_ * s_;

	return float3(
		(+4.0767416621f * l) - (3.3077115913f * m) + (0.2309699292f * s),
		(-1.2684380046f * l) + (2.6097574011f * m) - (0.3413193965f * s),
		(-0.0041960863f * l) - (0.7034186147f * m) + (1.7076147010f * s)
	);
}

float3 oklab_to_oklch(float3 lab) {
	float L = lab[0];
	float a = lab[1];
	float b = lab[2];
	return float3(
		L,
		sqrt((a*a) + (b*b)),
		atan2(b, a)
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

float3 oklch_to_linear_srgb(float3 lch) {
	return oklab_to_linear_srgb(
			oklch_to_oklab(lch)
	);
}

float3 linear_srgb_to_oklch(float3 rgb) {
	return oklab_to_oklch(
		linear_srgb_to_oklab(rgb)
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
#define PqLmsToIctcp float3x3( \
	asfloat(0x3f000000), asfloat(0x3f000000), asfloat(0x00000000), \
	asfloat(0x3fce9000), asfloat(0xc054b400), asfloat(0x3fdad800), \
	asfloat(0x408c1a00), asfloat(0xc087dc00), asfloat(0xbe07c000))

//ICtCp->L'M'S'
#define IctcpToPqLms float3x3( \
	asfloat(0x3f800000), asfloat(0x3c0d0ceb), asfloat(0x3de36380), \
	asfloat(0x3f800000), asfloat(0xbc0d0ceb), asfloat(0xbde36380), \
	asfloat(0x3f800000), asfloat(0x3f0f5e37), asfloat(0xbea4293f))

//RGB BT.709->LMS
#define Bt709ToLms float3x3( \
	asfloat(0x3e976000), asfloat(0x3f1f9000), asfloat(0x3da60000), \
	asfloat(0x3e1fc000), asfloat(0x3f3a4000), asfloat(0x3dee8000), \
	asfloat(0x3d100000), asfloat(0x3e208000), asfloat(0x3f4ed000))

//LMS->RGB BT.709
#define LmsToBt709 float3x3( \
	asfloat(0x40c57ba5), asfloat(0xc0aa33fb), asfloat(0x3e171433), \
	asfloat(0xbfa92286), asfloat(0x4023ac35), asfloat(0xbe71be38), \
	asfloat(0xbc47d18b), asfloat(0xbe87882b), asfloat(0x3fa37be5))

//ICtCp->L'M'S'
float3 ICtCp_to_LMS(float3 Colour)
{
	return mul(IctcpToPqLms, Colour);
}

//L'M'S'->ICtCp
float3 LMS_to_ICtCp(float3 Colour)
{
	return mul(PqLmsToIctcp, Colour);
}

//RGB BT.709->LMS
float3 BT709_to_LMS(float3 Colour)
{
	return mul(Bt709ToLms, Colour);
}

//LMS->RGB BT.709
float3 LMS_to_BT709(float3 Colour)
{
	return mul(LmsToBt709, Colour);
}

float3 BT709_to_ICtCp(float3 Colour)
{
	// Keep division by "PQMaxWhitePoint" here (BT709_to_LMS()) instead of in "linear_to_PQ()" for floating point accuracy
    float3 LMS = mul(Bt709ToLms, Colour / PQMaxWhitePoint);
    float3 PQ_LMS = linear_to_PQ(LMS, 1.f);
    return LMS_to_ICtCp(PQ_LMS);
}

float3 ICtCp_to_BT709(float3 Colour)
{
    float3 PQ_LMS = ICtCp_to_LMS(Colour);
	// Max should be save as LMS should be only positive
    float3 LMS = max(PQ_to_Linear(PQ_LMS, 1.f), 0.f);
    return LMS_to_BT709(LMS * PQMaxWhitePoint);
}

static const float3x3 XYZ_2_sRGB = float3x3(
	3.2409699419, -1.5373831776, -0.4986107603,
	-0.9692436363, 1.8759675015, 0.0415550574,
	0.0556300797, -0.2039769589, 1.0569715142);
static const float3x3 sRGB_2_XYZ = float3x3(
	0.4124564, 0.3575761, 0.1804375,
	0.2126729, 0.7151522, 0.0721750,
	0.0193339, 0.1191920, 0.9503041);
static const float3x3 XYZ_2_AP1 = float3x3(
	1.6410233797, -0.3248032942, -0.2364246952,
	-0.6636628587, 1.6153315917, 0.0167563477,
	0.0117218943, -0.0082844420, 0.9883948585);
static const float3x3 D65_2_D60 = float3x3(
	1.01303, 0.00610531, -0.014971,
	0.00769823, 0.998165, -0.00503203,
	-0.00284131, 0.00468516, 0.924507);
static const float3x3 D60_2_D65 = float3x3(
	0.987224, -0.00611327, 0.0159533,
	-0.00759836, 1.00186, 0.00533002,
	0.00307257, -0.00509595, 1.08168);
static const float3x3 AP1_2_XYZ = float3x3(
	0.6624541811, 0.1340042065, 0.1561876870,
	0.2722287168, 0.6740817658, 0.0536895174,
	-0.0055746495, 0.0040607335, 1.0103391003);
static const float3 AP1_RGB2Y = float3(
	0.2722287168, /*AP1_2_XYZ[0][1]*/
	0.6740817658, /*AP1_2_XYZ[1][1]*/
	0.0536895174 /*AP1_2_XYZ[2][1]*/);
static const float3x3 SRGB_2_CUSTOM_XYZ = float3x3(
    0.5441691, 0.2395926, 0.1666943,
    0.2394656, 0.7021530, 0.0583814,
    -0.0023439, 0.0361834, 1.0552183); //TODO1

// Expand bright saturated BT.709 colors onto BT.2020 to achieve a fake HDR look.
// Input (and output) needs to be in sRGB linear space.
// Calling this with a value of 0 still results in changes (avoid doing so, it might produce invalid colors).
// Calling this with values above 1 yields diminishing returns.
float3 ExtendGamut(float3 Color, float ExtendGamutAmount = 1.f)
{
    const float3x3 sRGB_2_AP1 = mul(XYZ_2_AP1, mul(D65_2_D60, sRGB_2_XYZ));
    const float3x3 AP1_2_sRGB = mul(XYZ_2_sRGB, mul(D60_2_D65, AP1_2_XYZ));
    const float3x3 CUSTOM_XYZ_2_AP1 = mul(XYZ_2_AP1, SRGB_2_CUSTOM_XYZ);
    const float3x3 ExtendGamutMatrix = mul(CUSTOM_XYZ_2_AP1, AP1_2_sRGB);

    float3 ColorAP1 = mul(sRGB_2_AP1, Color);

    float LumaAP1 = dot(ColorAP1, AP1_RGB2Y);
    float3 ChromaAP1 = ColorAP1 / LumaAP1;

    float ChromaDistSqr = dot(ChromaAP1 - 1.f, ChromaAP1 - 1.f);
    float ExtendGamutAlpha = (1.f - exp2(-4.f * ChromaDistSqr)) * (1.f - exp2(-4.f * ExtendGamutAmount * LumaAP1 * LumaAP1));

    float3 ColorExpand = mul(ExtendGamutMatrix, ColorAP1);
    ColorAP1 = lerp(ColorAP1, ColorExpand, ExtendGamutAlpha);

    Color = mul(AP1_2_sRGB, ColorAP1);
    return Color;
}