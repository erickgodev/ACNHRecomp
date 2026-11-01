@echo off
setlocal

rem Build the source launcher and the dynamic Windows player.
rem The game DLL and SPIR-V files remain in the folder prepared by ACNHRecomp-Importer.

cd /d "%~dp0"
set "REPO=%CD%"
set "PRIVATE=%REPO%\private"
set "CMAKE=%PRIVATE%\venv\Scripts\cmake.exe"
set "NINJA=%PRIVATE%\venv\Scripts\ninja.exe"
set "LLVM=%PRIVATE%\third_party\llvm-23.1.3"
set "CLANG=%LLVM%\bin\clang-cl.exe"
set "SDL=%PRIVATE%\third_party\SDL3-3.4.16"
set "VKH=%PRIVATE%\third_party\Vulkan-Headers-1.4.357\include"
set "IMGUI=%PRIVATE%\third_party\imgui"
set "VCPKG=%PRIVATE%\third_party\vcpkg\installed\x64-windows-static-md-release"
set "LAUNCHER_BUILD=%REPO%\build\launcher"
set "PLAYER_BUILD=%REPO%\build\player"

if not exist "%CMAKE%" goto :missing_tools
if not exist "%NINJA%" goto :missing_tools
if not exist "%CLANG%" goto :missing_tools
if not exist "%SDL%\cmake\SDL3Config.cmake" goto :missing_tools
if not exist "%VKH%\vulkan\vulkan.h" goto :missing_tools
if not exist "%IMGUI%\imgui.cpp" goto :missing_tools

set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" goto :missing_vs
for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSINSTALL=%%i"
if not defined VSINSTALL goto :missing_vs
if not exist "%VSINSTALL%\VC\Auxiliary\Build\vcvars64.bat" goto :missing_vs

call "%VSINSTALL%\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 goto :build_failed
set "PATH=%PRIVATE%\venv\Scripts;%LLVM%\bin;%PATH%"

echo.
echo [1/2] Configuring and building the launcher...
"%CMAKE%" -S "%REPO%" -B "%LAUNCHER_BUILD%" -G Ninja ^
  "-DCMAKE_MAKE_PROGRAM=%NINJA%" ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DNX_GAME=acnh ^
  "-DNX_GEN_DIR=%LAUNCHER_BUILD%\no-gen" ^
  "-DNX_IMGUI_DIR=%IMGUI%" ^
  "-DCMAKE_PREFIX_PATH=%SDL%" ^
  "-DCMAKE_C_COMPILER=%CLANG%" ^
  "-DCMAKE_CXX_COMPILER=%CLANG%"
if errorlevel 1 goto :build_failed
"%CMAKE%" --build "%LAUNCHER_BUILD%" --target acnhrecomp_launcher
if errorlevel 1 goto :build_failed

echo.
echo [2/2] Configuring and building the player (uses Importer DLL and shaders)...
"%CMAKE%" -S "%REPO%" -B "%PLAYER_BUILD%" -G Ninja ^
  "-DCMAKE_MAKE_PROGRAM=%NINJA%" ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DNX_GAME=acnh ^
  -DNX_GAME_FROM_FOLDER=ON ^
  -DNX_LAUNCHER=OFF ^
  "-DNX_GEN_DIR=%PLAYER_BUILD%\no-gen" ^
  "-DNX_VULKAN_INCLUDE=%VKH%" ^
  "-DNX_IMGUI_DIR=%IMGUI%" ^
  "-DCMAKE_PREFIX_PATH=%SDL%;%VCPKG%" ^
  "-DCMAKE_RUNTIME_OUTPUT_DIRECTORY=%LAUNCHER_BUILD%" ^
  "-DCMAKE_C_COMPILER=%CLANG%" ^
  "-DCMAKE_CXX_COMPILER=%CLANG%"
if errorlevel 1 goto :build_failed
"%CMAKE%" --build "%PLAYER_BUILD%" --target acnh
if errorlevel 1 goto :build_failed

echo.
echo Build complete:
echo   %LAUNCHER_BUILD%\acnhrecomp_launcher.exe
echo   %LAUNCHER_BUILD%\acnh.exe
echo.
exit /b 0

:missing_tools
echo Required dependencies are missing under private\third_party.
echo Run tools\setup_acnh.py once to fetch the compiler, CMake, Ninja and libraries.
exit /b 1

:missing_vs
echo Visual Studio C++ tools were not found.
echo Install the "Desktop development with C++" workload in Visual Studio Installer.
exit /b 1

:build_failed
echo Build failed. Check the CMake/Ninja output above.
exit /b 1
