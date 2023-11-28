#include "Utils.h"

#include "Offsets.h"
#include "Settings.h"

#include <DirectXTex.h>
#include <wincodec.h>

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

	bool IsInPauseMenu()
	{
		const auto ui = *Offsets::uiPtr;
		if (Offsets::UI_IsMenuOpen(ui, "PauseMenu")) {
			return true;
		}
		return false;
	}

	bool IsInMainMenu()
	{
		const auto ui = *Offsets::uiPtr;
		if (Offsets::UI_IsMenuOpen(ui, "MainMenu")) {
			return true;
		}
		return false;
	}

	// Only works if HDR is enaged on the monitor that contains the swapchain
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

	std::string GetPhotoModeScreenshotPath()
    {
		SYSTEMTIME systemTime;
		GetLocalTime(&systemTime);
		return std::format("{}{}\\Photo_{}-{:02d}-{:02d}-{:02d}{:02d}{:02d}", Offsets::documentsPath, *Offsets::photosPath, systemTime.wYear, systemTime.wMonth, systemTime.wDay, systemTime.wHour, systemTime.wMinute, systemTime.wSecond);
    }

	void TransformColor_HDR(DirectX::XMVECTOR* a_outPixels, const DirectX::XMVECTOR* a_inPixels, size_t a_width, size_t a_y)
	{
		const auto  settings = Settings::Main::GetSingleton();
		const float peakBrightness = settings->PeakBrightness.value.get_data();
		const auto  peakBrightnessThreshold = DirectX::XMVectorReplicate(peakBrightness * (1.05f / 80.f));

		const DirectX::XMMATRIX c_fromWBT2020toBT2020 = {
			1.02967584133148193359375f, -0.013273007236421108245849609375f, -0.008765391074120998382568359375f, 0.f,
			-0.01190710626542568206787109375f, 1.032054901123046875f, -0.008311719633638858795166015625f, 0.f,
			-0.017768688499927520751953125f, -0.01878183521330356597900390625f, 1.01707708835601806640625f, 0.f,
			0.f, 0.f, 0.f, 1.f
		};

		const DirectX::XMMATRIX c_fromBT2020toBT709 = {
			1.6609637737274169921875f, -0.124477200210094451904296875f, -0.0181571580469608306884765625f, 0.f,
			-0.58811271190643310546875f, 1.1328194141387939453125f, -0.10066641867160797119140625f, 0.f,
			-0.072851054370403289794921875f, -0.00834227167069911956787109375f, 1.118823528289794921875f, 0.f,
			0.f, 0.f, 0.f, 1.f
		};

		for (size_t i = 0; i < a_width; ++i) {
			// color.rgb = WBT2020_To_BT2020(color.rgb);
			const auto bt2020Color = DirectX::XMVector4Transform(a_inPixels[i], c_fromWBT2020toBT2020);

			// color.rgb = clamp(color.rgb, 0.f, HdrDllPluginConstants.HDRPeakBrightnessNits * PEAK_BRIGHTNESS_THRESHOLD_SCRGB);
			const auto bt2020ColorClamped = DirectX::XMVectorClamp(bt2020Color, DirectX::XMVectorZero(), peakBrightnessThreshold);

			// color.rgb = BT2020_To_BT709(color.rgb);
			const auto bt709Color = DirectX::XMVector4Transform(bt2020ColorClamped, c_fromBT2020toBT709);

			// Discard alpha channel writes
			DirectX::XMStoreFloat3(reinterpret_cast<DirectX::XMFLOAT3*>(&a_outPixels[i]), bt709Color);
		}
	}

	void TakeSDRPhotoModeScreenshot(ID3D12CommandQueue* a_queue, ID3D12Resource* a_resource, D3D12_RESOURCE_STATES a_state, std::string a_path)
	{
		auto path = std::format("{}.png", a_path);
		auto thumbnailPath = std::format("{}-thumbnail.png", a_path);

		std::wstring widePath = std::wstring(path.begin(), path.end());
		std::wstring wideThumbnailPath = std::wstring(thumbnailPath.begin(), thumbnailPath.end());

		DirectX::ScratchImage scratchImage;
		DirectX::CaptureTexture(a_queue, a_resource, false, scratchImage, a_state, a_state);

		// full photo
		DirectX::SaveToWICFile(scratchImage.GetImages(), scratchImage.GetImageCount(), DirectX::WIC_FLAGS_FORCE_SRGB, GUID_ContainerFormatPng, widePath.c_str(), &GUID_WICPixelFormat32bppBGRA, nullptr);

		// thumbnail
		DirectX::ScratchImage resizedImage;
		DirectX::Resize(scratchImage.GetImages(), scratchImage.GetImageCount(), scratchImage.GetMetadata(), 640, 360, DirectX::TEX_FILTER_DEFAULT, resizedImage);
		DirectX::SaveToWICFile(resizedImage.GetImages(), resizedImage.GetImageCount(), DirectX::WIC_FLAGS_FORCE_SRGB, GUID_ContainerFormatPng, wideThumbnailPath.c_str(), &GUID_WICPixelFormat32bppBGRA, nullptr);

		a_resource->Release();
	}

	void TakeHDRPhotoModeScreenshot(ID3D12CommandQueue* a_queue, ID3D12Resource* a_resource, D3D12_RESOURCE_STATES a_state, std::string a_path)
	{
		auto path = std::format("{}.jxr", a_path);
		std::wstring widePath = std::wstring(path.begin(), path.end());

		DirectX::ScratchImage scratchImage;
		DirectX::CaptureTexture(a_queue, a_resource, false, scratchImage, a_state, a_state);
		
		DirectX::ScratchImage transformedImage;
		DirectX::TransformImage(scratchImage.GetImages(), scratchImage.GetImageCount(), scratchImage.GetMetadata(), &TransformColor_HDR, transformedImage);

		DirectX::SaveToWICFile(transformedImage.GetImages(), transformedImage.GetImageCount(), DirectX::WIC_FLAGS_FORCE_SRGB, GUID_ContainerFormatWmp, widePath.c_str(), &GUID_WICPixelFormat64bppRGBHalf, [&](IPropertyBag2* props) {
			PROPBAG2 options[1] = {};
			options[0].pstrName = const_cast<wchar_t*>(L"Lossless");

			VARIANT varValues[1] = {};
			varValues[0].vt = VT_BOOL;
			varValues[0].bVal = VARIANT_TRUE;

			std::ignore = props->Write(1, options, varValues);
		});

		a_resource->Release();
	}
}
