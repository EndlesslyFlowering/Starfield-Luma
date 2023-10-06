#pragma once
#include "Settings.h"
#include "Utils.h"
#include "RE/Buffers.h"
#include "RE/SettingsDataModel.h"

namespace Hooks
{
	class Patches
	{
	public:
		static void Patch()
		{
			const auto settings = Settings::Main::GetSingleton();

			auto newFormat = settings->GetDisplayModeFormat();
			Utils::SetBufferFormat(RE::Buffers::FrameBuffer, newFormat);

			for (const auto& renderTargetName : settings->RenderTargetsToUpgrade.get_collection()) {
				if (const auto buffer = GetBufferFromString(renderTargetName)) {
					Utils::SetBufferFormat(buffer, RE::BS_DXGI_FORMAT::BS_DXGI_FORMAT_R16G16B16A16_FLOAT);
				}
			}

			Utils::LogBuffers();
		}

	private:
		static RE::BufferDefinition* GetBufferFromString(std::string_view a_bufferName);
	};

	class Hooks
	{
	public:
		static void Hook()
		{
			// set color space and save swapchain object pointer
			_UnkFunc = dku::Hook::write_call<5>(dku::Hook::IDToAbs(204384, 0x3EA), Hook_UnkFunc);

			// disable photo mode screenshots with HDR
			const auto takeSnapshotVtbl = dku::Hook::IDToAbs(415473);
			auto       _Hook_TakeSnapshot = dku::Hook::AddVMTHook(&takeSnapshotVtbl, 1, FUNC_INFO(Hook_TakeSnapshot));
			_TakeSnapshot = reinterpret_cast<std::add_pointer_t<decltype(Hook_TakeSnapshot)>>(_Hook_TakeSnapshot->OldAddress);
			_Hook_TakeSnapshot->Enable();

			// Settings UI
			_CreateDataModelOptions = dku::Hook::write_call<5>(dku::Hook::IDToAbs(135915, 0x89), Hook_CreateDataModelOptions);
			_SettingsDataModelBoolEvent = dku::Hook::write_call<5>(dku::Hook::IDToAbs(136121, 0x3A), Hook_SettingsDataModelBoolEvent);
			_SettingsDataModelIntEvent = dku::Hook::write_call<5>(dku::Hook::IDToAbs(136131, 0x37), Hook_SettingsDataModelIntEvent);
			_SettingsDataModelFloatEvent = dku::Hook::write_call<5>(dku::Hook::IDToAbs(136130, 0x37), Hook_SettingsDataModelFloatEvent);

			_RecreateSwapchain = dku::Hook::write_call<5>(dku::Hook::IDToAbs(203027, 0x89), Hook_RecreateSwapchain);

			_ApplyRenderPassRenderState = dku::Hook::write_call<5>(dku::Hook::IDToAbs(204409, 0x18), Hook_ApplyRenderPassRenderState);  // CmdDraw
			dku::Hook::write_call<5>(dku::Hook::IDToAbs(204408, 0x20), Hook_ApplyRenderPassRenderState);                                // CmdDispatch
		}

	private:
		static void ToggleEnableHDRSubSettings(RE::SettingsDataModel* a_model, bool a_bEnable);
		static void CreateCheckboxSetting(RE::ArrayNestedUIValue<RE::SubSettingsList::GeneralSetting, 0>& a_settingList, Settings::Checkbox& a_setting, bool a_bEnabled);
		static void CreateStepperSetting(RE::ArrayNestedUIValue<RE::SubSettingsList::GeneralSetting, 0>& a_settingList, Settings::Stepper& a_setting, bool a_bEnabled);
		static void CreateSliderSetting(RE::ArrayNestedUIValue<RE::SubSettingsList::GeneralSetting, 0>& a_settingList, Settings::Slider& a_setting, bool a_bEnabled);

		static void Hook_UnkFunc(uintptr_t a1, RE::BGSSwapChainObject* a_bgsSwapchainObject);
		static inline std::add_pointer_t<decltype(Hook_UnkFunc)> _UnkFunc;

		static bool Hook_TakeSnapshot(uintptr_t a1);
		static inline std::add_pointer_t<decltype(Hook_TakeSnapshot)> _TakeSnapshot;

		static void Hook_RecreateSwapchain(void* a1, RE::BGSSwapChainObject* a_bgsSwapChainObject, uint32_t a_width, uint32_t a_height, uint8_t a5);
		static inline std::add_pointer_t<decltype(Hook_RecreateSwapchain)> _RecreateSwapchain;

		static void Hook_CreateDataModelOptions(void* a_arg1, RE::ArrayNestedUIValue<RE::SubSettingsList::GeneralSetting, 0>& a_settingList);
		static inline std::add_pointer_t<decltype(Hook_CreateDataModelOptions)> _CreateDataModelOptions;
		static void Hook_SettingsDataModelBoolEvent(void* a_arg1, RE::SettingsDataModel::UpdateEventData& a_eventData);
		static inline std::add_pointer_t<decltype(Hook_SettingsDataModelBoolEvent)> _SettingsDataModelBoolEvent;
		static void Hook_SettingsDataModelIntEvent(void* a_arg1, RE::SettingsDataModel::UpdateEventData& a_eventData);
		static inline std::add_pointer_t<decltype(Hook_SettingsDataModelIntEvent)> _SettingsDataModelIntEvent;
		static void Hook_SettingsDataModelFloatEvent(void* a_arg1, RE::SettingsDataModel::UpdateEventData& a_eventData);
		static inline std::add_pointer_t<decltype(Hook_SettingsDataModelFloatEvent)> _SettingsDataModelFloatEvent;

		static bool Hook_ApplyRenderPassRenderState(void* a_arg1, void* a_arg2);
		static inline std::add_pointer_t<decltype(Hook_ApplyRenderPassRenderState)> _ApplyRenderPassRenderState;
	};

	void Install();
}
