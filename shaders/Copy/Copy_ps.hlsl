#include "../shared.hlsl"
#include "../color.hlsl"
#include "RootSignature.hlsl"

Texture2D<float4> inputTexture  : register(t0, space8);
SamplerState inputSampler : register(s0, space8);

struct PSInputs
{
    float2 uv : TEXCOORD0;
	float4 pos : SV_Position;
};

[RootSignature(ShaderRootSignature)]
float4 PS(PSInputs inputs) : SV_Target
{
	float4 color = inputTexture.Sample(inputSampler, float2(inputs.uv.x, inputs.uv.y));

    if (HdrDllPluginConstants.DisplayMode == 1 && HdrDllPluginConstants.bIsAtEndOfFrame)
	{
        float3 pq = linear_to_PQ(color.rgb);
        color.rgb = pq.rgb;
    }

    return color;
}


//--

// Texture2D<float4> _8 : register(t0, space8);
// SamplerState _11 : register(s0, space8);

// static float4 TEXCOORD;
// static float4 SV_Target;

// struct SPIRV_Cross_Input
// {
//     float4 TEXCOORD : TEXCOORD0;
// };

// struct SPIRV_Cross_Output
// {
//     float4 SV_Target : SV_Target0;
// };

// void frag_main()
// {
//     float4 _31 = _8.Sample(_11, float2(TEXCOORD.x, TEXCOORD.y));
//     SV_Target.x = _31.x;
//     SV_Target.y = _31.y;
//     SV_Target.z = _31.z;
//     SV_Target.w = _31.w;
// }

// SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
// {
//     TEXCOORD = stage_input.TEXCOORD;
//     frag_main();
//     SPIRV_Cross_Output stage_output;
//     stage_output.SV_Target = SV_Target;
//     return stage_output;
// }
