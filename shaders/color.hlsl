#pragma once

// Rec.709 SDR white is meant to be mapped to 80 nits (not 100, even if some game engine (UE) and consoles (PS5) interpret it as such).
static const float WhiteNits_BT709 = 80.f;
static const float ReferenceWhiteNits_BT2408 = 203.f;

// SDR mid gray.
// This is based on the commonly used value, though perception space mid gray in sRGB or Gamma 2.2 would theoretically be ~0.2155
static const float MidGray = 0.18f;

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
