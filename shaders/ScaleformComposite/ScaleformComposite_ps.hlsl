#include "../shared.hlsl"
#include "../color.hlsl"
#include "RootSignature.hlsl"

// Hack: change the alpha value at which the UI blends in in HDR, to increase readability. Range is 0 to 1, with 1 having no effect.
// We found the best value empirically and it seems to match gamma 2.2.
// Note that this make the look more towards SDR sRGB gamma blends when the background is white and the UI is dark, but in the opposite case, it will have the inverse effect (or something like that).
#define HDR_UI_BLEND_POW (1.f / 2.2f)

struct PushConstantWrapper_ScaleformCompositeLayout
{
	float UIIntensity; // 1.0f
	float Unknown2; // 2.4f
};

ConstantBuffer<PushConstantWrapper_ScaleformCompositeLayout> ScaleformCompositeLayout : register(b0);

Texture2D<float4> UITexture : register(t0, space8);
SamplerState UISampler : register(s0, space8);
RWTexture2D<float4> FinalColorTexture : register(u0, space8);

struct PSInputs
{
	float4 uv : TEXCOORD0;
	float4 pos : SV_Position;
};

[RootSignature(ShaderRootSignature)]
float4 PS(PSInputs psInputs) : SV_Target
{
	const float4 inputColor = FinalColorTexture[psInputs.pos.xy];
	float4 uiColor = UITexture.Sample(UISampler, psInputs.uv.xy);

	// Theoretically all UI is in sRGB (though it might have been designed on gamma 2.2 screens, we can't know that, but it was definately targeting gamma 2.2 as output anyway).
	uiColor.rgb = gamma_sRGB_to_linear(uiColor.rgb);

	// This multiplication is probably used by Bethesda to dim the UI when applying an AutoHDR pass at the very end (they don't have real HDR)
	uiColor.rgb *= ScaleformCompositeLayout.UIIntensity;

#if !SDR_LINEAR_INTERMEDIARY
	if (HdrDllPluginConstants.DisplayMode > 0)
#endif // SDR_LINEAR_INTERMEDIARY
	{
#if SDR_USE_GAMMA_2_2
		uiColor.rgb = pow(gamma_linear_to_sRGB(uiColor.rgb), 2.2f);
#endif // SDR_USE_GAMMA_2_2
		uiColor.rgb *= HdrDllPluginConstants.DisplayMode > 0 ? (HdrDllPluginConstants.HDRUIPaperWhiteNits / WhiteNits_sRGB) : 1.f;
		// Scale alpha to emulate sRGB gamma blending (we blend in linear space in HDR),
		// this won't ever be perfect but it's close enough for most cases.
		// We do a saturate to avoid pow of -0, which might lead to unexpected results.
#if DEVELOPMENT && 0
		const float HDRUIBlendPow = 1.f - HdrDllPluginConstants.DevSetting02;
#else
		const float HDRUIBlendPow = HDR_UI_BLEND_POW;
#endif
		uiColor.a = pow(saturate(uiColor.a), HDRUIBlendPow); //TODO: base the percentage of application of "HDR_UI_BLEND_POW" based on how black/dark the UI color is?
	}
#if !SDR_LINEAR_INTERMEDIARY
	else // in SDR, output the UI as it was, independently of "SDR_USE_GAMMA_2_2", there's no need to ever adjust it really
	{
		uiColor.rgb = gamma_linear_to_sRGB(uiColor.rgb);
	}
#endif // SDR_LINEAR_INTERMEDIARY

	// TODO: Incorrect blend formula
	FinalColorTexture[psInputs.pos.xy] = inputColor + float4(uiColor.rgb * uiColor.a, 0.f);

	// The Luma plugin binds a null render target on the engine side. All writes beyond this point are discarded regardless
	// of whether a "discard;" statement is used.
	discard;
	return float4(0.f, 0.f, 0.f, 0.f);
}
