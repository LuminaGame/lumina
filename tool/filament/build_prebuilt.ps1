<#
.SYNOPSIS
Builds Lumina's prebuilt Filament for Windows x64: upstream google/filament at
the tag tool/filament/VERSION names, plus third_party/filament/patches, built
with MSVC (/MT) through flutter_filament/tool/build_filament_windows.bat, then
pruned to what the native-assets hooks read and zipped.

.DESCRIPTION
  tool\filament\build_prebuilt.ps1 [-WorkDir <dir>] [-OutDir <dir>] [-SkipBuild]

WorkDir  the Filament checkout + build tree (default: $env:LUMINA_FILAMENT_WORK,
         else build\filament-src under the repo root). Reused across runs: the
         clone, the patch state and the ninja tree are all incremental.
OutDir   where the archive goes (default: build\filament-prebuilt).
SkipBuild  package an existing build only.

Writes <OutDir>\filament-<VERSION>-windows-x64.zip and a .sha256 sidecar
(sha256sum format). The zip holds one folder, filament-<VERSION>-windows-x64,
that works as the hooks' filament_dir.
Needs Visual Studio 2022 with the C++ workload (cl, CMake, Ninja), Python 3
and git. Keep WorkDir short: MSVC object paths approach MAX_PATH.
#>
[CmdletBinding()]
param(
  [string]$WorkDir,
  [string]$OutDir,
  [switch]$SkipBuild
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Version = ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'VERSION'))).Trim()
$UpstreamTag = 'v' + ($Version -split '-')[0]
$UpstreamUrl = if ($env:LUMINA_FILAMENT_UPSTREAM) { $env:LUMINA_FILAMENT_UPSTREAM } else { 'https://github.com/google/filament.git' }
$Os = 'windows'
$BuildOut = 'out/cmake-release-windows'
if (-not $WorkDir) { $WorkDir = if ($env:LUMINA_FILAMENT_WORK) { $env:LUMINA_FILAMENT_WORK } else { Join-Path $Repo 'build\filament-src' } }
if (-not $OutDir) { $OutDir = Join-Path $Repo 'build\filament-prebuilt' }
$WorkDir = [IO.Path]::GetFullPath($WorkDir)
$OutDir = [IO.Path]::GetFullPath($OutDir)
$PatchDir = Join-Path $Repo 'third_party\filament\patches'
$Patches = @(Get-ChildItem $PatchDir -Filter '*.patch' | Sort-Object Name)
$Utf8 = New-Object Text.UTF8Encoding $false

function Invoke-Native([string]$exe, [string[]]$argv) {
  & $exe @argv
  if ($LASTEXITCODE -ne 0) { throw "$exe $($argv -join ' ') failed ($LASTEXITCODE)" }
}
function Log([string]$msg) { Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] $msg" }

# --- 1. upstream checkout at the tag, with the patches applied -------------
$git = @('-c', 'core.autocrlf=false', '-c', 'core.longpaths=true', '-c', 'advice.detachedHead=false')
if (-not (Test-Path (Join-Path $WorkDir '.git'))) {
  Log "cloning $UpstreamUrl $UpstreamTag -> $WorkDir"
  New-Item -ItemType Directory -Force (Split-Path $WorkDir) | Out-Null
  Invoke-Native git ($git + @('clone', '--depth', '1', '--branch', $UpstreamTag,
    '--config', 'core.autocrlf=false', '--config', 'core.longpaths=true', $UpstreamUrl, $WorkDir))
}
# Windows PowerShell turns a native command's redirected stderr into an error
# under 'Stop'; describe fails (on purpose) off the tag.
$ErrorActionPreference = 'Continue'
$head = (& git -C $WorkDir describe --tags --exact-match HEAD 2>$null)
$ErrorActionPreference = 'Stop'
if ($head -ne $UpstreamTag) {
  Log "checkout is at '$head', fetching $UpstreamTag"
  Invoke-Native git ($git + @('-C', $WorkDir, 'fetch', '--depth', '1', 'origin', 'tag', $UpstreamTag))
  Invoke-Native git ($git + @('-C', $WorkDir, 'checkout', '-f', $UpstreamTag))
}
$UpstreamCommit = (& git -C $WorkDir rev-parse HEAD).Trim()
$patchInfo = @(foreach ($p in $Patches) {
  [ordered]@{ name = $p.Name; sha256 = (Get-FileHash $p.FullName -Algorithm SHA256).Hash.ToLower() }
})
$stamp = ($patchInfo | ForEach-Object { "$($_.name) $($_.sha256)" }) -join "`n"
$stampFile = Join-Path $WorkDir '.lumina-patches'
$applied = if (Test-Path $stampFile) { [IO.File]::ReadAllText($stampFile) } else { $null }
if ($applied -ne $stamp) {
  Log "applying $($Patches.Count) patches"
  # Back to the pristine tag (tracked files only: out\ survives).
  Invoke-Native git ($git + @('-C', $WorkDir, 'reset', '-q', '--hard', 'HEAD'))
  $paths = @($Patches | ForEach-Object { $_.FullName })
  Invoke-Native git ($git + @('-C', $WorkDir, 'apply', '--check') + $paths)
  Invoke-Native git ($git + @('-C', $WorkDir, 'apply') + $paths)
  [IO.File]::WriteAllText($stampFile, $stamp, $Utf8)
} else {
  Log 'patches already applied'
}

# --- 2. the manifest: what the hooks read ----------------------------------
$Entries = @(foreach ($line in [IO.File]::ReadAllLines((Join-Path $PSScriptRoot 'prebuilt_manifest.txt'))) {
  if (-not $line.Trim() -or $line.StartsWith('#')) { continue }
  $f = $line.Trim() -split '\s+'
  if ($f[0] -ne 'all' -and -not (($f[0] -split ',') -contains $Os)) { continue }
  [pscustomobject]@{ Kind = $f[1]; Path = $f[2]; From = $(if ($f.Count -gt 3) { $f[3] } else { $null }) }
})
$outPrefix = "$BuildOut/"
$Targets = @(foreach ($e in $Entries) {
  $built = if ($e.Kind -eq 'tool') { $e.From } elseif ($e.Kind -eq 'file') { $e.Path } else { $null }
  if ($built -and $built.StartsWith($outPrefix)) { $built.Substring($outPrefix.Length) }
})

# --- 3. build: only the libraries and tools the archive carries ------------
$started = Get-Date
if (-not $SkipBuild) {
  Log "building $($Targets.Count) targets in $WorkDir\$BuildOut"
  $env:LUMINA_FILAMENT_SRC = $WorkDir
  $bat = Join-Path $Repo 'flutter_filament\tool\build_filament_windows.bat'
  & cmd.exe /d /c "`"$bat`" $($Targets -join ' ')"
  $rc = $LASTEXITCODE
  Remove-Item Env:LUMINA_FILAMENT_SRC
  if ($rc -ne 0) { throw "Filament build failed ($rc)" }
  Log ("build finished in {0:N1} min" -f ((Get-Date) - $started).TotalMinutes)
}

# --- 4. stage the pruned tree ----------------------------------------------
$Name = "filament-$Version-$Os-x64"
$Stage = Join-Path $OutDir "stage\$Name"
if (Test-Path (Join-Path $OutDir 'stage')) { Remove-Item -Recurse -Force (Join-Path $OutDir 'stage') }
New-Item -ItemType Directory -Force $Stage | Out-Null
$HeaderExt = @('.h', '.hh', '.hpp', '.hxx', '.inl', '.inc', '.ipp', '.tcc', '.def')
function Copy-One([string]$from, [string]$to) {
  New-Item -ItemType Directory -Force (Split-Path $to) | Out-Null
  Copy-Item -LiteralPath $from -Destination $to -Force
}
$copied = 0
foreach ($e in $Entries) {
  $src = Join-Path $WorkDir ($e.Path -replace '/', '\')
  $dst = Join-Path $Stage ($e.Path -replace '/', '\')
  switch ($e.Kind) {
    'file' {
      if (-not (Test-Path -LiteralPath $src -PathType Leaf)) { throw "missing: $($e.Path)" }
      Copy-One $src $dst; $copied++
    }
    'tool' {
      $from = Join-Path $WorkDir ($e.From -replace '/', '\')
      if (-not (Test-Path -LiteralPath $from -PathType Leaf)) { throw "missing: $($e.From)" }
      Copy-One $from $dst; $copied++
    }
    'dir' {
      if (-not (Test-Path -LiteralPath $src -PathType Container)) { throw "missing: $($e.Path)" }
      New-Item -ItemType Directory -Force $dst | Out-Null
      foreach ($h in Get-ChildItem -LiteralPath $src -Recurse -File) {
        if ($HeaderExt -notcontains $h.Extension.ToLower()) { continue }
        Copy-One $h.FullName (Join-Path $dst $h.FullName.Substring($src.Length).TrimStart('\')); $copied++
      }
    }
  }
}
New-Item -ItemType Directory -Force (Join-Path $Stage 'lumina\patches') | Out-Null
foreach ($p in $Patches) { Copy-Item $p.FullName (Join-Path $Stage "lumina\patches\$($p.Name)") }

# Provenance: what this archive is and how it was built.
$batText = [IO.File]::ReadAllText((Join-Path $Repo 'flutter_filament\tool\build_filament_windows.bat'))
$cmakeFlags = @('-G', 'Ninja') + @([regex]::Matches($batText, '-D[A-Za-z0-9_]+=[^\s^]+') | ForEach-Object { $_.Value })
$cache = [IO.File]::ReadAllText((Join-Path $WorkDir "$BuildOut\CMakeCache.txt"))
$compiler = if ($cache -match 'CMAKE_CXX_COMPILER:[A-Z]+=(.+)') { $Matches[1].Trim() } else { 'unknown' }
$meta = [ordered]@{
  version = $Version
  platform = "$Os-x64"
  upstream = [ordered]@{ repository = 'https://github.com/google/filament'; tag = $UpstreamTag; commit = $UpstreamCommit }
  patches = $patchInfo
  build = [ordered]@{
    directory = $BuildOut
    cmake = $cmakeFlags
    compiler = $compiler
    crt = '/MT (static)'
  }
}
[IO.File]::WriteAllText((Join-Path $Stage 'lumina-filament.json'), ($meta | ConvertTo-Json -Depth 6) + "`n", $Utf8)

# --- 5. archive + checksum -------------------------------------------------
$Archive = Join-Path $OutDir "$Name.zip"
if (Test-Path $Archive) { Remove-Item -Force $Archive }
Log "packing $copied files -> $Archive"
# bsdtar (Windows 10+) writes '/'-separated zip entries; Compress-Archive in
# Windows PowerShell 5.1 does not.
Push-Location (Join-Path $OutDir 'stage')
try { Invoke-Native "$env:SystemRoot\System32\tar.exe" @('-a', '-c', '-f', $Archive, $Name) } finally { Pop-Location }
$hash = (Get-FileHash $Archive -Algorithm SHA256).Hash.ToLower()
[IO.File]::WriteAllText("$Archive.sha256", "$hash  $Name.zip`n", $Utf8)
Remove-Item -Recurse -Force (Join-Path $OutDir 'stage')
$size = (Get-Item $Archive).Length / 1MB
Log ("{0} ({1:N1} MiB) sha256 {2}" -f $Archive, $size, $hash)
