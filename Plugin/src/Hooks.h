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
			const auto scan = static_cast<uint8_t*>(dku::Hook::Assembly::search_pattern<"E8 ?? ?? ?? ?? 8B 4D A8 8B 45 AC">());
			if (!scan) {
				ERROR("Failed to find color space hook")
			}
			const auto callsiteOffset = *reinterpret_cast<int32_t*>(scan + 1);
			const auto UnkFuncCallsite = AsAddress(scan + 5 + callsiteOffset + 0x3EA);

			_UnkFunc = dku::Hook::write_call<5>(UnkFuncCallsite, Hook_UnkFunc);  // 32E7856

			INFO("Found color space hook callsite at {:X}", UnkFuncCallsite)

			_CreateDataModelOptions = dku::Hook::write_call<5>(dku::Hook::Module::get().base() + 0x20BD2F9, Hook_CreateDataModelOptions);
			_SettingsDataModelBoolEvent = dku::Hook::write_call<5>(dku::Hook::Module::get().base() + 0x20CB63E, Hook_SettingsDataModelBoolEvent);
			_SettingsDataModelIntEvent = dku::Hook::write_call<5>(dku::Hook::Module::get().base() + 0x20CB937, Hook_SettingsDataModelIntEvent);
			_SettingsDataModelFloatEvent = dku::Hook::write_call<5>(dku::Hook::Module::get().base() + 0x20CB8EB, Hook_SettingsDataModelFloatEvent);
		}

	private:
	    static inline RE::BGSSwapChainObject* swapChainObject = nullptr;

		static void RecreateSwapChain(RE::BGSSwapChainObject* a_bgsSwapchainObject, RE::BS_DXGI_FORMAT a_newFormat);
		static void ToggleEnableHDRSubSettings(RE::SettingsDataModel* a_model, bool a_bEnable);

		static void Hook_UnkFunc(uintptr_t a1, RE::BGSSwapChainObject* a_bgsSwapchainObject);
		static inline std::add_pointer_t<decltype(Hook_UnkFunc)> _UnkFunc;

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
			_SettingsDataModelBoolEvent = dku::Hook::write_call<5>(dku::Hook::Module::get().base() + 0x20CB63E, Hook_SettingsDataModelBoolEvent);
			_SettingsDataModelIntEvent = dku::Hook::write_call<5>(dku::Hook::Module::get().base() + 0x20CB937, Hook_SettingsDataModelIntEvent);
			_SettingsDataModelFloatEvent = dku::Hook::write_call<5>(dku::Hook::Module::get().base() + 0x20CB8EB, Hook_SettingsDataModelFloatEvent);

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