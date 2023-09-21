#include "../shared.h"

// Hack: change the alpha value at which the UI blends in in HDR, to increase readability. Range is 0 to 1, with 1 having no effect.
#define HDR_UI_BLEND_POW 0.775f
#define HDR_GAMMA_CORRECTION 1

struct PushConstantWrapper_ScaleformCompositeLayout
{
    int Unknown1;
    int Unknown2;
};

cbuffer stub_PushConstantWrapper_ScaleformCompositeLayout : register(b0)
{
    PushConstantWrapper_ScaleformCompositeLayout Layout : packoffset(c0);
};

Texture2D<float4> inputTexture : register(t0, space8);
SamplerState inputSampler : register(s0, space8);

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

struct PSInputs
{
    float4 uv : TEXCOORD0;
    float4 pos : SV_Position;
};

float4 PS(PSInputs inputs) : SV_Target
{
    float4 UIColor = inputTexture.Sample(inputSampler, float2(inputs.uv.x, inputs.uv.y));
    float UIIntensity = asfloat(Layout.Unknown1);

    UIColor.xyz = gamma_sRGB_to_linear(UIColor.xyz);
    UIColor.xyz = UIColor.xyz * UIIntensity;
#if !ENABLE_HDR
    UIColor.xyz = gamma_linear_to_sRGB(UIColor.xyz);
#else
#if HDR_GAMMA_CORRECTION
    UIColor.xyz = pow(gamma_linear_to_sRGB(UIColor.xyz), 2.2f);
#endif
    UIColor.xyz *= HDR_UI_PAPER_WHITE;
    // Scale alpha to emulate sRGB gamma blending (we blend in linear space in HDR),
    // this won't ever be perfect but it's close enough for most cases.
    // We do a saturate to avoid pow of -0, which might lead to unexpected results.
    //UIColor.a = pow(saturate(UIColor.a), HDR_UI_BLEND_POW); //TODO: base the percentage of application of "HDR_UI_BLEND_POW" based on how black/dark the UI color is.
#endif // ENABLE_HDR

    return UIColor;
}
