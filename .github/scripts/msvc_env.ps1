<#
.SYNOPSIS
  Puts the Visual Studio 2022 x64 developer environment (cl, link, the
  Windows SDK, CMake, Ninja) into the following workflow steps.

.DESCRIPTION
  Replaces ilammy/msvc-dev-cmd, which still runs on Node.js 20. Finds
  VS 2022 (17.x) with the x64 C++ tools through vswhere, runs its
  vcvars64.bat, and writes every variable the batch file added or changed to
  $GITHUB_ENV. Outside Actions (no GITHUB_ENV) it applies them to the
  current PowerShell session instead, so it can be checked locally.

  No -vcvars_ver: the default MSVC of the image's VS 2022 (14.4x), as
  ilammy/msvc-dev-cmd with `arch: x64` chose.
#>
$ErrorActionPreference = 'Stop'

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path $vswhere)) { throw "vswhere not found at $vswhere" }
$vs = & $vswhere -products * -version '[17.0,18.0)' -latest `
  -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
  -property installationPath
if (-not $vs) { throw 'No Visual Studio 2022 with the x64 C++ tools (Microsoft.VisualStudio.Component.VC.Tools.x86.x64).' }
$vcvars = Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'
if (-not (Test-Path $vcvars)) { throw "$vcvars not found" }
Write-Host "Visual Studio: $vs"

# A batch file avoids PowerShell's quoting of cmd.exe arguments.
$tmp = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }
$bat = Join-Path $tmp 'lumina-vcvars64.cmd'
[IO.File]::WriteAllText($bat, "@call `"$vcvars`" >nul`r`n@if errorlevel 1 exit /b 1`r`n@set`r`n")
$lines = & cmd.exe /d /c $bat
if ($LASTEXITCODE -ne 0) { throw "vcvars64.bat failed ($LASTEXITCODE)" }
Remove-Item $bat

$changed = [ordered]@{}
foreach ($line in $lines) {
  $i = $line.IndexOf('=')
  if ($i -le 0) { continue }
  $name = $line.Substring(0, $i)
  $value = $line.Substring($i + 1)
  if ([Environment]::GetEnvironmentVariable($name) -ne $value) { $changed[$name] = $value }
}
if (-not $changed['VCToolsVersion']) { throw 'vcvars64.bat set no VCToolsVersion.' }

foreach ($name in $changed.Keys) {
  $value = $changed[$name]
  if ($env:GITHUB_ENV) {
    # Heredoc form, so no value can break the file's format.
    $delim = "EOF_$([guid]::NewGuid().ToString('N'))"
    [IO.File]::AppendAllText($env:GITHUB_ENV, "$name<<$delim`n$value`n$delim`n")
  }
  [Environment]::SetEnvironmentVariable($name, $value)
}

$cl = (Get-Command cl.exe).Source
Write-Host "MSVC $($changed['VCToolsVersion']) ($($changed.Count) variables): $cl"
