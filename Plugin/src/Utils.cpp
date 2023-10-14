#include "Utils.h"

#include "Offsets.h"

namespace Utils
{
    std::unordered_map<DXGI_FORMAT, std::string> GetDXGIFormatNameMap()
    {
		std::unordered_map<DXGI_FORMAT, std::string> formatNames;

		formatNames[DXGI_FORMAT_UNKNOWN] = "DXGI_FORMAT_UNKNOWN";
		formatNames[DXGI_FORMAT_R32G32B32A32_TYPELESS] = "DXGI_FORMAT_R32G32B32A32_TYPELESS";
		formatNames[DXGI_FORMAT_R32G32B32A32_FLOAT] = "DXGI_FORMAT_R32G32B32A32_FLOAT";
		formatNames[DXGI_FORMAT_R32G32B32A32_UINT] = "DXGI_FORMAT_R32G32B32A32_UINT";
		formatNames[DXGI_FORMAT_R32G32B32A32_SINT] = "DXGI_FORMAT_R32G32B32A32_SINT";
		formatNames[DXGI_FORMAT_R32G32B32_TYPELESS] = "DXGI_FORMAT_R32G32B32_TYPELESS";
		formatNames[DXGI_FORMAT_R32G32B32_FLOAT] = "DXGI_FORMAT_R32G32B32_FLOAT";
		formatNames[DXGI_FORMAT_R32G32B32_UINT] = "DXGI_FORMAT_R32G32B32_UINT";
		formatNames[DXGI_FORMAT_R32G32B32_SINT] = "DXGI_FORMAT_R32G32B32_SINT";
		formatNames[DXGI_FORMAT_R16G16B16A16_TYPELESS] = "DXGI_FORMAT_R16G16B16A16_TYPELESS";
		formatNames[DXGI_FORMAT_R16G16B16A16_FLOAT] = "DXGI_FORMAT_R16G16B16A16_FLOAT";
		formatNames[DXGI_FORMAT_R16G16B16A16_UNORM] = "DXGI_FORMAT_R16G16B16A16_UNORM";
		formatNames[DXGI_FORMAT_R16G16B16A16_UINT] = "DXGI_FORMAT_R16G16B16A16_UINT";
		formatNames[DXGI_FORMAT_R16G16B16A16_SNORM] = "DXGI_FORMAT_R16G16B16A16_SNORM";
		formatNames[DXGI_FORMAT_R16G16B16A16_SINT] = "DXGI_FORMAT_R16G16B16A16_SINT";
		formatNames[DXGI_FORMAT_R32G32_TYPELESS] = "DXGI_FORMAT_R32G32_TYPELESS";
		formatNames[DXGI_FORMAT_R32G32_FLOAT] = "DXGI_FORMAT_R32G32_FLOAT";
		formatNames[DXGI_FORMAT_R32G32_UINT] = "DXGI_FORMAT_R32G32_UINT";
		formatNames[DXGI_FORMAT_R32G32_SINT] = "DXGI_FORMAT_R32G32_SINT";
		formatNames[DXGI_FORMAT_R32G8X24_TYPELESS] = "DXGI_FORMAT_R32G8X24_TYPELESS";
		formatNames[DXGI_FORMAT_D32_FLOAT_S8X24_UINT] = "DXGI_FORMAT_D32_FLOAT_S8X24_UINT";
		formatNames[DXGI_FORMAT_R32_FLOAT_X8X24_TYPELESS] = "DXGI_FORMAT_R32_FLOAT_X8X24_TYPELESS";
		formatNames[DXGI_FORMAT_X32_TYPELESS_G8X24_UINT] = "DXGI_FORMAT_X32_TYPELESS_G8X24_UINT";
		formatNames[DXGI_FORMAT_R10G10B10A2_TYPELESS] = "DXGI_FORMAT_R10G10B10A2_TYPELESS";
		formatNames[DXGI_FORMAT_R10G10B10A2_UNORM] = "DXGI_FORMAT_R10G10B10A2_UNORM";
		formatNames[DXGI_FORMAT_R10G10B10A2_UINT] = "DXGI_FORMAT_R10G10B10A2_UINT";
		formatNames[DXGI_FORMAT_R11G11B10_FLOAT] = "DXGI_FORMAT_R11G11B10_FLOAT";
		formatNames[DXGI_FORMAT_R8G8B8A8_TYPELESS] = "DXGI_FORMAT_R8G8B8A8_TYPELESS";
		formatNames[DXGI_FORMAT_R8G8B8A8_UNORM] = "DXGI_FORMAT_R8G8B8A8_UNORM";
		formatNames[DXGI_FORMAT_R8G8B8A8_UNORM_SRGB] = "DXGI_FORMAT_R8G8B8A8_UNORM_SRGB";
		formatNames[DXGI_FORMAT_R8G8B8A8_UINT] = "DXGI_FORMAT_R8G8B8A8_UINT";
		formatNames[DXGI_FORMAT_R8G8B8A8_SNORM] = "DXGI_FORMAT_R8G8B8A8_SNORM";
		formatNames[DXGI_FORMAT_R8G8B8A8_SINT] = "DXGI_FORMAT_R8G8B8A8_SINT";
		formatNames[DXGI_FORMAT_R16G16_TYPELESS] = "DXGI_FORMAT_R16G16_TYPELESS";
		formatNames[DXGI_FORMAT_R16G16_FLOAT] = "DXGI_FORMAT_R16G16_FLOAT";
		formatNames[DXGI_FORMAT_R16G16_UNORM] = "DXGI_FORMAT_R16G16_UNORM";
		formatNames[DXGI_FORMAT_R16G16_UINT] = "DXGI_FORMAT_R16G16_UINT";
		formatNames[DXGI_FORMAT_R16G16_SNORM] = "DXGI_FORMAT_R16G16_SNORM";
		formatNames[DXGI_FORMAT_R16G16_SINT] = "DXGI_FORMAT_R16G16_SINT";
		formatNames[DXGI_FORMAT_R32_TYPELESS] = "DXGI_FORMAT_R32_TYPELESS";
		formatNames[DXGI_FORMAT_D32_FLOAT] = "DXGI_FORMAT_D32_FLOAT";
		formatNames[DXGI_FORMAT_R32_FLOAT] = "DXGI_FORMAT_R32_FLOAT";
		formatNames[DXGI_FORMAT_R32_UINT] = "DXGI_FORMAT_R32_UINT";
		formatNames[DXGI_FORMAT_R32_SINT] = "DXGI_FORMAT_R32_SINT";
		formatNames[DXGI_FORMAT_R24G8_TYPELESS] = "DXGI_FORMAT_R24G8_TYPELESS";
		formatNames[DXGI_FORMAT_D24_UNORM_S8_UINT] = "DXGI_FORMAT_D24_UNORM_S8_UINT";
		formatNames[DXGI_FORMAT_R24_UNORM_X8_TYPELESS] = "DXGI_FORMAT_R24_UNORM_X8_TYPELESS";
		formatNames[DXGI_FORMAT_X24_TYPELESS_G8_UINT] = "DXGI_FORMAT_X24_TYPELESS_G8_UINT";
		formatNames[DXGI_FORMAT_R8G8_TYPELESS] = "DXGI_FORMAT_R8G8_TYPELESS";
		formatNames[DXGI_FORMAT_R8G8_UNORM] = "DXGI_FORMAT_R8G8_UNORM";
		formatNames[DXGI_FORMAT_R8G8_UINT] = "DXGI_FORMAT_R8G8_UINT";
		formatNames[DXGI_FORMAT_R8G8_SNORM] = "DXGI_FORMAT_R8G8_SNORM";
		formatNames[DXGI_FORMAT_R8G8_SINT] = "DXGI_FORMAT_R8G8_SINT";
		formatNames[DXGI_FORMAT_R16_TYPELESS] = "DXGI_FORMAT_R16_TYPELESS";
		formatNames[DXGI_FORMAT_R16_FLOAT] = "DXGI_FORMAT_R16_FLOAT";
		formatNames[DXGI_FORMAT_D16_UNORM] = "DXGI_FORMAT_D16_UNORM";
		formatNames[DXGI_FORMAT_R16_UNORM] = "DXGI_FORMAT_R16_UNORM";
		formatNames[DXGI_FORMAT_R16_UINT] = "DXGI_FORMAT_R16_UINT";
		formatNames[DXGI_FORMAT_R16_SNORM] = "DXGI_FORMAT_R16_SNORM";
		formatNames[DXGI_FORMAT_R16_SINT] = "DXGI_FORMAT_R16_SINT";
		formatNames[DXGI_FORMAT_R8_TYPELESS] = "DXGI_FORMAT_R8_TYPELESS";
		formatNames[DXGI_FORMAT_R8_UNORM] = "DXGI_FORMAT_R8_UNORM";
		formatNames[DXGI_FORMAT_R8_UINT] = "DXGI_FORMAT_R8_UINT";
		formatNames[DXGI_FORMAT_R8_SNORM] = "DXGI_FORMAT_R8_SNORM";
		formatNames[DXGI_FORMAT_R8_SINT] = "DXGI_FORMAT_R8_SINT";
		formatNames[DXGI_FORMAT_A8_UNORM] = "DXGI_FORMAT_A8_UNORM";
		formatNames[DXGI_FORMAT_R1_UNORM] = "DXGI_FORMAT_R1_UNORM";
		formatNames[DXGI_FORMAT_R9G9B9E5_SHAREDEXP] = "DXGI_FORMAT_R9G9B9E5_SHAREDEXP";
		formatNames[DXGI_FORMAT_R8G8_B8G8_UNORM] = "DXGI_FORMAT_R8G8_B8G8_UNORM";
		formatNames[DXGI_FORMAT_G8R8_G8B8_UNORM] = "DXGI_FORMAT_G8R8_G8B8_UNORM";
		formatNames[DXGI_FORMAT_BC1_TYPELESS] = "DXGI_FORMAT_BC1_TYPELESS";
		formatNames[DXGI_FORMAT_BC1_UNORM] = "DXGI_FORMAT_BC1_UNORM";
		formatNames[DXGI_FORMAT_BC1_UNORM_SRGB] = "DXGI_FORMAT_BC1_UNORM_SRGB";
		formatNames[DXGI_FORMAT_BC2_TYPELESS] = "DXGI_FORMAT_BC2_TYPELESS";
		formatNames[DXGI_FORMAT_BC2_UNORM] = "DXGI_FORMAT_BC2_UNORM";
		formatNames[DXGI_FORMAT_BC2_UNORM_SRGB] = "DXGI_FORMAT_BC2_UNORM_SRGB";
		formatNames[DXGI_FORMAT_BC3_TYPELESS] = "DXGI_FORMAT_BC3_TYPELESS";
		formatNames[DXGI_FORMAT_BC3_UNORM] = "DXGI_FORMAT_BC3_UNORM";
		formatNames[DXGI_FORMAT_BC3_UNORM_SRGB] = "DXGI_FORMAT_BC3_UNORM_SRGB";
		formatNames[DXGI_FORMAT_BC4_TYPELESS] = "DXGI_FORMAT_BC4_TYPELESS";
		formatNames[DXGI_FORMAT_BC4_UNORM] = "DXGI_FORMAT_BC4_UNORM";
		formatNames[DXGI_FORMAT_BC4_SNORM] = "DXGI_FORMAT_BC4_SNORM";
		formatNames[DXGI_FORMAT_BC5_TYPELESS] = "DXGI_FORMAT_BC5_TYPELESS";
		formatNames[DXGI_FORMAT_BC5_UNORM] = "DXGI_FORMAT_BC5_UNORM";
		formatNames[DXGI_FORMAT_BC5_SNORM] = "DXGI_FORMAT_BC5_SNORM";
		formatNames[DXGI_FORMAT_B5G6R5_UNORM] = "DXGI_FORMAT_B5G6R5_UNORM";
		formatNames[DXGI_FORMAT_B5G5R5A1_UNORM] = "DXGI_FORMAT_B5G5R5A1_UNORM";
		formatNames[DXGI_FORMAT_B8G8R8A8_UNORM] = "DXGI_FORMAT_B8G8R8A8_UNORM";
		formatNames[DXGI_FORMAT_B8G8R8X8_UNORM] = "DXGI_FORMAT_B8G8R8X8_UNORM";
		formatNames[DXGI_FORMAT_R10G10B10_XR_BIAS_A2_UNORM] = "DXGI_FORMAT_R10G10B10_XR_BIAS_A2_UNORM";
		formatNames[DXGI_FORMAT_B8G8R8A8_TYPELESS] = "DXGI_FORMAT_B8G8R8A8_TYPELESS";
		formatNames[DXGI_FORMAT_B8G8R8A8_UNORM_SRGB] = "DXGI_FORMAT_B8G8R8A8_UNORM_SRGB";
		formatNames[DXGI_FORMAT_B8G8R8X8_TYPELESS] = "DXGI_FORMAT_B8G8R8X8_TYPELESS";
		formatNames[DXGI_FORMAT_B8G8R8X8_UNORM_SRGB] = "DXGI_FORMAT_B8G8R8X8_UNORM_SRGB";
		formatNames[DXGI_FORMAT_BC6H_TYPELESS] = "DXGI_FORMAT_BC6H_TYPELESS";
		formatNames[DXGI_FORMAT_BC6H_UF16] = "DXGI_FORMAT_BC6H_UF16";
		formatNames[DXGI_FORMAT_BC6H_SF16] = "DXGI_FORMAT_BC6H_SF16";
		formatNames[DXGI_FORMAT_BC7_TYPELESS] = "DXGI_FORMAT_BC7_TYPELESS";
		formatNames[DXGI_FORMAT_BC7_UNORM] = "DXGI_FORMAT_BC7_UNORM";
		formatNames[DXGI_FORMAT_BC7_UNORM_SRGB] = "DXGI_FORMAT_BC7_UNORM_SRGB";
		formatNames[DXGI_FORMAT_AYUV] = "DXGI_FORMAT_AYUV";
		formatNames[DXGI_FORMAT_Y410] = "DXGI_FORMAT_Y410";
		formatNames[DXGI_FORMAT_Y416] = "DXGI_FORMAT_Y416";
		formatNames[DXGI_FORMAT_NV12] = "DXGI_FORMAT_NV12";
		formatNames[DXGI_FORMAT_P010] = "DXGI_FORMAT_P010";
		formatNames[DXGI_FORMAT_P016] = "DXGI_FORMAT_P016";
		formatNames[DXGI_FORMAT_420_OPAQUE] = "DXGI_FORMAT_420_OPAQUE";
		formatNames[DXGI_FORMAT_YUY2] = "DXGI_FORMAT_YUY2";
		formatNames[DXGI_FORMAT_Y210] = "DXGI_FORMAT_Y210";
		formatNames[DXGI_FORMAT_Y216] = "DXGI_FORMAT_Y216";
		formatNames[DXGI_FORMAT_NV11] = "DXGI_FORMAT_NV11";
		formatNames[DXGI_FORMAT_AI44] = "DXGI_FORMAT_AI44";
		formatNames[DXGI_FORMAT_IA44] = "DXGI_FORMAT_IA44";
		formatNames[DXGI_FORMAT_P8] = "DXGI_FORMAT_P8";
		formatNames[DXGI_FORMAT_A8P8] = "DXGI_FORMAT_A8P8";
		formatNames[DXGI_FORMAT_B4G4R4A4_UNORM] = "DXGI_FORMAT_B4G4R4A4_UNORM";
		formatNames[DXGI_FORMAT_P208] = "DXGI_FORMAT_P208";
		formatNames[DXGI_FORMAT_V208] = "DXGI_FORMAT_V208";
		formatNames[DXGI_FORMAT_V408] = "DXGI_FORMAT_V408";
		formatNames[DXGI_FORMAT_SAMPLER_FEEDBACK_MIN_MIP_OPAQUE] = "DXGI_FORMAT_SAMPLER_FEEDBACK_MIN_MIP_OPAQUE";
		formatNames[DXGI_FORMAT_SAMPLER_FEEDBACK_MIP_REGION_USED_OPAQUE] = "DXGI_FORMAT_SAMPLER_FEEDBACK_MIP_REGION_USED_OPAQUE";

		return formatNames;
    }

    void LogFormats()
    {
		auto formatNames = GetDXGIFormatNameMap();

		for (int i = 0; i < 128; ++i) {
			const auto format = Offsets::GetDXGIFormat(static_cast<RE::BS_DXGI_FORMAT>(i));
			INFO("{} - {}", i, formatNames[format])
		}
    }

    void LogBuffers()
    {
		INFO("===LOGGING BUFFERS===")

		std::string logString = "Index, Buffer name, DXGI_FORMAT\n";

		auto formatNames = GetDXGIFormatNameMap();
		for (int i = 0; i < Offsets::bufferArray->size(); ++i) {
		    const auto& bufferDefinition = (*Offsets::bufferArray)[i];
			const auto dxgiFormat = Offsets::GetDXGIFormat(bufferDefinition->format);
			logString.append(fmt::format("{:3}, {}, {}\n", i, bufferDefinition->bufferName, formatNames[dxgiFormat]));
		}

		INFO(logString)
		INFO("===END LOGGING BUFFERS===")
    }

    void SetBufferFormat(RE::BufferDefinition* a_buffer, RE::BS_DXGI_FORMAT a_format)
    {
		if (!a_buffer) {
			return;
		}

		auto formatNames = Utils::GetDXGIFormatNameMap();
		INFO("{} - changing from format {} to {}", a_buffer->bufferName, formatNames[Offsets::GetDXGIFormat(a_buffer->format)], formatNames[Offsets::GetDXGIFormat(a_format)])
		a_buffer->format = a_format;
    }

    void SetBufferFormat(RE::Buffers a_buffer, RE::BS_DXGI_FORMAT a_format)
    {
		const auto buffer = (*Offsets::bufferArray)[static_cast<uint32_t>(a_buffer)];
		SetBufferFormat(buffer, a_format);
    }

    RE::BS_DXGI_FORMAT GetBufferFormat(RE::Buffers a_buffer)
    {
		const auto buffer = (*Offsets::bufferArray)[static_cast<uint32_t>(a_buffer)];
		return buffer->format;
    }

	bool ShouldCorrectLUTs()
	{
		const auto ui = *Offsets::uiPtr;
		// make sure we do indeed correct luts in these menus, even though DataMenu is in the menu stack
		if (Offsets::UI_IsMenuOpen(ui, "GalaxyStarMapMenu")) {
			return true;
		}
		if (Offsets::UI_IsMenuOpen(ui, "SpaceshipEditorMenu")) {
			return true;
		}

		// don't correct luts while we're in menus that have a LUT
		if (Offsets::UI_IsMenuOpen(ui, "DataMenu")) {
			return false;
		}
		if (Offsets::UI_IsMenuOpen(ui, "InventoryMenu")) {
			return false;
		}
		if (Offsets::UI_IsMenuOpen(ui, "ContainerMenu")) {
			return false;
		}
		if (Offsets::UI_IsMenuOpen(ui, "BarterMenu")) {
			return false;
		}

		return true;
	}
	
	bool IsInSettingsMenu()
	{
		const auto ui = *Offsets::uiPtr;
		if (Offsets::UI_IsMenuOpen(ui, "SettingsMenu")) {
			return true;
		}
		return false;
	}

    bool GetHDRMaxLuminance(IDXGISwapChain3* a_swapChainInterface, float& a_outMaxLuminance)
    {
		IDXGIOutput* output = nullptr;
		if (FAILED(a_swapChainInterface->GetContainingOutput(&output))) {
		    return false;
		}

		IDXGIOutput6* output6 = nullptr;
		if (FAILED(output->QueryInterface(&output6))) {
		    return false;
		}

		DXGI_OUTPUT_DESC1 desc1;
		if (FAILED(output6->GetDesc1(&desc1))) {
		    return false;
		}

		a_outMaxLuminance = desc1.MaxLuminance;
		return true;
    }

    bool GetDisplayConfigPathInfo(HWND a_hwnd, DISPLAYCONFIG_PATH_INFO& a_outPathInfo)
    {
		uint32_t pathCount, modeCount;
		if (ERROR_SUCCESS != GetDisplayConfigBufferSizes(QDC_ONLY_ACTIVE_PATHS, &pathCount, &modeCount)) {
		    return false;
		}

		std::vector<DISPLAYCONFIG_PATH_INFO> paths(pathCount);
		std::vector<DISPLAYCONFIG_MODE_INFO> modes(modeCount);
		if (ERROR_SUCCESS != QueryDisplayConfig(QDC_ONLY_ACTIVE_PATHS, &pathCount, paths.data(), &modeCount, modes.data(), nullptr)) {
		    return false;
		}

		const HMONITOR monitorFromWindow = MonitorFromWindow(a_hwnd, MONITOR_DEFAULTTONULL);
		for (auto& pathInfo : paths) {
			if (pathInfo.flags & DISPLAYCONFIG_PATH_ACTIVE && pathInfo.sourceInfo.statusFlags & DISPLAYCONFIG_SOURCE_IN_USE) {
				const bool bVirtual = pathInfo.flags & DISPLAYCONFIG_PATH_SUPPORT_VIRTUAL_MODE;
				const DISPLAYCONFIG_SOURCE_MODE& sourceMode = modes[bVirtual ? pathInfo.sourceInfo.sourceModeInfoIdx : pathInfo.sourceInfo.modeInfoIdx].sourceMode;

				RECT rect { sourceMode.position.x, sourceMode.position.y, sourceMode.position.x + sourceMode.width, sourceMode.position.y + sourceMode.height };
				if (!IsRectEmpty(&rect)) {
					const HMONITOR monitorFromMode = MonitorFromRect(&rect, MONITOR_DEFAULTTONULL);
					if (monitorFromMode != nullptr && monitorFromMode == monitorFromWindow) {
						a_outPathInfo = pathInfo;
						return true;
					}
				}
			}
		}

		return false;
    }

    bool GetColorInfo(HWND a_hwnd, DISPLAYCONFIG_GET_ADVANCED_COLOR_INFO& a_outColorInfo)
    {
		DISPLAYCONFIG_PATH_INFO pathInfo{};
		if (GetDisplayConfigPathInfo(a_hwnd, pathInfo)) {
			DISPLAYCONFIG_GET_ADVANCED_COLOR_INFO colorInfo{};
			colorInfo.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_ADVANCED_COLOR_INFO;
		    colorInfo.header.size = sizeof(colorInfo);
		    colorInfo.header.adapterId = pathInfo.targetInfo.adapterId;
		    colorInfo.header.id = pathInfo.targetInfo.id;
			auto result = DisplayConfigGetDeviceInfo(&colorInfo.header);
			if (result == ERROR_SUCCESS) {
				a_outColorInfo = colorInfo;
				return true;
			}
		}

		return false;
    }

    bool IsHDRSupported(HWND a_hwnd)
    {
		DISPLAYCONFIG_GET_ADVANCED_COLOR_INFO colorInfo{};
		if (GetColorInfo(a_hwnd, colorInfo)) {
		    return colorInfo.advancedColorSupported;
		}

		return false;
    }

    bool IsHDREnabled(HWND a_hwnd)
    {
		DISPLAYCONFIG_GET_ADVANCED_COLOR_INFO colorInfo{};
		if (GetColorInfo(a_hwnd, colorInfo)) {
			return colorInfo.advancedColorEnabled;
		}

		return false;
    }

    bool SetHDREnabled(HWND a_hwnd)
    {
		DISPLAYCONFIG_GET_ADVANCED_COLOR_INFO colorInfo{};
		if (GetColorInfo(a_hwnd, colorInfo)) {
			if (colorInfo.advancedColorSupported && !colorInfo.advancedColorEnabled) {
				DISPLAYCONFIG_SET_ADVANCED_COLOR_STATE setColorState{};
			    setColorState.header.type = DISPLAYCONFIG_DEVICE_INFO_SET_ADVANCED_COLOR_STATE;
			    setColorState.header.size = sizeof(setColorState);
			    setColorState.header.adapterId = colorInfo.header.adapterId;
			    setColorState.header.id = colorInfo.header.id;
			    setColorState.enableAdvancedColor = true;
				return ERROR_SUCCESS == DisplayConfigSetDeviceInfo(&setColorState.header);
			}

			return colorInfo.advancedColorEnabled;
		}

		return false;
    }
}
