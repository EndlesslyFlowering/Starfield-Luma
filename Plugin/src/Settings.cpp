#include "Settings.h"

#include "Utils.h"

namespace Settings
{
	std::string EnumStepper::GetStepperText(int32_t a_value) const
    {
		if (optionNames.size() > a_value) {
			return optionNames[a_value];
		}

		return "Invalid";
    }

    std::string ValueStepper::GetStepperText(int32_t a_value) const
    {
		return std::to_string(GetValueFromStepper(a_value));
    }

    float Slider::GetSliderPercentage() const
    {
		return (value.get_data() - sliderMin) / (sliderMax - sliderMin);
    }

    std::string Slider::GetSliderText() const
    {
		return std::format("{}{}", value.get_data(), suffix);
    }

    float Slider::GetValueFromSlider(float a_percentage) const
    {
		return std::roundf(a_percentage * (sliderMax - sliderMin) + sliderMin);
    }

    void Slider::SetValueFromSlider(float a_percentage)
    {
        *value = GetValueFromSlider(a_percentage);
    }

    bool Main::InitCompatibility(RE::BGSSwapChainObject* a_swapChainObject)
	{
		swapChainObject = a_swapChainObject;

		// check for old NativeHDR being present
		auto isModuleLoaded = [&](LPCWSTR a_moduleName) {
			HMODULE hModule = nullptr;
			GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, a_moduleName, &hModule);
			return hModule != nullptr;
		};

		constexpr std::array moduleNames = { L"NativeHDR.dll", L"NativeHDR.asi", L"NativeAutoHDR.dll", L"NativeAutoHDR.asi" };

		for (auto& moduleName : moduleNames) {
			if (isModuleLoaded(moduleName)) {
				ERROR("An old version of the Native(Auto)HDR plugin is loaded. Please remove it while using Luma. It is a successor to the previous mod.")
				return false;
			}
		}

		// check hdr support
		bIsHDRSupported = Utils::IsHDRSupported(swapChainObject->hwnd);
		bIsHDREnabled = Utils::IsHDREnabled(swapChainObject->hwnd);

		// enable hdr if off and display mode suggests it should be on
		if (bIsHDRSupported && !bIsHDREnabled && DisplayMode.value.get_data() > 0) {
		    bIsHDREnabled = Utils::SetHDREnabled(swapChainObject->hwnd);
		}

		// change display mode setting if it's hdr and hdr is not supported
		if (!bIsHDRSupported && DisplayMode.value.get_data() > 0) {
		    *DisplayMode.value = 0;
		}

		// autodetect peak brightness
		if (bIsHDRSupported && PeakBrightnessAutoDetected.get_data() == false) {
			float detectedMaxLuminance;
			if (Utils::GetHDRMaxLuminance(swapChainObject->swapChainInterface, detectedMaxLuminance)) {
			    *PeakBrightnessAutoDetected = true;
				*PeakBrightness.value = detectedMaxLuminance;
				Save();
			}
		}

		return true;
	}

    bool Main::IsDisplayModeSetToHDR() const
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

    void Main::OnDisplayModeChanged()
	{
		// enable HDR if disabled
		if (!bIsHDREnabled && bIsHDRSupported && DisplayMode.value.get_data() > 0) {
			bIsHDREnabled = Utils::SetHDREnabled(swapChainObject->hwnd);
		}

		const RE::BS_DXGI_FORMAT newFormat = GetDisplayModeFormat();
		Utils::SetBufferFormat(RE::Buffers::FrameBuffer, newFormat);

		swapChainObject->format = newFormat;

		// toggle vsync to force a swapchain recreation
		Offsets::ToggleVsync(reinterpret_cast<void*>(*Offsets::unkToggleVsyncArg1Ptr + 0x8), *Offsets::bEnableVsync);
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
		a_outShaderConstants.GammaCorrectionStrength = static_cast<float>(GammaCorrectionStrength.value.get_data() * 0.01f);  // 0-100 to 0-1
		// There is no reason this wouldn't work in HDR, but for now it's disabled
		a_outShaderConstants.SDRSecondaryBrightness = IsGameRenderingSetToHDR() ? 1.f : static_cast<float>((SecondaryBrightness.value.get_data()) * 0.02f); // 0-100 to 0-2
		a_outShaderConstants.FilmGrainType = static_cast<uint32_t>(FilmGrainType.value.get_data());
		a_outShaderConstants.PostSharpen = static_cast<uint32_t>(PostSharpen.value.get_data());
		a_outShaderConstants.bIsAtEndOfFrame = static_cast<uint32_t>(bIsAtEndOfFrame.load());
		a_outShaderConstants.RuntimeMS = *Offsets::g_durationOfApplicationRunTimeMS;
		a_outShaderConstants.DevSetting01 = static_cast<float>(DevSetting01.value.get_data() * 0.01f);  // 0-100 to 0-1
		a_outShaderConstants.DevSetting02 = static_cast<float>(DevSetting02.value.get_data() * 0.01f);  // 0-100 to 0-1
		a_outShaderConstants.DevSetting03 = static_cast<float>(DevSetting03.value.get_data() * 0.01f);  // 0-100 to 0-1
		a_outShaderConstants.DevSetting04 = static_cast<float>(DevSetting04.value.get_data() * 0.01f);  // 0-100 to 0-1
		a_outShaderConstants.DevSetting05 = static_cast<float>(DevSetting05.value.get_data() * 0.01f);  // 0-100 to 0-1
    }

    void Main::RegisterReshadeOverlay()
    {
		if (!bReshadeSettingsOverlayRegistered) {
			HMODULE hModule = nullptr;
			GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, reinterpret_cast<LPCWSTR>(Main::GetSingleton()), &hModule);
			if (hModule) {
				if (reshade::register_addon(hModule)) {
					reshade::register_overlay("Starfield Luma Settings", DrawReshadeSettings);
					bReshadeSettingsOverlayRegistered = true;
				}
			}
		}
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
			config.Bind(SecondaryBrightness.value, SecondaryBrightness.defaultValue);
			config.Bind(LUTCorrectionStrength.value, LUTCorrectionStrength.defaultValue);
			config.Bind(ColorGradingStrength.value, ColorGradingStrength.defaultValue);
			config.Bind(GammaCorrectionStrength.value, GammaCorrectionStrength.defaultValue);
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
			config.Bind(PeakBrightnessAutoDetected, false);
		});

		config.Load();

		INFO("Config loaded"sv)
	}

    void Main::Save() noexcept
    {
		config.Generate();
		config.Write();
    }

    void Main::DrawReshadeSettings(reshade::api::effect_runtime*)
    {
        const auto settings = Settings::Main::GetSingleton();
		settings->DrawReshadeSettings();
    }

    bool Main::DrawReshadeCheckbox(Checkbox& a_checkbox)
    {
		bool tempValue = *a_checkbox.value;
		if (ImGui::Checkbox(a_checkbox.name.c_str(), &tempValue)) {
			*a_checkbox.value = tempValue;
			Save();
			return true;
		}
		return false;
    }

    bool Main::DrawReshadeEnumStepper(EnumStepper& a_stepper)
    {
		int tempValue = *a_stepper.value;
		if (ImGui::SliderInt(a_stepper.name.c_str(), &tempValue, 0, a_stepper.GetNumOptions() - 1, a_stepper.GetStepperText(tempValue).c_str(), ImGuiSliderFlags_NoInput)) {
			*a_stepper.value = tempValue;
			Save();
			return true;
		}
		return false;
    }

    bool Main::DrawReshadeValueStepper(ValueStepper& a_stepper)
	{
		int tempValue = *a_stepper.value;
		if (ImGui::SliderInt(a_stepper.name.c_str(), &tempValue, a_stepper.minValue, a_stepper.maxValue, std::to_string(tempValue).c_str())) {
			*a_stepper.value = tempValue;
			Save();
			return true;
		}
		return false;
	}

    bool Main::DrawReshadeSlider(Slider& a_slider)
    {
		float tempValue = *a_slider.value;
		if (ImGui::SliderFloat(a_slider.name.c_str(), &tempValue, a_slider.sliderMin, a_slider.sliderMax, "%.0f")) {
			*a_slider.value = tempValue;
			Save();
			return true;
		}
		return false;
    }

    void Main::DrawReshadeSettings()
    {
		DrawReshadeValueStepper(PeakBrightness);
		DrawReshadeValueStepper(GamePaperWhite);
		DrawReshadeValueStepper(UIPaperWhite);
		DrawReshadeSlider(Saturation);
		DrawReshadeSlider(Contrast);
		DrawReshadeSlider(GammaCorrectionStrength);
		DrawReshadeSlider(SecondaryBrightness);
		DrawReshadeSlider(LUTCorrectionStrength);
		DrawReshadeSlider(ColorGradingStrength);
		DrawReshadeCheckbox(VanillaMenuLUTs);
		DrawReshadeEnumStepper(FilmGrainType);
		DrawReshadeCheckbox(PostSharpen);

		DrawReshadeSlider(DevSetting01);
		DrawReshadeSlider(DevSetting02);
		DrawReshadeSlider(DevSetting03);
		DrawReshadeSlider(DevSetting04);
		DrawReshadeSlider(DevSetting05);
    }
}
