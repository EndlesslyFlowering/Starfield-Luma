Texture2D<float4> _8 : register(t0, space8);
SamplerState _11 : register(s0, space8);

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
    float4 _31 = _8.Sample(_11, float2(TEXCOORD.x, TEXCOORD.y));
    SV_Target.x = _31.x;
    SV_Target.y = _31.y;
    SV_Target.z = _31.z;
    SV_Target.w = _31.w;
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    TEXCOORD = stage_input.TEXCOORD;
    frag_main();
    SPIRV_Cross_Output stage_output;
    stage_output.SV_Target = SV_Target;
    return stage_output;
}
