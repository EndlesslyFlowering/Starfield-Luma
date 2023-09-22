#ifndef COLOR_H
#define COLOR_H

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

#endif