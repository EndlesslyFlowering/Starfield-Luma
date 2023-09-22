#ifndef SHARED_H
#define SHARED_H

#define ENABLE_HDR 1
#define HDR_GAME_PAPER_WHITE 1.f
#define HDR_UI_PAPER_WHITE 2.5f
// This possibly shifts colors a lot, but it's mathematically correct, it's also necessary for HDR LUTs to work.
#define FIX_LUT_GAMMA_MAPPING 1
#define LUT_SIZE 16.f

#endif