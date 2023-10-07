#include "../shared.hlsl"
#include "../color.hlsl"
#include "RootSignature.hlsl"

cbuffer _13_15 : register(b0, space7)
{
	float4 _15_m0[3269] : packoffset(c0);
};

cbuffer _18_20 : register(b0, space0)
{
	float4 _20_m0[2] : packoffset(c0);
};

Texture2D<float3> TonemappedColorTexture : register(t0, space8); // Possibly in gamma space in SDR
SamplerState Sampler0 : register(s13, space6); // Likely bilinear
SamplerState Sampler1 : register(s15, space6); // Likely nearest neighbor

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

#if SDR_USE_GAMMA_2_2
	#define GAMMA_TO_LINEAR(x) pow(x, 2.2f)
	#define LINEAR_TO_GAMMA(x) pow(x, 1.f / 2.2f)
#else //TODO: make this use half instead of float
	#define GAMMA_TO_LINEAR(x) gamma_sRGB_to_linear(x)
	#define LINEAR_TO_GAMMA(x) gamma_linear_to_sRGB(x)
#endif

void frag_main()
{
	float3 inColor = TonemappedColorTexture.Sample(Sampler0, TEXCOORD.xy).xyz;
#if !ENABLE_HDR
	inColor = GAMMA_TO_LINEAR(inColor);
#endif
	float3 outColor = inColor;
	uint4 sharpenParams = asuint(_20_m0[0u]);
	float sharpenIntensity = asfloat(sharpenParams.z);
	if (sharpenIntensity > 0.f)
	{
		float _70 = ((_15_m0[161u].z * TEXCOORD.x) * asfloat(sharpenParams.x)) + 0.5f;
		float _72 = ((_15_m0[161u].w * TEXCOORD.y) * asfloat(sharpenParams.y)) + 0.5f;
		float _76 = frac(_70);
		float _77 = frac(_72);
		float _87 = ((((((_76 * 2.0f) + (-3.0f)) * _76) + (-3.0f)) * _76) + 5.0f) * 0.16666667163372039794921875f;
		float _89 = _76 * 3.0f;
		float _98 = ((((((3.0f - _89) + _76) * _76) + 3.0f) * _76) + 1.0f) * 0.16666667163372039794921875f;
		float _99 = _76 * _76;
		float _113 = _77 * _77;
		float _114 = _77 * 3.0f;
		float _125 = ((((((_77 * 2.0f) + (-3.0f)) * _77) + (-3.0f)) * _77) + 5.0f) * 0.16666667163372039794921875f;
		float _136 = ((((((3.0f - _114) + _77) * _77) + 3.0f) * _77) + 1.0f) * 0.16666667163372039794921875f;
		float _139 = floor(_70) + (-0.5f);
		float _142 = floor(_72) + (-0.5f);
		float _144 = (_139 + (((((_99 * (_89 + (-6.0f))) + 4.0f) * 0.16666667163372039794921875f) / _87) + (-1.0f))) / _15_m0[161u].z;
		float _145 = (_142 + (((((_113 * (_114 + (-6.0f))) + 4.0f) * 0.16666667163372039794921875f) / _125) + (-1.0f))) / _15_m0[161u].w;
		float _147 = (_139 + ((((_99 * 0.16666667163372039794921875f) * _76) / _98) + 1.0f)) / _15_m0[161u].z;
		float _149 = (_142 + ((((_113 * 0.16666667163372039794921875f) * _77) / _136) + 1.0f)) / _15_m0[161u].w;
		float3 _152 = TonemappedColorTexture.SampleLevel(Sampler1, float2(_144, _145), 0.0f);
		float3 _157 = TonemappedColorTexture.SampleLevel(Sampler1, float2(_147, _145), 0.0f);
		float3 _162 = TonemappedColorTexture.SampleLevel(Sampler1, float2(_144, _149), 0.0f);
		float3 _167 = TonemappedColorTexture.SampleLevel(Sampler1, float2(_147, _149), 0.0f);
#if !ENABLE_HDR
		_152 = GAMMA_TO_LINEAR(_152);
		_157 = GAMMA_TO_LINEAR(_157);
		_162 = GAMMA_TO_LINEAR(_162);
		_167 = GAMMA_TO_LINEAR(_167);
#endif
		float3 sharpenedColor = (((_167 * _98) + (_162 * _87)) * _136) + (((_157 * _98) + (_152 * _87)) * _125);
		// It seems controls the amount of (manaually done) bilinear filtering vs nearest neightbor, so full sharpening is just bilinear
		outColor = lerp(sharpenedColor, inColor, sharpenIntensity); 
	}
#if !ENABLE_HDR
	outColor = LINEAR_TO_GAMMA(outColor);
#endif
	SV_Target.xyz = outColor;
	SV_Target.w = 1.0f;
}

[RootSignature(ShaderRootSignature)]
SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
	TEXCOORD = stage_input.TEXCOORD;
	frag_main();
	SPIRV_Cross_Output stage_output;
	stage_output.SV_Target = SV_Target;
	return stage_output;
}