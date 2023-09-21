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
}

[numthreads(64, 1, 1)]
void main(SPIRV_Cross_Input stage_input)
{
    gl_WorkGroupID = stage_input.gl_WorkGroupID;
    gl_LocalInvocationID = stage_input.gl_LocalInvocationID;
    comp_main();
}
