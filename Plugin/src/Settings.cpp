#include "Settings.h"

namespace Settings
{
    float Slider::GetSliderPercentage() const
    {
		return (value.get_data() - sliderMin) / (sliderMax - sliderMin);
    }

    std::string Slider::GetSliderText() const
    {
		return std::format("{}", value.get_data());
    }

    float Slider::GetValueFromSlider(float a_percentage) const
    {
		return std::roundf(a_percentage * (sliderMax - sliderMin) + sliderMin);
    }

    void Slider::SetValueFromSlider(float a_percentage)
    {
        *value = GetValueFromSlider(a_percentage);
    }

    bool Main::IsHDREnabled() const
    {
		return DisplayMode.value.get_data() != 0;
    }

    RE::BS_DXGI_FORMAT Main::GetDisplayModeFormat() const
    {
		switch (DisplayMode.value.get_data()) {
		case 0:
		case 1:
		default:
			return RE::BS_DXGI_FORMAT::BS_DXGI_FORMAT_R10G10B10A2_UNORM;
		case 2:
			return RE::BS_DXGI_FORMAT::BS_DXGI_FORMAT_R16G16B16A16_FLOAT;
		}
    }

    DXGI_COLOR_SPACE_TYPE Main::GetDisplayModeColorSpaceType() const
    {
		switch (DisplayMode.value.get_data()) {
		case 0:
		default:
			return DXGI_COLOR_SPACE_RGB_FULL_G22_NONE_P709;
		case 1:
			return DXGI_COLOR_SPACE_RGB_FULL_G2084_NONE_P2020;
		case 2:
			return DXGI_COLOR_SPACE_RGB_FULL_G10_NONE_P709;
		}
    }

    void Main::Load() noexcept
	{
		static std::once_flag ConfigInit;
		std::call_once(ConfigInit, [&]() {
			config.Bind(DisplayMode.value, 0);
			config.Bind(PeakBrightness.value, PeakBrightness.defaultValue);
			config.Bind(GamePaperWhite.value, GamePaperWhite.defaultValue);
			config.Bind(UIPaperWhite.value, UIPaperWhite.defaultValue);
			config.Bind(Saturation.value, Saturation.defaultValue);
			config.Bind(Contrast.value, Contrast.defaultValue);
			config.Bind(LUTCorrectionStrength.value, LUTCorrectionStrength.defaultValue);
			config.Bind(ColorGradingStrength.value, ColorGradingStrength.defaultValue);
			config.Bind(DevSetting01.value, DevSetting01.defaultValue);
			config.Bind(DevSetting02.value, DevSetting02.defaultValue);
			config.Bind(RenderTargetsToUpgrade,
			    "ImageSpaceBuffer",
				"ScaleformCompositeBuffer",
				"SF_ColorBuffer",
				"HDRImagespaceBuffer",
				"ImageSpaceHalfResBuffer",
				"ImageProcessColorTarget",
				"ImageSpaceBufferB10G11R11",
				"ImageSpaceBufferE5B9G9R9",
				"TAA_idTech7HistoryColorTarget",
				"EnvBRDF",
				"ImageSpaceBufferR10G10B10A2",
#if 0
				'NativeResolutionColorBuffer01',
				'ColorBuffer01'
#endif
				);
		});

		config.Load();

		INFO("Config loaded"sv)
	}

    void Main::Save() noexcept
    {
		config.Generate();
		config.Write();
    }
}
