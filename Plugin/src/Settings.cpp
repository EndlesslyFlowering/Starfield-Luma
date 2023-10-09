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

    void Main::GetShaderConstants(ShaderConstants& a_outShaderConstants) const
    {
		a_outShaderConstants.DisplayMode = static_cast<uint32_t>(DisplayMode.value.get_data());
		a_outShaderConstants.PeakBrightness = static_cast<float>(PeakBrightness.value.get_data());
		a_outShaderConstants.GamePaperWhite = static_cast<float>(GamePaperWhite.value.get_data());
		a_outShaderConstants.UIPaperWhite = static_cast<float>(UIPaperWhite.value.get_data());
		a_outShaderConstants.Saturation = static_cast<float>(Saturation.value.get_data() * 0.02f);                        // 0-100 to 0-2
		a_outShaderConstants.Contrast = static_cast<float>(Contrast.value.get_data() * 0.02f);                            // 0-100 to 0-2
		a_outShaderConstants.LUTCorrectionStrength = static_cast<float>(LUTCorrectionStrength.value.get_data() * 0.01f);  // 0-100 to 0-1
		a_outShaderConstants.ColorGradingStrength = static_cast<float>(ColorGradingStrength.value.get_data() * 0.01f);    // 0-100 to 0-1
		a_outShaderConstants.FilmGrainType = static_cast<uint32_t>(FilmGrainType.value.get_data());
		a_outShaderConstants.PostSharpen = static_cast<uint32_t>(PostSharpen.value.get_data());
		a_outShaderConstants.bIsAtEndOfFrame = static_cast<uint32_t>(bIsAtEndOfFrame.load());
		a_outShaderConstants.DeltaTime = *Offsets::g_deltaTimeRealTime;
		a_outShaderConstants.DevSetting01 = static_cast<float>(DevSetting01.value.get_data() * 0.01f);  // 0-100 to 0-1
		a_outShaderConstants.DevSetting02 = static_cast<float>(DevSetting02.value.get_data() * 0.01f);  // 0-100 to 0-1
		a_outShaderConstants.DevSetting03 = static_cast<float>(DevSetting03.value.get_data() * 0.01f);  // 0-100 to 0-1
		a_outShaderConstants.DevSetting04 = static_cast<float>(DevSetting04.value.get_data() * 0.01f);  // 0-100 to 0-1
		a_outShaderConstants.DevSetting05 = static_cast<float>(DevSetting05.value.get_data() * 0.01f);  // 0-100 to 0-1
    }

    void Main::Load() noexcept
	{
		static std::once_flag ConfigInit;
		std::call_once(ConfigInit, [&]() {
			config.Bind(DisplayMode.value, DisplayMode.defaultValue);
			config.Bind(PeakBrightness.value, PeakBrightness.defaultValue);
			config.Bind(GamePaperWhite.value, GamePaperWhite.defaultValue);
			config.Bind(UIPaperWhite.value, UIPaperWhite.defaultValue);
			config.Bind(Saturation.value, Saturation.defaultValue);
			config.Bind(Contrast.value, Contrast.defaultValue);
			config.Bind(LUTCorrectionStrength.value, LUTCorrectionStrength.defaultValue);
			config.Bind(ColorGradingStrength.value, ColorGradingStrength.defaultValue);
			config.Bind(VanillaMenuLUTs.value, VanillaMenuLUTs.defaultValue);
			config.Bind(FilmGrainType.value, FilmGrainType.defaultValue);
			config.Bind(PostSharpen.value, PostSharpen.defaultValue);
			config.Bind(DevSetting01.value, DevSetting01.defaultValue);
			config.Bind(DevSetting02.value, DevSetting02.defaultValue);
			config.Bind(DevSetting03.value, DevSetting03.defaultValue);
			config.Bind(DevSetting04.value, DevSetting04.defaultValue);
			config.Bind(DevSetting05.value, DevSetting05.defaultValue);
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
				"ImageSpaceBufferR10G10B10A2"
				//"NativeResolutionColorBuffer01",  // issues on AMD
				//"ColorBuffer01"
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
