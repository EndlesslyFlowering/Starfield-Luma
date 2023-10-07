#include "../shared.hlsl"
#include "../color.hlsl"
#include "RootSignature.hlsl"

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
}
