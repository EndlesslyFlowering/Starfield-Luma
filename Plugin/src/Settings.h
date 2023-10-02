#pragma once
#include "DKUtil/Config.hpp"
#include "RE/Buffers.h"

#include <d3d12.h>

namespace Settings
{
    using namespace DKUtil::Alias;

    enum class SettingID : unsigned int
    {
        kDisplayMode = 600,
        kPeakBrightness,
        kGamePaperWhite,
		kUIPaperWhite
    };

	struct Setting
	{
		SettingID id;
	    std::string name;
		std::string description;
	};

	struct Checkbox : Setting
	{
	    Boolean value;
	};

	struct Stepper : Setting
	{
		Integer value;
		std::vector<std::string> optionNames;
	};

	struct Slider : Setting
	{
	    Double value;
		float sliderMin;
		float sliderMax;
		float defaultValue;

		float GetSliderPercentage() const;
		std::string GetSliderText() const;
		float GetValueFromSlider(float a_percentage) const;
		void SetValueFromSlider(float a_percentage);
	};

    class Main : public DKUtil::model::Singleton<Main>
    {
    public:
		Stepper DisplayMode{ SettingID::kDisplayMode, "Display Mode", "Sets the game's display mode between SDR, HDR10 PQ, or HDR scRGB", { "DisplayMode", "Main" }, { "SDR", "HDR10 PQ", "HDR scRGB" } };

		Slider PeakBrightness{ SettingID::kPeakBrightness, "Peak Brightness", "Sets the peak brightness in HDR modes", { "PeakBrightness", "HDR" }, 80.f, 10000.f, 1000.f };
		Slider GamePaperWhite{ SettingID::kGamePaperWhite, "Game Paper White", "Sets the game paper white brightness in HDR modes", { "GamePaperWhite", "HDR" }, 80.f, 500.f, 200.f };
		Slider UIPaperWhite{ SettingID::kUIPaperWhite, "UI Paper White", "Sets the UI paper white brightness in HDR modes", { "UIPaperWhite", "HDR" }, 80.f, 500.f, 200.f };

		String RenderTargetsToUpgrade{ "RenderTargetsToUpgrade", "RenderTargets" };

        bool IsHDREnabled() const;

		RE::BS_DXGI_FORMAT GetDisplayModeFormat() const;
        DXGI_COLOR_SPACE_TYPE GetDisplayModeColorSpaceType() const;

        void Load() noexcept;
		void Save() noexcept;

    private:
		TomlConfig config = COMPILE_PROXY("NativeHDR.toml"sv);
    };
}
