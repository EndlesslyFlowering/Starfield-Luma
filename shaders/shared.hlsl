#pragma once

#include "structs.hlsl"

// Enables HDR scRGB output. If false, we output Rec.709 in gamma space (~sRGB).
#define ENABLE_HDR 1
// Set equal to the max nits your display can output
#define HDR_MAX_OUTPUT_NITS 1000.f
// Brings the range roughly from 80 nits to 200 nits (close to the target reference of 203 nits)
#define HDR_GAME_PAPER_WHITE 1.f
#define HDR_UI_PAPER_WHITE 2.5f


// This possibly shifts colors a lot, but it's mathematically correct, it's also necessary for HDR LUTs to work.
#define LUT_FIX_GAMMA_MAPPING 1
#define LUT_CUSTOM_STRENGTH 1
#define LUT_ADDITIONAL_NEUTRAL_PERCENTAGE 1
#define LUT_SIZE 16.f
#define LUT_SIZE_UINT (uint)LUT_SIZE

// 0 None, 1 ShortFuse technique (normalization), 2 luminance preservation (doesn't look so good)
#define LUT_IMPROVEMENT_TYPE 1
