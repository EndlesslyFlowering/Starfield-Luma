#include <wincodec.h>

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

    void Hooks::ToggleEnableHDRSubSettings(RE::SettingsDataModel* a_model, bool a_bDisplayModeHDREnable, bool a_bGameRenderingHDREnable, bool a_bSDRForcedOnHDR)
    {
		if (const auto peakBrightnessSetting = a_model->FindSettingById(static_cast<int>(Settings::SettingID::kHDR_PeakBrightness))) {
			peakBrightnessSetting->m_Enabled.SetValue(a_bGameRenderingHDREnable);
		}

		if (const auto gamePaperWhiteSetting = a_model->FindSettingById(static_cast<int>(Settings::SettingID::kHDR_GamePaperWhite))) {
			gamePaperWhiteSetting->m_Enabled.SetValue(a_bDisplayModeHDREnable || a_bSDRForcedOnHDR);
		}

		if (const auto uiPaperWhiteSetting = a_model->FindSettingById(static_cast<int>(Settings::SettingID::kHDR_UIPaperWhite))) {
			uiPaperWhiteSetting->m_Enabled.SetValue(a_bGameRenderingHDREnable);
		}

		if (const auto extendGamut = a_model->FindSettingById(static_cast<int>(Settings::SettingID::kHDR_ExtendGamut))) {
			extendGamut->m_Enabled.SetValue(a_bGameRenderingHDREnable);
		}

		if (const auto secondaryBrightnessSetting = a_model->FindSettingById(static_cast<int>(Settings::SettingID::kSecondaryBrightness))) {
			secondaryBrightnessSetting->m_Enabled.SetValue(!a_bGameRenderingHDREnable);
		}

		if (const auto strictLUTApplicationSetting = a_model->FindSettingById(static_cast<int>(Settings::SettingID::kStrictLUTApplication))) {
			strictLUTApplicationSetting->m_Enabled.SetValue(a_bGameRenderingHDREnable);
		}
    }

		void Hooks::CheckCustomToneMapperSettings(RE::SettingsDataModel* a_model, bool a_bIsCustomToneMapper)
		{
			if (const auto toneMapperHighlights = a_model->FindSettingById(static_cast<int>(Settings::SettingID::kToneMapperHighlights)))
			{
				toneMapperHighlights->m_Enabled.SetValue(a_bIsCustomToneMapper);
			}
			if (const auto toneMapperShadows = a_model->FindSettingById(static_cast<int>(Settings::SettingID::kToneMapperShadows)))
			{
				toneMapperShadows->m_Enabled.SetValue(a_bIsCustomToneMapper);
			}
		}

    void Hooks::CreateCheckboxSetting(RE::ArrayNestedUIValue<RE::SubSettingsList::GeneralSetting, 0>* a_settingList, Settings::Checkbox& a_setting, bool a_bEnabled)
    {
		auto& s = *(new (alloca(sizeof(RE::SubSettingsList::GeneralSetting))) RE::SubSettingsList::GeneralSetting());

		s.m_Text.SetStringValue(a_setting.name.c_str());
		s.m_Description.SetStringValue(a_setting.description.c_str());
		s.m_ID.SetValue(static_cast<unsigned int>(a_setting.id));
		s.m_Type.SetValue(RE::SubSettingsList::GeneralSetting::Type::Checkbox);
		s.m_Category.SetValue(RE::SubSettingsList::GeneralSetting::Category::Display);
		s.m_Enabled.SetValue(a_bEnabled);
		s.m_CheckBoxData.m_ShuttleMap.GetData().m_Value.SetValue(a_setting.value.get_data());
		a_settingList->AddItem(s);
    }

    void Hooks::CreateStepperSetting(RE::ArrayNestedUIValue<RE::SubSettingsList::GeneralSetting, 0>* a_settingList, Settings::Stepper& a_setting, bool a_bEnabled)
    {
		auto& s = *(new (alloca(sizeof(RE::SubSettingsList::GeneralSetting))) RE::SubSettingsList::GeneralSetting());

		s.m_Text.SetStringValue(a_setting.name.c_str());
		s.m_Description.SetStringValue(a_setting.description.c_str());
		s.m_ID.SetValue(static_cast<unsigned int>(a_setting.id));
		s.m_Type.SetValue(RE::SubSettingsList::GeneralSetting::Type::Stepper);
		s.m_Category.SetValue(RE::SubSettingsList::GeneralSetting::Category::Display);
		s.m_Enabled.SetValue(a_bEnabled);
		for (auto i = 0; i < a_setting.GetNumOptions(); ++i) {
			s.m_StepperData.m_ShuttleMap.GetData().m_DisplayValues.AddItem(a_setting.GetStepperText(i).c_str());
		}
		s.m_StepperData.m_ShuttleMap.GetData().m_Value.SetValue(a_setting.GetCurrentStepFromValue());
		a_settingList->AddItem(s);
    }

    void Hooks::CreateSliderSetting(RE::ArrayNestedUIValue<RE::SubSettingsList::GeneralSetting, 0>* a_settingList, Settings::Slider& a_setting, bool a_bEnabled)
    {
		auto& s = *(new (alloca(sizeof(RE::SubSettingsList::GeneralSetting))) RE::SubSettingsList::GeneralSetting());

		s.m_Text.SetStringValue(a_setting.name.c_str());
		s.m_Description.SetStringValue(a_setting.description.c_str());
		s.m_ID.SetValue(static_cast<unsigned int>(a_setting.id));
		s.m_Type.SetValue(RE::SubSettingsList::GeneralSetting::Type::Slider);
		s.m_Category.SetValue(RE::SubSettingsList::GeneralSetting::Category::Display);
		s.m_Enabled.SetValue(a_bEnabled);
		s.m_SliderData.m_ShuttleMap.GetData().m_Value.SetValue(a_setting.GetSliderPercentage());
		s.m_SliderData.m_ShuttleMap.GetData().m_DisplayValue.SetStringValue(a_setting.GetSliderText().c_str());
		a_settingList->AddItem(s);
    }

    void Hooks::CreateSeparator(RE::ArrayNestedUIValue<RE::SubSettingsList::GeneralSetting, 0>* a_settingList, Settings::SettingID a_id)
    {
		auto& s = *(new (alloca(sizeof(RE::SubSettingsList::GeneralSetting))) RE::SubSettingsList::GeneralSetting());

		s.m_Text.SetStringValue("");
		s.m_Description.SetStringValue("");
		s.m_ID.SetValue(static_cast<unsigned int>(a_id));
		s.m_Type.SetValue(RE::SubSettingsList::GeneralSetting::Type::LargeStepper);
		s.m_Category.SetValue(RE::SubSettingsList::GeneralSetting::Category::Display);
		s.m_Enabled.SetValue(false);
		a_settingList->AddItem(s);
    }

    void Hooks::CreateSettings(RE::ArrayNestedUIValue<RE::SubSettingsList::GeneralSetting, 0>* a_settingList)
    {
		const auto settings = Settings::Main::GetSingleton();

		CreateSeparator(a_settingList, Settings::SettingID::kSTART);

		// We don't expose "DevSetting*" or "ForceSDROnHDR" to the game settings, they'd just confuse users
		CreateStepperSetting(a_settingList, settings->DisplayMode, settings->IsHDRSupported() && !settings->IsSDRForcedOnHDR());
		CreateStepperSetting(a_settingList, settings->PeakBrightness, settings->IsGameRenderingSetToHDR());
		CreateStepperSetting(a_settingList, settings->GamePaperWhite, settings->IsDisplayModeSetToHDR() || settings->IsSDRForcedOnHDR());
		CreateStepperSetting(a_settingList, settings->UIPaperWhite, settings->IsGameRenderingSetToHDR());
		CreateSliderSetting(a_settingList, settings->ExtendGamut, settings->IsGameRenderingSetToHDR());

		CreateSliderSetting(a_settingList, settings->SecondaryBrightness, !settings->IsGameRenderingSetToHDR());

		CreateStepperSetting(a_settingList, settings->ToneMapperType, true);
		CreateSliderSetting(a_settingList, settings->Saturation, true); // Requires "CLAMP_INPUT_OUTPUT_TYPE" 1 in shaders (gamut mapping) if we are rendering to SDR
		CreateSliderSetting(a_settingList, settings->Contrast, true); // Requires "CLAMP_INPUT_OUTPUT_TYPE" 1 in shaders (gamut mapping) if we are rendering to SDR
		CreateSliderSetting(a_settingList, settings->Highlights, settings->IsCustomToneMapper());
		CreateSliderSetting(a_settingList, settings->Shadows, settings->IsCustomToneMapper());
		CreateSliderSetting(a_settingList, settings->Bloom, true);

		CreateSliderSetting(a_settingList, settings->ColorGradingStrength, true);
		CreateSliderSetting(a_settingList, settings->LUTCorrectionStrength, true);
		CreateCheckboxSetting(a_settingList, settings->VanillaMenuLUTs, true);
		CreateCheckboxSetting(a_settingList, settings->StrictLUTApplication, settings->IsGameRenderingSetToHDR());

		CreateSliderSetting(a_settingList, settings->GammaCorrectionStrength, true);
		CreateStepperSetting(a_settingList, settings->FilmGrainType, true);
		CreateSliderSetting(a_settingList, settings->FilmGrainFPSLimit, settings->IsFilmGrainTypeImproved());
		CreateCheckboxSetting(a_settingList, settings->PostSharpen, true);

		CreateSeparator(a_settingList, Settings::SettingID::kEND);
    }

	struct ScreenshotData
	{
		std::string                                                                                   FileName;
		std::function<void(ID3D12CommandQueue*, ID3D12Resource*, D3D12_RESOURCE_STATES, std::string)> Callback;
		ID3D12Resource*                                                                               TextureCopy;
		uint64_t                                                                                      CaptureFrameIndex;
	};

	static std::string                 screenshotName;
	static std::vector<ScreenshotData> pendingScreenshots;

	bool CheckForScreenshotRequest(ID3D12Device2* a_device, ID3D12CommandQueue* a_queue, ID3D12GraphicsCommandList* a_commandList, ID3D12Resource* a_sourceTexture)
	{
		static uint64_t currentFrameCounter = 0;
		currentFrameCounter++;

		decltype(ScreenshotData::Callback) screenshotCallback;
		bool                               screenshotEnqueued = false;
		const auto                         settings = Settings::Main::GetSingleton();

		if (settings->bRequestedHDRScreenshot) {
			screenshotCallback = &Utils::TakeHDRPhotoModeScreenshot;
		} else if (settings->bRequestedSDRScreenshot) {
			screenshotCallback = &Utils::TakeSDRPhotoModeScreenshot;
		}

		// Capture texture data on the GPU side initially
		if (screenshotCallback) {
			ID3D12Resource* texture = nullptr;
			auto textureDesc = a_sourceTexture->GetDesc();

			if (textureDesc.Format == DXGI_FORMAT_R10G10B10A2_TYPELESS) {
				textureDesc.Format = DXGI_FORMAT_R10G10B10A2_UNORM;
			}
			else if (textureDesc.Format == DXGI_FORMAT_R16G16B16A16_TYPELESS) {
				textureDesc.Format = DXGI_FORMAT_R16G16B16A16_FLOAT;
			}

			const D3D12_HEAP_PROPERTIES heapProperties = {
				.Type = D3D12_HEAP_TYPE_DEFAULT,
				.CPUPageProperty = D3D12_CPU_PAGE_PROPERTY_UNKNOWN,
				.MemoryPoolPreference = D3D12_MEMORY_POOL_UNKNOWN,
			};

			if (SUCCEEDED(a_device->CreateCommittedResource(
					&heapProperties,
					D3D12_HEAP_FLAG_NONE,
					&textureDesc,
					D3D12_RESOURCE_STATE_COPY_DEST,
					nullptr,
					IID_PPV_ARGS(&texture)))) {
				// We're assuming the input is always a render target
				D3D12_RESOURCE_BARRIER barrier = {};
				barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
				barrier.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE;
				barrier.Transition.pResource = a_sourceTexture;
				barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
				barrier.Transition.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET;
				barrier.Transition.StateAfter = D3D12_RESOURCE_STATE_COPY_SOURCE;

				a_commandList->ResourceBarrier(1, &barrier);
				a_commandList->CopyResource(texture, a_sourceTexture);
				std::swap(barrier.Transition.StateBefore, barrier.Transition.StateAfter);
				a_commandList->ResourceBarrier(1, &barrier);
			}

			pendingScreenshots.emplace_back(ScreenshotData{
				screenshotName,
				screenshotCallback,
				texture,
				currentFrameCounter });

			screenshotEnqueued = true;
		}

		// Allow eight frames to pass before attempting a CPU readback. Ideally a fence would be issued on the
		// command queue, but that's not possible without a lot of reverse engineering work.
		for (auto itr = pendingScreenshots.begin(); itr != pendingScreenshots.end();) {
			if ((currentFrameCounter - itr->CaptureFrameIndex) >= 8) {
				// Callback releases the texture
				std::thread(itr->Callback, a_queue, itr->TextureCopy, D3D12_RESOURCE_STATE_COPY_DEST, itr->FileName).detach();

				itr = pendingScreenshots.erase(itr);
			} else {
				itr++;
			}
		}

		return screenshotEnqueued;
	}

	struct DescriptorAllocation
	{
		enum class Type : uint8_t
		{
			Sampler = 0,
			CbvSrvUav = 1,
		};

		D3D12_CPU_DESCRIPTOR_HANDLE CpuHandleBase;
		D3D12_GPU_DESCRIPTOR_HANDLE GpuHandleBase;
	};

	struct Dx12Resource
	{
		char _pad0[0x48];                // 0
		int  m_CpuDescriptorArrayCount;  // 48 Greater than 0 (msb bit) indicates an array
		union
		{
			D3D12_CPU_DESCRIPTOR_HANDLE  m_CpuDescriptor;       // 50 Possibly mip levels? No idea w.r.t. its purpose
			D3D12_CPU_DESCRIPTOR_HANDLE* m_CpuDescriptorArray;  // 50
		};
		char _pad1[0x8];                    // 58
		int  m_UAVCpuDescriptorArrayCount;  // 60
		union
		{
			D3D12_CPU_DESCRIPTOR_HANDLE  m_UAVCpuDescriptor;       // 68
			D3D12_CPU_DESCRIPTOR_HANDLE* m_UAVCpuDescriptorArray;  // 68
		};
		char            _pad2[0x8];  // 70
		ID3D12Resource* m_Resource;  // 78
	};
	static_assert(offsetof(Dx12Resource, m_CpuDescriptorArrayCount) == 0x48);
	static_assert(offsetof(Dx12Resource, m_UAVCpuDescriptor) == 0x68);
	static_assert(offsetof(Dx12Resource, m_Resource) == 0x78);

	thread_local Dx12Resource *ScaleformCompositeRenderTarget;

	void Hooks::HookedScaleformCompositeSetRenderTarget(void* a1, void* a2, void** a_rtArray, void* a4, void* a5, void* a6, void* a7, void* a8, void* a9)
	{
		ScaleformCompositeRenderTarget = *reinterpret_cast<Dx12Resource**>(reinterpret_cast<uintptr_t>(a_rtArray[0]) + 0x48);

		// Ignore render target sets. They're going to be overwritten anyway.
		//_ScaleformCompositeSetRenderTarget(a1, a2, a_rtArray, a4, a5, a6, a7, a8, a9);
	}

	void Hooks::HookedScaleformCompositeDraw(void* a_arg1, void* a_arg2, uint32_t a_vertexCount)
	{
		auto creationRendererInstance = *reinterpret_cast<uintptr_t*>(reinterpret_cast<uintptr_t>(a_arg1) + 0x0);
		auto device = *reinterpret_cast<ID3D12Device2**>(creationRendererInstance + 0x3A0);

		auto commandList = *reinterpret_cast<ID3D12GraphicsCommandList**>(reinterpret_cast<uintptr_t>(a_arg1) + 0x10);

		auto getDescriptorManager = [&]() {
			const auto v1 = *reinterpret_cast<uintptr_t*>(reinterpret_cast<uintptr_t>(a_arg1) + 0x8);
			return *reinterpret_cast<void**>(v1 + 0x18);
		};

		auto getCommandQueue = [&]() {
			const auto v1 = *reinterpret_cast<uintptr_t*>(reinterpret_cast<uintptr_t>(a_arg1) + 0x8);
			const auto v2 = *reinterpret_cast<uintptr_t*>(v1 + 0x10);
			return *reinterpret_cast<ID3D12CommandQueue**>(v2 + 0x28);
		};

		auto getBoundShaderResource = [&](uint32_t a_index) {
			const auto v1 = *reinterpret_cast<uintptr_t*>(reinterpret_cast<uintptr_t>(a_arg2) + 0x30);
			const auto v2 = *reinterpret_cast<uintptr_t*>(v1 + 0x10) + 24 * *(uint32_t*)(*(uintptr_t*)v1 + (4 * a_index) + 0x20);
			return *reinterpret_cast<Dx12Resource**>(v2 + 0x8);
		};

		using AllocateDescriptors_t = void (*)(void*, DescriptorAllocation&, uint32_t, DescriptorAllocation::Type, uint32_t&);
		auto allocateDescriptors = reinterpret_cast<AllocateDescriptors_t>(dku::Hook::IDToAbs(207691));

		// This seems to be the best place to shove our screenshot code in. It's not worth adding new hooks.
		bool bScreenshotMade = CheckForScreenshotRequest(device, getCommandQueue(), commandList, ScaleformCompositeRenderTarget->m_Resource);

		if (Hook_ApplyRenderPassRenderState1(a_arg1, a_arg2)) {
			// Remove all render targets; we're treating this pixel shader as a compute shader. All RT writes end
			// up discarded.
			//
			// The ScaleformComposite pass contains exactly one draw so we can safely unbind them without informing
			// the game. Game code also happens to unbind RTs immediately after the hook.
			commandList->OMSetRenderTargets(0, nullptr, false, nullptr);

			// Instead of creating copies and worrying about resource allocations, bind the original RT and SRV as
			// UAVs that can be modified in-place.
			DescriptorAllocation alloc;
			uint32_t             handleSizeIncrement;
			allocateDescriptors(getDescriptorManager(), alloc, 2, DescriptorAllocation::Type::CbvSrvUav, handleSizeIncrement);

			alloc.CpuHandleBase.ptr += (0 * handleSizeIncrement);
			device->CopyDescriptorsSimple(1, alloc.CpuHandleBase, getBoundShaderResource(0)->m_CpuDescriptor, D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

			alloc.CpuHandleBase.ptr += (1 * handleSizeIncrement);
			device->CopyDescriptorsSimple(1, alloc.CpuHandleBase, ScaleformCompositeRenderTarget->m_UAVCpuDescriptor, D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

			D3D12_RESOURCE_BARRIER barrier = {};
			barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
			barrier.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE;
			barrier.Transition.pResource = ScaleformCompositeRenderTarget->m_Resource;
			barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
			barrier.Transition.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET;
			barrier.Transition.StateAfter = D3D12_RESOURCE_STATE_UNORDERED_ACCESS;

			commandList->ResourceBarrier(1, &barrier);
			commandList->SetGraphicsRootDescriptorTable(1, alloc.GpuHandleBase); // Hardcoded in ScaleformComposite\RootSignature.hlsl
			commandList->DrawInstanced(a_vertexCount, 1, 0, 0);
			std::swap(barrier.Transition.StateBefore, barrier.Transition.StateAfter);
			commandList->ResourceBarrier(1, &barrier);
		}

		if (bScreenshotMade) {
			const auto settings = Settings::Main::GetSingleton();
			if (!settings->bRequestedHDRScreenshot.exchange(false)) {
				settings->bRequestedSDRScreenshot.exchange(false);
			}
		}
	}

    void Hooks::UploadRootConstants(void* a1, void* a2)
    {
		const auto technique = *reinterpret_cast<uintptr_t*>(reinterpret_cast<uintptr_t>(a2) + 0x8);
		const auto techniqueId = *reinterpret_cast<uint64_t*>(technique + 0x60);

		auto uploadRootConstants = [&](const Settings::ShaderConstants& a_shaderConstants, uint32_t a_rootParameterIndex, bool a_bCompute) {
			auto commandList = *reinterpret_cast<ID3D12GraphicsCommandList**>(reinterpret_cast<uintptr_t>(a1) + 0x10);

			if (!a_bCompute)
				commandList->SetGraphicsRoot32BitConstants(a_rootParameterIndex, Settings::shaderConstantsCount, &a_shaderConstants, 0);
			else
				commandList->SetComputeRoot32BitConstants(a_rootParameterIndex, Settings::shaderConstantsCount, &a_shaderConstants, 0);
		};

		// Note: The following switch statement may be called several thousand times per frame. Additionally, it'll be called from multiple
		// threads concurrently. The individual cases are called at most once or twice per frame. Keep the amount of code here fairly light.
		//
		// RootParameterIndex is the index of our custom RootConstants() entry in the root signature. It's taken from the corresponding
		// RootSignature.hlsl file stored next to each technique hlsl file.
		switch (techniqueId) {
		case 0x1FE1A:
		case 0xC01FE1A:
		case 0xE01FE1A:
		case 0x1001FE1A:
		case 0x1C01FE1A:
		case 0x1E01FE1A:
			{
				Settings::ShaderConstants shaderConstants;
				const auto settings = Settings::Main::GetSingleton();
				settings->GetShaderConstants(shaderConstants);
				if (*settings->VanillaMenuLUTs.value && !Utils::ShouldCorrectLUTs()) {
				    shaderConstants.LUTCorrectionStrength = 0.f;
					shaderConstants.ColorGradingStrength = 1.f;
				}
				uploadRootConstants(shaderConstants, 14, false);  // HDRComposite
				break;
			}

		case 0x801FE57:
		case 0x4001FE57:
			{
				Settings::ShaderConstants shaderConstants;
				Settings::Main::GetSingleton()->GetShaderConstants(shaderConstants);
				uploadRootConstants(shaderConstants, 2, false);  // Copy
				break;
			}

		case 0x1FE73:
			{
				Settings::ShaderConstants shaderConstants;
				Settings::Main::GetSingleton()->GetShaderConstants(shaderConstants);
				uploadRootConstants(shaderConstants, 2, false);  // FilmGrain
				break;
			}

		case 0x1FE86:
		case 0x1FE87:
			{
				Settings::ShaderConstants shaderConstants;
				const auto settings = Settings::Main::GetSingleton();
				settings->GetShaderConstants(shaderConstants);
				if (*settings->VanillaMenuLUTs.value && !Utils::ShouldCorrectLUTs()) {
				    shaderConstants.LUTCorrectionStrength = 0.f;
				    shaderConstants.ColorGradingStrength = 1.f;
				}
				uploadRootConstants(shaderConstants, 7, true);  // ColorGradingMerge / HDRColorGradingMerge
				break;
			}

		case 0x1FE96:
		case 0x201FE96:
		case 0x401FE96:
		case 0x601FE96:
			{
				Settings::ShaderConstants shaderConstants;
				Settings::Main::GetSingleton()->GetShaderConstants(shaderConstants);
				uploadRootConstants(shaderConstants, 14, true);  // ContrastAdaptiveSharpening
				break;
			}

		case 0x1FE9C:
			{
				Settings::ShaderConstants shaderConstants;
				Settings::Main::GetSingleton()->GetShaderConstants(shaderConstants);
				uploadRootConstants(shaderConstants, 14, false);  // PostSharpen
				break;
			}

		case 0x1FEAC:
			{
				Settings::ShaderConstants shaderConstants;
				Settings::Main::GetSingleton()->GetShaderConstants(shaderConstants);
				uploadRootConstants(shaderConstants, 2, false);  // ScaleformComposite
				break;
			}

		case 0x1FEAD:
			{
				Settings::ShaderConstants shaderConstants;
				Settings::Main::GetSingleton()->GetShaderConstants(shaderConstants);
				uploadRootConstants(shaderConstants, 2, false);  // BinkMovie
				break;
			}
		}
    }

    void Hooks::Hook_UnkFunc(uintptr_t a1, RE::BGSSwapChainObject* a_bgsSwapchainObject)
    {
		const auto settings = Settings::Main::GetSingleton();
		settings->InitCompatibility(a_bgsSwapchainObject);

		a_bgsSwapchainObject->swapChainInterface->SetColorSpace1(settings->GetDisplayModeColorSpaceType());

		settings->RegisterReshadeOverlay();

		return _UnkFunc(a1, a_bgsSwapchainObject);
    }

    void Hooks::Hook_UnkFunc2(uint64_t a1, uint64_t a2)
	{
		_UnkFunc2(a1, a2);

		const auto settings = Settings::Main::GetSingleton();

		Utils::SetBufferFormat(RE::Buffers::FrameBuffer, settings->GetDisplayModeFormat());
	}

    bool Hooks::Hook_TakeSnapshot(uintptr_t a1)
    {
		const auto settings = Settings::Main::GetSingleton();
		screenshotName = Utils::GetPhotoModeScreenshotName();
		if (settings->IsDisplayModeSetToHDR() && *settings->HDRScreenshots.value) {
			settings->bRequestedHDRScreenshot.store(true);
		}
		settings->bRequestedSDRScreenshot.store(true);

		// hack to refresh the UI visibility after the snapshot
		Offsets::PhotoMode_ToggleUI(a1 + 0x8);
		Offsets::PhotoMode_ToggleUI(a1 + 0x8);

		return true;
        //return _TakeSnapshot(a1);
    }

    void Hooks::Hook_RecreateSwapchain(void* a1, RE::BGSSwapChainObject* a_bgsSwapChainObject, uint32_t a_width, uint32_t a_height, uint8_t a5)
    {
		_RecreateSwapchain(a1, a_bgsSwapChainObject, a_width, a_height, a5);

		const auto settings = Settings::Main::GetSingleton();
		// Note: this might actually engage HDR on the display automatically on AMD GPUs
		a_bgsSwapChainObject->swapChainInterface->SetColorSpace1(settings->GetDisplayModeColorSpaceType());
    }

    void Hooks::Hook_CreateMonitorSetting(void* a1, void* a2)
    {
		_CreateMonitorSetting(a1, a2);

		// insert our settings after
		auto* settingList = reinterpret_cast<RE::ArrayNestedUIValue<RE::SubSettingsList::GeneralSetting, 0>*>(reinterpret_cast<uintptr_t>(a1) - 0x28);
		CreateSettings(settingList);
    }

    void Hooks::Hook_SettingsDataModelCheckboxChanged(void* a_arg1, RE::SettingsDataModel::UpdateEventData& a_eventData)
    {
		const auto settings = Settings::Main::GetSingleton();

		auto HandleSetting = [&](Settings::Checkbox& a_setting) {
			const auto prevValue = a_setting.value.get_data();
			const auto newValue = a_eventData.m_Value.Bool;
			if (prevValue != newValue) {
				*a_setting.value = newValue;
				settings->Save();
				return true;
			}
			return false;
		};

		switch (a_eventData.m_SettingID) {
		case static_cast<int>(Settings::SettingID::kForceSDROnHDR):
			{
				const bool wasDisplayModeHDR = settings->IsDisplayModeSetToHDR();
				const bool wasSDRForcedOnHDR = settings->IsSDRForcedOnHDR();
				const bool wasGameRenderingHDR = settings->IsGameRenderingSetToHDR();
				if (HandleSetting(settings->ForceSDROnHDR)) {
					const bool isDisplayModeHDR = settings->IsDisplayModeSetToHDR();
					const bool isSDRForcedOnHDR = settings->IsSDRForcedOnHDR();
					const bool isGameRenderingHDR = settings->IsGameRenderingSetToHDR();
					// We probably don't need all these checks, but we are being extra sure
					if (wasDisplayModeHDR != isDisplayModeHDR || wasSDRForcedOnHDR != isSDRForcedOnHDR || wasGameRenderingHDR != isGameRenderingHDR) {
						ToggleEnableHDRSubSettings(a_eventData.m_Model, isDisplayModeHDR, isGameRenderingHDR, isSDRForcedOnHDR);
						CheckCustomToneMapperSettings(a_eventData.m_Model, settings->IsCustomToneMapper());
					}
					if (const auto displayModeSetting = a_eventData.m_Model->FindSettingById(static_cast<int>(Settings::SettingID::kDisplayMode))) {
						displayModeSetting->m_Enabled.SetValue(settings->IsHDRSupported() && !settings->IsSDRForcedOnHDR());
					}
					settings->OnDisplayModeChanged();
				}
			}
			break;
		case static_cast<int>(Settings::SettingID::kVanillaMenuLUTs):
			HandleSetting(settings->VanillaMenuLUTs);
			break;
		case static_cast<int>(Settings::SettingID::kStrictLUTApplication):
			HandleSetting(settings->StrictLUTApplication);
			break;
		case static_cast<int>(Settings::SettingID::kPostSharpen):
			HandleSetting(settings->PostSharpen);
		    break;
		case 24:  // Frame Generation
			const auto prevFramegenValue = *Offsets::uiFrameGenerationTech;
			const auto isFramegenOn = a_eventData.m_Value.Bool;
			RE::FrameGenerationTech newFramegenValue;
			if (isFramegenOn) {
				if (*Offsets::uiUpscalingTechnique == RE::UpscalingTechnique::kDLSS) {
					newFramegenValue = RE::FrameGenerationTech::kDLSSG;
				} else {
					newFramegenValue = RE::FrameGenerationTech::kFSR3;
				}
			} else {
				newFramegenValue = RE::FrameGenerationTech::kNone;
			}
			if (prevFramegenValue != newFramegenValue) {
				if (prevFramegenValue != newFramegenValue) {
					settings->RefreshSwapchainFormat(newFramegenValue);
				}
			}
			break;
		}

		_SettingsDataModelCheckboxChanged(a_arg1, a_eventData);
    }

    void Hooks::Hook_SettingsDataModelStepperChanged(void* a_arg1, RE::SettingsDataModel::UpdateEventData& a_eventData)
    {
		const auto settings = Settings::Main::GetSingleton();

		auto HandleSetting = [&](Settings::Stepper& a_setting) {
			const auto prevValue = a_setting.value.get_data();
			const auto newValue = a_setting.GetValueFromStepper(a_eventData.m_Value.Int);
			if (prevValue != newValue) {
				*a_setting.value = newValue;
				settings->Save();
				return true;
			}
			return false;
		};

		switch (a_eventData.m_SettingID) {
		case static_cast<int>(Settings::SettingID::kDisplayMode):
			{
				const bool wasDisplayModeHDR = settings->IsDisplayModeSetToHDR();
				const bool wasSDRForcedOnHDR = settings->IsSDRForcedOnHDR();
				const bool wasGameRenderingHDR = settings->IsGameRenderingSetToHDR();
				if (HandleSetting(settings->DisplayMode)) {
					const bool isDisplayModeHDR = settings->IsDisplayModeSetToHDR();
					const bool isSDRForcedOnHDR = settings->IsSDRForcedOnHDR();
					const bool isGameRenderingHDR = settings->IsGameRenderingSetToHDR();
					// We probably don't need all these checks, but we are being extra sure
					if (wasDisplayModeHDR != isDisplayModeHDR || wasSDRForcedOnHDR != isSDRForcedOnHDR || wasGameRenderingHDR != isGameRenderingHDR) {
						ToggleEnableHDRSubSettings(a_eventData.m_Model, isDisplayModeHDR, isGameRenderingHDR, isSDRForcedOnHDR);
						CheckCustomToneMapperSettings(a_eventData.m_Model, settings->IsCustomToneMapper());
					}
					if (const auto displayModeSetting = a_eventData.m_Model->FindSettingById(static_cast<int>(Settings::SettingID::kDisplayMode))) {
						displayModeSetting->m_Enabled.SetValue(settings->IsHDRSupported() && !settings->IsSDRForcedOnHDR());
					}
					settings->OnDisplayModeChanged();
				}
			}
			break;
		case static_cast<int>(Settings::SettingID::kHDR_PeakBrightness):
			HandleSetting(settings->PeakBrightness);
			break;
		case static_cast<int>(Settings::SettingID::kHDR_GamePaperWhite):
			HandleSetting(settings->GamePaperWhite);
			break;
		case static_cast<int>(Settings::SettingID::kHDR_UIPaperWhite):
			HandleSetting(settings->UIPaperWhite);
			break;
		case static_cast<int>(Settings::SettingID::kToneMapperType):
			HandleSetting(settings->ToneMapperType);
			CheckCustomToneMapperSettings(a_eventData.m_Model, settings->IsCustomToneMapper());
			break;
		case static_cast<int>(Settings::SettingID::kFilmGrainType):
			HandleSetting(settings->FilmGrainType);
			if (const auto filmGrainFPSLimit = a_eventData.m_Model->FindSettingById(static_cast<int>(Settings::SettingID::kFilmGrainFPSLimit))) {
				filmGrainFPSLimit->m_Enabled.SetValue(settings->IsFilmGrainTypeImproved());
			}
			break;
		case 22:  // Upscaling Technique
			auto getUpscalingTechnique = [](int a_settingValue) {
				switch (a_settingValue) {
				case 0:  // off
					return RE::UpscalingTechnique::kNone;
				case 1:  // CAS
					return RE::UpscalingTechnique::kCAS;
				case 2:  // FSR3
					return RE::UpscalingTechnique::kFSR3;
				case 3:  // DLSS
					return RE::UpscalingTechnique::kDLSS;
				case 4:  // XESS
					return RE::UpscalingTechnique::kXESS;
				}
			};
			const auto prevUpscalingTechnique = *Offsets::uiUpscalingTechnique;
			const auto newUpscalingTechnique = getUpscalingTechnique(a_eventData.m_Value.Int);
			if (prevUpscalingTechnique != newUpscalingTechnique && *Offsets::uiFrameGenerationTech != RE::FrameGenerationTech::kNone) {
				RE::FrameGenerationTech newFramegenValue;
				if (newUpscalingTechnique == RE::UpscalingTechnique::kDLSS) {
					newFramegenValue = RE::FrameGenerationTech::kDLSSG;
				} else if (newUpscalingTechnique == RE::UpscalingTechnique::kFSR2 || newUpscalingTechnique == RE::UpscalingTechnique::kFSR3) {
					newFramegenValue = RE::FrameGenerationTech::kFSR3;
				} else {
					newFramegenValue = RE::FrameGenerationTech::kNone;
				}
				settings->RefreshSwapchainFormat(newFramegenValue);
			}
		    break;
		}

		_SettingsDataModelStepperChanged(a_arg1, a_eventData);
    }

    bool Hooks::OnSettingsDataModelSliderChanged(RE::SettingsDataModel::UpdateEventData& a_eventData)
    {
		const auto settings = Settings::Main::GetSingleton();

		auto HandleSetting = [&](Settings::Slider& a_setting) {
			const auto prevValue = a_setting.value.get_data();
			const auto newValue = a_setting.GetValueFromSlider(a_eventData.m_Value.Float);

			if (prevValue != newValue) {
				*a_setting.value = newValue;
				settings->Save();
			}

			// Skip _SettingsDataModelSliderChanged and queue the update callback ourselves. Why, you ask? Bethesda had the
			// brilliant idea to hardcode slider option text values.
			const std::string sliderText = a_setting.GetSliderText();
			struct
			{
				int            v1;         // 0
				float          v2;         // 4
				const char*    v3;         // 8
				unsigned int   v4 = 0;     // 10
				unsigned short v5 = 1024;  // 14
			} const callbackData = {
				.v1 = a_eventData.m_SettingID,
				.v2 = a_eventData.m_Value.Float,
				.v3 = sliderText.c_str(),
			};

			const auto modelData = *reinterpret_cast<void**>(reinterpret_cast<uintptr_t>(a_eventData.m_Model) + 0x8);
			const auto func = reinterpret_cast<void (*)(void*, const void*)>(dku::Hook::IDToAbs(135746));

			if (modelData) {
				func(modelData, &callbackData);
			}
		};

		switch (a_eventData.m_SettingID) {
		case static_cast<int>(Settings::SettingID::kHDR_ExtendGamut):
			HandleSetting(settings->ExtendGamut);
			return true;
		case static_cast<int>(Settings::SettingID::kSecondaryBrightness):
			HandleSetting(settings->SecondaryBrightness);
			return true;
		case static_cast<int>(Settings::SettingID::kToneMapperSaturation):
			HandleSetting(settings->Saturation);
			return true;
		case static_cast<int>(Settings::SettingID::kToneMapperContrast):
			HandleSetting(settings->Contrast);
			return true;
		case static_cast<int>(Settings::SettingID::kToneMapperHighlights):
			HandleSetting(settings->Highlights);
			return true;
		case static_cast<int>(Settings::SettingID::kToneMapperShadows):
			HandleSetting(settings->Shadows);
			return true;
		case static_cast<int>(Settings::SettingID::kToneMapperBloom):
			HandleSetting(settings->Bloom);
			return true;
		case static_cast<int>(Settings::SettingID::kColorGradingStrength):
			HandleSetting(settings->ColorGradingStrength);
			return true;
		case static_cast<int>(Settings::SettingID::kLUTCorrectionStrength):
			HandleSetting(settings->LUTCorrectionStrength);
			return true;
		case static_cast<int>(Settings::SettingID::kGammaCorrectionStrength):
			HandleSetting(settings->GammaCorrectionStrength);
			return true;
		case static_cast<int>(Settings::SettingID::kFilmGrainFPSLimit):
			HandleSetting(settings->FilmGrainFPSLimit);
			return true;
		}

		return false;
    }

    void Hooks::Hook_SettingsDataModelSliderChanged(void* a_arg1, RE::SettingsDataModel::UpdateEventData& a_eventData)
    {
		if (!OnSettingsDataModelSliderChanged(a_eventData)) {
			_SettingsDataModelSliderChanged(a_arg1, a_eventData);
		}
    }

    bool Hooks::Hook_ApplyRenderPassRenderState1(void* a_arg1, void* a_arg2)
	{
		const bool result = _ApplyRenderPassRenderState1(a_arg1, a_arg2);

		if (result) {
			UploadRootConstants(a_arg1, a_arg2);
		}

		return result;
	}

    bool Hooks::Hook_ApplyRenderPassRenderState2(void* a_arg1, void* a_arg2)
    {
		const bool result = _ApplyRenderPassRenderState2(a_arg1, a_arg2);

		if (result) {
			UploadRootConstants(a_arg1, a_arg2);
		}

		return result;
    }

    void Hooks::Hook_EndOfFrame(void* a1, void* a2, const char* a3)
    {
		Settings::Main::GetSingleton()->SetAtEndOfFrame(true);
		_EndOfFrame(a1, a2, a3);
    }

    void Hooks::Hook_PostEndOfFrame(void* a1)
    {
		_PostEndOfFrame(a1);
		Settings::Main::GetSingleton()->SetAtEndOfFrame(false);

		// Hack to refresh the HDR official game graphics settings menu settings when the main or pause menu is first opened,
		// otherwise if moving the game between SDR and HDR screens, it could end up staying grayed out, or not graying out.
		// Note that toggling between windowed and borderless also automatically refreshes this as it re-creates the swapchain.
		static bool wasInPauseMenu = false;
		if (!wasInPauseMenu && (Utils::IsInPauseMenu() || Utils::IsInMainMenu())) {
			Settings::Main::GetSingleton()->RefreshHDRDisplaySupportState();
			wasInPauseMenu = true;
		} else if (wasInPauseMenu && !(Utils::IsInPauseMenu() || Utils::IsInMainMenu())) {
			wasInPauseMenu = false;
		}
    }

    int32_t Hooks::Hook_ffxFsr3ContextCreate(void* a_context, RE::FfxFsr3ContextDescription* a_contextDescription)
	{
		// format is hardcoded to FFX_SURFACE_FORMAT_R8G8B8A8_UNORM in vanilla

		RE::BS_DXGI_FORMAT newFormat = Settings::Main::GetSingleton()->GetDisplayModeFormat();
		switch (newFormat) {
		case RE::BS_DXGI_FORMAT::BS_DXGI_FORMAT_R10G10B10A2_UNORM:
			a_contextDescription->backBufferFormat = RE::FFX_SURFACE_FORMAT_R10G10B10A2_UNORM;  
		    break;
		case RE::BS_DXGI_FORMAT::BS_DXGI_FORMAT_R16G16B16A16_FLOAT:
			a_contextDescription->backBufferFormat = RE::FFX_SURFACE_FORMAT_R16G16B16A16_FLOAT;
		    break;
		}

	    return _ffxFsr3ContextCreate(a_context, a_contextDescription);
	}

    void Hooks::Hook_CreateShaderResourceView(ID3D12Device* a_this, ID3D12Resource* a_resource, D3D12_SHADER_RESOURCE_VIEW_DESC* a_desc, D3D12_CPU_DESCRIPTOR_HANDLE a_destDescriptor)
	{
		// for whatever reason the format is typeless and needs to be fixed up

		if (a_desc->Format == DXGI_FORMAT_R16G16B16A16_TYPELESS) {
			a_desc->Format = DXGI_FORMAT_R16G16B16A16_FLOAT;
		}

	    a_this->CreateShaderResourceView(a_resource, a_desc, a_destDescriptor);
	}

	static uint64_t g_savedUnk;

    void Hooks::Hook_UnkFunc3(uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t* a5, uint64_t a6, uint8_t a7)
	{
		const auto settings = Settings::Main::GetSingleton();
		if (settings->bNeedsToRefreshFSR3) {
			g_savedUnk = a1;
			a1 = UINT64_MAX;  // force fail check
		}

		_UnkFunc3(a1, a2, a3, a4, a5, a6, a7);
	}

    void Hooks::Hook_UnkFunc3_Internal(uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4, uint64_t* a5, uint64_t a6)
	{
		const auto settings = Settings::Main::GetSingleton();
		if (settings->bNeedsToRefreshFSR3) {
			a1 = g_savedUnk;
			settings->bNeedsToRefreshFSR3 = false;
		}

		_UnkFunc3_Internal(a1, a2, a3, a4, a5, a6);
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
