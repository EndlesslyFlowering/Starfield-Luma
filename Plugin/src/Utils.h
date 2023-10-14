#pragma once
#include "RE/Buffers.h"

namespace Utils
{
	std::unordered_map<DXGI_FORMAT, std::string> GetDXGIFormatNameMap();

	void LogFormats();

	void LogBuffers();

	void SetBufferFormat(RE::BufferDefinition* a_buffer, RE::BS_DXGI_FORMAT a_format);
	void SetBufferFormat(RE::Buffers a_buffer, RE::BS_DXGI_FORMAT a_format);
	RE::BS_DXGI_FORMAT GetBufferFormat(RE::Buffers a_buffer);

	bool ShouldCorrectLUTs();
	bool IsInSettingsMenu();

	bool GetHDRMaxLuminance(IDXGISwapChain3* a_swapChainInterface, float& a_outMaxLuminance);
	bool GetDisplayConfigPathInfo(HWND a_hwnd, DISPLAYCONFIG_PATH_INFO& a_outPathInfo);
	bool GetColorInfo(HWND a_hwnd, DISPLAYCONFIG_GET_ADVANCED_COLOR_INFO& a_outColorInfo);
	bool IsHDRSupported(HWND a_hwnd);
	bool IsHDREnabled(HWND a_hwnd);
	bool SetHDREnabled(HWND a_hwnd);
	
}
