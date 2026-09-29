<#
.SYNOPSIS
  Installs what Lumina Studio needs on Windows, then downloads the latest
  Lumina Studio release. setup.exe (lumina-studio.iss) runs it; it also runs
  on its own.

.DESCRIPTION
  1. Prerequisites through winget: Git, the Visual Studio 2022 Build Tools
     with the C++ desktop workload, GStreamer and (with -WithFfmpeg) FFmpeg.
     Anything already present is left alone.
  2. Flutter: an existing `flutter` on PATH is used as is; otherwise the
     stable channel is cloned to %LOCALAPPDATA%\Lumina\flutter and its bin
     folder added to the user PATH.
  3. Lumina Studio: the Windows zip of the latest GitHub release (or -Tag)
     is downloaded, checked against its .sha256 sidecar and unpacked into
     -InstallDir.

  -DryRun lists what would be installed and downloaded and changes nothing.

  Exit codes: 0 done, 10 a prerequisite failed, 20 Flutter failed,
  30 Lumina Studio could not be downloaded, 1 anything else.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File lumina-setup.ps1 -DryRun
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File lumina-setup.ps1 -StudioOnly
#>
[CmdletBinding()]
param(
  [switch]$DryRun,
  [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Programs\Lumina Studio'),
  [string]$FlutterDir = (Join-Path $env:LOCALAPPDATA 'Lumina\flutter'),
  [string]$FlutterBranch = 'stable',
  [switch]$WithFfmpeg,
  [switch]$SkipPrerequisites,
  [switch]$SkipFlutter,
  # Only (re)download Lumina Studio: the "Update Lumina Studio" shortcut.
  [switch]$StudioOnly,
  [switch]$Uninstall,
  [switch]$RemoveFlutter,
  [string]$Repository = 'LuminaGame/lumina',
  [string]$Tag = 'latest',
  [string]$LogPath
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$StateDir = Join-Path $env:LOCALAPPDATA 'Lumina'
$StateFile = Join-Path $StateDir 'install-state.json'
$Utf8 = New-Object System.Text.UTF8Encoding($false)
if ($StudioOnly) { $SkipPrerequisites = $true; $SkipFlutter = $true }

function Say([string]$Message) {
  Write-Host $Message
  if ($LogPath) {
    $dir = Split-Path -Parent $LogPath
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [IO.File]::AppendAllText($LogPath, $Message + "`r`n", $Utf8)
  }
}

function Read-State {
  if (Test-Path $StateFile) {
    try { return Get-Content -Raw -Encoding UTF8 $StateFile | ConvertFrom-Json } catch { }
  }
  return New-Object PSObject -Property @{ flutterInstalledByLumina = $false; flutterPathAdded = $false; flutterDir = '' }
}

function Write-State($State) {
  if (-not (Test-Path $StateDir)) { New-Item -ItemType Directory -Force -Path $StateDir | Out-Null }
  [IO.File]::WriteAllText($StateFile, ($State | ConvertTo-Json), $Utf8)
}

function Update-SessionPath {
  $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
  $user = [Environment]::GetEnvironmentVariable('Path', 'User')
  $env:Path = (@($machine, $user) | Where-Object { $_ }) -join ';'
}

# ------------------------------------------------------------ prerequisites

function Find-VsWhere {
  $p = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
  if (Test-Path $p) { return $p }
  return $null
}

function Test-Git {
  if (Get-Command git.exe -ErrorAction SilentlyContinue) { return $true }
  return (Test-Path (Join-Path $env:ProgramFiles 'Git\cmd\git.exe'))
}

function Test-CppBuildTools {
  $vswhere = Find-VsWhere
  if (-not $vswhere) { return $false }
  $path = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
  return [bool]$path
}

function Test-GStreamer {
  foreach ($scope in 'Machine', 'User') {
    $root = [Environment]::GetEnvironmentVariable('GSTREAMER_1_0_ROOT_MSVC_X86_64', $scope)
    if ($root -and (Test-Path (Join-Path $root 'bin\gst-launch-1.0.exe'))) { return $true }
  }
  foreach ($root in @((Join-Path $env:ProgramFiles 'gstreamer\1.0\msvc_x86_64'), (Join-Path $env:LOCALAPPDATA 'Programs\gstreamer\1.0\msvc_x86_64'), 'C:\gstreamer\1.0\msvc_x86_64')) {
    if (Test-Path (Join-Path $root 'bin\gst-launch-1.0.exe')) { return $true }
  }
  return $false
}

function Test-Ffmpeg {
  return [bool](Get-Command ffmpeg.exe -ErrorAction SilentlyContinue)
}

$Prerequisites = @(
  @{ Name = 'Git'; Id = 'Git.Git'; Test = { Test-Git }; Override = $null },
  @{ Name = 'Visual Studio 2022 Build Tools (C++ desktop workload)'; Id = 'Microsoft.VisualStudio.2022.BuildTools'; Test = { Test-CppBuildTools };
     Override = '--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended' },
  @{ Name = 'GStreamer'; Id = 'gstreamerproject.gstreamer'; Test = { Test-GStreamer }; Override = $null }
)
if ($WithFfmpeg) {
  $Prerequisites += @{ Name = 'FFmpeg'; Id = 'Gyan.FFmpeg.Essentials'; Test = { Test-Ffmpeg }; Override = $null }
}

# winget results that mean "nothing to do".
$WingetOk = @(0, -1978335189, -1978335135, 3010)

function Install-Prerequisites {
  Say '== Prerequisites (winget)'
  $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
  $failed = @()
  foreach ($p in $Prerequisites) {
    $cmd = "winget install --id $($p.Id) -e --silent --accept-source-agreements --accept-package-agreements"
    if ($p.Override) { $cmd += " --override `"$($p.Override)`"" }
    $present = & $p.Test
    if ($present) {
      Say ("  [present]  {0}" -f $p.Name)
      if ($DryRun) { Say ("             (when missing: {0})" -f $cmd) }
      continue
    }
    if ($DryRun) {
      Say ("  [install]  {0}" -f $p.Name)
      Say ("             {0}" -f $cmd)
      continue
    }
    if (-not $winget) {
      Say ("  [missing]  {0}: winget is not available. Install 'App Installer' from the Microsoft Store, or install {1} by hand." -f $p.Name, $p.Id)
      $failed += $p.Name
      continue
    }
    Say ("  [install]  {0} ..." -f $p.Name)
    $wingetArgs = @('install', '--id', $p.Id, '-e', '--silent', '--accept-source-agreements', '--accept-package-agreements')
    if ($p.Override) { $wingetArgs += @('--override', $p.Override) }
    & $winget.Source @wingetArgs | Out-Host
    $code = $LASTEXITCODE
    if ($WingetOk -contains $code) {
      Say ("  [done]     {0}" -f $p.Name)
    } else {
      Say ("  [failed]   {0}: winget exited with {1}" -f $p.Name, $code)
      $failed += $p.Name
    }
  }
  if (-not $DryRun) { Update-SessionPath }
  return $failed
}

# ------------------------------------------------------------ Flutter

function Find-Git {
  $g = Get-Command git.exe -ErrorAction SilentlyContinue
  if ($g) { return $g.Source }
  $p = Join-Path $env:ProgramFiles 'Git\cmd\git.exe'
  if (Test-Path $p) { return $p }
  return $null
}

function Add-UserPath([string]$Dir) {
  $user = [Environment]::GetEnvironmentVariable('Path', 'User')
  $parts = @($user -split ';' | Where-Object { $_ })
  if ($parts | Where-Object { $_.TrimEnd('\') -ieq $Dir.TrimEnd('\') }) { return $false }
  [Environment]::SetEnvironmentVariable('Path', (($parts + $Dir) -join ';'), 'User')
  return $true
}

function Remove-UserPath([string]$Dir) {
  $user = [Environment]::GetEnvironmentVariable('Path', 'User')
  if (-not $user) { return }
  $parts = @($user -split ';' | Where-Object { $_ -and ($_.TrimEnd('\') -ine $Dir.TrimEnd('\')) })
  [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')
}

function Install-Flutter {
  Say '== Flutter SDK'
  $own = Join-Path $FlutterDir 'bin\flutter.bat'
  if (Test-Path $own) {
    Say ("  [present]  {0}" -f $FlutterDir)
    return $true
  }
  $existing = Get-Command flutter.bat -ErrorAction SilentlyContinue
  if (-not $existing) { $existing = Get-Command flutter -ErrorAction SilentlyContinue }
  if ($existing) {
    Say ("  [present]  flutter on PATH: {0}" -f $existing.Source)
    return $true
  }
  $clone = "git clone --filter=blob:none --branch $FlutterBranch https://github.com/flutter/flutter.git `"$FlutterDir`""
  if ($DryRun) {
    Say ("  [install]  Flutter ({0} channel) into {1}" -f $FlutterBranch, $FlutterDir)
    Say ("             {0}" -f $clone)
    Say ("             then add {0} to the user PATH" -f (Join-Path $FlutterDir 'bin'))
    return $true
  }
  $git = Find-Git
  if (-not $git) {
    Say '  [failed]   Git is not installed, so Flutter cannot be cloned.'
    return $false
  }
  $parent = Split-Path -Parent $FlutterDir
  if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  Say ("  [install]  {0}" -f $clone)
  & $git clone --filter=blob:none --branch $FlutterBranch https://github.com/flutter/flutter.git $FlutterDir | Out-Host
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $own)) {
    Say ("  [failed]   git clone exited with {0}" -f $LASTEXITCODE)
    if (Test-Path $FlutterDir) { Remove-Item -Recurse -Force $FlutterDir -ErrorAction SilentlyContinue }
    return $false
  }
  $state = Read-State
  $state.flutterInstalledByLumina = $true
  $state.flutterDir = $FlutterDir
  $state.flutterPathAdded = Add-UserPath (Join-Path $FlutterDir 'bin')
  Write-State $state
  $env:Path = (Join-Path $FlutterDir 'bin') + ';' + $env:Path
  Say '  [setup]    flutter --version (downloads the Dart SDK once)'
  & $own --version | Out-Host
  if ($LASTEXITCODE -ne 0) {
    Say ("  [warning]  flutter --version exited with {0}; run it once by hand." -f $LASTEXITCODE)
  }
  Say ("  [done]     Flutter in {0} (on the user PATH for new terminals)" -f $FlutterDir)
  return $true
}

# ------------------------------------------------------------ Lumina Studio

function Invoke-GitHubApi([string]$Url) {
  $headers = @{ 'Accept' = 'application/vnd.github+json'; 'User-Agent' = 'lumina-studio-setup'; 'X-GitHub-Api-Version' = '2022-11-28' }
  if ($env:GITHUB_TOKEN) { $headers['Authorization'] = "Bearer $($env:GITHUB_TOKEN)" }
  return Invoke-RestMethod -Uri $Url -Headers $headers -UseBasicParsing -TimeoutSec 60
}

function Get-StudioRelease {
  $url = if ($Tag -eq 'latest') { "https://api.github.com/repos/$Repository/releases/latest" } else { "https://api.github.com/repos/$Repository/releases/tags/$Tag" }
  $release = Invoke-GitHubApi $url
  $zip = $release.assets | Where-Object { $_.name -match '^lumina-studio-.+-windows-x64\.zip$' } | Select-Object -First 1
  if (-not $zip) { throw "Release $($release.tag_name) has no lumina-studio-*-windows-x64.zip asset." }
  $sum = $release.assets | Where-Object { $_.name -eq "$($zip.name).sha256" } | Select-Object -First 1
  return New-Object PSObject -Property @{ Url = $url; Tag = $release.tag_name; Zip = $zip; Sha256 = $sum }
}

function Invoke-Download([string]$Url, [string]$OutFile) {
  $last = $null
  for ($i = 1; $i -le 3; $i++) {
    try {
      Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -Headers @{ 'User-Agent' = 'lumina-studio-setup' } -TimeoutSec 600
      return
    } catch {
      $last = $_
      Start-Sleep -Seconds (5 * $i)
    }
  }
  throw $last
}

function Install-Studio {
  Say '== Lumina Studio'
  $apiUrl = if ($Tag -eq 'latest') { "https://api.github.com/repos/$Repository/releases/latest" } else { "https://api.github.com/repos/$Repository/releases/tags/$Tag" }
  try {
    $rel = Get-StudioRelease
  } catch {
    Say ("  [error]    Could not read the release from {0}: {1}" -f $apiUrl, $_.Exception.Message)
    if ($DryRun) {
      Say ("  [download] would download lumina-studio-<tag>-windows-x64.zip from the {0} release of {1}" -f $Tag, $Repository)
      Say ("             and unpack it into {0}" -f $InstallDir)
      return 0
    }
    Say '             Check the internet connection, then run "Update Lumina Studio" from the Start menu.'
    return 30
  }
  $mb = [Math]::Round($rel.Zip.size / 1MB, 1)
  if ($DryRun) {
    Say ("  [download] {0} ({1} MB, release {2})" -f $rel.Zip.name, $mb, $rel.Tag)
    Say ("             {0}" -f $rel.Zip.browser_download_url)
    if ($rel.Sha256) { Say ("             checked against {0}" -f $rel.Sha256.name) }
    Say ("             unpacked into {0}" -f $InstallDir)
    return 0
  }

  $running = Get-Process lumina_ui -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($InstallDir, [StringComparison]::OrdinalIgnoreCase) }
  if ($running) {
    Say '  [error]    Lumina Studio is running; close it and try again.'
    return 30
  }

  $work = Join-Path $env:TEMP ('lumina-studio-' + [Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $work | Out-Null
  try {
    $zipPath = Join-Path $work $rel.Zip.name
    Say ("  [download] {0} ({1} MB, release {2})" -f $rel.Zip.name, $mb, $rel.Tag)
    try {
      Invoke-Download $rel.Zip.browser_download_url $zipPath
    } catch {
      Say ("  [error]    Download failed: {0}" -f $_.Exception.Message)
      return 30
    }
    $hash = (Get-FileHash -Algorithm SHA256 $zipPath).Hash.ToLowerInvariant()
    if ($rel.Sha256) {
      $sumPath = Join-Path $work $rel.Sha256.name
      try { Invoke-Download $rel.Sha256.browser_download_url $sumPath } catch { Say ("  [error]    Checksum download failed: {0}" -f $_.Exception.Message); return 30 }
      $expected = ((Get-Content -Raw $sumPath) -split '\s+')[0].ToLowerInvariant()
      if ($expected -ne $hash) {
        Say ("  [error]    SHA-256 mismatch: expected {0}, got {1}" -f $expected, $hash)
        return 30
      }
      Say '  [verified] SHA-256 matches'
    } else {
      Say '  [warning]  The release has no .sha256 sidecar; not verified.'
    }

    $staging = Join-Path $work 'studio'
    Expand-Archive -Path $zipPath -DestinationPath $staging -Force
    if (-not (Test-Path (Join-Path $staging 'lumina_ui.exe'))) {
      Say '  [error]    The archive has no lumina_ui.exe.'
      return 30
    }

    if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null }
    # Replace the previous download (its files are listed in the manifest),
    # never touching setup's own files next to it.
    $manifest = Join-Path $InstallDir 'studio-files.txt'
    if (Test-Path $manifest) {
      foreach ($rel0 in Get-Content -Encoding UTF8 $manifest) {
        if (-not $rel0) { continue }
        $old = Join-Path $InstallDir $rel0
        if (Test-Path -LiteralPath $old -PathType Leaf) { Remove-Item -LiteralPath $old -Force }
      }
      $dataDir = Join-Path $InstallDir 'data'
      if (Test-Path $dataDir) { Remove-Item -Recurse -Force $dataDir }
    }
    $files = Get-ChildItem -Recurse -File $staging | ForEach-Object { $_.FullName.Substring($staging.Length + 1) }
    Copy-Item -Path (Join-Path $staging '*') -Destination $InstallDir -Recurse -Force
    [IO.File]::WriteAllLines($manifest, [string[]]$files, $Utf8)
    $info = New-Object PSObject -Property @{ tag = $rel.Tag; asset = $rel.Zip.name; sha256 = $hash; repository = $Repository; installed = (Get-Date).ToString('o') }
    [IO.File]::WriteAllText((Join-Path $InstallDir 'release.json'), ($info | ConvertTo-Json), $Utf8)
    Say ("  [done]     Lumina Studio {0} in {1}" -f $rel.Tag, $InstallDir)
    return 0
  } finally {
    Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
  }
}

# ------------------------------------------------------------ uninstall

function Invoke-Uninstall {
  $state = Read-State
  if ($RemoveFlutter -and $state.flutterInstalledByLumina -and $state.flutterDir) {
    Say ("Removing the Flutter SDK Lumina installed: {0}" -f $state.flutterDir)
    if (-not $DryRun) {
      if ($state.flutterPathAdded) { Remove-UserPath (Join-Path $state.flutterDir 'bin') }
      Remove-Item -Recurse -Force $state.flutterDir -ErrorAction SilentlyContinue
    }
    $state.flutterInstalledByLumina = $false
    $state.flutterPathAdded = $false
  }
  if (-not $DryRun) {
    if ($state.flutterInstalledByLumina) { Write-State $state }
    elseif (Test-Path $StateFile) { Remove-Item -Force $StateFile }
  }
  Say 'Git, the Build Tools, GStreamer and FFmpeg stay installed (other programs may use them); remove them from Settings > Apps.'
  return 0
}

# ------------------------------------------------------------ main

try {
  if ($LogPath -and (Test-Path $LogPath) -and $DryRun) { Remove-Item -Force $LogPath }
  if ($Uninstall) { exit (Invoke-Uninstall) }

  Say ("Lumina Studio setup{0}" -f $(if ($DryRun) { ' - dry run: nothing is installed or downloaded' } else { '' }))
  Say ("  install folder: {0}" -f $InstallDir)
  Say ("  release:        {0} of https://github.com/{1}" -f $Tag, $Repository)
  Say ''

  $code = 0
  if (-not $SkipPrerequisites) {
    $failed = @(Install-Prerequisites)
    if ($failed.Count -gt 0) {
      Say ("Prerequisites not installed: {0}" -f ($failed -join ', '))
      $code = 10
    }
    Say ''
  }
  if (-not $SkipFlutter) {
    if (-not (Install-Flutter)) { if ($code -eq 0) { $code = 20 } }
    Say ''
  }
  $studio = Install-Studio
  # A failed download wins: setup.exe offers to retry it.
  if ($studio -ne 0) { $code = $studio }
  Say ''
  Say $(if ($DryRun) { 'Dry run finished.' } elseif ($code -eq 0) { 'Lumina Studio is ready.' } else { "Finished with problems (exit $code)." })
  exit $code
} catch {
  Say ("Setup failed: {0}" -f $_.Exception.Message)
  exit 1
}
