@echo off
rem Builds the vendored Filament (../filament) with MSVC into
rem filament\out\cmake-release-windows, the static libraries hook/build.dart
rem links on Windows. Same feature set as the Linux out/cmake-release build;
rem the static CRT (/MT) matches the cl.exe default the native-assets hook
rem compiles flutter_filament.dll with. Needs Visual Studio 2022 with the C++
rem workload (cl, CMake, Ninja) and Python 3.
rem
rem   tool\build_filament_windows.bat            configure (first run) + build
rem   tool\build_filament_windows.bat filament   rebuild one target
rem
rem LUMINA_FILAMENT_SRC names another checkout (tool\filament\build_prebuilt.ps1
rem builds the release archives through this script, with the same flags).
setlocal
set "FILAMENT=%~dp0..\..\filament"
if defined LUMINA_FILAMENT_SRC set "FILAMENT=%LUMINA_FILAMENT_SRC%"
set "OUT=%FILAMENT%\out\cmake-release-windows"

if not defined VCINSTALLDIR (
  for /f "usebackq delims=" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSDIR=%%i"
)
if defined VSDIR call "%VSDIR%\VC\Auxiliary\Build\vcvars64.bat" >nul || exit /b 1
if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" set "PATH=%LOCALAPPDATA%\Programs\Python\Python312;%PATH%"

if not exist "%OUT%\build.ninja" (
  cmake -S "%FILAMENT%" -B "%OUT%" -G Ninja -DCMAKE_BUILD_TYPE=Release ^
    -DFILAMENT_BUILD_TESTING=OFF ^
    -DFILAMENT_SUPPORTS_VULKAN=ON -DFILAMENT_SUPPORTS_OPENGL=ON ^
    -DFILAMENT_BUILD_FILAMAT=ON -DFILAMENT_ENABLE_MATDBG=OFF ^
    -DFILAMENT_SUPPORTS_WEBP_TEXTURES=ON ^
    -DFILAMENT_ENABLE_EXCEPTIONS=ON -DUSE_STATIC_CRT=ON || exit /b 1
)
ninja -C "%OUT%" %* || exit /b 1
echo Filament built at %OUT%
