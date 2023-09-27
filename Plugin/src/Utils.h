#pragma once
#include "RE/Buffers.h"

#include <d3d12.h>

namespace Utils
{
	std::unordered_map<DXGI_FORMAT, std::string> GetDXGIFormatNameMap();

	void LogFormats();

	void LogBuffers();

	void SetBufferFormat(RE::BufferDefinition* a_buffer, RE::BS_DXGI_FORMAT a_format);
	void SetBufferFormat(RE::Buffers a_buffer, RE::BS_DXGI_FORMAT a_format);
}
