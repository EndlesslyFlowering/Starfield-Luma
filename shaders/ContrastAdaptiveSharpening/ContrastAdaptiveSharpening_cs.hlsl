#include "../shared.hlsl"
#include "../color.hlsl"
#include "RootSignature.hlsl"

//#define USE_PACKED_MATH
//#define USE_UPSCALING

// shader permutations:
// - CAS sharpening in FP32 [FF94/1FE95]
// - CAS sharpening in FP16 with FFX_CAS_USE_PRECISE_MATH [100FF94/201FE95] (USE_PACKED_MATH)
// - CAS upscaling in FP32 [200FF94/401FE95] (USE_UPSCALING)
// - CAS upscaling in FP16 with FFX_CAS_USE_PRECISE_MATH [300FF94/601FE95] (USE_PACKED_MATH + USE_UPSCALING)

// don't need it
//cbuffer _16_18 : register(b0, space6)
//{
//	float4 _18_m0[9] : packoffset(c0); // _18_m0[1u].w = Gamma
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

#if SDR_LINEAR_INTERMEDIARY
	#define GAMMA_TO_LINEAR_HALF(x) x
	#define LINEAR_TO_GAMMA_HALF(x) x
	#define GAMMA_TO_LINEAR_SINGLE(x) x
	#define LINEAR_TO_GAMMA_SINGLE(x) x
#elif SDR_USE_GAMMA_2_2 // NOTE: these gamma formulas should use their mirrored versions in the CLAMP_INPUT_OUTPUT_TYPE < 3 case
	#define GAMMA_TO_LINEAR_HALF(x) pow(x, 2.2h)
	#define LINEAR_TO_GAMMA_HALF(x) pow(x, half(1.f / 2.2f))
	#define GAMMA_TO_LINEAR_SINGLE(x) pow(x, 2.2f)
	#define LINEAR_TO_GAMMA_SINGLE(x) pow(x, 1.f / 2.2f)
#else // doing sRGB in half is not accurate enough
	#define GAMMA_TO_LINEAR_HALF(x) gamma_sRGB_to_linear(x)
	#define LINEAR_TO_GAMMA_HALF(x) gamma_linear_to_sRGB(x)
	#define GAMMA_TO_LINEAR_SINGLE(x) gamma_sRGB_to_linear(x)
	#define LINEAR_TO_GAMMA_SINGLE(x) gamma_linear_to_sRGB(x)
#endif


#define CLAMPX(x) clamp(x, minX, maxX)
#define CLAMPY(y) clamp(y, minY, maxY)


float3 ConditionalSaturate(float3 Color)
{
#if CLAMP_INPUT_OUTPUT_TYPE >= 3
	Color = saturate(Color);
#endif
	return Color;
}

float3 PrepareForProcessing(float3 Color)
{
	if (HdrDllPluginConstants.DisplayMode > 0)
	{
		Color /= PQMaxWhitePoint;
		Color = BT709_To_WBT2020(Color);
	}
	else
	{
		Color = GAMMA_TO_LINEAR_SINGLE(Color);
	}

	return ConditionalSaturate(Color);
}

float3 PrepareForOutput(float3 Color)
{
	if (HdrDllPluginConstants.DisplayMode > 0)
	{
		Color = WBT2020_To_BT709(Color);
		Color = Color * PQMaxWhitePoint;
	}
	else
	{
		Color = LINEAR_TO_GAMMA_SINGLE(Color);
	}

	return ConditionalSaturate(Color);
}


// could theoretically be used for SDR
half3 ConditionalSaturate(half3 Color)
{
#if CLAMP_INPUT_OUTPUT_TYPE >= 3
	Color = saturate(Color);
#endif
	return Color;
}

half3 PrepareForProcessing(half3 Color)
{
	Color = GAMMA_TO_LINEAR_HALF(Color);

	return ConditionalSaturate(Color);
}

half3 PrepareForOutput(half3 Color)
{
	Color = LINEAR_TO_GAMMA_HALF(Color);

	return ConditionalSaturate(Color);
}


[RootSignature(ShaderRootSignature)]
[numthreads(64, 1, 1)]
void CS(CSInput csInput)
{
#if defined(USE_PACKED_MATH) \
 && defined(USE_UPSCALING)

// "FP16" CAS upscaling

	uint4 _55 = CASData.rectLimits0;

	uint _58 = ((csInput.SV_GroupThreadID.x >> 1) & 7)
	         | (csInput.SV_GroupID.x << 4);
	_58 += _55.x;

	uint _59 = ((csInput.SV_GroupThreadID.x >> 3) & 6)
	         | (csInput.SV_GroupThreadID.x & 1)
	         | (csInput.SV_GroupID.y << 4);
	_59 += _55.y;

	static const bool testX0 = _58 <= _55.z;
	static const bool testY0 = _59 <= _55.w;

	if (testX0 && testY0)
	{
		uint _1119 = _58 + 8;
		uint _1153 = _59 + 8;

		CASConst0 _62 = CASData.upscalingConst0;
		CASConst1 _69 = CASData.upscalingConst1;

		uint4 _101 = CASData.rectLimits1;

		uint minX = _101.x;
		uint minY = _101.y;
		uint maxX = _101.z;
		uint maxY = _101.w;

		static const float sharp = _69.sharp;


		float   _85 = (float(_58) * _62.rcpScalingFactorX) + _62.otherScalingFactorX;
		float   _86 = (float(_59) * _62.rcpScalingFactorY) + _62.otherScalingFactorY;
		float  _205 = _85 + _69.rcpScalingFactorXTimes8; // for some reason this optimisation only exists for the width
		float _1156 = (float(_1153) * _62.rcpScalingFactorY) + _62.otherScalingFactorY;

		float   _91 = frac(  _85);
		float   _93 = frac(  _86);
		float  _208 = frac( _205);
		float _1159 = frac(_1156);

		uint   _95 = uint(  _85);
		uint   _96 = uint(  _86);
		uint  _209 = uint( _205);
		uint _1160 = uint(_1156);

		uint _131 = clamp(_95 - 1, minX, maxX);
		uint _114 = clamp(_95,     minX, maxX);
		uint _148 = clamp(_95 + 1, minX, maxX);
		uint _163 = clamp(_95 + 2, minX, maxX);

		uint _116 = clamp(_96 - 1, minY, maxY);
		uint _133 = clamp(_96,     minY, maxY);
		uint _173 = clamp(_96 + 1, minY, maxY);
		uint _187 = clamp(_96 + 2, minY, maxY);

		uint _228 = clamp(_209 - 1, minX, maxX);
		uint _214 = clamp(_209,     minX, maxX);
		uint _250 = clamp(_209 + 1, minX, maxX);
		uint _272 = clamp(_209 + 2, minX, maxX);

		uint _1177 = clamp(_1160 - 1, minY, maxY);
		uint _1191 = clamp(_1160,     minY, maxY);
		uint _1225 = clamp(_1160 + 1, minY, maxY);
		uint _1239 = clamp(_1160 + 2, minY, maxY);


		//  a b c d
		//  e f g h
		//  i j k l
		//  m n o p

		float3 b0 = ColorIn.Load(int3(_114, _116, 0)).rgb;
		float3 e0 = ColorIn.Load(int3(_131, _133, 0)).rgb;
		float3 f0 = ColorIn.Load(int3(_114, _133, 0)).rgb;
		float3 c0 = ColorIn.Load(int3(_148, _116, 0)).rgb;
		float3 g0 = ColorIn.Load(int3(_148, _133, 0)).rgb;
		float3 h0 = ColorIn.Load(int3(_163, _133, 0)).rgb;
		float3 i0 = ColorIn.Load(int3(_131, _173, 0)).rgb;
		float3 j0 = ColorIn.Load(int3(_114, _173, 0)).rgb;
		float3 n0 = ColorIn.Load(int3(_114, _187, 0)).rgb;
		float3 k0 = ColorIn.Load(int3(_148, _173, 0)).rgb;
		float3 l0 = ColorIn.Load(int3(_163, _173, 0)).rgb;
		float3 o0 = ColorIn.Load(int3(_148, _187, 0)).rgb;

		b0 = PrepareForProcessing(b0);
		c0 = PrepareForProcessing(c0);
		e0 = PrepareForProcessing(e0);
		f0 = PrepareForProcessing(f0);
		g0 = PrepareForProcessing(g0);
		h0 = PrepareForProcessing(h0);
		i0 = PrepareForProcessing(i0);
		j0 = PrepareForProcessing(j0);
		k0 = PrepareForProcessing(k0);
		l0 = PrepareForProcessing(l0);
		n0 = PrepareForProcessing(n0);
		o0 = PrepareForProcessing(o0);

  	float3 _577 = min(min(b0, min(e0, f0)), min(g0, j0));
  	float3 _593 = min(min(c0, min(f0, g0)), min(h0, k0));
  	float3 _609 = min(min(f0, min(i0, j0)), min(k0, n0));
  	float3 _625 = min(min(g0, min(j0, k0)), min(l0, o0));

  	float3 _585 = max(max(b0, max(e0, f0)), max(g0, j0));
  	float3 _601 = max(max(c0, max(f0, g0)), max(h0, k0));
  	float3 _617 = max(max(f0, max(i0, j0)), max(k0, n0));
  	float3 _633 = max(max(g0, max(j0, k0)), max(l0, o0));

		float3 _644 = 1.f - _585;
		float3 _653 = 1.f - _601;
		float3 _661 = 1.f - _617;
		float3 _669 = 1.f - _633;

		float3 _648 = 1.f / _585;
		float3 _657 = 1.f / _601;
		float3 _665 = 1.f / _617;
		float3 _673 = 1.f / _633;

		_648 *= min(_577, _644);
		_657 *= min(_593, _653);
		_665 *= min(_609, _661);
		_673 *= min(_625, _669);

		float3 _2515 = saturate(_648);
		float3 _2547 = saturate(_657);
		float3 _2579 = saturate(_665);
		float3 _2611 = saturate(_673);

		float3  _699 = 1.f   - _91;
		float3  _701 = 1.f   - _93;
		float3  _700 = 1.f  - _208;
		float3 _1732 = 1.f - _1159;

		float3 _717 = 0.03125f - _577;
		float3 _725 = 0.03125f - _593;
		float3 _733 = 0.03125f - _609;
		float3 _741 = 0.03125f - _625;

		_717 += _585;
		_725 += _601;
		_733 += _617;
		_741 += _633;

		_717 = 1.f / _717;
		_725 = 1.f / _725;
		_733 = 1.f / _733;
		_741 = 1.f / _741;

		_717 *= _701 * _699;
		_725 *= _701 *  _91;
		_733 *=  _93 * _699;
		_741 *=  _93 *  _91;

		float3 _743 = sqrt(_2515);
		float3 _745 = sqrt(_2547);
		float3 _747 = sqrt(_2579);
		float3 _753 = sqrt(_2611);

		_743 *= sharp;
		_745 *= sharp;
		_747 *= sharp;
		_753 *= sharp;

		_743 *= _717;
		_745 *= _725;
		_747 *= _733;
		_753 *= _741;

		float3 _750 = (_745 + _717) + _747;
		float3 _756 = (_725 + _743) + _753;
		float3 _760 = (_733 + _743) + _753;
		float3 _765 = (_747 + _745) + _741;

		float3 _784 = 1.f / (((_745 + _743 + _747 + _753) * 2.f) + _765 + _750 + _756 + _760);

		float3 colorOut0 = ((((((((f0 *  _750) + ((e0 + b0) *  _743)) + (g0 *  _756)) + (j0 *  _760)) + (k0 *  _765)) + ((o0 + l0) *  _753)) + ((n0 + i0) *  _747)) + ((h0 + c0) *  _745)) *  _784;

		colorOut0 = PrepareForOutput(colorOut0);

		ColorOut[uint2(_58, _59)] = float4(colorOut0, 1.f);

		static const bool testX1 = _1119 <= _55.z;
		static const bool testY1 = _1153 <= _55.w;

		if (testX1)
		{
			float3 b1 = ColorIn.Load(int3(_214, _116, 0)).rgb;
			float3 e1 = ColorIn.Load(int3(_228, _133, 0)).rgb;
			float3 f1 = ColorIn.Load(int3(_214, _133, 0)).rgb;
			float3 c1 = ColorIn.Load(int3(_250, _116, 0)).rgb;
			float3 g1 = ColorIn.Load(int3(_250, _133, 0)).rgb;
			float3 h1 = ColorIn.Load(int3(_272, _133, 0)).rgb;
			float3 i1 = ColorIn.Load(int3(_228, _173, 0)).rgb;
			float3 j1 = ColorIn.Load(int3(_214, _173, 0)).rgb;
			float3 n1 = ColorIn.Load(int3(_214, _187, 0)).rgb;
			float3 k1 = ColorIn.Load(int3(_250, _173, 0)).rgb;
			float3 l1 = ColorIn.Load(int3(_272, _173, 0)).rgb;
			float3 o1 = ColorIn.Load(int3(_250, _187, 0)).rgb;

			b1 = PrepareForProcessing(b1);
			c1 = PrepareForProcessing(c1);
			e1 = PrepareForProcessing(e1);
			f1 = PrepareForProcessing(f1);
			g1 = PrepareForProcessing(g1);
			h1 = PrepareForProcessing(h1);
			i1 = PrepareForProcessing(i1);
			j1 = PrepareForProcessing(j1);
			k1 = PrepareForProcessing(k1);
			l1 = PrepareForProcessing(l1);
			n1 = PrepareForProcessing(n1);
			o1 = PrepareForProcessing(o1);

		  float3 _578 = min(min(b1, min(e1, f1)), min(g1, j1));
		  float3 _594 = min(min(c1, min(f1, g1)), min(h1, k1));
		  float3 _610 = min(min(f1, min(i1, j1)), min(k1, n1));
		  float3 _626 = min(min(g1, min(j1, k1)), min(l1, o1));

		  float3 _586 = max(max(b1, max(e1, f1)), max(g1, j1));
		  float3 _602 = max(max(c1, max(f1, g1)), max(h1, k1));
		  float3 _618 = max(max(f1, max(i1, j1)), max(k1, n1));
		  float3 _634 = max(max(g1, max(j1, k1)), max(l1, o1));

			float3 _645 = 1.f - _586;
			float3 _654 = 1.f - _602;
			float3 _662 = 1.f - _618;
			float3 _670 = 1.f - _634;

			float3 _649 = 1.f / _586;
			float3 _658 = 1.f / _602;
			float3 _666 = 1.f / _618;
			float3 _674 = 1.f / _634;

			_649 *= min(_578, _645);
			_658 *= min(_594, _654);
			_666 *= min(_610, _662);
			_674 *= min(_626, _670);

			float3 _2526 = saturate(_649);
			float3 _2558 = saturate(_658);
			float3 _2590 = saturate(_666);
			float3 _2622 = saturate(_674);

			float3 _718 = 0.03125f - _578;
			float3 _726 = 0.03125f - _594;
			float3 _734 = 0.03125f - _610;
			float3 _742 = 0.03125f - _626;

			_718 += _586;
			_726 += _602;
			_734 += _618;
			_742 += _634;

			_718 = 1.f / _718;
			_726 = 1.f / _726;
			_734 = 1.f / _734;
			_742 = 1.f / _742;

			_718 *= _701 * _700;
			_726 *= _701 * _208;
			_734 *=  _93 * _700;
			_742 *=  _93 * _208;

			float3 _744 = sqrt(_2526);
			float3 _746 = sqrt(_2558);
			float3 _748 = sqrt(_2590);
			float3 _754 = sqrt(_2622);

			_744 *= sharp;
			_746 *= sharp;
			_748 *= sharp;
			_754 *= sharp;

			_744 *= _718;
			_746 *= _726;
			_748 *= _734;
			_754 *= _742;

			float3 _752 = (_746 + _718) + _748;
			float3 _758 = (_726 + _744) + _754;
			float3 _762 = (_734 + _744) + _754;
			float3 _766 = (_748 + _746) + _742;

			float3 _785 = 1.f /(((_746 + _744 + _748 + _754) * 2.f) + _766 + _752 + _758 + _762);

			float3 colorOut1 = ((((((((f1 *  _752) + ((e1 + b1) *  _744)) + (k1 *  _766)) + (g1 *  _758)) + (j1 *  _762)) + ((o1 + l1) *  _754)) + ((n1 + i1) *  _748)) + ((h1 + c1) *  _746)) *  _785;

			colorOut1 = PrepareForOutput(colorOut1);

			ColorOut[uint2(_1119, _59)] = float4(colorOut1, 1.f);

			if (testY1)
			{
				float3 b3 = ColorIn.Load(int3(_214, _1177, 0)).rgb;
				float3 e3 = ColorIn.Load(int3(_228, _1191, 0)).rgb;
				float3 f3 = ColorIn.Load(int3(_214, _1191, 0)).rgb;
				float3 c3 = ColorIn.Load(int3(_250, _1177, 0)).rgb;
				float3 g3 = ColorIn.Load(int3(_250, _1191, 0)).rgb;
				float3 h3 = ColorIn.Load(int3(_272, _1191, 0)).rgb;
				float3 i3 = ColorIn.Load(int3(_228, _1225, 0)).rgb;
				float3 j3 = ColorIn.Load(int3(_214, _1225, 0)).rgb;
				float3 n3 = ColorIn.Load(int3(_214, _1239, 0)).rgb;
				float3 k3 = ColorIn.Load(int3(_250, _1225, 0)).rgb;
				float3 l3 = ColorIn.Load(int3(_272, _1225, 0)).rgb;
				float3 o3 = ColorIn.Load(int3(_250, _1239, 0)).rgb;

				b3 = PrepareForProcessing(b3);
				c3 = PrepareForProcessing(c3);
				e3 = PrepareForProcessing(e3);
				f3 = PrepareForProcessing(f3);
				g3 = PrepareForProcessing(g3);
				h3 = PrepareForProcessing(h3);
				i3 = PrepareForProcessing(i3);
				j3 = PrepareForProcessing(j3);
				k3 = PrepareForProcessing(k3);
				l3 = PrepareForProcessing(l3);
				n3 = PrepareForProcessing(n3);
				o3 = PrepareForProcessing(o3);

			  float3 _1619 = min(min(b3, min(e3, f3)), min(g3, j3));
			  float3 _1635 = min(min(c3, min(f3, g3)), min(h3, k3));
			  float3 _1651 = min(min(f3, min(i3, j3)), min(k3, n3));
			  float3 _1667 = min(min(g3, min(j3, k3)), min(l3, o3));

			  float3 _1627 = max(max(b3, max(e3, f3)), max(g3, j3));
			  float3 _1643 = max(max(c3, max(f3, g3)), max(h3, k3));
			  float3 _1659 = max(max(f3, max(i3, j3)), max(k3, n3));
			  float3 _1675 = max(max(g3, max(j3, k3)), max(l3, o3));

				float3 _1685 = 1.f - _1627;
				float3 _1693 = 1.f - _1643;
				float3 _1701 = 1.f - _1659;
				float3 _1709 = 1.f - _1675;

				float3 _1689 = 1.f / _1627;
				float3 _1697 = 1.f / _1643;
				float3 _1705 = 1.f / _1659;
				float3 _1713 = 1.f / _1675;

				_1689 *= min(_1619, _1685);
				_1697 *= min(_1635, _1693);
				_1705 *= min(_1651, _1701);
				_1713 *= min(_1667, _1709);

				float3 _3075 = saturate(_1689);
				float3 _3107 = saturate(_1697);
				float3 _3139 = saturate(_1705);
				float3 _3171 = saturate(_1713);

				float3 _1748 = 0.03125f - _1619;
				float3 _1756 = 0.03125f - _1635;
				float3 _1764 = 0.03125f - _1651;
				float3 _1772 = 0.03125f - _1667;

				_1748 += _1627;
				_1756 += _1643;
				_1764 += _1659;
				_1772 += _1675;

				_1748 = 1.f / _1748;
				_1756 = 1.f / _1756;
				_1764 = 1.f / _1764;
				_1772 = 1.f / _1772;

				_1748 *= _1732 * _700;
				_1756 *= _1732 * _208;
				_1764 *= _1159 * _700;
				_1772 *= _1159 * _208;

				float3 _1774 = sqrt(_3075);
				float3 _1776 = sqrt(_3107);
				float3 _1778 = sqrt(_3139);
				float3 _1784 = sqrt(_3171);

				_1774 *= sharp;
				_1776 *= sharp;
				_1778 *= sharp;
				_1784 *= sharp;

				_1774 *= _1748;
				_1776 *= _1756;
				_1778 *= _1764;
				_1784 *= _1772;

				float3 _1782 = (_1776 + _1748) + _1778;
				float3 _1788 = (_1756 + _1774) + _1784;
				float3 _1792 = (_1764 + _1774) + _1784;
				float3 _1796 = (_1778 + _1776) + _1772;

				float3 _1814 = 1.f / (((_1776 + _1774 + _1778 + _1784) * 2.f) + _1796 + _1782 + _1788 + _1792);

				float3 colorOut3 = ((((((((f3 * _1782) + ((e3 + b3) * _1774)) + (k3 * _1796)) + (g3 * _1788)) + (j3 * _1792)) + ((o3 + l3) * _1784)) + ((n3 + i3) * _1778)) + ((h3 + c3) * _1776)) * _1814;

				colorOut3 = PrepareForOutput(colorOut3);

				ColorOut[uint2(_1119, _1153)] = float4(colorOut3, 1.f);
			}
		}

		if (testY1)
		{
			float3 b2 = ColorIn.Load(int3(_114, _1177, 0)).rgb;
			float3 e2 = ColorIn.Load(int3(_131, _1191, 0)).rgb;
			float3 f2 = ColorIn.Load(int3(_114, _1191, 0)).rgb;
			float3 c2 = ColorIn.Load(int3(_148, _1177, 0)).rgb;
			float3 g2 = ColorIn.Load(int3(_148, _1191, 0)).rgb;
			float3 h2 = ColorIn.Load(int3(_163, _1191, 0)).rgb;
			float3 i2 = ColorIn.Load(int3(_131, _1225, 0)).rgb;
			float3 j2 = ColorIn.Load(int3(_114, _1225, 0)).rgb;
			float3 n2 = ColorIn.Load(int3(_114, _1239, 0)).rgb;
			float3 k2 = ColorIn.Load(int3(_148, _1225, 0)).rgb;
			float3 l2 = ColorIn.Load(int3(_163, _1225, 0)).rgb;
			float3 o2 = ColorIn.Load(int3(_148, _1239, 0)).rgb;

			b2 = PrepareForProcessing(b2);
			c2 = PrepareForProcessing(c2);
			e2 = PrepareForProcessing(e2);
			f2 = PrepareForProcessing(f2);
			g2 = PrepareForProcessing(g2);
			h2 = PrepareForProcessing(h2);
			i2 = PrepareForProcessing(i2);
			j2 = PrepareForProcessing(j2);
			k2 = PrepareForProcessing(k2);
			l2 = PrepareForProcessing(l2);
			n2 = PrepareForProcessing(n2);
			o2 = PrepareForProcessing(o2);

		  float3 _1618 = min(min(b2, min(e2, f2)), min(g2, j2));
		  float3 _1634 = min(min(c2, min(f2, g2)), min(h2, k2));
		  float3 _1650 = min(min(f2, min(i2, j2)), min(k2, n2));
		  float3 _1666 = min(min(g2, min(j2, k2)), min(l2, o2));

		  float3 _1626 = max(max(b2, max(e2, f2)), max(g2, j2));
		  float3 _1642 = max(max(c2, max(f2, g2)), max(h2, k2));
		  float3 _1658 = max(max(f2, max(i2, j2)), max(k2, n2));
		  float3 _1674 = max(max(g2, max(j2, k2)), max(l2, o2));

			float3 _1684 = 1.f - _1626;
			float3 _1692 = 1.f - _1642;
			float3 _1700 = 1.f - _1658;
			float3 _1708 = 1.f - _1674;

			float3 _1688 = 1.f / _1626;
			float3 _1696 = 1.f / _1642;
			float3 _1704 = 1.f / _1658;
			float3 _1712 = 1.f / _1674;

			_1688 *= min(_1618, _1684);
			_1696 *= min(_1634, _1692);
			_1704 *= min(_1650, _1700);
			_1712 *= min(_1666, _1708);

			float3 _3064 = saturate(_1688);
			float3 _3096 = saturate(_1696);
			float3 _3128 = saturate(_1704);
			float3 _3160 = saturate(_1712);

			float3 _1747 = 0.03125f - _1618;
			float3 _1755 = 0.03125f - _1634;
			float3 _1763 = 0.03125f - _1650;
			float3 _1771 = 0.03125f - _1666;

			_1747 += _1626;
			_1755 += _1642;
			_1763 += _1658;
			_1771 += _1674;

			_1747 = 1.f / _1747;
			_1755 = 1.f / _1755;
			_1763 = 1.f / _1763;
			_1771 = 1.f / _1771;

			_1747 *= _1732 * _699;
			_1755 *= _1732 *  _91;
			_1763 *= _1159 * _699;
			_1771 *= _1159 *  _91;

			float3 _1773 = sqrt(_3064);
			float3 _1775 = sqrt(_3096);
			float3 _1777 = sqrt(_3128);
			float3 _1783 = sqrt(_3160);

			_1773 *= sharp;
			_1775 *= sharp;
			_1777 *= sharp;
			_1783 *= sharp;

			_1773 *= _1747;
			_1775 *= _1755;
			_1777 *= _1763;
			_1783 *= _1771;

			float3 _1780 = (_1775 + _1747) + _1777;
			float3 _1786 = (_1755 + _1773) + _1783;
			float3 _1790 = (_1763 + _1773) + _1783;
			float3 _1795 = (_1777 + _1775) + _1771;

			float3 _1813 = 1.f / (((_1775 + _1773 + _1777 + _1783) * 2.f) + _1795 + _1780 + _1786 + _1790);

			float3 colorOut2 = ((((((((f2 * _1780) + ((e2 + b2) * _1773)) + (g2 * _1786)) + (j2 * _1790)) + (k2 * _1795)) + ((o2 + l2) * _1783)) + ((n2 + i2) * _1777)) + ((h2 + c2) * _1775)) * _1813;

			colorOut2 = PrepareForOutput(colorOut2);

			ColorOut[uint2(_58, _1153)] = float4(colorOut2, 1.f);
		}
	}

#elif !defined(USE_PACKED_MATH) \
    && defined(USE_UPSCALING)

// FP32 CAS upscaling

	uint4 _55 = CASData.rectLimits0;

	uint _58 = ((csInput.SV_GroupThreadID.x >> 1) & 7)
	         | (csInput.SV_GroupID.x << 4);
	_58 += _55.x;

	uint _59 = ((csInput.SV_GroupThreadID.x >> 3) & 6)
	         | (csInput.SV_GroupThreadID.x & 1)
	         | (csInput.SV_GroupID.y << 4);
	_59 += _55.y;

	static const bool testX0 = _58 <= _55.z;
	static const bool testY0 = _59 <= _55.w;

	if (testX0 && testY0)
	{
		uint  _604 = _58 + 8;
		uint _1110 = _59 + 8;

		CASConst0 _62 = CASData.upscalingConst0;
		CASConst1 _69 = CASData.upscalingConst1;

		uint4 _92 = CASData.rectLimits1;

		uint minX = _92.x;
		uint minY = _92.y;
		uint maxX = _92.z;
		uint maxY = _92.w;

		static const float sharp = _69.sharp;

		float _79   = (float(_58)   * _62.rcpScalingFactorX) + _62.otherScalingFactorX;
		float _80   = (float(_59)   * _62.rcpScalingFactorY) + _62.otherScalingFactorY;
		float _607  = _79 + _69.rcpScalingFactorXTimes8; // for some reason this optimisation only exists for the width
		float _1113 = (float(_1110) * _62.rcpScalingFactorY) + _62.otherScalingFactorY;

		float   _82 = floor(  _79);
		float   _83 = floor(  _80);
		float  _608 = floor( _607);
		float _1114 = floor(_1113);

		float   _84 =   _79 -   _82;
		float   _85 =   _80 -   _83;
		float  _609 =  _607 -  _608;
		float _1115 = _1113 - _1114;

		uint   _86 = uint(  _82);
		uint   _87 = uint(  _83);
		uint  _610 = uint( _608);
		uint _1116 = uint(_1114);

		uint _109 = CLAMPX(_86 - 1);
		uint  _99 = CLAMPX(_86);
		uint _119 = CLAMPX(_86 + 1);
		uint _128 = CLAMPX(_86 + 2);

		uint _629 = CLAMPX(_610 - 1);
		uint _620 = CLAMPX(_610);
		uint _639 = CLAMPX(_610 + 1);
		uint _648 = CLAMPX(_610 + 2);

		uint _100 = CLAMPY(_87 - 1);
		uint _110 = CLAMPY(_87);
		uint _134 = CLAMPY(_87 + 1);
		uint _143 = CLAMPY(_87 + 2);

		uint _1128 = CLAMPY(_1116 - 1);
		uint _1136 = CLAMPY(_1116);
		uint _1158 = CLAMPY(_1116 + 1);
		uint _1167 = CLAMPY(_1116 + 2);


		float3 _102 = ColorIn.Load(int3( _99, _100, 0)).rgb;
		float3 _111 = ColorIn.Load(int3(_109, _110, 0)).rgb;
		float3 _114 = ColorIn.Load(int3( _99, _110, 0)).rgb;
		float3 _120 = ColorIn.Load(int3(_119, _100, 0)).rgb;
		float3 _123 = ColorIn.Load(int3(_119, _110, 0)).rgb;
		float3 _129 = ColorIn.Load(int3(_128, _110, 0)).rgb;
		float3 _135 = ColorIn.Load(int3(_109, _134, 0)).rgb;
		float3 _138 = ColorIn.Load(int3( _99, _134, 0)).rgb;
		float3 _144 = ColorIn.Load(int3( _99, _143, 0)).rgb;
		float3 _147 = ColorIn.Load(int3(_119, _134, 0)).rgb;
		float3 _150 = ColorIn.Load(int3(_128, _134, 0)).rgb;
		float3 _153 = ColorIn.Load(int3(_119, _143, 0)).rgb;

		float3 _165 = PrepareForProcessing(_102);
		float3 _170 = PrepareForProcessing(_120);
		float3 _175 = PrepareForProcessing(_111);
		float3 _180 = PrepareForProcessing(_114);
		float3 _185 = PrepareForProcessing(_123);
		float3 _190 = PrepareForProcessing(_129);
		float3 _195 = PrepareForProcessing(_135);
		float3 _200 = PrepareForProcessing(_138);
		float3 _205 = PrepareForProcessing(_147);
		float3 _210 = PrepareForProcessing(_150);
		float3 _215 = PrepareForProcessing(_144);
		float3 _220 = PrepareForProcessing(_153);

		float3 _224 = min(min(_165, min(_175, _180)), min(_185, _200));
		float3 _228 = max(max(_165, max(_175, _180)), max(_185, _200));

		float3 _232 = min(min(_170, min(_180, _185)), min(_190, _205));
		float3 _236 = max(max(_170, max(_180, _185)), max(_190, _205));

		float3 _240 = min(min(_180, min(_195, _200)), min(_205, _215));
		float3 _244 = max(max(_180, max(_195, _200)), max(_205, _215));

		float3 _248 = min(min(_185, min(_200, _205)), min(_210, _220));
		float3 _252 = max(max(_185, max(_200, _205)), max(_210, _220));

		float3  _306 = 1.f -   _84;
		float3  _307 = 1.f -   _85;
		float3  _817 = 1.f -  _609;
		float3 _1323 = 1.f - _1115;

		float3 _318 = (_306 * _307) * (1.f / ((0.03125f - _224) + _228));
		float3 _324 = (_307 *  _84) * (1.f / ((0.03125f - _232) + _236));
		float3 _330 = (_306 *  _85) * (1.f / ((0.03125f - _240) + _244));
		float3 _336 = ( _84 *  _85) * (1.f / ((0.03125f - _248) + _252));

		float3 _337 = (sqrt(saturate(min(_224, 1.f - _228) * (1.f / _228))) * sharp) * _318;
		float3 _338 = (sqrt(saturate(min(_232, 1.f - _236) * (1.f / _236))) * sharp) * _324;
		float3 _339 = (sqrt(saturate(min(_240, 1.f - _244) * (1.f / _244))) * sharp) * _330;
		float3 _342 = (sqrt(saturate(min(_248, 1.f - _252) * (1.f / _252))) * sharp) * _336;

		float3 _341 = (_338 + _318) + _339;
		float3 _344 = (_337 + _324) + _342;
		float3 _346 = (_337 + _330) + _342;
		float3 _348 = (_338 + _336) + _339;

		float3 _364 = 1.f / (((_338 + _337 + _339 + _342) * 2.f) + _348 + _341 + _344 + _346);

		float3 colorOut0 = _364 * ((((((((_341 * _180) + (_337 * (_175 + _165))) + (_348 * _205)) + (_344 * _185)) + (_346 * _200)) + (_342 * (_220 + _210))) + (_339 * (_215 + _195))) + (_338 * (_190 + _170)));

		colorOut0 = PrepareForOutput(colorOut0);

		ColorOut[uint2(_58, _59)] = float4(colorOut0, 1.f);


		static const bool testX1 =  _604 <= _55.z;
		static const bool testY1 = _1110 <= _55.w;

		if (testX1)
		{
			float3 _623 = ColorIn.Load(int3(_620, _100, 0)).rgb;
			float3 _631 = ColorIn.Load(int3(_629, _110, 0)).rgb;
			float3 _634 = ColorIn.Load(int3(_620, _110, 0)).rgb;
			float3 _640 = ColorIn.Load(int3(_639, _100, 0)).rgb;
			float3 _643 = ColorIn.Load(int3(_639, _110, 0)).rgb;
			float3 _649 = ColorIn.Load(int3(_648, _110, 0)).rgb;
			float3 _654 = ColorIn.Load(int3(_629, _134, 0)).rgb;
			float3 _657 = ColorIn.Load(int3(_620, _134, 0)).rgb;
			float3 _662 = ColorIn.Load(int3(_620, _143, 0)).rgb;
			float3 _665 = ColorIn.Load(int3(_639, _134, 0)).rgb;
			float3 _668 = ColorIn.Load(int3(_648, _134, 0)).rgb;
			float3 _671 = ColorIn.Load(int3(_639, _143, 0)).rgb;

			float3 _681 = PrepareForProcessing(_623);
			float3 _686 = PrepareForProcessing(_640);
			float3 _691 = PrepareForProcessing(_631);
			float3 _696 = PrepareForProcessing(_634);
			float3 _701 = PrepareForProcessing(_643);
			float3 _706 = PrepareForProcessing(_649);
			float3 _711 = PrepareForProcessing(_654);
			float3 _716 = PrepareForProcessing(_657);
			float3 _721 = PrepareForProcessing(_665);
			float3 _726 = PrepareForProcessing(_668);
			float3 _731 = PrepareForProcessing(_662);
			float3 _736 = PrepareForProcessing(_671);

			float3 _740 = min(min(_681, min(_691, _696)), min(_701, _716));
			float3 _744 = max(max(_681, max(_691, _696)), max(_701, _716));

			float3 _748 = min(min(_686, min(_696, _701)), min(_706, _721));
			float3 _752 = max(max(_686, max(_696, _701)), max(_706, _721));

			float3 _756 = min(min(_696, min(_711, _716)), min(_721, _731));
			float3 _760 = max(max(_696, max(_711, _716)), max(_721, _731));

			float3 _764 = min(min(_701, min(_716, _721)), min(_726, _736));
			float3 _768 = max(max(_701, max(_716, _721)), max(_726, _736));

			float3 _827 = (_307 * _817) * (1.f / ((0.03125f - _740) + _744));
			float3 _833 = (_307 * _609) * (1.f / ((0.03125f - _748) + _752));
			float3 _839 = (_817 *  _85) * (1.f / ((0.03125f - _756) + _760));
			float3 _845 = ( _85 * _609) * (1.f / ((0.03125f - _764) + _768));

			float3 _846 = (sqrt(saturate(min(_740, 1.f - _744) * (1.f / _744))) * sharp) * _827;
			float3 _847 = (sqrt(saturate(min(_748, 1.f - _752) * (1.f / _752))) * sharp) * _833;
			float3 _848 = (sqrt(saturate(min(_756, 1.f - _760) * (1.f / _760))) * sharp) * _839;
			float3 _851 = (sqrt(saturate(min(_764, 1.f - _768) * (1.f / _768))) * sharp) * _845;

			float3 _850 = (_847 + _827) + _848;
			float3 _853 = (_846 + _833) + _851;
			float3 _855 = (_846 + _839) + _851;
			float3 _857 = (_847 + _845) + _848;

			float3 _871 = 1.f / (((_847 + _846 + _848 + _851) * 2.f) + _857 + _850 + _853 + _855);

			float3 colorOut1 = _871 * ((((((((_850 * _696) + (_846 * (_691 + _681))) + (_857 * _721)) + (_853 * _701)) + (_855 * _716)) + (_851 * (_736 + _726))) + (_848 * (_731 + _711))) + (_847 * (_706 + _686)));

			colorOut1 = PrepareForOutput(colorOut1);

			ColorOut[uint2(_604, _59)] = float4(colorOut1, 1.f);

			if (testY1)
			{
				float3 _1130 = ColorIn.Load(int3(_620, _1128, 0)).rgb;
				float3 _1137 = ColorIn.Load(int3(_629, _1136, 0)).rgb;
				float3 _1140 = ColorIn.Load(int3(_620, _1136, 0)).rgb;
				float3 _1145 = ColorIn.Load(int3(_639, _1128, 0)).rgb;
				float3 _1148 = ColorIn.Load(int3(_639, _1136, 0)).rgb;
				float3 _1153 = ColorIn.Load(int3(_648, _1136, 0)).rgb;
				float3 _1159 = ColorIn.Load(int3(_629, _1158, 0)).rgb;
				float3 _1162 = ColorIn.Load(int3(_620, _1158, 0)).rgb;
				float3 _1168 = ColorIn.Load(int3(_620, _1167, 0)).rgb;
				float3 _1171 = ColorIn.Load(int3(_639, _1158, 0)).rgb;
				float3 _1174 = ColorIn.Load(int3(_648, _1158, 0)).rgb;
				float3 _1177 = ColorIn.Load(int3(_639, _1167, 0)).rgb;

				float3 _1187 = PrepareForProcessing(_1130);
				float3 _1192 = PrepareForProcessing(_1145);
				float3 _1197 = PrepareForProcessing(_1137);
				float3 _1202 = PrepareForProcessing(_1140);
				float3 _1207 = PrepareForProcessing(_1148);
				float3 _1212 = PrepareForProcessing(_1153);
				float3 _1217 = PrepareForProcessing(_1159);
				float3 _1222 = PrepareForProcessing(_1162);
				float3 _1227 = PrepareForProcessing(_1171);
				float3 _1232 = PrepareForProcessing(_1174);
				float3 _1237 = PrepareForProcessing(_1168);
				float3 _1242 = PrepareForProcessing(_1177);

				float3 _1246 = min(min(_1187, min(_1197, _1202)), min(_1207, _1222));
				float3 _1250 = max(max(_1187, max(_1197, _1202)), max(_1207, _1222));

				float3 _1254 = min(min(_1192, min(_1202, _1207)), min(_1212, _1227));
				float3 _1258 = max(max(_1192, max(_1202, _1207)), max(_1212, _1227));

				float3 _1262 = min(min(_1202, min(_1217, _1222)), min(_1227, _1237));
				float3 _1266 = max(max(_1202, max(_1217, _1222)), max(_1227, _1237));

				float3 _1270 = min(min(_1207, min(_1222, _1227)), min(_1232, _1242));
				float3 _1274 = max(max(_1207, max(_1222, _1227)), max(_1232, _1242));

				float3 _1333 = (_1323 * _817) * (1.f / ((0.03125f - _1246) + _1250));
				float3 _1339 = (_1323 * _609) * (1.f / ((0.03125f - _1254) + _1258));
				float3 _1345 = (_817 * _1115) * (1.f / ((0.03125f - _1262) + _1266));
				float3 _1351 = (_1115 * _609) * (1.f / ((0.03125f - _1270) + _1274));

				float3 _1352 = (sqrt(saturate(min(_1246, 1.f - _1250) * (1.f / _1250))) * sharp) * _1333;
				float3 _1353 = (sqrt(saturate(min(_1254, 1.f - _1258) * (1.f / _1258))) * sharp) * _1339;
				float3 _1354 = (sqrt(saturate(min(_1262, 1.f - _1266) * (1.f / _1266))) * sharp) * _1345;
				float3 _1357 = (sqrt(saturate(min(_1270, 1.f - _1274) * (1.f / _1274))) * sharp) * _1351;

				float3 _1356 = (_1353 + _1333) + _1354;
				float3 _1359 = (_1352 + _1339) + _1357;
				float3 _1361 = (_1352 + _1345) + _1357;
				float3 _1363 = (_1353 + _1351) + _1354;

				float3 _1377 = 1.f / (((_1353 + _1352 + _1354 + _1357) * 2.f) + _1363 + _1356 + _1359 + _1361);

				float3 colorOut2 = _1377 * ((((((((_1356 * _1202) + (_1352 * (_1197 + _1187))) + (_1363 * _1227)) + (_1359 * _1207)) + (_1361 * _1222)) + (_1357 * (_1242 + _1232))) + (_1354 * (_1237 + _1217))) + (_1353 * (_1212 + _1192)));

				colorOut2 = PrepareForOutput(colorOut2);

				ColorOut[uint2(_604, _1110)] = float4(colorOut2, 1.f);
			}
		}

		if (testY1)
		{
			float3 _1628 = ColorIn.Load(int3( _99, _1128, 0)).rgb;
			float3 _1635 = ColorIn.Load(int3(_109, _1136, 0)).rgb;
			float3 _1638 = ColorIn.Load(int3( _99, _1136, 0)).rgb;
			float3 _1643 = ColorIn.Load(int3(_119, _1128, 0)).rgb;
			float3 _1646 = ColorIn.Load(int3(_119, _1136, 0)).rgb;
			float3 _1651 = ColorIn.Load(int3(_128, _1136, 0)).rgb;
			float3 _1656 = ColorIn.Load(int3(_109, _1158, 0)).rgb;
			float3 _1659 = ColorIn.Load(int3( _99, _1158, 0)).rgb;
			float3 _1664 = ColorIn.Load(int3( _99, _1167, 0)).rgb;
			float3 _1667 = ColorIn.Load(int3(_119, _1158, 0)).rgb;
			float3 _1670 = ColorIn.Load(int3(_128, _1158, 0)).rgb;
			float3 _1673 = ColorIn.Load(int3(_119, _1167, 0)).rgb;

			float3 _1683 = PrepareForProcessing(_1628);
			float3 _1688 = PrepareForProcessing(_1643);
			float3 _1693 = PrepareForProcessing(_1635);
			float3 _1698 = PrepareForProcessing(_1638);
			float3 _1703 = PrepareForProcessing(_1646);
			float3 _1708 = PrepareForProcessing(_1651);
			float3 _1713 = PrepareForProcessing(_1656);
			float3 _1718 = PrepareForProcessing(_1659);
			float3 _1723 = PrepareForProcessing(_1667);
			float3 _1728 = PrepareForProcessing(_1670);
			float3 _1733 = PrepareForProcessing(_1664);
			float3 _1738 = PrepareForProcessing(_1673);

			float3 _1742 = min(min(_1683, min(_1693, _1698)), min(_1703, _1718));
			float3 _1746 = max(max(_1683, max(_1693, _1698)), max(_1703, _1718));

			float3 _1750 = min(min(_1688, min(_1698, _1703)), min(_1708, _1723));
			float3 _1754 = max(max(_1688, max(_1698, _1703)), max(_1708, _1723));

			float3 _1758 = min(min(_1698, min(_1713, _1718)), min(_1723, _1733));
			float3 _1762 = max(max(_1698, max(_1713, _1718)), max(_1723, _1733));

			float3 _1766 = min(min(_1703, min(_1718, _1723)), min(_1728, _1738));
			float3 _1770 = max(max(_1703, max(_1718, _1723)), max(_1728, _1738));

			float3 _1828 = (_1323 *  _306) * (1.f / ((0.03125f - _1742) + _1746));
			float3 _1834 = (_1323 *   _84) * (1.f / ((0.03125f - _1750) + _1754));
			float3 _1840 = ( _306 * _1115) * (1.f / ((0.03125f - _1758) + _1762));
			float3 _1846 = (_1115 *   _84) * (1.f / ((0.03125f - _1766) + _1770));

			float3 _1847 = (sqrt(saturate(min(_1742, 1.f - _1746) * (1.f / _1746))) * sharp) * _1828;
			float3 _1848 = (sqrt(saturate(min(_1750, 1.f - _1754) * (1.f / _1754))) * sharp) * _1834;
			float3 _1849 = (sqrt(saturate(min(_1758, 1.f - _1762) * (1.f / _1762))) * sharp) * _1840;
			float3 _1852 = (sqrt(saturate(min(_1766, 1.f - _1770) * (1.f / _1770))) * sharp) * _1846;

			float3 _1851 = (_1848 + _1828) + _1849;
			float3 _1854 = (_1847 + _1834) + _1852;
			float3 _1856 = (_1847 + _1840) + _1852;
			float3 _1858 = (_1848 + _1846) + _1849;

			float3 _1872 = 1.f / (((_1848 + _1847 + _1849 + _1852) * 2.f) + _1858 + _1851 + _1854 + _1856);

			float3 colorOut3 = _1872 * ((((((((_1851 * _1698) + (_1847 * (_1693 + _1683))) + (_1858 * _1723)) + (_1854 * _1703)) + (_1856 * _1718)) + (_1852 * (_1738 + _1728))) + (_1849 * (_1733 + _1713))) + (_1848 * (_1708 + _1688)));

			colorOut3 = PrepareForOutput(colorOut3);

			ColorOut[uint2(_58, _1110)] = float4(colorOut3, 1.f);
		}
	}

#elif defined(USE_PACKED_MATH) \
  && !defined(USE_UPSCALING)

// "FP16" CAS sharpening

#if 0 // Disable the CS so it just outputs the input
	uint2 _55 = CASData.rectLimits0.xy;
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

	static const bool testX0 = _58 <= _55.z;
	static const bool testY0 = _59 <= _55.w;

	if (testX0 && testY0)
	{
		uint _495 = _58 + 8;
		uint _529 = _59 + 8;

		uint4 _71 = CASData.rectLimits1;

		uint minX = _71.x;
		uint minY = _71.y;
		uint maxX = _71.z;
		uint maxY = _71.w;

		static const float sharp = CASData.upscalingConst1.sharp;

		uint _100 = clamp(_58 - 1, minX, maxX);
		uint  _89 = clamp(_58,     minX, maxX);
		uint _120 = clamp(_58 + 1, minX, maxX);

		uint  _91 = clamp(_59 - 1, minY, maxY);
		uint _108 = clamp(_59,     minY, maxY);
		uint _133 = clamp(_59 + 1, minY, maxY);

		uint _157 = clamp(_495 - 1, minX, maxX);
		uint _145 = clamp(_495,     minX, maxX);
		uint _180 = clamp(_495 + 1, minX, maxX);

		uint _547 = clamp(_529 - 1, minY, maxY);
		uint _561 = clamp(_529,     minY, maxY);
		uint _583 = clamp(_529 + 1, minY, maxY);


		float3 b0 = ColorIn.Load(int3( _89,  _91, 0)).rgb;
		float3 d0 = ColorIn.Load(int3(_100, _108, 0)).rgb;
		float3 e0 = ColorIn.Load(int3( _89, _108, 0)).rgb;
		float3 f0 = ColorIn.Load(int3(_120, _108, 0)).rgb;
		float3 h0 = ColorIn.Load(int3( _89, _133, 0)).rgb;

		b0 = PrepareForProcessing(b0);
		d0 = PrepareForProcessing(d0);
		e0 = PrepareForProcessing(e0);
		f0 = PrepareForProcessing(f0);
		h0 = PrepareForProcessing(h0);

		float3 maxRGB0 = max(max(f0, h0), max(max(b0, d0), e0));
		float3 minRGB0 = min(min(f0, h0), min(min(b0, d0), e0));

		float3 weight0 = sharp * sqrt(saturate(min(minRGB0, 1.f - maxRGB0) * (1.f / maxRGB0)));

		float3 rcpWeight0 = 1.f / ((weight0 * 4.f) + 1.f);

		float3 colorOut0 = (((d0 + b0 + f0 + h0) * weight0) + e0) * rcpWeight0;

		colorOut0 = PrepareForOutput(colorOut0);

		ColorOut[uint2(_58, _59)] = float4(colorOut0, 1.f);


		static const bool testX1 = _495 <= _55.z;
		static const bool testY1 = _529 <= _55.w;

		if (testX1)
		{
			float3 b1 = ColorIn.Load(int3(_145,  _91, 0)).rgb;
			float3 d1 = ColorIn.Load(int3(_157, _108, 0)).rgb;
			float3 e1 = ColorIn.Load(int3(_145, _108, 0)).rgb;
			float3 f1 = ColorIn.Load(int3(_180, _108, 0)).rgb;
			float3 h1 = ColorIn.Load(int3(_145, _133, 0)).rgb;

			b1 = PrepareForProcessing(b1);
			d1 = PrepareForProcessing(d1);
			e1 = PrepareForProcessing(e1);
			f1 = PrepareForProcessing(f1);
			h1 = PrepareForProcessing(h1);

			float3 maxRGB1 = max(max(f1, h1), max(max(b1, d1), e1));
			float3 minRGB1 = min(min(f1, h1), min(min(b1, d1), e1));

			float3 weight1 = sharp * sqrt(saturate(min(minRGB1, 1.f - maxRGB1) * (1.f / maxRGB1)));

			float3 rcpWeight1 = 1.f / ((weight1 * 4.f) + 1.f);

			float3 colorOut1 = (((d1 + b1 + f1 + h1) * weight1) + e1) * rcpWeight1;

			colorOut1 = PrepareForOutput(colorOut1);

			ColorOut[uint2(_495, _59)] = float4(colorOut1, 1.f);

			if (testY1)
			{
				float3 b3 = ColorIn.Load(int3(_145, _547, 0)).rgb;
				float3 d3 = ColorIn.Load(int3(_157, _561, 0)).rgb;
				float3 e3 = ColorIn.Load(int3(_145, _561, 0)).rgb;
				float3 f3 = ColorIn.Load(int3(_180, _561, 0)).rgb;
				float3 h3 = ColorIn.Load(int3(_145, _583, 0)).rgb;

				d3 = PrepareForProcessing(d3);
				b3 = PrepareForProcessing(b3);
				e3 = PrepareForProcessing(e3);
				f3 = PrepareForProcessing(f3);
				h3 = PrepareForProcessing(h3);

				float3 maxRGB3 = max(max(f3, h3), max(max(b3, d3), e3));
				float3 minRGB3 = min(min(f3, h3), min(min(b3, d3), e3));

				float3 weight3 = sharp * sqrt(saturate(min(minRGB3, 1.f - maxRGB3) * (1.f / maxRGB3)));

				float3 rcpWeight3 = 1.f / ((weight3 * 4.f) + 1.f);

				float3 colorOut3 = (((d3 + b3 + f3 + h3) * weight3) + e3) * rcpWeight3;

				colorOut3 = PrepareForOutput(colorOut3);

				ColorOut[uint2(_495, _529)] = float4(colorOut3, 1.f);
			}
		}

		if (testY1)
		{
			float3 b2 = ColorIn.Load(int3( _89, _547, 0)).rgb;
			float3 d2 = ColorIn.Load(int3(_100, _561, 0)).rgb;
			float3 e2 = ColorIn.Load(int3( _89, _561, 0)).rgb;
			float3 f2 = ColorIn.Load(int3(_120, _561, 0)).rgb;
			float3 h2 = ColorIn.Load(int3( _89, _583, 0)).rgb;

			b2 = PrepareForProcessing(b2);
			d2 = PrepareForProcessing(d2);
			e2 = PrepareForProcessing(e2);
			f2 = PrepareForProcessing(f2);
			h2 = PrepareForProcessing(h2);

			float3 maxRGB2 = max(max(f2, h2), max(max(b2, d2), e2));
			float3 minRGB2 = min(min(f2, h2), min(min(b2, d2), e2));

			float3 weight2 = sharp * sqrt(saturate(min(minRGB2, 1.f - maxRGB2) * (1.f / maxRGB2)));

			float3 rcpWeight2 = 1.f / ((weight2 * 4.f) + 1.f);

			float3 colorOut2 = (((d2 + b2 + f2 + h2) * weight2) + e2) * rcpWeight2;

			colorOut2 = PrepareForOutput(colorOut2);

			ColorOut[uint2(_58, _529)] = float4(colorOut2, 1.f);
		}
	}

#endif
#else

// FP32 CAS sharpening

	uint4 _55 = CASData.rectLimits0;

	uint _58 = ((csInput.SV_GroupThreadID.x >> 1) & 7)
	         | (csInput.SV_GroupID.x << 4);
	_58 += _55.x;

	uint _59 = ((csInput.SV_GroupThreadID.x >> 3) & 6)
	         | (csInput.SV_GroupThreadID.x & 1)
	         | (csInput.SV_GroupID.y << 4);
	_59 += _55.y;

	static const bool testX0 = _58 <= _55.z;
	static const bool testY0 = _59 <= _55.w;

	if (testX0 && testY0)
	{
		uint _285 = _58 + 8;
		uint _492 = _59 + 8;

		static const float sharp = CASData.upscalingConst1.sharp;

		uint4 _68 = CASData.rectLimits1;

		uint minX = _68.x;
		uint minY = _68.y;
		uint maxX = _68.z;
		uint maxY = _68.w;

		uint _83 = CLAMPX(_58 - 1);
		uint _76 = CLAMPX(_58);
		uint _94 = CLAMPX(_58 + 1);

		uint  _64 = CLAMPY(_59 - 1);
		uint  _87 = CLAMPY(_59);
		uint _100 = CLAMPY(_59 + 1);

		uint _301 = CLAMPX(_285 - 1);
		uint _295 = CLAMPX(_285);
		uint _312 = CLAMPX(_285 + 1);

		uint _513 = CLAMPY(_492 - 1);
		uint _512 = CLAMPY(_492);
		uint _514 = CLAMPY(_492 + 1);

		float3 b0 = ColorIn.Load(int3(_76,  _64, 0)).rgb;
		float3 d0 = ColorIn.Load(int3(_83,  _87, 0)).rgb;
		float3 e0 = ColorIn.Load(int3(_76,  _87, 0)).rgb;
		float3 f0 = ColorIn.Load(int3(_94,  _87, 0)).rgb;
		float3 h0 = ColorIn.Load(int3(_76, _100, 0)).rgb;

		b0 = PrepareForProcessing(b0);
		d0 = PrepareForProcessing(d0);
		e0 = PrepareForProcessing(e0);
		f0 = PrepareForProcessing(f0);
		h0 = PrepareForProcessing(h0);

		float3 maxRGB0 = max(max(d0, max(e0, f0)), max(b0, h0));
		float3 minRGB0 = min(min(d0, min(e0, f0)), min(b0, h0));

		float3 weight0 = sharp * sqrt(saturate(min(minRGB0, 1.f - maxRGB0) * (1.f / maxRGB0)));

		float3 rcpWeight0 = 1.f / ((weight0 * 4.f) + 1.f);

		float3 colorOut0 = (((d0 + b0 + f0 + h0) * weight0) + e0) * rcpWeight0;

		colorOut0 = PrepareForOutput(colorOut0);

		ColorOut[uint2(_58, _59)] = float4(colorOut0, 1.f);


		static const bool testX1 = _285 <= _55.z;
		static const bool testY1 = _492 <= _55.w;

		if (testX1)
		{
			float3 b1 = ColorIn.Load(int3(_295,  _64, 0)).rgb;
			float3 d1 = ColorIn.Load(int3(_301,  _87, 0)).rgb;
			float3 e1 = ColorIn.Load(int3(_295,  _87, 0)).rgb;
			float3 f1 = ColorIn.Load(int3(_312,  _87, 0)).rgb;
			float3 h1 = ColorIn.Load(int3(_295, _100, 0)).rgb;

			b1 = PrepareForProcessing(b1);
			d1 = PrepareForProcessing(d1);
			e1 = PrepareForProcessing(e1);
			f1 = PrepareForProcessing(f1);
			h1 = PrepareForProcessing(h1);

			float3 maxRGB1 = max(max(d1, max(e1, f1)), max(b1, h1));
			float3 minRGB1 = min(min(d1, min(e1, f1)), min(b1, h1));

			float3 weight1 = sharp * sqrt(saturate(min(minRGB1, 1.f - maxRGB1) * (1.f / maxRGB1)));

			float3 rcpWeight1 = 1.f / ((weight1 * 4.f) + 1.f);

			float3 colorOut1 = (((d1 + b1 + f1 + h1) * weight1) + e1) * rcpWeight1;

			colorOut1 = PrepareForOutput(colorOut1);

			ColorOut[uint2(_285, _59)] = float4(colorOut1, 1.f);

			if (testY1)
			{
				float3 b2 = ColorIn.Load(int3(_295, _513, 0)).rgb;
				float3 d2 = ColorIn.Load(int3(_301, _512, 0)).rgb;
				float3 e2 = ColorIn.Load(int3(_295, _512, 0)).rgb;
				float3 f2 = ColorIn.Load(int3(_312, _512, 0)).rgb;
				float3 h2 = ColorIn.Load(int3(_295, _514, 0)).rgb;

				b2 = PrepareForProcessing(b2);
				d2 = PrepareForProcessing(d2);
				e2 = PrepareForProcessing(e2);
				f2 = PrepareForProcessing(f2);
				h2 = PrepareForProcessing(h2);

				float3 maxRGB2 = max(max(d2, max(e2, f2)), max(b2, h2));
				float3 minRGB2 = min(min(d2, min(e2, f2)), min(b2, h2));

				float3 weight2 = sharp * sqrt(saturate(min(minRGB2, 1.f - maxRGB2) * (1.f / maxRGB2)));

				float3 rcpWeight2 = 1.f / ((weight2 * 4.f) + 1.f);

				float3 colorOut2 = (((d2 + b2 + f2 + h2) * weight2) + e2) * rcpWeight2;

				colorOut2 = PrepareForOutput(colorOut2);

				ColorOut[uint2(_285, _492)] = float4(colorOut2, 1.f);
			}
		}

		if (testY1)
		{
			float3 b3 = ColorIn.Load(int3(_76, _513, 0)).rgb;
			float3 d3 = ColorIn.Load(int3(_83, _512, 0)).rgb;
			float3 e3 = ColorIn.Load(int3(_76, _512, 0)).rgb;
			float3 f3 = ColorIn.Load(int3(_94, _512, 0)).rgb;
			float3 h3 = ColorIn.Load(int3(_76, _514, 0)).rgb;

			b3 = PrepareForProcessing(b3);
			d3 = PrepareForProcessing(d3);
			e3 = PrepareForProcessing(e3);
			f3 = PrepareForProcessing(f3);
			h3 = PrepareForProcessing(h3);

			float3 maxRGB3 = max(max(d3, max(e3, f3)), max(b3, h3));
			float3 minRGB3 = min(min(d3, min(e3, f3)), min(b3, h3));

			float3 weight3 = sharp * sqrt(saturate(min(minRGB3, 1.f - maxRGB3) * (1.f / maxRGB3)));

			float3 rcpWeight3 = 1.f / ((weight3 * 4.f) + 1.f);

			float3 colorOut3 = (((d3 + b3 + f3 + h3) * weight3) + e3) * rcpWeight3;

			colorOut3 = PrepareForOutput(colorOut3);

			ColorOut[uint2(_58, _492)] = float4(colorOut3, 1.f);
		}
	}

#endif
}
