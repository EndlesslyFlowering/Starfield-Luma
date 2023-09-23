#include "Hooks.h"

#include "Offsets.h"
#include "Utils.h"

namespace Hooks
{
    RE::BufferDefinition* Patches::GetBufferFromString(std::string_view a_bufferName)
	{
		const auto& bufferArray = *Offsets::bufferArray;
		for (const auto& bufferDefinition : bufferArray) {
		    if (bufferDefinition->bufferName == a_bufferName) {
                return bufferDefinition;
            }
		}

		return nullptr;
	}
	
    void Patches::UpgradeRenderTarget(RE::BufferDefinition* a_buffer, RE::BS_DXGI_FORMAT a_newFormat, bool a_bLimited)
    {
		if (!a_buffer) {
		    return;
		}

		if (!std::strcmp(a_buffer->bufferName, "FrameBuffer") || !std::strcmp(a_buffer->bufferName, "ImageSpaceBuffer") || !std::strcmp(a_buffer->bufferName, "ScaleformCompositeBuffer")) {
			INFO("Warning: {} - skipping because buffer is handled by a separate setting", a_buffer->bufferName)
			return;
		}

		if (a_bLimited && a_buffer->format != RE::BS_DXGI_FORMAT::BS_DXGI_FORMAT_R8G8B8A8_UNORM && a_buffer->format != RE::BS_DXGI_FORMAT::BS_DXGI_FORMAT_R8G8B8A8_UNORM_SRGB) {
			auto formatNames = Utils::GetDXGIFormatNameMap();
			INFO("{} - skipping because format is {}", a_buffer->bufferName, formatNames[Offsets::GetDXGIFormat(a_buffer->format)])
			return;
		}

		SetBufferFormat(a_buffer, a_newFormat);
    }

    void Patches::SetBufferFormat(RE::BufferDefinition* a_buffer, RE::BS_DXGI_FORMAT a_newFormat)
    {
		if (!a_buffer) {
		    return;
		}

		auto formatNames = Utils::GetDXGIFormatNameMap();
		INFO("{} - changing from format {} to {}", a_buffer->bufferName, formatNames[Offsets::GetDXGIFormat(a_buffer->format)], formatNames[Offsets::GetDXGIFormat(a_newFormat)])
		a_buffer->format = a_newFormat;
    }

    void Patches::SetBufferFormat(RE::Buffers a_buffer, RE::BS_DXGI_FORMAT a_format)
	{
		const auto buffer = (*Offsets::bufferArray)[static_cast<uint32_t>(a_buffer)];
		SetBufferFormat(buffer, a_format);
	}

    void Hooks::Hook_UnkFunc(uintptr_t a1, UnkObject* a2)
    {
		const auto settings = Settings::Main::GetSingleton();
		switch (*settings->FrameBufferFormat) {
		case 1:
			a2->swapChainInterface->SetColorSpace1(DXGI_COLOR_SPACE_RGB_FULL_G2084_NONE_P2020);
			break;
		case 2:
			a2->swapChainInterface->SetColorSpace1(DXGI_COLOR_SPACE_RGB_FULL_G10_NONE_P709);
			break;
		}

		return _UnkFunc(a1, a2);		
    }

#ifndef NDEBUG
    void DebugHooks::Hook_CreateRenderTargetView(uintptr_t a1, ID3D12Resource* a_resource, DXGI_FORMAT a_format, uint8_t a4, uint16_t a5, uintptr_t a6)
    {
		const auto textureDesc = a_resource->GetDesc();

		_CreateRenderTargetView(a1, a_resource, a_format, a4, a5, a6);
    }

    void DebugHooks::Hook_CreateDepthStencilView(uintptr_t a1, ID3D12Resource* a_resource, DXGI_FORMAT a_format, uint8_t a4, uint16_t a5, uintptr_t a6)
    {
		const auto textureDesc = a_resource->GetDesc();

		_CreateDepthStencilView(a1, a_resource, a_format, a4, a5, a6);
    }
#endif

    void Install()
	{
#ifndef NDEBUG
	    Utils::LogBuffers();
		DebugHooks::Hook();
#endif
		Hooks::Hook();
		Patches::Patch();
	}
}
