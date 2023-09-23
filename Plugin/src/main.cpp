#include "SFSE/Stub.h"

#include "Hooks.h"
#include "Offsets.h"
#include "Settings.h"

DLLEXPORT constinit auto SFSEPlugin_Version = []() noexcept {
	SFSE::PluginVersionData data{};

	data.PluginVersion(Plugin::Version);
	data.PluginName(Plugin::NAME);
	data.AuthorName(Plugin::AUTHOR);
	data.UsesSigScanning(true);
	//data.UsesAddressLibrary(true);
	data.HasNoStructUse(true);
	//data.IsLayoutDependent(true);
	data.CompatibleVersions({ RUNTIME_VERSION_1_7_23, RUNTIME_VERSION_1_7_29 });

	return data;
}();

/**
// for preload plugins
void SFSEPlugin_Preload(SFSE::LoadInterface* a_sfse);
/**/

DLLEXPORT bool SFSEAPI SFSEPlugin_Load(SFSEInterface* a_sfse)
{
#ifndef NDEBUG
	while (!IsDebuggerPresent()) {
		Sleep(100);
	}
#endif

	SFSE::Init(a_sfse);

	DKUtil::Logger::Init(Plugin::NAME, std::to_string(Plugin::Version));

	INFO("{} v{} loaded", Plugin::NAME, Plugin::Version);
	INFO("base address : {:X}", dku::Hook::Module::get().base())

	// do stuff
	Settings::Main::GetSingleton()->Load();

	SFSE::AllocTrampoline(1 << 7);
	Offsets::Initialize();
	Hooks::Install();

	return true;
}
