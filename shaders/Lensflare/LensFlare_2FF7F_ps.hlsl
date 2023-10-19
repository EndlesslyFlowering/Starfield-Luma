cbuffer _18_20 : register(b0, space7)
{
    float4 _20_m0[3269] : packoffset(c0);
};

cbuffer _23_25 : register(b0, space8)
{
    float4 _25_m0[894] : packoffset(c0);
};

cbuffer _28_30 : register(b1, space8)
{
    float4 _30_m0[4] : packoffset(c0);
};

Texture2D<float4> _9[] : register(t0, space0);
Buffer<uint4> _13 : register(t0, space8);
Buffer<uint4> _14 : register(t1, space8);
SamplerState _33 : register(s0, space8);

static float4 TEXCOORD;
static float4 SV_Target;

struct SPIRV_Cross_Input
{
    float4 TEXCOORD : TEXCOORD0;
};

struct SPIRV_Cross_Output
{
    float4 SV_Target : SV_Target0;
};

void frag_main()
{
    uint4 _55 = asuint(_30_m0[2u]);
    uint _56 = _55.x;
    float _60 = asfloat(_13.Load(_56).x);
    float _64;
    float _66;
    if ((asuint(_30_m0[1u].w) & 2u) == 0u)
    {
        _64 = TEXCOORD.x;
        _66 = TEXCOORD.y;
    }
    else
    {
        float _130 = _60 + 0.001000000047497451305389404296875f;
        _64 = ((TEXCOORD.x + (-0.5f)) / _130) + 0.5f;
        _66 = ((TEXCOORD.y + (-0.5f)) / _130) + 0.5f;
    }
    float4 _116 = _9[_55.z].Sample(_33, float2(_64, _66));
    float _158;
    float _159;
    float _160;
    if (_56 == asuint(_25_m0[1u]).z)
    {
        float3 _147 = asfloat(uint3(_14.Load(0u).x, _14.Load(0u + 1u).x, _14.Load(0u + 2u).x));
        _158 = _147.x;
        _159 = _147.y;
        _160 = _147.z;
    }
    else
    {
        uint _151 = _56 + 514u;
        _158 = _25_m0[_151].x;
        _159 = _25_m0[_151].y;
        _160 = _25_m0[_151].z;
    }
    float _164 = (1.0f - ((1.0f - clamp((_30_m0[3u].y + log2(min(max((_20_m0[316u].y > 1.0000000133514319600180897396058e-10f) ? _20_m0[316u].y : (_20_m0[316u].z / max(_20_m0[316u].x * 1.2000000476837158203125f, 9.9999997473787516355514526367188e-05f)), _20_m0[317u].y), _20_m0[317u].z) * 1.2000000476837158203125f)) / (_30_m0[3u].y - _30_m0[3u].x), 0.0f, 1.0f)) * _30_m0[2u].w)) * _60;
    SV_Target.x = ((_164 * _116.x) * _158) * _30_m0[1u].x;
    SV_Target.y = ((_164 * _116.y) * _159) * _30_m0[1u].y;
    SV_Target.z = ((_164 * _116.z) * _160) * _30_m0[1u].z;
    SV_Target.w = 0.0f;
}

[earlydepthstencil]
SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    TEXCOORD = stage_input.TEXCOORD;
    frag_main();
    SPIRV_Cross_Output stage_output;
    stage_output.SV_Target = SV_Target;
    return stage_output;
}
