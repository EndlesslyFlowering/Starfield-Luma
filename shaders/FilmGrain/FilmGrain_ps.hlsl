#include "../math.hlsl"
#include "../shared.hlsl"
#include "../color.hlsl"
#include "RootSignature.hlsl"

#define FILM_GRAIN_TEXTURE_SIZE 1024u

// 1 New Random (no flicker/repeating), 2 New random, no raised blacks 3 Kodak Filmic
#define IMPROVED_FILM_GRAIN_TYPE 3

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

// This is an attempt to replicate Kodak Vision 5242 with (0,3) range:
// Should be channel independent (R/G/B), but just using R curve for now
// Reference target is actually just luminance * 2.046f;
// (0, 0)
// (0.5, 0.2)
// (1, 0.65)
// (2, 1.6)
// (3, 2.38)
float computeFilmDensity(float luminance) {
	float scaledX = luminance * 3.0f;
	float result = 4.118015f + (-0.00282387f - 4.118015f)/pow(1.f + pow(scaledX/3.024177f,1.75339f),1.262519f);
	return result;
}

// Bartleson
// https://www.imaging.org/common/uploaded%20files/pdfs/Papers/2003/PICS-0-287/8583.pdf
float computeFilmGraininess(float density) {
	float preComputedMin = 7.5857757502918375f;
	float bofDOverC = 0.880f - (0.736f * density) - (0.003f * pow(density, 7.6f));
	return linearNormalization(pow(10.f, bofDOverC), preComputedMin, 0.f, 1.f, 0.f);
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

	const float3 inputColor = TonemappedColorTexture.Sample(Sampler0, float2(TEXCOORD.x, TEXCOORD.y));
	const float paperWhite = HdrDllPluginConstants.HDRGamePaperWhiteNits / WhiteNits_BT709;
	// sRGBColor gets the luminance shift
	float3 srgbColor = inputColor;
	// linearColor is used to compute Y
	float3 linearColor = inputColor;
	
	bool isInOutColorLinear = HdrDllPluginConstants.DisplayMode > 0;
#if SDR_LINEAR_INTERMEDIARY
	isInOutColorLinear |= HdrDllPluginConstants.DisplayMode <= 0;
#endif // SDR_LINEAR_INTERMEDIARY
	if (isInOutColorLinear)
	{
		srgbColor = gamma_linear_to_sRGB(inputColor / paperWhite);
	}
	else
	{
		linearColor = gamma_sRGB_to_linear(inputColor);
	}

#if 0 // Debug Gradient
	float pixelNumber = 1.f - (TEXCOORD.y);
	linearColor = float3(pixelNumber, pixelNumber, pixelNumber);
	srgbColor = gamma_linear_to_sRGB(linearColor);
#endif

	float randomNumber, customMultiplier;

	if (HdrDllPluginConstants.FilmGrainType == 0)
	{
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
		randomNumber = bethesdaRandom(seed);

		float colorLuma = Luminance(srgbColor);
		customMultiplier = saturate(1.f - colorLuma); // inverseLuma
	}
	else
	{
		float fps = 24.f; // TODO: Make external option
		// Mod by FPS to ensure consistent range
		float frameNumber = floor(HdrDllPluginConstants.RuntimeMS / (1000.f/(fps)));
		// TODO: Use iteration? Use only if repeating is noticeable
		// float iteration = fmod(frameNumber, (fps * fps));
		float frame = fmod(frameNumber, fps); 
		randomNumber = rand(TEXCOORD.xy + (frame / fps));

#if IMPROVED_FILM_GRAIN_TYPE == 1
		float colorLuma = Luminance(srgbColor);
		customMultiplier = saturate(1.f - colorLuma); // inverseLuma
#elif IMPROVED_FILM_GRAIN_TYPE == 2
		float colorLuma = Luminance(srgbColor);
		customMultiplier = (-2.f * (0.5f - abs(saturate(colorLuma) - 0.5f))) // Bias towards center (nothing if black or white)
			* 3.333f; // Bump to 10%
#elif IMPROVED_FILM_GRAIN_TYPE == 3
		// Film grain is based on film density
		// Film works in negative, meaning black has no density
		// The greater the film density (lighter), more perceived grain
		// Simplified, grain scales with Y

		// Scaling is not not linear
		// We can estimate based on film stock.
		float colorY = Luminance(linearColor);
		float density = max(0.f, computeFilmDensity(colorY));
		float graininess = computeFilmGraininess(density);
		customMultiplier = graininess
			* Luminance(srgbColor) // Scale by perceived luma
			* 5.f; // Don't see a need to bump this more, 10.f for enthusiasts?

#endif
	}

	// luminanceShift at -1 is black, 0 unchanged, 1 negative of current texel
	float luminanceShift = (randomNumber * 2.f) - 1.f;


	float additiveFilmGrain = (luminanceShift * filmGrainColorAndIntensity.z * customMultiplier);
	float3 newColor = float3(additiveFilmGrain, additiveFilmGrain,additiveFilmGrain);

	// Use addition to overlay color on top
	// Note: we let this possibly generate colors below 1 for scRGB
	float3 tonemappedColorWithFilmGrain = srgbColor + newColor;

#if 0 // WIP fixes
	// Right side only
	if (TEXCOORD.x < 0.5f) {
		tonemappedColorWithFilmGrain = inputColor;
	}
#endif

	if (isInOutColorLinear)
	{
		tonemappedColorWithFilmGrain = gamma_sRGB_to_linear(tonemappedColorWithFilmGrain) * paperWhite;
	}

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
