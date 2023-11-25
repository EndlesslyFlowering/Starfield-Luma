#include "Settings.h"

#include "Utils.h"

#define ICON_FK_UNDO reinterpret_cast<const char*>(u8"\uf0e2")

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
		// NOTE: this is called every time the game switches between windowed and borderless.
		// It's not called again when we replace swapchain color space or format ourselves.

		swapChainObject = a_swapChainObject;
		//commandQueue = a_swapChainObject->unkStruct->unkInternalStruct->commandQueue;

		// check for other plugins being present
		auto isModuleLoaded = [&](LPCWSTR a_moduleName) {
			HMODULE hModule = nullptr;
			GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, a_moduleName, &hModule);
			return hModule != nullptr;
		};

		constexpr std::array moduleNamesNativeHDR = { L"NativeHDR.dll", L"NativeHDR.asi", L"NativeAutoHDR.dll", L"NativeAutoHDR.asi" };
		constexpr std::array moduleNamesShaderInjector = { L"SFShaderInjector.dll", L"SFShaderInjector.asi" };

		// check for old NativeHDR being present
		for (auto& moduleName : moduleNamesNativeHDR) {
			if (isModuleLoaded(moduleName)) {
				ERROR("An old version of the Native(Auto)HDR plugin is loaded. Please remove it while using Luma. It is a successor to the previous mod.")
				return false;
			}
		}

		// check for Shader Injector being present
		bool bShaderInjectorFound = false;
		for (auto& moduleName : moduleNamesShaderInjector) {
			if (!bShaderInjectorFound && isModuleLoaded(moduleName)) {
				bShaderInjectorFound = true;
			}
		}

		if (!bShaderInjectorFound) {
			ERROR("Starfield Shader Injector is not loaded. Luma requires it to function properly. Please download and install the plugin - https://www.nexusmods.com/starfield/mods/5562")
			return false;
		}

		// check hdr support
		RefreshHDRDisplaySupportState();

		// enable hdr if off and display mode suggests it should be on
		RefreshHDRDisplayEnableState();

		// change display mode setting if it's hdr and hdr is not supported
		if (!bIsHDRSupported && IsGameRenderingSetToHDR()) {
			*DisplayMode.value = 0;
			// No need to save, the user might have moved the game to an SDR display temporarily
		}

		// autodetect peak brightness (only works reliably if HDR is enabled)
		if (bIsHDREnabled) {
			float detectedMaxLuminance;
			if (Utils::GetHDRMaxLuminance(swapChainObject->swapChainInterface, detectedMaxLuminance)) {
				PeakBrightness.defaultValue = detectedMaxLuminance;
				if (PeakBrightnessAutoDetected.get_data() == false) {
					*PeakBrightnessAutoDetected = true;
					*PeakBrightness.value = std::max(detectedMaxLuminance, 80.f);
					Save();
				}
			}
		}

		return true;
	}

    void Main::RefreshHDRDisplaySupportState()
    {
		bIsHDRSupported = Utils::IsHDRSupported(swapChainObject->hwnd);
		bIsHDREnabled = Utils::IsHDREnabled(swapChainObject->hwnd);
	}
	
    void Main::RefreshHDRDisplayEnableState()
    {
		if (bIsHDRSupported && !bIsHDREnabled && IsGameRenderingSetToHDR()) {
		    bIsHDREnabled = Utils::SetHDREnabled(swapChainObject->hwnd);
		}
		// TODO: it would be nice to also force the "DisplayMode" to 0 here, and re-detect the peak brightness if "PeakBrightnessAutoDetected" was false,
		// but it seems like it would run into thread safety problems
	}

    bool Main::IsSDRForcedOnHDR() const
    {
		// The game will tonemap to SDR if this is true
		return ForceSDROnHDR.value.get_data() || (!bRequestedHDRScreenshot && bRequestedSDRScreenshot);
    }

    bool Main::IsDisplayModeSetToHDR() const
    {
		return DisplayMode.value.get_data() > 0;
    }
	
    bool Main::IsGameRenderingSetToHDR() const
    {
		// The game will tonemap to SDR if this is false
		return IsDisplayModeSetToHDR() && !IsSDRForcedOnHDR();
    }

    bool Main::IsFilmGrainTypeImproved() const
	{
		return FilmGrainType.value.get_data() == 1;
	}

    RE::BS_DXGI_FORMAT Main::GetDisplayModeFormat() const
    {
		if (IsSDRForcedOnHDR())
			return RE::BS_DXGI_FORMAT::BS_DXGI_FORMAT_R16G16B16A16_FLOAT;
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
		if (IsSDRForcedOnHDR())
			return DXGI_COLOR_SPACE_RGB_FULL_G10_NONE_P709;
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
		RefreshHDRDisplaySupportState();
		RefreshHDRDisplayEnableState();

		const RE::BS_DXGI_FORMAT newFormat = GetDisplayModeFormat();
		Utils::SetBufferFormat(RE::Buffers::FrameBuffer, newFormat);

		swapChainObject->format = newFormat;

		// toggle vsync to force a swapchain recreation
		Offsets::ToggleVsync(reinterpret_cast<void*>(*Offsets::unkToggleVsyncArg1Ptr + 0x8), *Offsets::bEnableVsync);
	}

    void Main::GetShaderConstants(ShaderConstants& a_outShaderConstants) const
    {
		a_outShaderConstants.DisplayMode = IsSDRForcedOnHDR() ? -1 : static_cast<int32_t>(DisplayMode.value.get_data());
		a_outShaderConstants.PeakBrightness = static_cast<float>(PeakBrightness.value.get_data());
		a_outShaderConstants.GamePaperWhite = static_cast<float>(GamePaperWhite.value.get_data());
		a_outShaderConstants.UIPaperWhite = static_cast<float>(UIPaperWhite.value.get_data());
		a_outShaderConstants.ExtendGamut = static_cast<float>(ExtendGamut.value.get_data() * 0.01f);                      // 0-100 to 0-1
		a_outShaderConstants.Saturation = static_cast<float>(Saturation.value.get_data() * 0.02f);                        // 0-100 to 0-2
		a_outShaderConstants.Contrast = static_cast<float>(Contrast.value.get_data() * 0.02f);                            // 0-100 to 0-2
		// There is no reason this wouldn't work in HDR, but for now it's disabled
		a_outShaderConstants.SDRSecondaryBrightness = IsGameRenderingSetToHDR() ? 1.f : static_cast<float>((SecondaryBrightness.value.get_data()) * 0.02f); // 0-100 to 0-2
		a_outShaderConstants.ToneMapperType = static_cast<uint32_t>(ToneMapperType.value.get_data());
		a_outShaderConstants.Highlights = static_cast<float>(Highlights.value.get_data() * 0.01f);                        // 0-100 to 0-1
		a_outShaderConstants.Shadows = static_cast<float>(Shadows.value.get_data() * 0.01f);                              // 0-100 to 0-1
		a_outShaderConstants.Bloom = static_cast<float>(Bloom.value.get_data() * 0.01f);                              // 0-100 to 0-1
		a_outShaderConstants.LUTCorrectionStrength = static_cast<float>(LUTCorrectionStrength.value.get_data() * 0.01f);  // 0-100 to 0-1
		a_outShaderConstants.StrictLUTApplication = static_cast<uint32_t>(StrictLUTApplication.value.get_data());
		a_outShaderConstants.ColorGradingStrength = static_cast<float>(ColorGradingStrength.value.get_data() * 0.01f);    // 0-100 to 0-1
		a_outShaderConstants.GammaCorrectionStrength = static_cast<float>(GammaCorrectionStrength.value.get_data() * 0.01f);  // 0-100 to 0-1
		a_outShaderConstants.FilmGrainType = static_cast<uint32_t>(FilmGrainType.value.get_data());
		a_outShaderConstants.FilmGrainCap = static_cast<float>(FilmGrainCap.value.get_data());
		a_outShaderConstants.PostSharpen = static_cast<uint32_t>(PostSharpen.value.get_data());
		a_outShaderConstants.bIsAtEndOfFrame = static_cast<uint32_t>(bIsAtEndOfFrame.load());
		a_outShaderConstants.RuntimeMS = *Offsets::g_durationOfApplicationRunTimeMS;
		a_outShaderConstants.DevSetting01 = static_cast<float>(DevSetting01.value.get_data() * 0.01f);  // 0-100 to 0-1
		a_outShaderConstants.DevSetting02 = static_cast<float>(DevSetting02.value.get_data() * 0.01f);  // 0-100 to 0-1
		a_outShaderConstants.DevSetting03 = static_cast<float>(DevSetting03.value.get_data() * 0.01f);  // 0-100 to 0-1
		a_outShaderConstants.DevSetting04 = static_cast<float>(DevSetting04.value.get_data() * 0.01f);  // 0-100 to 0-1
		a_outShaderConstants.DevSetting05 = static_cast<float>(DevSetting05.value.get_data() * 0.01f);  // 0-100 to 0-1
    }

    void Main::InitConfig(bool a_bIsSFSE)
	{
		config = a_bIsSFSE ? &sfseConfig : &asiConfig;
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
			config->Bind(DisplayMode.value, DisplayMode.defaultValue);
			config->Bind(ForceSDROnHDR.value, ForceSDROnHDR.defaultValue);
			config->Bind(PeakBrightness.value, PeakBrightness.defaultValue);
			config->Bind(GamePaperWhite.value, GamePaperWhite.defaultValue);
			config->Bind(UIPaperWhite.value, UIPaperWhite.defaultValue);
			config->Bind(ExtendGamut.value, ExtendGamut.defaultValue);
			config->Bind(Saturation.value, Saturation.defaultValue);
			config->Bind(Contrast.value, Contrast.defaultValue);
			config->Bind(SecondaryBrightness.value, SecondaryBrightness.defaultValue);
			config->Bind(ToneMapperType.value, ToneMapperType.defaultValue);
			config->Bind(Highlights.value, Highlights.defaultValue);
			config->Bind(Shadows.value, Shadows.defaultValue);
			config->Bind(Bloom.value, Bloom.defaultValue);
			config->Bind(LUTCorrectionStrength.value, LUTCorrectionStrength.defaultValue);
			config->Bind(ColorGradingStrength.value, ColorGradingStrength.defaultValue);
			config->Bind(GammaCorrectionStrength.value, GammaCorrectionStrength.defaultValue);
			config->Bind(VanillaMenuLUTs.value, VanillaMenuLUTs.defaultValue);
			config->Bind(StrictLUTApplication.value, StrictLUTApplication.defaultValue);
			config->Bind(FilmGrainType.value, FilmGrainType.defaultValue);
			config->Bind(FilmGrainCap.value, FilmGrainCap.defaultValue);
			config->Bind(PostSharpen.value, PostSharpen.defaultValue);
			config->Bind(HDRScreenshots.value, HDRScreenshots.defaultValue);
			config->Bind(DevSetting01.value, DevSetting01.defaultValue);
			config->Bind(DevSetting02.value, DevSetting02.defaultValue);
			config->Bind(DevSetting03.value, DevSetting03.defaultValue);
			config->Bind(DevSetting04.value, DevSetting04.defaultValue);
			config->Bind(DevSetting05.value, DevSetting05.defaultValue);
			config->Bind(RenderTargetsToUpgrade,
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
			config->Bind(PeakBrightnessAutoDetected, false);
		});

		config->Load();

		INFO("Config loaded"sv)
	}

    void Main::Save() noexcept
    {
		config->Generate();
		config->Write();
    }

    void Main::DrawReshadeSettings(reshade::api::effect_runtime*)
    {
        const auto settings = Settings::Main::GetSingleton();
		settings->DrawReshadeSettings();
    }

    void Main::DrawReshadeTooltip(const char* a_desc)
	{
		if (ImGui::IsItemHovered(ImGuiHoveredFlags_DelayNormal)) {
			ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, { 8, 8 });
			if (ImGui::BeginTooltip()) {
				ImGui::PushTextWrapPos(ImGui::GetFontSize() * 50.0f);
				ImGui::TextUnformatted(a_desc);
				ImGui::PopTextWrapPos();
				ImGui::EndTooltip();
			}
			ImGui::PopStyleVar();
		}
	}

    bool Main::DrawReshadeCheckbox(Checkbox& a_checkbox)
    {
		bool result = false;
		bool tempValue = *a_checkbox.value;
		if (ImGui::Checkbox(a_checkbox.name.c_str(), &tempValue)) {
			*a_checkbox.value = tempValue;
			Save();
			result = true;
		}
		DrawReshadeTooltip(a_checkbox.description.c_str());
		if (DrawReshadeResetButton(a_checkbox)) {
			*a_checkbox.value = a_checkbox.defaultValue;
			Save();
			result = true;
		}
	    return result;
    }

    bool Main::DrawReshadeEnumStepper(EnumStepper& a_stepper)
    {
		bool result = false;
		int tempValue = *a_stepper.value;
		if (ImGui::SliderInt(a_stepper.name.c_str(), &tempValue, 0, a_stepper.GetNumOptions() - 1, a_stepper.GetStepperText(tempValue).c_str(), ImGuiSliderFlags_NoInput)) {
			*a_stepper.value = tempValue;
			Save();
			result = true;
		}
		DrawReshadeTooltip(a_stepper.description.c_str());
		if (DrawReshadeResetButton(a_stepper)) {
			*a_stepper.value = a_stepper.defaultValue;
			Save();
			result = true;
		}
		return result;
    }

    bool Main::DrawReshadeValueStepper(ValueStepper& a_stepper)
	{
		bool result = false;
		int tempValue = *a_stepper.value;
		if (ImGui::SliderInt(a_stepper.name.c_str(), &tempValue, a_stepper.minValue, a_stepper.maxValue, std::to_string(tempValue).c_str())) {
			*a_stepper.value = tempValue;
			Save();
			result = true;
		}
		DrawReshadeTooltip(a_stepper.description.c_str());
		if (DrawReshadeResetButton(a_stepper)) {
			*a_stepper.value = a_stepper.defaultValue;
			Save();
			result = true;
		}
		return result;
	}

    bool Main::DrawReshadeSlider(Slider& a_slider)
    {
		bool result = false;
		float tempValue = *a_slider.value;
		if (ImGui::SliderFloat(a_slider.name.c_str(), &tempValue, a_slider.sliderMin, a_slider.sliderMax, "%.0f")) {
			*a_slider.value = tempValue;
			Save();
			result = true;
		}
		DrawReshadeTooltip(a_slider.description.c_str());
		if (DrawReshadeResetButton(a_slider)) {
			*a_slider.value = a_slider.defaultValue;
			Save();
			result = true;
		}
		return result;
    }

    bool Main::DrawReshadeResetButton(Setting& a_setting)
	{
		bool bResult = false;
		ImGui::SameLine();
		ImGui::PushID(&a_setting);
		if (!a_setting.IsDefault()) {
			if (ImGui::SmallButton(ICON_FK_UNDO)) {
				bResult = true;
			}
		} else {
			const auto& style = ImGui::GetStyle();
			const float width = ImGui::CalcTextSize(ICON_FK_UNDO).x + style.FramePadding.x * 2.f;
			ImGui::InvisibleButton("", ImVec2(width, 0));
		}
		ImGui::PopID();
		return bResult;
	}

    void Main::DrawReshadeSettings()
    {
		ImGui::SetWindowSize(ImVec2(0, 0));
		const auto& io = ImGui::GetIO();
		const auto currentPos = ImGui::GetWindowPos();
		ImGui::SetWindowPos(ImVec2(io.DisplaySize.x / 3, currentPos.y), ImGuiCond_FirstUseEver);

		const bool isSDRForcedOnHDR = IsSDRForcedOnHDR();
		const bool isGameRenderingSetToHDR = IsGameRenderingSetToHDR();
#if DEVELOPMENT
		if (IsHDRSupported()) {
			// TODO: fix, these can often crash, Maybe we could find a way to push this change to the game main or rendering thread (they probably have a func for it),
			// or simply delay the application in our code until we get another call from the thread where this can be called (e.g. settings changed callbacks).
			if (DrawReshadeEnumStepper(DisplayMode)) {
				OnDisplayModeChanged();
			}
			if (DrawReshadeCheckbox(ForceSDROnHDR)) {
				OnDisplayModeChanged();
			}
		}
#endif

		if (isGameRenderingSetToHDR) {
			DrawReshadeValueStepper(PeakBrightness);
			DrawReshadeValueStepper(GamePaperWhite);
			DrawReshadeValueStepper(UIPaperWhite);
			DrawReshadeSlider(ExtendGamut);
			DrawReshadeSlider(Saturation);
			DrawReshadeSlider(Contrast);
		}
		else {
			if (isSDRForcedOnHDR) {
				DrawReshadeValueStepper(GamePaperWhite);
			}
			DrawReshadeSlider(SecondaryBrightness);
		}
		DrawReshadeEnumStepper(ToneMapperType);
		DrawReshadeSlider(Highlights);
		DrawReshadeSlider(Shadows);
		DrawReshadeSlider(Bloom);
		DrawReshadeSlider(GammaCorrectionStrength);
		DrawReshadeSlider(LUTCorrectionStrength);
		DrawReshadeSlider(ColorGradingStrength);
		DrawReshadeCheckbox(VanillaMenuLUTs);
		if (isGameRenderingSetToHDR) {
			DrawReshadeCheckbox(StrictLUTApplication);
		}
		DrawReshadeEnumStepper(FilmGrainType);
		if (IsFilmGrainTypeImproved()) {
			DrawReshadeSlider(FilmGrainCap);
		}
		DrawReshadeCheckbox(PostSharpen);
		DrawReshadeCheckbox(HDRScreenshots);

#if DEVELOPMENT
		DrawReshadeSlider(DevSetting01);
		DrawReshadeSlider(DevSetting02);
		DrawReshadeSlider(DevSetting03);
		DrawReshadeSlider(DevSetting04);
		DrawReshadeSlider(DevSetting05);
#endif
    }
}
