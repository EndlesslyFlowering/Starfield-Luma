#include "../shared.hlsl"
#include "../color.hlsl"
#include "RootSignature.hlsl"

//#define USE_PACKED_MATH
//#define USE_UPSCALING

// shader permutations:
// - CAS sharpening in FP32 [FF94] (USE_PACKED_MATH)
// - CAS sharpening in FP16 with FFX_CAS_USE_PRECISE_MATH [100FF94]
// - CAS upscaling in FP32 [200FF94] (USE_UPSCALING)
// - CAS upscaling in FP16 with FFX_CAS_USE_PRECISE_MATH [300FF94] (USE_PACKED_MATH + USE_UPSCALING)

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

#if SDR_LINEAR_INTERMEDIARY
	#define GAMMA_TO_LINEAR(x) x
	#define LINEAR_TO_GAMMA(x) x
#elif SDR_USE_GAMMA_2_2 // NOTE: these gamma formulas should use their mirrored versions in the CLAMP_INPUT_OUTPUT_TYPE < 3 case
	#define GAMMA_TO_LINEAR(x) pow(x, 2.2h)
	#define LINEAR_TO_GAMMA(x) pow(x, half(1.f / 2.2f))
#else // doing sRGB in half is not accurate enough
	#define GAMMA_TO_LINEAR(x) gamma_sRGB_to_linear(x)
	#define LINEAR_TO_GAMMA(x) gamma_linear_to_sRGB(x)
#endif

half3 conditionalSaturate(half3 Color)
{
#if CLAMP_INPUT_OUTPUT_TYPE >= 3
	Color = saturate(Color);
#endif
	return Color;
}

half3 PrepareForProcessing(half3 Color)
{
	if (HdrDllPluginConstants.DisplayMode > 0)
	{
		Color /= PQMaxWhitePoint;
		Color = BT709_To_WBT2020(Color);
	}
	else
	{
		Color = GAMMA_TO_LINEAR(Color);
	}
	return conditionalSaturate(Color);
}

half3 PrepareForOutput(half3 Color)
{
	if (HdrDllPluginConstants.DisplayMode > 0)
	{
		Color = WBT2020_To_BT709(Color);
		return Color * PQMaxWhitePoint;
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

	uint _131 = _95 - 1;
	uint _114 = _95;
	uint _148 = _95 + 1;
	uint _163 = _95 + 2;

	uint _116 = _96 - 1;
	uint _133 = _96;
	uint _173 = _96 + 1;
	uint _187 = _96 + 2;

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

	uint _228 = _209 - 1;
	uint _214 = _209;
	uint _250 = _209 + 1;
	uint _272 = _209 + 2;

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

	half _648 = 1.h / _585;
	half _649 = 1.h / _586;
	half _657 = 1.h / _601;
	half _658 = 1.h / _602;
	half _665 = 1.h / _617;
	half _666 = 1.h / _618;
	half _673 = 1.h / _633;
	half _674 = 1.h / _634;

	_648 *= min(_577, _644);
	_649 *= min(_578, _645);
	_657 *= min(_593, _653);
	_658 *= min(_594, _654);
	_665 *= min(_609, _661);
	_666 *= min(_610, _662);
	_673 *= min(_625, _669);
	_674 *= min(_626, _670);

	half _2515 = saturate(_648);
	half _2526 = saturate(_649);
	half _2547 = saturate(_657);
	half _2558 = saturate(_658);
	half _2579 = saturate(_665);
	half _2590 = saturate(_666);
	half _2611 = saturate(_673);
	half _2622 = saturate(_674);

	half hSharp = f16tof32(_69.sharpAsHalf & 0xFFFF);

	half _699 = 1.h - _91;
	half _700 = 1.h - _208;
	half _701 = 1.h - _93;

	half _717 = 0.03125h - _577;
	half _718 = 0.03125h - _578;
	half _725 = 0.03125h - _593;
	half _726 = 0.03125h - _594;
	half _733 = 0.03125h - _609;
	half _734 = 0.03125h - _610;
	half _741 = 0.03125h - _625;
	half _742 = 0.03125h - _626;

	_717 += _585;
	_718 += _586;
	_725 += _601;
	_726 += _602;
	_733 += _617;
	_734 += _618;
	_741 += _633;
	_742 += _634;

	_717 = 1.h / _717;
	_718 = 1.h / _718;
	_725 = 1.h / _725;
	_726 = 1.h / _726;
	_733 = 1.h / _733;
	_734 = 1.h / _734;
	_741 = 1.h / _741;
	_742 = 1.h / _742;

	_717 *= _701 * _699;
	_718 *= _701 * _700;
	_725 *= _701 *  _91;
	_726 *= _701 * _208;
	_733 *=  _93 * _699;
	_734 *=  _93 * _700;
	_741 *=  _93 *  _91;
	_742 *=  _93 * _208;

	half _743 = sqrt(_2515);
	half _744 = sqrt(_2526);
	half _745 = sqrt(_2547);
	half _746 = sqrt(_2558);
	half _747 = sqrt(_2579);
	half _748 = sqrt(_2590);
	half _753 = sqrt(_2611);
	half _754 = sqrt(_2622);

	_743 *= hSharp;
	_744 *= hSharp;
	_745 *= hSharp;
	_746 *= hSharp;
	_747 *= hSharp;
	_748 *= hSharp;
	_753 *= hSharp;
	_754 *= hSharp;

	_743 *= _717;
	_744 *= _718;
	_745 *= _725;
	_746 *= _726;
	_747 *= _733;
	_748 *= _734;
	_753 *= _741;
	_754 *= _742;

	half _750 = (_745 + _717) + _747;
	half _752 = (_746 + _718) + _748;
	half _756 = (_725 + _743) + _753;
	half _758 = (_726 + _744) + _754;
	half _760 = (_733 + _743) + _753;
	half _762 = (_734 + _744) + _754;
	half _765 = (_747 + _745) + _741;
	half _766 = (_748 + _746) + _742;

	half2 _783 = half2(_745 + _743 + _747 + _753,
	                   _746 + _744 + _748 + _754);

	_783 *= 2.h;

	_783 += half2(_765 + _750 + _756 + _760,
	              _766 + _752 + _758 + _762);

	_783 = 1.h / _783;

	half3 _803 = ((((((((_752 * _237) + (_744 * (_229 + _215))) + (_766 * _305)) + (_758 * _259)) + (_762 * _289)) + (_754 * (_321 + _313))) + (_748 * (_297 + _281))) + (_746 * (_273 + _251))) * _783.y;
	half3 colorOut2 = conditionalSaturate(_803);

	colorOut2 = PrepareForOutput(colorOut2);

	if ((_58 <= _55.z) && (_59 <= _55.w))
	{
		half3 _961 = ((((((((_138 * _750) + ((_134 + _118) * _743)) + (_153 * _756)) + (_178 * _760)) + (_192 * _765)) + ((_200 + _196) * _753)) + ((_188 + _174) * _747)) + ((_164 + _149) * _745)) * _783.x;
		half3 colorOut1 = conditionalSaturate(_961);

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

	uint _1177 = _1160 - 1;
	uint _1191 = _1160;
	uint _1225 = _1160 + 1;
	uint _1239 = _1160 + 2;

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

	half _1688 = 1.h / _1626;
	half _1689 = 1.h / _1627;
	half _1696 = 1.h / _1642;
	half _1697 = 1.h / _1643;
	half _1704 = 1.h / _1658;
	half _1705 = 1.h / _1659;
	half _1712 = 1.h / _1674;
	half _1713 = 1.h / _1675;

	_1688 *= min(_1618, _1684);
	_1689 *= min(_1619, _1685);
	_1696 *= min(_1634, _1692);
	_1697 *= min(_1635, _1693);
	_1704 *= min(_1650, _1700);
	_1705 *= min(_1651, _1701);
	_1712 *= min(_1666, _1708);
	_1713 *= min(_1667, _1709);

	half _3064 = saturate(_1688);
	half _3075 = saturate(_1689);
	half _3096 = saturate(_1696);
	half _3107 = saturate(_1697);
	half _3128 = saturate(_1704);
	half _3139 = saturate(_1705);
	half _3160 = saturate(_1712);
	half _3171 = saturate(_1713);

	half _1732 = 1.h - _1159;

	half _1747 = 0.03125h - _1618;
	half _1748 = 0.03125h - _1619;
	half _1755 = 0.03125h - _1634;
	half _1756 = 0.03125h - _1635;
	half _1763 = 0.03125h - _1650;
	half _1764 = 0.03125h - _1651;
	half _1771 = 0.03125h - _1666;
	half _1772 = 0.03125h - _1667;

	_1747 += _1626;
	_1748 += _1627;
	_1755 += _1642;
	_1756 += _1643;
	_1763 += _1658;
	_1764 += _1659;
	_1771 += _1674;
	_1772 += _1675;

	_1747 = 1.h / _1747;
	_1748 = 1.h / _1748;
	_1755 = 1.h / _1755;
	_1756 = 1.h / _1756;
	_1763 = 1.h / _1763;
	_1764 = 1.h / _1764;
	_1771 = 1.h / _1771;
	_1772 = 1.h / _1772;

	_1747 *= _1732 * _699;
	_1748 *= _1732 * _700;
	_1755 *= _1732 *  _91;
	_1756 *= _1732 * _208;
	_1763 *= _1159 * _699;
	_1764 *= _1159 * _700;
	_1771 *= _1159 *  _91;
	_1772 *= _1159 * _208;

	half _1773 = sqrt(_3064);
	half _1774 = sqrt(_3075);
	half _1775 = sqrt(_3096);
	half _1776 = sqrt(_3107);
	half _1777 = sqrt(_3128);
	half _1778 = sqrt(_3139);
	half _1783 = sqrt(_3160);
	half _1784 = sqrt(_3171);

	_1773 *= hSharp;
	_1774 *= hSharp;
	_1775 *= hSharp;
	_1776 *= hSharp;
	_1777 *= hSharp;
	_1778 *= hSharp;
	_1783 *= hSharp;
	_1784 *= hSharp;

	_1773 *= _1747;
	_1774 *= _1748;
	_1775 *= _1755;
	_1776 *= _1756;
	_1777 *= _1763;
	_1778 *= _1764;
	_1783 *= _1771;
	_1784 *= _1772;

	half _1780 = (_1775 + _1747) + _1777;
	half _1782 = (_1776 + _1748) + _1778;
	half _1786 = (_1755 + _1773) + _1783;
	half _1788 = (_1756 + _1774) + _1784;
	half _1790 = (_1763 + _1773) + _1783;
	half _1792 = (_1764 + _1774) + _1784;
	half _1795 = (_1777 + _1775) + _1771;
	half _1796 = (_1778 + _1776) + _1772;

	half2 _1812 = half2(_1775 + _1773 + _1777 + _1783,
	                    _1776 + _1774 + _1778 + _1784);

	_1812 *= 2.h;

	_1812 += half2(_1795 + _1780 + _1786 + _1790,
	               _1796 + _1782 + _1788 + _1792);

	_1812 = 1.h / _1812;

	half3 _1832 = ((((((((_1782 * _1280) + (_1774 * (_1272 + _1260))) + (_1796 * _1344)) + (_1788 * _1300)) + (_1792 * _1328)) + (_1784 * (_1360 + _1352))) + (_1778 * (_1336 + _1320))) + (_1776 * (_1312 + _1292))) * _1812.y;
	half3 colorOut4 = conditionalSaturate(_1832);

	colorOut4 = PrepareForOutput(colorOut4);

	if ((_58 <= _55.z) && (_1153 <= _55.w))
	{
		half3 _1987 = ((((((((_1196 * _1780) + ((_1192 + _1179) * _1773)) + (_1208 * _1786)) + (_1230 * _1790)) + (_1244 * _1795)) + ((_1252 + _1248) * _1783)) + ((_1240 + _1226) * _1777)) + ((_1216 + _1204) * _1775)) * _1812.x;
		half3 colorOut3 = conditionalSaturate(_1987);

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

	uint4 _71 = CASData.rectLimits1;

	//unpack sharp stored as half
	static const half hSharp = f16tof32(CASData.upscalingConst1.sharpAsHalf & 0xFFFF);

	uint minX = _71.x;
	uint minY = _71.y;
	uint maxX = _71.z;
	uint maxY = _71.w;

	uint  _89 = clamp(_58,     minX, maxX);
	uint _100 = clamp(_58 - 1, minX, maxX);
	uint _120 = clamp(_58 + 1, minX, maxX);

	uint _108 = clamp(_59,     minY, maxY);
	uint  _91 = clamp(_59 - 1, minY, maxY);
	uint _133 = clamp(_59 + 1, minY, maxY);

	uint _156 = _58 + 7;
	uint _141 = _58 + 8;
	uint _179 = _58 + 9;

	uint _157 = clamp(_156, minX, maxX);
	uint _145 = clamp(_141, minX, maxX);
	uint _180 = clamp(_179, minX, maxX);

	half3  _93 = half3(ColorIn.Load(int3( _89,  _91, 0)).rgb);
	half3 _109 = half3(ColorIn.Load(int3(_100, _108, 0)).rgb);
	half3 _113 = half3(ColorIn.Load(int3( _89, _108, 0)).rgb);
	half3 _124 = half3(ColorIn.Load(int3(_120, _108, 0)).rgb);
	half3 _134 = half3(ColorIn.Load(int3( _89, _133, 0)).rgb);
	half3 _146 = half3(ColorIn.Load(int3(_145,  _91, 0)).rgb);
	half3 _161 = half3(ColorIn.Load(int3(_157, _108, 0)).rgb);
	half3 _169 = half3(ColorIn.Load(int3(_145, _108, 0)).rgb);
	half3 _184 = half3(ColorIn.Load(int3(_180, _108, 0)).rgb);
	half3 _192 = half3(ColorIn.Load(int3(_145, _133, 0)).rgb);

	 _93 = PrepareForProcessing( _93);
	_109 = PrepareForProcessing(_109);
	_113 = PrepareForProcessing(_113);
	_124 = PrepareForProcessing(_124);
	_134 = PrepareForProcessing(_134);
	_146 = PrepareForProcessing(_146);
	_161 = PrepareForProcessing(_161);
	_169 = PrepareForProcessing(_169);
	_184 = PrepareForProcessing(_184);
	_192 = PrepareForProcessing(_192);

	half _215 =  _93.y;
	half _216 = _146.y;
	half _235 = _109.y;
	half _236 = _161.y;
	half _255 = _113.y;
	half _256 = _169.y;
	half _275 = _124.y;
	half _276 = _184.y;
	half _295 = _134.y;
	half _296 = _192.y;

	half _316 = max(max(_275, _295), max(max(_215, _235), _255));
	half _317 = max(max(_276, _296), max(max(_216, _236), _256));

	half _338 = hSharp * sqrt(saturate(min(min(min(_275, _295), min(min(_215, _235), _255)), 1.h - _316) * (1.h / _316)));
	half _339 = hSharp * sqrt(saturate(min(min(min(_276, _296), min(min(_216, _236), _256)), 1.h - _317) * (1.h / _317)));

	half _345 = 1.h / ((_338 * 4.h) + 1.h);
	half _346 = 1.h / ((_339 * 4.h) + 1.h);

	if ((_58 <= _55.z) && (_59 <= _55.w))
	{
		half3 colorOut = (((_109 + _93 + _124 + _134) * _338) + _113) * _345;

		colorOut = conditionalSaturate(colorOut);
		colorOut = PrepareForOutput(colorOut);

		ColorOut[uint2(_58, _59)] = float4(float3(colorOut), 1.f);
	}

	uint _495 = _58 + 8;

	if ((_495 <= _55.z) && (_59 <= _55.w))
	{
		half3 colorOut = (((_161 + _146 + _184 + _192) * _339) + _169) * _346;

		colorOut = conditionalSaturate(colorOut);
		colorOut = PrepareForOutput(colorOut);

		ColorOut[uint2(_495, _59)] = float4(float3(colorOut), 1.f);
	}

	uint _529 = _59 + 8;

	uint _561 = clamp(_529,     minY, maxY);
	uint _547 = clamp(_529 - 1, minY, maxY);
	uint _583 = clamp(_529 + 1, minY, maxY);

	half3 _549 = half3(ColorIn.Load(int3( _89, _547, 0)).rgb);
	half3 _562 = half3(ColorIn.Load(int3(_100, _561, 0)).rgb);
	half3 _566 = half3(ColorIn.Load(int3( _89, _561, 0)).rgb);
	half3 _574 = half3(ColorIn.Load(int3(_120, _561, 0)).rgb);
	half3 _584 = half3(ColorIn.Load(int3( _89, _583, 0)).rgb);
	half3 _592 = half3(ColorIn.Load(int3(_145, _547, 0)).rgb);
	half3 _604 = half3(ColorIn.Load(int3(_157, _561, 0)).rgb);
	half3 _612 = half3(ColorIn.Load(int3(_145, _561, 0)).rgb);
	half3 _624 = half3(ColorIn.Load(int3(_180, _561, 0)).rgb);
	half3 _632 = half3(ColorIn.Load(int3(_145, _583, 0)).rgb);

	_549 = PrepareForProcessing(_549);
	_562 = PrepareForProcessing(_562);
	_566 = PrepareForProcessing(_566);
	_574 = PrepareForProcessing(_574);
	_584 = PrepareForProcessing(_584);
	_592 = PrepareForProcessing(_592);
	_604 = PrepareForProcessing(_604);
	_612 = PrepareForProcessing(_612);
	_624 = PrepareForProcessing(_624);
	_632 = PrepareForProcessing(_632);

	half _657 = _549.y;
	half _658 = _592.y;
	half _677 = _562.y;
	half _678 = _604.y;
	half _697 = _566.y;
	half _698 = _612.y;
	half _717 = _574.y;
	half _718 = _624.y;
	half _737 = _584.y;
	half _738 = _632.y;

	half _758 = max(max(_717, _737), max(max(_657, _677), _697));
	half _759 = max(max(_718, _738), max(max(_658, _678), _698));

	half _772 = hSharp * sqrt(saturate(min(min(min(_717, _737), min(min(_657, _677), _697)), 1.h - _758) * (1.h / _758)));
	half _773 = hSharp * sqrt(saturate(min(min(min(_718, _738), min(min(_658, _678), _698)), 1.h - _759) * (1.h / _759)));

	half _778 = 1.h / ((_772 * 4.h) + 1.h);
	half _779 = 1.h / ((_773 * 4.h) + 1.h);

	if ((_58 <= _55.z) && (_529 <= _55.w))
	{
		half3 colorOut = (((_562 + _549 + _574 + _584) * _772) + _566) * _778;

		colorOut = conditionalSaturate(colorOut);
		colorOut = PrepareForOutput(colorOut);

		ColorOut[uint2(_58, _529)] = float4(float3(colorOut), 1.f);
	}

	if ((_495 <= _55.z) && (_529 <= _55.w))
	{
		half3 colorOut = (((_604 + _592 + _624 + _632) * _773) + _612) * _779;

		colorOut = conditionalSaturate(colorOut);
		colorOut = PrepareForOutput(colorOut);

		ColorOut[uint2(_495, _529)] = float4(float3(colorOut), 1.f);
	}

#endif
#endif // USE_PACKED_MATH
}
