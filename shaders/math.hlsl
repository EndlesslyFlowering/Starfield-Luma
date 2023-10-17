#pragma once

#define FLT_MIN 1.175494351e-38f
#define FLT_MAX 3.402823466e+38F
#define FLT10_MAX 64512.f
#define FLT11_MAX 65024.f
#define FLT16_MAX 65504.f

// From old to new range (just a remap function)
template<class T>
T linearNormalization(T input, T min, T max, T newMin, T newMax)
{
	return ((input - min) * ((newMax - newMin) / (max - min))) + newMin;
}

// Returns 1 if "dividend" is 0
float safeDivision(float quotient, float dividend)
{
	float result = quotient / dividend;

	if (dividend == 0.f)
	{
#if 0
		result = FLT_MAX * sign(quotient);
#else
		result = 1.f;
#endif
	}

	return result;
}

// Returns 1 if "dividend" is 0
float3 safeDivision(float3 quotient, float3 dividend)
{
	return float3(safeDivision(quotient.x, dividend.x),
	              safeDivision(quotient.y, dividend.y),
	              safeDivision(quotient.z, dividend.z));
}

// Aplies exponential ("Photographic") luminance/luma compression.
// The pow can modulate the curve without changing the values around the edges.
float rangeCompress(float X, float Max = FLT_MAX, float Pow = 1.f)
{
	// Branches are for static parameters optimizations
	if (Pow == 1.f && Max == FLT_MAX)
	{
		// This does e^X. We expect X to be between 0 and 1.
		return 1.f - exp(-X);
	}
	if (Pow == 1.f && Max != FLT_MAX)
	{
		const float fLostRange = exp(-Max);
		const float fRestoreRangeScale = 1.f / (1.f - fLostRange);
		return (1.f - exp(-X)) * fRestoreRangeScale;
	}
	if (Pow != 1.f && Max == FLT_MAX)
	{
		return (1.f - pow(exp(-X), Pow));
	}
	const float lostRange = pow(exp(-Max), Pow);
	const float restoreRangeScale = 1.f / (1.f - lostRange);
	return (1.f - pow(exp(-X), Pow)) * restoreRangeScale;
}

// Refurbished DICE HDR tonemapper (per channel or luminance)
float luminanceCompress(float InValue, float OutMaxValue, float ShoulderStart = 0.f, bool considerMaxValue = false, float InMaxValue = FLT_MAX, float ModulationPow = 1.f)
{
	const float compressableValue = InValue - ShoulderStart;
	const float compressableRange = InMaxValue - ShoulderStart;
	const float compressedRange = OutMaxValue - ShoulderStart;
	const float possibleOutValue = ShoulderStart + compressedRange * rangeCompress(compressableValue / compressedRange, considerMaxValue ? (compressableRange / compressedRange) : FLT_MAX, ModulationPow);
	return InValue <= ShoulderStart ? InValue : possibleOutValue;
}
