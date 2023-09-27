#include "Hooks.h"
#include "Offsets.h"
#include "Utils.h"

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
	
    void Patches::UpgradeRenderTarget(RE::BufferDefinition* a_buffer, RE::BS_DXGI_FORMAT a_newFormat, bool a_bLimited)
    {
		if (!a_buffer) {
		    return;
		}

		if (!std::strcmp(a_buffer->bufferName, "FrameBuffer") || !std::strcmp(a_buffer->bufferName, "ImageSpaceBuffer") || !std::strcmp(a_buffer->bufferName, "ScaleformCompositeBuffer")) {
			INFO("Warning: {} - skipping because buffer is handled by a separate setting", a_buffer->bufferName)
			return;
		}

		if (a_bLimited && a_buffer->format != RE::BS_DXGI_FORMAT::BS_DXGI_FORMAT_R8G8B8A8_UNORM && a_buffer->format != RE::BS_DXGI_FORMAT::BS_DXGI_FORMAT_R8G8B8A8_UNORM_SRGB) {
			auto formatNames = Utils::GetDXGIFormatNameMap();
			INFO("{} - skipping because format is {}", a_buffer->bufferName, formatNames[Offsets::GetDXGIFormat(a_buffer->format)])
			return;
		}

        Utils::SetBufferFormat(a_buffer, a_newFormat);
    }

    void Hooks::RecreateSwapChain(RE::BGSSwapChainObject* a_bgsSwapchainObject, RE::BS_DXGI_FORMAT a_newFormat)
    {
		if (a_bgsSwapchainObject->format != a_newFormat) {
			a_bgsSwapchainObject->format = a_newFormat;
			Offsets::RecreateSwapChain(*reinterpret_cast<void**>(*Offsets::unkRecreateSwapChainArg1Ptr + 0x28), a_bgsSwapchainObject, a_bgsSwapchainObject->width, a_bgsSwapchainObject->height, *Offsets::unkRecreateSwapChainArg5);

			// set correct color space
			DXGI_COLOR_SPACE_TYPE newColorSpace;
			switch (a_newFormat) {
			case RE::BS_DXGI_FORMAT::BS_DXGI_FORMAT_B8G8R8A8_UNORM:
			default:
				newColorSpace = DXGI_COLOR_SPACE_RGB_FULL_G22_NONE_P709;
				break;
			case RE::BS_DXGI_FORMAT::BS_DXGI_FORMAT_R10G10B10A2_UNORM:
				newColorSpace = DXGI_COLOR_SPACE_RGB_FULL_G2084_NONE_P2020;
			    break;
			case RE::BS_DXGI_FORMAT::BS_DXGI_FORMAT_R16G16B16A16_FLOAT:
				newColorSpace = DXGI_COLOR_SPACE_RGB_FULL_G10_NONE_P709;
			}
			a_bgsSwapchainObject->swapChainInterface->SetColorSpace1(newColorSpace);
		}
    }

    void Hooks::ToggleEnableHDRSubSettings(RE::SettingsDataModel* a_model, bool a_bEnable)
    {
		if (const auto maxLuminanceSetting = a_model->FindSettingById(static_cast<int>(Settings::SettingID::kMaxLuminance))) {
		    maxLuminanceSetting->m_Enabled.SetValue(a_bEnable);
		}

		if (const auto paperwhiteSetting = a_model->FindSettingById(static_cast<int>(Settings::SettingID::kPaperwhite))) {
			paperwhiteSetting->m_Enabled.SetValue(a_bEnable);
		}
    }

    void Hooks::Hook_UnkFunc(uintptr_t a1, RE::BGSSwapChainObject* a_bgsSwapchainObject)
    {
		// save the pointer for later
		swapChainObject = a_bgsSwapchainObject;

		const auto settings = Settings::Main::GetSingleton();
		switch (*settings->FrameBufferFormat) {
		case 1:
			a_bgsSwapchainObject->swapChainInterface->SetColorSpace1(DXGI_COLOR_SPACE_RGB_FULL_G2084_NONE_P2020);
			break;
		case 2:
			a_bgsSwapchainObject->swapChainInterface->SetColorSpace1(DXGI_COLOR_SPACE_RGB_FULL_G10_NONE_P709);
			break;
		}

		return _UnkFunc(a1, a_bgsSwapchainObject);		
    }

    void Hooks::Hook_CreateDataModelOptions(void* a_arg1, RE::ArrayNestedUIValue<RE::SubSettingsList::GeneralSetting, 0>& a_SettingList)
    {
		const auto settings = Settings::Main::GetSingleton();

		{
			auto hack = alloca(sizeof(RE::SubSettingsList::GeneralSetting));
			auto& s = *(new (hack) RE::SubSettingsList::GeneralSetting());
			constexpr auto id = static_cast<unsigned int>(Settings::SettingID::kHDR);

			s.m_Text.SetStringValue("HDR");
			s.m_Description.SetStringValue("Sets the game's output mode between SDR, HDR10 PQ, or HDR10 scRGB.");
			s.m_ID.SetValue(id);
			s.m_Type.SetValue(RE::SubSettingsList::GeneralSetting::Type::Stepper);
			s.m_Category.SetValue(RE::SubSettingsList::GeneralSetting::Category::Display);
			s.m_Enabled.SetValue(true);
			s.m_StepperData.m_ShuttleMap.GetData().m_DisplayValues.AddItem("OFF");
			s.m_StepperData.m_ShuttleMap.GetData().m_DisplayValues.AddItem("HDR10 PQ");
			s.m_StepperData.m_ShuttleMap.GetData().m_DisplayValues.AddItem("HDR10 scRGB");
			s.m_StepperData.m_ShuttleMap.GetData().m_Value.SetValue(*settings->FrameBufferFormat);
			a_SettingList.AddItem(s);
		}

		{
			auto hack = alloca(sizeof(RE::SubSettingsList::GeneralSetting));
			auto& s = *(new (hack) RE::SubSettingsList::GeneralSetting());
			constexpr auto id = static_cast<unsigned int>(Settings::SettingID::kMaxLuminance);

			s.m_Text.SetStringValue("Max Luminance");
			s.m_Description.SetStringValue("Sets the maximum luminance in HDR modes.");
			s.m_ID.SetValue(id);
			s.m_Type.SetValue(RE::SubSettingsList::GeneralSetting::Type::Slider);
			s.m_Category.SetValue(RE::SubSettingsList::GeneralSetting::Category::Display);
			s.m_Enabled.SetValue(settings->IsHDREnabled());
			s.m_SliderData.m_ShuttleMap.GetData().m_Value.SetValue(settings->GetMaxLuminanceSliderPercentage());
			s.m_SliderData.m_ShuttleMap.GetData().m_DisplayValue.SetStringValue(settings->GetMaxLuminanceText().data());
			a_SettingList.AddItem(s);
		}

		{
			auto hack = alloca(sizeof(RE::SubSettingsList::GeneralSetting));
			auto& s = *(new (hack) RE::SubSettingsList::GeneralSetting());
			constexpr auto id = static_cast<unsigned int>(Settings::SettingID::kPaperwhite);

			s.m_Text.SetStringValue("Paperwhite Brightness");
			s.m_Description.SetStringValue("Sets the paperwhite brightness used in HDR modes.");
			s.m_ID.SetValue(id);
			s.m_Type.SetValue(RE::SubSettingsList::GeneralSetting::Type::Slider);
			s.m_Category.SetValue(RE::SubSettingsList::GeneralSetting::Category::Display);
			s.m_Enabled.SetValue(settings->IsHDREnabled());
			s.m_SliderData.m_ShuttleMap.GetData().m_Value.SetValue(settings->GetPaperwhiteSliderPercentage());
			s.m_SliderData.m_ShuttleMap.GetData().m_DisplayValue.SetStringValue(settings->GetPaperwhiteText().data());
			a_SettingList.AddItem(s);
		}

		// Initialize the rest of the settings after ours
		_CreateDataModelOptions(a_arg1, a_SettingList);
    }

    void Hooks::Hook_SettingsDataModelBoolEvent(void* a_arg1, RE::SettingsDataModel::UpdateEventData& EventData)
    {
		_SettingsDataModelBoolEvent(a_arg1, EventData);
    }

    void Hooks::Hook_SettingsDataModelIntEvent(void* a_arg1, RE::SettingsDataModel::UpdateEventData& EventData)
    {
		if (EventData.m_SettingID == static_cast<int>(Settings::SettingID::kHDR)) {
			const auto settings = Settings::Main::GetSingleton();

			const auto prevValue = *settings->FrameBufferFormat;
			const auto newValue = EventData.m_Value.Int;
			if (prevValue != newValue) {
				*settings->FrameBufferFormat = newValue;
				
				RE::BS_DXGI_FORMAT newFormat;
				switch (*settings->FrameBufferFormat) {
				case 0:
				default:
					newFormat = RE::BS_DXGI_FORMAT::BS_DXGI_FORMAT_B8G8R8A8_UNORM;
					break;
				case 1:
					newFormat = RE::BS_DXGI_FORMAT::BS_DXGI_FORMAT_R10G10B10A2_UNORM;
					break;
				case 2:
					newFormat = RE::BS_DXGI_FORMAT::BS_DXGI_FORMAT_R16G16B16A16_FLOAT;
					break;
				}

				// the value in the buffer definition is not going to be read by the game anymore by this point, but changing it anyway in case something else tries to read it
				Utils::SetBufferFormat(RE::Buffers::FrameBuffer, newFormat);

				if (prevValue == 0) {
					ToggleEnableHDRSubSettings(EventData.m_Model, true);
				} else if (newValue == 0) {
					ToggleEnableHDRSubSettings(EventData.m_Model, false);
				}

				RecreateSwapChain(swapChainObject, newFormat);
			}
		}

		_SettingsDataModelIntEvent(a_arg1, EventData);
    }

    void Hooks::Hook_SettingsDataModelFloatEvent(void* a_arg1, RE::SettingsDataModel::UpdateEventData& EventData)
    {
		if (EventData.m_SettingID == static_cast<int>(Settings::SettingID::kMaxLuminance)) {
			const auto settings = Settings::Main::GetSingleton();

			settings->SetMaxLuminanceFromSlider(EventData.m_Value.Float);
			if (auto setting = EventData.m_Model->FindSettingById(EventData.m_SettingID)) {
				setting->m_SliderData.m_ShuttleMap.GetData().m_DisplayValue.SetStringValue(settings->GetMaxLuminanceText().data());
			}

			//settingTest->m_SliderData.m_ShuttleMap.GetData().m_DisplayValue.SetStringValue(buffer);
		} else if (EventData.m_SettingID == static_cast<int>(Settings::SettingID::kPaperwhite)) {
			const auto settings = Settings::Main::GetSingleton();

			settings->SetPaperwhiteFromSlider(EventData.m_Value.Float);
			if (auto setting = EventData.m_Model->FindSettingById(EventData.m_SettingID)) {
				setting->m_SliderData.m_ShuttleMap.GetData().m_DisplayValue.SetStringValue(settings->GetPaperwhiteText().data());
			}
		}
    }

    void DebugHooks::Hook_CreateDataModelOptions(void* a_arg1, RE::ArrayNestedUIValue<RE::SubSettingsList::GeneralSetting, 0>& a_SettingList)
	{
		int id = 600;

		{
			auto hack = alloca(sizeof(RE::SubSettingsList::GeneralSetting));
			auto& s = *(new (hack) RE::SubSettingsList::GeneralSetting());

			s.m_Text.SetStringValue("Hello Checkbox");
			s.m_Description.SetStringValue("Hello World Checkbox Description");
			s.m_ID.SetValue(id++);
			s.m_Type.SetValue(RE::SubSettingsList::GeneralSetting::Type::Checkbox);
			s.m_Category.SetValue(RE::SubSettingsList::GeneralSetting::Category::Display);
			s.m_Enabled.SetValue(true);
			s.m_CheckBoxData.m_ShuttleMap.GetData().m_Value.SetValue(false);
			a_SettingList.AddItem(s);
		}

		{
			auto hack = alloca(sizeof(RE::SubSettingsList::GeneralSetting));
			auto& s = *(new (hack) RE::SubSettingsList::GeneralSetting());

			s.m_Text.SetStringValue("Hello Checkbox Disabled");
			s.m_Description.SetStringValue("Hello World Checkbox Disabled Description");
			s.m_ID.SetValue(id++);
			s.m_Type.SetValue(RE::SubSettingsList::GeneralSetting::Type::Checkbox);
			s.m_Category.SetValue(RE::SubSettingsList::GeneralSetting::Category::Display);
			s.m_Enabled.SetValue(false);
			s.m_CheckBoxData.m_ShuttleMap.GetData().m_Value.SetValue(false);
			a_SettingList.AddItem(s);
		}

		{
			auto hack = alloca(sizeof(RE::SubSettingsList::GeneralSetting));
			auto& s = *(new (hack) RE::SubSettingsList::GeneralSetting());

			s.m_Text.SetStringValue("Hello Checkbox On");
			s.m_Description.SetStringValue("Hello World Checkbox On Description");
			s.m_ID.SetValue(id++);
			s.m_Type.SetValue(RE::SubSettingsList::GeneralSetting::Type::Checkbox);
			s.m_Category.SetValue(RE::SubSettingsList::GeneralSetting::Category::Display);
			s.m_Enabled.SetValue(false);
			s.m_CheckBoxData.m_ShuttleMap.GetData().m_Value.SetValue(true);
			a_SettingList.AddItem(s);
		}
		
		{
			auto hack = alloca(sizeof(RE::SubSettingsList::GeneralSetting));
			auto& s = *(new (hack) RE::SubSettingsList::GeneralSetting());

			s.m_Text.SetStringValue("Hello Stepper");
			s.m_Description.SetStringValue("Hello World Stepper Description");
			s.m_ID.SetValue(id++);
			s.m_Type.SetValue(RE::SubSettingsList::GeneralSetting::Type::Stepper);
			s.m_Category.SetValue(RE::SubSettingsList::GeneralSetting::Category::Display);
			s.m_Enabled.SetValue(true);
			s.m_StepperData.m_ShuttleMap.GetData().m_DisplayValues.AddItem("Option 1");
			s.m_StepperData.m_ShuttleMap.GetData().m_DisplayValues.AddItem("Option 2");
			s.m_StepperData.m_ShuttleMap.GetData().m_DisplayValues.AddItem("Option 3");
			s.m_StepperData.m_ShuttleMap.GetData().m_Value.SetValue(0);
			a_SettingList.AddItem(s);
		}

		{
			auto hack = alloca(sizeof(RE::SubSettingsList::GeneralSetting));
			auto& s = *(new (hack) RE::SubSettingsList::GeneralSetting());

			s.m_Text.SetStringValue("Hello Stepper Disabled");
			s.m_Description.SetStringValue("Hello World Stepper Disabled Description");
			s.m_ID.SetValue(id++);
			s.m_Type.SetValue(RE::SubSettingsList::GeneralSetting::Type::Stepper);
			s.m_Category.SetValue(RE::SubSettingsList::GeneralSetting::Category::Display);
			s.m_Enabled.SetValue(false);
			s.m_StepperData.m_ShuttleMap.GetData().m_DisplayValues.AddItem("Option 1");
			s.m_StepperData.m_ShuttleMap.GetData().m_DisplayValues.AddItem("Option 2");
			s.m_StepperData.m_ShuttleMap.GetData().m_DisplayValues.AddItem("Option 3");
			s.m_StepperData.m_ShuttleMap.GetData().m_Value.SetValue(0);
			a_SettingList.AddItem(s);
		}

		{
			auto hack = alloca(sizeof(RE::SubSettingsList::GeneralSetting));
			auto& s = *(new (hack) RE::SubSettingsList::GeneralSetting());

			s.m_Text.SetStringValue("Hello Stepper On");
			s.m_Description.SetStringValue("Hello World Stepper On Description");
			s.m_ID.SetValue(id++);
			s.m_Type.SetValue(RE::SubSettingsList::GeneralSetting::Type::Stepper);
			s.m_Category.SetValue(RE::SubSettingsList::GeneralSetting::Category::Display);
			s.m_Enabled.SetValue(false);
			s.m_StepperData.m_ShuttleMap.GetData().m_DisplayValues.AddItem("Option 1");
			s.m_StepperData.m_ShuttleMap.GetData().m_DisplayValues.AddItem("Option 2");
			s.m_StepperData.m_ShuttleMap.GetData().m_DisplayValues.AddItem("Option 3");
			s.m_StepperData.m_ShuttleMap.GetData().m_Value.SetValue(2);
			a_SettingList.AddItem(s);
		}

		{
			auto hack = alloca(sizeof(RE::SubSettingsList::GeneralSetting));
			auto& s = *(new (hack) RE::SubSettingsList::GeneralSetting());

			s.m_Text.SetStringValue("Hello Slider");
			s.m_Description.SetStringValue("Hello World Slider Description");
			s.m_ID.SetValue(id++);
			s.m_Type.SetValue(RE::SubSettingsList::GeneralSetting::Type::Slider);
			s.m_Category.SetValue(RE::SubSettingsList::GeneralSetting::Category::Display);
			s.m_Enabled.SetValue(true);
			s.m_SliderData.m_ShuttleMap.GetData().m_Value.SetValue(0.5f);
			s.m_SliderData.m_ShuttleMap.GetData().m_DisplayValue.SetStringValue("0.5");
			a_SettingList.AddItem(s);
		}

		{
			auto hack = alloca(sizeof(RE::SubSettingsList::GeneralSetting));
			auto& s = *(new (hack) RE::SubSettingsList::GeneralSetting());

			s.m_Text.SetStringValue("Hello Slider Disabled");
			s.m_Description.SetStringValue("Hello World Slider Disabled Description");
			s.m_ID.SetValue(id++);
			s.m_Type.SetValue(RE::SubSettingsList::GeneralSetting::Type::Slider);
			s.m_Category.SetValue(RE::SubSettingsList::GeneralSetting::Category::Display);
			s.m_Enabled.SetValue(false);
			s.m_SliderData.m_ShuttleMap.GetData().m_Value.SetValue(0.5f);
			s.m_SliderData.m_ShuttleMap.GetData().m_DisplayValue.SetStringValue("0.5");
			a_SettingList.AddItem(s);
		}

		// Initialize the rest of the settings after ours
		_CreateDataModelOptions(a_arg1, a_SettingList);
	}

	void DebugHooks::Hook_SettingsDataModelBoolEvent(void* a_arg1, RE::SettingsDataModel::UpdateEventData& EventData)
	{
		char buffer[128];
		sprintf_s(buffer, "Got a bool event: %d %s\n", EventData.m_SettingID, EventData.m_Value.Bool ? "true" : "false");
		OutputDebugStringA(buffer);

		_SettingsDataModelBoolEvent(a_arg1, EventData);
	}

	void DebugHooks::Hook_SettingsDataModelIntEvent(void* a_arg1, RE::SettingsDataModel::UpdateEventData& EventData)
	{
		char buffer[128];
		sprintf_s(buffer, "Got an integer event: %d %d\n", EventData.m_SettingID, EventData.m_Value.Int);
		OutputDebugStringA(buffer);

		if (auto settingTest = EventData.m_Model->FindSettingById(602))
		{
			OutputDebugStringA("Manually updating checkbox state\n");
			settingTest->m_CheckBoxData.m_ShuttleMap.GetData().m_Value.SetValue(false);
		}

		_SettingsDataModelIntEvent(a_arg1, EventData);
	}

	void DebugHooks::Hook_SettingsDataModelFloatEvent(void* a_arg1, RE::SettingsDataModel::UpdateEventData& EventData)
	{
		char buffer[128];
		sprintf_s(buffer, "Got a float event: %d %f\n", EventData.m_SettingID, EventData.m_Value.Float);
		OutputDebugStringA(buffer);

		if (EventData.m_SettingID >= 600) {
			if (auto settingTest = EventData.m_Model->FindSettingById(EventData.m_SettingID)) {
				char buffer[128];
				sprintf_s(buffer, "%.0f%%", EventData.m_Value.Float * 100.0f);

				settingTest->m_SliderData.m_ShuttleMap.GetData().m_DisplayValue.SetStringValue(buffer);
			}
		}

		_SettingsDataModelFloatEvent(a_arg1, EventData);
	}

    void DebugHooks::Hook_CreateRenderTargetView(uintptr_t a1, ID3D12Resource* a_resource, DXGI_FORMAT a_format, uint8_t a4, uint16_t a5, uintptr_t a6)
    {
		const auto textureDesc = a_resource->GetDesc();

		_CreateRenderTargetView(a1, a_resource, a_format, a4, a5, a6);
    }

    void DebugHooks::Hook_CreateDepthStencilView(uintptr_t a1, ID3D12Resource* a_resource, DXGI_FORMAT a_format, uint8_t a4, uint16_t a5, uintptr_t a6)
    {
		const auto textureDesc = a_resource->GetDesc();

		_CreateDepthStencilView(a1, a_resource, a_format, a4, a5, a6);
    }

    void Install()
	{
//#ifndef NDEBUG
	    Utils::LogBuffers();
		//DebugHooks::Hook();
//#endif
		Hooks::Hook();
		Patches::Patch();
	}
}
