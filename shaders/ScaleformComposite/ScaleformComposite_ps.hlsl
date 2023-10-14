#include "../shared.hlsl"
#include "../color.hlsl"
#include "RootSignature.hlsl"

// Hack: change the alpha value at which the UI blends in in HDR, to increase readability. Range is 0 to 1, with 1 having no effect.
// We found the best value empirically and it seems to match gamma 2.2.
// Note that this make the look more towards SDR sRGB gamma blends when the background is white and the UI is dark,
// but in the opposite case, it will have the inverse effect (or something like that).
#define HDR_UI_BLEND_POW (1.f / 2.2f)
// Let's only correct up to a percentage to avoid corrections in the other direction
// (e.g. the game sometimes forgets some UI widgets in the view that had a very low alpha,
// and without or alpha pow modifications, it becomes much more noticeable).
#define HDR_UI_BLEND_POW_ALPHA 0.5f

struct PushConstantWrapper_ScaleformCompositeLayout
{
	int Unknown1;
	int Unknown2;
};

cbuffer stub_PushConstantWrapper_ScaleformCompositeLayout : register(b0)
{
	PushConstantWrapper_ScaleformCompositeLayout Layout : packoffset(c0);
};

Texture2D<float4> inputTexture : register(t0, space8);
SamplerState inputSampler : register(s0, space8);

struct PSInputs
{
	float4 uv : TEXCOORD0;
	float4 pos : SV_Position;
};

[RootSignature(ShaderRootSignature)]
float4 PS(PSInputs inputs) : SV_Target
{
	float4 UIColor = inputTexture.Sample(inputSampler, float2(inputs.uv.x, inputs.uv.y));
	float UIIntensity = asfloat(Layout.Unknown1);

	// NOTE: any kind of modulation we do on the UI might not be acknowledged by DLSS FG,
	// as it has a copy of the UI buffer 

	// Theoretically all UI is in sRGB (though it might have been designed on gamma 2.2 screens, we can't know that, but it was definately targeting gamma 2.2 as output anyway).
	UIColor.xyz = gamma_sRGB_to_linear(UIColor.xyz);
	// This multiplication is probably used by Bethesda to dim the UI when applying an AutoHDR pass at the very end (they don't have real HDR)
	UIColor.xyz = UIColor.xyz * UIIntensity;
#if !SDR_LINEAR_INTERMEDIARY
	if (HdrDllPluginConstants.DisplayMode > 0)
#endif // SDR_LINEAR_INTERMEDIARY
	{
#if SDR_USE_GAMMA_2_2
		UIColor.xyz = pow(gamma_linear_to_sRGB(UIColor.xyz), 2.2f);
#endif // SDR_USE_GAMMA_2_2
		UIColor.xyz *= HdrDllPluginConstants.DisplayMode > 0 ? (HdrDllPluginConstants.HDRUIPaperWhiteNits / WhiteNits_sRGB) : 1.f;
		// Scale alpha to emulate sRGB gamma blending (we blend in linear space in HDR),
		// this won't ever be perfect but it's close enough for most cases.
#if DEVELOPMENT && 0 // Quick testing
		const float HDRUIBlendPow = 1.f - HdrDllPluginConstants.DevSetting02;
#elif 1
		// Base the alpha pow application percentage on the color luminance.
		// Generally speaking dark colors (with a low alpha) are meant as darkneing (transparent) backgrounds,
		// while brighter/whiter colors are meant to replace the background color directly (opaque),
		// so we could take that into account to avoid cases where the alpha pow would make stuff look worse.
		const float HDRUIBlendPow = lerp(HDR_UI_BLEND_POW, 1.f, saturate(Luminance(UIColor.xyz)));
#else
		const float HDRUIBlendPow = lerp(1.f, HDR_UI_BLEND_POW, HDR_UI_BLEND_POW_ALPHA);
#endif
		// We do a saturate to avoid pow of -0, which might lead to unexpected results.
		UIColor.a = pow(saturate(UIColor.a), HDRUIBlendPow);
	}
#if !SDR_LINEAR_INTERMEDIARY
	else // in SDR, output the UI as it was, independently of "SDR_USE_GAMMA_2_2", there's no need to ever adjust it really
	{
		UIColor.xyz = gamma_linear_to_sRGB(UIColor.xyz);
	}
#endif // SDR_LINEAR_INTERMEDIARY

	return UIColor;
}
