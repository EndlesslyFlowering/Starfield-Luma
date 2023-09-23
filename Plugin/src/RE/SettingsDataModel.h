#pragma once

#include "UIDataShuttle.h"
#include "UI.h"

namespace RE
{
	class SubSettingsList
	{
	public:
		class GeneralSetting
		{
		public:
			struct Type
			{
				enum
				{
					Slider = 0,
					Stepper = 1,
					LargeStepper = 2,
					Checkbox = 3,
				};
			};

			struct Category
			{
				enum
				{
					Gameplay = 0,
					Display = 1,
					Interface = 2,
					Controls = 3,
					ControlMappings = 4,
					Audio = 5,
					Accessibility = 6,
				};
			};

			struct SliderData
			{
				TUIValue<float> m_Value;       // 0
				StringUIValue m_DisplayValue;  // 20
				char _pad40[0x8];              // 40
			};

			struct StepperData
			{
				TUIValue<unsigned int> m_Value;                              // 0
				ArrayUIValue<TUIValue<BSFixedStringCS>, 0> m_DisplayValues;  // 20
				char _pad98[0x8];                                            // 98
			};

			struct CheckBoxData
			{
				TUIValue<bool> m_Value;  // 0
				char _pad20[0x8];        // 20
			};

			StringUIValue m_Text;                        // 00
			StringUIValue m_Description;                 // 20
			TUIValue<unsigned int> m_ID;                 // 40
			TUIValue<unsigned int> m_Type;               // 60
			TUIValue<unsigned int> m_Category;           // 80
			TUIValue<bool> m_Enabled;                    // A0
			NestedUIValue<SliderData> m_SliderData;      // C0
			NestedUIValue<StepperData> m_StepperData;    // 158
			NestedUIValue<CheckBoxData> m_CheckBoxData;  // 248
			char _pad2C0[0x58];                          // 2D0

			GeneralSetting()
			{
				auto addr = dku::Hook::Module::get().base() + 0x20B801C;
				auto func = reinterpret_cast<void (*)(GeneralSetting&)>(addr);
				func(*this);
			}

			~GeneralSetting()
			{
				auto addr = dku::Hook::Module::get().base() + 0x20B9220;
				auto func = reinterpret_cast<void (*)(GeneralSetting&)>(addr);
				func(*this);
			}
		};

		ArrayNestedUIValue<GeneralSetting, 0> m_Settings;  // 0
		char _pad78[0x8];                                  // 78
	};

	class SettingsDataModel
	{
	public:
		class UpdateEventData
		{
		public:
			SettingsDataModel* m_Model;
			union
			{
				bool Bool;
				int Int;
				float Float;
			} m_Value;
			int m_ID;
		};

		char _pad0[0x190 + 0x20];
		TUIDataShuttleContainerMap<SubSettingsList> m_SubSettingsMap;
	};

	// Sanity checks
	static_assert(sizeof(NestedUIValue<SubSettingsList::GeneralSetting::SliderData>) == 0x98);
	static_assert(sizeof(NestedUIValue<SubSettingsList::GeneralSetting::StepperData>) == 0xF0);
	static_assert(sizeof(NestedUIValue<SubSettingsList::GeneralSetting::CheckBoxData>) == 0x78);

	static_assert(sizeof(TUIDataShuttleContainerMap<SubSettingsList::GeneralSetting::SliderData>) == 0x70);
	static_assert(sizeof(TUIDataShuttleContainerMap<SubSettingsList::GeneralSetting::StepperData>) == 0xC8);
	static_assert(sizeof(TUIDataShuttleContainerMap<SubSettingsList::GeneralSetting::CheckBoxData>) == 0x50);

	static_assert(sizeof(ArrayUIValue<NestedUIValue<SubSettingsList::GeneralSetting::SliderData>, 0>) == 0x78);

	static_assert(sizeof(SubSettingsList::GeneralSetting) == 0x318);
	static_assert(sizeof(ArrayNestedUIValue<SubSettingsList::GeneralSetting, 0>) == 0x78);

	static_assert(sizeof(TUIDataShuttleContainerMap<SubSettingsList>) == 0xA8);
}