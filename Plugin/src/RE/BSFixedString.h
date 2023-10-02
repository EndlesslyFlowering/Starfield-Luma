#pragma once

namespace RE
{
	class BSFixedStringCS
	{
	private:
		void* m_EntryPoolData = nullptr;

	public:
		BSFixedStringCS() = default;

		BSFixedStringCS(const char* String)
		{
			auto addr = dku::Hook::IDToAbs(198219);
			auto func = reinterpret_cast<void (*)(BSFixedStringCS*, const char*)>(addr);
			func(this, String);
		}

		BSFixedStringCS(const BSFixedStringCS& Other) = delete;

		~BSFixedStringCS()
		{
			auto addr = dku::Hook::IDToAbs(33964);
			auto func = reinterpret_cast<void (*)(BSFixedStringCS*)>(addr);
			func(this);
		}

		BSFixedStringCS& operator=(const BSFixedStringCS& Other) = delete;

		bool operator==(const BSFixedStringCS& Other) const
		{
			return m_EntryPoolData == Other.m_EntryPoolData;
		}

		bool operator!=(const BSFixedStringCS& Other) const
		{
			return m_EntryPoolData != Other.m_EntryPoolData;
		}
	};
}
