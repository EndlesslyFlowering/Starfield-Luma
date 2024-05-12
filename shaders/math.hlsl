#pragma once

#define FLT_MIN asfloat(0x00800000) //1.175494351e-38f
#define FLT_MAX asfloat(0x7F7FFFFF) //3.402823466e+38f
#define FLT10_MAX 64512.f
#define FLT11_MAX 65024.f
#define FLT16_MAX 65504.f

// From old to new range (just a remap function)
template<class T>
T linearNormalization(T input, T min, T max, T newMin, T newMax)
{
	return ((input - min) * ((newMax - newMin) / (max - min))) + newMin;
}

float average(float3 color)
{
	return (color.x + color.y + color.z) / 3.f;
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
	const float compressedRange = max(OutMaxValue - ShoulderStart, FLT_MIN);
	const float possibleOutValue = ShoulderStart + compressedRange * rangeCompress(compressableValue / compressedRange, considerMaxValue ? (compressableRange / compressedRange) : FLT_MAX, ModulationPow);
	return InValue <= ShoulderStart ? InValue : possibleOutValue;
}

// Takes coordinates centered around zero, and a normal for a cube of side size 1, both with origin at 0.
// The normal is expected to be negative/inverted (facing origin) (basically it's just the cube side).
bool cubeCoordinatesIntersection(out float3 intersection, float3 coordinates, float3 sideNormal)
{
    if (dot(sideNormal, coordinates) >= -1.f)
        return false; // No intersection, the line is parallel or facing away from the plane
    // Compute the X value for the directed line ray intersecting the plane
    float t = -1.f / dot(sideNormal, coordinates);
    intersection = coordinates * t;
    return true;
}

// Clamps cube coordinates (e.g. 3D LUT) within 0-1, but instead of just doing a saturate(),
// if the coordinates go beyond the cube range, it finds their intersection point.
float3 clampCubeCoordinates(float3 coordinates, out bool clamped, bool clampFromCenter)
{
	clamped = false;
	
	// Avoid false positives around 0 and 1 coordinates (due to floating point accuracy errors we need to threshold)
#if 1
	if (length(coordinates - saturate(coordinates)) <= FLT_MIN)
#else
	if (all(coordinates == saturate(coordinates)) || all(normalize(coordinates - saturate(coordinates)) == 0.f))
#endif
		return coordinates;

	const float3 originalCoordinates = coordinates;
	// Shift range from [0,1] to [-1,+1]
	// The cube will be around that exact range
	if (clampFromCenter)
		coordinates = (coordinates - 0.5f) * 2.f;

	const float3 coordinatesSigns = sign(coordinates);
	// Do abs to restrict the possible intersections from 6 to 3 cube faces
	if (clampFromCenter)
		coordinates = abs(coordinates);

	float3 bestIntersection;
	float3 currentIntersection;
	float intersection1Length = FLT_MAX;
	float intersection2Length = FLT_MAX;
	float intersection3Length = FLT_MAX;
	bool foundIntersection = false;
	// Find the closest intersection with each cube edge as a plane (multiple planes would intersect, likely all 3)
	if (cubeCoordinatesIntersection(currentIntersection, coordinates, float3(-1.f, 0.f, 0.f)))
	{
		foundIntersection = true;
		intersection1Length = length(currentIntersection);
		bestIntersection = currentIntersection;
	}
	if (cubeCoordinatesIntersection(currentIntersection, coordinates, float3(0.f, -1.f, 0.f)))
	{
		foundIntersection = true;
		intersection2Length = length(currentIntersection);
		if (intersection2Length < intersection1Length)
			bestIntersection = currentIntersection;
	}
	if (cubeCoordinatesIntersection(currentIntersection, coordinates, float3(0.f, 0.f, -1.f)))
	{
		foundIntersection = true;
		intersection3Length = length(currentIntersection);
		if (intersection3Length < intersection1Length && intersection3Length < intersection2Length)
			bestIntersection = currentIntersection;
	}

	if (!foundIntersection /*|| length(coordinates - bestIntersection) <= 0.000001f*/)
		return originalCoordinates;

	coordinates = bestIntersection;
	clamped = true;

	if (clampFromCenter)
	{
		coordinates *= coordinatesSigns; // Revert abs

		coordinates = (coordinates * 0.5f) + 0.5f;
	}
	return coordinates;
}