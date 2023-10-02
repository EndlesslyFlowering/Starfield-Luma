#pragma once
#include "DKUtil/Config.hpp"

namespace Settings
{
    using namespace DKUtil::Alias;

    enum class SettingID : unsigned int
    {
        kHDR = 600,
        kMaxLuminance,
        kPaperwhite
    };

    class Main : public DKUtil::model::Singleton<Main>
    {
    public:
		Integer ImageSpaceBufferFormat{ "ImageSpaceBufferFormat", "Main" };
		Boolean UpgradeUIRenderTarget{ "UpgradeUIRenderTarget", "Main" };
		Integer UpgradeRenderTargets{ "UpgradeRenderTargets", "Main" };

		Integer FrameBufferFormat{ "FrameBufferFormat", "HDR" };
		Double MaxLuminance{ "MaxLuminance", "HDR" };
		Double Paperwhite{ "Paperwhite", "HDR" };

		String RenderTargetsToUpgrade{ "RenderTargetsToUpgrade", "RenderTargets" };

        bool IsHDREnabled() const;

		float GetMaxLuminanceSliderPercentage() const;
		std::string GetMaxLuminanceText() const;
		float GetMaxLuminanceFromSlider(float a_percentage) const;
		void SetMaxLuminanceFromSlider(float a_percentage);

		float GetPaperwhiteSliderPercentage() const;
		std::string GetPaperwhiteText() const;
        float GetPaperwhiteFromSlider(float a_percentage) const;
		void SetPaperwhiteFromSlider(float a_percentage);

        void Load() noexcept;

    private:
        static inline constexpr float luminanceSliderMin = 400.f;
        static inline constexpr float luminanceSliderMax = 2000.f;
        static inline constexpr float paperwhiteSliderMin = 80.f;
        static inline constexpr float paperwhiteSliderMax = 500.f;

		TomlConfig config = COMPILE_PROXY("NativeHDR.toml"sv);
    };
}
