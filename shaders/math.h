#ifndef MATH_H
#define MATH_H

#define FLT_MAX 3.402823466e+38F

float hypot3(float3 input)
{
	float3 inputSquared = input * input;
	return sqrt(inputSquared.x + inputSquared.y + inputSquared.z);
}

// From old to new range
template<class T>
T linearNormalization(T input, float min, float max, float newMin, float newMax)
{
	return ((input - min) * ((newMax - newMin) / (max - min))) + newMin;
}

#endif