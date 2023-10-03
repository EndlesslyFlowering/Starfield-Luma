#pragma once

#include "structs.hlsl"

// Enables HDR scRGB output. If false, we output Rec.709 in gamma space (~sRGB).
#define ENABLE_HDR 1
// Set equal to the max nits your display can output
#define HDR_MAX_OUTPUT_NITS 1000.f
// User configured variable
#define HDR_GAME_PAPER_WHITE_MULTIPLIER 1.f
// User configured variable
#define HDR_UI_PAPER_WHITE_MULTIPLIER 1.f
// Brings the range roughly from 80 nits to 203 nits (~2.5)
#define HDR_REFERENCE_PAPER_WHITE (ReferenceWhiteNits_BT2408 / WhiteNits_BT709)
#define HDR_GAME_PAPER_WHITE HDR_REFERENCE_PAPER_WHITE * HDR_GAME_PAPER_WHITE_MULTIPLIER
#define HDR_UI_PAPER_WHITE HDR_REFERENCE_PAPER_WHITE * HDR_UI_PAPER_WHITE_MULTIPLIER

// If this is true, the code makes the assumption that Bethesda developed and calibrated the game on gamma 2.2 screens, as opposed to sRGB gamma.
// This implies there's a mismatch baked in the output colors, as they were using a ~sRGB similar formula, which would then be interpreted by screens as 2.2 gamma.
// This makes sense to use given we fix up (normalize) the LUTs colors and their gamma mapping.
#define SDR_USE_GAMMA_2_2 1
// Emulates the SDR look of the game on an SDR display using gamma 2.2.
// Which by our best guesses should be the creative intent.
#define EMULATE_SDR_GAMMA_APPEARANCE 1

// Makes LUTs sampling work in linear space, which is mathematically correct. Without this, they are stored as ~sRGB in a float texture and sampled in sRGB without acknowledging it.
// This possibly shifts colors a lot, but it's correct, it's also necessary for HDR LUTs to work.
#define LUT_FIX_GAMMA_MAPPING 1
#define LUT_SIZE 16.f
#define LUT_SIZE_UINT (uint)LUT_SIZE
