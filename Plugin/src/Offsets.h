#pragma once
#include "RE/Buffers.h"
#include "RE/MessageBoxData.h"

class Offsets
{
public:
	using BufferArray = std::array<RE::BufferDefinition*, 204>;
	static inline BufferArray* bufferArray = nullptr;

	using tGetDXGIFormat = DXGI_FORMAT (*)(RE::BS_DXGI_FORMAT a_bgsFormat);
	static inline tGetDXGIFormat GetDXGIFormat = nullptr;

	static inline void** MessageMenuManagerPtr = nullptr;
	using tShowMessageBox = void (*)(void* a_messageMenuManager, const RE::MessageBoxData& a_messageBoxData, bool a3);
	static inline tShowMessageBox ShowMessageBox = nullptr;

	using tPhotoMode_ToggleUI = bool (*)(uintptr_t a1);
	static inline tPhotoMode_ToggleUI PhotoMode_ToggleUI = nullptr;

	//test
	static inline uintptr_t* unkToggleVsyncArg1Ptr = nullptr;
	using tToggleVsync = void (*)(void* a1, bool a_bEnable);
	static inline tToggleVsync ToggleVsync = nullptr;
	static inline bool* bEnableVsync = nullptr;

	static void Initialize()
	{
		bufferArray = reinterpret_cast<BufferArray*>(dku::Hook::IDToAbs(477165));
		GetDXGIFormat = reinterpret_cast<tGetDXGIFormat>(dku::Hook::IDToAbs(204483));

		ToggleVsync = reinterpret_cast<tToggleVsync>(dku::Hook::IDToAbs(184653));
		unkToggleVsyncArg1Ptr = reinterpret_cast<uintptr_t*>(dku::Hook::IDToAbs(878340));
		bEnableVsync = reinterpret_cast<bool*>(dku::Hook::IDToAbs(875798));

		MessageMenuManagerPtr = reinterpret_cast<void**>(dku::Hook::IDToAbs(878772));
		ShowMessageBox = reinterpret_cast<tShowMessageBox>(dku::Hook::IDToAbs(167094));
		PhotoMode_ToggleUI = reinterpret_cast<tPhotoMode_ToggleUI>(dku::Hook::IDToAbs(139734));
	}
};
