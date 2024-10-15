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
	//data.IsLayoutDependent(true);
	data.structureCompatibility = 1 << 3;  // kStructureIndependence_1_14_70_Layout = 1 << 3,

	data.CompatibleVersions({ CURRENT_RELEASE_RUNTIME });

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
#if 0
#ifndef NDEBUG
	if (!IsDebuggerPresent()) {
		MessageBoxA(NULL, "Loaded. You can now attach the debugger or continue execution.", Plugin::NAME.data(), NULL);
	}
#endif
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

	auto module = reinterpret_cast<uintptr_t>(GetModuleHandleA(nullptr));
	auto ntHeaders = reinterpret_cast<const PIMAGE_NT_HEADERS>(module + reinterpret_cast<PIMAGE_DOS_HEADER>(module)->e_lfanew);

	auto& directory = ntHeaders->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT];
	auto  descriptor = reinterpret_cast<const PIMAGE_EXPORT_DIRECTORY>(module + directory.VirtualAddress);

	// Plugin dlls can be loaded into non-game processes when people use broken ASI loader setups. The only
	// version-agnostic and file-name-agnostic method to detect Starfield.exe is to check the export directory
	// name.
	if (directory.VirtualAddress == 0 ||
		directory.Size == 0 ||
		memcmp(reinterpret_cast<void*>(module + descriptor->Name), "Starfield.exe", 14) != 0)
		return;

	LoadPlugin(false);
}
