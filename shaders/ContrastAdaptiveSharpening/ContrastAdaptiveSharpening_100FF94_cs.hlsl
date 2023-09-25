#include "../shared.hlsl"
#include "../color.hlsl"

cbuffer _16_18 : register(b0, space6)
{
    float4 _18_m0[8] : packoffset(c0);
};

cbuffer _21_23 : register(b0, space8)
{
    float4 _23_m0[4] : packoffset(c0);
};

Texture2D<float4> _8 : register(t0, space8);
RWTexture2D<float4> _11 : register(u0, space8);

static uint3 gl_WorkGroupID;
static uint3 gl_LocalInvocationID;
struct SPIRV_Cross_Input
{
    uint3 gl_WorkGroupID : SV_GroupID;
    uint3 gl_LocalInvocationID : SV_GroupThreadID;
};

uint spvPackHalf2x16(float2 value)
{
    uint2 Packed = f32tof16(value);
    return Packed.x | (Packed.y << 16);
}

float2 spvUnpackHalf2x16(uint value)
{
    return f16tof32(uint2(value & 0xffff, value >> 16));
}

void comp_main()
{
#if ENABLE_HDR
    // butchered the CS so it just outputs the input
    uint4 _55 = asuint(_23_m0[2u]);
    uint _58 = _55.x + (((gl_LocalInvocationID.x >> 1u) & 7u) | (gl_WorkGroupID.x << 4u));
    uint _59 = ((((gl_LocalInvocationID.x >> 3u) & 6u) | (gl_LocalInvocationID.x & 1u)) | (gl_WorkGroupID.y << 4u)) + _55.y;
    uint _458 = _58 + 8u;
    uint _489 = _59 + 8u;

    _11[uint2(_58, _59)] = _8.Load(int3(uint2(_58, _59), 0u));
    _11[uint2(_458, _59)] = _8.Load(int3(uint2(_458, _59), 0u));
    _11[uint2(_58, _489)] = _8.Load(int3(uint2(_58, _489), 0u));
    _11[uint2(_458, _489)] = _8.Load(int3(uint2(_458, _489), 0u));
#else
    uint4 _55 = asuint(_23_m0[2u]);
    uint _58 = _55.x + (((gl_LocalInvocationID.x >> 1u) & 7u) | (gl_WorkGroupID.x << 4u));
    uint _59 = ((((gl_LocalInvocationID.x >> 3u) & 6u) | (gl_LocalInvocationID.x & 1u)) | (gl_WorkGroupID.y << 4u)) + _55.y;
    uint4 _69 = asuint(_23_m0[3u]);
    uint _70 = _69.x;
    uint _71 = _69.y;
    uint _72 = _69.z;
    uint _73 = _69.w;
    uint _74 = _58 << 16u;
    uint _76 = uint(int(_74) >> int(16u));
    uint _77 = _59 << 16u;
    uint _87 = uint(int(max(min(_76, _72), _70) << 16u) >> int(16u));
    uint _89 = uint(int(max(min(uint(int(_77 + 4294901760u) >> int(16u)), _73), _71) << 16u) >> int(16u));
    float4 _91 = _8.Load(int3(uint2(_87, _89), 0u));
    uint _96 = uint(int(_74 + 4294901760u) >> int(16u));
    uint _105 = uint(int(max(min(uint(int(_77) >> int(16u)), _73), _71) << 16u) >> int(16u));
    float4 _106 = _8.Load(int3(uint2(uint(int(max(min(_96, _72), _70) << 16u) >> int(16u)), _105), 0u));
    float4 _109 = _8.Load(int3(uint2(_87, _105), 0u));
    uint _114 = uint(int(_74 + 65536u) >> int(16u));
    float4 _119 = _8.Load(int3(uint2(uint(int(max(min(_114, _72), _70) << 16u) >> int(16u)), _105), 0u));
    uint _127 = uint(int(max(min(uint(int(_77 + 65536u) >> int(16u)), _73), _71) << 16u) >> int(16u));
    float4 _128 = _8.Load(int3(uint2(_87, _127), 0u));
    uint _134 = uint(int((_58 << 16u) + 524288u) >> int(16u));
    uint _138 = uint(int(max(min(_134, _72), _70) << 16u) >> int(16u));
    float4 _139 = _8.Load(int3(uint2(_138, _89), 0u));
    uint _146 = uint(int(_74 + 458752u) >> int(16u));
    float4 _151 = _8.Load(int3(uint2(uint(int(max(min(_146, _72), _70) << 16u) >> int(16u)), _105), 0u));
    float4 _156 = _8.Load(int3(uint2(_138, _105), 0u));
    uint _163 = uint(int(_74 + 589824u) >> int(16u));
    float4 _168 = _8.Load(int3(uint2(uint(int(max(min(_163, _72), _70) << 16u) >> int(16u)), _105), 0u));
    float4 _173 = _8.Load(int3(uint2(_138, _127), 0u));
    float _193 = exp2(log2((_91.y + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w);
    float _194 = exp2(log2((_139.y + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w);
    float _213 = exp2(log2((_106.y + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w);
    float _214 = exp2(log2((_151.y + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w);
    float _233 = exp2(log2((_109.y + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w);
    float _234 = exp2(log2((_156.y + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w);
    float _253 = exp2(log2((_119.y + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w);
    float _254 = exp2(log2((_168.y + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w);
    float _273 = exp2(log2((_128.y + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w);
    float _274 = exp2(log2((_173.y + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w);
    float _280 = isnan(_213) ? _193 : (isnan(_193) ? _213 : min(_193, _213));
    float _281 = isnan(_214) ? _194 : (isnan(_194) ? _214 : min(_194, _214));
    float _282 = isnan(_233) ? _280 : (isnan(_280) ? _233 : min(_280, _233));
    float _283 = isnan(_234) ? _281 : (isnan(_281) ? _234 : min(_281, _234));
    float _284 = isnan(_273) ? _253 : (isnan(_253) ? _273 : min(_253, _273));
    float _285 = isnan(_274) ? _254 : (isnan(_254) ? _274 : min(_254, _274));
    float _286 = isnan(_282) ? _284 : (isnan(_284) ? _282 : min(_284, _282));
    float _287 = isnan(_283) ? _285 : (isnan(_285) ? _283 : min(_285, _283));
    float _288 = isnan(_213) ? _193 : (isnan(_193) ? _213 : max(_193, _213));
    float _289 = isnan(_214) ? _194 : (isnan(_194) ? _214 : max(_194, _214));
    float _290 = isnan(_233) ? _288 : (isnan(_288) ? _233 : max(_288, _233));
    float _291 = isnan(_234) ? _289 : (isnan(_289) ? _234 : max(_289, _234));
    float _292 = isnan(_273) ? _253 : (isnan(_253) ? _273 : max(_253, _273));
    float _293 = isnan(_274) ? _254 : (isnan(_254) ? _274 : max(_254, _274));
    float _294 = isnan(_290) ? _292 : (isnan(_292) ? _290 : max(_292, _290));
    float _295 = isnan(_291) ? _293 : (isnan(_293) ? _291 : max(_293, _291));
    float _299 = 1.0f - _294;
    float _300 = 1.0f - _295;
    float _303 = (isnan(_299) ? _286 : (isnan(_286) ? _299 : min(_286, _299))) * (1.0f / _294);
    float _304 = (isnan(_300) ? _287 : (isnan(_287) ? _300 : min(_287, _300))) * (1.0f / _295);
    float _981 = isnan(0.0f) ? _303 : (isnan(_303) ? 0.0f : max(_303, 0.0f));
    float _992 = isnan(0.0f) ? _304 : (isnan(_304) ? 0.0f : max(_304, 0.0f));
    float2 _313 = spvUnpackHalf2x16(asuint(_23_m0[1u]).y & 65535u);
    float _314 = _313.x;
    float _315 = _314 * sqrt(isnan(1.0f) ? _981 : (isnan(_981) ? 1.0f : min(_981, 1.0f)));
    float _316 = _314 * sqrt(isnan(1.0f) ? _992 : (isnan(_992) ? 1.0f : min(_992, 1.0f)));
    float _322 = 1.0f / ((_315 * 4.0f) + 1.0f);
    float _323 = 1.0f / ((_316 * 4.0f) + 1.0f);
    float _329 = ((_316 * (((exp2(_18_m0[1u].w * log2((_151.x + 0.05499267578125f) * 0.9482421875f)) + exp2(_18_m0[1u].w * log2((_139.x + 0.05499267578125f) * 0.9482421875f))) + exp2(_18_m0[1u].w * log2((_168.x + 0.05499267578125f) * 0.9482421875f))) + exp2(_18_m0[1u].w * log2((_173.x + 0.05499267578125f) * 0.9482421875f)))) + exp2(_18_m0[1u].w * log2((_156.x + 0.05499267578125f) * 0.9482421875f))) * _323;
    float _1003 = isnan(0.0f) ? _329 : (isnan(_329) ? 0.0f : max(_329, 0.0f));
    float _336 = ((_316 * (((_214 + _194) + _254) + _274)) + _234) * _323;
    float _1014 = isnan(0.0f) ? _336 : (isnan(_336) ? 0.0f : max(_336, 0.0f));
    float _343 = ((_316 * (((exp2(log2((_151.z + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w) + exp2(log2((_139.z + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w)) + exp2(log2((_168.z + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w)) + exp2(log2((_173.z + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w))) + exp2(log2((_156.z + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w)) * _323;
    float _1025 = isnan(0.0f) ? _343 : (isnan(_343) ? 0.0f : max(_343, 0.0f));
    float _345 = isnan(0.00100040435791015625f) ? _18_m0[1u].w : (isnan(_18_m0[1u].w) ? 0.00100040435791015625f : max(_18_m0[1u].w, 0.00100040435791015625f));
    if ((_58 <= _55.z) && (_59 <= _55.w))
    {
        float _388 = (((((exp2(log2((_106.z + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w) + exp2(log2((_91.z + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w)) + exp2(log2((_119.z + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w)) + exp2(log2((_128.z + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w)) * _315) + exp2(log2((_109.z + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w)) * _322;
        float _1041 = isnan(0.0f) ? _388 : (isnan(_388) ? 0.0f : max(_388, 0.0f));
        float _391 = 1.0f / _345;
        float _396 = (exp2(_391 * log2(isnan(1.0f) ? _1041 : (isnan(_1041) ? 1.0f : min(_1041, 1.0f)))) * 1.0546875f) + (-0.05499267578125f);
        float _404 = ((_315 * (((_213 + _193) + _253) + _273)) + _233) * _322;
        float _1057 = isnan(0.0f) ? _404 : (isnan(_404) ? 0.0f : max(_404, 0.0f));
        float _410 = (exp2(_391 * log2(isnan(1.0f) ? _1057 : (isnan(_1057) ? 1.0f : min(_1057, 1.0f)))) * 1.0546875f) + (-0.05499267578125f);
        float _447 = (((((exp2(log2((_106.x + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w) + exp2(log2((_91.x + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w)) + exp2(log2((_119.x + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w)) + exp2(log2((_128.x + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w)) * _315) + exp2(log2((_109.x + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w)) * _322;
        float _1073 = isnan(0.0f) ? _447 : (isnan(_447) ? 0.0f : max(_447, 0.0f));
        float _453 = (exp2(_391 * log2(isnan(1.0f) ? _1073 : (isnan(_1073) ? 1.0f : min(_1073, 1.0f)))) * 1.0546875f) + (-0.05499267578125f);
        _11[uint2(_58, _59)] = float4(isnan(0.0f) ? _453 : (isnan(_453) ? 0.0f : max(_453, 0.0f)), isnan(0.0f) ? _410 : (isnan(_410) ? 0.0f : max(_410, 0.0f)), isnan(0.0f) ? _396 : (isnan(_396) ? 0.0f : max(_396, 0.0f)), 1.0f);
    }
    uint _458 = _58 + 8u;
    uint4 _461 = asuint(_23_m0[2u]);
    if ((_458 <= _461.z) && (_59 <= _461.w))
    {
        float _468 = 1.0f / _345;
        float _472 = (exp2(_468 * log2(isnan(1.0f) ? _1025 : (isnan(_1025) ? 1.0f : min(_1025, 1.0f)))) * 1.0546875f) + (-0.05499267578125f);
        float _478 = (exp2(_468 * log2(isnan(1.0f) ? _1014 : (isnan(_1014) ? 1.0f : min(_1014, 1.0f)))) * 1.0546875f) + (-0.05499267578125f);
        float _484 = (exp2(_468 * log2(isnan(1.0f) ? _1003 : (isnan(_1003) ? 1.0f : min(_1003, 1.0f)))) * 1.0546875f) + (-0.05499267578125f);
        _11[uint2(_458, _59)] = float4(isnan(0.0f) ? _484 : (isnan(_484) ? 0.0f : max(_484, 0.0f)), isnan(0.0f) ? _478 : (isnan(_478) ? 0.0f : max(_478, 0.0f)), isnan(0.0f) ? _472 : (isnan(_472) ? 0.0f : max(_472, 0.0f)), 1.0f);
    }
    uint _489 = _59 + 8u;
    uint4 _492 = asuint(_23_m0[3u]);
    uint _493 = _492.x;
    uint _494 = _492.y;
    uint _495 = _492.z;
    uint _496 = _492.w;
    uint _497 = _489 << 16u;
    uint _505 = uint(int(max(min(_76, _495), _493) << 16u) >> int(16u));
    uint _507 = uint(int(max(min(uint(int(_497 + 4294901760u) >> int(16u)), _496), _494) << 16u) >> int(16u));
    float4 _509 = _8.Load(int3(uint2(_505, _507), 0u));
    uint _520 = uint(int(max(min(uint(int(_497) >> int(16u)), _496), _494) << 16u) >> int(16u));
    float4 _521 = _8.Load(int3(uint2(uint(int(max(min(_96, _495), _493) << 16u) >> int(16u)), _520), 0u));
    float4 _524 = _8.Load(int3(uint2(_505, _520), 0u));
    float4 _531 = _8.Load(int3(uint2(uint(int(max(min(_114, _495), _493) << 16u) >> int(16u)), _520), 0u));
    uint _539 = uint(int(max(min(uint(int(_497 + 65536u) >> int(16u)), _496), _494) << 16u) >> int(16u));
    float4 _540 = _8.Load(int3(uint2(_505, _539), 0u));
    uint _546 = uint(int(max(min(_134, _495), _493) << 16u) >> int(16u));
    float4 _547 = _8.Load(int3(uint2(_546, _507), 0u));
    float4 _556 = _8.Load(int3(uint2(uint(int(max(min(_146, _495), _493) << 16u) >> int(16u)), _520), 0u));
    float4 _561 = _8.Load(int3(uint2(_546, _520), 0u));
    float4 _570 = _8.Load(int3(uint2(uint(int(max(min(_163, _495), _493) << 16u) >> int(16u)), _520), 0u));
    float4 _575 = _8.Load(int3(uint2(_546, _539), 0u));
    float _596 = exp2(log2((_509.y + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w);
    float _597 = exp2(log2((_547.y + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w);
    float _616 = exp2(log2((_521.y + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w);
    float _617 = exp2(log2((_556.y + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w);
    float _636 = exp2(log2((_524.y + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w);
    float _637 = exp2(log2((_561.y + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w);
    float _656 = exp2(log2((_531.y + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w);
    float _657 = exp2(log2((_570.y + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w);
    float _676 = exp2(log2((_540.y + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w);
    float _677 = exp2(log2((_575.y + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w);
    float _683 = isnan(_616) ? _596 : (isnan(_596) ? _616 : min(_596, _616));
    float _684 = isnan(_617) ? _597 : (isnan(_597) ? _617 : min(_597, _617));
    float _685 = isnan(_636) ? _683 : (isnan(_683) ? _636 : min(_683, _636));
    float _686 = isnan(_637) ? _684 : (isnan(_684) ? _637 : min(_684, _637));
    float _687 = isnan(_676) ? _656 : (isnan(_656) ? _676 : min(_656, _676));
    float _688 = isnan(_677) ? _657 : (isnan(_657) ? _677 : min(_657, _677));
    float _689 = isnan(_685) ? _687 : (isnan(_687) ? _685 : min(_687, _685));
    float _690 = isnan(_686) ? _688 : (isnan(_688) ? _686 : min(_688, _686));
    float _691 = isnan(_616) ? _596 : (isnan(_596) ? _616 : max(_596, _616));
    float _692 = isnan(_617) ? _597 : (isnan(_597) ? _617 : max(_597, _617));
    float _693 = isnan(_636) ? _691 : (isnan(_691) ? _636 : max(_691, _636));
    float _694 = isnan(_637) ? _692 : (isnan(_692) ? _637 : max(_692, _637));
    float _695 = isnan(_676) ? _656 : (isnan(_656) ? _676 : max(_656, _676));
    float _696 = isnan(_677) ? _657 : (isnan(_657) ? _677 : max(_657, _677));
    float _697 = isnan(_693) ? _695 : (isnan(_695) ? _693 : max(_695, _693));
    float _698 = isnan(_694) ? _696 : (isnan(_696) ? _694 : max(_696, _694));
    float _701 = 1.0f - _697;
    float _702 = 1.0f - _698;
    float _705 = (isnan(_701) ? _689 : (isnan(_689) ? _701 : min(_689, _701))) * (1.0f / _697);
    float _706 = (isnan(_702) ? _690 : (isnan(_690) ? _702 : min(_690, _702))) * (1.0f / _698);
    float _1194 = isnan(0.0f) ? _705 : (isnan(_705) ? 0.0f : max(_705, 0.0f));
    float _1205 = isnan(0.0f) ? _706 : (isnan(_706) ? 0.0f : max(_706, 0.0f));
    float _711 = _314 * sqrt(isnan(1.0f) ? _1194 : (isnan(_1194) ? 1.0f : min(_1194, 1.0f)));
    float _712 = _314 * sqrt(isnan(1.0f) ? _1205 : (isnan(_1205) ? 1.0f : min(_1205, 1.0f)));
    float _717 = 1.0f / ((_711 * 4.0f) + 1.0f);
    float _718 = 1.0f / ((_712 * 4.0f) + 1.0f);
    float _724 = ((_712 * (((exp2(_18_m0[1u].w * log2((_556.x + 0.05499267578125f) * 0.9482421875f)) + exp2(_18_m0[1u].w * log2((_547.x + 0.05499267578125f) * 0.9482421875f))) + exp2(_18_m0[1u].w * log2((_570.x + 0.05499267578125f) * 0.9482421875f))) + exp2(_18_m0[1u].w * log2((_575.x + 0.05499267578125f) * 0.9482421875f)))) + exp2(_18_m0[1u].w * log2((_561.x + 0.05499267578125f) * 0.9482421875f))) * _718;
    float _1216 = isnan(0.0f) ? _724 : (isnan(_724) ? 0.0f : max(_724, 0.0f));
    float _731 = ((_712 * (((_617 + _597) + _657) + _677)) + _637) * _718;
    float _1227 = isnan(0.0f) ? _731 : (isnan(_731) ? 0.0f : max(_731, 0.0f));
    float _738 = ((_712 * (((exp2(log2((_556.z + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w) + exp2(log2((_547.z + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w)) + exp2(log2((_570.z + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w)) + exp2(log2((_575.z + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w))) + exp2(log2((_561.z + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w)) * _718;
    float _1238 = isnan(0.0f) ? _738 : (isnan(_738) ? 0.0f : max(_738, 0.0f));
    uint4 _742 = asuint(_23_m0[2u]);
    if ((_58 <= _742.z) && (_489 <= _742.w))
    {
        float _783 = (((((exp2(log2((_521.z + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w) + exp2(log2((_509.z + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w)) + exp2(log2((_531.z + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w)) + exp2(log2((_540.z + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w)) * _711) + exp2(log2((_524.z + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w)) * _717;
        float _1249 = isnan(0.0f) ? _783 : (isnan(_783) ? 0.0f : max(_783, 0.0f));
        float _786 = 1.0f / _345;
        float _790 = (exp2(_786 * log2(isnan(1.0f) ? _1249 : (isnan(_1249) ? 1.0f : min(_1249, 1.0f)))) * 1.0546875f) + (-0.05499267578125f);
        float _797 = ((_711 * (((_616 + _596) + _656) + _676)) + _636) * _717;
        float _1265 = isnan(0.0f) ? _797 : (isnan(_797) ? 0.0f : max(_797, 0.0f));
        float _803 = (exp2(_786 * log2(isnan(1.0f) ? _1265 : (isnan(_1265) ? 1.0f : min(_1265, 1.0f)))) * 1.0546875f) + (-0.05499267578125f);
        float _840 = (((((exp2(log2((_521.x + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w) + exp2(log2((_509.x + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w)) + exp2(log2((_531.x + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w)) + exp2(log2((_540.x + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w)) * _711) + exp2(log2((_524.x + 0.05499267578125f) * 0.9482421875f) * _18_m0[1u].w)) * _717;
        float _1281 = isnan(0.0f) ? _840 : (isnan(_840) ? 0.0f : max(_840, 0.0f));
        float _846 = (exp2(_786 * log2(isnan(1.0f) ? _1281 : (isnan(_1281) ? 1.0f : min(_1281, 1.0f)))) * 1.0546875f) + (-0.05499267578125f);
        _11[uint2(_58, _489)] = float4(isnan(0.0f) ? _846 : (isnan(_846) ? 0.0f : max(_846, 0.0f)), isnan(0.0f) ? _803 : (isnan(_803) ? 0.0f : max(_803, 0.0f)), isnan(0.0f) ? _790 : (isnan(_790) ? 0.0f : max(_790, 0.0f)), 1.0f);
    }
    uint4 _853 = asuint(_23_m0[2u]);
    if ((_458 <= _853.z) && (_489 <= _853.w))
    {
        float _860 = 1.0f / _345;
        float _864 = (exp2(_860 * log2(isnan(1.0f) ? _1238 : (isnan(_1238) ? 1.0f : min(_1238, 1.0f)))) * 1.0546875f) + (-0.05499267578125f);
        float _870 = (exp2(_860 * log2(isnan(1.0f) ? _1227 : (isnan(_1227) ? 1.0f : min(_1227, 1.0f)))) * 1.0546875f) + (-0.05499267578125f);
        float _876 = (exp2(_860 * log2(isnan(1.0f) ? _1216 : (isnan(_1216) ? 1.0f : min(_1216, 1.0f)))) * 1.0546875f) + (-0.05499267578125f);
        _11[uint2(_458, _489)] = float4(isnan(0.0f) ? _876 : (isnan(_876) ? 0.0f : max(_876, 0.0f)), isnan(0.0f) ? _870 : (isnan(_870) ? 0.0f : max(_870, 0.0f)), isnan(0.0f) ? _864 : (isnan(_864) ? 0.0f : max(_864, 0.0f)), 1.0f);
    }
#endif
}

[numthreads(64, 1, 1)]
void main(SPIRV_Cross_Input stage_input)
{
    gl_WorkGroupID = stage_input.gl_WorkGroupID;
    gl_LocalInvocationID = stage_input.gl_LocalInvocationID;
    comp_main();
}
