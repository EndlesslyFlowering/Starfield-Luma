#pragma once

// Rec.709 SDR white is meant to be mapped to 80 nits (not 100, even if some game engine (UE) and consoles (PS5) interpret it as such).
static const float WhiteNits_BT709 = 80.f;
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
static const float PQMaxWhitePoint = PQMaxNits / WhiteNits_BT709;

// These have been calculated to be as accurate as possible
static const float3x3 BT709_2_BT2020 = float3x3(
	0.627401924722236, 0.329291971755002, 0.0433061035227622,
	0.0690954897392608, 0.919544281267395, 0.0113602289933443,
	0.0163937090881632, 0.0880281623979006, 0.895578128513936);
static const float3x3 BT2020_2_BT709 = float3x3(
	1.66049621914783, -0.587656444131135, -0.0728397750166941,
	-0.124547095586012, 1.13289510924730, -0.00834801366128445,
	-0.0181536813870718, -0.100597371685743, 1.11875105307281);

float3 BT709_To_BT2020(float3 color)
{
	return mul(BT709_2_BT2020, color);
}

float3 BT2020_To_BT709(float3 color)
{
	return mul(BT2020_2_BT709, color);
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

float Luminance(float3 color)
{
	// Fixed from "wrong" values: 0.2125 0.7154 0.0721f
	return dot(color, float3(0.2126f, 0.7152f, 0.0722f));
}

float3 saturation(float3 color, float saturation)
{
    float3 luminance = Luminance(color);
    return lerp(luminance, color, saturation);
}


float3 linear_srgb_to_oklab(float3 rgb) {
	float l = (0.4122214708f * rgb.r) + (0.5363325363f * rgb.g) + (0.0514459929f * rgb.b);
	float m = (0.2119034982f * rgb.r) + (0.6806995451f * rgb.g) + (0.1073969566f * rgb.b);
	float s = (0.0883024619f * rgb.r) + (0.2817188376f * rgb.g) + (0.6299787005f * rgb.b);

	float l_ = pow(l, 1.f/3.f);
	float m_ = pow(m, 1.f/3.f);
	float s_ = pow(s, 1.f/3.f);

	return float3(
		(0.2104542553f * l_) + (0.7936177850f * m_) - (0.0040720468f * s_),
		(1.9779984951f * l_) - (2.4285922050f * m_) + (0.4505937099f * s_),
		(0.0259040371f * l_) + (0.7827717662f * m_) - (0.8086757660f * s_)
	);
}


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
	return float3 (
		L,
		sqrt((a*a) + (b*b)),
		atan2(b, a)
	);
}

float3 oklch_to_oklab(float3 lch) {
	float L = lch[0];
	float C = lch[1];
	float h = lch[2];
	return float3 (
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
