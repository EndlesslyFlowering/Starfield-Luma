#pragma once

#include "structs.hlsl"

// Turn on when developing to engage error checks and development setting variables
#define DEVELOPMENT 0

// Preset all defines to be as close as possible to the og game vanilla look
#define FORCE_VANILLA_LOOK 0
// 0 No in-out clamping.
// 1 Gamut map final output only.
// 2 Clamp final output only (with raw rgb clipping).
// 3 Clamp many shader passes input and output.
// 4 Clamp many shader passes input and output, including the first input (HDRComposite pixel shader).
#define CLAMP_INPUT_OUTPUT_TYPE (FORCE_VANILLA_LOOK ? 3 : 1)
// If this is true, the code makes the assumption that Bethesda developed and calibrated the game on gamma 2.2 screens, as opposed to sRGB gamma.
// This implies there was a mismatch baked in the output colors, as they were using a ~sRGB similar formula, which would then be interpreted by screens as 2.2 gamma.
// By turning this on, we emulate the SDR look in HDR (and out SDR) by baking that assumption into our calculations.
// This makes sense to use given we fix up (normalize) the LUTs colors and their gamma mapping.
#define SDR_USE_GAMMA_2_2 (FORCE_VANILLA_LOOK ? 0 : 1)

// If true, SDR will be kept in linear space until the final out.
// This is desired for output quality as we store colors on float buffers, which are based kept in linear space,
// it also simplifies the code and optmizes performance, but at the moment is changes the look of the Scaleform UI blend in.
#define SDR_LINEAR_INTERMEDIARY (FORCE_VANILLA_LOOK ? 0 : 1)

// 0 None, 1 Scale with Black Linear 2 Remove Black SRGB Values
#define LUT_IMPROVEMENT_TYPE (FORCE_VANILLA_LOOK ? 0 : 2)
#define MAINTAIN_CORRECTED_LUTS_TINT_AROUND_BLACK (LUT_IMPROVEMENT_TYPE == 1)


// Determines what kind of color space/gamut/gamma the merged/mixed LUT is in.
// 0) sRGB gamma mapping (Vanilla): the most mathematically correct way of mapping LUTs.
// 1) Linear mapping: Makes LUTs sampling work in linear space. This possibly shifts colors a bit, and is less mathematically correct, though it's faster and avoids using SDR gamma on LUTs colors that might be in the HDR range (which would be fine anyway).
//    Other than performance, this helps a bit with accuracy, as LUTs are stored in linear FP16 textures in SF, thus storing values in gamma space isn't the smartest choice.
// 2) Linear mapping + OKLAB blending: Blend multiple LUTs (by their respective percentage) in OKLab colorspace before returning as Linear SRGB. Identical to index 1 when there's only one LUT applied.
// 3) REMOVED: OKLAB mapping: this has a lot of advantages, like allowing the blackest LUT texel (coords 0 0 0) to also have a hue, so it can contribute to tinting the image even near black,
//    the problem with this is that near black blending is very different compared to sRGB gamma or linear, crushing blacks without further adjustments.
//    "MAINTAIN_CORRECTED_LUTS_TINT_AROUND_BLACK" has since then fixed the near black ting problem in a different way.
#define LUT_MAPPING_TYPE (FORCE_VANILLA_LOOK ? 0 : 2)
#define LUT_SIZE 16.f
#define LUT_SIZE_UINT (uint)LUT_SIZE
#define LUT_MAX_UINT (uint)(LUT_SIZE - 1u)
// If true, we do gamma correction directly in LUTs (in sRGB, out 2.2), if not, we do it after.
// Doing it in LUTs is quicker, but it can sensibly affect results, as LUTs only have a limited amount of precisions and they have nearly no samples around the part where 2.2 and sRGB have the biggest mismatch.
// Requires "SDR_USE_GAMMA_2_2".
// Cannot be set to false with "LUT_MAPPING_TYPE" == 3 (removed), as the point of doing LUTs mapping in OKLAB is for the blackest point to have no luminosity but still have a hue
// to help out with tinting the dakest 1/16 part of the image, thus if we convert back from OKLAB to Rec.709 to OKLAB, we'd lose the hue on black, due to having no luminance.
// NOTE: to avoid hue shift from gamma correction, we could do gamma correction by luminance instead of by channel, though the hue shift is kind of "correct".
#define GAMMA_CORRECTION_IN_LUTS 1
#define FORCE_SDR_LUTS 0

// Brings the range roughly from 80 nits to 203 nits (~2.5)
#define HDR_REFERENCE_PAPER_WHITE_MUTLIPLIER (ReferenceWhiteNits_BT2408 / WhiteNits_sRGB)

// Custom push constants uploaded by the HDR DLL plugin code. Do note that register space comes at a premium when adding members. Bit/byte packing is advised.
// Bools are set as uint to avoid padding inconsistencies between c++ and hlsl.
struct StructHdrDllPluginConstants
{
	int DisplayMode; // -1 SDR on scRGB HDR, 0 SDR (Rec.709 with 2.2 gamma, not sRGB), 1 HDR10 PQ BT.2020, 2 scRGB HDR
	float HDRPeakBrightnessNits; // Set equal to the max nits your display can output
	float HDRGamePaperWhiteNits; // 203 is the reference value (ReferenceWhiteNits_BT2408)
	float HDRUIPaperWhiteNits; // 203 is the reference value (ReferenceWhiteNits_BT2408)
	float HDRExtendGamut; // 0-1. 0 is neutral

	float SDRSecondaryBrightness; // 0-2. Only meant for SDR. 1 is neutral

	uint ToneMapperType; // Overrides tonemapper type. 0 is default (not overridden)
	float ToneMapperSaturation; // 0.5-1.5. 1 is neutral
	float ToneMapperContrast; // 0.5-1.5. 1 is neutral
	float ToneMapperHighlights; // 0-1. 0.5 is "neutral"
	float ToneMapperShadows; // 0-1. 0.5 is neutral
	float ToneMapperBloom; // 0-1. 0.5 is neutral

	float ColorGradingStrength; // 1 is full strength
	float LUTCorrectionStrength; // 1 is full strength
	uint StrictLUTApplication; // false is default (true looks more like vanilla SDR)

	float GammaCorrection; // Application percentage of "SDR_USE_GAMMA_2_2" correction from LUTs. 0 to 1. 1 is "neutral"
	uint FilmGrainType; // 1 is default
	float FilmGrainFPSLimit; // 24 and 0 are common defaults
	uint PostSharpen; // true is default

	uint IsAtEndOfFrame;
	uint RuntimeMS;
	float DevSetting01; // 0-1 variable for development. Default 0
	float DevSetting02; // 0-1 variable for development. Default 0
	float DevSetting03; // 0-1 variable for development. Default 0
	float DevSetting04; // 0-1 variable for development. Default 0.5
	float DevSetting05; // 0-1 variable for development. Default 0.5
};

#define HDR_PLUGIN_CONSTANTS_SIZE "26"

ConstantBuffer<StructHdrDllPluginConstants> HdrDllPluginConstants : register(b3, space0);
