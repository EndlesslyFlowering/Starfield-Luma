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

// 0 None, 1 ShortFuse technique (normalization), 2 luminance preservation (doesn't look so good and it's kinda broken), 3 tonemapper LUT lost luminance restore (improved iteration of type 2)
#define LUT_IMPROVEMENT_TYPE 1
// Makes LUTs sampling work in linear space, which is mathematically correct. Without this, they are stored as ~sRGB in a float texture and sampled in sRGB without acknowledging it.
// This possibly shifts colors a lot, but it's correct, it's also necessary for HDR LUTs to work.
#define LUT_FIX_GAMMA_MAPPING 1
#define LUT_SIZE 16.f
#define LUT_SIZE_UINT (uint)LUT_SIZE

static float LUTCorrectionPercentage = 1.f;
