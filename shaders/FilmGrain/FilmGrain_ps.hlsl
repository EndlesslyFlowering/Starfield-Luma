#include "../shared.hlsl"
#include "../color.hlsl"
#include "RootSignature.hlsl"

#define FILM_GRAIN_TEXTURE_SIZE 1024u

// 0 Vanilla, 1 New Random (no flicker/repeating), 2 New random, no raised blacks
#define FILM_GRAIN_TYPE 0

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

// Better random generator
float rand(float2 uv) {
	return frac(sin(dot(uv,float2(12.9898,78.233)))*43758.5453123);
}


// Returns a random number between 0 and 1 based on seed
float bethesdaRandom(float seed) {
	return frac(sin(seed) * 493013.f);
}


void frag_main()
{
// TEXCOORD = float2 [0,1] relative to screen
// TonemappedColorTexture is the framebuffer?
// Generate random noise and overlay on top of screen buffer
// filmGrainColorAndIntensity
//   .x - randomInt32? changed every frame?
//   .y = randomInt32? changed every frame?
//   .z = Film Grading Intensity (0 - 0.03)

	float3 tonemappedColor = TonemappedColorTexture.Sample(Sampler0, float2(TEXCOORD.x, TEXCOORD.y));
#if ENABLE_HDR
	tonemappedColor /= HDR_GAME_PAPER_WHITE;
	tonemappedColor = gamma_linear_to_sRGB(tonemappedColor);
#endif // ENABLE_HDR
float colorY = Luminance(tonemappedColor);

#if FILM_GRAIN_TYPE == 0
	const float filmGrainInvSize = 1.f / (FILM_GRAIN_TEXTURE_SIZE - 1u);
	const float filmGrainHalfSize = 521.f; //TODO: rename in case we keep this as 521
	// Applying modulus against 1023 will give value between 0 and 1023
	// Same two values for all texels this frame
	float randomFromRange1 = float(int(uint(filmGrainColorAndIntensity.x) & (FILM_GRAIN_TEXTURE_SIZE - 1u)));
	float randomFromRange2 = float(int(uint(filmGrainColorAndIntensity.y) & (FILM_GRAIN_TEXTURE_SIZE - 1u)));

	// Divide by 1023 to get a number between 0 and 1
	float randomNormalized1 = randomFromRange1 * filmGrainInvSize;
	float randomNormalized2 = randomFromRange1 * filmGrainInvSize;

	// Offset by x/y position
	float uniqueX = randomNormalized1 + TEXCOORD.x;
	float uniqueY = (randomNormalized2 + TEXCOORD.y) * filmGrainHalfSize;

	// Unique each frame and texel. (Is it though?)
	float seed = (uniqueX + uniqueY);

	// Generate a random number between 0 and 1;
	float randomNumber = bethesdaRandom(seed);
#else
	float randomNumber = rand(TEXCOORD.xy
		+ frac(filmGrainColorAndIntensity.x / 2147483647.f)
		+ frac(filmGrainColorAndIntensity.y / 2147483647.f)
	);
#endif // FILM_GRAIN_TYPE == 0

#if FILM_GRAIN_TYPE != 2
	float inverseLuminance = saturate(1.f - colorY);
	// luminanceShift at -1 is black, 0 unchanged, 1 negative of current texel
	float luminanceShift = (randomNumber * 2.f) - 1.f;
	float additiveFilmGrain = (luminanceShift * filmGrainColorAndIntensity.z * inverseLuminance);
#else
	float additiveFilmGrain = ((randomNumber * 2.f) - 1.f) // (-1 to 1)
		* (2.f* (0.5f - abs(colorY - 0.5f))) // Bias towards center (nothing if black or white)
		* filmGrainColorAndIntensity.z
		* 3.333f;
#endif // FILM_GRAIN_TYPE != 2

	float3 newColor = float3(additiveFilmGrain, additiveFilmGrain,additiveFilmGrain);

	// Use addition to overlay color on top
	// Note: we let this possibly generate colors below 1 for scRGB
	float3 tonemappedColorWithFilmGrain = tonemappedColor + newColor;


#if 0 // WIP fixes
	// Right side only
	if (TEXCOORD.x < 0.5f) {
		tonemappedColorWithFilmGrain = tonemappedColor;
	}
#endif

#if ENABLE_HDR
	tonemappedColorWithFilmGrain = gamma_sRGB_to_linear(tonemappedColorWithFilmGrain) * HDR_GAME_PAPER_WHITE;
#endif // ENABLE_HDR

	SV_Target.rgb = tonemappedColorWithFilmGrain;

	SV_Target.w = 1.0f;
}

[RootSignature(ShaderRootSignature)]
SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
	TEXCOORD = stage_input.TEXCOORD;
	frag_main();
	SPIRV_Cross_Output stage_output;
	stage_output.SV_Target = SV_Target;
	return stage_output;
}
