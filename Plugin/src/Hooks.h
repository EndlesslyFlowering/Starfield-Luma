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

	private:
		static RE::BufferDefinition* GetBufferFromString(std::string_view a_bufferName);
	};

	class Hooks
	{
	public:
		static void Hook()
		{
			// set color space and save swapchain object pointer
			_UnkFunc = dku::Hook::write_call<5>(dku::Hook::IDToAbs(143272, 0xAC9), Hook_UnkFunc);

			// just after loading ini settings; deal with initial framegen setting value
			_UnkFunc2 = dku::Hook::write_call<5>(dku::Hook::IDToAbs(99482, 0x61D), Hook_UnkFunc2);

			// disable photo mode screenshots with HDR
			const auto takeSnapshotVtbl = dku::Hook::IDToAbs(443439);
			auto       _Hook_TakeSnapshot = dku::Hook::AddVMTHook(&takeSnapshotVtbl, 1, FUNC_INFO(Hook_TakeSnapshot));
			_TakeSnapshot = reinterpret_cast<decltype(&Hook_TakeSnapshot)>(_Hook_TakeSnapshot->OldAddress);
			_Hook_TakeSnapshot->Enable();

			// Settings UI
			_CreateMonitorSetting = dku::Hook::write_call<5>(dku::Hook::IDToAbs(88728, 0x121C), Hook_CreateMonitorSetting);

			// Hide vanilla brightness, contrast and hdr brightness
			const uint8_t nop5[] = { 0x90, 0x90, 0x90, 0x90, 0x90 };
			dku::Hook::WriteData(dku::Hook::IDToAbs(88728, 0x1B2E), nop5, 5);
			dku::Hook::WriteData(dku::Hook::IDToAbs(88728, 0x1DAA), nop5, 5);
			dku::Hook::WriteData(dku::Hook::IDToAbs(88728, 0x209D), nop5, 5);

			const auto settingsDataModelCheckboxVtbl = dku::Hook::IDToAbs(439683);
			const auto settingsDataModelStepperVtbl = dku::Hook::IDToAbs(439693);
			const auto settingsDataModelSliderVtbl = dku::Hook::IDToAbs(439695);

			auto hookSettingsDataModelCheckbox = dku::Hook::AddVMTHook(&settingsDataModelCheckboxVtbl, 1, FUNC_INFO(Hook_SettingsDataModelCheckboxChanged));
			auto hookSettingsDataModelStepper = dku::Hook::AddVMTHook(&settingsDataModelStepperVtbl, 1, FUNC_INFO(Hook_SettingsDataModelStepperChanged));
			auto hookSettingsDataModelSlider = dku::Hook::AddVMTHook(&settingsDataModelSliderVtbl, 1, FUNC_INFO(Hook_SettingsDataModelSliderChanged));

			_SettingsDataModelCheckboxChanged = reinterpret_cast<decltype(&Hook_SettingsDataModelCheckboxChanged)>(hookSettingsDataModelCheckbox->OldAddress);
			_SettingsDataModelStepperChanged = reinterpret_cast<decltype(&Hook_SettingsDataModelStepperChanged)>(hookSettingsDataModelStepper->OldAddress);
			_SettingsDataModelSliderChanged = reinterpret_cast<decltype(&Hook_SettingsDataModelSliderChanged)>(hookSettingsDataModelSlider->OldAddress);

			hookSettingsDataModelCheckbox->Enable();
			hookSettingsDataModelStepper->Enable();
			hookSettingsDataModelSlider->Enable();

			_RecreateSwapchain = dku::Hook::write_call<5>(dku::Hook::IDToAbs(141998, 0xBF), Hook_RecreateSwapchain);

			// Hook ApplyRenderPassRenderState before any CmdDraw or CmdDispatch calls. DKUtil doesn't provide a sane way to restore function prologues so we do it manually.
			const auto applyRenderPassRenderState = dku::Hook::IDToAbs(142462);
			const auto temp = reinterpret_cast<uintptr_t>(dku::Hook::Trampoline::Allocate(5 + 2 + 4 + 8));
			dku::Hook::WriteData(temp + 0, reinterpret_cast<void *>(applyRenderPassRenderState), 5, false);
			dku::Hook::WriteImm(temp + 5, static_cast<uint16_t>(0x25FF), false);
			dku::Hook::WriteImm(temp + 7, static_cast<uint32_t>(0), false);
			dku::Hook::WriteImm(temp + 11, static_cast<uintptr_t>(applyRenderPassRenderState + 0x5), false);
			_ApplyRenderPassRenderState = reinterpret_cast<decltype(&Hook_ApplyRenderPassRenderState)>(temp);
			dku::Hook::write_branch<5>(applyRenderPassRenderState, Hook_ApplyRenderPassRenderState);

			_EndOfFrame = dku::Hook::write_call<5>(dku::Hook::IDToAbs(143152, 0xCBD), Hook_EndOfFrame);
			_PostEndOfFrame = dku::Hook::write_call<5>(dku::Hook::IDToAbs(143152, 0x148F), Hook_PostEndOfFrame);  // CmdEnd, was CmdEndProfilingMarker previously

			const auto scaleformCompositeRenderPassVtbl = dku::Hook::IDToAbs(497272);
			auto hookScaleformCompositeRenderPass = dku::Hook::AddVMTHook(&scaleformCompositeRenderPassVtbl, 7, FUNC_INFO(HookedScaleformCompositeRenderPass));
			_ScaleformCompositeRenderPass = reinterpret_cast<decltype(&HookedScaleformCompositeRenderPass)>(hookScaleformCompositeRenderPass->OldAddress);
			hookScaleformCompositeRenderPass->Enable();
			dku::Hook::write_call<5>(hookScaleformCompositeRenderPass->OldAddress + 0x4A0, HookedScaleformCompositeRenderPassExecuteDraw);

			// fsr3 fixes
			_ffxFsr3ContextCreate = dku::Hook::write_call<5>(dku::Hook::IDToAbs(144625, 0x374), Hook_ffxFsr3ContextCreate);
			dku::Hook::write_call<6>(dku::Hook::IDToAbs(178624, 0x3CE), Hook_CreateShaderResourceView);
			_ffxGetSwapchainDX12 = dku::Hook::write_call<5>(dku::Hook::IDToAbs(144623, 0x1D5), Hook_ffxGetSwapchainDX12);

			// Starfield immediately crashes because of an unhandled assertion when any D3D12 debug layer is active
			// const uint8_t retn[] = { 0xC3 };
			// dku::Hook::WriteData(dku::Hook::IDToAbs(140240), retn, 1);
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

		static void HookedScaleformCompositeRenderPass(void* a1, void* a2, void* a_renderPassData);
		static inline std::add_pointer_t<decltype(HookedScaleformCompositeRenderPass)> _ScaleformCompositeRenderPass;
		static void HookedScaleformCompositeRenderPassExecuteDraw(void* a_arg1, void* a_arg2, uint32_t a_vertexCount);

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
		static bool Hook_SettingsDataModelCheckboxChanged(uintptr_t a1, uintptr_t a2);
		static inline std::add_pointer_t<decltype(Hook_SettingsDataModelCheckboxChanged)> _SettingsDataModelCheckboxChanged;
		static bool Hook_SettingsDataModelStepperChanged(uintptr_t a1, uintptr_t a2);
		static inline std::add_pointer_t<decltype(Hook_SettingsDataModelStepperChanged)> _SettingsDataModelStepperChanged;
		static bool Hook_SettingsDataModelSliderChanged(uintptr_t a1, uintptr_t a2);
		static inline std::add_pointer_t<decltype(Hook_SettingsDataModelSliderChanged)> _SettingsDataModelSliderChanged;

		static bool OnSettingsDataModelSliderChanged(RE::SettingsDataModel::UpdateEventData& a_eventData);

		static bool Hook_ApplyRenderPassRenderState(void* a_arg1, void* a_arg2);
		static inline std::add_pointer_t<decltype(Hook_ApplyRenderPassRenderState)> _ApplyRenderPassRenderState;

		static void Hook_EndOfFrame(void* a1, void* a2, const char* a3);
		static inline std::add_pointer_t<decltype(Hook_EndOfFrame)> _EndOfFrame;

		static void Hook_PostEndOfFrame(void* a1);
		static inline std::add_pointer_t<decltype(Hook_PostEndOfFrame)> _PostEndOfFrame;

		static int32_t Hook_ffxFsr3ContextCreate(void* a_context, RE::FfxFsr3ContextDescription* a_contextDescription);
		static inline std::add_pointer_t<decltype(Hook_ffxFsr3ContextCreate)> _ffxFsr3ContextCreate;

		static void Hook_CreateShaderResourceView(ID3D12Device* a_this, ID3D12Resource* a_resource, D3D12_SHADER_RESOURCE_VIEW_DESC* a_desc, D3D12_CPU_DESCRIPTOR_HANDLE a_destDescriptor);

		static IDXGISwapChain4* Hook_ffxGetSwapchainDX12(void* a1);
		static inline std::add_pointer_t<decltype(Hook_ffxGetSwapchainDX12)> _ffxGetSwapchainDX12;
	};

	void Install();
}
