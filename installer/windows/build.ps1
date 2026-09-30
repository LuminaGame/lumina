<#
.SYNOPSIS
  Builds the Lumina Studio setup.exe with Inno Setup 6.

.EXAMPLE
  ./installer/windows/build.ps1 -Version 0.1.0 -Tag v0.1.0 -OutDir dist
  # dist/lumina-studio-setup-v0.1.0-windows-x64.exe and its .sha256

.EXAMPLE
  ./installer/windows/build.ps1 -Version 0.1.0 -Tag v0.1.0 -OutDir dist `
    -SignToolCommand '$q<path to signtool.exe>$q sign /fd sha256 /tr http://time.certum.pl /td sha256 /sha1 <thumbprint> $f'
  # The same, with setup.exe and its uninstaller Authenticode-signed. The
  # command is an Inno Setup sign tool command: $f is the file to sign, $q a
  # double quote.

.NOTES
  Needs ISCC.exe (Inno Setup 6): `winget install JRSoftware.InnoSetup`, or
  -InstallInnoSetup to install it with Chocolatey (CI runners).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Version,
  [string]$Tag = "v$Version",
  [string]$OutDir = 'dist',
  [string]$Repository = 'LuminaGame/lumina',
  [switch]$InstallInnoSetup,
  [string]$SignToolCommand
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

function Find-Iscc {
  $candidates = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
    (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
  )
  foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { return $c } }
  $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

$iscc = Find-Iscc
if (-not $iscc -and $InstallInnoSetup) {
  choco install innosetup -y --no-progress | Out-Host
  $iscc = Find-Iscc
}
if (-not $iscc) { throw 'ISCC.exe (Inno Setup 6) not found: winget install JRSoftware.InnoSetup' }

# The file version is four numbers; a pre-release suffix is dropped.
if ($Version -notmatch '^(\d+)\.(\d+)\.(\d+)') { throw "Version '$Version' is not x.y.z[-pre]" }
$numeric = "$($Matches[1]).$($Matches[2]).$($Matches[3]).0"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$out = (Resolve-Path $OutDir).Path
$isccArgs = @("/DAppVersion=$Version", "/DAppTag=$Tag", "/DNumericVersion=$numeric", "/DRepository=$Repository", "/O$out")
if ($SignToolCommand) {
  # Not quiet: the log then shows the sign tool running for the uninstaller
  # and for setup.exe.
  $isccArgs += @("/Slumina=$SignToolCommand", '/DSignToolName=lumina')
} else {
  $isccArgs += '/Q'
}
& $iscc @isccArgs (Join-Path $here 'lumina-studio.iss') | Out-Host
if ($LASTEXITCODE -ne 0) { throw "ISCC failed (exit $LASTEXITCODE)" }

$name = "lumina-studio-setup-$Tag-windows-x64.exe"
$exe = Join-Path $out $name
if (-not (Test-Path $exe)) { throw "ISCC did not produce $exe" }
$hash = (Get-FileHash -Algorithm SHA256 $exe).Hash.ToLowerInvariant()
[IO.File]::WriteAllText("$exe.sha256", "$hash  $name`n", (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Built $exe"
Write-Host "  sha256: $hash"
