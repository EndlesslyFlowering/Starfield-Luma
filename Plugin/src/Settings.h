#pragma once
#include "Offsets.h"
#include "DKUtil/Config.hpp"
#include "RE/Buffers.h"
#include "reshade/reshade.hpp"

#include <d3d12.h>

// TODO: set to false in release builds (use the build configuation to automatically define it)
#define DEVELOPMENT 1

namespace Settings
{
    using namespace DKUtil::Alias;

    enum class SettingID : unsigned int
    {
		kSTART = 600,

        kDisplayMode,
		kForceSDROnHDR,
        kHDR_PeakBrightness,
        kHDR_GamePaperWhite,
		kHDR_UIPaperWhite,
		kHDR_Contrast,
		kHDR_Saturation,
		kLUTCorrectionStrength,
		kColorGradingStrength,
		kGammaCorrectionStrength,
		kSecondaryBrightness,
        kVanillaMenuLUTs,
		kFilmGrainType,
		kPostSharpen,

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
		bool defaultValue;
	};

	struct Stepper : Setting
	{
		Integer value;
		int32_t defaultValue;

		Stepper(SettingID a_id, const std::string& a_name, const std::string& a_description, const std::string& a_key, const std::string& a_section, int32_t a_defaultValue) :
			Setting{ a_id, a_name, a_description }, value{ a_key, a_section }, defaultValue(a_defaultValue) {}

		virtual ~Stepper() = default;

		virtual std::string GetStepperText(int32_t a_value) const = 0;
		virtual int32_t GetNumOptions() const = 0;
		virtual int32_t GetValueFromStepper(int32_t a_value) const = 0;
		virtual int32_t GetCurrentStepFromValue() const = 0;
		virtual void SetValueFromStepper(int32_t a_value) = 0;
	};

	struct EnumStepper : Stepper
	{
		std::vector<std::string> optionNames;

		EnumStepper(SettingID a_id, const std::string& a_name, const std::string& a_description, const std::string& a_key, const std::string& a_section, int32_t a_defaultValue, const std::vector<std::string>& a_optionNames) :
			Stepper{ a_id, a_name, a_description, a_key, a_section, a_defaultValue }, optionNames(a_optionNames) {}

		std::string GetStepperText(int32_t a_value) const override;
		int32_t GetNumOptions() const override{ return optionNames.size(); }
		int32_t GetValueFromStepper(int32_t a_value) const override { return a_value; }
		int32_t GetCurrentStepFromValue() const override { return value.get_data(); }
		void SetValueFromStepper(int32_t a_value) override { *value = a_value; }
	};

	struct ValueStepper : Stepper
	{
	    int32_t minValue;
		int32_t maxValue;
		int32_t stepSize;

		ValueStepper(SettingID a_id, const std::string& a_name, const std::string& a_description, const std::string& a_key, const std::string& a_section, int32_t a_defaultValue, int32_t a_minValue, int32_t a_maxValue, int32_t a_stepSize) :
			Stepper{ a_id, a_name, a_description, a_key, a_section, a_defaultValue }, minValue(a_minValue), maxValue(a_maxValue), stepSize(a_stepSize) {}

		std::string GetStepperText(int32_t a_value) const override;
		int32_t GetNumOptions() const override { return (maxValue - minValue) / stepSize + 1; }
		int32_t GetValueFromStepper(int32_t a_value) const override { return a_value * stepSize + minValue; }
		int32_t GetCurrentStepFromValue() const override { return (value.get_data() - minValue) / stepSize; }
		void SetValueFromStepper(int32_t a_value) override { *value = GetValueFromStepper(a_value); }
	};

	struct Slider : Setting
	{
	    Double value;
		float  defaultValue;
		float sliderMin;
		float sliderMax;
		std::string suffix = "";

		float GetSliderPercentage() const;
		std::string GetSliderText() const;
		float GetValueFromSlider(float a_percentage) const;
		void SetValueFromSlider(float a_percentage);
	};

	// Has to match StructHdrDllPluginConstants in HLSL.
	// Bools are set as uint to avoid padding inconsistencies between c++ and hlsl.
	struct ShaderConstants
	{
		int32_t  DisplayMode;
		float    PeakBrightness;
		float    GamePaperWhite;
		float    UIPaperWhite;
		float    Saturation;
		float    Contrast;
		float    LUTCorrectionStrength;
		float    ColorGradingStrength;
		float    GammaCorrectionStrength;
		float    SDRSecondaryBrightness;
		uint32_t FilmGrainType;
		uint32_t PostSharpen;
		uint32_t bIsAtEndOfFrame;
		uint32_t RuntimeMS;
		float    DevSetting01;
		float    DevSetting02;
		float    DevSetting03;
		float    DevSetting04;
		float    DevSetting05;
	};
	static inline uint32_t shaderConstantsSize = 19;

    class Main : public DKUtil::model::Singleton<Main>
    {
    public:
		EnumStepper DisplayMode {
		    SettingID::kDisplayMode,
		    "Display Mode",
		    "Sets the game's display mode between SDR (Gamma 2.2 Rec.709), HDR10 BT.2020 PQ, or HDR scRGB.\n\nHDR scRGB offers the highest quality but is not compatible with technologies like DLSS Frame Generation.",
		    "DisplayMode", "Main",
		    0,
		    { "SDR", "HDR10", "HDR scRGB" }
		};
		Checkbox ForceSDROnHDR{
			SettingID::kForceSDROnHDR,
			"Force SDR on scRGB HDR",
			"When enabled, the game will still tonemap to SDR but output on an HDR scRGB swapchain.",
			{ "ForceSDROnHDR", "Dev" },
			false
		};
		ValueStepper PeakBrightness{
			SettingID::kHDR_PeakBrightness,
			"Peak Brightness",
			"Sets the peak brightness in HDR modes, this should match your display peak brightness. This will not influence the game average brightness.",
			"PeakBrightness", "HDR",
			1000,
			80,
			4000,
			10
		};
		ValueStepper GamePaperWhite{
			SettingID::kHDR_GamePaperWhite,
			"Game Paper White",
			"Sets the game paper white brightness in HDR modes. This influences the average brightness of the image without affecting the peak brightness. The reference default is 200.",
			"GamePaperWhite", "HDR",
			200,
		    80,
			500,
			10
		};
		ValueStepper UIPaperWhite{
			SettingID::kHDR_UIPaperWhite,
			"UI Paper White",
			"Sets the UI paper white brightness in HDR modes. The reference default is 200.",
			"UIPaperWhite", "HDR",
			200,
			80,
			500,
			10
		};
		Slider   Saturation{
		    SettingID::kHDR_Saturation,
		    "Saturation",
		    "Sets the saturation strength in HDR modes. Neutral default at 50\%.",
		    { "Saturation", "HDR" },
		    50.f,
		    0.f,
		    100.f,
			"%"
		};
		Slider   Contrast{
		    SettingID::kHDR_Contrast,
		    "Contrast",
		    "Sets the contrast strength in HDR modes. Neutral default at 50\%.",
		    { "Contrast", "HDR" },
		    50.f,
		    0.f,
		    100.f,
			"%"
		};
		Slider   SecondaryBrightness{
		    SettingID::kSecondaryBrightness,
		    "Brightness",
		    "Modulates the brightness in SDR modes. Neutral default at 50\%.",
		    { "SecondaryBrightness", "Main" },
		    50.f,
		    0.f,
		    100.f,
			"%"
		};
		Slider   LUTCorrectionStrength{
		    SettingID::kLUTCorrectionStrength,
		    "LUT Correction Strength",
		    "Sets the LUT correction (normalization) strength. This removes the fogginess from the game vanilla LUTs.",
		    { "LUTCorrectionStrength", "Main" },
		    100.f,
		    0.f,
		    100.f,
			"%"
		};
		Slider   ColorGradingStrength{
		    SettingID::kColorGradingStrength,
		    "Color Grading Strength",
		    "Sets the color grading strength - how much the LUTs influence the final image.",
		    { "ColorGradingStrength", "Main" },
		    100.f,
		    0.f,
		    100.f,
			"%"
		};
		Slider   GammaCorrectionStrength{
		    SettingID::kGammaCorrectionStrength,
		    "Gamma Correction Strength",
		    "Sets the gamma correction strength. The game used the sRGB gamma formula but was calibrated on gamma 2.2 displays. Only applies if \"Color Grading\" is enabled. 100\% should be closer to the original look.",
		    { "GammaCorrectionStrength", "Main" },
		    50.f,
		    0.f,
		    100.f,
			"%"
		};
		Checkbox VanillaMenuLUTs{
			SettingID::kVanillaMenuLUTs,
			"Vanilla Menu LUTs",
			"When enabled, menu LUTs will be unaffected by the \"LUT Correction Strength\" and \"Color Grading Strength\" settings.",
			{ "VanillaMenuLUTs", "Main" },
			true
		};
		EnumStepper  FilmGrainType{
		    SettingID::kFilmGrainType,
		    "Film Grain Type",
		    "Sets the film grain type.",
		     "FilmGrainType", "Main",
		    1,
		    { "Vanilla", "Improved" }
		};
		Checkbox PostSharpen{
			SettingID::kPostSharpen,
			"Post Sharpening",
			"Toggles the game default post sharpen pass. By default this was running after other sharpening or upscaling methods, and was always forced on.",
			{ "PostSharpen", "Main" },
			true
		};
		Slider DevSetting01{ SettingID::kDevSetting01, "DevSetting01", "Development setting", { "DevSetting01", "Dev" }, 0.f, 0.f, 100.f };
		Slider DevSetting02{ SettingID::kDevSetting02, "DevSetting02", "Development setting", { "DevSetting02", "Dev" }, 0.f, 0.f, 100.f };
		Slider DevSetting03{ SettingID::kDevSetting03, "DevSetting03", "Development setting", { "DevSetting03", "Dev" }, 0.f, 0.f, 100.f };
		Slider DevSetting04{ SettingID::kDevSetting04, "DevSetting04", "Development setting", { "DevSetting04", "Dev" }, 50.f, 0.f, 100.f };
		Slider DevSetting05{ SettingID::kDevSetting05, "DevSetting05", "Development setting", { "DevSetting05", "Dev" }, 50.f, 0.f, 100.f };
		String RenderTargetsToUpgrade{ "RenderTargetsToUpgrade", "RenderTargets" };

		Boolean PeakBrightnessAutoDetected { "PeakBrightnessAutoDetected", "HDR" };

		bool InitCompatibility(RE::BGSSwapChainObject* a_swapChainObject);
		void RefreshHDRSupportState();

		bool IsHDRSupported() const { return bIsHDRSupported; }
        bool IsSDRForcedOnHDR() const;
        bool IsDisplayModeSetToHDR() const;
        bool IsGameRenderingSetToHDR() const;

		void SetAtEndOfFrame(bool a_bIsAtEndOfFrame) { bIsAtEndOfFrame.store(a_bIsAtEndOfFrame); }

		RE::BS_DXGI_FORMAT GetDisplayModeFormat() const;
        DXGI_COLOR_SPACE_TYPE GetDisplayModeColorSpaceType() const;

		void OnDisplayModeChanged();

		void GetShaderConstants(ShaderConstants& a_outShaderConstants) const;

		void RegisterReshadeOverlay();

        void Load() noexcept;
		void Save() noexcept;

		static void DrawReshadeSettings(reshade::api::effect_runtime*);

    private:
		TomlConfig config = COMPILE_PROXY("Luma.toml"sv);
		std::atomic_bool bIsAtEndOfFrame = false;
		std::atomic_bool bIsHDRSupported = false;
		std::atomic_bool bIsHDREnabled = false;

		RE::BGSSwapChainObject* swapChainObject = nullptr;

		bool bReshadeSettingsOverlayRegistered = false;

		bool DrawReshadeCheckbox(Checkbox& a_checkbox);
		bool DrawReshadeEnumStepper(EnumStepper& a_stepper);
		bool DrawReshadeValueStepper(ValueStepper& a_stepper);
		bool DrawReshadeSlider(Slider& a_slider);
		void DrawReshadeSettings();
    };

	
}
