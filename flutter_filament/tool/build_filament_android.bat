@echo off
rem Builds the vendored Filament (../../filament) for Android (arm64-v8a, x86_64) into
rem filament\out\android-release\filament, the static libraries hook/build.dart
rem links on Android.
setlocal enabledelayedexpansion

set "FILAMENT=%~dp0..\..\filament"
if defined LUMINA_FILAMENT_SRC set "FILAMENT=%LUMINA_FILAMENT_SRC%"

if not defined ANDROID_HOME (
  if exist "%LOCALAPPDATA%\Android\Sdk" set "ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk"
)
if not defined ANDROID_HOME (
  echo Error: ANDROID_HOME is not set and could not be found at %LOCALAPPDATA%\Android\Sdk
  exit /b 1
)

for /d %%d in ("%ANDROID_HOME%\ndk\28*") do set "NDK_DIR=%%d"
if not defined NDK_DIR (
  for /d %%d in ("%ANDROID_HOME%\ndk\*") do set "NDK_DIR=%%d"
)
if not defined NDK_DIR (
  echo Error: No Android NDK found under %ANDROID_HOME%\ndk
  exit /b 1
)

for %%i in ("%NDK_DIR%") do set "NDK_VER=%%~nxi"
echo Using Android NDK: %NDK_VER% at %NDK_DIR%

if not defined VCINSTALLDIR (
  for /f "usebackq delims=" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSDIR=%%i"
)
if defined VSDIR (
  set "PATH=%VSDIR%\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;%VSDIR%\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja;%PATH%"
)
if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" set "PATH=%LOCALAPPDATA%\Programs\Python\Python312;%PATH%"

set "ABIS=aarch64 x86_64"
if not "%~1"=="" set "ABIS=%~1"

for %%a in (%ABIS%) do (
  set "ARCH=%%a"
  set "TOOLCHAIN=%FILAMENT%\build\toolchain-%%a-linux-android.cmake"
  set "OUT_DIR=%FILAMENT%\out\cmake-android-release-%%a"
  echo --- Configuring %%a ---
  cmake -S "%FILAMENT%" -B "!OUT_DIR!" -G Ninja ^
    -DIMPORT_EXECUTABLES_DIR=. ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DFILAMENT_NDK_VERSION=28 ^
    -DANDROID_NDK="%NDK_DIR:\=/%" ^
    -DCMAKE_INSTALL_PREFIX="%FILAMENT:\=/%/out/android-release/filament" ^
    -DCMAKE_TOOLCHAIN_FILE="!TOOLCHAIN:\=/!" ^
    -DFILAMENT_BUILD_TESTING=OFF ^
    -DFILAMENT_ENABLE_MATDBG=OFF ^
    -DFILAMENT_SUPPORTS_VULKAN=ON ^
    -DFILAMENT_ENABLE_EXCEPTIONS=ON ^
    -DFILAMENT_SUPPORTS_WEBP_TEXTURES=ON || exit /b 1
  echo --- Building and Installing %%a ---
  ninja -C "!OUT_DIR!" install || exit /b 1
)

echo Filament Android build complete at %FILAMENT%\out\android-release\filament
