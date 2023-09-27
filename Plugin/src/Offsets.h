#pragma once
#include "RE/Buffers.h"

class Offsets
{
public:
	using BufferArray = std::array<RE::BufferDefinition*, 204>;
	static inline BufferArray* bufferArray = nullptr;

	using tGetDXGIFormat = DXGI_FORMAT (*)(RE::BS_DXGI_FORMAT a_bgsFormat);
	static inline tGetDXGIFormat GetDXGIFormat = nullptr;

	using tRecreateSwapChain = void (*)(void* a1, RE::BGSSwapChainObject* a_bgsSwapChainObject, uint32_t a_width, uint32_t a_height, uint8_t a5);
	static inline tRecreateSwapChain RecreateSwapChain = nullptr;

	static inline uintptr_t* unkRecreateSwapChainArg1Ptr = nullptr;
	static inline uint8_t* unkRecreateSwapChainArg5 = nullptr;

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

	    RecreateSwapChain = reinterpret_cast<tRecreateSwapChain>(dku::Hook::Module::get().base() + 0x32F4BEC);  // 0x32F14BC in 1.7.23

		unkRecreateSwapChainArg1Ptr = reinterpret_cast<uintptr_t*>(dku::Hook::Module::get().base() + 0x5916FF0);  // 0x5912F80 in 1.7.23
		unkRecreateSwapChainArg5 = reinterpret_cast<uint8_t*>(dku::Hook::Module::get().base() + 0x55F8DB0);  // 0x55F4D70 in 1.7.23
	}
};
