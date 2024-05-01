[![CMake on Windows](https://github.com/EndlesslyFlowering/Starfield-Luma/actions/workflows/cmake-windows.yml/badge.svg)](https://github.com/EndlesslyFlowering/Starfield-Luma/actions/workflows/cmake-windows.yml)

Source code for the Starfield Luma mod.

To set up a development environment for this mod (skip to step 7 if you don't care about developing the code plugin and only want to modify shaders):
1) Have Visual Studio (only VS 2022 was tested) installed, with components to build C++ code for Windows
2) Follow the requirements specified here: [SF Plugin Template requirements](https://github.com/gottyduke/SF_PluginTemplate#-requirements). You need to install vcpkg and CMake, either as VS installer components or as a custom install, and set up the specified environment paths
3) Install the official mod and anything that comes along with it (e.g. SFSE, Shader Injector): [Starfield Luma](https://www.nexusmods.com/starfield/mods/4821)
4) Run `make-sln-msvc.bat`
5) Open `build\Luma.sln` with VS and run the `ALL_BUILD` CMake in `Release` configuration, this will automatically build the plugin binary and copy it and its shaders in your game mods directory (and reset the mod settings)
6) Alternatively, run `build-msvc-release.bat`, though that might not work
7) If you don't have the `SFPath` environment variable set up from a prior step, open `shaders\target_folder.txt` and paste your Starfield mods directory + relative shaders binaries path in there (e.g. `C:\Games\Starfield\Data\shadersfx\`)
8) set the `DEVELOPMENT` defines to `1` in `Plugin\src\Settings.h` and `shaders\shared.hlsl` to have full access to the mod development settings
9) To allow shaders hot reload (live edits) while running, open `SFShaderInjector.ini` (it goes alongside the Shader Injector ASI or DLL, wherever the mod was installed) and change `AllowLiveUpdates` to `1`
10) You can now modify (or add) any hlsl shader in the `shaders` folder and run `compile_all_shaders.ps1` to build them and copy them to the game folder
11) Run `Plugin\dist\deploy-release.ps1` to package a new full release

If you want to modify the Shader Injector source code, you can find it [here](https://github.com/Nukem9/sf-shader-injector). That isn't necessary for the development of this mod.
If you want to bump up the project version, it's in `Plugin\CMakeList.txt`.
Note that `SFPath` can also point to a virtual folder from a mod manager.
