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

			// Note: at this point "Offsets::uiFrameGenerationTech" has not loaded in yet (nor there's a swapchain yet), and "bIsDLSSFGToFSRFGPresent" might have an outdated value, so we are possibly setting a "wrong" display format
			auto newFormat = settings->GetDisplayModeFormat();
			Utils::SetBufferFormat(RE::Buffers::FrameBuffer, newFormat);

			for (const auto& renderTargetName : settings->RenderTargetsToUpgrade.get_collection()) {
				if (const auto buffer = GetBufferFromString(renderTargetName)) {
					Utils::SetBufferFormat(buffer, RE::BS_DXGI_FORMAT::BS_DXGI_FORMAT_R16G16B16A16_FLOAT);
				}
			}
			if (settings->UpgradeExtraRenderTargets.get_data()) {
				for (const auto& renderTargetName : settings->ExtraRenderTargetsToUpgrade.get_collection()) {
					if (const auto buffer = GetBufferFromString(renderTargetName)) {
						Utils::SetBufferFormat(buffer, RE::BS_DXGI_FORMAT::BS_DXGI_FORMAT_R16G16B16A16_FLOAT);
					}
				}
			}

			Utils::LogBuffers();
		}

		static void PatchStreamline()
		{
			// TODO: add version check
			auto address = reinterpret_cast<uintptr_t>(GetModuleHandleW(L"sl.dlss_g.dll"));

			DWORD d = 0;
			VirtualProtect(reinterpret_cast<void*>(address + 0x1897F), 1, PAGE_EXECUTE_READWRITE, &d);
			memset(reinterpret_cast<void*>(address + 0x1897F), 0xEB, 1);
			VirtualProtect(reinterpret_cast<void*>(address + 0x1897F), 1, d, &d);

			VirtualProtect(reinterpret_cast<void*>(address + 0x19D46), 2, PAGE_EXECUTE_READWRITE, &d);
			memset(reinterpret_cast<void*>(address + 0x19D46), 0x90, 1);
			memset(reinterpret_cast<void*>(address + 0x19D47), 0xE9, 1);
			VirtualProtect(reinterpret_cast<void*>(address + 0x19D46), 2, d, &d);
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
			_UnkFunc = dku::Hook::write_call<5>(dku::Hook::IDToAbs(204384, 0x387), Hook_UnkFunc);

			// just after loading ini settings; deal with initial framegen setting value
			_UnkFunc2 = dku::Hook::write_call<5>(dku::Hook::IDToAbs(149040, 0x533), Hook_UnkFunc2);

			// disable photo mode screenshots with HDR
			const auto takeSnapshotVtbl = dku::Hook::IDToAbs(415473);
			auto       _Hook_TakeSnapshot = dku::Hook::AddVMTHook(&takeSnapshotVtbl, 1, FUNC_INFO(Hook_TakeSnapshot));
			_TakeSnapshot = reinterpret_cast<std::add_pointer_t<decltype(Hook_TakeSnapshot)>>(_Hook_TakeSnapshot->OldAddress);
			_Hook_TakeSnapshot->Enable();

			// Settings UI
			_CreateMonitorSetting = dku::Hook::write_call<5>(dku::Hook::IDToAbs(1078398, 0x759), Hook_CreateMonitorSetting);

			// Hide vanilla brightness, contrast and hdr brightness
			const uint8_t nop5[] = { 0x90, 0x90, 0x90, 0x90, 0x90 };
			dku::Hook::WriteData(dku::Hook::IDToAbs(1078398, 0xBBB), nop5, 5);
			dku::Hook::WriteData(dku::Hook::IDToAbs(1078398, 0xD06), nop5, 5);
			dku::Hook::WriteData(dku::Hook::IDToAbs(1078398, 0xE8F), nop5, 5);

			_SettingsDataModelCheckboxChanged = dku::Hook::write_call<5>(dku::Hook::IDToAbs(136121, 0x43), Hook_SettingsDataModelCheckboxChanged);
			_SettingsDataModelStepperChanged = dku::Hook::write_call<5>(dku::Hook::IDToAbs(136131, 0x40), Hook_SettingsDataModelStepperChanged);
			_SettingsDataModelSliderChanged = dku::Hook::write_call<5>(dku::Hook::IDToAbs(136130, 0x40), Hook_SettingsDataModelSliderChanged);

			_RecreateSwapchain = dku::Hook::write_call<5>(dku::Hook::IDToAbs(203027, 0x8F), Hook_RecreateSwapchain);

			_ApplyRenderPassRenderState1 = dku::Hook::write_call<5>(dku::Hook::IDToAbs(204409, 0x18), Hook_ApplyRenderPassRenderState1);  // CmdDraw
			_ApplyRenderPassRenderState2 = dku::Hook::write_call<5>(dku::Hook::IDToAbs(204408, 0x20), Hook_ApplyRenderPassRenderState2);  // CmdDispatch

			_EndOfFrame = dku::Hook::write_call<5>(dku::Hook::IDToAbs(1078950, 0x12F5), Hook_EndOfFrame);
			_PostEndOfFrame = dku::Hook::write_call<5>(dku::Hook::IDToAbs(1078950, 0x1B2B), Hook_PostEndOfFrame);

			dku::Hook::write_call<5>(dku::Hook::IDToAbs(208157, 0x21D), HookedScaleformCompositeSetRenderTarget);
			dku::Hook::write_call<5>(dku::Hook::IDToAbs(208157, 0x33E), HookedScaleformCompositeDraw);

			// fsr3 fixes
			_ffxFsr3ContextCreate = dku::Hook::write_call<5>(dku::Hook::IDToAbs(1391756, 0x3B2), Hook_ffxFsr3ContextCreate);
			dku::Hook::write_call<6>(dku::Hook::IDToAbs(1391482, 0x3CE), Hook_CreateShaderResourceView);
			_UnkFunc3 = dku::Hook::write_call<5>(dku::Hook::IDToAbs(1078894, 0x5D8), Hook_UnkFunc3);
			_UnkFunc3_Internal = dku::Hook::write_call<5>(dku::Hook::IDToAbs(1722115, 0x113), Hook_UnkFunc3_Internal);
		}

	private:
		static void ToggleEnableHDRSubSettings(RE::SettingsDataModel* a_model, bool a_bDisplayModeHDREnable, bool a_bGameRenderingHDREnable, bool a_bSDRForcedOnHDR, RE::FrameGenerationTech a_frameGenerationTech);
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

		static void Hook_UnkFunc2(uint64_t a1, uint64_t a2);
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
		static void Hook_SettingsDataModelSliderChanged(void* a_arg1, RE::SettingsDataModel::UpdateEventData& a_eventData);
		static inline std::add_pointer_t<decltype(Hook_SettingsDataModelSliderChanged)> _SettingsDataModelSliderChanged;

		static bool Hook_ApplyRenderPassRenderState1(void* a_arg1, void* a_arg2);
		static bool Hook_ApplyRenderPassRenderState2(void* a_arg1, void* a_arg2);
		static inline std::add_pointer_t<decltype(Hook_ApplyRenderPassRenderState1)> _ApplyRenderPassRenderState1;
		static inline std::add_pointer_t<decltype(Hook_ApplyRenderPassRenderState2)> _ApplyRenderPassRenderState2;

		static void Hook_EndOfFrame(void* a1, void* a2, const char* a3);
		static inline std::add_pointer_t<decltype(Hook_EndOfFrame)> _EndOfFrame;

		static void Hook_PostEndOfFrame(void* a1);
		static inline std::add_pointer_t<decltype(Hook_PostEndOfFrame)> _PostEndOfFrame;

		static int32_t Hook_ffxFsr3ContextCreate(void* a_context, RE::FfxFsr3ContextDescription* a_contextDescription);
		static inline std::add_pointer_t<decltype(Hook_ffxFsr3ContextCreate)> _ffxFsr3ContextCreate;

		static void Hook_CreateShaderResourceView(ID3D12Device* a_this, ID3D12Resource* a_resource, D3D12_SHADER_RESOURCE_VIEW_DESC* a_desc, D3D12_CPU_DESCRIPTOR_HANDLE a_destDescriptor);

		static void Hook_UnkFunc3(uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t* a5, uint64_t a6, uint8_t a7);
		static inline std::add_pointer_t<decltype(Hook_UnkFunc3)> _UnkFunc3;

		static void Hook_UnkFunc3_Internal(uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t* a5, uint64_t a6, uint64_t a7);
		static inline std::add_pointer_t<decltype(Hook_UnkFunc3_Internal)> _UnkFunc3_Internal;
	};

	void Install();
}
