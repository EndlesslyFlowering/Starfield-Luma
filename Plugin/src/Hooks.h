#pragma once
#include "Offsets.h"
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
		// Resolves a hook site and checks it still holds a call before we patch over it. Offsets
		// into a function move whenever the game is rebuilt, even when the address library id
		// still points at the right function.
		static std::uintptr_t CallSite(std::uint64_t a_id, std::ptrdiff_t a_offset, std::size_t a_size, std::string_view a_name)
		{
			const auto address = dku::Hook::IDToAbs(a_id, a_offset);
			Offsets::IsCallSite(address, a_size, a_name);
			return address;
		}

		static void Hook()
		{
			// set color space and save swapchain object pointer
			_UnkFunc = dku::Hook::write_call<5>(CallSite(143272, 0xAC9, 5, "UnkFunc"), Hook_UnkFunc);

			// just after loading ini settings; deal with initial framegen setting value
			_UnkFunc2 = dku::Hook::write_call<5>(CallSite(99482, 0x61D, 5, "UnkFunc2"), Hook_UnkFunc2);

			// disable photo mode screenshots with HDR
			const auto takeSnapshotVtbl = dku::Hook::IDToAbs(443439);
			auto       _Hook_TakeSnapshot = dku::Hook::AddVMTHook(&takeSnapshotVtbl, 1, FUNC_INFO(Hook_TakeSnapshot));
			_TakeSnapshot = reinterpret_cast<decltype(&Hook_TakeSnapshot)>(_Hook_TakeSnapshot->OldAddress);
			_Hook_TakeSnapshot->Enable();

			// Settings UI
			_CreateMonitorSetting = dku::Hook::write_call<5>(CallSite(88728, 0x121C, 5, "CreateMonitorSetting"), Hook_CreateMonitorSetting);

			// Hide vanilla brightness, contrast and hdr brightness. Only NOP these out once we know
			// they are still the calls we expect - blanking five bytes of something else would
			// corrupt the function rather than just fail.
			const uint8_t nop5[] = { 0x90, 0x90, 0x90, 0x90, 0x90 };
			for (const auto& [offset, name] : std::initializer_list<std::pair<std::ptrdiff_t, std::string_view>>{
					 { 0x1B2E, "HideVanillaBrightness" },
					 { 0x1DAA, "HideVanillaContrast" },
					 { 0x209D, "HideVanillaHDRBrightness" } }) {
				const auto address = dku::Hook::IDToAbs(88728, offset);
				if (Offsets::IsCallSite(address, 5, name)) {
					dku::Hook::WriteData(address, nop5, 5);
				}
			}

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

			_RecreateSwapchain = dku::Hook::write_call<5>(CallSite(141998, 0xBF, 5, "RecreateSwapchain"), Hook_RecreateSwapchain);

			_ApplyRenderPassRenderState1 = dku::Hook::write_call<5>(CallSite(144651, 0x18, 5, "ApplyRenderPassRenderState1"), Hook_ApplyRenderPassRenderState1);  // CmdDraw
			_ApplyRenderPassRenderState2 = dku::Hook::write_call<5>(CallSite(144655, 0x20, 5, "ApplyRenderPassRenderState2"), Hook_ApplyRenderPassRenderState2);  // CmdDispatch

			_EndOfFrame = dku::Hook::write_call<5>(CallSite(143152, 0xCBD, 5, "EndOfFrame"), Hook_EndOfFrame);
			_PostEndOfFrame = dku::Hook::write_call<5>(CallSite(143152, 0x148F, 5, "PostEndOfFrame"), Hook_PostEndOfFrame);  // CmdEnd, was CmdEndProfilingMarker previously

			const auto scaleformCompositeRenderPassVtbl = dku::Hook::IDToAbs(497272);
			auto hookScaleformCompositeRenderPass = dku::Hook::AddVMTHook(&scaleformCompositeRenderPassVtbl, 7, FUNC_INFO(HookedScaleformCompositeRenderPass));
			_ScaleformCompositeRenderPass = reinterpret_cast<decltype(&HookedScaleformCompositeRenderPass)>(hookScaleformCompositeRenderPass->OldAddress);
			hookScaleformCompositeRenderPass->Enable();
			const auto scaleformExecuteDrawSite = hookScaleformCompositeRenderPass->OldAddress + 0x4A0;
			Offsets::IsCallSite(scaleformExecuteDrawSite, 5, "ScaleformCompositeRenderPassExecuteDraw");
			dku::Hook::write_call<5>(scaleformExecuteDrawSite, HookedScaleformCompositeRenderPassExecuteDraw);

			// fsr3 fixes
			_ffxFsr3ContextCreate = dku::Hook::write_call<5>(CallSite(144625, 0x374, 5, "ffxFsr3ContextCreate"), Hook_ffxFsr3ContextCreate);
			dku::Hook::write_call<6>(CallSite(178624, 0x3CE, 6, "CreateShaderResourceView"), Hook_CreateShaderResourceView);
			//_UnkFunc3 = dku::Hook::write_call<5>(dku::Hook::IDToAbs(1078894, 0x5DB), Hook_UnkFunc3);  // mess
			//_UnkFunc3_Internal = dku::Hook::write_call<5>(dku::Hook::IDToAbs(1722115, 0x113), Hook_UnkFunc3_Internal);  // mess

			// Starfield immediately crashes because of an unhandled assertion when any D3D12 debug layer is active
			// const uint8_t retn[] = { 0xC3 };
			// dku::Hook::WriteData(dku::Hook::IDToAbs(140240), retn, 1);

			if (const auto failures = Offsets::GetResolveFailureCount(); failures > 0) {
				WARN("Hooks: finished with {} failed address validation(s) in total, expect broken or missing features", failures)
			} else {
				INFO("Hooks: all hook sites validated")
			}
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
