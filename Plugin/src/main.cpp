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

	// Uses version specific structure definitions
	data.IsLayoutDependent(true);

	data.CompatibleVersions({ RUNTIME_VERSION_1_8_86 });

	return data;
}();

/**
// for preload plugins
void SFSEPlugin_Preload(SFSE::LoadInterface* a_sfse);
/**/

static inline bool bIsLoaded = false;

void LoadPlugin(bool a_bIsSFSE)
{
#ifndef NDEBUG
	while (!IsDebuggerPresent()) {
		Sleep(100);
	}
#endif

	dku::Logger::Init(Plugin::NAME, std::to_string(Plugin::Version));
	INFO("{} v{} loaded", Plugin::NAME, Plugin::Version)

	// do stuff
	const auto settings = Settings::Main::GetSingleton();
	settings->InitConfig(a_bIsSFSE);
	settings->Load();

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

DLLEXPORT void InitializeASI()
{
	if (bIsLoaded) {
		return;
	}

	LoadPlugin(false);
}
