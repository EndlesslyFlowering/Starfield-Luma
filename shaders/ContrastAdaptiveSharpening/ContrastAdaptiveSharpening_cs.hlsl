#include "../shared.hlsl"
#include "../color.hlsl"
#include "RootSignature.hlsl"

#define USE_PACKED_MATH
#define USE_UPSCALING

// this is CAS upscaling in FP16 with FFX_CAS_USE_PRECISE_MATH [100FF94]
// other variants are also available but seemingly unused, which are:
// - CAS upscaling in FP32 [200FF94]
// - CAS upscaling in FP16 with FFX_CAS_USE_PRECISE_MATH and FFX_CAS_BETTER_DIAGONALS [300FF94]
// - just CAS sharpening in FP32 [FF94]

// TODO: make full process in half not just after csp conversion? (needs matrices in half)

// don't need it
//cbuffer _16_18 : register(b0, space6)
//{
//	float4 _18_m0[8] : packoffset(c0); // _18_m0[1u].w = Gamma
//};

cbuffer CCASData : register(b0, space8)
{
	ContrastAdaptiveSharpeningData CASData : packoffset(c0);
};

Texture2D<float4>   ColorIn  : register(t0, space8);
RWTexture2D<float4> ColorOut : register(u0, space8);

struct CSInput
{
	uint3 SV_GroupID       : SV_GroupID;
	uint3 SV_GroupThreadID : SV_GroupThreadID;
};

//uint spvPackHalf2x16(float2 value)
//{
//	uint2 Packed = f32tof16(value);
//	return Packed.x | (Packed.y << 16);
//}
//
//half2 spvUnpackHalf2x16(uint value)
//{
//	return f16tof32(uint2(value & 0xffff, value >> 16));
//}

#if SDR_USE_GAMMA_2_2
	#define GAMMA_TO_LINEAR(x) pow(x, 2.2h)
	#define LINEAR_TO_GAMMA(x) pow(x, 1.h / 2.2h)
#else //TODO: make this use half instead of float
	#define GAMMA_TO_LINEAR(x) gamma_sRGB_to_linear(x)
	#define LINEAR_TO_GAMMA(x) gamma_linear_to_sRGB(x)
#endif

#define HDR_BT2020 1

// since blue is the least contributing in terms of luminance
// the worst case is red and green at 0 and blue high enough so that the luminance is HDR_MAX_OUTPUT_NITS
// TODO: use more accurate value than just the K factor from the YCbCr<->RGB transform
#if HDR_BT2020
	static const float blueFactor = 0.0593f;
#else
	static const float blueFactor = 0.0722f;
#endif
static const float normalizationFactor = (HdrDllPluginConstants.HDRPeakBrightnessNits / WhiteNits_BT709) / blueFactor;


half3 PrepareForProcessing(half3 Color)
{
	if (HdrDllPluginConstants.DisplayMode > 0)
	{
#if HDR_BT2020
		Color = BT709_To_BT2020(Color);
#endif
		return saturate(Color / normalizationFactor);
	}
	else
	{
		return saturate(GAMMA_TO_LINEAR(Color));
	}
}

half3 PrepareForOutput(half3 Color)
{
	if (HdrDllPluginConstants.DisplayMode > 0)
	{
		Color *= normalizationFactor;
#if HDR_BT2020
		return BT2020_To_BT709(Color);
#else
		return Color;
#endif
	}
	else
	{
		return LINEAR_TO_GAMMA(Color);
	}
}


[RootSignature(ShaderRootSignature)]
[numthreads(64, 1, 1)]
void CS(CSInput csInput)
{

#if defined(USE_PACKED_MATH) \
 && defined(USE_UPSCALING)

	uint4 _55 = asuint(_23_m0[2u]);
	uint _58 = _55.x + (((gl_LocalInvocationID.x >> 1u) & 7u) | (gl_WorkGroupID.x << 4u));
	uint _59 = ((((gl_LocalInvocationID.x >> 3u) & 6u) | (gl_LocalInvocationID.x & 1u)) | (gl_WorkGroupID.y << 4u)) + _55.y;
	uint4 _62 = asuint(_23_m0[0u]);
	uint4 _69 = asuint(_23_m0[1u]);
	half _76 = half(_18_m0[1u].w);
	float _80 = asfloat(_62.y);
	float _84 = asfloat(_62.w);
	float _85 = (float(_58) * asfloat(_62.x)) + asfloat(_62.z);
	float _86 = (float(_59) * _80) + _84;
	float _88 = floor(_85);
	float _89 = floor(_86);
	half _91 = half(_85 - _88);
	half _93 = half(_86 - _89);
	uint16_t _95 = (int16_t(_88));
	uint16_t _96 = (int16_t(_89));
	uint4 _101 = asuint(_23_m0[3u]);
	uint _102 = _101.x;
	uint _103 = _101.y;
	uint _104 = _101.z;
	uint _105 = _101.w;
	uint _106 = uint(_95);
	uint _114 = uint(int(max(min(_106, _104), _102) << 16u) >> int(16u));
	uint _116 = uint(int(max(min(uint((_96 + 65535u)), _105), _103) << 16u) >> int(16u));
	float4 _118 = _8.Load(int3(uint2(_114, _116), 0u));
	uint _124 = uint((_95 + 65535u));
	uint _131 = uint(int(max(min(_124, _104), _102) << 16u) >> int(16u));
	uint _133 = uint(int(max(min(uint(_96), _105), _103) << 16u) >> int(16u));
	float4 _134 = _8.Load(int3(uint2(_131, _133), 0u));
	float4 _138 = _8.Load(int3(uint2(_114, _133), 0u));
	uint _144 = uint((_95 + 1u));
	uint _148 = uint(int(max(min(_144, _104), _102) << 16u) >> int(16u));
	float4 _149 = _8.Load(int3(uint2(_148, _116), 0u));
	float4 _153 = _8.Load(int3(uint2(_148, _133), 0u));
	uint _159 = uint((_95 + 2u));
	uint _163 = uint(int(max(min(_159, _104), _102) << 16u) >> int(16u));
	float4 _164 = _8.Load(int3(uint2(_163, _133), 0u));
	uint _173 = uint(int(max(min(uint((_96 + 1u)), _105), _103) << 16u) >> int(16u));
	float4 _174 = _8.Load(int3(uint2(_131, _173), 0u));
	float4 _178 = _8.Load(int3(uint2(_114, _173), 0u));
	uint _187 = uint(int(max(min(uint((_96 + 2u)), _105), _103) << 16u) >> int(16u));
	float4 _188 = _8.Load(int3(uint2(_114, _187), 0u));
	float4 _192 = _8.Load(int3(uint2(_148, _173), 0u));
	float4 _196 = _8.Load(int3(uint2(_163, _173), 0u));
	float4 _200 = _8.Load(int3(uint2(_148, _187), 0u));
	float _205 = _85 + asfloat(_69.z);
	float _206 = floor(_205);
	half _208 = half(_205 - _206);
	uint16_t _209 = (int16_t(_206));
	uint _210 = uint(_209);
	uint _214 = uint(int(max(min(_210, _104), _102) << 16u) >> int(16u));
	float4 _215 = _8.Load(int3(uint2(_214, _116), 0u));
	uint _224 = uint((_209 + 65535u));
	uint _228 = uint(int(max(min(_224, _104), _102) << 16u) >> int(16u));
	float4 _229 = _8.Load(int3(uint2(_228, _133), 0u));
	float4 _237 = _8.Load(int3(uint2(_214, _133), 0u));
	uint _246 = uint((_209 + 1u));
	uint _250 = uint(int(max(min(_246, _104), _102) << 16u) >> int(16u));
	float4 _251 = _8.Load(int3(uint2(_250, _116), 0u));
	float4 _259 = _8.Load(int3(uint2(_250, _133), 0u));
	uint _268 = uint((_209 + 2u));
	uint _272 = uint(int(max(min(_268, _104), _102) << 16u) >> int(16u));
	float4 _273 = _8.Load(int3(uint2(_272, _133), 0u));
	float4 _281 = _8.Load(int3(uint2(_228, _173), 0u));
	float4 _289 = _8.Load(int3(uint2(_214, _173), 0u));
	float4 _297 = _8.Load(int3(uint2(_214, _187), 0u));
	float4 _305 = _8.Load(int3(uint2(_250, _173), 0u));
	float4 _313 = _8.Load(int3(uint2(_272, _173), 0u));
	float4 _321 = _8.Load(int3(uint2(_250, _187), 0u));
	half _344 = exp2(log2((half(_118.y) + half(0.05499267578125)) * half(0.9482421875)) * _76);
	half _345 = exp2(log2((half(_215.y) + half(0.05499267578125)) * half(0.9482421875)) * _76);
	half _364 = exp2(log2((half(_149.y) + half(0.05499267578125)) * half(0.9482421875)) * _76);
	half _365 = exp2(log2((half(_251.y) + half(0.05499267578125)) * half(0.9482421875)) * _76);
	half _384 = exp2(log2((half(_134.y) + half(0.05499267578125)) * half(0.9482421875)) * _76);
	half _385 = exp2(log2((half(_229.y) + half(0.05499267578125)) * half(0.9482421875)) * _76);
	half _404 = exp2(log2((half(_138.y) + half(0.05499267578125)) * half(0.9482421875)) * _76);
	half _405 = exp2(log2((half(_237.y) + half(0.05499267578125)) * half(0.9482421875)) * _76);
	half _424 = exp2(log2((half(_153.y) + half(0.05499267578125)) * half(0.9482421875)) * _76);
	half _425 = exp2(log2((half(_259.y) + half(0.05499267578125)) * half(0.9482421875)) * _76);
	half _444 = exp2(log2((half(_164.y) + half(0.05499267578125)) * half(0.9482421875)) * _76);
	half _445 = exp2(log2((half(_273.y) + half(0.05499267578125)) * half(0.9482421875)) * _76);
	half _464 = exp2(log2((half(_174.y) + half(0.05499267578125)) * half(0.9482421875)) * _76);
	half _465 = exp2(log2((half(_281.y) + half(0.05499267578125)) * half(0.9482421875)) * _76);
	half _484 = exp2(log2((half(_178.y) + half(0.05499267578125)) * half(0.9482421875)) * _76);
	half _485 = exp2(log2((half(_289.y) + half(0.05499267578125)) * half(0.9482421875)) * _76);
	half _504 = exp2(log2((half(_192.y) + half(0.05499267578125)) * half(0.9482421875)) * _76);
	half _505 = exp2(log2((half(_305.y) + half(0.05499267578125)) * half(0.9482421875)) * _76);
	half _524 = exp2(log2((half(_196.y) + half(0.05499267578125)) * half(0.9482421875)) * _76);
	half _525 = exp2(log2((half(_313.y) + half(0.05499267578125)) * half(0.9482421875)) * _76);
	half _544 = exp2(log2((half(_188.y) + half(0.05499267578125)) * half(0.9482421875)) * _76);
	half _545 = exp2(log2((half(_297.y) + half(0.05499267578125)) * half(0.9482421875)) * _76);
	half _564 = exp2(log2((half(_200.y) + half(0.05499267578125)) * half(0.9482421875)) * _76);
	half _565 = exp2(log2((half(_321.y) + half(0.05499267578125)) * half(0.9482421875)) * _76);
	half _571 = isnan(_404) ? _384 : (isnan(_384) ? _404 : min(_384, _404));
	half _572 = isnan(_405) ? _385 : (isnan(_385) ? _405 : min(_385, _405));
	half _573 = isnan(_571) ? _344 : (isnan(_344) ? _571 : min(_344, _571));
	half _574 = isnan(_572) ? _345 : (isnan(_345) ? _572 : min(_345, _572));
	half _575 = isnan(_484) ? _424 : (isnan(_424) ? _484 : min(_424, _484));
	half _576 = isnan(_485) ? _425 : (isnan(_425) ? _485 : min(_425, _485));
	half _577 = isnan(_575) ? _573 : (isnan(_573) ? _575 : min(_573, _575));
	half _578 = isnan(_576) ? _574 : (isnan(_574) ? _576 : min(_574, _576));
	half _579 = isnan(_404) ? _384 : (isnan(_384) ? _404 : max(_384, _404));
	half _580 = isnan(_405) ? _385 : (isnan(_385) ? _405 : max(_385, _405));
	half _581 = isnan(_579) ? _344 : (isnan(_344) ? _579 : max(_344, _579));
	half _582 = isnan(_580) ? _345 : (isnan(_345) ? _580 : max(_345, _580));
	half _583 = isnan(_484) ? _424 : (isnan(_424) ? _484 : max(_424, _484));
	half _584 = isnan(_485) ? _425 : (isnan(_425) ? _485 : max(_425, _485));
	half _585 = isnan(_583) ? _581 : (isnan(_581) ? _583 : max(_581, _583));
	half _586 = isnan(_584) ? _582 : (isnan(_582) ? _584 : max(_582, _584));
	half _587 = isnan(_424) ? _404 : (isnan(_404) ? _424 : min(_404, _424));
	half _588 = isnan(_425) ? _405 : (isnan(_405) ? _425 : min(_405, _425));
	half _589 = isnan(_587) ? _364 : (isnan(_364) ? _587 : min(_364, _587));
	half _590 = isnan(_588) ? _365 : (isnan(_365) ? _588 : min(_365, _588));
	half _591 = isnan(_504) ? _444 : (isnan(_444) ? _504 : min(_444, _504));
	half _592 = isnan(_505) ? _445 : (isnan(_445) ? _505 : min(_445, _505));
	half _593 = isnan(_591) ? _589 : (isnan(_589) ? _591 : min(_589, _591));
	half _594 = isnan(_592) ? _590 : (isnan(_590) ? _592 : min(_590, _592));
	half _595 = isnan(_424) ? _404 : (isnan(_404) ? _424 : max(_404, _424));
	half _596 = isnan(_425) ? _405 : (isnan(_405) ? _425 : max(_405, _425));
	half _597 = isnan(_595) ? _364 : (isnan(_364) ? _595 : max(_364, _595));
	half _598 = isnan(_596) ? _365 : (isnan(_365) ? _596 : max(_365, _596));
	half _599 = isnan(_504) ? _444 : (isnan(_444) ? _504 : max(_444, _504));
	half _600 = isnan(_505) ? _445 : (isnan(_445) ? _505 : max(_445, _505));
	half _601 = isnan(_599) ? _597 : (isnan(_597) ? _599 : max(_597, _599));
	half _602 = isnan(_600) ? _598 : (isnan(_598) ? _600 : max(_598, _600));
	half _603 = isnan(_484) ? _464 : (isnan(_464) ? _484 : min(_464, _484));
	half _604 = isnan(_485) ? _465 : (isnan(_465) ? _485 : min(_465, _485));
	half _605 = isnan(_603) ? _404 : (isnan(_404) ? _603 : min(_404, _603));
	half _606 = isnan(_604) ? _405 : (isnan(_405) ? _604 : min(_405, _604));
	half _607 = isnan(_544) ? _504 : (isnan(_504) ? _544 : min(_504, _544));
	half _608 = isnan(_545) ? _505 : (isnan(_505) ? _545 : min(_505, _545));
	half _609 = isnan(_607) ? _605 : (isnan(_605) ? _607 : min(_605, _607));
	half _610 = isnan(_608) ? _606 : (isnan(_606) ? _608 : min(_606, _608));
	half _611 = isnan(_484) ? _464 : (isnan(_464) ? _484 : max(_464, _484));
	half _612 = isnan(_485) ? _465 : (isnan(_465) ? _485 : max(_465, _485));
	half _613 = isnan(_611) ? _404 : (isnan(_404) ? _611 : max(_404, _611));
	half _614 = isnan(_612) ? _405 : (isnan(_405) ? _612 : max(_405, _612));
	half _615 = isnan(_544) ? _504 : (isnan(_504) ? _544 : max(_504, _544));
	half _616 = isnan(_545) ? _505 : (isnan(_505) ? _545 : max(_505, _545));
	half _617 = isnan(_615) ? _613 : (isnan(_613) ? _615 : max(_613, _615));
	half _618 = isnan(_616) ? _614 : (isnan(_614) ? _616 : max(_614, _616));
	half _619 = isnan(_504) ? _484 : (isnan(_484) ? _504 : min(_484, _504));
	half _620 = isnan(_505) ? _485 : (isnan(_485) ? _505 : min(_485, _505));
	half _621 = isnan(_619) ? _424 : (isnan(_424) ? _619 : min(_424, _619));
	half _622 = isnan(_620) ? _425 : (isnan(_425) ? _620 : min(_425, _620));
	half _623 = isnan(_564) ? _524 : (isnan(_524) ? _564 : min(_524, _564));
	half _624 = isnan(_565) ? _525 : (isnan(_525) ? _565 : min(_525, _565));
	half _625 = isnan(_623) ? _621 : (isnan(_621) ? _623 : min(_621, _623));
	half _626 = isnan(_624) ? _622 : (isnan(_622) ? _624 : min(_622, _624));
	half _627 = isnan(_504) ? _484 : (isnan(_484) ? _504 : max(_484, _504));
	half _628 = isnan(_505) ? _485 : (isnan(_485) ? _505 : max(_485, _505));
	half _629 = isnan(_627) ? _424 : (isnan(_424) ? _627 : max(_424, _627));
	half _630 = isnan(_628) ? _425 : (isnan(_425) ? _628 : max(_425, _628));
	half _631 = isnan(_564) ? _524 : (isnan(_524) ? _564 : max(_524, _564));
	half _632 = isnan(_565) ? _525 : (isnan(_525) ? _565 : max(_525, _565));
	half _633 = isnan(_631) ? _629 : (isnan(_629) ? _631 : max(_629, _631));
	half _634 = isnan(_632) ? _630 : (isnan(_630) ? _632 : max(_630, _632));
	half _644 = half(1.0) - _585;
	half _645 = half(1.0) - _586;
	half _648 = (isnan(_644) ? _577 : (isnan(_577) ? _644 : min(_577, _644))) * (half(1.0) / _585);
	half _649 = (isnan(_645) ? _578 : (isnan(_578) ? _645 : min(_578, _645))) * (half(1.0) / _586);
	half _2515 = isnan(half(0.0)) ? _648 : (isnan(_648) ? half(0.0) : max(_648, half(0.0)));
	half _2526 = isnan(half(0.0)) ? _649 : (isnan(_649) ? half(0.0) : max(_649, half(0.0)));
	half _653 = half(1.0) - _601;
	half _654 = half(1.0) - _602;
	half _657 = (isnan(_653) ? _593 : (isnan(_593) ? _653 : min(_593, _653))) * (half(1.0) / _601);
	half _658 = (isnan(_654) ? _594 : (isnan(_594) ? _654 : min(_594, _654))) * (half(1.0) / _602);
	half _2547 = isnan(half(0.0)) ? _657 : (isnan(_657) ? half(0.0) : max(_657, half(0.0)));
	half _2558 = isnan(half(0.0)) ? _658 : (isnan(_658) ? half(0.0) : max(_658, half(0.0)));
	half _661 = half(1.0) - _617;
	half _662 = half(1.0) - _618;
	half _665 = (isnan(_661) ? _609 : (isnan(_609) ? _661 : min(_609, _661))) * (half(1.0) / _617);
	half _666 = (isnan(_662) ? _610 : (isnan(_610) ? _662 : min(_610, _662))) * (half(1.0) / _618);
	half _2579 = isnan(half(0.0)) ? _665 : (isnan(_665) ? half(0.0) : max(_665, half(0.0)));
	half _2590 = isnan(half(0.0)) ? _666 : (isnan(_666) ? half(0.0) : max(_666, half(0.0)));
	half _669 = half(1.0) - _633;
	half _670 = half(1.0) - _634;
	half _673 = (isnan(_669) ? _625 : (isnan(_625) ? _669 : min(_625, _669))) * (half(1.0) / _633);
	half _674 = (isnan(_670) ? _626 : (isnan(_626) ? _670 : min(_626, _670))) * (half(1.0) / _634);
	half _2611 = isnan(half(0.0)) ? _673 : (isnan(_673) ? half(0.0) : max(_673, half(0.0)));
	half _2622 = isnan(half(0.0)) ? _674 : (isnan(_674) ? half(0.0) : max(_674, half(0.0)));
	half _690 = half(spvUnpackHalf2x16(_69.y & 65535u).x);
	half _699 = half(1.0) - _91;
	half _700 = half(1.0) - _208;
	half _701 = half(1.0) - _93;
	half _717 = (_699 * _701) * (half(1.0) / ((half(0.03125) - _577) + _585));
	half _718 = (_700 * _701) * (half(1.0) / ((half(0.03125) - _578) + _586));
	half _725 = (_701 * _91) * (half(1.0) / ((half(0.03125) - _593) + _601));
	half _726 = (_208 * _701) * (half(1.0) / ((half(0.03125) - _594) + _602));
	half _733 = (_699 * _93) * (half(1.0) / ((half(0.03125) - _609) + _617));
	half _734 = (_700 * _93) * (half(1.0) / ((half(0.03125) - _610) + _618));
	half _741 = (_91 * _93) * (half(1.0) / ((half(0.03125) - _625) + _633));
	half _742 = (_208 * _93) * (half(1.0) / ((half(0.03125) - _626) + _634));
	half _743 = (_690 * sqrt(isnan(half(1.0)) ? _2515 : (isnan(_2515) ? half(1.0) : min(_2515, half(1.0))))) * _717;
	half _744 = _718 * (_690 * sqrt(isnan(half(1.0)) ? _2526 : (isnan(_2526) ? half(1.0) : min(_2526, half(1.0)))));
	half _745 = _725 * (_690 * sqrt(isnan(half(1.0)) ? _2547 : (isnan(_2547) ? half(1.0) : min(_2547, half(1.0)))));
	half _746 = _726 * (_690 * sqrt(isnan(half(1.0)) ? _2558 : (isnan(_2558) ? half(1.0) : min(_2558, half(1.0)))));
	half _747 = _733 * (_690 * sqrt(isnan(half(1.0)) ? _2579 : (isnan(_2579) ? half(1.0) : min(_2579, half(1.0)))));
	half _748 = _734 * (_690 * sqrt(isnan(half(1.0)) ? _2590 : (isnan(_2590) ? half(1.0) : min(_2590, half(1.0)))));
	half _750 = (_745 + _717) + _747;
	half _752 = (_746 + _718) + _748;
	half _753 = _741 * (_690 * sqrt(isnan(half(1.0)) ? _2611 : (isnan(_2611) ? half(1.0) : min(_2611, half(1.0)))));
	half _754 = _742 * (_690 * sqrt(isnan(half(1.0)) ? _2622 : (isnan(_2622) ? half(1.0) : min(_2622, half(1.0)))));
	half _756 = (_725 + _743) + _753;
	half _758 = (_726 + _744) + _754;
	half _760 = (_733 + _743) + _753;
	half _762 = (_734 + _744) + _754;
	half _765 = (_747 + _745) + _741;
	half _766 = (_748 + _746) + _742;
	half _784 = half(1.0) / ((((_765 + _750) + ((((_745 + _743) + _747) + _753) * half(2.0))) + _756) + _760);
	half _785 = half(1.0) / ((((_766 + _752) + ((((_746 + _744) + _748) + _754) * half(2.0))) + _758) + _762);
	half _803 = ((((((_752 * exp2(_76 * log2((half(_237.x) + half(0.05499267578125)) * half(0.9482421875)))) + (_744 * (exp2(_76 * log2((half(_229.x) + half(0.05499267578125)) * half(0.9482421875))) + exp2(_76 * log2((half(_215.x) + half(0.05499267578125)) * half(0.9482421875)))))) + (_766 * exp2(_76 * log2((half(_305.x) + half(0.05499267578125)) * half(0.9482421875))))) + (_758 * exp2(_76 * log2((half(_259.x) + half(0.05499267578125)) * half(0.9482421875))))) + (_762 * exp2(_76 * log2((half(_289.x) + half(0.05499267578125)) * half(0.9482421875))))) + (_754 * (exp2(_76 * log2((half(_321.x) + half(0.05499267578125)) * half(0.9482421875))) + exp2(_76 * log2((half(_313.x) + half(0.05499267578125)) * half(0.9482421875)))))) + (_748 * (exp2(_76 * log2((half(_297.x) + half(0.05499267578125)) * half(0.9482421875))) + exp2(_76 * log2((half(_281.x) + half(0.05499267578125)) * half(0.9482421875)))));
	half _805 = (_803 + (_746 * (exp2(_76 * log2((half(_273.x) + half(0.05499267578125)) * half(0.9482421875))) + exp2(_76 * log2((half(_251.x) + half(0.05499267578125)) * half(0.9482421875)))))) * _785;
	half _2633 = isnan(half(0.0)) ? _805 : (isnan(_805) ? half(0.0) : max(_805, half(0.0)));
	half _826 = ((((((((_752 * _405) + (_744 * (_385 + _345))) + (_766 * _505)) + (_758 * _425)) + (_762 * _485)) + (_754 * (_565 + _525))) + (_748 * (_545 + _465))) + (_746 * (_445 + _365))) * _785;
	half _2644 = isnan(half(0.0)) ? _826 : (isnan(_826) ? half(0.0) : max(_826, half(0.0)));
	half _845 = ((((((_752 * exp2(log2((half(_237.z) + half(0.05499267578125)) * half(0.9482421875)) * _76)) + (_744 * (exp2(log2((half(_229.z) + half(0.05499267578125)) * half(0.9482421875)) * _76) + exp2(log2((half(_215.z) + half(0.05499267578125)) * half(0.9482421875)) * _76)))) + (_766 * exp2(log2((half(_305.z) + half(0.05499267578125)) * half(0.9482421875)) * _76))) + (_758 * exp2(log2((half(_259.z) + half(0.05499267578125)) * half(0.9482421875)) * _76))) + (_762 * exp2(log2((half(_289.z) + half(0.05499267578125)) * half(0.9482421875)) * _76))) + (_754 * (exp2(log2((half(_321.z) + half(0.05499267578125)) * half(0.9482421875)) * _76) + exp2(log2((half(_313.z) + half(0.05499267578125)) * half(0.9482421875)) * _76)))) + (_748 * (exp2(log2((half(_297.z) + half(0.05499267578125)) * half(0.9482421875)) * _76) + exp2(log2((half(_281.z) + half(0.05499267578125)) * half(0.9482421875)) * _76)));
	half _847 = (_845 + (_746 * (exp2(log2((half(_273.z) + half(0.05499267578125)) * half(0.9482421875)) * _76) + exp2(log2((half(_251.z) + half(0.05499267578125)) * half(0.9482421875)) * _76)))) * _785;
	half _2655 = isnan(half(0.0)) ? _847 : (isnan(_847) ? half(0.0) : max(_847, half(0.0)));
	half _849 = isnan(half(0.00100040435791015625)) ? _76 : (isnan(_76) ? half(0.00100040435791015625) : max(_76, half(0.00100040435791015625)));
	uint4 _853 = asuint(_23_m0[2u]);
	if ((_58 <= _853.z) && (_59 <= _853.w))
	{
		half _961 = ((((((exp2(log2((half(_138.z) + half(0.05499267578125)) * half(0.9482421875)) * _76) * _750) + ((exp2(log2((half(_134.z) + half(0.05499267578125)) * half(0.9482421875)) * _76) + exp2(log2((half(_118.z) + half(0.05499267578125)) * half(0.9482421875)) * _76)) * _743)) + (exp2(log2((half(_153.z) + half(0.05499267578125)) * half(0.9482421875)) * _76) * _756)) + (exp2(log2((half(_178.z) + half(0.05499267578125)) * half(0.9482421875)) * _76) * _760)) + (exp2(log2((half(_192.z) + half(0.05499267578125)) * half(0.9482421875)) * _76) * _765)) + ((exp2(log2((half(_200.z) + half(0.05499267578125)) * half(0.9482421875)) * _76) + exp2(log2((half(_196.z) + half(0.05499267578125)) * half(0.9482421875)) * _76)) * _753)) + ((exp2(log2((half(_188.z) + half(0.05499267578125)) * half(0.9482421875)) * _76) + exp2(log2((half(_174.z) + half(0.05499267578125)) * half(0.9482421875)) * _76)) * _747);
		half _963 = (_961 + ((exp2(log2((half(_164.z) + half(0.05499267578125)) * half(0.9482421875)) * _76) + exp2(log2((half(_149.z) + half(0.05499267578125)) * half(0.9482421875)) * _76)) * _745)) * _784;
		half _2671 = isnan(half(0.0)) ? _963 : (isnan(_963) ? half(0.0) : max(_963, half(0.0)));
		half _966 = half(1.0) / _849;
		half _971 = (exp2(_966 * log2(isnan(half(1.0)) ? _2671 : (isnan(_2671) ? half(1.0) : min(_2671, half(1.0))))) * half(1.0546875)) + half(-0.05499267578125);
		half _994 = ((((((((_750 * _404) + (_743 * (_384 + _344))) + (_765 * _504)) + (_756 * _424)) + (_760 * _484)) + (_753 * (_564 + _524))) + (_747 * (_544 + _464))) + (_745 * (_444 + _364))) * _784;
		half _2687 = isnan(half(0.0)) ? _994 : (isnan(_994) ? half(0.0) : max(_994, half(0.0)));
		half _1000 = (exp2(_966 * log2(isnan(half(1.0)) ? _2687 : (isnan(_2687) ? half(1.0) : min(_2687, half(1.0))))) * half(1.0546875)) + half(-0.05499267578125);
		half _1104 = ((((((exp2(log2((half(_138.x) + half(0.05499267578125)) * half(0.9482421875)) * _76) * _750) + ((exp2(log2((half(_134.x) + half(0.05499267578125)) * half(0.9482421875)) * _76) + exp2(log2((half(_118.x) + half(0.05499267578125)) * half(0.9482421875)) * _76)) * _743)) + (exp2(log2((half(_153.x) + half(0.05499267578125)) * half(0.9482421875)) * _76) * _756)) + (exp2(log2((half(_178.x) + half(0.05499267578125)) * half(0.9482421875)) * _76) * _760)) + (exp2(log2((half(_192.x) + half(0.05499267578125)) * half(0.9482421875)) * _76) * _765)) + ((exp2(log2((half(_200.x) + half(0.05499267578125)) * half(0.9482421875)) * _76) + exp2(log2((half(_196.x) + half(0.05499267578125)) * half(0.9482421875)) * _76)) * _753)) + ((exp2(log2((half(_188.x) + half(0.05499267578125)) * half(0.9482421875)) * _76) + exp2(log2((half(_174.x) + half(0.05499267578125)) * half(0.9482421875)) * _76)) * _747);
		half _1106 = (_1104 + ((exp2(log2((half(_164.x) + half(0.05499267578125)) * half(0.9482421875)) * _76) + exp2(log2((half(_149.x) + half(0.05499267578125)) * half(0.9482421875)) * _76)) * _745)) * _784;
		half _2703 = isnan(half(0.0)) ? _1106 : (isnan(_1106) ? half(0.0) : max(_1106, half(0.0)));
		half _1112 = (exp2(_966 * log2(isnan(half(1.0)) ? _2703 : (isnan(_2703) ? half(1.0) : min(_2703, half(1.0))))) * half(1.0546875)) + half(-0.05499267578125);
		_11[uint2(_58, _59)] = float4(float(isnan(half(0.0)) ? _1112 : (isnan(_1112) ? half(0.0) : max(_1112, half(0.0)))), float(isnan(half(0.0)) ? _1000 : (isnan(_1000) ? half(0.0) : max(_1000, half(0.0)))), float(isnan(half(0.0)) ? _971 : (isnan(_971) ? half(0.0) : max(_971, half(0.0)))), 1.0f);
	}
	uint _1119 = _58 + 8u;
	uint4 _1122 = asuint(_23_m0[2u]);
	if ((_1119 <= _1122.z) && (_59 <= _1122.w))
	{
		half _1129 = half(1.0) / _849;
		half _1133 = (exp2(_1129 * log2(isnan(half(1.0)) ? _2655 : (isnan(_2655) ? half(1.0) : min(_2655, half(1.0))))) * half(1.0546875)) + half(-0.05499267578125);
		half _1140 = (exp2(_1129 * log2(isnan(half(1.0)) ? _2644 : (isnan(_2644) ? half(1.0) : min(_2644, half(1.0))))) * half(1.0546875)) + half(-0.05499267578125);
		half _1147 = (exp2(_1129 * log2(isnan(half(1.0)) ? _2633 : (isnan(_2633) ? half(1.0) : min(_2633, half(1.0))))) * half(1.0546875)) + half(-0.05499267578125);
		_11[uint2(_1119, _59)] = float4(float(isnan(half(0.0)) ? _1147 : (isnan(_1147) ? half(0.0) : max(_1147, half(0.0)))), float(isnan(half(0.0)) ? _1140 : (isnan(_1140) ? half(0.0) : max(_1140, half(0.0)))), float(isnan(half(0.0)) ? _1133 : (isnan(_1133) ? half(0.0) : max(_1133, half(0.0)))), 1.0f);
	}
	uint _1153 = _59 + 8u;
	float _1156 = (float(_1153) * _80) + _84;
	float _1157 = floor(_1156);
	half _1159 = half(_1156 - _1157);
	uint16_t _1160 = (int16_t(_1157));
	uint4 _1164 = asuint(_23_m0[3u]);
	uint _1165 = _1164.x;
	uint _1166 = _1164.y;
	uint _1167 = _1164.z;
	uint _1168 = _1164.w;
	uint _1175 = uint(int(max(min(_106, _1167), _1165) << 16u) >> int(16u));
	uint _1177 = uint(int(max(min(uint((_1160 + 65535u)), _1168), _1166) << 16u) >> int(16u));
	float4 _1179 = _8.Load(int3(uint2(_1175, _1177), 0u));
	uint _1189 = uint(int(max(min(_124, _1167), _1165) << 16u) >> int(16u));
	uint _1191 = uint(int(max(min(uint(_1160), _1168), _1166) << 16u) >> int(16u));
	float4 _1192 = _8.Load(int3(uint2(_1189, _1191), 0u));
	float4 _1196 = _8.Load(int3(uint2(_1175, _1191), 0u));
	uint _1203 = uint(int(max(min(_144, _1167), _1165) << 16u) >> int(16u));
	float4 _1204 = _8.Load(int3(uint2(_1203, _1177), 0u));
	float4 _1208 = _8.Load(int3(uint2(_1203, _1191), 0u));
	uint _1215 = uint(int(max(min(_159, _1167), _1165) << 16u) >> int(16u));
	float4 _1216 = _8.Load(int3(uint2(_1215, _1191), 0u));
	uint _1225 = uint(int(max(min(uint((_1160 + 1u)), _1168), _1166) << 16u) >> int(16u));
	float4 _1226 = _8.Load(int3(uint2(_1189, _1225), 0u));
	float4 _1230 = _8.Load(int3(uint2(_1175, _1225), 0u));
	uint _1239 = uint(int(max(min(uint((_1160 + 2u)), _1168), _1166) << 16u) >> int(16u));
	float4 _1240 = _8.Load(int3(uint2(_1175, _1239), 0u));
	float4 _1244 = _8.Load(int3(uint2(_1203, _1225), 0u));
	float4 _1248 = _8.Load(int3(uint2(_1215, _1225), 0u));
	float4 _1252 = _8.Load(int3(uint2(_1203, _1239), 0u));
	uint _1259 = uint(int(max(min(_210, _1167), _1165) << 16u) >> int(16u));
	float4 _1260 = _8.Load(int3(uint2(_1259, _1177), 0u));
	uint _1271 = uint(int(max(min(_224, _1167), _1165) << 16u) >> int(16u));
	float4 _1272 = _8.Load(int3(uint2(_1271, _1191), 0u));
	float4 _1280 = _8.Load(int3(uint2(_1259, _1191), 0u));
	uint _1291 = uint(int(max(min(_246, _1167), _1165) << 16u) >> int(16u));
	float4 _1292 = _8.Load(int3(uint2(_1291, _1177), 0u));
	float4 _1300 = _8.Load(int3(uint2(_1291, _1191), 0u));
	uint _1311 = uint(int(max(min(_268, _1167), _1165) << 16u) >> int(16u));
	float4 _1312 = _8.Load(int3(uint2(_1311, _1191), 0u));
	float4 _1320 = _8.Load(int3(uint2(_1271, _1225), 0u));
	float4 _1328 = _8.Load(int3(uint2(_1259, _1225), 0u));
	float4 _1336 = _8.Load(int3(uint2(_1259, _1239), 0u));
	float4 _1344 = _8.Load(int3(uint2(_1291, _1225), 0u));
	float4 _1352 = _8.Load(int3(uint2(_1311, _1225), 0u));
	float4 _1360 = _8.Load(int3(uint2(_1291, _1239), 0u));
	half _1371 = half(_18_m0[1u].w);
	half _1385 = exp2(log2((half(_1179.y) + half(0.05499267578125)) * half(0.9482421875)) * _1371);
	half _1386 = exp2(log2((half(_1260.y) + half(0.05499267578125)) * half(0.9482421875)) * _1371);
	half _1405 = exp2(log2((half(_1204.y) + half(0.05499267578125)) * half(0.9482421875)) * _1371);
	half _1406 = exp2(log2((half(_1292.y) + half(0.05499267578125)) * half(0.9482421875)) * _1371);
	half _1425 = exp2(log2((half(_1192.y) + half(0.05499267578125)) * half(0.9482421875)) * _1371);
	half _1426 = exp2(log2((half(_1272.y) + half(0.05499267578125)) * half(0.9482421875)) * _1371);
	half _1445 = exp2(log2((half(_1196.y) + half(0.05499267578125)) * half(0.9482421875)) * _1371);
	half _1446 = exp2(log2((half(_1280.y) + half(0.05499267578125)) * half(0.9482421875)) * _1371);
	half _1465 = exp2(log2((half(_1208.y) + half(0.05499267578125)) * half(0.9482421875)) * _1371);
	half _1466 = exp2(log2((half(_1300.y) + half(0.05499267578125)) * half(0.9482421875)) * _1371);
	half _1485 = exp2(log2((half(_1216.y) + half(0.05499267578125)) * half(0.9482421875)) * _1371);
	half _1486 = exp2(log2((half(_1312.y) + half(0.05499267578125)) * half(0.9482421875)) * _1371);
	half _1505 = exp2(log2((half(_1226.y) + half(0.05499267578125)) * half(0.9482421875)) * _1371);
	half _1506 = exp2(log2((half(_1320.y) + half(0.05499267578125)) * half(0.9482421875)) * _1371);
	half _1525 = exp2(log2((half(_1230.y) + half(0.05499267578125)) * half(0.9482421875)) * _1371);
	half _1526 = exp2(log2((half(_1328.y) + half(0.05499267578125)) * half(0.9482421875)) * _1371);
	half _1545 = exp2(log2((half(_1244.y) + half(0.05499267578125)) * half(0.9482421875)) * _1371);
	half _1546 = exp2(log2((half(_1344.y) + half(0.05499267578125)) * half(0.9482421875)) * _1371);
	half _1565 = exp2(log2((half(_1248.y) + half(0.05499267578125)) * half(0.9482421875)) * _1371);
	half _1566 = exp2(log2((half(_1352.y) + half(0.05499267578125)) * half(0.9482421875)) * _1371);
	half _1585 = exp2(log2((half(_1240.y) + half(0.05499267578125)) * half(0.9482421875)) * _1371);
	half _1586 = exp2(log2((half(_1336.y) + half(0.05499267578125)) * half(0.9482421875)) * _1371);
	half _1605 = exp2(log2((half(_1252.y) + half(0.05499267578125)) * half(0.9482421875)) * _1371);
	half _1606 = exp2(log2((half(_1360.y) + half(0.05499267578125)) * half(0.9482421875)) * _1371);
	half _1612 = isnan(_1445) ? _1425 : (isnan(_1425) ? _1445 : min(_1425, _1445));
	half _1613 = isnan(_1446) ? _1426 : (isnan(_1426) ? _1446 : min(_1426, _1446));
	half _1614 = isnan(_1612) ? _1385 : (isnan(_1385) ? _1612 : min(_1385, _1612));
	half _1615 = isnan(_1613) ? _1386 : (isnan(_1386) ? _1613 : min(_1386, _1613));
	half _1616 = isnan(_1525) ? _1465 : (isnan(_1465) ? _1525 : min(_1465, _1525));
	half _1617 = isnan(_1526) ? _1466 : (isnan(_1466) ? _1526 : min(_1466, _1526));
	half _1618 = isnan(_1616) ? _1614 : (isnan(_1614) ? _1616 : min(_1614, _1616));
	half _1619 = isnan(_1617) ? _1615 : (isnan(_1615) ? _1617 : min(_1615, _1617));
	half _1620 = isnan(_1445) ? _1425 : (isnan(_1425) ? _1445 : max(_1425, _1445));
	half _1621 = isnan(_1446) ? _1426 : (isnan(_1426) ? _1446 : max(_1426, _1446));
	half _1622 = isnan(_1620) ? _1385 : (isnan(_1385) ? _1620 : max(_1385, _1620));
	half _1623 = isnan(_1621) ? _1386 : (isnan(_1386) ? _1621 : max(_1386, _1621));
	half _1624 = isnan(_1525) ? _1465 : (isnan(_1465) ? _1525 : max(_1465, _1525));
	half _1625 = isnan(_1526) ? _1466 : (isnan(_1466) ? _1526 : max(_1466, _1526));
	half _1626 = isnan(_1624) ? _1622 : (isnan(_1622) ? _1624 : max(_1622, _1624));
	half _1627 = isnan(_1625) ? _1623 : (isnan(_1623) ? _1625 : max(_1623, _1625));
	half _1628 = isnan(_1465) ? _1445 : (isnan(_1445) ? _1465 : min(_1445, _1465));
	half _1629 = isnan(_1466) ? _1446 : (isnan(_1446) ? _1466 : min(_1446, _1466));
	half _1630 = isnan(_1628) ? _1405 : (isnan(_1405) ? _1628 : min(_1405, _1628));
	half _1631 = isnan(_1629) ? _1406 : (isnan(_1406) ? _1629 : min(_1406, _1629));
	half _1632 = isnan(_1545) ? _1485 : (isnan(_1485) ? _1545 : min(_1485, _1545));
	half _1633 = isnan(_1546) ? _1486 : (isnan(_1486) ? _1546 : min(_1486, _1546));
	half _1634 = isnan(_1632) ? _1630 : (isnan(_1630) ? _1632 : min(_1630, _1632));
	half _1635 = isnan(_1633) ? _1631 : (isnan(_1631) ? _1633 : min(_1631, _1633));
	half _1636 = isnan(_1465) ? _1445 : (isnan(_1445) ? _1465 : max(_1445, _1465));
	half _1637 = isnan(_1466) ? _1446 : (isnan(_1446) ? _1466 : max(_1446, _1466));
	half _1638 = isnan(_1636) ? _1405 : (isnan(_1405) ? _1636 : max(_1405, _1636));
	half _1639 = isnan(_1637) ? _1406 : (isnan(_1406) ? _1637 : max(_1406, _1637));
	half _1640 = isnan(_1545) ? _1485 : (isnan(_1485) ? _1545 : max(_1485, _1545));
	half _1641 = isnan(_1546) ? _1486 : (isnan(_1486) ? _1546 : max(_1486, _1546));
	half _1642 = isnan(_1640) ? _1638 : (isnan(_1638) ? _1640 : max(_1638, _1640));
	half _1643 = isnan(_1641) ? _1639 : (isnan(_1639) ? _1641 : max(_1639, _1641));
	half _1644 = isnan(_1525) ? _1505 : (isnan(_1505) ? _1525 : min(_1505, _1525));
	half _1645 = isnan(_1526) ? _1506 : (isnan(_1506) ? _1526 : min(_1506, _1526));
	half _1646 = isnan(_1644) ? _1445 : (isnan(_1445) ? _1644 : min(_1445, _1644));
	half _1647 = isnan(_1645) ? _1446 : (isnan(_1446) ? _1645 : min(_1446, _1645));
	half _1648 = isnan(_1585) ? _1545 : (isnan(_1545) ? _1585 : min(_1545, _1585));
	half _1649 = isnan(_1586) ? _1546 : (isnan(_1546) ? _1586 : min(_1546, _1586));
	half _1650 = isnan(_1648) ? _1646 : (isnan(_1646) ? _1648 : min(_1646, _1648));
	half _1651 = isnan(_1649) ? _1647 : (isnan(_1647) ? _1649 : min(_1647, _1649));
	half _1652 = isnan(_1525) ? _1505 : (isnan(_1505) ? _1525 : max(_1505, _1525));
	half _1653 = isnan(_1526) ? _1506 : (isnan(_1506) ? _1526 : max(_1506, _1526));
	half _1654 = isnan(_1652) ? _1445 : (isnan(_1445) ? _1652 : max(_1445, _1652));
	half _1655 = isnan(_1653) ? _1446 : (isnan(_1446) ? _1653 : max(_1446, _1653));
	half _1656 = isnan(_1585) ? _1545 : (isnan(_1545) ? _1585 : max(_1545, _1585));
	half _1657 = isnan(_1586) ? _1546 : (isnan(_1546) ? _1586 : max(_1546, _1586));
	half _1658 = isnan(_1656) ? _1654 : (isnan(_1654) ? _1656 : max(_1654, _1656));
	half _1659 = isnan(_1657) ? _1655 : (isnan(_1655) ? _1657 : max(_1655, _1657));
	half _1660 = isnan(_1545) ? _1525 : (isnan(_1525) ? _1545 : min(_1525, _1545));
	half _1661 = isnan(_1546) ? _1526 : (isnan(_1526) ? _1546 : min(_1526, _1546));
	half _1662 = isnan(_1660) ? _1465 : (isnan(_1465) ? _1660 : min(_1465, _1660));
	half _1663 = isnan(_1661) ? _1466 : (isnan(_1466) ? _1661 : min(_1466, _1661));
	half _1664 = isnan(_1605) ? _1565 : (isnan(_1565) ? _1605 : min(_1565, _1605));
	half _1665 = isnan(_1606) ? _1566 : (isnan(_1566) ? _1606 : min(_1566, _1606));
	half _1666 = isnan(_1664) ? _1662 : (isnan(_1662) ? _1664 : min(_1662, _1664));
	half _1667 = isnan(_1665) ? _1663 : (isnan(_1663) ? _1665 : min(_1663, _1665));
	half _1668 = isnan(_1545) ? _1525 : (isnan(_1525) ? _1545 : max(_1525, _1545));
	half _1669 = isnan(_1546) ? _1526 : (isnan(_1526) ? _1546 : max(_1526, _1546));
	half _1670 = isnan(_1668) ? _1465 : (isnan(_1465) ? _1668 : max(_1465, _1668));
	half _1671 = isnan(_1669) ? _1466 : (isnan(_1466) ? _1669 : max(_1466, _1669));
	half _1672 = isnan(_1605) ? _1565 : (isnan(_1565) ? _1605 : max(_1565, _1605));
	half _1673 = isnan(_1606) ? _1566 : (isnan(_1566) ? _1606 : max(_1566, _1606));
	half _1674 = isnan(_1672) ? _1670 : (isnan(_1670) ? _1672 : max(_1670, _1672));
	half _1675 = isnan(_1673) ? _1671 : (isnan(_1671) ? _1673 : max(_1671, _1673));
	half _1684 = half(1.0) - _1626;
	half _1685 = half(1.0) - _1627;
	half _1688 = (isnan(_1684) ? _1618 : (isnan(_1618) ? _1684 : min(_1618, _1684))) * (half(1.0) / _1626);
	half _1689 = (isnan(_1685) ? _1619 : (isnan(_1619) ? _1685 : min(_1619, _1685))) * (half(1.0) / _1627);
	half _3064 = isnan(half(0.0)) ? _1688 : (isnan(_1688) ? half(0.0) : max(_1688, half(0.0)));
	half _3075 = isnan(half(0.0)) ? _1689 : (isnan(_1689) ? half(0.0) : max(_1689, half(0.0)));
	half _1692 = half(1.0) - _1642;
	half _1693 = half(1.0) - _1643;
	half _1696 = (isnan(_1692) ? _1634 : (isnan(_1634) ? _1692 : min(_1634, _1692))) * (half(1.0) / _1642);
	half _1697 = (isnan(_1693) ? _1635 : (isnan(_1635) ? _1693 : min(_1635, _1693))) * (half(1.0) / _1643);
	half _3096 = isnan(half(0.0)) ? _1696 : (isnan(_1696) ? half(0.0) : max(_1696, half(0.0)));
	half _3107 = isnan(half(0.0)) ? _1697 : (isnan(_1697) ? half(0.0) : max(_1697, half(0.0)));
	half _1700 = half(1.0) - _1658;
	half _1701 = half(1.0) - _1659;
	half _1704 = (isnan(_1700) ? _1650 : (isnan(_1650) ? _1700 : min(_1650, _1700))) * (half(1.0) / _1658);
	half _1705 = (isnan(_1701) ? _1651 : (isnan(_1651) ? _1701 : min(_1651, _1701))) * (half(1.0) / _1659);
	half _3128 = isnan(half(0.0)) ? _1704 : (isnan(_1704) ? half(0.0) : max(_1704, half(0.0)));
	half _3139 = isnan(half(0.0)) ? _1705 : (isnan(_1705) ? half(0.0) : max(_1705, half(0.0)));
	half _1708 = half(1.0) - _1674;
	half _1709 = half(1.0) - _1675;
	half _1712 = (isnan(_1708) ? _1666 : (isnan(_1666) ? _1708 : min(_1666, _1708))) * (half(1.0) / _1674);
	half _1713 = (isnan(_1709) ? _1667 : (isnan(_1667) ? _1709 : min(_1667, _1709))) * (half(1.0) / _1675);
	half _3160 = isnan(half(0.0)) ? _1712 : (isnan(_1712) ? half(0.0) : max(_1712, half(0.0)));
	half _3171 = isnan(half(0.0)) ? _1713 : (isnan(_1713) ? half(0.0) : max(_1713, half(0.0)));
	half _1732 = half(1.0) - _1159;
	half _1747 = (_1732 * _699) * (half(1.0) / ((half(0.03125) - _1618) + _1626));
	half _1748 = (_700 * _1732) * (half(1.0) / ((half(0.03125) - _1619) + _1627));
	half _1755 = (_1732 * _91) * (half(1.0) / ((half(0.03125) - _1634) + _1642));
	half _1756 = (_208 * _1732) * (half(1.0) / ((half(0.03125) - _1635) + _1643));
	half _1763 = (_699 * _1159) * (half(1.0) / ((half(0.03125) - _1650) + _1658));
	half _1764 = (_700 * _1159) * (half(1.0) / ((half(0.03125) - _1651) + _1659));
	half _1771 = (_1159 * _91) * (half(1.0) / ((half(0.03125) - _1666) + _1674));
	half _1772 = (_208 * _1159) * (half(1.0) / ((half(0.03125) - _1667) + _1675));
	half _1773 = (_690 * sqrt(isnan(half(1.0)) ? _3064 : (isnan(_3064) ? half(1.0) : min(_3064, half(1.0))))) * _1747;
	half _1774 = _1748 * (_690 * sqrt(isnan(half(1.0)) ? _3075 : (isnan(_3075) ? half(1.0) : min(_3075, half(1.0)))));
	half _1775 = _1755 * (_690 * sqrt(isnan(half(1.0)) ? _3096 : (isnan(_3096) ? half(1.0) : min(_3096, half(1.0)))));
	half _1776 = _1756 * (_690 * sqrt(isnan(half(1.0)) ? _3107 : (isnan(_3107) ? half(1.0) : min(_3107, half(1.0)))));
	half _1777 = _1763 * (_690 * sqrt(isnan(half(1.0)) ? _3128 : (isnan(_3128) ? half(1.0) : min(_3128, half(1.0)))));
	half _1778 = _1764 * (_690 * sqrt(isnan(half(1.0)) ? _3139 : (isnan(_3139) ? half(1.0) : min(_3139, half(1.0)))));
	half _1780 = (_1775 + _1747) + _1777;
	half _1782 = (_1776 + _1748) + _1778;
	half _1783 = _1771 * (_690 * sqrt(isnan(half(1.0)) ? _3160 : (isnan(_3160) ? half(1.0) : min(_3160, half(1.0)))));
	half _1784 = _1772 * (_690 * sqrt(isnan(half(1.0)) ? _3171 : (isnan(_3171) ? half(1.0) : min(_3171, half(1.0)))));
	half _1786 = (_1755 + _1773) + _1783;
	half _1788 = (_1756 + _1774) + _1784;
	half _1790 = (_1763 + _1773) + _1783;
	half _1792 = (_1764 + _1774) + _1784;
	half _1795 = (_1777 + _1775) + _1771;
	half _1796 = (_1778 + _1776) + _1772;
	half _1813 = half(1.0) / ((((_1795 + _1780) + ((((_1775 + _1773) + _1777) + _1783) * half(2.0))) + _1786) + _1790);
	half _1814 = half(1.0) / ((((_1796 + _1782) + ((((_1776 + _1774) + _1778) + _1784) * half(2.0))) + _1788) + _1792);
	half _1832 = ((((((_1782 * exp2(_1371 * log2((half(_1280.x) + half(0.05499267578125)) * half(0.9482421875)))) + (_1774 * (exp2(_1371 * log2((half(_1272.x) + half(0.05499267578125)) * half(0.9482421875))) + exp2(_1371 * log2((half(_1260.x) + half(0.05499267578125)) * half(0.9482421875)))))) + (_1796 * exp2(_1371 * log2((half(_1344.x) + half(0.05499267578125)) * half(0.9482421875))))) + (_1788 * exp2(_1371 * log2((half(_1300.x) + half(0.05499267578125)) * half(0.9482421875))))) + (_1792 * exp2(_1371 * log2((half(_1328.x) + half(0.05499267578125)) * half(0.9482421875))))) + (_1784 * (exp2(_1371 * log2((half(_1360.x) + half(0.05499267578125)) * half(0.9482421875))) + exp2(_1371 * log2((half(_1352.x) + half(0.05499267578125)) * half(0.9482421875)))))) + (_1778 * (exp2(_1371 * log2((half(_1336.x) + half(0.05499267578125)) * half(0.9482421875))) + exp2(_1371 * log2((half(_1320.x) + half(0.05499267578125)) * half(0.9482421875)))));
	half _1834 = (_1832 + (_1776 * (exp2(_1371 * log2((half(_1312.x) + half(0.05499267578125)) * half(0.9482421875))) + exp2(_1371 * log2((half(_1292.x) + half(0.05499267578125)) * half(0.9482421875)))))) * _1814;
	half _3182 = isnan(half(0.0)) ? _1834 : (isnan(_1834) ? half(0.0) : max(_1834, half(0.0)));
	half _1855 = ((((((((_1782 * _1446) + (_1774 * (_1426 + _1386))) + (_1796 * _1546)) + (_1788 * _1466)) + (_1792 * _1526)) + (_1784 * (_1606 + _1566))) + (_1778 * (_1586 + _1506))) + (_1776 * (_1486 + _1406))) * _1814;
	half _3193 = isnan(half(0.0)) ? _1855 : (isnan(_1855) ? half(0.0) : max(_1855, half(0.0)));
	half _1874 = ((((((_1782 * exp2(log2((half(_1280.z) + half(0.05499267578125)) * half(0.9482421875)) * _1371)) + (_1774 * (exp2(log2((half(_1272.z) + half(0.05499267578125)) * half(0.9482421875)) * _1371) + exp2(log2((half(_1260.z) + half(0.05499267578125)) * half(0.9482421875)) * _1371)))) + (_1796 * exp2(log2((half(_1344.z) + half(0.05499267578125)) * half(0.9482421875)) * _1371))) + (_1788 * exp2(log2((half(_1300.z) + half(0.05499267578125)) * half(0.9482421875)) * _1371))) + (_1792 * exp2(log2((half(_1328.z) + half(0.05499267578125)) * half(0.9482421875)) * _1371))) + (_1784 * (exp2(log2((half(_1360.z) + half(0.05499267578125)) * half(0.9482421875)) * _1371) + exp2(log2((half(_1352.z) + half(0.05499267578125)) * half(0.9482421875)) * _1371)))) + (_1778 * (exp2(log2((half(_1336.z) + half(0.05499267578125)) * half(0.9482421875)) * _1371) + exp2(log2((half(_1320.z) + half(0.05499267578125)) * half(0.9482421875)) * _1371)));
	half _1876 = (_1874 + (_1776 * (exp2(log2((half(_1312.z) + half(0.05499267578125)) * half(0.9482421875)) * _1371) + exp2(log2((half(_1292.z) + half(0.05499267578125)) * half(0.9482421875)) * _1371)))) * _1814;
	half _3204 = isnan(half(0.0)) ? _1876 : (isnan(_1876) ? half(0.0) : max(_1876, half(0.0)));
	uint4 _1880 = asuint(_23_m0[2u]);
	if ((_58 <= _1880.z) && (_1153 <= _1880.w))
	{
		half _1987 = ((((((exp2(log2((half(_1196.z) + half(0.05499267578125)) * half(0.9482421875)) * _1371) * _1780) + ((exp2(log2((half(_1192.z) + half(0.05499267578125)) * half(0.9482421875)) * _1371) + exp2(log2((half(_1179.z) + half(0.05499267578125)) * half(0.9482421875)) * _1371)) * _1773)) + (exp2(log2((half(_1208.z) + half(0.05499267578125)) * half(0.9482421875)) * _1371) * _1786)) + (exp2(log2((half(_1230.z) + half(0.05499267578125)) * half(0.9482421875)) * _1371) * _1790)) + (exp2(log2((half(_1244.z) + half(0.05499267578125)) * half(0.9482421875)) * _1371) * _1795)) + ((exp2(log2((half(_1252.z) + half(0.05499267578125)) * half(0.9482421875)) * _1371) + exp2(log2((half(_1248.z) + half(0.05499267578125)) * half(0.9482421875)) * _1371)) * _1783)) + ((exp2(log2((half(_1240.z) + half(0.05499267578125)) * half(0.9482421875)) * _1371) + exp2(log2((half(_1226.z) + half(0.05499267578125)) * half(0.9482421875)) * _1371)) * _1777);
		half _1989 = (_1987 + ((exp2(log2((half(_1216.z) + half(0.05499267578125)) * half(0.9482421875)) * _1371) + exp2(log2((half(_1204.z) + half(0.05499267578125)) * half(0.9482421875)) * _1371)) * _1775)) * _1813;
		half _3215 = isnan(half(0.0)) ? _1989 : (isnan(_1989) ? half(0.0) : max(_1989, half(0.0)));
		half _1992 = half(1.0) / _849;
		half _1996 = (exp2(_1992 * log2(isnan(half(1.0)) ? _3215 : (isnan(_3215) ? half(1.0) : min(_3215, half(1.0))))) * half(1.0546875)) + half(-0.05499267578125);
		half _2018 = ((((((((_1780 * _1445) + (_1773 * (_1425 + _1385))) + (_1795 * _1545)) + (_1786 * _1465)) + (_1790 * _1525)) + (_1783 * (_1605 + _1565))) + (_1777 * (_1585 + _1505))) + (_1775 * (_1485 + _1405))) * _1813;
		half _3231 = isnan(half(0.0)) ? _2018 : (isnan(_2018) ? half(0.0) : max(_2018, half(0.0)));
		half _2024 = (exp2(_1992 * log2(isnan(half(1.0)) ? _3231 : (isnan(_3231) ? half(1.0) : min(_3231, half(1.0))))) * half(1.0546875)) + half(-0.05499267578125);
		half _2128 = ((((((exp2(log2((half(_1196.x) + half(0.05499267578125)) * half(0.9482421875)) * _1371) * _1780) + ((exp2(log2((half(_1192.x) + half(0.05499267578125)) * half(0.9482421875)) * _1371) + exp2(log2((half(_1179.x) + half(0.05499267578125)) * half(0.9482421875)) * _1371)) * _1773)) + (exp2(log2((half(_1208.x) + half(0.05499267578125)) * half(0.9482421875)) * _1371) * _1786)) + (exp2(log2((half(_1230.x) + half(0.05499267578125)) * half(0.9482421875)) * _1371) * _1790)) + (exp2(log2((half(_1244.x) + half(0.05499267578125)) * half(0.9482421875)) * _1371) * _1795)) + ((exp2(log2((half(_1252.x) + half(0.05499267578125)) * half(0.9482421875)) * _1371) + exp2(log2((half(_1248.x) + half(0.05499267578125)) * half(0.9482421875)) * _1371)) * _1783)) + ((exp2(log2((half(_1240.x) + half(0.05499267578125)) * half(0.9482421875)) * _1371) + exp2(log2((half(_1226.x) + half(0.05499267578125)) * half(0.9482421875)) * _1371)) * _1777);
		half _2130 = (_2128 + ((exp2(log2((half(_1216.x) + half(0.05499267578125)) * half(0.9482421875)) * _1371) + exp2(log2((half(_1204.x) + half(0.05499267578125)) * half(0.9482421875)) * _1371)) * _1775)) * _1813;
		half _3247 = isnan(half(0.0)) ? _2130 : (isnan(_2130) ? half(0.0) : max(_2130, half(0.0)));
		half _2136 = (exp2(_1992 * log2(isnan(half(1.0)) ? _3247 : (isnan(_3247) ? half(1.0) : min(_3247, half(1.0))))) * half(1.0546875)) + half(-0.05499267578125);
		_11[uint2(_58, _1153)] = float4(float(isnan(half(0.0)) ? _2136 : (isnan(_2136) ? half(0.0) : max(_2136, half(0.0)))), float(isnan(half(0.0)) ? _2024 : (isnan(_2024) ? half(0.0) : max(_2024, half(0.0)))), float(isnan(half(0.0)) ? _1996 : (isnan(_1996) ? half(0.0) : max(_1996, half(0.0)))), 1.0f);
	}
	uint4 _2144 = asuint(_23_m0[2u]);
	if ((_1119 <= _2144.z) && (_1153 <= _2144.w))
	{
		half _2151 = half(1.0) / _849;
		half _2155 = (exp2(_2151 * log2(isnan(half(1.0)) ? _3204 : (isnan(_3204) ? half(1.0) : min(_3204, half(1.0))))) * half(1.0546875)) + half(-0.05499267578125);
		half _2162 = (exp2(_2151 * log2(isnan(half(1.0)) ? _3193 : (isnan(_3193) ? half(1.0) : min(_3193, half(1.0))))) * half(1.0546875)) + half(-0.05499267578125);
		half _2169 = (exp2(_2151 * log2(isnan(half(1.0)) ? _3182 : (isnan(_3182) ? half(1.0) : min(_3182, half(1.0))))) * half(1.0546875)) + half(-0.05499267578125);
		_11[uint2(_1119, _1153)] = float4(float(isnan(half(0.0)) ? _2169 : (isnan(_2169) ? half(0.0) : max(_2169, half(0.0)))), float(isnan(half(0.0)) ? _2162 : (isnan(_2162) ? half(0.0) : max(_2162, half(0.0)))), float(isnan(half(0.0)) ? _2155 : (isnan(_2155) ? half(0.0) : max(_2155, half(0.0)))), 1.0f);
	}

#elif defined(USE_PACKED_MATH)
#if 0 // Disable the CS so it just outputs the input
	uint2 _55 = CASData.cas2.xy;
	uint _58 = _55.x + (((csInput.SV_GroupThreadID.x >> 1u) & 7u) | (csInput.SV_GroupID.x << 4u));
	uint ppx = _58;
	uint ppy = ((((csInput.SV_GroupThreadID.x >> 3u) & 6u) | (csInput.SV_GroupThreadID.x & 1u)) | (csInput.SV_GroupID.y << 4u)) + _55.y;

	ColorOut[uint2(ppx, ppy)] = ColorIn.Load(int3(uint2(ppx, ppy), 0));

	ppx += 8;

	ColorOut[uint2(ppx, ppy)] = ColorIn.Load(int3(uint2(ppx, ppy), 0));

	ppy += 8;

	ColorOut[uint2(_58, ppy)] = ColorIn.Load(int3(uint2(_58, ppy), 0));
	ColorOut[uint2(ppx, ppy)] = ColorIn.Load(int3(uint2(ppx, ppy), 0));
#else

	uint4 _55 = CASData.rectLimits0;

	uint _58 = ((csInput.SV_GroupThreadID.x >> 1) & 7)
	         | (csInput.SV_GroupID.x << 4);
	_58 += _55.x;

	uint _59 = ((csInput.SV_GroupThreadID.x >> 3) & 6)
	         | (csInput.SV_GroupThreadID.x & 1)
	         | (csInput.SV_GroupID.y << 4);
	_59 += _55.y;

	uint2 pp = uint2(_58, _59);

	uint4 _69 = CASData.rectLimits1;

	uint _70 = _69.x;
	uint _71 = _69.y;
	uint _72 = _69.z;
	uint _73 = _69.w;

	uint _107 = max(min(pp.x - 1, _72), _70);
	uint  _87 = max(min(pp.x,     _72), _70);
	uint _118 = max(min(pp.x + 1, _72), _70);

	uint  _89 = max(min(pp.y - 1, _73), _71);
	uint _105 = max(min(pp.y,     _73), _71);
	uint _127 = max(min(pp.y + 1, _73), _71);

	uint _150 = max(min(pp.x + 7, _72), _70);
	uint _138 = max(min(pp.x + 8, _72), _70);
	uint _167 = max(min(pp.x + 9, _72), _70);

	half3  _91 = ColorIn.Load(int3( _87,  _89, 0)).rgb;
	half3 _106 = ColorIn.Load(int3(_107, _105, 0)).rgb;
	half3 _109 = ColorIn.Load(int3( _87, _105, 0)).rgb;
	half3 _119 = ColorIn.Load(int3(_118, _105, 0)).rgb;
	half3 _128 = ColorIn.Load(int3( _87, _127, 0)).rgb;
	half3 _139 = ColorIn.Load(int3(_138,  _89, 0)).rgb;
	half3 _151 = ColorIn.Load(int3(_150, _105, 0)).rgb;
	half3 _156 = ColorIn.Load(int3(_138, _105, 0)).rgb;
	half3 _168 = ColorIn.Load(int3(_167, _105, 0)).rgb;
	half3 _173 = ColorIn.Load(int3(_138, _127, 0)).rgb;

	 _91 = PrepareForProcessing( _91);
	_106 = PrepareForProcessing(_106);
	_109 = PrepareForProcessing(_109);
	_119 = PrepareForProcessing(_119);
	_128 = PrepareForProcessing(_128);
	_139 = PrepareForProcessing(_139);
	_151 = PrepareForProcessing(_151);
	_156 = PrepareForProcessing(_156);
	_168 = PrepareForProcessing(_168);
	_173 = PrepareForProcessing(_173);

	half _193 =  _91.y;
	half _194 = _139.y;
	half _213 = _106.y;
	half _214 = _151.y;
	half _233 = _109.y;
	half _234 = _156.y;
	half _253 = _119.y;
	half _254 = _168.y;
	half _273 = _128.y;
	half _274 = _173.y;

	half _280 = min(_193, _213);
	half _281 = min(_194, _214);
	half _282 = min(_280, _233);
	half _283 = min(_281, _234);
	half _284 = min(_253, _273);
	half _285 = min(_254, _274);
	half _286 = min(_284, _282);
	half _287 = min(_285, _283);

	half _288 = max(_193, _213);
	half _289 = max(_194, _214);
	half _290 = max(_288, _233);
	half _291 = max(_289, _234);
	half _292 = max(_253, _273);
	half _293 = max(_254, _274);
	half _294 = max(_292, _290);
	half _295 = max(_293, _291);

	half _299 = 1.h - _294;
	half _300 = 1.h - _295;

	half _303 = min(_286, _299) * (1.h / _294);
	half _304 = min(_287, _300) * (1.h / _295);

	half _981 = saturate(_303);
	half _992 = saturate(_304);

	half hSharp = f16tof32(CASData.upscalingConst1.sharpAsHalf & 0xFFFF);

	half _315 = hSharp * sqrt(_981);
	half _316 = hSharp * sqrt(_992);

	half _322 = 1.h / ((_315 * 4.h) + 1.h);
	half _323 = 1.h / ((_316 * 4.h) + 1.h);

	half3 _329 = (((_151 + _139 + _168 + _173) * _316) + _156) * _323;
	half3 colorOut2 = saturate(_329);

	colorOut2 = PrepareForOutput(colorOut2);

	if ((pp.x <= _55.z) && (pp.y <= _55.w))
	{
		half3 _388 = (((_106 + _91 + _119 + _128) * _315) + _109) * _322;
		half3 colorOut1 = saturate(_388);

		colorOut1 = PrepareForOutput(colorOut1);

		ColorOut[pp] = float4(colorOut1, 1.f);
	}

	pp.x += 8;

	if ((pp.x <= _55.z) && (pp.y <= _55.w))
	{
		ColorOut[pp] = float4(colorOut2, 1.f);
	}

	pp.y += 8;

	uint _507 = max(min(pp.y - 1, _73), _71);
	uint _520 = max(min(pp.y,     _73), _71);
	uint _539 = max(min(pp.y + 1, _73), _71);

	half3 _509 = ColorIn.Load(int3( _87, _507, 0)).rgb;
	half3 _521 = ColorIn.Load(int3(_107, _520, 0)).rgb;
	half3 _524 = ColorIn.Load(int3( _87, _520, 0)).rgb;
	half3 _531 = ColorIn.Load(int3(_118, _520, 0)).rgb;
	half3 _540 = ColorIn.Load(int3( _87, _539, 0)).rgb;
	half3 _547 = ColorIn.Load(int3(_138, _507, 0)).rgb;
	half3 _556 = ColorIn.Load(int3(_150, _520, 0)).rgb;
	half3 _561 = ColorIn.Load(int3(_138, _520, 0)).rgb;
	half3 _570 = ColorIn.Load(int3(_167, _520, 0)).rgb;
	half3 _575 = ColorIn.Load(int3(_138, _539, 0)).rgb;

	_509 = PrepareForProcessing(_509);
	_547 = PrepareForProcessing(_547);
	_521 = PrepareForProcessing(_521);
	_556 = PrepareForProcessing(_556);
	_524 = PrepareForProcessing(_524);
	_561 = PrepareForProcessing(_561);
	_531 = PrepareForProcessing(_531);
	_570 = PrepareForProcessing(_570);
	_540 = PrepareForProcessing(_540);
	_575 = PrepareForProcessing(_575);

	half _596 = _509.y;
	half _597 = _547.y;
	half _616 = _521.y;
	half _617 = _556.y;
	half _636 = _524.y;
	half _637 = _561.y;
	half _656 = _531.y;
	half _657 = _570.y;
	half _676 = _540.y;
	half _677 = _575.y;

	half _683 = min(_596, _616);
	half _684 = min(_597, _617);
	half _685 = min(_683, _636);
	half _686 = min(_684, _637);
	half _687 = min(_656, _676);
	half _688 = min(_657, _677);
	half _689 = min(_687, _685);
	half _690 = min(_688, _686);

	half _691 = max(_596, _616);
	half _692 = max(_597, _617);
	half _693 = max(_691, _636);
	half _694 = max(_692, _637);
	half _695 = max(_656, _676);
	half _696 = max(_657, _677);
	half _697 = max(_695, _693);
	half _698 = max(_696, _694);

	half _701 = 1.h - _697;
	half _702 = 1.h - _698;

	half _705 = min(_689, _701) * (1.h / _697);
	half _706 = min(_690, _702) * (1.h / _698);

	half _1194 = saturate(_705);
	half _1205 = saturate(_706);

	half _711 = hSharp * sqrt(_1194);
	half _712 = hSharp * sqrt(_1205);

	half _717 = 1.h / ((_711 * 4.h) + 1.h);
	half _718 = 1.h / ((_712 * 4.h) + 1.h);

	half3 _724 = (((_556 + _547 + _570 + _575) * _712) + _561) * _718;
	half3 colorOut4 = saturate(_724);

	colorOut4 = PrepareForOutput(colorOut4);

	if ((pp.x <= _55.z) && (pp.y <= _55.w))
	{
		half3 _783 = (((_521 + _509 + _531 + _540) * _711) + _524) * _717;
		half3 colorOut3 = saturate(_783);

		colorOut3 = PrepareForOutput(colorOut3);

		ColorOut[uint2(_58, pp.y)] = float4(colorOut3, 1.f);
	}

	if ((pp.x <= _55.z) && (pp.y <= _55.w))
	{
		ColorOut[pp] = float4(colorOut4, 1.f);
	}

#endif
#endif // USE_PACKED_MATH
}
