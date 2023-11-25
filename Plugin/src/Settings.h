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
		kSTART = 600,

		kDisplayMode,
		kForceSDROnHDR,
		kHDR_PeakBrightness,
		kHDR_GamePaperWhite,
		kHDR_UIPaperWhite,
		kHDR_ExtendGamut,
		kHDR_Saturation,
		kHDR_Contrast,
		kSecondaryBrightness,
		kToneMapperType,
		kToneMapperHighlights,
		kToneMapperShadows,
		kToneMapperBloom,
		kLUTCorrectionStrength,
		kColorGradingStrength,
		kGammaCorrectionStrength,
		kVanillaMenuLUTs,
		kStrictLUTApplication,
		kFilmGrainType,
		kFilmGrainCap,
		kPostSharpen,

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
		float    Saturation;
		float    Contrast;
		float    SDRSecondaryBrightness;
		uint32_t ToneMapperType;
		float    Highlights;
		float    Shadows;
		float    Bloom;
		float    LUTCorrectionStrength;
		uint32_t StrictLUTApplication;
		float    ColorGradingStrength;
		float    GammaCorrectionStrength;
		uint32_t FilmGrainType;
		float    FilmGrainCap;
		uint32_t PostSharpen;
		uint32_t bIsAtEndOfFrame;
		uint32_t RuntimeMS;
		float    DevSetting01;
		float    DevSetting02;
		float    DevSetting03;
		float    DevSetting04;
		float    DevSetting05;
	};
	static inline uint32_t shaderConstantsSize = 26;

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
			"ForceSDROnHDR", "Dev",
			false
		};
		ValueStepper PeakBrightness{
			SettingID::kHDR_PeakBrightness,
			"Peak Brightness",
			"Sets the peak brightness in HDR modes.\nThe value should match your display's peak brightness.\n\nThis does not affect the game's average brightness.",
			"PeakBrightness", "HDR",
			1000,
			80,
			10000,
			10
		};
		ValueStepper GamePaperWhite{
			SettingID::kHDR_GamePaperWhite,
			"Game Paper White",
			"Sets the game paper white brightness in HDR modes.\nThis setting affects the average brightness of the image without impacting the peak brightness.\n\nThe default value is 200.",
			"GamePaperWhite", "HDR",
			200, /*ITU reference default is 203 but we don't want to confuse users*/
		    80,
			500,
			10
		};
		ValueStepper UIPaperWhite{
			SettingID::kHDR_UIPaperWhite,
			"UI Paper White",
			"Sets the user interface paper white brightness in HDR modes.\n\nThe default value is 200.",
			"UIPaperWhite", "HDR",
			200, /*ITU reference default is 203 but we don't want to confuse users*/
			80,
			500,
			10
		};
		Slider   ExtendGamut{
		    SettingID::kHDR_ExtendGamut,
		    "Extend Gamut",
		    "Shifts bright saturated colors from SDR to HDR, essentially acting as a \"smart\" saturation.\n\nNeutral at 0\%.",
		    "ExtendGamut", "HDR",
		    0.f,
		    0.f,
		    100.f,
			"%"
		};
		Slider   Saturation{
		    SettingID::kHDR_Saturation,
		    "Saturation",
		    "Sets the saturation strength in HDR modes.\n\nNeutral default at 50\%.",
		    "Saturation", "HDR",
		    50.f,
		    0.f,
		    100.f,
			"%"
		};
		Slider   Contrast{
		    SettingID::kHDR_Contrast,
		    "Contrast",
		    "Sets the contrast strength in HDR modes.\n\nNeutral default at 50\%.",
		    "Contrast", "HDR",
		    50.f,
		    0.f,
		    100.f,
			"%"
		};
		Slider   SecondaryBrightness{
		    SettingID::kSecondaryBrightness,
		    "Brightness",
		    "Modulates the brightness in SDR modes.\n\nNeutral default at 50\%.",
		    "SecondaryBrightness", "Main",
		    50.f,
		    0.f,
		    100.f,
			"%"
		};
		EnumStepper ToneMapperType{
			SettingID::kToneMapperType,
			"Tone Mapper Type",
			"Sets the tone mapper type."
				"\n"
				"\nVanilla+ uses a tonemapper inspired by the original SDR one, with enhancements to support HDR."
				"\nACES is based on ACES 1.3 and supports variable output (SDR/HDR)."
				"\nOpenDRT an newer tone mapper that supports variable output (SDR/HDR).",
			"ToneMapperType", "ToneMapper",
			0,
			{ "Vanilla+", "ACES", "OpenDRT" }
		};
		Slider Highlights{
			SettingID::kToneMapperHighlights,
			"Highlights",
			"Sets the highlights strength in the tone mapper modes.\n\nNeutral default at 50\%.",
			"Highlights", "ToneMapper",
			50.f,
			0.f,
			100.f,
			"%"
		};
		Slider Shadows{
			SettingID::kToneMapperShadows,
			"Shadows",
			"Sets the shadows strength in the tone mapper (it might not always apply).\n\nNeutral default at 50\%.",
			"Shadows", "ToneMapper",
			50.f,
			0.f,
			100.f,
			"%"
		};
		Slider Bloom{
			SettingID::kToneMapperBloom,
			"Bloom",
			"Sets the bloom strength in the tone mapper.\n\nNeutral default at 50\%.",
			"Bloom", "ToneMapper",
			50.f,
			0.f,
			100.f,
			"%"
		};
		Slider   LUTCorrectionStrength{
		    SettingID::kLUTCorrectionStrength,
		    "LUT Correction Strength",
		    "Sets the LUT correction (normalization) strength.\nThis removes the fogginess from the game vanilla LUTs.",
		    "LUTCorrectionStrength", "Main",
		    100.f,
		    0.f,
		    100.f,
			"%"
		};
		Slider   ColorGradingStrength{
		    SettingID::kColorGradingStrength,
		    "Color Grading Strength",
		    "Sets the color grading strength.\nThis setting determines how much the LUTs influence the final image.",
		    "ColorGradingStrength", "Main",
		    100.f,
		    0.f,
		    100.f,
			"%"
		};
		Slider   GammaCorrectionStrength{
		    SettingID::kGammaCorrectionStrength,
		    "Gamma Correction Strength",
		    "Sets the gamma correction strength.\nThe game used the sRGB gamma formula but was calibrated on gamma 2.2 displays.\n\n100\% should be closer to the original look.",
		    "GammaCorrectionStrength", "Main",
		    100.f,
		    0.f,
		    100.f,
			"%"
		};
		Checkbox VanillaMenuLUTs{
			SettingID::kVanillaMenuLUTs,
			"Vanilla Menu LUTs",
			"When enabled, menu LUTs will be unaffected by the \"LUT Correction Strength\" and \"Color Grading Strength\" settings.",
			"VanillaMenuLUTs", "Main",
			true
		};
		Checkbox StrictLUTApplication{
			SettingID::kStrictLUTApplication,
			"Strict LUT Application",
			"Makes LUTs apply in a way that is more similar to the vanilla SDR look. Leave off for a more HDR look.",
			"StrictLUTApplication", "HDR",
			false
		};
		EnumStepper  FilmGrainType{
		    SettingID::kFilmGrainType,
		    "Film Grain Type",
		    "Sets the film grain type.\nLuma offers an improved version film grain that does not raise the black floor.",
		     "FilmGrainType", "Main",
		    1,
		    { "Vanilla", "Improved" }
		};
		Slider FilmGrainCap{
			SettingID::kFilmGrainCap,
			"Film Grain Framerate",
			"Sets a framerate cap on the improved film grain.\nSet to 0 for uncapped film grain framerate.",
			"FilmGrainCap", "Main",
			0.f,
			0.f,
			100.f
		};
		Checkbox PostSharpen{
			SettingID::kPostSharpen,
			"Post Sharpening",
			"Toggles the game's default post-sharpen pass.\nBy default, this pass runs after other sharpening or upscaling methods, and it is always forced on.",
			"PostSharpen", "Main",
			true
		};
		Slider DevSetting01{ SettingID::kDevSetting01, "DevSetting01", "Development setting", "DevSetting01", "Dev", 0.f, 0.f, 100.f };
		Slider DevSetting02{ SettingID::kDevSetting02, "DevSetting02", "Development setting", "DevSetting02", "Dev", 0.f, 0.f, 100.f };
		Slider DevSetting03{ SettingID::kDevSetting03, "DevSetting03", "Development setting", "DevSetting03", "Dev", 0.f, 0.f, 100.f };
		Slider DevSetting04{ SettingID::kDevSetting04, "DevSetting04", "Development setting", "DevSetting04", "Dev", 50.f, 0.f, 100.f };
		Slider DevSetting05{ SettingID::kDevSetting05, "DevSetting05", "Development setting", "DevSetting05", "Dev", 50.f, 0.f, 100.f };
		String RenderTargetsToUpgrade{ "RenderTargetsToUpgrade", "RenderTargets" };

		Boolean PeakBrightnessAutoDetected { "PeakBrightnessAutoDetected", "HDR" };

		bool InitCompatibility(RE::BGSSwapChainObject* a_swapChainObject);
		void RefreshHDRDisplaySupportState();
		void RefreshHDRDisplayEnableState();

		bool IsHDRSupported() const { return bIsHDRSupported; }
		bool IsSDRForcedOnHDR() const;
		bool IsDisplayModeSetToHDR() const;
		bool IsGameRenderingSetToHDR() const;
		bool IsFilmGrainTypeImproved() const;


		void SetAtEndOfFrame(bool a_bIsAtEndOfFrame) { bIsAtEndOfFrame.store(a_bIsAtEndOfFrame); }

		RE::BGSSwapChainObject* GetSwapChainObject() const { return swapChainObject; }
		ID3D12CommandQueue* GetCommandQueue() const { return commandQueue; }
		RE::BS_DXGI_FORMAT GetDisplayModeFormat() const;
        DXGI_COLOR_SPACE_TYPE GetDisplayModeColorSpaceType() const;

		void OnDisplayModeChanged();

		void GetShaderConstants(ShaderConstants& a_outShaderConstants) const;

		void InitConfig(bool a_bIsSFSE);

		void RegisterReshadeOverlay();

        void Load() noexcept;
		void Save() noexcept;

		static void DrawReshadeSettings(reshade::api::effect_runtime*);

    private:
		TomlConfig sfseConfig = COMPILE_PROXY("Data\\SFSE\\Plugins\\Luma.toml");
		TomlConfig asiConfig = COMPILE_PROXY("Luma.toml");
		TomlConfig* config = nullptr;

		std::atomic_bool bIsAtEndOfFrame = false;
		std::atomic_bool bIsHDRSupported = false;
		std::atomic_bool bIsHDREnabled = false;

		RE::BGSSwapChainObject* swapChainObject = nullptr;
		ID3D12CommandQueue*     commandQueue = nullptr;

		bool bReshadeSettingsOverlayRegistered = false;

		void DrawReshadeTooltip(const char* a_desc);
		bool DrawReshadeCheckbox(Checkbox& a_checkbox);
		bool DrawReshadeEnumStepper(EnumStepper& a_stepper);
		bool DrawReshadeValueStepper(ValueStepper& a_stepper);
		bool DrawReshadeSlider(Slider& a_slider);
		bool DrawReshadeResetButton(Setting& a_setting);
		void DrawReshadeSettings();
    };

	
}
