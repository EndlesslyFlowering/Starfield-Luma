#include "SFSE/Stub.h"

#include "Hooks.h"
#include "Offsets.h"
#include "Settings.h"

DLLEXPORT constinit auto SFSEPlugin_Version = []() noexcept {
	SFSE::PluginVersionData data{};

	data.PluginVersion(Plugin::Version);
	data.PluginName(Plugin::NAME);
	data.AuthorName(Plugin::AUTHOR);

	// Address Library v1 (https://www.nexusmods.com/starfield/mods/3256)
	data.UsesAddressLibrary(true);
	// Version independent signature scanning
	//data.UsesSigScanning(true);

	// Uses version specific structure definitions
	//data.IsLayoutDependent(true);
	//data.HasNoStructUse(true);

	data.CompatibleVersions({ RUNTIME_VERSION_1_7_33 });

	return data;
}();

/**
// for preload plugins
void SFSEPlugin_Preload(SFSE::LoadInterface* a_sfse);
/**/

static inline bool bIsLoaded = false;

void LoadPlugin(bool a_bIsSFSE)
{
	dku::Logger::Init(Plugin::NAME, std::to_string(Plugin::Version));
	INFO("{} v{} loaded", Plugin::NAME, Plugin::Version)

	// do stuff
	Settings::Main::GetSingleton()->Load();

	if (a_bIsSFSE) {
		SFSE::AllocTrampoline(1 << 8);
	} else {
		dku::Hook::Trampoline::AllocTrampoline(1 << 8);
	}
	
	Offsets::Initialize();
	Hooks::Install();
	
	bIsLoaded = true;
}

DLLEXPORT bool SFSEAPI SFSEPlugin_Load(SFSEInterface* a_sfse)
{
#ifndef NDEBUG
	while (!IsDebuggerPresent()) {
		Sleep(100);
	}
#endif

	if (bIsLoaded) {
	    return true;
	}

	SFSE::Init(a_sfse);

	LoadPlugin(true);

	return true;
}

BOOL APIENTRY DllMain(HMODULE a_hModule, DWORD a_ul_reason_for_call, LPVOID a_lpReserved)
{
	switch (a_ul_reason_for_call) {
	case DLL_PROCESS_ATTACH:
#ifndef NDEBUG
		while (!IsDebuggerPresent()) {
			Sleep(100);
		}
#endif
		if (bIsLoaded) {
			return TRUE;
		}

		LoadPlugin(false);
	    break;
	case DLL_PROCESS_DETACH:
	    reshade::unregister_addon(a_hModule);
	    break;
	}

	return TRUE;
}
