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

DLLEXPORT bool SFSEAPI SFSEPlugin_Load(SFSEInterface* a_sfse)
{
	if (bIsLoaded) {
	    return true;
	}

#ifndef NDEBUG
	while (!IsDebuggerPresent()) {
		Sleep(100);
	}
#endif

	SFSE::Init(a_sfse);

	dku::Logger::Init(Plugin::NAME, std::to_string(Plugin::Version));
	INFO("{} v{} loaded", Plugin::NAME, Plugin::Version)

	// do stuff
	Settings::Main::GetSingleton()->Load();

	SFSE::AllocTrampoline(1 << 7);
	Offsets::Initialize();
	Hooks::Install();

	bIsLoaded = true;

	return true;
}

// for non sfse plugin loaders
BOOL APIENTRY DllMain(HMODULE a_hModule, DWORD a_ul_reason_for_call, LPVOID a_lpReserved)
{
	if (bIsLoaded) {
	    return TRUE;
	}

	if (a_ul_reason_for_call == DLL_PROCESS_ATTACH) {
#ifndef NDEBUG
		while (!IsDebuggerPresent()) {
			Sleep(100);
		}
#endif

		dku::Logger::Init(Plugin::NAME, std::to_string(Plugin::Version));
		INFO("{} v{} loaded", Plugin::NAME, Plugin::Version)

		Settings::Main::GetSingleton()->Load();

		dku::Hook::Trampoline::AllocTrampoline(1 << 7);
		Offsets::Initialize();
		Hooks::Install();

		bIsLoaded = true;
	}

	return TRUE;
}
