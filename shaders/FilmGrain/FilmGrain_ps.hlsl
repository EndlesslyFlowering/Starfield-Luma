#include "../math.hlsl"
#include "../shared.hlsl"
#include "../color.hlsl"
#include "RootSignature.hlsl"

#define FILM_GRAIN_TEXTURE_SIZE 1024

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

cbuffer CPushConstantWrapper_FilmGrain : register(b0, space0)
{
	float4 filmGrainColorAndIntensity : packoffset(c0);
};

Texture2D<float3> TonemappedColorTexture : register(t0, space8); // Possibly in gamma space in SDR
SamplerState Sampler0 : register(s0, space8);

struct PSInput
{
	float4 TEXCOORD : TEXCOORD0;
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


[RootSignature(ShaderRootSignature)]
float4 PS(PSInput psInput) : SV_Target
{
// TEXCOORD = float2 [0,1] relative to screen
// TonemappedColorTexture is the framebuffer?
// Generate random noise and overlay on top of screen buffer
// filmGrainColorAndIntensity
//   .x - randomInt32? changed every frame?
//   .y = randomInt32? changed every frame?
//   .z = Film Grading Intensity (0 - 0.03)

	const float3 inputColor = TonemappedColorTexture.Sample(Sampler0, psInput.TEXCOORD.xy);
	bool isHDR = HdrDllPluginConstants.DisplayMode > 0;
	bool isInOutColorLinear = isHDR;
#if SDR_LINEAR_INTERMEDIARY
	isInOutColorLinear |= HdrDllPluginConstants.DisplayMode <= 0;
#endif // SDR_LINEAR_INTERMEDIARY

	float3 outputColor;

	if (HdrDllPluginConstants.FilmGrainType == 0)
	{
		float3 color = inputColor;

		float filmGrainIntensity = filmGrainColorAndIntensity.z;

		float luminance;

		if (isInOutColorLinear) {
			color /= PQMaxWhitePoint;

			// get relative luminance in normalized space
			luminance = Luminance(color);

			color = BT709_To_AP0D65(color);

			color = Linear_to_PQ_approx(color);
		}
		else {
			luminance = Luminance(GAMMA_TO_LINEAR(color));
		}

		float inverseLuminance = saturate(1.f - luminance);

		static const float filmGrainInvSize = 1.f / (FILM_GRAIN_TEXTURE_SIZE - 1);
		static const float filmGrainHalfSize = 511.f;
		// Applying modulus against 1023 will give value between 0 and 1023
		// Same two values for all texels this frame
		float2 randomFromRange = int2(filmGrainColorAndIntensity.xy) & (FILM_GRAIN_TEXTURE_SIZE - 1);

		// Divide by 1023 to get a number between 0 and 1
		float2 randomNormalized = randomFromRange * filmGrainInvSize;

		// Offset by x/y position
		float2 unique = randomNormalized + psInput.TEXCOORD.xy;
		unique.y *= filmGrainHalfSize;

		// Unique each frame and texel. (Is it though?)
		float seed = (unique.x + unique.y);

		// Generate a random number between 0 and 1;
		float randomNumber = bethesdaRandom(seed);

		float luminanceShift = (randomNumber * 2.f) - 1.f;

		float additiveFilmGrain = (luminanceShift * (filmGrainIntensity * inverseLuminance));

		outputColor = color + additiveFilmGrain;

		if (isInOutColorLinear)
		{
			outputColor = PQ_approx_to_Linear(outputColor);

			outputColor = max(outputColor, 0.f);
			outputColor = AP0D65_To_BT709(outputColor);

			outputColor *= PQMaxWhitePoint;
		}

#if 0 // Output Visualization
	float oldY = Luminance(GAMMA_TO_LINEAR(linearColor));
	float newY = Luminance(GAMMA_TO_LINEAR(outputColor));
	float yChange = (oldY/newY) - 1.f;
	outputColor = abs(yChange);
#endif

	}
	else
	{
		float fps = HdrDllPluginConstants.FilmGrainCap;
		// Mod by FPS to ensure consistent range
		float2 seed = psInput.TEXCOORD.xy;
		if (fps > 0.f) {
			float frameNumber = floor(HdrDllPluginConstants.RuntimeMS / (1000.f/(fps)));
			// TODO: Use iteration? Use only if repeating is noticeable
			// float iteration = fmod(frameNumber, (fps * fps));
			float frame = fmod(frameNumber, fps);
			seed += (frame / fps);
		} else {
			seed += frac(HdrDllPluginConstants.RuntimeMS / 1000.f);
		}

		float randomNumber = rand(seed);

		float colorY;

		float3 linearColor = inputColor;
		if (isInOutColorLinear) {
			linearColor /= PQMaxWhitePoint;

			// get relative luminance in normalized space
			colorY = Luminance(linearColor);

			linearColor = BT709_To_AP0D65(linearColor);

			// approximation of PQ
			linearColor = Linear_to_PQ_approx(linearColor);
		}
		else {
			colorY = Luminance(GAMMA_TO_LINEAR(linearColor));
		}
		// Film grain is based on film density
		// Film works in negative, meaning black has no density
		// The greater the film density (lighter), more perceived grain
		// Simplified, grain scales with Y

		// Scaling is not not linear

		float yAdjustment = isHDR
			? (HdrDllPluginConstants.HDRGamePaperWhiteNits / PQMaxWhitePoint)
			: 1.f;

		float adjustedColorY = linearNormalization(colorY,0.f,yAdjustment,0.f,1.f);
		//float adjustedColorY = colorY;

		// Emulate density from a chosen film stock (Removed)
		// float density = computeFilmDensity(adjustedColorY);

		// Ideal film density matches 0-3. Skip emulating film stock
		// https://www.mr-alvandi.com/technique/measuring-film-speed.html
		float density = adjustedColorY * 3.f;

		float graininess = computeFilmGraininess(density);
		float randomFactor = (randomNumber * 2.f) - 1.f;

		float yChange = randomFactor
			* graininess
			* filmGrainColorAndIntensity.z // fFilmGrainAmountMax (0.03)
			* 3.333f; // Bump to 10%

		yChange *= 0.0666f;

		outputColor = linearColor * (1.f + yChange);

		if (isInOutColorLinear) {
			outputColor = PQ_approx_to_Linear(outputColor);

			outputColor = max(outputColor, 0.f);
			outputColor = AP0D65_To_BT709(outputColor);

			outputColor *= PQMaxWhitePoint;
		}

#if 0 // Output Visualization
		outputColor = abs(yChange);
#endif
	}

	return float4(isHDR ? outputColor
	                    : saturate(outputColor), 1.f);
}
