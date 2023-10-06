#include "Hooks.h"
#include "Offsets.h"
#include "Utils.h"
#include "reshade/reshade.hpp"

namespace Hooks
{
    RE::BufferDefinition* Patches::GetBufferFromString(std::string_view a_bufferName)
	{
		const auto& bufferArray = *Offsets::bufferArray;
		for (const auto& bufferDefinition : bufferArray) {
		    if (bufferDefinition->bufferName == a_bufferName) {
                return bufferDefinition;
            }
		}

		return nullptr;
	}

    void Hooks::ToggleEnableHDRSubSettings(RE::SettingsDataModel* a_model, bool a_bEnable)
    {
		if (const auto peakBrightnessSetting = a_model->FindSettingById(static_cast<int>(Settings::SettingID::kHDR_PeakBrightness))) {
			peakBrightnessSetting->m_Enabled.SetValue(a_bEnable);
		}

		if (const auto gamePaperWhiteSetting = a_model->FindSettingById(static_cast<int>(Settings::SettingID::kHDR_GamePaperWhite))) {
			gamePaperWhiteSetting->m_Enabled.SetValue(a_bEnable);
		}

		if (const auto uiPaperWhiteSetting = a_model->FindSettingById(static_cast<int>(Settings::SettingID::kHDR_UIPaperWhite))) {
			uiPaperWhiteSetting->m_Enabled.SetValue(a_bEnable);
		}

		if (const auto saturation = a_model->FindSettingById(static_cast<int>(Settings::SettingID::kHDR_Saturation))) {
			saturation->m_Enabled.SetValue(a_bEnable);
		}
    }

    void Hooks::CreateCheckboxSetting(RE::ArrayNestedUIValue<RE::SubSettingsList::GeneralSetting, 0>& a_settingList, Settings::Checkbox& a_setting, bool a_bEnabled)
    {
		auto  hack = alloca(sizeof(RE::SubSettingsList::GeneralSetting));
		auto& s = *(new (hack) RE::SubSettingsList::GeneralSetting());

		s.m_Text.SetStringValue(a_setting.name.c_str());
		s.m_Description.SetStringValue(a_setting.description.c_str());
		s.m_ID.SetValue(static_cast<unsigned int>(a_setting.id));
		s.m_Type.SetValue(RE::SubSettingsList::GeneralSetting::Type::Checkbox);
		s.m_Category.SetValue(RE::SubSettingsList::GeneralSetting::Category::Display);
		s.m_Enabled.SetValue(a_bEnabled);
		s.m_CheckBoxData.m_ShuttleMap.GetData().m_Value.SetValue(a_setting.value.get_data());
		a_settingList.AddItem(s);
    }

    void Hooks::CreateStepperSetting(RE::ArrayNestedUIValue<RE::SubSettingsList::GeneralSetting, 0>& a_settingList, Settings::Stepper& a_setting, bool a_bEnabled)
    {
		auto  hack = alloca(sizeof(RE::SubSettingsList::GeneralSetting));
		auto& s = *(new (hack) RE::SubSettingsList::GeneralSetting());

		s.m_Text.SetStringValue(a_setting.name.c_str());
		s.m_Description.SetStringValue(a_setting.description.c_str());
		s.m_ID.SetValue(static_cast<unsigned int>(a_setting.id));
		s.m_Type.SetValue(RE::SubSettingsList::GeneralSetting::Type::Stepper);
		s.m_Category.SetValue(RE::SubSettingsList::GeneralSetting::Category::Display);
		s.m_Enabled.SetValue(a_bEnabled);
		for (auto& optionName : a_setting.optionNames) {
			s.m_StepperData.m_ShuttleMap.GetData().m_DisplayValues.AddItem(optionName.c_str());
		}
		s.m_StepperData.m_ShuttleMap.GetData().m_Value.SetValue(a_setting.value.get_data());
		a_settingList.AddItem(s);
    }

    void Hooks::CreateSliderSetting(RE::ArrayNestedUIValue<RE::SubSettingsList::GeneralSetting, 0>& a_settingList, Settings::Slider& a_setting, bool a_bEnabled)
    {
		auto  hack = alloca(sizeof(RE::SubSettingsList::GeneralSetting));
		auto& s = *(new (hack) RE::SubSettingsList::GeneralSetting());

		s.m_Text.SetStringValue(a_setting.name.c_str());
		s.m_Description.SetStringValue(a_setting.description.c_str());
		s.m_ID.SetValue(static_cast<unsigned int>(a_setting.id));
		s.m_Type.SetValue(RE::SubSettingsList::GeneralSetting::Type::Slider);
		s.m_Category.SetValue(RE::SubSettingsList::GeneralSetting::Category::Display);
		s.m_Enabled.SetValue(a_bEnabled);
		s.m_SliderData.m_ShuttleMap.GetData().m_Value.SetValue(a_setting.GetSliderPercentage());
		s.m_SliderData.m_ShuttleMap.GetData().m_DisplayValue.SetStringValue(a_setting.GetSliderText().c_str());
		a_settingList.AddItem(s);
    }

    void Hooks::Hook_UnkFunc(uintptr_t a1, RE::BGSSwapChainObject* a_bgsSwapchainObject)
    {
		// save the pointer for later
		Settings::swapChainObject = a_bgsSwapchainObject;

		const auto settings = Settings::Main::GetSingleton();

		a_bgsSwapchainObject->swapChainInterface->SetColorSpace1(settings->GetDisplayModeColorSpaceType());

		Settings::RegisterReshadeOverlay();

		return _UnkFunc(a1, a_bgsSwapchainObject);		
    }

    bool Hooks::Hook_TakeSnapshot(uintptr_t a1)
    {
		const auto settings = Settings::Main::GetSingleton();
		//if (settings->IsHDREnabled()) {
		if (true) {  // actually it's always going to be the case because we're always going to update the image space buffer format
			auto  hack = alloca(sizeof(RE::MessageBoxData));
			auto& message = *(new (hack) RE::MessageBoxData("Photo Mode", "Taking screenshots with Photo Mode is not supported with Native HDR. Use an external tool (e.g. Xbox Game Bar) to take a screenshot.", nullptr, 0));
			Offsets::ShowMessageBox(*Offsets::MessageMenuManagerPtr, message, false);

			// hack to refresh the UI visibility after the snapshot
			Offsets::PhotoMode_ToggleUI(a1 + 0x8);
			Offsets::PhotoMode_ToggleUI(a1 + 0x8);

			return true;
		}
		
        return _TakeSnapshot(a1);
    }

    void Hooks::Hook_RecreateSwapchain(void* a1, RE::BGSSwapChainObject* a_bgsSwapChainObject, uint32_t a_width, uint32_t a_height, uint8_t a5)
    {
		_RecreateSwapchain(a1, a_bgsSwapChainObject, a_width, a_height, a5);

		const auto settings = Settings::Main::GetSingleton();
		a_bgsSwapChainObject->swapChainInterface->SetColorSpace1(settings->GetDisplayModeColorSpaceType());
    }

    void Hooks::Hook_CreateDataModelOptions(void* a_arg1, RE::ArrayNestedUIValue<RE::SubSettingsList::GeneralSetting, 0>& a_settingList)
    {
		const auto settings = Settings::Main::GetSingleton();

		CreateStepperSetting(a_settingList, settings->DisplayMode, true);

        CreateSliderSetting(a_settingList, settings->PeakBrightness, settings->IsHDREnabled());
        CreateSliderSetting(a_settingList, settings->GamePaperWhite, settings->IsHDREnabled());
        CreateSliderSetting(a_settingList, settings->UIPaperWhite, settings->IsHDREnabled());
        CreateSliderSetting(a_settingList, settings->Saturation, settings->IsHDREnabled());
		CreateSliderSetting(a_settingList, settings->LUTCorrectionStrength, true);
		CreateSliderSetting(a_settingList, settings->ColorGradingStrength, true);
        CreateSliderSetting(a_settingList, settings->Contrast, true);
        CreateSliderSetting(a_settingList, settings->DevSetting01, true);
        CreateSliderSetting(a_settingList, settings->DevSetting02, true);

		// Initialize the rest of the settings after ours
		_CreateDataModelOptions(a_arg1, a_settingList);
    }

    void Hooks::Hook_SettingsDataModelBoolEvent(void* a_arg1, RE::SettingsDataModel::UpdateEventData& a_eventData)
    {
		_SettingsDataModelBoolEvent(a_arg1, a_eventData);
    }

    void Hooks::Hook_SettingsDataModelIntEvent(void* a_arg1, RE::SettingsDataModel::UpdateEventData& a_eventData)
    {
		if (a_eventData.m_SettingID == static_cast<int>(Settings::SettingID::kDisplayMode)) {
			const auto settings = Settings::Main::GetSingleton();

			const auto prevValue = *settings->DisplayMode.value;
			const auto newValue = a_eventData.m_Value.Int;
			if (prevValue != newValue) {
				*settings->DisplayMode.value = newValue;
				
				const RE::BS_DXGI_FORMAT newFormat = settings->GetDisplayModeFormat();

				Utils::SetBufferFormat(RE::Buffers::FrameBuffer, newFormat);

				if (prevValue == 0) {
					ToggleEnableHDRSubSettings(a_eventData.m_Model, true);
				} else if (newValue == 0) {
					ToggleEnableHDRSubSettings(a_eventData.m_Model, false);
				}

				Settings::swapChainObject->format = newFormat;

				// toggle vsync to force a swapchain recreation
			    Offsets::ToggleVsync(reinterpret_cast<void*>(*Offsets::unkToggleVsyncArg1Ptr + 0x8), *Offsets::bEnableVsync);

				settings->Save();
			}
		}

		_SettingsDataModelIntEvent(a_arg1, a_eventData);
    }

    void Hooks::Hook_SettingsDataModelFloatEvent(void* a_arg1, RE::SettingsDataModel::UpdateEventData& a_eventData)
    {
		const auto settings = Settings::Main::GetSingleton();

		auto HandleSetting = [&](Settings::Slider& a_setting) {
			const auto prevValue = a_setting.value.get_data();
			const auto newValue = a_setting.GetValueFromSlider(a_eventData.m_Value.Float);
			if (prevValue != newValue) {
				*a_setting.value = newValue;
				if (auto setting = a_eventData.m_Model->FindSettingById(a_eventData.m_SettingID)) {
					setting->m_SliderData.m_ShuttleMap.GetData().m_DisplayValue.SetStringValue(a_setting.GetSliderText().data());
				}
				settings->Save();
			}
		};

		switch (a_eventData.m_SettingID) {
		case static_cast<int>(Settings::SettingID::kHDR_PeakBrightness):
			HandleSetting(settings->PeakBrightness);
			break;
		case static_cast<int>(Settings::SettingID::kHDR_GamePaperWhite):
			HandleSetting(settings->GamePaperWhite);
			break;
		case static_cast<int>(Settings::SettingID::kHDR_UIPaperWhite):
			HandleSetting(settings->UIPaperWhite);
			break;
		case static_cast<int>(Settings::SettingID::kHDR_Saturation):
			HandleSetting(settings->Saturation);
			break;
		case static_cast<int>(Settings::SettingID::kLUTCorrectionStrength):
			HandleSetting(settings->LUTCorrectionStrength);
			break;
		case static_cast<int>(Settings::SettingID::kColorGradingStrength):
			HandleSetting(settings->ColorGradingStrength);
			break;
		case static_cast<int>(Settings::SettingID::kContrast):
			HandleSetting(settings->Contrast);
			break;
		case static_cast<int>(Settings::SettingID::kDevSetting01):
			HandleSetting(settings->DevSetting01);
			break;
		case static_cast<int>(Settings::SettingID::kDevSetting02):
			HandleSetting(settings->DevSetting02);
			break;
		}

		_SettingsDataModelFloatEvent(a_arg1, a_eventData);
    }

	bool Hooks::Hook_ApplyRenderPassRenderState(void* a_arg1, void* a_arg2)
	{
		const bool result = _ApplyRenderPassRenderState(a_arg1, a_arg2);

		if (result) {
			const auto technique = *reinterpret_cast<uintptr_t*>(reinterpret_cast<uintptr_t>(a_arg2) + 0x8);
			const auto techniqueId = *reinterpret_cast<uint64_t*>(technique + 0x78);

			auto uploadRootConstants = [&](uint32_t RootParameterIndex, bool Compute) {
				auto       commandList = *reinterpret_cast<ID3D12GraphicsCommandList**>(reinterpret_cast<uintptr_t>(a_arg1) + 0x10);
				const auto settings = Settings::Main::GetSingleton();

				// This can be any data type, even a struct. It just has to match StructHdrDllPluginConstants in HLSL.
				std::array<float, 9> data {
					*settings->PeakBrightness.value,
					*settings->GamePaperWhite.value,
					*settings->UIPaperWhite.value,
					*settings->Saturation.value * 0.02f,
					*settings->LUTCorrectionStrength.value * 0.01f,
					*settings->ColorGradingStrength.value * 0.01f,
					*settings->Contrast.value * 0.02f,
					*settings->DevSetting01.value * 0.01f,
					*settings->DevSetting02.value * 0.01f
				};

				if (!Compute)
					commandList->SetGraphicsRoot32BitConstants(RootParameterIndex, data.size(), reinterpret_cast<uint32_t*>(data.data()), 0);
				else
					commandList->SetComputeRoot32BitConstants(RootParameterIndex, data.size(), reinterpret_cast<uint32_t*>(data.data()), 0);
			};

			// Note: The following switch statement may be called several thousand times per frame. Additionally, it'll be called from multiple
			// threads concurrently. The individual cases are called at most once or twice per frame. Keep the amount of code here fairly light.
			//
			// RootParameterIndex is the index of our custom RootConstants() entry in the root signature. It's taken from the corresponding
			// RootSignature.hlsl file stored next to each technique hlsl file.
			switch (techniqueId) {
			case 0xFF1A:
			case 0x600FF1A:
			case 0x700FF1A:
			//case 0x800FF1A:
			case 0xE00FF1A:
			case 0xF00FF1A:
				uploadRootConstants(14, false); // HDRComposite
				break;

			case 0xFF75:
				uploadRootConstants(2, false);  // FilmGrain
				break;

			case 0xFF81:
				uploadRootConstants(7, true);  // ColorGradingMerge
				break;

			//case 0xFF94:
			case 0x100FF94:
				uploadRootConstants(14, true);  // ContrastAdaptiveSharpening
				break;

			case 0xFF9A:
				uploadRootConstants(14, false);  // PostSharpen
				break;

			case 0xFFAA:
				uploadRootConstants(2, false);  // ScaleformComposite
				break;

			case 0xFFAB:
				uploadRootConstants(1, false);  // BinkMovie
				break;
			}
		}

		return result;
	}

    void Install()
	{
#ifndef NDEBUG
	    Utils::LogBuffers();
#endif
		Hooks::Hook();
		Patches::Patch();
	}
}
