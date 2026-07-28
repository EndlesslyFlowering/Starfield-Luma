#pragma once
#include "RE/Types.h"
#include "sfse/GameUI.h"

class Offsets
{
public:
	using BufferArray = std::array<RE::BufferDefinition*, static_cast<size_t>(RE::Buffers::Buffers_MAX)>;
	static inline BufferArray* bufferArray = nullptr;

	using tGetDXGIFormat = DXGI_FORMAT (*)(RE::BS_DXGI_FORMAT a_bgsFormat);
	static inline tGetDXGIFormat GetDXGIFormat = nullptr;

	//static inline void** MessageMenuManagerPtr = nullptr;
	//using tShowMessageBox = void (*)(void* a_messageMenuManager, const RE::MessageBoxData& a_messageBoxData, bool a3);
	//static inline tShowMessageBox ShowMessageBox = nullptr;

	using tPhotoMode_ToggleUI = bool (*)(uintptr_t a1);
	static inline tPhotoMode_ToggleUI PhotoMode_ToggleUI = nullptr;

	using tUI_IsMenuOpen = bool (*)(UI* a_ui, const RE::BSFixedString& a_menuName);
	static inline UI** uiPtr = nullptr;
	static inline tUI_IsMenuOpen UI_IsMenuOpen = nullptr;

	//using tToggleMenus = void (*)(void* a1, bool a_bDisable);
	//static inline void** unkToggleMenusPtr = nullptr;
	//static inline tToggleMenus ToggleMenus = nullptr;

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

	using tGetSettingsDataModelParams = void* (*)(uintptr_t a1, uintptr_t a2);
	static inline tGetSettingsDataModelParams GetSettingsDataModelCheckboxParams = nullptr;
	static inline tGetSettingsDataModelParams GetSettingsDataModelStepperParams = nullptr;
	static inline tGetSettingsDataModelParams GetSettingsDataModelSliderParams = nullptr;

	// What a resolved address is expected to point at. Checked against the section it lands in.
	enum class AddressKind
	{
		Code,      // a function, so an executable section
		Data,      // a global, so a writable section
		ReadOnly,  // a vtable or similar, so .rdata
	};

	// Address library IDs are regenerated for every game build, and a stale ID normally still
	// resolves - to whatever unrelated thing now occupies that slot - so a bad port surfaces as a
	// crash a long way from its cause. Sanity check every address and log the lot, so that after a
	// game update the log alone says which IDs moved.
	static std::uintptr_t Resolve(std::uint64_t a_id, AddressKind a_kind, std::string_view a_name)
	{
		const auto address = dku::Hook::IDToAbs(a_id);

		const auto* section = FindSection(address);
		if (!section) {
			WARN("Offsets: {} (id {}) resolved to {:X}, which is outside every section", a_name, a_id, address)
			++resolveFailures;
			return address;
		}

		const bool executable = (section->Characteristics & IMAGE_SCN_MEM_EXECUTE) != 0;
		const bool writable = (section->Characteristics & IMAGE_SCN_MEM_WRITE) != 0;

		bool matches = false;
		switch (a_kind) {
		case AddressKind::Code:
			matches = executable;
			break;
		case AddressKind::Data:
			matches = writable && !executable;
			break;
		case AddressKind::ReadOnly:
			matches = !writable && !executable;
			break;
		}

		// Section names are not null terminated when they use all 8 bytes.
		const std::string_view sectionName{ reinterpret_cast<const char*>(section->Name),
			::strnlen(reinterpret_cast<const char*>(section->Name), sizeof(section->Name)) };

		if (!matches) {
			WARN("Offsets: {} (id {}) resolved to {:X} in {}, which is not the expected kind", a_name, a_id, address, sectionName)
			++resolveFailures;
		} else {
			INFO("Offsets: {} (id {}) -> {:X} [{}]", a_name, a_id, address, sectionName)
		}

		return address;
	}

	// Hook sites are given as an offset into a function, and those offsets shift whenever the game
	// is rebuilt even when the address library id still points at the right function. Every site we
	// patch is a call, so check for one before overwriting it.
	static bool IsCallSite(std::uintptr_t a_address, std::size_t a_size, std::string_view a_name)
	{
		// Guard the read: a badly moved offset can land outside the image entirely, and faulting
		// here would defeat the point of checking.
		const auto* section = FindSection(a_address);
		if (!section || (section->Characteristics & IMAGE_SCN_MEM_EXECUTE) == 0) {
			WARN("Offsets: hook site {} at {:X} is not in executable memory, the offset has moved", a_name, a_address)
			++resolveFailures;
			return false;
		}

		const auto* opcode = reinterpret_cast<const std::uint8_t*>(a_address);

		// E8 is a direct call rel32 (5 bytes); FF /2 is an indirect call (6 bytes here).
		const bool isCall = (a_size == 5 && opcode[0] == 0xE8) ||
		                    (a_size == 6 && opcode[0] == 0xFF);

		if (!isCall) {
			WARN("Offsets: hook site {} at {:X} is not a {}-byte call (found {:02X}), the offset has moved", a_name, a_address, a_size, opcode[0])
			++resolveFailures;
		}

		return isCall;
	}

	static std::uint32_t GetResolveFailureCount() { return resolveFailures; }

	static void Initialize()
	{
		resolveFailures = 0;

		bufferArray = reinterpret_cast<BufferArray*>(Resolve(370539, AddressKind::ReadOnly, "bufferArray"));
		GetDXGIFormat = reinterpret_cast<tGetDXGIFormat>(Resolve(142460, AddressKind::Code, "GetDXGIFormat"));

		ToggleVsync = reinterpret_cast<tToggleVsync>(Resolve(128505, AddressKind::Code, "ToggleVsync"));
		unkToggleVsyncArg1Ptr = reinterpret_cast<uintptr_t*>(Resolve(937583, AddressKind::Data, "unkToggleVsyncArg1Ptr"));
		bEnableVsync = reinterpret_cast<bool*>(Resolve(933467, AddressKind::Data, "bEnableVsync"));

		//MessageMenuManagerPtr = reinterpret_cast<void**>(dku::Hook::IDToAbs(878772));
		//ShowMessageBox = reinterpret_cast<tShowMessageBox>(dku::Hook::IDToAbs(167094));

		PhotoMode_ToggleUI = reinterpret_cast<tPhotoMode_ToggleUI>(Resolve(92038, AddressKind::Code, "PhotoMode_ToggleUI"));

		uiPtr = reinterpret_cast<UI**>(Resolve(937580, AddressKind::Data, "uiPtr"));
		UI_IsMenuOpen = reinterpret_cast<tUI_IsMenuOpen>(Resolve(130475, AddressKind::Code, "UI_IsMenuOpen"));

		//unkToggleMenusPtr = reinterpret_cast<void**>(dku::Hook::IDToAbs(938533));
		//ToggleMenus = reinterpret_cast<tToggleMenus>(dku::Hook::IDToAbs(130602));

		g_deltaTimeRealTime = reinterpret_cast<float*>(Resolve(936961, AddressKind::Data, "g_deltaTimeRealTime"));
		g_durationOfApplicationRunTimeMS = reinterpret_cast<uint32_t*>(Resolve(936963, AddressKind::Data, "g_durationOfApplicationRunTimeMS"));

		documentsPath = reinterpret_cast<const char*>(Resolve(937452, AddressKind::Data, "documentsPath"));
		photosPath = reinterpret_cast<const char**>(Resolve(828199, AddressKind::Data, "photosPath"));

		fGamma = reinterpret_cast<float*>(Resolve(933234, AddressKind::Data, "fGamma"));
		fGammaUI = reinterpret_cast<float*>(Resolve(933237, AddressKind::Data, "fGammaUI"));
		uiUpscalingTechnique = reinterpret_cast<RE::UpscalingTechnique*>(Resolve(933266, AddressKind::Data, "uiUpscalingTechnique"));
		uiFrameGenerationTech = reinterpret_cast<RE::FrameGenerationTech*>(Resolve(933291, AddressKind::Data, "uiFrameGenerationTech"));

		GetSettingsDataModelCheckboxParams = reinterpret_cast<tGetSettingsDataModelParams>(Resolve(88949, AddressKind::Code, "GetSettingsDataModelCheckboxParams"));
		GetSettingsDataModelStepperParams = reinterpret_cast<tGetSettingsDataModelParams>(Resolve(88948, AddressKind::Code, "GetSettingsDataModelStepperParams"));
		GetSettingsDataModelSliderParams = reinterpret_cast<tGetSettingsDataModelParams>(Resolve(88946, AddressKind::Code, "GetSettingsDataModelSliderParams"));

		if (resolveFailures > 0) {
			WARN("Offsets: {} address(es) failed validation - this build of Luma likely does not match the running game version", resolveFailures)
		} else {
			INFO("Offsets: all addresses resolved and validated")
		}
	}

private:
	static const ::IMAGE_SECTION_HEADER* FindSection(std::uintptr_t a_address)
	{
		auto&       gameModule = dku::Hook::Module::get();
		const auto  base = gameModule.base();
		const auto* ntHeader = gameModule.ntHeader();

		if (a_address < base) {
			return nullptr;
		}

		const auto  rva = static_cast<std::uint32_t>(a_address - base);
		const auto* section = gameModule.sectionHeader();

		for (std::uint16_t i = 0; i < ntHeader->FileHeader.NumberOfSections; ++i, ++section) {
			const auto size = section->Misc.VirtualSize ? section->Misc.VirtualSize : section->SizeOfRawData;
			if (rva >= section->VirtualAddress && rva < section->VirtualAddress + size) {
				return section;
			}
		}

		return nullptr;
	}

	static inline std::uint32_t resolveFailures = 0;
};
