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

			switch (*settings->FrameBufferFormat) {
			case 1:
                Utils::SetBufferFormat(RE::Buffers::FrameBuffer, RE::BS_DXGI_FORMAT::BS_DXGI_FORMAT_R10G10B10A2_UNORM);
                break;
			case 2:
                Utils::SetBufferFormat(RE::Buffers::FrameBuffer, RE::BS_DXGI_FORMAT::BS_DXGI_FORMAT_R16G16B16A16_FLOAT);
				break;
			}

			switch (*settings->ImageSpaceBufferFormat) {
			case 1:
                Utils::SetBufferFormat(RE::Buffers::ImageSpaceBuffer, RE::BS_DXGI_FORMAT::BS_DXGI_FORMAT_R10G10B10A2_UNORM);
				break;
			case 2:
                Utils::SetBufferFormat(RE::Buffers::ImageSpaceBuffer, RE::BS_DXGI_FORMAT::BS_DXGI_FORMAT_R16G16B16A16_FLOAT);
				break;
			}

			if (*settings->UpgradeUIRenderTarget) {
                Utils::SetBufferFormat(RE::Buffers::ScaleformCompositeBuffer, RE::BS_DXGI_FORMAT::BS_DXGI_FORMAT_R16G16B16A16_FLOAT);
			}

			{
				if (*settings->UpgradeRenderTargets > 0) {
					const bool bLimited = *settings->UpgradeRenderTargets == 1 ? true : false;
					const RE::BS_DXGI_FORMAT format = *settings->UpgradeRenderTargets == 1 ? RE::BS_DXGI_FORMAT::BS_DXGI_FORMAT_R10G10B10A2_UNORM : RE::BS_DXGI_FORMAT::BS_DXGI_FORMAT_R16G16B16A16_FLOAT;

					for (const auto& renderTargetName : settings->RenderTargetsToUpgrade.get_collection()) {
					    if (auto buffer = GetBufferFromString(renderTargetName)) {
							UpgradeRenderTarget(buffer, format, bLimited);
					    }
                    }
				}
			}

			Utils::LogBuffers();
		}

	private:
		static RE::BufferDefinition* GetBufferFromString(std::string_view a_bufferName);

		static void UpgradeRenderTarget(RE::BufferDefinition* a_buffer, RE::BS_DXGI_FORMAT a_format, bool a_bLimited);
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
			auto _Hook_TakeSnapshot = dku::Hook::AddVMTHook(&takeSnapshotVtbl, 1, FUNC_INFO(Hook_TakeSnapshot));
			_TakeSnapshot = reinterpret_cast<std::add_pointer_t<decltype(Hook_TakeSnapshot)>>(_Hook_TakeSnapshot->OldAddress);
			_Hook_TakeSnapshot->Enable();

			// Settings UI
			_CreateDataModelOptions = dku::Hook::write_call<5>(dku::Hook::IDToAbs(135915, 0x89), Hook_CreateDataModelOptions);
			_SettingsDataModelBoolEvent = dku::Hook::write_call<5>(dku::Hook::IDToAbs(136121, 0x3A), Hook_SettingsDataModelBoolEvent);
			_SettingsDataModelIntEvent = dku::Hook::write_call<5>(dku::Hook::IDToAbs(136131, 0x37), Hook_SettingsDataModelIntEvent);
			_SettingsDataModelFloatEvent = dku::Hook::write_call<5>(dku::Hook::IDToAbs(136130, 0x37), Hook_SettingsDataModelFloatEvent);

			_RecreateSwapchain = dku::Hook::write_call<5>(dku::Hook::IDToAbs(203027, 0x89), Hook_RecreateSwapchain);
		}

	private:
	    static inline RE::BGSSwapChainObject* swapChainObject = nullptr;

		static void ToggleEnableHDRSubSettings(RE::SettingsDataModel* a_model, bool a_bEnable);

		static void Hook_UnkFunc(uintptr_t a1, RE::BGSSwapChainObject* a_bgsSwapchainObject);
		static inline std::add_pointer_t<decltype(Hook_UnkFunc)> _UnkFunc;

		static bool Hook_TakeSnapshot(uintptr_t a1);
		static inline std::add_pointer_t<decltype(Hook_TakeSnapshot)> _TakeSnapshot;

		static void Hook_RecreateSwapchain(void* a1, RE::BGSSwapChainObject* a_bgsSwapChainObject, uint32_t a_width, uint32_t a_height, uint8_t a5);
		static inline std::add_pointer_t<decltype(Hook_RecreateSwapchain)> _RecreateSwapchain;

		static void Hook_CreateDataModelOptions(void* a_arg1, RE::ArrayNestedUIValue<RE::SubSettingsList::GeneralSetting, 0>& a_SettingList);
		static inline std::add_pointer_t<decltype(Hook_CreateDataModelOptions)> _CreateDataModelOptions;
		static void Hook_SettingsDataModelBoolEvent(void* a_arg1, RE::SettingsDataModel::UpdateEventData& EventData);
		static inline std::add_pointer_t<decltype(Hook_SettingsDataModelBoolEvent)> _SettingsDataModelBoolEvent;
		static void Hook_SettingsDataModelIntEvent(void* a_arg1, RE::SettingsDataModel::UpdateEventData& EventData);
		static inline std::add_pointer_t<decltype(Hook_SettingsDataModelIntEvent)> _SettingsDataModelIntEvent;
		static void Hook_SettingsDataModelFloatEvent(void* a_arg1, RE::SettingsDataModel::UpdateEventData& EventData);
		static inline std::add_pointer_t<decltype(Hook_SettingsDataModelFloatEvent)> _SettingsDataModelFloatEvent;
	};

	class DebugHooks
	{
	public:
		static void Hook()
		{
			//_CreateDataModelOptions = dku::Hook::write_call<5>(dku::Hook::Module::get().base() + 0x20BD2F9, Hook_CreateDataModelOptions);
			//_SettingsDataModelBoolEvent = dku::Hook::write_call<5>(dku::Hook::Module::get().base() + 0x20CB63E, Hook_SettingsDataModelBoolEvent);
			//_SettingsDataModelIntEvent = dku::Hook::write_call<5>(dku::Hook::Module::get().base() + 0x20CB937, Hook_SettingsDataModelIntEvent);
			//_SettingsDataModelFloatEvent = dku::Hook::write_call<5>(dku::Hook::Module::get().base() + 0x20CB8EB, Hook_SettingsDataModelFloatEvent);

#if 0
			const auto callsite1 = AsAddress(dku::Hook::Module::get().base() + 0x32ED294);
			const auto callsite2 = AsAddress(dku::Hook::Module::get().base() + 0x32ED341);
			const auto callsite3 = AsAddress(dku::Hook::Module::get().base() + 0x32ED2C1);
			const auto callsite4 = AsAddress(dku::Hook::Module::get().base() + 0x32ED37F);

			_CreateRenderTargetView = dku::Hook::write_call<5>(callsite1, Hook_CreateRenderTargetView);
			dku::Hook::write_call<5>(callsite2, Hook_CreateRenderTargetView);
			_CreateDepthStencilView = dku::Hook::write_call<5>(callsite3, Hook_CreateDepthStencilView);
			dku::Hook::write_call<5>(callsite4, Hook_CreateDepthStencilView);
#endif
		}

	private:
		static void Hook_CreateDataModelOptions(void* a_arg1, RE::ArrayNestedUIValue<RE::SubSettingsList::GeneralSetting, 0>& a_SettingList);
		static inline std::add_pointer_t<decltype(Hook_CreateDataModelOptions)> _CreateDataModelOptions;
		static void Hook_SettingsDataModelBoolEvent(void* a_arg1, RE::SettingsDataModel::UpdateEventData& EventData);
		static inline std::add_pointer_t<decltype(Hook_SettingsDataModelBoolEvent)> _SettingsDataModelBoolEvent;
		static void Hook_SettingsDataModelIntEvent(void* a_arg1, RE::SettingsDataModel::UpdateEventData& EventData);
		static inline std::add_pointer_t<decltype(Hook_SettingsDataModelIntEvent)> _SettingsDataModelIntEvent;
		static void Hook_SettingsDataModelFloatEvent(void* a_arg1, RE::SettingsDataModel::UpdateEventData& EventData);
		static inline std::add_pointer_t<decltype(Hook_SettingsDataModelFloatEvent)> _SettingsDataModelFloatEvent;

		static void Hook_CreateRenderTargetView(uintptr_t a1, ID3D12Resource* a_resource, DXGI_FORMAT a_format, uint8_t a4, uint16_t a5, uintptr_t a6);
		static void Hook_CreateDepthStencilView(uintptr_t a1, ID3D12Resource* a_resource, DXGI_FORMAT a_format, uint8_t a4, uint16_t a5, uintptr_t a6);
		static inline std::add_pointer_t<decltype(Hook_CreateRenderTargetView)> _CreateRenderTargetView;
		static inline std::add_pointer_t<decltype(Hook_CreateDepthStencilView)> _CreateDepthStencilView;
	};

	void Install();
}
