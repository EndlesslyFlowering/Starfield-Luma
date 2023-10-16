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

	if (HdrDllPluginConstants.IsAtEndOfFrame)
	{
		if (HdrDllPluginConstants.DisplayMode == 1) // HDR10 PQ BT.2020
		{
			// There is no need to clamp if "CLAMP_INPUT_OUTPUT" is true here as the output buffer is int so it will clip anything beyond 0-1.
			color.rgb = Linear_to_PQ(BT709_To_BT2020(color.rgb), PQMaxWhitePoint);
		}
#if SDR_LINEAR_INTERMEDIARY
		else if (HdrDllPluginConstants.DisplayMode == 0) // SDR (linear to gamma space conversion)
		{
#if SDR_USE_GAMMA_2_2
			color.rgb = pow(color.rgb, 1.f / 2.2f);
#else
			color.rgb = gamma_linear_to_sRGB(color.rgb);
#endif // SDR_USE_GAMMA_2_2
		}
#else // SDR_LINEAR_INTERMEDIARY
		else if (HdrDllPluginConstants.DisplayMode == -1) // SDR on scRGB HDR (gamma to linear space conversion)
		{
#if SDR_USE_GAMMA_2_2
			color.rgb = pow(color.rgb, 2.2f);
#else
			color.rgb = gamma_sRGB_to_linear(color.rgb);
#endif // SDR_USE_GAMMA_2_2
		}
#endif // SDR_LINEAR_INTERMEDIARY
		if (HdrDllPluginConstants.DisplayMode == -1) // SDR on scRGB HDR (paper white multiplication)
		{
#if CLAMP_INPUT_OUTPUT || 1
			color.rgb = saturate(color.rgb); // Remove any non SDR color, this mode is just meant for debugging SDR in HDR
#endif
			const float paperWhite = HdrDllPluginConstants.HDRGamePaperWhiteNits / WhiteNits_sRGB;
			color.rgb *= paperWhite;
		}
	}

	return color;
}
