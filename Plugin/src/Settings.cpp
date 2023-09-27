#include "Settings.h"

namespace Settings
{
    bool Main::IsHDREnabled() const
    {
		return FrameBufferFormat.get_data() != 0;
    }

    float Main::GetMaxLuminanceSliderPercentage() const
    {
		return (MaxLuminance.get_data() - luminanceSliderMin) / (luminanceSliderMax - luminanceSliderMin);
    }

    std::string Main::GetMaxLuminanceText() const
    {
		return std::format("{}", MaxLuminance.get_data());
    }

    float Main::GetMaxLuminanceFromSlider(float a_percentage) const
    {
		return std::roundf(a_percentage * (luminanceSliderMax - luminanceSliderMin) + luminanceSliderMin);
    }

    void Main::SetMaxLuminanceFromSlider(float a_percentage)
    {
		*MaxLuminance = GetMaxLuminanceFromSlider(a_percentage);
    }

    float Main::GetPaperwhiteSliderPercentage() const
    {
		return (Paperwhite.get_data() - paperwhiteSliderMin) / (paperwhiteSliderMax - paperwhiteSliderMin);
    }

    std::string Main::GetPaperwhiteText() const
    {
		return std::format("{}", Paperwhite.get_data());
    }

    float Main::GetPaperwhiteFromSlider(float a_percentage) const
    {
		return std::roundf(a_percentage * (paperwhiteSliderMax - paperwhiteSliderMin) + paperwhiteSliderMin);
    }

    void Main::SetPaperwhiteFromSlider(float a_percentage)
    {
		*Paperwhite = GetPaperwhiteFromSlider(a_percentage);
    }

    void Main::Load() noexcept
	{
		static std::once_flag ConfigInit;
		std::call_once(ConfigInit, [&]() {
			config.Bind(ImageSpaceBufferFormat, 0);
			config.Bind(UpgradeUIRenderTarget, true);
			config.Bind(UpgradeRenderTargets, 2);
			config.Bind(FrameBufferFormat, 0);
			config.Bind(MaxLuminance, 1000.f);
			config.Bind(Paperwhite, 200.f);
			config.Bind(RenderTargetsToUpgrade, "SF_ColorBuffer", "HDRImagespaceBuffer", "ImageSpaceHalfResBuffer", "ImageProcessColorTarget", "ImageSpaceBufferB10G11R11", "ImageSpaceBufferE5B9G9R9", "TAA_idTech7HistoryColorTarget", "EnvBRDF", "GBuffer_Normal_EmissiveIntensity", "ImageSpaceBufferR10G10B10A2");
		});

		config.Load();

		INFO("Config loaded"sv)
	}
}