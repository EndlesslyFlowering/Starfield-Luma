#pragma once

#define FLT_MAX 3.402823466e+38F
#define FLT10_MAX 64512.f
#define FLT11_MAX 65024.f
#define FLT16_MAX 65504.f

float hypot3(float3 input)
{
	float3 inputSquared = input * input;
	return sqrt(inputSquared.x + inputSquared.y + inputSquared.z);
}

// From old to new range
template<class T>
T linearNormalization(T input, T min, T max, T newMin, T newMax)
{
	return ((input - min) * ((newMax - newMin) / (max - min))) + newMin;
}

// Returns 1 if "dividend" is 0
float safeDivision(float quotient, float dividend)
{
	return dividend == 0.f ? 1.f : (quotient / dividend);
}

// Returns 1 if "dividend" is 0
float3 safeDivision(float3 quotient, float3 dividend)
{
	float3 result = quotient / dividend;
	for (uint channel = 0; channel < 3; channel++)
	{
		if (dividend[channel] == 0.f)
		{
			result = 1.f;
		}
	}
	return result;
}

// Aplies exponential ("Photographic") luma compression.
// The pow can modulate the curve without changing the values around the edges.
float rangeCompressPow(float x, float fMax = FLT_MAX, float fPow = 1.f)
{
	// Branches are for static parameters optimizations
	if (fPow == 1.f && fMax == FLT_MAX)
	{
		// This does e^x. We expect x to be between 0 and 1.
		return 1.f - exp(-x);
	}
	if (fPow == 1.f && fMax != FLT_MAX)
	{
		const float fLostRange = exp(-fMax);
		const float fRestoreRangeScale = 1.f / (1.f - fLostRange);
		return (1.f - exp(-x)) * fRestoreRangeScale;
	}
	if (fPow != 1.f && fMax == FLT_MAX)
	{
		return (1.f - pow(exp(-x), fPow));
	}
	const float fLostRange = pow(exp(-fMax), fPow);
	const float fRestoreRangeScale = 1.f / (1.f - fLostRange);
	return (1.f - pow(exp(-x), fPow)) * fRestoreRangeScale;
}

// Refurbished DICE HDR tonemapper (per channel or luminance)
float luminanceCompress(float fInValue, float fOutMaxValue, float fShoulderStart = 0.f, float fInMaxValue = FLT_MAX, float fModulationPow = 1.f)
{
	float fCompressableValue = fInValue - fShoulderStart;
	float fCompressableRange = fInMaxValue - fShoulderStart;
	float fCompressedRange = fOutMaxValue - fShoulderStart;
	float fPossibleOutValue = fShoulderStart + fCompressedRange * rangeCompressPow(fCompressableValue / fCompressedRange, fCompressableRange / fCompressedRange, fModulationPow);
	return fInValue <= fShoulderStart ? fInValue : fPossibleOutValue;
}
