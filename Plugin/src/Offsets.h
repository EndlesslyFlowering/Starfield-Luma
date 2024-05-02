#pragma once
#include "RE/Types.h"
#include "sfse/GameUI.h"

class Offsets
{
public:
	using BufferArray = std::array<RE::BufferDefinition*, 200>;
	static inline BufferArray* bufferArray = nullptr;

	using tGetDXGIFormat = DXGI_FORMAT (*)(RE::BS_DXGI_FORMAT a_bgsFormat);
	static inline tGetDXGIFormat GetDXGIFormat = nullptr;

	static inline void** MessageMenuManagerPtr = nullptr;
	using tShowMessageBox = void (*)(void* a_messageMenuManager, const RE::MessageBoxData& a_messageBoxData, bool a3);
	static inline tShowMessageBox ShowMessageBox = nullptr;

	using tPhotoMode_ToggleUI = bool (*)(uintptr_t a1);
	static inline tPhotoMode_ToggleUI PhotoMode_ToggleUI = nullptr;

	using tUI_IsMenuOpen = bool (*)(UI* a_ui, const RE::BSFixedString& a_menuName);
	static inline UI** uiPtr = nullptr;
	static inline tUI_IsMenuOpen UI_IsMenuOpen = nullptr;

	using tToggleMenus = void (*)(void* a1, bool a_bDisable);
	static inline void** unkToggleMenusPtr = nullptr;
	static inline tToggleMenus ToggleMenus = nullptr;

	static inline float* g_deltaTimeRealTime = nullptr;
	static inline uint32_t* g_durationOfApplicationRunTimeMS = nullptr;

	static inline const char* documentsPath = nullptr;
	static inline const char** photosPath = nullptr;

	static inline uintptr_t* unkToggleVsyncArg1Ptr = nullptr;
	using tToggleVsync = void (*)(void* a1, bool a_bEnable);
	static inline tToggleVsync ToggleVsync = nullptr;

	static inline bool* bEnableVsync = nullptr;
	static inline float* fGamma = nullptr;
	static inline float* fGammaUI = nullptr;
	static inline RE::UpscalingTechnique*  uiUpscalingTechnique = nullptr;
	static inline RE::FrameGenerationTech* uiFrameGenerationTech = nullptr;

	static void Initialize()
	{
		bufferArray = reinterpret_cast<BufferArray*>(dku::Hook::IDToAbs(477165));
		GetDXGIFormat = reinterpret_cast<tGetDXGIFormat>(dku::Hook::IDToAbs(204483));

		ToggleVsync = reinterpret_cast<tToggleVsync>(dku::Hook::IDToAbs(184653));
		unkToggleVsyncArg1Ptr = reinterpret_cast<uintptr_t*>(dku::Hook::IDToAbs(878340));
		bEnableVsync = reinterpret_cast<bool*>(dku::Hook::IDToAbs(1488777));  // 875798 pre 1.8, 1171838 pre fsr3

		MessageMenuManagerPtr = reinterpret_cast<void**>(dku::Hook::IDToAbs(878772));
		ShowMessageBox = reinterpret_cast<tShowMessageBox>(dku::Hook::IDToAbs(167094));
		PhotoMode_ToggleUI = reinterpret_cast<tPhotoMode_ToggleUI>(dku::Hook::IDToAbs(139734));

		uiPtr = reinterpret_cast<UI**>(dku::Hook::IDToAbs(878339));
		UI_IsMenuOpen = reinterpret_cast<tUI_IsMenuOpen>(dku::Hook::IDToAbs(187049));

		unkToggleMenusPtr = reinterpret_cast<void**>(dku::Hook::IDToAbs(879521));
		ToggleMenus = reinterpret_cast<tToggleMenus>(dku::Hook::IDToAbs(187200));

		g_deltaTimeRealTime = reinterpret_cast<float*>(dku::Hook::IDToAbs(871870));
		g_durationOfApplicationRunTimeMS = reinterpret_cast<uint32_t*>(dku::Hook::IDToAbs(871872));

		documentsPath = reinterpret_cast<const char*>(dku::Hook::IDToAbs(886315));
		photosPath = reinterpret_cast<const char**>(dku::Hook::IDToAbs(778159));

		fGamma = reinterpret_cast<float*>(dku::Hook::IDToAbs(1171814));
		fGammaUI = reinterpret_cast<float*>(dku::Hook::IDToAbs(1171816));
		uiUpscalingTechnique = reinterpret_cast<RE::UpscalingTechnique*>(dku::Hook::IDToAbs(875684));
		uiFrameGenerationTech = reinterpret_cast<RE::FrameGenerationTech*>(dku::Hook::IDToAbs(1488775));
	}
};
