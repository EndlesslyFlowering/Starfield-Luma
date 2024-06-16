#include "../shared.hlsl"
#include "../color.hlsl"
#include "RootSignature.hlsl"

// This is defined by Luma and Shader Injector code, we can't directly change it in the shader
#define USE_REPLACED_COMPOSITION 1
#define OPTIMIZE_REPLACED_COMPOSITION_BLENDS (FORCE_VANILLA_LOOK ? 0 : 0)
#define CLIP_HDR_UI 0
#define CLIP_HDR_BACKGROUND 0
// 0) Raw linear blend instead of sRGB gamma blend (looks very different from Vanilla).
// 1) Apply pow on blend alpha (luminance based). Looks better than linear blends, though results vary on the background brightness.
// 2) DEPRECATED: Apply pow on blend alpha (percentage based).
// 3) Pre-blend against mid gray (alpha based): attempts to pre-blend with a mid gray background to better predict the color shift from sRGB gamma blends.
//    This generally looks best and closest to sRGB gamma blends, though results vary on the background brightness.
// 4) DEPRECATED: Pre-blend against mid gray (rgb based).
#define OPTIMIZED_REPLACED_COMPOSITION_BLENDS_TYPE 3
// Hack: change the alpha value at which the UI blends in in HDR, to increase readability. Range is 0 to 1, with 1 having no effect.
// We found the best value empirically and it seems to match gamma 2.2.
// Note that this make the look more towards SDR sRGB gamma blends when the background is white and the UI is dark,
// but in the opposite case, it will have the inverse effect (or something like that).
#define HDR_UI_BLEND_POW (1.f / 2.2f)
// Let's only correct up to a percentage to avoid corrections in the other direction
// (e.g. the game sometimes forgets some UI widgets in the view that had a very low alpha,
// and without or alpha pow modifications, it becomes much more noticeable).
#define HDR_UI_BLEND_POW_ALPHA 0.5f

// Note: we ignore "HdrDllPluginConstants.GammaCorrection" here, as we fully rely on "SDR_USE_GAMMA_2_2"
// Note: "ApplyGammaBelowZeroDefault" doesn't really matter here as the UI should only have positive scRGB values
#if SDR_USE_GAMMA_2_2 // NOTE: these gamma formulas should use their mirrored versions in the CLAMP_INPUT_OUTPUT_TYPE < 3 case
	#define GAMMA_TO_LINEAR(x) gamma_to_linear_mirrored(x, 2.2f)
	#define LINEAR_TO_GAMMA(x) linear_to_gamma_mirrored(x, 2.2f)
#else
	#define GAMMA_TO_LINEAR(x) gamma_sRGB_to_linear(x)
	#define LINEAR_TO_GAMMA(x) gamma_linear_to_sRGB(x)
#endif

struct PushConstantWrapper_ScaleformCompositeLayout
{
	float UIIntensity; // 1.0f always (it's not the "HUD Opacity" setting, that's pre-applied in the buffer)
	float UIBrightness; // Seemengly unused (it's not the same brightness as the one for the tonemapper)
	float UIContrast; // Seemengly unused (it's not the same contrast as the one for the tonemapper)
};

ConstantBuffer<PushConstantWrapper_ScaleformCompositeLayout> ScaleformCompositeLayout : register(b0);

Texture2D<float4> UITexture : register(t0, space8);
SamplerState UISampler : register(s0, space8);
#if USE_REPLACED_COMPOSITION
RWTexture2D<float4> FinalColorTexture : register(u0, space8);
#endif // USE_REPLACED_COMPOSITION

struct PSInputs
{
	float4 uv : TEXCOORD0;
	float4 pos : SV_Position;
};

[RootSignature(ShaderRootSignature)]
float4 PS(PSInputs psInputs) : SV_Target
{
	// The UI is always stored in gamma space, even if we might be using FP textures for it
	float4 UIColor = UITexture.Sample(UISampler, psInputs.uv.xy);

	// NOTE: any kind of modulation we do on the UI might not be acknowledged by DLSS FG or FSR FG,
	// as it has a copy of the UI buffer that it uses to determine how much to reconstruct pixels.

#if CLIP_HDR_UI
	// We do a saturate because the original UI texture was a INT/UNORM so it couldn't have had values beyond 0-1. And this also avoids negatives powers in the code below.
	// It's possible that skipping this clipping would allow some "HDR" UI to come through, due to usage of pre-multiplied alpha.
	UIColor = saturate(UIColor);
#else
	UIColor.a = saturate(UIColor.a);
#endif // CLIP_HDR_UI

	// This multiplication is probably used by Bethesda to dim the UI when applying an AutoHDR pass at the very end (they don't have real HDR).
	// We do it in gamma space to maintain the expected intensity change (it doesn't cause hue shift, as one might think).
	UIColor.rgb *= ScaleformCompositeLayout.UIIntensity;

	// Theoretically all UI would be in sRGB though it seems like it was designed on gamma 2.2 screens, and even if it wasn't, that's how it looks in the game
	const float3 UIColorGammaSpace = UIColor.rgb;
	UIColor.rgb = GAMMA_TO_LINEAR(UIColor.rgb);

	const bool isHDR = HdrDllPluginConstants.DisplayMode > 0;
	bool isLinear = true;
	float LinearUIPaperWhite = 1.f;

#if !SDR_LINEAR_INTERMEDIARY
	if (isHDR)
#endif // SDR_LINEAR_INTERMEDIARY
	{
		LinearUIPaperWhite = isHDR ? (HdrDllPluginConstants.HDRUIPaperWhiteNits / WhiteNits_sRGB) : 1.f;

#if !USE_REPLACED_COMPOSITION || OPTIMIZE_REPLACED_COMPOSITION_BLENDS

#if OPTIMIZED_REPLACED_COMPOSITION_BLENDS_TYPE == 1 || OPTIMIZED_REPLACED_COMPOSITION_BLENDS_TYPE == 2

		// Scale alpha to emulate sRGB gamma blending (we blend in linear space in HDR),
		// this won't ever be perfect but it's close enough for most cases.
		float HDRUIBlendPow = HDR_UI_BLEND_POW;
#if OPTIMIZED_REPLACED_COMPOSITION_BLENDS_TYPE == 2
		HDRUIBlendPow = lerp(1.f, HDRUIBlendPow, HDR_UI_BLEND_POW_ALPHA);
#else // OPTIMIZED_REPLACED_COMPOSITION_BLENDS_TYPE == 1
		// Base the alpha pow application percentage on the color luminance.
		// Generally speaking dark colors (with a low alpha) are meant as darkneing (transparent) backgrounds,
		// while brighter/whiter colors are meant to replace the background color directly (opaque),
		// so we could take that into account to avoid cases where the alpha pow would make stuff look worse.
		HDRUIBlendPow = lerp(HDRUIBlendPow, 1.f, saturate(LINEAR_TO_GAMMA(Luminance(UIColor.xyz))));
#endif // OPTIMIZED_REPLACED_COMPOSITION_BLENDS_TYPE == 1
		UIColor.a = pow(UIColor.a, HDRUIBlendPow);
		
#else // OPTIMIZED_REPLACED_COMPOSITION_BLENDS_TYPE == 3 || OPTIMIZED_REPLACED_COMPOSITION_BLENDS_TYPE == 4

		// Blend in in gamma space with the average color of the background (guessed to be 0.5, even if it's likely a lot lower than that, and finding the actual average pixel brightness of the game could yield better results),
		// then, with the pre-multiplied alpha inverse formula, find the new UI color with the average gamma space "offset" baked into it.
		static const float MidGrayBackgroundColorGammaSpace = 0.5f;
		static const float MidGrayBackgroundColorLinearSpace = GAMMA_TO_LINEAR(MidGrayBackgroundColorGammaSpace);
		const float3 averageGammaBlendColor = GAMMA_TO_LINEAR(UIColorGammaSpace + (MidGrayBackgroundColorGammaSpace * (1.f - UIColor.a)));
#if 0 // Unused
		const float3 averageLinearBlendColor = UIColor.rgb + (MidGrayBackgroundColorLinearSpace * (1.f - UIColor.a));
#endif
// Find the matching alpha (theoretically less correct but it looks better)
#if OPTIMIZED_REPLACED_COMPOSITION_BLENDS_TYPE == 3
		// Note: for now we let it possibly go < 0, as theoretically it's more accurate (I don't know if it can even happen, but probably not as it ends up adding alpha, not removing it)
		UIColor.a = -((average(averageGammaBlendColor - UIColor.rgb) / MidGrayBackgroundColorLinearSpace) - 1.f);
// Find the matching rgb color (theoretically more correct but it seems to cause issues with alpha blending, probably because rgb values go below 0)
#else // OPTIMIZED_REPLACED_COMPOSITION_BLENDS_TYPE == 4
		UIColor.rgb = averageGammaBlendColor - (MidGrayBackgroundColorLinearSpace * (1.f - UIColor.a));
#endif // OPTIMIZED_REPLACED_COMPOSITION_BLENDS_TYPE == 4

#endif // OPTIMIZED_REPLACED_COMPOSITION_BLENDS_TYPE == 3 || OPTIMIZED_REPLACED_COMPOSITION_BLENDS_TYPE == 4

#endif // !USE_REPLACED_COMPOSITION || OPTIMIZE_REPLACED_COMPOSITION_BLENDS
	}
#if !SDR_LINEAR_INTERMEDIARY
	else
	{
		UIColor.rgb = LINEAR_TO_GAMMA(UIColor.rgb);
		isLinear = false;
	}
#endif // SDR_LINEAR_INTERMEDIARY

#if USE_REPLACED_COMPOSITION
	if (all(UIColor == 0.f)) // UI will have no influence at all in this case, skip all the conversions and writes
	{
		discard;
		return 0;
	}
	// This is always in linear unless "SDR_LINEAR_INTERMEDIARY" was false and we were in SDR
	const float3 backgroundColor = FinalColorTexture[psInputs.pos.xy].rgb;
	float3 outputColor;
#if !OPTIMIZE_REPLACED_COMPOSITION_BLENDS
	// Do this even if "UIColor.a" is 1, as we still need to tonemap the HDR background
	if (isLinear)
	{
		float GamePaperWhite;

		if (isHDR)
		{
			GamePaperWhite = HdrDllPluginConstants.HDRGamePaperWhiteNits / WhiteNits_sRGB;
		}
		else
		{
			GamePaperWhite = 1.f;
		}

		// 1) Emulate SDR gamma space blends:

		const float3 normalizedBackgroundColor = backgroundColor / GamePaperWhite;
		const float3 SDRBackgroundColor = saturate(normalizedBackgroundColor);
		const float3 excessBackgroundColor = (normalizedBackgroundColor - SDRBackgroundColor) * GamePaperWhite;

		const float3 UIColorGammaSpace = LINEAR_TO_GAMMA(UIColor.rgb);
		const float3 SDRBackgroundColorGammaSpace = LINEAR_TO_GAMMA(SDRBackgroundColor);
		const float3 darkenedSDRBackgroundColorGammaSpace = SDRBackgroundColorGammaSpace * (1.f - UIColor.a); // Pre-multiply alpha on the background
		outputColor = GAMMA_TO_LINEAR(UIColorGammaSpace + darkenedSDRBackgroundColorGammaSpace);

		// 2) Restore the paper white multipliers:

		// Find out how much the UI has changed the non darkened background color (in gamma space to keep ratios the same).
		float3 UIInfluence = select(SDRBackgroundColorGammaSpace == 0.f, 1.f, 1.f - (SDRBackgroundColorGammaSpace / (UIColorGammaSpace + SDRBackgroundColorGammaSpace)));
		// Lerp the UI influence to 1 if the UI alpha is higher, as that means the background had been darkened by that amount, and thus had reduced influence in the final color.
		UIInfluence = lerp(UIInfluence, 1.f, UIColor.a);
		outputColor *= lerp(GamePaperWhite, LinearUIPaperWhite, UIInfluence);

		// 3) Then add any color in excess in linear space, as there's no other way really:

		// Apply the Reinhard tonemapper on any background color in excess, to avoid it burning it through the UI.
		// NOTE: If this is not enough we could already apply to the entire "backgroundColor" before blending it with the UI.
		float3 tonemappedBackgroundColor = excessBackgroundColor / (1.f + abs(excessBackgroundColor));
		// In SDR, we clip any HDR color passing through the UI, as long as the UI has ANY kind of influence on the output.
		// The reason is that the game wouldn't have ever had any colors beyond 0-1 due to having int UNORM textures, so we want to replicate the same look.
		tonemappedBackgroundColor *= isHDR ? 1.f : 0.f;
#if CLIP_HDR_BACKGROUND // If backgrounds were ever too bright, we can just clip them
		tonemappedBackgroundColor = 0.f;
#endif // !CLIP_HDR_BACKGROUND
		outputColor += lerp(tonemappedBackgroundColor, excessBackgroundColor, 1.f - UIColor.a) * (1.f - UIColor.a);
	}
	else
#endif // !OPTIMIZE_REPLACED_COMPOSITION_BLENDS
	{
		// Pre-multiplied alpha formula
		outputColor = (UIColor.rgb * LinearUIPaperWhite) + (backgroundColor * (1.f - UIColor.a));
	}

	FinalColorTexture[psInputs.pos.xy].rgb = outputColor;

	// The Luma plugin binds a null render target on the engine side. All writes beyond this point are discarded regardless
	// of whether a "discard" statement is used.
	discard;
	return 0.f;
#else // USE_REPLACED_COMPOSITION
	return UIColor;
#endif // USE_REPLACED_COMPOSITION
}
