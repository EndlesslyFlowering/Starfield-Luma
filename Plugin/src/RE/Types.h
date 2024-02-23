#pragma once
#include "RE/BSFixedString.h"
#include "RE/Buffers.h"
#include "RE/MessageBoxData.h"

namespace RE
{
	enum class UpscalingTechnique : uint32_t
	{
		kNone = 1,
		kCAS = 2,
		kDLSS = 4,
		kFSR2 = 8,
		kFSR3 = 16,
		kXESS = 32
	};

	enum class FrameGenerationTech : uint32_t
	{
		kNone,
		kDLSSG,
		kFSR3
	};

	struct FfxDimensions2D
	{
		uint32_t width;
		uint32_t height;
	};

	struct FfxInterface
	{
		void* fpGetSDKVersion;
		void* fpCreateBackendContext;
		void* fpGetDeviceCapabilities;
		void* fpDestroyBackendContext;
		void* fpCreateResource;
		void* fpRegisterResource;
		void* fpGetResource;
		void* fpUnregisterResources;
		void* fpGetResourceDescription;
		void* fpDestroyResource;
		void* fpCreatePipeline;
		void* fpGetPermutationBlobByIndex;
		void* fpDestroyPipeline;
		void* fpScheduleGpuJob;
		void* fpExecuteGpuJobs;
		void* fpSwapChainConfigureFrameGeneration;

		void*  scratchBuffer;
		size_t scratchBufferSize;
		void*  device;
	};

	enum FfxSurfaceFormat
	{
		FFX_SURFACE_FORMAT_UNKNOWN,
		FFX_SURFACE_FORMAT_R32G32B32A32_TYPELESS,
		FFX_SURFACE_FORMAT_R32G32B32A32_UINT,
		FFX_SURFACE_FORMAT_R32G32B32A32_FLOAT,
		FFX_SURFACE_FORMAT_R16G16B16A16_FLOAT,
		FFX_SURFACE_FORMAT_R32G32_FLOAT,
		FFX_SURFACE_FORMAT_R8_UINT,
		FFX_SURFACE_FORMAT_R32_UINT,
		FFX_SURFACE_FORMAT_R10G10B10A2_UNORM,
		FFX_SURFACE_FORMAT_R8G8B8A8_TYPELESS,
		FFX_SURFACE_FORMAT_R8G8B8A8_UNORM,
		FFX_SURFACE_FORMAT_R8G8B8A8_SNORM,
		FFX_SURFACE_FORMAT_R8G8B8A8_SRGB,
		FFX_SURFACE_FORMAT_R11G11B10_FLOAT,
		FFX_SURFACE_FORMAT_R16G16_FLOAT,
		FFX_SURFACE_FORMAT_R16G16_UINT,
		FFX_SURFACE_FORMAT_R16G16_SINT,
		FFX_SURFACE_FORMAT_R16_FLOAT,
		FFX_SURFACE_FORMAT_R16_UINT,
		FFX_SURFACE_FORMAT_R16_UNORM,
		FFX_SURFACE_FORMAT_R16_SNORM,
		FFX_SURFACE_FORMAT_R8_UNORM,
		FFX_SURFACE_FORMAT_R8G8_UNORM,
		FFX_SURFACE_FORMAT_R8G8_UINT,
		FFX_SURFACE_FORMAT_R32_FLOAT
	};

	struct FfxFsr3ContextDescription
	{
		uint32_t        flags;
		FfxDimensions2D maxRenderSize;
		FfxDimensions2D upscaleOutputSize;
		FfxDimensions2D displaySize;
		FfxInterface    backendInterfaceSharedResources;
		FfxInterface    backendInterfaceUpscaling;
		FfxInterface    backendInterfaceFrameInterpolation;
		void*           fpMessage;

		FfxSurfaceFormat backBufferFormat;
	};
}
