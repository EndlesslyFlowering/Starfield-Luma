#define ENABLE_HDR 1
#define HDR_GAME_PAPER_WHITE 2.5f
#define FILM_GRAIN_TEXTURE_SIZE 1024u

cbuffer _13_15 : register(b0, space0)
{
    float4 filmGrainColorAndIntensity : packoffset(c0);
};

Texture2D<float3> TonemappedColorTexture : register(t0, space8); // Possibly in gamma space in SDR
SamplerState Sampler0 : register(s0, space8);

static float4 TEXCOORD;
static float4 SV_Target;

struct SPIRV_Cross_Input
{
    float4 TEXCOORD : TEXCOORD0;
};

struct SPIRV_Cross_Output
{
    float4 SV_Target : SV_Target0;
};

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

void frag_main()
{
    float3 tonemappedColor = TonemappedColorTexture.Sample(Sampler0, float2(TEXCOORD.x, TEXCOORD.y));
#if ENABLE_HDR
    tonemappedColor /= HDR_GAME_PAPER_WHITE;
    tonemappedColor = gamma_linear_to_sRGB(tonemappedColor);
    float inverseLuminance = saturate(1.f - Luminance(tonemappedColor));
#else
    float inverseLuminance = saturate(1.f - Luminance(tonemappedColor));
#endif // ENABLE_HDR
    
#if 0 // WIP fixes
    const float filmGrainInvSize = 1.f / FILM_GRAIN_TEXTURE_SIZE; // This was "1.f / (FILM_GRAIN_TEXTURE_SIZE - 1u)", though that seems incorrect
    const float filmGrainHalfSize = FILM_GRAIN_TEXTURE_SIZE * 0.5f; // This was "521.f", which seems like a mistake on 512
#else
    const float filmGrainInvSize = 1.f / (FILM_GRAIN_TEXTURE_SIZE - 1u);
    const float filmGrainHalfSize = 521.f; //TODO: rename in case we keep this as 521
#endif
    float additiveFilmGrain = (((frac(sin(((float(int(uint(filmGrainColorAndIntensity.x) & (FILM_GRAIN_TEXTURE_SIZE - 1u))) * filmGrainInvSize) + TEXCOORD.x) + (((float(int(uint(filmGrainColorAndIntensity.y) & (FILM_GRAIN_TEXTURE_SIZE - 1u))) * filmGrainInvSize) + TEXCOORD.y) * filmGrainHalfSize)) * 493013.f) * 2.f) - 1.f) * filmGrainColorAndIntensity.z) * inverseLuminance;
    float3 tonemappedColorWithFilmGrain = tonemappedColor + float3(additiveFilmGrain, additiveFilmGrain, additiveFilmGrain); // Note: we let this possibly generate colors below 1 for scRGB
#if ENABLE_HDR
    tonemappedColorWithFilmGrain = gamma_sRGB_to_linear(tonemappedColorWithFilmGrain) * HDR_GAME_PAPER_WHITE;
#endif // ENABLE_HDR

    SV_Target.xyz = tonemappedColorWithFilmGrain;
    SV_Target.w = 1.0f;
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    TEXCOORD = stage_input.TEXCOORD;
    frag_main();
    SPIRV_Cross_Output stage_output;
    stage_output.SV_Target = SV_Target;
    return stage_output;
}