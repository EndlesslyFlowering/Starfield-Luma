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

#if SDR_LINEAR_INTERMEDIARY
	#define GAMMA_TO_LINEAR(x) x
	#define LINEAR_TO_GAMMA(x) x
#elif SDR_USE_GAMMA_2_2
	#define GAMMA_TO_LINEAR(x) pow(x, 2.2f)
	#define LINEAR_TO_GAMMA(x) pow(x, 1.f / 2.2f)
#else
	#define GAMMA_TO_LINEAR(x) gamma_sRGB_to_linear(x)
	#define LINEAR_TO_GAMMA(x) gamma_linear_to_sRGB(x)
#endif

#define RCP6 0.16666667163372039794921875f

[RootSignature(ShaderRootSignature)]
PSOutput PS(PSInput psInput)
{
	float3 outColor;

	if (HdrDllPluginConstants.PostSharpen == false)  // Disable post sharpen
	{
		outColor = TonemappedColorTexture.Sample(Sampler0, psInput.TEXCOORD.xy).rgb;
	}
	else
	{
		float3 inColor = TonemappedColorTexture.Sample(Sampler0, psInput.TEXCOORD.xy).rgb;
		outColor = inColor;
		float4 sharpenParams = PcwPostSharpen.params0;
		float sharpenIntensity = sharpenParams.z;
		if (sharpenIntensity > 0.f && sharpenIntensity != 1.f)
		{
			// Sharpening is best done in linear space, even if Bethesda made in gamma space
			if (HdrDllPluginConstants.DisplayMode > 0)
			{
				inColor /= IntermediateNormalizationFactor;
			}
			else
			{
				inColor = GAMMA_TO_LINEAR(inColor);
			}

			static const float2 cbConst = _15_m0[161u].zw;

			float2 _70 = (cbConst * psInput.TEXCOORD.xy * sharpenParams.xy) + 0.5f;

			float2 _76 = frac(_70);

			float2 _89 = _76 * 3.f;

#if 0
			float2 _87 = (((((_76 * 2.f - 3.f) * _76) - 3.f) * _76) + 5.f) * RCP6;

			float2 _98 = (((((3.f - _89 + _76) * _76) + 3.f) * _76) + 1.f) * RCP6;
#else
			float4 _88 = float4(_76 * 2.f - 3.f,
			                    3.f - _89 + _76);
			_88.xzyw *= _76.xxyy;

			_88.xy -= 3.f;
			_88.zw += 3.f;

			_88.xzyw *= _76.xxyy;

			_88.xy += 5.f;
			_88.zw += 1.f;

			_88 *= RCP6;
#endif
			float2 _139 = floor(_70) - 0.5f;

			float2 _99 = _76 * _76;

#if 0
			float2 _144 = (_139 + (((((_99 * (_89 - 6.f)) + 4.f) * RCP6) / _87) - 1.f)) / cbConst;

			float2 _147 = (_139 + ((((_99 * RCP6) * _76) / _98) + 1.f)) / cbConst;

			float3 _152 = TonemappedColorTexture.Sample(Sampler1, _144);
			float3 _157 = TonemappedColorTexture.Sample(Sampler1, float2(_147.x, _144.y));
			float3 _162 = TonemappedColorTexture.Sample(Sampler1, float2(_144.x, _147.y));
			float3 _167 = TonemappedColorTexture.Sample(Sampler1, _147);
#else
			float4 _145 = float4(_89 - 6.f,
			                     RCP6, RCP6);

			_145.xzyw *= _99.xxyy;

			_145.xy += 4.f;
			_145.zw *= _76;

			_145.xy *= RCP6;

			_145 /= _88;

			_145.xy -= 1.f;
			_145.zw += 1.f;

			_145.xzyw += _139.xxyy;

			_145.xzyw /= cbConst.xxyy;

			float3 _152 = TonemappedColorTexture.Sample(Sampler1, _145.xy);
			float3 _157 = TonemappedColorTexture.Sample(Sampler1, _145.zy);
			float3 _162 = TonemappedColorTexture.Sample(Sampler1, _145.xw);
			float3 _167 = TonemappedColorTexture.Sample(Sampler1, _145.zw);
#endif

			if (HdrDllPluginConstants.DisplayMode > 0)
			{
				_152 /= IntermediateNormalizationFactor;
				_157 /= IntermediateNormalizationFactor;
				_162 /= IntermediateNormalizationFactor;
				_167 /= IntermediateNormalizationFactor;
			}
			else
			{
				_152 = GAMMA_TO_LINEAR(_152);
				_157 = GAMMA_TO_LINEAR(_157);
				_162 = GAMMA_TO_LINEAR(_162);
				_167 = GAMMA_TO_LINEAR(_167);
			}

#if 0
			float3 unsharpenedColor = (((_167 * _98.x) + (_162 * _87.x)) * _98.y) + (((_157 * _98.x) + (_152 * _87.x)) * _87.y);
#else
			float3 unsharpenedColor = (((_167 * _88.z) + (_162 * _88.x)) * _88.w) + (((_157 * _88.z) + (_152 * _88.x)) * _88.y);
#endif
			// Controls the amount of a custom blurred bilinear filtering vs HW bilinear (which is blurry if there's upscaling),
			// by lerping beyond 1 in the opposite direction of the blurred image, we apply sharpening.
			outColor = lerp(unsharpenedColor, inColor, sharpenIntensity);

			if (HdrDllPluginConstants.DisplayMode > 0)
			{
				outColor = max(outColor, 0.f);
				outColor *= IntermediateNormalizationFactor;
			}
			else
			{
				outColor = LINEAR_TO_GAMMA(outColor);
			}
		}
	}

	PSOutput psOutput;

	psOutput.SV_Target.rgb = outColor;
	psOutput.SV_Target.a = 1.f;

	return psOutput;
}
