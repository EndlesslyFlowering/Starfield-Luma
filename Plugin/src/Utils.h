#pragma once
#include <d3d12.h>

namespace Utils
{
	std::unordered_map<DXGI_FORMAT, std::string> GetDXGIFormatNameMap();

	void LogFormats();

	void LogBuffers();
}
