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
			_UnkFunc = dku::Hook::write_call<5>(dku::Hook::IDToAbs(204384, 0x42C), Hook_UnkFunc);  // 0x3EA pre 1.8

			// just after loading ini settings; deal with initial framegen setting value
			_UnkFunc2 = dku::Hook::write_call<5>(dku::Hook::IDToAbs(149040, 0x543), Hook_UnkFunc2);

			// disable photo mode screenshots with HDR
			const auto takeSnapshotVtbl = dku::Hook::IDToAbs(415473);
			auto       _Hook_TakeSnapshot = dku::Hook::AddVMTHook(&takeSnapshotVtbl, 1, FUNC_INFO(Hook_TakeSnapshot));
			_TakeSnapshot = reinterpret_cast<std::add_pointer_t<decltype(Hook_TakeSnapshot)>>(_Hook_TakeSnapshot->OldAddress);
			_Hook_TakeSnapshot->Enable();

			// Settings UI
			_CreateMonitorSetting = dku::Hook::write_call<5>(dku::Hook::IDToAbs(1078398, 0x63A), Hook_CreateMonitorSetting);  // 136113, 0x62F pre 1.8

			// Hide vanilla brightness, contrast and hdr brightness
			const uint8_t nop5[] = { 0x90, 0x90, 0x90, 0x90, 0x90 };
			dku::Hook::WriteData(dku::Hook::IDToAbs(1078398, 0xA94), nop5, 5);
			dku::Hook::WriteData(dku::Hook::IDToAbs(1078398, 0xBEB), nop5, 5);
			dku::Hook::WriteData(dku::Hook::IDToAbs(1078398, 0xD6E), nop5, 5);

			_SettingsDataModelCheckboxChanged = dku::Hook::write_call<5>(dku::Hook::IDToAbs(136121, 0x3A), Hook_SettingsDataModelCheckboxChanged);
			_SettingsDataModelStepperChanged = dku::Hook::write_call<5>(dku::Hook::IDToAbs(136131, 0x37), Hook_SettingsDataModelStepperChanged);
			_SettingsDataModelSliderChanged1 = dku::Hook::write_branch<5>(dku::Hook::IDToAbs(135739, 0xA3), Hook_SettingsDataModelSliderChanged1);
			_SettingsDataModelSliderChanged2 = dku::Hook::write_branch<5>(dku::Hook::IDToAbs(135956, 0x4), Hook_SettingsDataModelSliderChanged2);

			_RecreateSwapchain = dku::Hook::write_call<5>(dku::Hook::IDToAbs(203027, 0x8F), Hook_RecreateSwapchain);  // 0x89 pre 1.8

			_ApplyRenderPassRenderState1 = dku::Hook::write_call<5>(dku::Hook::IDToAbs(204409, 0x18), Hook_ApplyRenderPassRenderState1);  // CmdDraw
			_ApplyRenderPassRenderState2 = dku::Hook::write_call<5>(dku::Hook::IDToAbs(204408, 0x20), Hook_ApplyRenderPassRenderState2);  // CmdDispatch

			_EndOfFrame = dku::Hook::write_call<5>(dku::Hook::IDToAbs(1078950, 0x12F0), Hook_EndOfFrame);  // 205436, 0x3F7 pre 1.8
			_PostEndOfFrame = dku::Hook::write_call<5>(dku::Hook::IDToAbs(1078950, 0x1B32), Hook_PostEndOfFrame);  // 205436, 0x7CB pre 1.8

			dku::Hook::write_call<5>(dku::Hook::IDToAbs(208157, 0x17E), HookedScaleformCompositeSetRenderTarget);  // 0x174 pre 1.8
			dku::Hook::write_call<5>(dku::Hook::IDToAbs(208157, 0x297), HookedScaleformCompositeDraw);  // 0x249 pre 1.8
		}

	private:
		static void ToggleEnableHDRSubSettings(RE::SettingsDataModel* a_model, bool a_bDisplayModeHDREnable, bool a_bGameRenderingHDREnable, bool a_bSDRForcedOnHDR);
		static void CheckCustomToneMapperSettings(RE::SettingsDataModel* a_model, bool a_bIsCustomToneMapper);
		static void CreateCheckboxSetting(RE::ArrayNestedUIValue<RE::SubSettingsList::GeneralSetting, 0>* a_settingList, Settings::Checkbox& a_setting, bool a_bEnabled);
		static void CreateStepperSetting(RE::ArrayNestedUIValue<RE::SubSettingsList::GeneralSetting, 0>* a_settingList, Settings::Stepper& a_setting, bool a_bEnabled);
		static void CreateSliderSetting(RE::ArrayNestedUIValue<RE::SubSettingsList::GeneralSetting, 0>* a_settingList, Settings::Slider& a_setting, bool a_bEnabled);
		static void CreateSeparator(RE::ArrayNestedUIValue<RE::SubSettingsList::GeneralSetting, 0>* a_settingList, Settings::SettingID a_id);
		static void CreateSettings(RE::ArrayNestedUIValue<RE::SubSettingsList::GeneralSetting, 0>* a_settingList);

		static void UploadRootConstants(void* a1, void* a2);

		static void HookedScaleformCompositeSetRenderTarget(void* a1, void* a2, void** a_rtArray, void* a4, void* a5, void* a6, void* a7, void* a8, void* a9);
		static void HookedScaleformCompositeDraw(void* a_arg1, void* a_arg2, uint32_t a_vertexCount);

		static void Hook_UnkFunc(uintptr_t a1, RE::BGSSwapChainObject* a_bgsSwapchainObject);
		static inline std::add_pointer_t<decltype(Hook_UnkFunc)> _UnkFunc;

		static void Hook_UnkFunc2(uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4);
		static inline std::add_pointer_t<decltype(Hook_UnkFunc2)> _UnkFunc2;

		static bool Hook_TakeSnapshot(uintptr_t a1);
		static inline std::add_pointer_t<decltype(Hook_TakeSnapshot)> _TakeSnapshot;

		static void Hook_RecreateSwapchain(void* a1, RE::BGSSwapChainObject* a_bgsSwapChainObject, uint32_t a_width, uint32_t a_height, uint8_t a5);
		static inline std::add_pointer_t<decltype(Hook_RecreateSwapchain)> _RecreateSwapchain;

		static void Hook_CreateMonitorSetting(void* a1, void* a2);
		static inline std::add_pointer_t<decltype(Hook_CreateMonitorSetting)> _CreateMonitorSetting;
		static void Hook_SettingsDataModelCheckboxChanged(void* a_arg1, RE::SettingsDataModel::UpdateEventData& a_eventData);
		static inline std::add_pointer_t<decltype(Hook_SettingsDataModelCheckboxChanged)> _SettingsDataModelCheckboxChanged;
		static void Hook_SettingsDataModelStepperChanged(void* a_arg1, RE::SettingsDataModel::UpdateEventData& a_eventData);
		static inline std::add_pointer_t<decltype(Hook_SettingsDataModelStepperChanged)> _SettingsDataModelStepperChanged;

		static bool OnSettingsDataModelSliderChanged(RE::SettingsDataModel::UpdateEventData& a_eventData);
		static void Hook_SettingsDataModelSliderChanged1(RE::SettingsDataModel::UpdateEventData& a_eventData);
		static void Hook_SettingsDataModelSliderChanged2(RE::SettingsDataModel::UpdateEventData& a_eventData);
		static inline std::add_pointer_t<decltype(Hook_SettingsDataModelSliderChanged1)> _SettingsDataModelSliderChanged1;
		static inline std::add_pointer_t<decltype(Hook_SettingsDataModelSliderChanged2)> _SettingsDataModelSliderChanged2;

		static bool Hook_ApplyRenderPassRenderState1(void* a_arg1, void* a_arg2);
		static bool Hook_ApplyRenderPassRenderState2(void* a_arg1, void* a_arg2);
		static inline std::add_pointer_t<decltype(Hook_ApplyRenderPassRenderState1)> _ApplyRenderPassRenderState1;
		static inline std::add_pointer_t<decltype(Hook_ApplyRenderPassRenderState2)> _ApplyRenderPassRenderState2;

		static void Hook_EndOfFrame(void* a1, void* a2, const char* a3);
		static inline std::add_pointer_t<decltype(Hook_EndOfFrame)> _EndOfFrame;

		static void Hook_PostEndOfFrame(void* a1);
		static inline std::add_pointer_t<decltype(Hook_PostEndOfFrame)> _PostEndOfFrame;
	};

	void Install();
}
