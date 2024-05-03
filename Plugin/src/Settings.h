#pragma once
#include "Offsets.h"
#include "RE/Buffers.h"

#include "reshade/reshade.hpp"

#define CONFIG_ENTRY ""
#include "DKUtil/Config.hpp"

#include <d3d12.h>

// TODO: set to false in release builds (use the build configuation to automatically define it)
#define DEVELOPMENT 0

namespace Settings
{
    using namespace DKUtil::Alias;

    enum class SettingID : unsigned int
    {
		// Bethesda's settings (subject to change):
		kUpscalingTechnique = 24,
		kFrameGeneration = 26,

		// Make sure our settings IDs are all after Bethesda's ones
		kSTART = 600,

		kDisplayMode,
		kEnforceUserDisplayMode,
		kForceSDROnHDR,
		kHDR_PeakBrightness,
		kHDR_GamePaperWhite,
		kHDR_UIPaperWhite,
		kHDR_ExtendGamut,
		kHDR_AutoHDRVideos,

		kSecondaryBrightness,

		kToneMapperType,
		kToneMapperSaturation,
		kToneMapperContrast,
		kToneMapperHighlights,
		kToneMapperShadows,
		kToneMapperBloom,

		kColorGradingStrength,
		kLUTCorrectionStrength,
		kVanillaMenuLUTs,
		kStrictLUTApplication,

		kGammaCorrectionStrength,
		kFilmGrainType,
		kFilmGrainFPSLimit,
		kPostSharpen,
		kHDRScreenshots,
		kHDRScreenshotsLossless,

		kEND,

		kDevSetting01,
		kDevSetting02,
		kDevSetting03,
		kDevSetting04,
		kDevSetting05,
    };

	class Setting
	{
	public:
		SettingID id;
	    std::string name;
		std::string description;

		Setting(SettingID a_id, const std::string& a_name, const std::string& a_description) :
			id(a_id), name(a_name), description(a_description)
		{}

		virtual ~Setting() = default;
		virtual bool IsDefault() const = 0;
        
	};

	class Checkbox : public Setting
	{
	public:
	    Boolean value;
		bool defaultValue;

		Checkbox(SettingID a_id, const std::string& a_name, const std::string& a_description, const std::string& a_key, const std::string& a_section, bool a_defaultValue) :
			Setting{ a_id, a_name, a_description }, value{ a_key, a_section }, defaultValue(a_defaultValue) {}

		bool IsDefault() const override { return value.get_data() == defaultValue; }
	};

	class Stepper : public Setting
	{
	public:
		Integer value;
		int32_t defaultValue;

		Stepper(SettingID a_id, const std::string& a_name, const std::string& a_description, const std::string& a_key, const std::string& a_section, int32_t a_defaultValue) :
			Setting{ a_id, a_name, a_description }, value{ a_key, a_section }, defaultValue(a_defaultValue) {}

		bool IsDefault() const override { return value.get_data() == defaultValue; }

		virtual std::string GetStepperText(int32_t a_value) const = 0;
		virtual int32_t GetNumOptions() const = 0;
		virtual int32_t GetValueFromStepper(int32_t a_value) const = 0;
		virtual int32_t GetCurrentStepFromValue() const = 0;
		virtual void SetValueFromStepper(int32_t a_value) = 0;
	};

	class EnumStepper : public Stepper
	{
	public:
		std::vector<std::string> optionNames;

		EnumStepper(SettingID a_id, const std::string& a_name, const std::string& a_description, const std::string& a_key, const std::string& a_section, int32_t a_defaultValue, const std::vector<std::string>& a_optionNames) :
			Stepper{ a_id, a_name, a_description, a_key, a_section, a_defaultValue }, optionNames(a_optionNames) {}

		std::string GetStepperText(int32_t a_value) const override;
		int32_t GetNumOptions() const override{ return optionNames.size(); }
		int32_t GetValueFromStepper(int32_t a_value) const override { return a_value; }
		int32_t GetCurrentStepFromValue() const override { return value.get_data(); }
		void SetValueFromStepper(int32_t a_value) override { *value = a_value; }
	};

	class ValueStepper : public Stepper
	{
	public:
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

	class Slider : public Setting
	{
	public:
	    Double value;
		float  defaultValue;
		float sliderMin;
		float sliderMax;
		std::string suffix = "";

		Slider(SettingID a_id, const std::string& a_name, const std::string& a_description, const std::string& a_key, const std::string& a_section, float a_defaultValue, float a_sliderMin, float a_sliderMax, std::string_view a_suffix = "") :
			Setting{ a_id, a_name, a_description }, value{ a_key, a_section }, defaultValue(a_defaultValue), sliderMin(a_sliderMin), sliderMax(a_sliderMax), suffix(a_suffix) {}

		bool IsDefault() const override { return value.get_data() == defaultValue; }

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
		float    ExtendGamut;
		uint32_t bAutoHDRVideos;

		float    SDRSecondaryBrightness;

		uint32_t ToneMapperType;
		float    Saturation;
		float    Contrast;
		float    Highlights;
		float    Shadows;
		float    Bloom;

		float    ColorGradingStrength;
		float    LUTCorrectionStrength;
		uint32_t StrictLUTApplication;

		float    GammaCorrectionStrength;
		uint32_t FilmGrainType;
		float    FilmGrainFPSLimit;
		uint32_t PostSharpen;
		uint32_t bIsAtEndOfFrame;
		uint32_t RuntimeMS;
		float    DevSetting01;
		float    DevSetting02;
		float    DevSetting03;
		float    DevSetting04;
		float    DevSetting05;
	};
	constexpr static uint32_t shaderConstantsCount = sizeof(ShaderConstants) / sizeof(uint32_t); // Number of dwords

    class Main : public DKUtil::model::Singleton<Main>
    {
    public:
		EnumStepper DisplayMode {
		    SettingID::kDisplayMode,
		    "Display Mode",
		    "Sets the game's display mode between SDR (Gamma 2.2 Rec.709), HDR10 BT.2020 PQ, or HDR scRGB."
					"\n"
					"\nIn case Frame Generation is on, the format will internally fall back to the required one regardless of this setting.",
		    "DisplayMode", "Main",
		    0,
		    { "SDR", "HDR10", "HDR scRGB" }
		};
		Checkbox EnforceUserDisplayMode{
			SettingID::kEnforceUserDisplayMode,
			"Enforce User Display Mode",
			"Forces the user selected \"Display Mode\", ignoring the automatic fallback for Frame Generation compatibility (avoid using this unless you know what you are doing).",
			"EnforceUserDisplayMode", "Main",
			false
		};
		Checkbox ForceSDROnHDR{
			SettingID::kForceSDROnHDR,
			"Force SDR on scRGB HDR",
			"When enabled, the game will still tonemap to SDR but output on an HDR scRGB swapchain.",
			"ForceSDROnHDR", "Dev",
			false
		};
		ValueStepper PeakBrightness{
			SettingID::kHDR_PeakBrightness,
			"Peak Brightness",
			"Sets the peak brightness in HDR modes."
				"\nThe value should match your display's peak brightness."
				"\n"
				"\nThis does not affect the game's average brightness.",
			"PeakBrightness", "HDR",
			1000,
			80,
			10000,
			10
		};
		ValueStepper GamePaperWhite{
			SettingID::kHDR_GamePaperWhite,
			"Game Paper White",
			"Sets the in-game brightness of white in HDR modes."
				"\nThis setting represents the brightness of white paper (100\% diffuse white) in-game."
				"\n"
				"\nThe default value is 200.",
			"GamePaperWhite", "HDR",
			200, /*ITU reference default is 203 but we don't want to confuse users*/
			80,
			500,
			10
		};
		ValueStepper UIPaperWhite{
			SettingID::kHDR_UIPaperWhite,
			"UI Paper White",
			"Sets the user-interface brightness in HDR modes."
				"\nThis setting represents the brightness of UI elements."
				"\n"
				"\nThe default value is 200",
			"UIPaperWhite", "HDR",
			200, /*ITU reference default is 203 but we don't want to confuse users*/
			80,
			500,
			10
		};
		Slider ExtendGamut{
			SettingID::kHDR_ExtendGamut,
			"Extend Gamut",
			"Shifts bright saturated colors from SDR to HDR, essentially acting as a \"smart\" saturation."
				"\n"
				"\nNeutral at 0\%.",
			"ExtendGamut", "HDR",
			33.333f,
			0.f,
			100.f,
			"%"
		};
		Checkbox AutoHDRVideos{
			SettingID::kHDR_AutoHDRVideos,
			"AutoHDR Videos",
			"Applies an \"AutoHDR\" filter to pre-rendered videos."
				"\nThis should provide a more consistent experience, avoiding videos looking flat compared to the rest of the game.",
			"AutoHDRVideos", "HDR",
			true
		};

		Slider SecondaryBrightness{
			SettingID::kSecondaryBrightness,
			"Brightness",
			"Modulates the brightness in SDR modes."
				"\n"
				"\nNeutral default at 50\%.",
			"SecondaryBrightness", "Main",
			50.f,
			0.f,
			100.f,
			"%"
		};

		EnumStepper ToneMapperType{
			SettingID::kToneMapperType,
			"Tonemapper",
			"Selects the tonemapper."
				"\n"
				"\nVanilla+ enhances the original tonemappers to provide an HDR experience."
				"\nOpenDRT is a customizable SDR and HDR tonemapper modified to replicate the original look .",
			"ToneMapperType", "ToneMapper",
			0,
			{ "Vanilla+", "OpenDRT" }
		};
		Slider Saturation{
			SettingID::kToneMapperSaturation,
			"Saturation",
			"Sets the saturation strength in the tonemapper."
				"\n"
				"\nNeutral default at 50\%.",
			"Saturation", "ToneMapper",
			50.f,
			0.f,
			100.f,
			"%"
		};
		Slider Contrast{
			SettingID::kToneMapperContrast,
			"Contrast",
			"Sets the contrast strength in the tonemapper."
				"\n"
				"\nNeutral default at 50\%.",
			"Contrast", "ToneMapper",
			50.f,
			0.f,
			100.f,
			"%"
		};
		Slider Highlights{
			SettingID::kToneMapperHighlights,
			"Highlights",
			"Sets the highlights strength in the tonemapper."
				"\n"
				"\nNeutral default at 50\%.",
			"Highlights", "ToneMapper",
			50.f,
			0.f,
			100.f,
			"%"
		};
		Slider Shadows{
			SettingID::kToneMapperShadows,
			"Shadows",
			"Sets the shadows strength in the tonemapper."
				"\n"
				"\nNeutral default at 50\%.",
			"Shadows", "ToneMapper",
			50.f,
			0.f,
			100.f,
			"%"
		};
		Slider Bloom{
			SettingID::kToneMapperBloom,
			"Bloom",
			"Sets the bloom strength in the tonemapper."
				"\n"
				"\nNeutral default at 50\%.",
			"Bloom", "ToneMapper",
			50.f,
			0.f,
			100.f,
			"%"
		};

		Slider ColorGradingStrength{
			SettingID::kColorGradingStrength,
			"Color Grading Intensity", /*Referenced in other settings here*/
			"Sets the intensity of the game's color grading LUTs used to apply the game's look and feel.",
			"ColorGradingStrength", "Main",
			100.f,
			0.f,
			100.f,
			"%"
		};
		Slider LUTCorrectionStrength{
			SettingID::kLUTCorrectionStrength,
			"Color Grading Range Expansion", /*Referenced in other settings here, in Luma ReadMe and on the Nexus mod page*/
			"Expands the color grading LUTs to be full-range."
				"\nIncreasing will remove both the low-contrast fog present in shadows and the brightness limits in highlights caused by clamped LUTs.",
			"LUTCorrectionStrength", "Main",
			100.f,
			0.f,
			100.f,
			"%"
		};
		Checkbox VanillaMenuLUTs{
			SettingID::kVanillaMenuLUTs,
			"Vanilla Menu Color Grading",
			"When enabled, menus use the vanilla color grading LUTs and will be unaffected by the \"Color Grading Intensity\" and \"Color Grading Range Expansion\" settings.",
			"VanillaMenuLUTs", "Main",
			true
		};
		Checkbox StrictLUTApplication{
			SettingID::kStrictLUTApplication,
			"Strict Color Grading",
			"Applies color grading LUTs in a way that is more similar to the vanilla SDR look. Leave off for a more HDR look.",
			"StrictLUTApplication", "HDR",
			false
		};

		Slider GammaCorrectionStrength{
			SettingID::kGammaCorrectionStrength,
			"Gamma Correction",
			"Sets the gamma correction strength."
				"\nThe game used the sRGB gamma formula but was calibrated on gamma 2.2 displays."
				"\nThis mostly affects near black colors and might cause raised blacks if not used."
				"\n"
				"\n100\% should match the intended vanilla look."
				"\nIn SDR, Luma is meant to be played on gamma 2.2 displays.",
			"GammaCorrectionStrength", "Main",
			100.f,
			0.f,
			100.f,
			"%"
		};
		EnumStepper FilmGrainType{
			SettingID::kFilmGrainType,
			"Film Grain Type",
			"Sets the film grain type."
				"\nPerceptual applies a film grain based on how graininess is perceived in real film."
				"\nPerceptual, noticably, does not raise the black floor or discolor highlights.",
			"FilmGrainType", "Main",
			1,
			{ "Vanilla", "Perceptual" }
		};
		Slider FilmGrainFPSLimit{
			SettingID::kFilmGrainFPSLimit,
			"Film Grain FPS Limit",
			"Allows a frame limit on the perceptual film grain to counteract motion-senstivity."
				"\nUse 0 for uncapped film grain framerate.",
			"FilmGrainFPSLimit", "Main",
			0.f,
			0.f,
			100.f
		};
		Checkbox PostSharpen{
			SettingID::kPostSharpen,
			"Post Sharpening",
			"Toggles the game's default post-sharpen pass."
				"\nBy default, this is ran (forced on) after certain sharpening/upscaling methods.",
			"PostSharpen", "Main",
			true
		};
		Checkbox HDRScreenshots{
			SettingID::kHDRScreenshots,
			"HDR Screenshots",
			"Capture an additional HDR screenshot (.jxr) when using Photo Mode while in HDR.",
			"HDRScreenshots", "HDR",
			true
		};
		Checkbox HDRScreenshotsLossless{
			SettingID::kHDRScreenshotsLossless,
			"Lossless",
			"Enable to save the HDR screenshots with a lossless parameter. It vastly increases their filesize without a perceptible difference.",
			"HDRScreenshotsLossless", "HDR",
			false
		};
		Slider DevSetting01{ SettingID::kDevSetting01, "DevSetting01", "Development setting", "DevSetting01", "Dev", 0.f, 0.f, 100.f };
		Slider DevSetting02{ SettingID::kDevSetting02, "DevSetting02", "Development setting", "DevSetting02", "Dev", 0.f, 0.f, 100.f };
		Slider DevSetting03{ SettingID::kDevSetting03, "DevSetting03", "Development setting", "DevSetting03", "Dev", 0.f, 0.f, 100.f };
		Slider DevSetting04{ SettingID::kDevSetting04, "DevSetting04", "Development setting", "DevSetting04", "Dev", 50.f, 0.f, 100.f };
		Slider DevSetting05{ SettingID::kDevSetting05, "DevSetting05", "Development setting", "DevSetting05", "Dev", 50.f, 0.f, 100.f };
		String RenderTargetsToUpgrade{ "RenderTargetsToUpgrade", "RenderTargets" };
		String ExtraRenderTargetsToUpgrade{ "ExtraRenderTargetsToUpgrade", "RenderTargets" }; // Enabling these fixes banding, as they are the main color buffers
		Boolean UpgradeExtraRenderTargets{ "UpgradeExtraRenderTargets", "RenderTargets" };

		Boolean PeakBrightnessAutoDetected{ "PeakBrightnessAutoDetected", "HDR" };

		bool InitCompatibility(RE::BGSSwapChainObject* a_swapChainObject);
		void RefreshHDRDisplaySupportState();
		void RefreshHDRDisplayEnableState();

		bool IsHDRSupported() const { return bIsHDRSupported; }
		bool IsSDRForcedOnHDR(bool bAcknowledgeScreenshots = false) const;
		bool IsDisplayModeSetToHDR() const;
		bool IsGameRenderingSetToHDR(bool bAcknowledgeScreenshots = false) const;
		bool IsCustomToneMapper() const;
		bool IsFilmGrainTypeImproved() const;

		void SetAtEndOfFrame(bool a_bIsAtEndOfFrame) { bIsAtEndOfFrame.store(a_bIsAtEndOfFrame); }

		RE::BGSSwapChainObject* GetSwapChainObject() const { return swapChainObject; }
		int32_t GetActualDisplayMode(bool bAcknowledgeScreenshots = false, std::optional<RE::FrameGenerationTech> a_frameGenerationTech = std::nullopt) const;
		RE::BS_DXGI_FORMAT GetDisplayModeFormat(std::optional<RE::FrameGenerationTech> a_frameGenerationTech = std::nullopt) const;
        DXGI_COLOR_SPACE_TYPE GetDisplayModeColorSpaceType() const;

		void RefreshSwapchainFormat(std::optional<RE::FrameGenerationTech> a_frameGenerationTech = std::nullopt);
		void OnDisplayModeChanged();

		void GetShaderConstants(ShaderConstants& a_outShaderConstants) const;

		void InitConfig(bool a_bIsSFSE);

		void RegisterReshadeOverlay();

        void Load() noexcept;
		void Save() noexcept;

		static void DrawReshadeSettings(reshade::api::effect_runtime*);

		std::atomic_bool bRequestedSDRScreenshot = false;
		std::atomic_bool bRequestedHDRScreenshot = false;

        std::atomic_bool bNeedsToRefreshFSR3 = false;

    private:
		TomlConfig sfseConfig = COMPILE_PROXY("Data\\SFSE\\Plugins\\Luma.toml");
		TomlConfig asiConfig = COMPILE_PROXY("Luma.toml");
		TomlConfig* config = nullptr;

		std::atomic_bool bIsAtEndOfFrame = false;
		std::atomic_bool bIsHDRSupported = false;
		std::atomic_bool bIsHDREnabled = false;

		RE::BGSSwapChainObject* swapChainObject = nullptr;

		bool bReshadeSettingsOverlayRegistered = false;
		bool bIsDLSSGTOFSR3Present = false;

		void DrawReshadeTooltip(const char* a_desc);
		bool DrawReshadeCheckbox(Checkbox& a_checkbox);
		bool DrawReshadeEnumStepper(EnumStepper& a_stepper);
		bool DrawReshadeValueStepper(ValueStepper& a_stepper);
		bool DrawReshadeSlider(Slider& a_slider);
		bool DrawReshadeResetButton(Setting& a_setting);
		void DrawReshadeSettings();
    };

	
}
