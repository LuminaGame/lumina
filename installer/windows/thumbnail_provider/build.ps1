<#
.SYNOPSIS
  Builds the Lumina Studio shell thumbnail provider (lumina_thumbnails.dll)
  and its check tool (thumbnail_check.exe) with the Visual Studio 2022 C++
  toolset.

.EXAMPLE
  ./installer/windows/thumbnail_provider/build.ps1 -OutDir build\thumbnail_provider
  # build\thumbnail_provider\lumina_thumbnails.dll and thumbnail_check.exe

.NOTES
  Finds Visual Studio (or the Build Tools) with the C++ workload through
  vswhere and compiles x64 with the static runtime (/MT), so the DLL needs no
  Visual C++ redistributable inside Explorer's surrogate process. Prints the
  DLL path as its last line.
#>
[CmdletBinding()]
param(
  [string]$OutDir = (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'build')
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path $vswhere)) { throw 'vswhere.exe not found: install Visual Studio 2022 or its Build Tools with the C++ workload' }
$vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs) { throw 'No Visual Studio with the C++ x64 tools (Microsoft.VisualStudio.Component.VC.Tools.x86.x64)' }
$vcvars = Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'
if (-not (Test-Path $vcvars)) { throw "vcvars64.bat not found under $vs" }

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$out = (Resolve-Path $OutDir).Path
$obj = Join-Path $out 'obj'
New-Item -ItemType Directory -Force -Path $obj | Out-Null

$common = '/nologo /O2 /MT /EHsc /W4 /WX /permissive- /std:c++17 /DUNICODE /D_UNICODE /DWIN32_LEAN_AND_MEAN /DNOMINMAX'
$dll = "cl $common /LD /Fo`"$obj\\`" /Fe`"$out\lumina_thumbnails.dll`" `"$here\lumina_thumbnail_provider.cpp`" " +
  "/link /DEF:`"$here\lumina_thumbnail_provider.def`" ole32.lib windowscodecs.lib shell32.lib advapi32.lib user32.lib gdi32.lib"
$check = "cl $common /Fo`"$obj\\`" /Fe`"$out\thumbnail_check.exe`" `"$here\thumbnail_check.cpp`" " +
  "/link ole32.lib windowscodecs.lib shell32.lib shlwapi.lib gdi32.lib user32.lib"
# A batch file: Windows PowerShell mangles nested quotes on a cmd /c line.
$script = Join-Path $obj 'build.cmd'
$lines = @('@echo off', "set `"PATH=$(Split-Path -Parent $vswhere);%PATH%`"", "call `"$vcvars`" >nul || exit /b 1", "$dll || exit /b 1", "$check || exit /b 1")
[IO.File]::WriteAllLines($script, $lines, (New-Object System.Text.UTF8Encoding($false)))
& cmd.exe /d /c $script | Out-Host
if ($LASTEXITCODE -ne 0) { throw "The thumbnail provider did not build (exit $LASTEXITCODE)" }
foreach ($f in 'lumina_thumbnails.dll', 'thumbnail_check.exe') {
  if (-not (Test-Path (Join-Path $out $f))) { throw "cl did not produce $f" }
}
Remove-Item -Recurse -Force $obj -ErrorAction SilentlyContinue
Get-ChildItem $out -Include '*.lib', '*.exp' -File -Recurse | Remove-Item -Force
Join-Path $out 'lumina_thumbnails.dll'
