#include "../shared.hlsl"
#include "../color.hlsl"
#include "RootSignature.hlsl"

cbuffer _13_15 : register(b0, space7)
{
	float4 _15_m0[3269] : packoffset(c0);
};


struct PushConstantWrapper_PostSharpen
{
	float4 params0;
	float3 params1;
};


cbuffer CPushConstantWrapper_PostSharpen : register(b0, space0)
{
	PushConstantWrapper_PostSharpen PcwPostSharpen : packoffset(c0);
};

Texture2D<float3> TonemappedColorTexture : register(t0, space8); // Possibly in gamma space in SDR
SamplerState Sampler0 : register(s13, space6); // Likely bilinear
SamplerState Sampler1 : register(s15, space6); // Likely nearest neighbor

struct PSInput
{
	float4 TEXCOORD    : TEXCOORD0;
	float4 SV_Position : SV_Position0;
};

struct PSOutput
{
	float4 SV_Target : SV_Target0;
};

#if SDR_USE_GAMMA_2_2
	#define GAMMA_TO_LINEAR(x) pow(x, 2.2f)
	#define LINEAR_TO_GAMMA(x) pow(x, 1.f / 2.2f)
#else
	#define GAMMA_TO_LINEAR(x) gamma_sRGB_to_linear(x)
	#define LINEAR_TO_GAMMA(x) gamma_linear_to_sRGB(x)
#endif


[RootSignature(ShaderRootSignature)]
PSOutput PS(PSInput psInput)
{
#if 0
	float3 outColor = TonemappedColorTexture.Sample(Sampler0, psInput.TEXCOORD.xy).rgb;
#else
	float3 inColor = TonemappedColorTexture.Sample(Sampler0, psInput.TEXCOORD.xy).rgb;
	if (HdrDllPluginConstants.DisplayMode <= 0)
	{
		inColor = GAMMA_TO_LINEAR(inColor);
	}
	float3 outColor = inColor;
	float4 sharpenParams = PcwPostSharpen.params0;
	float sharpenIntensity = sharpenParams.z;
	if (sharpenIntensity > 0.f)
	{
		float _70 = ((_15_m0[161u].z * psInput.TEXCOORD.x) * sharpenParams.x) + 0.5f;
		float _72 = ((_15_m0[161u].w * psInput.TEXCOORD.y) * sharpenParams.y) + 0.5f;
		float _76 = frac(_70);
		float _77 = frac(_72);
		float _87 = ((((((_76 * 2.f) + (-3.f)) * _76) + (-3.f)) * _76) + 5.f) * (1.f / 6.f);
		float _89 = _76 * 3.f;
		float _98 = ((((((3.f - _89) + _76) * _76) + 3.f) * _76) + 1.f) * (1.f / 6.f);
		float _99 = _76 * _76;
		float _113 = _77 * _77;
		float _114 = _77 * 3.f;
		float _125 = ((((((_77 * 2.f) + (-3.f)) * _77) + (-3.f)) * _77) + 5.f) * (1.f / 6.f);
		float _136 = ((((((3.f - _114) + _77) * _77) + 3.f) * _77) + 1.f) * (1.f / 6.f);
		float _139 = floor(_70) + (-0.5f);
		float _142 = floor(_72) + (-0.5f);
		float _144 = (_139 + ((((( _99 * ( _89 + (-6.f))) + 4.f) * (1.f / 6.f)) /  _87) + (-1.f))) / _15_m0[161u].z;
		float _145 = (_142 + (((((_113 * (_114 + (-6.f))) + 4.f) * (1.f / 6.f)) / _125) + (-1.f))) / _15_m0[161u].w;
		float _147 = (_139 + (((( _99 * (1.f / 6.f)) * _76) /  _98) + 1.f)) / _15_m0[161u].z;
		float _149 = (_142 + ((((_113 * (1.f / 6.f)) * _77) / _136) + 1.f)) / _15_m0[161u].w;
		float3 _152 = TonemappedColorTexture.Sample(Sampler1, float2(_144, _145));
		float3 _157 = TonemappedColorTexture.Sample(Sampler1, float2(_147, _145));
		float3 _162 = TonemappedColorTexture.Sample(Sampler1, float2(_144, _149));
		float3 _167 = TonemappedColorTexture.Sample(Sampler1, float2(_147, _149));
		if (HdrDllPluginConstants.DisplayMode <= 0)
		{
			_152 = GAMMA_TO_LINEAR(_152);
			_157 = GAMMA_TO_LINEAR(_157);
			_162 = GAMMA_TO_LINEAR(_162);
			_167 = GAMMA_TO_LINEAR(_167);
		}
		float3 sharpenedColor = (((_167 * _98) + (_162 * _87)) * _136) + (((_157 * _98) + (_152 * _87)) * _125);
		// It seems controls the amount of (manaually done) bilinear filtering vs nearest neightbor, so full sharpening is just bilinear
		outColor = lerp(sharpenedColor, inColor, sharpenIntensity);
	}
	if (HdrDllPluginConstants.DisplayMode <= 0)
	{
		outColor = LINEAR_TO_GAMMA(outColor);
	}
#endif
	PSOutput psOutput;

	psOutput.SV_Target.rgb = outColor;
	psOutput.SV_Target.a = 1.f;

	return psOutput;
}
