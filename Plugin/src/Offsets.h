#pragma once
#include "RE/Buffers.h"

class Offsets
{
public:
	using BufferArray = std::array<RE::BufferDefinition*, 204>;
	static inline BufferArray* bufferArray = nullptr;

	using tGetDXGIFormat = DXGI_FORMAT (*)(RE::BS_DXGI_FORMAT a_bgsFormat);
	static inline tGetDXGIFormat GetDXGIFormat = nullptr;

	static void Initialize()
	{
		{
			const auto scan = static_cast<uint8_t*>(dku::Hook::Assembly::search_pattern<"4C 8D 15 ?? ?? ?? ?? BE ?? ?? ?? ??">());
			if (!scan) {
				ERROR("Failed to find buffer definition array!")
			}
			const auto offset = *reinterpret_cast<int32_t*>(scan + 3);
			const auto address = reinterpret_cast<uintptr_t>(scan) + 7 + offset;
			bufferArray = reinterpret_cast<BufferArray*>(address);  // 4718E40
			INFO("Found buffer array at {:X}", address)
		}

		{
			const auto scan = static_cast<uint8_t*>(dku::Hook::Assembly::search_pattern<"E8 ?? ?? ?? ?? 89 45 94">());
			if (!scan) {
				ERROR("Failed to find GetDXGIFormat!")
			}
			GetDXGIFormat = dku::Hook::GetDisp<tGetDXGIFormat>(scan);  // 32F18A0
			INFO("Found GetDXGIFormat at {:X}", reinterpret_cast<uintptr_t>(scan))
		}
	}
};
