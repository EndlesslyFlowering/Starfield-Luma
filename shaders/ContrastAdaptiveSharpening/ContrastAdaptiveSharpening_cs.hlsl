#include "../shared.hlsl"
#include "../color.hlsl"
#include "RootSignature.hlsl"

//#define USE_PACKED_MATH
//#define USE_UPSCALING

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
// Always normalize around the whole HDR10 range (anything beyond might get clipped here),
// as even if we tonemapped to e.g. 800 nits, we want 500 nits to be treated the same independently of the peak nits.
static const float normalizationFactor = (PQMaxNits / WhiteNits_BT709) / blueFactor;


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

	uint4 _55 = CASData.rectLimits0;

	uint _58 = ((csInput.SV_GroupThreadID.x >> 1) & 7)
	         | (csInput.SV_GroupID.x << 4);
	_58 += _55.x;

	uint _59 = ((csInput.SV_GroupThreadID.x >> 3) & 6)
	         | (csInput.SV_GroupThreadID.x & 1)
	         | (csInput.SV_GroupID.y << 4);
	_59 += _55.y;

	CASConst0 _62 = CASData.upscalingConst0;
	CASConst1 _69 = CASData.upscalingConst1;

	float _85 = (float(_58) * _62.rcpScalingFactorX) + _62.otherScalingFactorX;
	float _86 = (float(_59) * _62.rcpScalingFactorY) + _62.otherScalingFactorY;

	half _91 = frac(_85);
	half _93 = frac(_86);

	uint _95 = uint(_85);
	uint _96 = uint(_86);

	uint4 _101 = CASData.rectLimits1;

	uint _102 = _101.x;
	uint _103 = _101.y;
	uint _104 = _101.z;
	uint _105 = _101.w;

	uint _131 = max(min(_95 - 1, _104), _102);
	uint _114 = max(min(_95,     _104), _102);
	uint _148 = max(min(_95 + 1, _104), _102);
	uint _163 = max(min(_95 + 2, _104), _102);

	uint _116 = max(min(_96 - 1, _105), _103);
	uint _133 = max(min(_96,     _105), _103);
	uint _173 = max(min(_96 + 1, _105), _103);
	uint _187 = max(min(_96 + 2, _105), _103);

	half3 _118 = ColorIn.Load(int3(_114, _116, 0)).rgb;
	half3 _134 = ColorIn.Load(int3(_131, _133, 0)).rgb;
	half3 _138 = ColorIn.Load(int3(_114, _133, 0)).rgb;
	half3 _149 = ColorIn.Load(int3(_148, _116, 0)).rgb;
	half3 _153 = ColorIn.Load(int3(_148, _133, 0)).rgb;
	half3 _164 = ColorIn.Load(int3(_163, _133, 0)).rgb;
	half3 _174 = ColorIn.Load(int3(_131, _173, 0)).rgb;
	half3 _178 = ColorIn.Load(int3(_114, _173, 0)).rgb;
	half3 _188 = ColorIn.Load(int3(_114, _187, 0)).rgb;
	half3 _192 = ColorIn.Load(int3(_148, _173, 0)).rgb;
	half3 _196 = ColorIn.Load(int3(_163, _173, 0)).rgb;
	half3 _200 = ColorIn.Load(int3(_148, _187, 0)).rgb;

	float _205 = _85 + _69.rcpScalingFactorXTimes8;

	half _208 = frac(_205);

	uint _209 = uint(_205);

	uint _228 = max(min(_209 - 1, _104), _102);
	uint _214 = max(min(_209,     _104), _102);
	uint _250 = max(min(_209 + 1, _104), _102);
	uint _272 = max(min(_209 + 2, _104), _102);

	half3 _215 = ColorIn.Load(int3(_214, _116, 0)).rgb;
	half3 _229 = ColorIn.Load(int3(_228, _133, 0)).rgb;
	half3 _237 = ColorIn.Load(int3(_214, _133, 0)).rgb;
	half3 _251 = ColorIn.Load(int3(_250, _116, 0)).rgb;
	half3 _259 = ColorIn.Load(int3(_250, _133, 0)).rgb;
	half3 _273 = ColorIn.Load(int3(_272, _133, 0)).rgb;
	half3 _281 = ColorIn.Load(int3(_228, _173, 0)).rgb;
	half3 _289 = ColorIn.Load(int3(_214, _173, 0)).rgb;
	half3 _297 = ColorIn.Load(int3(_214, _187, 0)).rgb;
	half3 _305 = ColorIn.Load(int3(_250, _173, 0)).rgb;
	half3 _313 = ColorIn.Load(int3(_272, _173, 0)).rgb;
	half3 _321 = ColorIn.Load(int3(_250, _187, 0)).rgb;

	_118 = PrepareForProcessing(_118);
	_134 = PrepareForProcessing(_134);
	_138 = PrepareForProcessing(_138);
	_149 = PrepareForProcessing(_149);
	_153 = PrepareForProcessing(_153);
	_164 = PrepareForProcessing(_164);
	_174 = PrepareForProcessing(_174);
	_178 = PrepareForProcessing(_178);
	_188 = PrepareForProcessing(_188);
	_192 = PrepareForProcessing(_192);
	_196 = PrepareForProcessing(_196);
	_200 = PrepareForProcessing(_200);
	_215 = PrepareForProcessing(_215);
	_229 = PrepareForProcessing(_229);
	_237 = PrepareForProcessing(_237);
	_251 = PrepareForProcessing(_251);
	_259 = PrepareForProcessing(_259);
	_273 = PrepareForProcessing(_273);
	_281 = PrepareForProcessing(_281);
	_289 = PrepareForProcessing(_289);
	_297 = PrepareForProcessing(_297);
	_305 = PrepareForProcessing(_305);
	_313 = PrepareForProcessing(_313);
	_321 = PrepareForProcessing(_321);

	half _344 = _118.y;
	half _345 = _215.y;
	half _364 = _149.y;
	half _365 = _251.y;
	half _384 = _134.y;
	half _385 = _229.y;
	half _404 = _138.y;
	half _405 = _237.y;
	half _424 = _153.y;
	half _425 = _259.y;
	half _444 = _164.y;
	half _445 = _273.y;
	half _464 = _174.y;
	half _465 = _281.y;
	half _484 = _178.y;
	half _485 = _289.y;
	half _504 = _192.y;
	half _505 = _305.y;
	half _524 = _196.y;
	half _525 = _313.y;
	half _544 = _188.y;
	half _545 = _297.y;
	half _564 = _200.y;
	half _565 = _321.y;

	half _571 = min(_384, _404);
	half _572 = min(_385, _405);
	half _573 = min(_344, _571);
	half _574 = min(_345, _572);
	half _575 = min(_424, _484);
	half _576 = min(_425, _485);
	half _577 = min(_573, _575);
	half _578 = min(_574, _576);
	half _579 = max(_384, _404);
	half _580 = max(_385, _405);
	half _581 = max(_344, _579);
	half _582 = max(_345, _580);
	half _583 = max(_424, _484);
	half _584 = max(_425, _485);
	half _585 = max(_581, _583);
	half _586 = max(_582, _584);
	half _587 = min(_404, _424);
	half _588 = min(_405, _425);
	half _589 = min(_364, _587);
	half _590 = min(_365, _588);
	half _591 = min(_444, _504);
	half _592 = min(_445, _505);
	half _593 = min(_589, _591);
	half _594 = min(_590, _592);
	half _595 = max(_404, _424);
	half _596 = max(_405, _425);
	half _597 = max(_364, _595);
	half _598 = max(_365, _596);
	half _599 = max(_444, _504);
	half _600 = max(_445, _505);
	half _601 = max(_597, _599);
	half _602 = max(_598, _600);
	half _603 = min(_464, _484);
	half _604 = min(_465, _485);
	half _605 = min(_404, _603);
	half _606 = min(_405, _604);
	half _607 = min(_504, _544);
	half _608 = min(_505, _545);
	half _609 = min(_605, _607);
	half _610 = min(_606, _608);
	half _611 = max(_464, _484);
	half _612 = max(_465, _485);
	half _613 = max(_404, _611);
	half _614 = max(_405, _612);
	half _615 = max(_504, _544);
	half _616 = max(_505, _545);
	half _617 = max(_613, _615);
	half _618 = max(_614, _616);
	half _619 = min(_484, _504);
	half _620 = min(_485, _505);
	half _621 = min(_424, _619);
	half _622 = min(_425, _620);
	half _623 = min(_524, _564);
	half _624 = min(_525, _565);
	half _625 = min(_621, _623);
	half _626 = min(_622, _624);
	half _627 = max(_484, _504);
	half _628 = max(_485, _505);
	half _629 = max(_424, _627);
	half _630 = max(_425, _628);
	half _631 = max(_524, _564);
	half _632 = max(_525, _565);
	half _633 = max(_629, _631);
	half _634 = max(_630, _632);

	half _644 = 1.h - _585;
	half _645 = 1.h - _586;
	half _653 = 1.h - _601;
	half _654 = 1.h - _602;
	half _661 = 1.h - _617;
	half _662 = 1.h - _618;
	half _669 = 1.h - _633;
	half _670 = 1.h - _634;

	half _648 = min(_577, _644) * (1.h / _585);
	half _649 = min(_578, _645) * (1.h / _586);
	half _657 = min(_593, _653) * (1.h / _601);
	half _658 = min(_594, _654) * (1.h / _602);
	half _665 = min(_609, _661) * (1.h / _617);
	half _666 = min(_610, _662) * (1.h / _618);
	half _673 = min(_625, _669) * (1.h / _633);
	half _674 = min(_626, _670) * (1.h / _634);

	half _2515 = max(_648, 0.h);
	half _2526 = max(_649, 0.h);
	half _2547 = max(_657, 0.h);
	half _2558 = max(_658, 0.h);
	half _2579 = max(_665, 0.h);
	half _2590 = max(_666, 0.h);
	half _2611 = max(_673, 0.h);
	half _2622 = max(_674, 0.h);

	half hSharp = f16tof32(_69.sharpAsHalf & 0xFFFF);

	half _699 = 1.h - _91;
	half _700 = 1.h - _208;
	half _701 = 1.h - _93;

	half _717 = (_699 * _701) * (1.h / ((0.03125h - _577) + _585));
	half _718 = (_700 * _701) * (1.h / ((0.03125h - _578) + _586));
	half _725 = ( _91 * _701) * (1.h / ((0.03125h - _593) + _601));
	half _726 = (_208 * _701) * (1.h / ((0.03125h - _594) + _602));
	half _733 = (_699 *  _93) * (1.h / ((0.03125h - _609) + _617));
	half _734 = (_700 *  _93) * (1.h / ((0.03125h - _610) + _618));
	half _741 = ( _91 *  _93) * (1.h / ((0.03125h - _625) + _633));
	half _742 = (_208 *  _93) * (1.h / ((0.03125h - _626) + _634));

	half _743 = _717 * (hSharp * sqrt(min(_2515, 1.h)));
	half _744 = _718 * (hSharp * sqrt(min(_2526, 1.h)));
	half _745 = _725 * (hSharp * sqrt(min(_2547, 1.h)));
	half _746 = _726 * (hSharp * sqrt(min(_2558, 1.h)));
	half _747 = _733 * (hSharp * sqrt(min(_2579, 1.h)));
	half _748 = _734 * (hSharp * sqrt(min(_2590, 1.h)));
	half _753 = _741 * (hSharp * sqrt(min(_2611, 1.h)));
	half _754 = _742 * (hSharp * sqrt(min(_2622, 1.h)));

	half _750 = (_745 + _717) + _747;
	half _752 = (_746 + _718) + _748;
	half _756 = (_725 + _743) + _753;
	half _758 = (_726 + _744) + _754;
	half _760 = (_733 + _743) + _753;
	half _762 = (_734 + _744) + _754;
	half _765 = (_747 + _745) + _741;
	half _766 = (_748 + _746) + _742;

	half _784 = 1.h / ((((_765 + _750) + ((((_745 + _743) + _747) + _753) * 2.h)) + _756) + _760);
	half _785 = 1.h / ((((_766 + _752) + ((((_746 + _744) + _748) + _754) * 2.h)) + _758) + _762);

	half3 _803 = ((((((((_752 * _237) + (_744 * (_229 + _215))) + (_766 * _305)) + (_758 * _259)) + (_762 * _289)) + (_754 * (_321 + _313))) + (_748 * (_297 + _281))) + (_746 * (_273 + _251))) * _785;
	half3 colorOut2 = saturate(_803);

	colorOut2 = PrepareForOutput(colorOut2);

	if ((_58 <= _55.z) && (_59 <= _55.w))
	{
		half3 _961 = ((((((((_138 * _750) + ((_134 + _118) * _743)) + (_153 * _756)) + (_178 * _760)) + (_192 * _765)) + ((_200 + _196) * _753)) + ((_188 + _174) * _747)) + ((_164 + _149) * _745)) * _784;
		half3 colorOut1 = saturate(_961);

		colorOut1 = PrepareForOutput(colorOut1);

		ColorOut[uint2(_58, _59)] = float4(float3(colorOut1), 1.f);
	}

	uint _1119 = _58 + 8;

	if ((_1119 <= _55.z) && (_59 <= _55.w))
	{
		ColorOut[uint2(_1119, _59)] = float4(float3(colorOut2), 1.f);
	}

	uint _1153 = _59 + 8;

	float _1156 = (float(_1153) * _62.rcpScalingFactorY) + _62.otherScalingFactorY;

	half _1159 = frac(_1156);

	uint _1160 = uint(_1156);

	uint _1177 = max(min(_1160 - 1, _105), _103);
	uint _1191 = max(min(_1160,     _105), _103);
	uint _1225 = max(min(_1160 + 1, _105), _103);
	uint _1239 = max(min(_1160 + 2, _105), _103);

	half3 _1179 = ColorIn.Load(int3(_114, _1177, 0)).rgb;
	half3 _1192 = ColorIn.Load(int3(_131, _1191, 0)).rgb;
	half3 _1196 = ColorIn.Load(int3(_114, _1191, 0)).rgb;
	half3 _1204 = ColorIn.Load(int3(_148, _1177, 0)).rgb;
	half3 _1208 = ColorIn.Load(int3(_148, _1191, 0)).rgb;
	half3 _1216 = ColorIn.Load(int3(_163, _1191, 0)).rgb;
	half3 _1226 = ColorIn.Load(int3(_131, _1225, 0)).rgb;
	half3 _1230 = ColorIn.Load(int3(_114, _1225, 0)).rgb;
	half3 _1240 = ColorIn.Load(int3(_114, _1239, 0)).rgb;
	half3 _1244 = ColorIn.Load(int3(_148, _1225, 0)).rgb;
	half3 _1248 = ColorIn.Load(int3(_163, _1225, 0)).rgb;
	half3 _1252 = ColorIn.Load(int3(_148, _1239, 0)).rgb;
	half3 _1260 = ColorIn.Load(int3(_214, _1177, 0)).rgb;
	half3 _1272 = ColorIn.Load(int3(_228, _1191, 0)).rgb;
	half3 _1280 = ColorIn.Load(int3(_214, _1191, 0)).rgb;
	half3 _1292 = ColorIn.Load(int3(_250, _1177, 0)).rgb;
	half3 _1300 = ColorIn.Load(int3(_250, _1191, 0)).rgb;
	half3 _1312 = ColorIn.Load(int3(_272, _1191, 0)).rgb;
	half3 _1320 = ColorIn.Load(int3(_228, _1225, 0)).rgb;
	half3 _1328 = ColorIn.Load(int3(_214, _1225, 0)).rgb;
	half3 _1336 = ColorIn.Load(int3(_214, _1239, 0)).rgb;
	half3 _1344 = ColorIn.Load(int3(_250, _1225, 0)).rgb;
	half3 _1352 = ColorIn.Load(int3(_272, _1225, 0)).rgb;
	half3 _1360 = ColorIn.Load(int3(_250, _1239, 0)).rgb;

	_1179 = PrepareForProcessing(_1179);
	_1192 = PrepareForProcessing(_1192);
	_1196 = PrepareForProcessing(_1196);
	_1204 = PrepareForProcessing(_1204);
	_1208 = PrepareForProcessing(_1208);
	_1216 = PrepareForProcessing(_1216);
	_1226 = PrepareForProcessing(_1226);
	_1230 = PrepareForProcessing(_1230);
	_1240 = PrepareForProcessing(_1240);
	_1244 = PrepareForProcessing(_1244);
	_1248 = PrepareForProcessing(_1248);
	_1252 = PrepareForProcessing(_1252);
	_1260 = PrepareForProcessing(_1260);
	_1272 = PrepareForProcessing(_1272);
	_1280 = PrepareForProcessing(_1280);
	_1292 = PrepareForProcessing(_1292);
	_1300 = PrepareForProcessing(_1300);
	_1312 = PrepareForProcessing(_1312);
	_1320 = PrepareForProcessing(_1320);
	_1328 = PrepareForProcessing(_1328);
	_1336 = PrepareForProcessing(_1336);
	_1344 = PrepareForProcessing(_1344);
	_1352 = PrepareForProcessing(_1352);
	_1360 = PrepareForProcessing(_1360);

	half _1385 = _1179.y;
	half _1386 = _1260.y;
	half _1405 = _1204.y;
	half _1406 = _1292.y;
	half _1425 = _1192.y;
	half _1426 = _1272.y;
	half _1445 = _1196.y;
	half _1446 = _1280.y;
	half _1465 = _1208.y;
	half _1466 = _1300.y;
	half _1485 = _1216.y;
	half _1486 = _1312.y;
	half _1505 = _1226.y;
	half _1506 = _1320.y;
	half _1525 = _1230.y;
	half _1526 = _1328.y;
	half _1545 = _1244.y;
	half _1546 = _1344.y;
	half _1565 = _1248.y;
	half _1566 = _1352.y;
	half _1585 = _1240.y;
	half _1586 = _1336.y;
	half _1605 = _1252.y;
	half _1606 = _1360.y;

	half _1612 = min(_1425, _1445);
	half _1613 = min(_1426, _1446);
	half _1614 = min(_1385, _1612);
	half _1615 = min(_1386, _1613);
	half _1616 = min(_1465, _1525);
	half _1617 = min(_1466, _1526);
	half _1618 = min(_1614, _1616);
	half _1619 = min(_1615, _1617);
	half _1620 = max(_1425, _1445);
	half _1621 = max(_1426, _1446);
	half _1622 = max(_1385, _1620);
	half _1623 = max(_1386, _1621);
	half _1624 = max(_1465, _1525);
	half _1625 = max(_1466, _1526);
	half _1626 = max(_1622, _1624);
	half _1627 = max(_1623, _1625);
	half _1628 = min(_1445, _1465);
	half _1629 = min(_1446, _1466);
	half _1630 = min(_1405, _1628);
	half _1631 = min(_1406, _1629);
	half _1632 = min(_1485, _1545);
	half _1633 = min(_1486, _1546);
	half _1634 = min(_1630, _1632);
	half _1635 = min(_1631, _1633);
	half _1636 = max(_1445, _1465);
	half _1637 = max(_1446, _1466);
	half _1638 = max(_1405, _1636);
	half _1639 = max(_1406, _1637);
	half _1640 = max(_1485, _1545);
	half _1641 = max(_1486, _1546);
	half _1642 = max(_1638, _1640);
	half _1643 = max(_1639, _1641);
	half _1644 = min(_1505, _1525);
	half _1645 = min(_1506, _1526);
	half _1646 = min(_1445, _1644);
	half _1647 = min(_1446, _1645);
	half _1648 = min(_1545, _1585);
	half _1649 = min(_1546, _1586);
	half _1650 = min(_1646, _1648);
	half _1651 = min(_1647, _1649);
	half _1652 = max(_1505, _1525);
	half _1653 = max(_1506, _1526);
	half _1654 = max(_1445, _1652);
	half _1655 = max(_1446, _1653);
	half _1656 = max(_1545, _1585);
	half _1657 = max(_1546, _1586);
	half _1658 = max(_1654, _1656);
	half _1659 = max(_1655, _1657);
	half _1660 = min(_1525, _1545);
	half _1661 = min(_1526, _1546);
	half _1662 = min(_1465, _1660);
	half _1663 = min(_1466, _1661);
	half _1664 = min(_1565, _1605);
	half _1665 = min(_1566, _1606);
	half _1666 = min(_1662, _1664);
	half _1667 = min(_1663, _1665);
	half _1668 = max(_1525, _1545);
	half _1669 = max(_1526, _1546);
	half _1670 = max(_1465, _1668);
	half _1671 = max(_1466, _1669);
	half _1672 = max(_1565, _1605);
	half _1673 = max(_1566, _1606);
	half _1674 = max(_1670, _1672);
	half _1675 = max(_1671, _1673);

	half _1684 = 1.h - _1626;
	half _1685 = 1.h - _1627;
	half _1692 = 1.h - _1642;
	half _1693 = 1.h - _1643;
	half _1700 = 1.h - _1658;
	half _1701 = 1.h - _1659;
	half _1708 = 1.h - _1674;
	half _1709 = 1.h - _1675;

	half _1688 = min(_1618, _1684) * (1.h / _1626);
	half _1689 = min(_1619, _1685) * (1.h / _1627);
	half _1696 = min(_1634, _1692) * (1.h / _1642);
	half _1697 = min(_1635, _1693) * (1.h / _1643);
	half _1704 = min(_1650, _1700) * (1.h / _1658);
	half _1705 = min(_1651, _1701) * (1.h / _1659);
	half _1712 = min(_1666, _1708) * (1.h / _1674);
	half _1713 = min(_1667, _1709) * (1.h / _1675);

	half _3064 = max(_1688, 0.h);
	half _3075 = max(_1689, 0.h);
	half _3096 = max(_1696, 0.h);
	half _3107 = max(_1697, 0.h);
	half _3128 = max(_1704, 0.h);
	half _3139 = max(_1705, 0.h);
	half _3160 = max(_1712, 0.h);
	half _3171 = max(_1713, 0.h);

	half _1732 = 1.h - _1159;

	half _1747 = ( _699 * _1732) * (1.h / ((0.03125h - _1618) + _1626));
	half _1748 = ( _700 * _1732) * (1.h / ((0.03125h - _1619) + _1627));
	half _1755 = (  _91 * _1732) * (1.h / ((0.03125h - _1634) + _1642));
	half _1756 = ( _208 * _1732) * (1.h / ((0.03125h - _1635) + _1643));
	half _1763 = ( _699 * _1159) * (1.h / ((0.03125h - _1650) + _1658));
	half _1764 = ( _700 * _1159) * (1.h / ((0.03125h - _1651) + _1659));
	half _1771 = (  _91 * _1159) * (1.h / ((0.03125h - _1666) + _1674));
	half _1772 = ( _208 * _1159) * (1.h / ((0.03125h - _1667) + _1675));

	half _1773 = _1747 * (hSharp * sqrt(min(_3064, 1.h)));
	half _1774 = _1748 * (hSharp * sqrt(min(_3075, 1.h)));
	half _1775 = _1755 * (hSharp * sqrt(min(_3096, 1.h)));
	half _1776 = _1756 * (hSharp * sqrt(min(_3107, 1.h)));
	half _1777 = _1763 * (hSharp * sqrt(min(_3128, 1.h)));
	half _1778 = _1764 * (hSharp * sqrt(min(_3139, 1.h)));
	half _1783 = _1771 * (hSharp * sqrt(min(_3160, 1.h)));
	half _1784 = _1772 * (hSharp * sqrt(min(_3171, 1.h)));

	half _1780 = (_1775 + _1747) + _1777;
	half _1782 = (_1776 + _1748) + _1778;
	half _1786 = (_1755 + _1773) + _1783;
	half _1788 = (_1756 + _1774) + _1784;
	half _1790 = (_1763 + _1773) + _1783;
	half _1792 = (_1764 + _1774) + _1784;
	half _1795 = (_1777 + _1775) + _1771;
	half _1796 = (_1778 + _1776) + _1772;

	half _1813 = 1.h / ((((_1795 + _1780) + ((((_1775 + _1773) + _1777) + _1783) * 2.h)) + _1786) + _1790);
	half _1814 = 1.h / ((((_1796 + _1782) + ((((_1776 + _1774) + _1778) + _1784) * 2.h)) + _1788) + _1792);

	half3 _1832 = ((((((((_1782 * _1280) + (_1774 * (_1272 + _1260))) + (_1796 * _1344)) + (_1788 * _1300)) + (_1792 * _1328)) + (_1784 * (_1360 + _1352))) + (_1778 * (_1336 + _1320))) + (_1776 * (_1312 + _1292))) * _1814;
	half3 colorOut4 = saturate(_1832);

	colorOut4 = PrepareForOutput(colorOut4);

	if ((_58 <= _55.z) && (_1153 <= _55.w))
	{
		half3 _1987 = ((((((((_1196 * _1780) + ((_1192 + _1179) * _1773)) + (_1208 * _1786)) + (_1230 * _1790)) + (_1244 * _1795)) + ((_1252 + _1248) * _1783)) + ((_1240 + _1226) * _1777)) + ((_1216 + _1204) * _1775)) * _1813;
		half3 colorOut3 = saturate(_1987);

		colorOut3 = PrepareForOutput(colorOut3);

		ColorOut[uint2(_58, _1153)] = float4(float3(colorOut3), 1.f);
	}

	if ((_1119 <= _55.z) && (_1153 <= _55.w))
	{
		ColorOut[uint2(_1119, _1153)] = float4(float3(colorOut4), 1.f);
	}

#elif defined(USE_PACKED_MATH) \
  && !defined(USE_UPSCALING)
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
