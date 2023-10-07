#include "../shared.hlsl"
#include "../color.hlsl"
#include "RootSignature.hlsl"

Texture2D<float> TexY  : register(t0, space8);
Texture2D<float> TexCb : register(t2, space8);
Texture2D<float> TexCr : register(t1, space8);

SamplerState Sampler0 : register(s0, space8);

struct PSInputs
{
	float4 pos : SV_Position;
	float2 TEXCOORD : TEXCOORD0;
};

[RootSignature(ShaderRootSignature)]
float4 PS(PSInputs inputs) : SV_Target
{
	float Y = TexY.Sample(Sampler0, inputs.TEXCOORD.xy).x;
	float Cb = TexCb.Sample(Sampler0, inputs.TEXCOORD.xy).x;
	float Cr = TexCr.Sample(Sampler0, inputs.TEXCOORD.xy).x;

	float3 color;
	// usually in YCbCr the ranges are (in float):
	// Y:   0.0-1.0
	// Cb: -0.5-0.5
	// Cr: -0.5-0.5
	// but since this is a digital signal (in unsinged 8bit: 0-255) it's now:
	// Y:  0.0-1.0
	// Cb: 0.0-1.0
	// Cr: 0.0-1.0
	// the formula adjusts for that but was for BT.601 limited range while the video is definitely BT.709 full range
	// matrix paramters have been adjusted for BT.709 full range
	color.r = Y - 0.790487825870513916015625f + (Cr * 1.574800014495849609375f);
	color.g = Y + 0.329009473323822021484375f - (Cb * 0.18732427060604095458984375f) - (Cr * 0.46812427043914794921875f);
	color.b = Y - 0.931438446044921875f       + (Cb * 1.85559999942779541015625f);

	// Clamp for safety as YCbCr<->RGB is not 100% accurate in float and can produce negative/invalid colors,
	// this breaks the UI pass if we are using R16G16B16A16F textures,
	// as UI blending produces invalid pixels if it's blended with an invalid color.
	color = max(color, 0.f);

#if ENABLE_HDR
#if SDR_USE_GAMMA_2_2
	color = pow(color, 2.2f);
#else
	color = gamma_sRGB_to_linear(color);
#endif
	//TODO: AutoHDR on movies???

	color *= HDR_GAME_PAPER_WHITE;
#endif // ENABLE_HDR

	return float4(color, 1.0f);
}
