#pragma once
#include "Offsets.h"
#include "Utils.h"
#include "DKUtil/Config.hpp"
#include "RE/Buffers.h"
#include "reshade/reshade.hpp"

#include <d3d12.h>

namespace Settings
{
    using namespace DKUtil::Alias;

    enum class SettingID : unsigned int
    {
		kSTART = 600,

        kDisplayMode,
        kHDR_PeakBrightness,
        kHDR_GamePaperWhite,
		kHDR_UIPaperWhite,
		kHDR_Saturation,
		kHDR_Contrast,
		kLUTCorrectionStrength,
		kColorGradingStrength,

		kEND,

		kDevSetting01,
		kDevSetting02,
		kDevSetting03,
		kDevSetting04,
		kDevSetting05,
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

	struct ShaderConstants
	{
		uint32_t DisplayMode;
		bool     bIsAtEndOfFrame;
		float    PeakBrightness;
		float    GamePaperWhite;
		float    UIPaperWhite;
		float    Saturation;
		float    Contrast;
		float    LUTCorrectionStrength;
		float    ColorGradingStrength;
		float    DevSetting01;
		float    DevSetting02;
		float    DevSetting03;
		float    DevSetting04;
		float    DevSetting05;
	};
	static inline uint32_t shaderConstantsSize = 14;

    class Main : public DKUtil::model::Singleton<Main>
    {
    public:
		Stepper DisplayMode{ SettingID::kDisplayMode, "Display Mode", "Sets the game's display mode between SDR (Gamma 2.2 Rec.709), HDR10 BT.2020 PQ, or HDR scRGB", { "DisplayMode", "Main" }, { "SDR", "HDR10", "HDR scRGB" } };

		Slider PeakBrightness{ SettingID::kHDR_PeakBrightness, "Peak Brightness", "Sets the peak nits brightness in HDR modes, this should match your display peak brightness", { "PeakBrightness", "HDR" }, 80.f, 10000.f, 1000.f };
		Slider GamePaperWhite{ SettingID::kHDR_GamePaperWhite, "Game Paper White", "Sets the game paper white nits brightness in HDR modes", { "GamePaperWhite", "HDR" }, 80.f, 500.f, 203.f };
		Slider UIPaperWhite{ SettingID::kHDR_UIPaperWhite, "UI Paper White", "Sets the UI paper white nits brightness in HDR modes", { "UIPaperWhite", "HDR" }, 80.f, 500.f, 203.f };
		Slider Saturation{ SettingID::kHDR_Saturation, "Saturation", "Sets the saturation strength in HDR modes (only applies if LUT correction is on) (neutral at 50)", { "Saturation", "HDR" }, 0.f, 100.f, 50.f };
		Slider Contrast{ SettingID::kHDR_Contrast, "Contrast", "Sets the contrast strength in HDR modes (neutral at 50)", { "Contrast", "HDR" }, 0.f, 100.f, 50.f };
		Slider LUTCorrectionStrength{ SettingID::kLUTCorrectionStrength, "LUT Correction Strength", "Sets the LUT correction (normalization) strength", { "LUTCorrectionStrength", "Main" }, 0.f, 100.f, 100.f };
		Slider ColorGradingStrength{ SettingID::kColorGradingStrength, "Color Grading Strength", "Sets the color grading strength (e.g. LUTs)", { "ColorGradingStrength", "Main" }, 0.f, 100.f, 100.f };
#if 1
		Slider DevSetting01{ SettingID::kDevSetting01, "DevSetting01", "Development setting", { "DevSetting01", "Dev" }, 0.f, 100.f, 0.f };
		Slider DevSetting02{ SettingID::kDevSetting02, "DevSetting02", "Development setting", { "DevSetting02", "Dev" }, 0.f, 100.f, 0.f };
		Slider DevSetting03{ SettingID::kDevSetting03, "DevSetting03", "Development setting", { "DevSetting03", "Dev" }, 0.f, 100.f, 0.f };
		Slider DevSetting04{ SettingID::kDevSetting04, "DevSetting04", "Development setting", { "DevSetting04", "Dev" }, 0.f, 100.f, 0.f };
		Slider DevSetting05{ SettingID::kDevSetting05, "DevSetting05", "Development setting", { "DevSetting05", "Dev" }, 0.f, 100.f, 0.f };
#endif
		String RenderTargetsToUpgrade{ "RenderTargetsToUpgrade", "RenderTargets" };

        bool IsHDREnabled() const;

		RE::BS_DXGI_FORMAT GetDisplayModeFormat() const;
        DXGI_COLOR_SPACE_TYPE GetDisplayModeColorSpaceType() const;

        void Load() noexcept;
		void Save() noexcept;

    private:
		TomlConfig config = COMPILE_PROXY("NativeHDR.toml"sv);
    };

	static inline RE::BGSSwapChainObject* swapChainObject = nullptr;

	// settings reshade overlay
	inline bool DrawReshadeStepper(Settings::Main* a_settings, Stepper& a_stepper)
    {
		int tempValue = *a_stepper.value;
		if (ImGui::SliderInt(a_stepper.name.c_str(), &tempValue, 0, a_stepper.optionNames.size() - 1, a_stepper.optionNames[tempValue].c_str(), ImGuiSliderFlags_NoInput)) {
		    *a_stepper.value = tempValue;
			a_settings->Save();
			return true;
		}
		return false;
    }

	inline bool DrawReshadeSlider(Settings::Main* a_settings, Slider& a_slider)
    {
		float tempValue = *a_slider.value;
		if (ImGui::SliderFloat(a_slider.name.c_str(), &tempValue, a_slider.sliderMin, a_slider.sliderMax, "%.0f")) {
		    *a_slider.value = tempValue;
			a_settings->Save();
			return true;
		}
		return false;
    }
	
	static void DrawSettingsReshade(reshade::api::effect_runtime*)
	{
		const auto settings = Settings::Main::GetSingleton();

		if (DrawReshadeStepper(settings, settings->DisplayMode)) {
			const RE::BS_DXGI_FORMAT newFormat = settings->GetDisplayModeFormat();

			Utils::SetBufferFormat(RE::Buffers::FrameBuffer, newFormat);
			swapChainObject->format = newFormat;

			// toggle vsync to force a swapchain recreation
			Offsets::ToggleVsync(reinterpret_cast<void*>(*Offsets::unkToggleVsyncArg1Ptr + 0x8), *Offsets::bEnableVsync);
		}
		DrawReshadeSlider(settings, settings->PeakBrightness);
		DrawReshadeSlider(settings, settings->GamePaperWhite);
		DrawReshadeSlider(settings, settings->UIPaperWhite);
		DrawReshadeSlider(settings, settings->Saturation);
		DrawReshadeSlider(settings, settings->Contrast);
		DrawReshadeSlider(settings, settings->LUTCorrectionStrength);
		DrawReshadeSlider(settings, settings->ColorGradingStrength);
#if 1
		DrawReshadeSlider(settings, settings->DevSetting01);
		DrawReshadeSlider(settings, settings->DevSetting02);
		DrawReshadeSlider(settings, settings->DevSetting03);
		DrawReshadeSlider(settings, settings->DevSetting04);
		DrawReshadeSlider(settings, settings->DevSetting05);
#endif
	}

	static inline bool bReshadeSettingsOverlayRegistered = false;

	static void RegisterReshadeOverlay()
	{
		if (!bReshadeSettingsOverlayRegistered) {
			HMODULE hModule = nullptr;
			GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, reinterpret_cast<LPCWSTR>(Main::GetSingleton()), &hModule);
			if (hModule) {
				if (reshade::register_addon(hModule)) {
					reshade::register_overlay("NativeHDR Settings", &DrawSettingsReshade);
					bReshadeSettingsOverlayRegistered = true;
				}
			}
		}
	}
}
