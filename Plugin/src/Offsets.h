#pragma once
#include "RE/BSFixedString.h"
#include "RE/Buffers.h"
#include "RE/MessageBoxData.h"

#include "sfse/GameUI.h"

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

	using tUI_IsMenuOpen = bool (*)(UI* a_ui, const RE::BSFixedString& a_menuName);
	static inline tUI_IsMenuOpen UI_IsMenuOpen = nullptr;

	static inline float* g_deltaTimeRealTime = nullptr;
	static inline uint32_t* g_durationOfApplicationRunTimeMS = nullptr;

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

		UI_IsMenuOpen = reinterpret_cast<tUI_IsMenuOpen>(dku::Hook::IDToAbs(187049));

		g_deltaTimeRealTime = reinterpret_cast<float*>(dku::Hook::IDToAbs(871870));
		g_durationOfApplicationRunTimeMS = reinterpret_cast<uint32_t*>(dku::Hook::IDToAbs(871872));
	}
};
