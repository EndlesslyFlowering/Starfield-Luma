Texture2D<float4> r_currBB : register(t0, space0);
Texture2D<float4> r_uiTexture : register(t1, space0);

// https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/blob/be99c36a76fb6a09999dd6150f1fedc14d755182/sdk/src/backends/dx12/FrameInterpolationSwapchain/FrameInterpolationSwapchainUiComposition.hlsl
float4 main(float4 vPosition : SV_POSITION) : SV_Target
{
	uint2 pixelCoords = uint2(vPosition.xy);
	float3 backgroundColor = r_currBB.Load(uint3(pixelCoords, 0u)).rgb;
	float4 UIColor = r_uiTexture.Load(int3(pixelCoords, 0u));

	// We can't know exactly what settings the user used, the best we can do is assume default.
	// This will bring the UI and background in the same color space and white level.
	// We assume the swapchain is running in scRGB HDR mode.
	// All values are hardcoded because we don't have access to the rest of the hlsl shaders code base.
	backgroundColor *= 80.f / 203.f;
	float3 gammaBackgroundColor = pow(abs(backgroundColor), 1.f / 2.2f) * sign(backgroundColor);
	
	// The UI was pre-multiplied by its own alpha
	float invertedAlpha = 1.0f - UIColor.a;
	float3 blendedColor = (invertedAlpha * gammaBackgroundColor.rgb) + UIColor.rgb;
	float3 linearBlendedColor = pow(abs(blendedColor), 2.2f) * sign(blendedColor);
	linearBlendedColor *= 203.f / 80.f;

	return float4(linearBlendedColor, 1.f);
}