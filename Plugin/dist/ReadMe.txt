Luma aims to rewrite the game post processing phase to drastically improve the look without drifting too much from the original artistic vision.
The highlight feature is adding Native HDR support, which is not the same as the fake official HDR seen on the Xbox version, though benefits are not restricted to HDR users,
all LUTs are now normalized at runtime without needing any content changes, banding is gone, there's gamma correction etc etc.

Luma was created by 4 HDR passionate developers (Ersh, Pumbo, Lilium, ShortFuse), whom all took on different roles to achieve this expansive refactor.
It is a follow up to the "Native AutoHDR and Color Banding Fix" mod https://www.nexusmods.com/starfield/mods/588 (Ersh), which just increased the quality of the game buffers to 10bit+, leaving more room for AutoHDR to work.
It is a spiritual successor to the CONTROL HDR mod https://www.nexusmods.com/control/mods/90 (Pumbo).
It inclues an improved version of the "Normalized LUTs" mod https://www.nexusmods.com/starfield/mods/2407 (ShortFuse).
It was built by using the HDR analysis ReShade shaders https://github.com/EndlesslyFlowering/ReShade_HDR_shaders (Lilium).
Join our discord here: https://discord.gg/DNGfMZgH3f.
We plan on going open source soon and we hope for many of you to contribute.

List of features:
-Native HDR (scRGB and HDR10)
-Increased buffers accuracy in SDR and HDR, which reduced banding all around (SDR is now 10bit instead of 8bit)
-Normalized LUTs, the grey/flat look is mostly gone, but the color tint is still there
-Fixed bink fullscreen videos playing back with the wrong colors (BT.601 instead of BT.709) and made them use AutoHDR
-Improved the sharpening passes
-Improved film grain to be more realistic and nice to look at (e.g. rebalancing the grain size and strength on dark/bright colors)
-Fixed the game using very wrong gamma formulas
-Customization settings for you to personalize the game visuals (all of the features above are adjustable at runtime)
-More!

Details on the implementation:
Luma was achieved by reverse engineering, re-writing and replacing the game post process shaders:
the whole tonemapping, post processing and color correction (LUTs) phase has been re-written
to follow much more recent quality standards, while maintaining a similar performance level and allowing for more customization.
LUTs are analyzed at runtime and expanded to use their whole range (which can go into HDR territory), while maintaining their color tint.
The SDR tonemappers (Hable and ACES) have also been partially replaced to better handle highlights and BT.2020 colors in HDR.
The performance impact is minimal compared to the quality gains.

How to use:
Drop the content of the mod into the game root folder, or install it with a mod manager in the game root folder.
The game needs to be started through the SFSE loader on Steam and ASI loader on Microsoft Store (Game Pass).
Please remove the old "NativeHDR" or "NativeAutoHDR" mods before starting Luma.
You can access Luma's settings directly from the game graphics setting menu. If you ahve ReShade installed, our settings will also be visible there through a widget.
There a .toml config file in the mod's dll/asi folders, delete it to reset settings.
To uninstall, clear all the files (they are unique to the mod).

Dependencies:
-Starfield Script Extender (SFSE): https://www.nexusmods.com/starfield/mods/106
-Address Library for SFSE: https://www.nexusmods.com/starfield/mods/3256
-ShaderInjector by Nukem (included in the mod)

Compatibility:
This mod should work with any other mod, including DLSS Super Resolution and DLSS Frame Generation (scRGB is NOT supported by FG).
You can also use customized LUTs mods, but if you do, make sure to disable "LUTs Correction" in the mods settings, or they will be corrected twice.
Our suggestion is to use the LUT correction that is built in Luma, as it extract extracts HDR detail out of SDR LUTs while normalizing them, something that cannot be achieved by replacing assets.
Additionally Luma should be compatible with any story content and new location, whether official added by Bethesda as DLCs, or unofficial mods. 
You do NOT need any other HDR related mod, like AutoHDR ReShades, SpecialK, or "HUD for HDR" (which dimmed the UI for AutoHDR).
Refrain from using any ReShade shaders unless you are certain they support HDR.
If you find the playabla character flashlight too intense, you can use this mod https://www.nexusmods.com/starfield/mods/4888.

Issues and limitations:
-scRGB HDR doesn't work with DLSS Frame Generation (ping Nvidia about that)
-You can not take screenshots directly from Starfield in photo mode

Comparison with other "HDR" methods:
-Starfield Xbox HDR: Starfield on Xbox uses an internal version of AutoHDR, the output image in HDR is extracted from an SDR one, thus its visual quality is still bottlenecked by that.
-Windows 11 AutoHDR: Windows 11 can apply fake HDR as post process filter, but this is still limited by 8bits output (causing banding), interprets games as gamma sRGB instead of 2.2, and doesn't go anywhere beyond 1000 nits. Additionally, it makes the game UI too bright.
-SpecialK HDR Retrofit: It can upgrade all buffers to 16bit but the game tonemapping remains SDR, and highlights gets mushed together and clipped.
-Pumbo's Advanced Auto HDR + DXVK: Same problems as SpecialK HDR.