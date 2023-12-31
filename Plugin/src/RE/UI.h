#pragma once

#include "BSFixedString.h"
#include "UIDataShuttle.h"

namespace RE
{
	class __declspec(novtable) IUIValue
	{
	public:
		IUIValue() = default;
		virtual ~IUIValue() = default;                                  // 00
		virtual void IUIValue_01() = 0;                                 // 01
		virtual void IUIValue_02() = 0;                                 // 02
		virtual void IUIValue_03() = 0;                                 // 03
		virtual void IUIValue_04() = 0;                                 // 04
		virtual void IUIValue_05() = 0;                                 // 05
		virtual void IUIValue_06() = 0;                                 // 06
		virtual void IUIValue_07() = 0;                                 // 07
		virtual bool GetNeedsUpdate();                                  // 08
		virtual void SetNeedsUpdateAndNotifyShuttle(bool NeedsUpdate);  // 09
		virtual void SetNeedsUpdate();                                  // 0A
		virtual void IUIValue_0B() = 0;                                 // 0B

		UIDataShuttle* m_DataShuttle = nullptr;  // 08
		bool m_NeedsUpdate = true;               // 10

		void TriggerParentUpdate()
		{
			if (m_DataShuttle && m_DataShuttle->UIDataShuttle_06())
				m_DataShuttle->UIDataShuttle_02(*this);
		}
	};
	static_assert(sizeof(IUIValue) == 0x18);

	class __declspec(novtable) IArrayUIValue
	{
	public:
	};
	static_assert(sizeof(IArrayUIValue) == 0x1);

	template <typename T>
	class __declspec(novtable) TUIValue : public IUIValue
	{
	public:
		TUIValue() = default;
		virtual ~TUIValue() override = default;  // 00
		virtual void IUIValue_01() override;     // 01
		virtual void IUIValue_02() override;     // 02
		virtual void IUIValue_03() override;     // 03
		virtual void IUIValue_04() override;     // 04
		virtual void IUIValue_05() override;     // 05
		virtual void IUIValue_06() override;     // 06
		virtual void IUIValue_07() override;     // 07
		virtual void IUIValue_0B() override;     // 0B

		T m_Value = {};  // 18

		TUIValue& SetValue(const T& Value)
		{
			TriggerParentUpdate();

			if (m_Value != Value) {
				m_Value = Value;
				SetNeedsUpdateAndNotifyShuttle(true);
			}

			return *this;
		}
	};
	static_assert(sizeof(TUIValue<unsigned int>) == 0x20);
	static_assert(sizeof(TUIValue<bool>) == 0x20);

	class __declspec(novtable) StringUIValue : public TUIValue<BSFixedStringCS>
	{
	public:
		StringUIValue() = default;
		virtual ~StringUIValue() override = default;     // 00
		virtual void StringUIValue_0C();                 // 0C
		virtual void SetStringValue(const char* Value);  // 0D
	};
	static_assert(sizeof(StringUIValue) == 0x20);

	template <typename T>
	class __declspec(novtable) NestedUIValue : public IUIValue, public UIDataShuttle
	{
	public:
		NestedUIValue() = default;
		virtual ~NestedUIValue() override = default;  // 00

		// IUIValue
		virtual void IUIValue_01() override;                                     // 01
		virtual void IUIValue_02() override;                                     // 02
		virtual void IUIValue_03() override;                                     // 03
		virtual void IUIValue_04() override;                                     // 04
		virtual void IUIValue_05() override;                                     // 05
		virtual void IUIValue_06() override;                                     // 06
		virtual void IUIValue_07() override;                                     // 07
		virtual void SetNeedsUpdateAndNotifyShuttle(bool NeedsUpdate) override;  // 09
		virtual void SetNeedsUpdate() override;                                  // 0A
		virtual void IUIValue_0B() override;                                     // 0B

		// UIDataShuttle
		virtual void UIDataShuttle_01() override;                   // 01
		virtual void UIDataShuttle_02(IUIValue& UIValue) override;  // 02
		virtual void UIDataShuttle_03() override;                   // 03
		virtual void UIDataShuttle_04() override;                   // 04
		virtual void UIDataShuttle_05() override;                   // 05
		virtual bool UIDataShuttle_06() override;                   // 06
		virtual bool UIDataShuttle_07() override;                   // 07

		TUIDataShuttleContainerMap<T> m_ShuttleMap;  // 28
	};

	template <typename T, int Count>
	class __declspec(novtable) ArrayUIValue : public IUIValue, public UIDataShuttle, public IArrayUIValue
	{
	public:
		ArrayUIValue() = default;
		virtual ~ArrayUIValue() override = default;  // 00

		// IUIValue
		virtual void IUIValue_01() override;                                     // 01
		virtual void IUIValue_02() override;                                     // 02
		virtual void IUIValue_03() override;                                     // 03
		virtual void IUIValue_04() override;                                     // 04
		virtual void IUIValue_05() override;                                     // 05
		virtual void IUIValue_06() override;                                     // 06
		virtual void IUIValue_07() override;                                     // 07
		virtual void SetNeedsUpdateAndNotifyShuttle(bool NeedsUpdate) override;  // 09
		virtual void SetNeedsUpdate() override;                                  // 0A
		virtual void IUIValue_0B() override;                                     // 0B

		// UIDataShuttle
		virtual void UIDataShuttle_01() override;                   // 01
		virtual void UIDataShuttle_02(IUIValue& UIValue) override;  // 02
		virtual void UIDataShuttle_03() override;                   // 03
		virtual void UIDataShuttle_04() override;                   // 04
		virtual void UIDataShuttle_05() override;                   // 05
		virtual bool UIDataShuttle_06() override;                   // 06
		virtual bool UIDataShuttle_07() override;                   // 07

		TUIDataShuttleContainerArray<T> m_ShuttleArray;  // 28

		void AddItem(const BSFixedStringCS& Item)
		{
			auto addr = dku::Hook::IDToAbs(134612);
			auto func = reinterpret_cast<void (*)(ArrayUIValue<T, Count>*, const BSFixedStringCS&)>(addr);
			func(this, Item);
		}

		[[nodiscard]] auto Items() const noexcept
		{
			return m_ShuttleArray.Items();
		}
	};

	template <typename T, int Count>
	class __declspec(novtable) ArrayNestedUIValue : public ArrayUIValue<NestedUIValue<T>, Count>
	{
	public:
		void AddItem(T& Item)
		{
			// Seems like they have a helper function to apply NestedUIValue<> to the type
			auto addr = dku::Hook::IDToAbs(135760);
			auto func = reinterpret_cast<void (*)(TUIDataShuttleContainerArray<NestedUIValue<T>>*, T&)>(addr);
			func(&__super::m_ShuttleArray, Item);
		}
	};
}
