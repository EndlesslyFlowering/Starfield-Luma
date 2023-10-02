#pragma once

namespace RE
{
	class MessageBoxData
	{
	public:
		MessageBoxData() = default;

		MessageBoxData(const char* a_messageTitle, const char* a_messageText, void* a4, int32_t a5)
		{
			auto addr = dku::Hook::IDToAbs(81979);
			auto func = reinterpret_cast<void (*)(MessageBoxData*, const char*, const char*, void*, int32_t)>(addr);
			func(this, a_messageTitle, a_messageText, a4, a5);
		}

		MessageBoxData(const MessageBoxData& Other) = delete;

		~MessageBoxData()
		{
			auto addr = dku::Hook::IDToAbs(82034);
			auto func = reinterpret_cast<void (*)(MessageBoxData*)>(addr);
			func(this);
		}

		MessageBoxData& operator=(const MessageBoxData& Other) = delete;

		// members
		uint64_t unk00;
		uint64_t unk08;
		uint64_t unk10;
		uint64_t unk18;
		uint64_t unk20;
		uint64_t unk28;
		uint64_t unk30;
		int32_t unk38;
	};
	static_assert(sizeof(MessageBoxData) == 0x40);

}
