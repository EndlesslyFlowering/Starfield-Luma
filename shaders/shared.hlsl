#pragma once

#include "structs.hlsl"

// Turn on when developing to engage error checks and development setting variables
#define DEVELOPMENT 1

// Preset all defines to be as close as possible to the og game vanilla look
#define FORCE_VANILLA_LOOK 0
#define CLAMP_INPUT_OUTPUT 1
// If this is true, the code makes the assumption that Bethesda developed and calibrated the game on gamma 2.2 screens, as opposed to sRGB gamma.
// This implies there was a mismatch baked in the output colors, as they were using a ~sRGB similar formula, which would then be interpreted by screens as 2.2 gamma.
// By turning this on, we emulate the SDR look in HDR by baking that assumption into our calculations.
// This makes sense to use given we fix up (normalize) the LUTs colors and their gamma mapping.
#define SDR_USE_GAMMA_2_2 (FORCE_VANILLA_LOOK ? 0 : 1)

// Makes LUTs sampling work in linear space, which is mathematically correct. Without this, they are stored as ~sRGB in a float texture and sampled in sRGB without acknowledging it.
// This possibly shifts colors a lot, but it's correct, it's also necessary for HDR LUTs to work.
#define LUT_FIX_GAMMA_MAPPING (FORCE_VANILLA_LOOK ? 0 : 1)
#define LUT_SIZE 16.f
#define LUT_SIZE_UINT (uint)LUT_SIZE

// Brings the range roughly from 80 nits to 203 nits (~2.5)
#define HDR_REFERENCE_PAPER_WHITE_MUTLIPLIER (ReferenceWhiteNits_BT2408 / WhiteNits_BT709)

// Custom push constants uploaded by the HDR DLL plugin code. Do note that register space comes at a premium when adding members. Bit/byte packing is advised.
struct StructHdrDllPluginConstants
{
	uint DisplayMode; // SDR 0 (Rec.709 with 2.2 gamma, not sRGB), 1 HDR10 PQ BT.2020, 2 scRGB HDR
	float HDRPeakBrightnessNits; // Set equal to the max nits your display can output
	float HDRGamePaperWhiteNits; // 203 is the reference value (ReferenceWhiteNits_BT2408)
	float HDRUIPaperWhiteNits; // 203 is the reference value (ReferenceWhiteNits_BT2408)
	float HDRLUTCorrectionSaturation; // 1 is neutral
	float HDRSecondaryContrast; // 1 is neutral
	float LUTCorrectionStrength; // 1 is full strength
	float ColorGradingStrength; // 1 is full strength
	uint FilmGrainType; // 1 is default
	uint PostSharpen; // true is default
	uint IsAtEndOfFrame;
	uint RuntimeMS;
	float DevSetting01; // 0-1 variable for development
	float DevSetting02; // 0-1 variable for development
	float DevSetting03; // 0-1 variable for development
	float DevSetting04; // 0-1 variable for development
	float DevSetting05; // 0-1 variable for development
};

//TODO: use this in the root signature files?
#define HDR_PLUGIN_CONSTANTS_SIZE 17

ConstantBuffer<StructHdrDllPluginConstants> HdrDllPluginConstants : register(b3, space0);
