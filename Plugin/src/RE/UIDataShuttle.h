#pragma once

#include <span>

namespace RE
{
	class IUIValue;

	class __declspec(novtable) UIDataShuttle
	{
	public:
		UIDataShuttle() = default;
		virtual ~UIDataShuttle() = default;                    // 00
		virtual void UIDataShuttle_01() = 0;                   // 01
		virtual void UIDataShuttle_02(IUIValue& UIValue) = 0;  // 02
		virtual void UIDataShuttle_03() = 0;                   // 03
		virtual void UIDataShuttle_04() = 0;                   // 04
		virtual void UIDataShuttle_05() = 0;                   // 05
		virtual bool UIDataShuttle_06() = 0;                   // 06
		virtual bool UIDataShuttle_07() = 0;                   // 07

		char _pad0[0x8];  // 08
	};
	static_assert(sizeof(UIDataShuttle) == 0x10);

	class __declspec(novtable) UIDataShuttleContainer
	{
	public:
		UIDataShuttleContainer() = default;
		virtual void UIDataShuttleContainer_00();      // 00
		virtual void UIDataShuttleContainer_01();      // 01
		virtual void UIDataShuttleContainer_02() = 0;  // 02
		virtual void UIDataShuttleContainer_03() = 0;  // 03
		virtual void UIDataShuttleContainer_04() = 0;  // 04
		virtual void UIDataShuttleContainer_05();      // 05
		virtual void UIDataShuttleContainer_06();      // 06
		virtual void UIDataShuttleContainer_07();      // 07
		virtual void UIDataShuttleContainer_08() = 0;  // 08
		virtual ~UIDataShuttleContainer() = default;   // 09

		char _pad0[0x8];  // 08
	};
	static_assert(sizeof(UIDataShuttleContainer) == 0x10);

	template <typename T>
	class __declspec(novtable) TUIDataShuttleContainerArray : public UIDataShuttleContainer
	{
	public:
		TUIDataShuttleContainerArray() = default;
		virtual void UIDataShuttleContainer_00() override;           // 00
		virtual void UIDataShuttleContainer_01() override;           // 01
		virtual void UIDataShuttleContainer_02() override;           // 02
		virtual void UIDataShuttleContainer_03() override;           // 03
		virtual void UIDataShuttleContainer_04() override;           // 04
		virtual void UIDataShuttleContainer_05() override;           // 05
		virtual void UIDataShuttleContainer_06() override;           // 06
		virtual void UIDataShuttleContainer_07() override;           // 07
		virtual void UIDataShuttleContainer_08() override;           // 08
		virtual ~TUIDataShuttleContainerArray() override = default;  // 09

		T* m_ArrayBegin;    // 10
		T* m_ArrayEnd;      // 18
		char _pad20[0x30];  // 20

		[[nodiscard]] auto Items() const noexcept
		{
			return std::span{ m_ArrayBegin, m_ArrayEnd };
		}
	};
	//static_assert(sizeof(TUIDataShuttleContainerArray<TUIValue<int>>) == 0x50);

	template <typename T>
	class __declspec(novtable) TUIDataShuttleContainerMap : public UIDataShuttleContainer
	{
	public:
		TUIDataShuttleContainerMap() = default;
		virtual void UIDataShuttleContainer_00() override;         // 00
		virtual void UIDataShuttleContainer_02() override;         // 02
		virtual void UIDataShuttleContainer_03() override;         // 03
		virtual void UIDataShuttleContainer_04() override;         // 04
		virtual void UIDataShuttleContainer_05() override;         // 05
		virtual void UIDataShuttleContainer_06() override;         // 06
		virtual void UIDataShuttleContainer_07() override;         // 07
		virtual void UIDataShuttleContainer_08() override;         // 08
		virtual ~TUIDataShuttleContainerMap() override = default;  // 09
		virtual void TUIDataShuttleContainerMap_0A();              // 0A Identical to GetData(). Const version?
		virtual T& GetData();                                      // 0A

		char _pad10[0x18];  // 10
		T m_Data;           // 28
	};
	//static_assert((sizeof(TUIDataShuttleContainerMap<TUIValue<int>>) - sizeof(TUIValue<int>)) == 0x28);
}