#include "../color.hlsl"

Texture2D<float4> r_currBB : register(t0, space0);
Texture2D<float4> r_uiTexture : register(t1, space0);

// 0 SDR
// 1 HDR10
// 2 scRGB HDR
#ifndef OUTPUT_ENCODING
#define OUTPUT_ENCODING 1
#endif // OUTPUT_ENCODING

// https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/blob/be99c36a76fb6a09999dd6150f1fedc14d755182/sdk/src/backends/dx12/FrameInterpolationSwapchain/FrameInterpolationSwapchainUiComposition.hlsl
float4 main(float4 vPosition : SV_POSITION) : SV_Target
{
	uint2 pixelCoords = uint2(vPosition.xy);
	float3 backgroundColor = r_currBB.Load(uint3(pixelCoords, 0u)).rgb;
	float4 UIColor = r_uiTexture.Load(int3(pixelCoords, 0u));

	bool hdr = false;
#if OUTPUT_ENCODING > 0
	hdr = true;
#endif

	// We can't know exactly what settings the user used, the best we can do is assume default.
	// This will bring the UI and background in the same color space and white level.
	// All values are hardcoded because we don't have access to the rest of the hlsl shaders code base.
	const float hdrPaperWhite = 203.f / 80.f;

	float3 gammaBackgroundColor = backgroundColor;
	if (hdr)
	{
#if OUTPUT_ENCODING == 1
		backgroundColor = PQ_to_Linear(backgroundColor, PQMaxWhitePoint);
		backgroundColor = BT2020_To_BT709(backgroundColor);
#endif
		backgroundColor /= hdrPaperWhite;
		gammaBackgroundColor = pow(abs(backgroundColor), 1.f / 2.2f) * sign(backgroundColor);
	}
	
	// The UI was pre-multiplied by its own alpha
	float invertedAlpha = 1.0f - UIColor.a;
	// Blend in SDR gamma space like vanilla
	float3 blendedColor = (invertedAlpha * gammaBackgroundColor.rgb) + UIColor.rgb;

	if (hdr)
	{
		blendedColor = pow(abs(blendedColor), 2.2f) * sign(blendedColor);
		blendedColor *= hdrPaperWhite;

#if OUTPUT_ENCODING == 1
		blendedColor = BT709_To_BT2020(blendedColor);
		blendedColor = Linear_to_PQ(blendedColor, PQMaxWhitePoint);
#endif
	}

	return float4(blendedColor, 1.f);
}
