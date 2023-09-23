#include "Settings.h"

namespace Settings
{
	void Main::Load() noexcept
	{
		static std::once_flag ConfigInit;
		std::call_once(ConfigInit, [&]() {
			config.Bind(ImageSpaceBufferFormat, 0);
			config.Bind(UpgradeUIRenderTarget, true);
			config.Bind(UpgradeRenderTargets, 2);
			config.Bind(FrameBufferFormat, 0);
			config.Bind(RenderTargetsToUpgrade, "SF_ColorBuffer", "HDRImagespaceBuffer", "ImageSpaceHalfResBuffer", "ImageProcessColorTarget", "ImageSpaceBufferB10G11R11", "ImageSpaceBufferE5B9G9R9", "TAA_idTech7HistoryColorTarget", "EnvBRDF", "GBuffer_Normal_EmissiveIntensity", "ImageSpaceBufferR10G10B10A2");
		});

		config.Load();

		INFO("Config loaded"sv)
	}
}