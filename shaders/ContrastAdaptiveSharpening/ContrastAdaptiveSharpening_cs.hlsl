#include "../shared.hlsl"
#include "../color.hlsl"
#include "RootSignature.hlsl"

// this is CAS upscaling in FP16 with FFX_CAS_USE_PRECISE_MATH [100FF94]
// other variants are also available, which are:
// - CAS upscaling in FP32 [200FF94]
// - CAS upscaling in FP16 with FFX_CAS_USE_PRECISE_MATH and FFX_CAS_BETTER_DIAGONALS [300FF94]
// - just CAS sharpening in FP32 [FF94]

// TODO make full process in half not just after csp conversion?
// needs matrices in half

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


[RootSignature(ShaderRootSignature)]
[numthreads(64, 1, 1)]
void CS(CSInput csInput)
{
#if 0
	// butchered the CS so it just outputs the input
	uint4 _55 = CASData.cas2;
	uint ppx = _55.x + (((csInput.SV_GroupThreadID.x >> 1u) & 7u) | (csInput.SV_GroupID.x << 4u));
	uint ppy = ((((csInput.SV_GroupThreadID.x >> 3u) & 6u) | (csInput.SV_GroupThreadID.x & 1u)) | (csInput.SV_GroupID.y << 4u)) + _55.y;
	ppx += 8;
	ppy += 8;

	ColorOut[uint2(ppx, ppy)] = ColorIn.Load(int3(uint2(ppx, ppy), 0u));
	ColorOut[uint2(ppx, ppy)] = ColorIn.Load(int3(uint2(ppx, ppy), 0u));
	ColorOut[uint2(ppx, ppy)] = ColorIn.Load(int3(uint2(ppx, ppy), 0u));
	ColorOut[uint2(ppx, ppy)] = ColorIn.Load(int3(uint2(ppx, ppy), 0u));
#else

	uint4 _55 = CASData.cas2;

	uint _58 = _55.x + (((csInput.SV_GroupThreadID.x >> 1u) & 7u) | (csInput.SV_GroupID.x << 4u));

	uint2 pp =
		uint2(_58,
	        ((((csInput.SV_GroupThreadID.x >> 3u) & 6u) | (csInput.SV_GroupThreadID.x & 1u)) | (csInput.SV_GroupID.y << 4u)) + _55.y);

	uint4 _69 = CASData.cas3;

	uint _70 = _69.x;
	uint _71 = _69.y;
	uint _72 = _69.z;
	uint _73 = _69.w;

	uint _87 = max(min(pp.x, _72), _70);
	uint _89 = max(min(pp.y - 1, _73), _71);
	float3  _91f = ColorIn.Load(int3( _87,  _89, 0)).rgb;

	uint _105 = max(min(pp.y, _73), _71);
	uint _107 = max(min(pp.x - 1, _72), _70);
	float3 _106f = ColorIn.Load(int3(_107, _105, 0)).rgb;
	float3 _109f = ColorIn.Load(int3( _87, _105, 0)).rgb;

	uint _118 = max(min(pp.x + 1, _72), _70);
	float3 _119f = ColorIn.Load(int3(_118, _105, 0)).rgb;

	uint _127 = max(min(pp.y + 1, _73), _71);
	float3 _128f = ColorIn.Load(int3( _87, _127, 0)).rgb;

	uint _138 = max(min(pp.x + 8, _72), _70);
	float3 _139f = ColorIn.Load(int3(_138,  _89, 0)).rgb;

	uint _150 = max(min(pp.x + 7, _72), _70);
	float3 _151f = ColorIn.Load(int3(_150, _105, 0)).rgb;
	float3 _156f = ColorIn.Load(int3(_138, _105, 0)).rgb;

	uint _167 = max(min(pp.x + 9, _72), _70);
	float3 _168f = ColorIn.Load(int3(_167, _105, 0)).rgb;
	float3 _173f = ColorIn.Load(int3(_138, _127, 0)).rgb;

	 _91f = BT709_To_BT2020( _91f);
	_139f = BT709_To_BT2020(_139f);
	_106f = BT709_To_BT2020(_106f);
	_151f = BT709_To_BT2020(_151f);
	_109f = BT709_To_BT2020(_109f);
	_156f = BT709_To_BT2020(_156f);
	_119f = BT709_To_BT2020(_119f);
	_168f = BT709_To_BT2020(_168f);
	_128f = BT709_To_BT2020(_128f);
	_173f = BT709_To_BT2020(_173f);

	// worst case is red and blue at 0 and green high enough so that the luminance is HDR_MAX_OUTPUT_NITS
	static const float normalizationFactor = (HDR_MAX_OUTPUT_NITS / 80.f) / 0.678f;

	half3  _91 = saturate( _91f / normalizationFactor);
	half3 _139 = saturate(_139f / normalizationFactor);
	half3 _106 = saturate(_106f / normalizationFactor);
	half3 _151 = saturate(_151f / normalizationFactor);
	half3 _109 = saturate(_109f / normalizationFactor);
	half3 _156 = saturate(_156f / normalizationFactor);
	half3 _119 = saturate(_119f / normalizationFactor);
	half3 _168 = saturate(_168f / normalizationFactor);
	half3 _128 = saturate(_128f / normalizationFactor);
	half3 _173 = saturate(_173f / normalizationFactor);

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

	half hSharp = f16tof32(CASData.cas1.y & 0xFFFF);

	half _315 = hSharp * sqrt(_981);
	half _316 = hSharp * sqrt(_992);

	half _322 = 1.h / ((_315 * 4.h) + 1.h);
	half _323 = 1.h / ((_316 * 4.h) + 1.h);

	half3 _329 = (((_151 + _139 + _168 + _173) * _316) + _156) * _323;
	_329 = saturate(_329);
	float3 _1003 = _329 * normalizationFactor;

	float3 o2 = BT2020_To_BT709(_1003);

	if ((pp.x <= _55.z) && (pp.y <= _55.w))
	{
		half3 _388 = (((_106 + _91 + _119 + _128) * _315) + _109) * _322;
		_388 = saturate(_388);
		float3 _396 = _388 * normalizationFactor;

		float3 o1 = BT2020_To_BT709(_396);

		ColorOut[pp] = float4(o1, 1.f);
	}

	pp.x += 8;

	if ((pp.x <= _55.z) && (pp.y <= _55.w))
	{
		ColorOut[pp] = float4(o2, 1.f);
	}

	pp.y += 8;

	uint _507 = max(min(pp.y - 1, _73), _71);
	float3 _509f = ColorIn.Load(int3( _87, _507, 0)).rgb;

	uint _520 = max(min(pp.y, _73), _71);
	float3 _521f = ColorIn.Load(int3(_107, _520, 0)).rgb;
	float3 _524f = ColorIn.Load(int3( _87, _520, 0)).rgb;
	float3 _531f = ColorIn.Load(int3(_118, _520, 0)).rgb;

	uint _539 = max(min(pp.y + 1, _73), _71);
	float3 _540f = ColorIn.Load(int3( _87, _539, 0)).rgb;
	float3 _547f = ColorIn.Load(int3(_138, _507, 0)).rgb;
	float3 _556f = ColorIn.Load(int3(_150, _520, 0)).rgb;
	float3 _561f = ColorIn.Load(int3(_138, _520, 0)).rgb;
	float3 _570f = ColorIn.Load(int3(_167, _520, 0)).rgb;
	float3 _575f = ColorIn.Load(int3(_138, _539, 0)).rgb;

	_509f = BT709_To_BT2020(_509f);
	_547f = BT709_To_BT2020(_547f);
	_521f = BT709_To_BT2020(_521f);
	_556f = BT709_To_BT2020(_556f);
	_524f = BT709_To_BT2020(_524f);
	_561f = BT709_To_BT2020(_561f);
	_531f = BT709_To_BT2020(_531f);
	_570f = BT709_To_BT2020(_570f);
	_540f = BT709_To_BT2020(_540f);
	_575f = BT709_To_BT2020(_575f);

	half3 _509 = saturate(_509f / normalizationFactor);
	half3 _547 = saturate(_547f / normalizationFactor);
	half3 _521 = saturate(_521f / normalizationFactor);
	half3 _556 = saturate(_556f / normalizationFactor);
	half3 _524 = saturate(_524f / normalizationFactor);
	half3 _561 = saturate(_561f / normalizationFactor);
	half3 _531 = saturate(_531f / normalizationFactor);
	half3 _570 = saturate(_570f / normalizationFactor);
	half3 _540 = saturate(_540f / normalizationFactor);
	half3 _575 = saturate(_575f / normalizationFactor);

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
	_724 = saturate(_724);
	float3 _1216 = _724 * normalizationFactor;

	float3 o4 = BT2020_To_BT709(_1216);

	if ((pp.x <= _55.z) && (pp.y <= _55.w))
	{
		half3 _783 = (((_521 + _509 + _531 + _540) * _711) + _524) * _717;
		_783 = saturate(_783);
		float3 _790 = _783 * normalizationFactor;

		float3 o3 = BT2020_To_BT709(_790);

		ColorOut[uint2(_58, pp.y)] = float4(o3, 1.f);
	}

	if ((pp.x <= _55.z) && (pp.y <= _55.w))
	{
		ColorOut[pp] = float4(o4, 1.f);
	}

#endif
}
