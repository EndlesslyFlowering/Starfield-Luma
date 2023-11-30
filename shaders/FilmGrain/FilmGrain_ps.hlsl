#include "../math.hlsl"
#include "../shared.hlsl"
#include "../color.hlsl"
#include "RootSignature.hlsl"

#define FILM_GRAIN_TEXTURE_SIZE 1024u

#if SDR_LINEAR_INTERMEDIARY
	#define GAMMA_TO_LINEAR(x) x
	#define LINEAR_TO_GAMMA(x) x
#elif SDR_USE_GAMMA_2_2
	#define GAMMA_TO_LINEAR(x) pow(x, 2.2f)
	#define LINEAR_TO_GAMMA(x) pow(x, 1.f / 2.2f)
#else
	#define GAMMA_TO_LINEAR(x) gamma_sRGB_to_linear(x)
	#define LINEAR_TO_GAMMA(x) gamma_linear_to_sRGB(x)
#endif

#define IMPROVED_FILM_GRAIN true

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
// (0.5, 0.22)
// (1.5, 1.08)
// (2.5, 2.01)
// (3.0, 2.3)
float computeFilmDensity(float luminance) {
	float scaledX = luminance * 3.0f;
	float result = 3.386477f + (0.08886645f - 3.386477f)/pow(1.f + (scaledX/2.172591f),2.240936f);
	return result;
}

// Bartleson
// https://www.imaging.org/common/uploaded%20files/pdfs/Papers/2003/PICS-0-287/8583.pdf
float computeFilmGraininess(float density) {
	float preComputedMin = 7.5857757502918375f;
	float bofDOverC = 0.880f - (0.736f * density) - (0.003f * pow(density, 7.6f));
	return pow(10.f, bofDOverC);
}


void frag_main()
{
// TEXCOORD = float2 [0,1] relative to screen
// TonemappedColorTexture is the framebuffer?
// Generate random noise and overlay on top of screen buffer
// filmGrainColorAndIntensity
//   .x - randomInt32? changed every frame?
//   .y = randomInt32? changed every frame?
//   .z = Film Grading Intensity (fFilmGrainAmountMax=0.03)

	const float3 inputColor = TonemappedColorTexture.Sample(Sampler0, float2(TEXCOORD.x, TEXCOORD.y));
	bool isHDR = HdrDllPluginConstants.DisplayMode > 0;
	bool isInOutColorLinear = isHDR;
#if SDR_LINEAR_INTERMEDIARY
	isInOutColorLinear |= HdrDllPluginConstants.DisplayMode <= 0;
#endif // SDR_LINEAR_INTERMEDIARY

	float3 outputColor;

	if (HdrDllPluginConstants.FilmGrainType == 0)
	{
		float3 gammaColor = (isInOutColorLinear)
			? LINEAR_TO_GAMMA(inputColor)
			: inputColor;

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

		float colorLuma = Luminance(gammaColor);
		float inverseLuma = saturate(1.f - colorLuma); // inverseLuma

		float luminanceShift = (randomNumber * 2.f) - 1.f;

		float additiveFilmGrain = (luminanceShift * filmGrainColorAndIntensity.z * inverseLuma);
		float3 newColor = float3(additiveFilmGrain, additiveFilmGrain, additiveFilmGrain);

		outputColor = gammaColor + newColor;

#if 0 // Output Visualization
	float oldY = Luminance(GAMMA_TO_LINEAR(gammaColor));
	float newY = Luminance(GAMMA_TO_LINEAR(outputColor));
	float yChange = (oldY/newY) - 1.f;
	outputColor = abs(yChange);
#endif

		if (isInOutColorLinear)
		{
			outputColor = GAMMA_TO_LINEAR(outputColor);
		}
	}
	else
	{
		float fps = HdrDllPluginConstants.FilmGrainFPSLimit;
		// Mod by FPS to ensure consistent range.
		// Note: we still don't know if "RuntimeMS" is stable over time, though it should be ok.
		float2 seed = TEXCOORD.xy;
		if (fps > 0.f) {
			float frameNumber = floor(HdrDllPluginConstants.RuntimeMS / (1000.f / fps));
			// TODO: Use iteration? Use only if repeating is noticeable
			// float iteration = fmod(frameNumber, (fps * fps));
			float frame = fps == 1.f ? fmod(frameNumber, 2) : fmod(frameNumber, fps); // fmod(1,1) doesn't work
			seed += frame / fps;
		} else {
			seed += frac(HdrDllPluginConstants.RuntimeMS / 1000.f);
		}

		float randomNumber = rand(seed);

		float3 linearColor = (isHDR)
			? BT709_To_WBT2020(inputColor)
			: (isInOutColorLinear)
			? inputColor
			: GAMMA_TO_LINEAR(inputColor);
		// Film grain is based on film density
		// Film works in negative, meaning black has no density
		// The greater the film density (lighter), more perceived grain
		// Simplified, grain scales with Y

		// Scaling is not not linear

		float colorY = Luminance(linearColor);

		float yAdjustment = isHDR
			? (HdrDllPluginConstants.HDRGamePaperWhiteNits / WhiteNits_sRGB)
			: 1.f;

		float adjustedColorY = linearNormalization(colorY,0.f,yAdjustment,0.f,1.f);

		// Emulate density from a chosen film stock (Removed)
		// float density = computeFilmDensity(adjustedColorY);

		// Ideal film density matches 0-3. Skip emulating film stock
		// https://www.mr-alvandi.com/technique/measuring-film-speed.html
		float density = adjustedColorY * 3.f;

		float graininess = computeFilmGraininess(density);
		float randomFactor = (randomNumber * 2.f) - 1.f;
		float boost = 1.667f; // Boost max to 0.05

		float yChange = randomFactor * graininess * filmGrainColorAndIntensity.z * boost;

		outputColor = linearColor * (1.f + yChange);

#if 0 // Output Visualization
		outputColor = abs(yChange);
#endif

		if (isHDR) {
			outputColor = max(outputColor, 0.f);
			outputColor = WBT2020_To_BT709(outputColor);
		}
		else if (!isInOutColorLinear) {
			outputColor = saturate(outputColor);
			outputColor = LINEAR_TO_GAMMA(outputColor);
		}
	}

	SV_Target.rgb = outputColor;

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
