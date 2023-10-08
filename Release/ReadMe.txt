This mod was created by 5 (HDR passionate) developers (Ersh, Pumbo (Filoppi / Filippo T.), Lilium, Nukem and ShortFuse), whom all took on different roles to achieve a large refactor of the game post processing phase.
The main thing the mod does is adding Native HDR support to the game, which is not the same as the one seen on Xbox, this version changes the game tonemapper and color correction phase to give a much more HDR look, while also trying to retaining the look and feel of the vanilla game. This was achieved by replacing the game shaders.
This mod also improves the look of the game in SDR, so benefits are not restricted to HDR users.
This is a follow up to https://www.nexusmods.com/starfield/mods/588, which just increased the quality of the game buffers to 10bit+, leaving more room for AutoHDR to work.

List of features:
-Native HDR (scRGB and HDR10)
-Increased buffers accuracy in SDR and HDR, which reduced banding all around (SDR is now 10bit instead of 8bit)
-Normalized LUTs, the grey/flat look is mostly gone, but the color tint is still there (this mod includes a runtime version of https://www.nexusmods.com/starfield/mods/2407)
-Fixed bink fullscreen videos playing back with the wrong colors (BT.709 instead of BT.601)
-Improved the sharpening passes
-Improved film grain to be more realistic and nice to look at (e.g. rebalancing the grain size and strength on white/black colors)
-Fixed the game using very wrong gamma formulas
-Customization settings for you to personalize the game visuals

How to use:
Drop the content of the mod into the game root folder, or install it with a mod manager in the game root folder.
The game needs to be started through "sfse_loader.exe".
You can configure the mod from the game graphics setting menu. It also hooks to ReShade if you have installed, you will see the settings menu as a small ReShade widget.
There's also a config file in the dll folders, delete it to reset settings.
To uninstall, clear all the files (they are unique to the mod).

Compatibility:
This mod should work with any other mod, including DLSS Super Resolution and DLSS Frame Generation (scRGB is NOT supported by FG).
You can also use customized LUTs mods, but if you do, make sure to disable "LUTs Correction" in the mods settings, or they will be corrected twice. Our suggestion is to use the LUT correction that is built in with the mod.
You do NOT need any other HDR related mod, like AutoHDR, or "HUD for HDR" (which dimmed the UI for AutoHDR).

Issues:
-The UI blends in slightly differently in HDR, usually it's not noticeable
-scRGB HDR doesn't work with DLSS Frame Generation
-You can not take screenshots directly from Starfield in photo mode