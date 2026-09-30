<#
.SYNOPSIS
  End-to-end test of sign_windows_release.ps1 in its offline mode (-FromDir),
  with a throwaway self-signed code-signing certificate.

.DESCRIPTION
  Creates "CN=Lumina Test Signing" in Cert:\CurrentUser\My, runs the signing
  script over real release assets (the Windows zip, the setup and their
  .sha256 sidecars) and checks the result:
    - every executable and DLL that was unsigned in the zip is signed by the
      test certificate and carries a timestamp countersignature;
    - files already signed by someone else (the Visual C++ runtime) are
      byte-identical to the input;
    - the zip keeps the input's entries in the input's order;
    - setup.exe is rebuilt, signed and timestamped, with the input's version;
    - both sidecars match their files and keep the input sidecar's format;
    - a dry run writes nothing, a missing certificate is reported, and a
      second run gives the same result;
    - Inno Setup signed the uninstaller it embeds (from its compiler log).
  The test certificate is always removed again, by its thumbprint, from
  Cert:\CurrentUser\My and from the intermediate store (Cert:\CurrentUser\CA),
  where Windows keeps a copy of it after verifying. The
  timestamp server is called for real, so this needs network access.

.EXAMPLE
  gh release download v0.1.0 -R LuminaGame/lumina -p "lumina-studio-*windows-x64*" -D $env:TEMP\lumina-assets
  powershell -ExecutionPolicy Bypass -File tool\release\sign_windows_release_test.ps1 -FromDir $env:TEMP\lumina-assets -Tag v0.1.0

.EXAMPLE
  # A tag whose installer sources predate signed setup builds: build the
  # setup from the working tree instead.
  powershell -ExecutionPolicy Bypass -File tool\release\sign_windows_release_test.ps1 -FromDir <dir> -Tag v0.0.1-dev.5 -InstallerSourceRef worktree
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$FromDir,
  [Parameter(Mandatory = $true)][string]$Tag,
  [string]$InstallerSourceRef,
  [string]$TimestampUrl
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

$script = Join-Path $PSScriptRoot 'sign_windows_release.ps1'
$shell = (Get-Process -Id $PID).Path
$FromDir = (Resolve-Path $FromDir).Path
$zipName = "lumina-studio-$Tag-windows-x64.zip"
$setupName = "lumina-studio-setup-$Tag-windows-x64.exe"
$failures = New-Object System.Collections.Generic.List[string]

function Check([bool]$Condition, [string]$What) {
  if ($Condition) {
    Write-Host "  ok    $What"
  } else {
    Write-Host "  FAIL  $What" -ForegroundColor Red
    $failures.Add($What)
  }
}

# Runs the signing script in its own process; returns its exit code and output.
function Invoke-Signing([string[]]$Arguments) {
  $all = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script) + $Arguments
  $eap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $output = & $shell @all 2>&1 | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $eap
  }
  $text = ($output -join "`n")
  Write-Host ($text -replace '(?m)^', '    | ')
  return New-Object PSObject -Property @{ Code = $code; Output = $text }
}

function Expand-To([string]$Zip, [string]$Dir) {
  if (Test-Path $Dir) { Remove-Item -Recurse -Force $Dir }
  [IO.Compression.ZipFile]::ExtractToDirectory($Zip, $Dir)
}

function Get-EntryNames([string]$Zip) {
  $z = [IO.Compression.ZipFile]::OpenRead($Zip)
  try { return @($z.Entries | ForEach-Object { $_.FullName }) } finally { $z.Dispose() }
}

function Test-Sidecar([string]$File, [string]$InputSidecar) {
  $sidecar = "$File.sha256"
  if (-not (Test-Path $sidecar)) { return $false }
  $text = [IO.File]::ReadAllText($sidecar)
  $hash = (Get-FileHash -Algorithm SHA256 $File).Hash.ToLowerInvariant()
  $name = Split-Path -Leaf $File
  $separator = '  '
  if (Test-Path $InputSidecar) {
    $m = [regex]::Match([IO.File]::ReadAllText($InputSidecar), '^[0-9a-fA-F]{64}( \*|  )')
    if ($m.Success) { $separator = $m.Groups[1].Value }
  }
  return $text -ceq "$hash$separator$name`n"
}

function Test-SignedBy([string]$File, [string]$Thumbprint) {
  $s = Get-AuthenticodeSignature -FilePath $File
  return ($s.SignerCertificate -and $s.SignerCertificate.Thumbprint -eq $Thumbprint -and $s.TimeStamperCertificate)
}

foreach ($f in @($zipName, "$zipName.sha256", $setupName, "$setupName.sha256")) {
  if (-not (Test-Path (Join-Path $FromDir $f))) { throw "$FromDir has no $f" }
}

$root = Join-Path ([IO.Path]::GetTempPath()) ('lumina-sign-test-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $root | Out-Null
$cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=Lumina Test Signing' `
  -CertStoreLocation Cert:\CurrentUser\My -NotAfter (Get-Date).AddDays(2)
$thumb = $cert.Thumbprint
Write-Host "Test certificate: $($cert.Subject) $thumb"

try {
  $common = @('-Tag', $Tag, '-FromDir', $FromDir, '-AllowUntrustedForTest', '-WorkDir', (Join-Path $root 'work'))
  if ($InstallerSourceRef) { $common += @('-InstallerSourceRef', $InstallerSourceRef) }
  if ($TimestampUrl) { $common += @('-TimestampUrl', $TimestampUrl) }

  Write-Host "`n== A missing certificate is reported"
  $r = Invoke-Signing ($common + @('-Thumbprint', ('0' * 40), '-OutDir', (Join-Path $root 'missing')))
  Check ($r.Code -ne 0) 'exit code is not 0'
  Check ($r.Output -match 'Start SimplySign Desktop and log in') 'the message says to start SimplySign Desktop and log in'

  Write-Host "`n== Dry run"
  $dry = Join-Path $root 'dry'
  $r = Invoke-Signing ($common + @('-Thumbprint', $thumb, '-OutDir', $dry, '-DryRun'))
  Check ($r.Code -eq 0) 'exit code 0'
  Check ($r.Output -match 'lumina_ui\.exe') 'the plan lists lumina_ui.exe'
  Check (-not (Test-Path $dry) -or -not (Get-ChildItem $dry)) 'nothing written to -OutDir'

  $inputDir = Join-Path $root 'input-unpacked'
  Expand-To (Join-Path $FromDir $zipName) $inputDir
  $inputEntries = Get-EntryNames (Join-Path $FromDir $zipName)
  $pe = @(Get-ChildItem $inputDir -Recurse -File | Where-Object { $_.Extension -in '.exe', '.dll' })
  $unsigned = @($pe | Where-Object { (Get-AuthenticodeSignature $_.FullName).Status -eq 'NotSigned' })
  $signedByOthers = @($pe | Where-Object { (Get-AuthenticodeSignature $_.FullName).Status -eq 'Valid' })
  $inputVersion = (Get-Item (Join-Path $FromDir $setupName)).VersionInfo

  foreach ($run in 'first', 'second') {
    Write-Host "`n== Signing run ($run)"
    $out = Join-Path $root $run
    $r = Invoke-Signing ($common + @('-Thumbprint', $thumb, '-OutDir', $out))
    Check ($r.Code -eq 0) 'exit code 0'
    Check ($r.Output -match 'untrusted root') 'the untrusted test root is reported as such'

    $zip = Join-Path $out $zipName
    $setup = Join-Path $out $setupName
    Check (Test-Path $zip) "$zipName written"
    Check (Test-Path $setup) "$setupName written"
    if (-not ((Test-Path $zip) -and (Test-Path $setup))) { continue }

    $entries = Get-EntryNames $zip
    Check (($entries -join '|') -ceq ($inputEntries -join '|')) "the zip keeps the input's $($inputEntries.Count) entries in order"

    $unpacked = Join-Path $root "$run-unpacked"
    Expand-To $zip $unpacked
    foreach ($f in $unsigned) {
      $rel = $f.FullName.Substring($inputDir.Length + 1)
      Check (Test-SignedBy (Join-Path $unpacked $rel) $thumb) "$rel signed by the test certificate, timestamped"
    }
    foreach ($f in $signedByOthers) {
      $rel = $f.FullName.Substring($inputDir.Length + 1)
      $same = (Get-FileHash (Join-Path $unpacked $rel)).Hash -eq (Get-FileHash $f.FullName).Hash
      $signer = (Get-AuthenticodeSignature (Join-Path $unpacked $rel)).SignerCertificate.Subject
      Check $same "$rel untouched (signed by $signer)"
    }
    foreach ($name in 'lumina_ui.exe', 'flutter_filament.dll', 'flutter_assimp.dll', 'flutter_riglogic.dll', 'flutter_windows.dll') {
      Check (Test-SignedBy (Join-Path $unpacked $name) $thumb) "$name is among the signed files"
    }
    foreach ($name in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
      $s = Get-AuthenticodeSignature (Join-Path $unpacked $name)
      Check ($s.Status -eq 'Valid' -and $s.SignerCertificate.Subject -match 'O=Microsoft Corporation') "$name still signed by Microsoft"
    }

    Check (Test-SignedBy $setup $thumb) 'setup.exe signed by the test certificate, timestamped'
    $v = (Get-Item $setup).VersionInfo
    Check ($v.FileVersion -eq $inputVersion.FileVersion -and $v.ProductVersion -eq $inputVersion.ProductVersion) "setup.exe version $($v.ProductVersion.Trim()) ($($v.FileVersion.Trim())) equals the input's"

    Check (Test-Sidecar $zip (Join-Path $FromDir "$zipName.sha256")) 'zip sidecar matches, in the input format'
    Check (Test-Sidecar $setup (Join-Path $FromDir "$setupName.sha256")) 'setup sidecar matches, in the input format'

    # The uninstaller is not a file inside setup.exe: Inno Setup signs it at
    # compile time, keeps the signature, and setup applies it to the
    # unins000.exe it writes at install time. The compiler log is the
    # evidence here.
    Check ($r.Output -match 'Running Sign Tool lumina: .*uninst\.e32\.tmp' -and $r.Output -match 'Successfully signed: .*uninst\.e32\.tmp') 'Inno Setup signed the uninstaller it embeds (SignedUninstaller)'
  }
} finally {
  if (Test-Path "Cert:\CurrentUser\My\$thumb") { Remove-Item -Path "Cert:\CurrentUser\My\$thumb" -DeleteKey }
  # Windows keeps a public copy of a self-signed signer it met while
  # verifying in the intermediate store; remove that one too.
  if (Test-Path "Cert:\CurrentUser\CA\$thumb") { Remove-Item -Path "Cert:\CurrentUser\CA\$thumb" }
  Write-Host "`nRemoved the test certificate $thumb"
  Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
}

if ($failures.Count) {
  Write-Host "`n$($failures.Count) check(s) failed:" -ForegroundColor Red
  $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
  exit 1
}
Write-Host "`nAll checks passed."
