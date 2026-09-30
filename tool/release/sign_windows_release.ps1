<#
.SYNOPSIS
  Authenticode-signs the Windows assets of a Lumina Studio GitHub release on
  this machine, with a code-signing certificate from the Windows certificate
  store (a Certum cloud certificate through SimplySign Desktop).

.DESCRIPTION
  The release workflow builds the Windows zip and setup.exe but cannot sign
  them: the key of a cloud certificate is reachable only through SimplySign
  Desktop on the maintainer's machine. With the repository variable
  LUMINA_WINDOWS_SIGNING=local the workflow leaves the release as a draft,
  and this script finishes it:

    1. checks the prerequisites (signtool, Inno Setup 6, git, gh, the
       certificate with its private key and the Code Signing usage);
    2. downloads lumina-studio-<tag>-windows-x64.zip, the setup and their
       .sha256 sidecars from the release (drafts included), or copies them
       from -FromDir, and checks the zip against its sidecar;
    3. unpacks the zip and signs every unsigned .exe/.dll (lumina_ui.exe and
       our DLLs) with a timestamp; files already signed by someone else, such
       as the Microsoft Visual C++ runtime, are left untouched;
    4. writes the zip again with the same entries in the same order and
       rewrites its .sha256 in the format of the original sidecar;
    5. rebuilds setup.exe from the tag's installer sources with Inno Setup's
       sign tool support, so setup.exe and the uninstaller it embeds are both
       signed, and rewrites its .sha256;
    6. uploads the four files over the release's (gh release upload
       --clobber) and, with -Publish, publishes the draft.

  Everything happens in a work folder (-WorkDir) that each run starts afresh
  from the downloaded originals, so running it again is safe. Files already
  signed with the selected certificate are not signed a second time.

.PARAMETER Tag
  The release tag, e.g. v0.1.0.

.PARAMETER CertificateSubject
  Selects the certificate in Cert:\CurrentUser\My by its subject: the full
  distinguished name or just the common name (CN).

.PARAMETER Thumbprint
  Selects the certificate by its SHA-1 thumbprint instead.

.PARAMETER TimestampUrl
  RFC 3161 timestamp server. Default: Certum's, http://time.certum.pl.

.PARAMETER Publish
  After uploading, publish the draft release and replace the "being signed"
  line of its notes.

.PARAMETER FromDir
  Offline mode: take the zip, the setup and their sidecars from this folder
  instead of the release. Nothing is uploaded; the results go to -OutDir.

.PARAMETER OutDir
  Where the signed files are copied. Default in offline mode:
  <FromDir>\signed. Online the files are uploaded and also copied here when
  it is given.

.PARAMETER InstallerSourceRef
  The git ref whose installer sources (installer/windows and the setup icon)
  build the setup. Default: the tag, so the setup matches the one CI built.
  "worktree" uses this checkout's working tree instead.

.PARAMETER Repository
  owner/name of the GitHub repository. Default: LuminaGame/lumina.

.PARAMETER WorkDir
  The work folder. Default: %TEMP%\lumina-sign-<tag>.

.PARAMETER DryRun
  Check, download and unpack, then print what would be signed, built and
  uploaded. Nothing is signed, written to -OutDir or uploaded.

.PARAMETER AllowUntrustedForTest
  Accept a signature whose certificate chain ends in an untrusted root (a
  self-signed test certificate): it is reported as "untrusted root" instead of
  failing the verification. The signer and the timestamp are still checked.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tool\release\sign_windows_release.ps1 -Tag v0.1.0 -CertificateSubject "Open Source Developer, Jane Doe" -Publish

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tool\release\sign_windows_release.ps1 -Tag v0.1.0 -Thumbprint 0123456789ABCDEF0123456789ABCDEF01234567 -DryRun

.EXAMPLE
  # Offline: sign assets in a folder, results into <folder>\signed.
  powershell -ExecutionPolicy Bypass -File tool\release\sign_windows_release.ps1 -Tag v0.1.0 -Thumbprint <sha1> -FromDir C:\release-assets
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^v\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$')]
  [string]$Tag,
  [string]$CertificateSubject,
  [string]$Thumbprint,
  [string]$TimestampUrl = 'http://time.certum.pl',
  [switch]$Publish,
  [string]$FromDir,
  [string]$OutDir,
  [string]$InstallerSourceRef,
  [string]$Repository = 'LuminaGame/lumina',
  [string]$WorkDir,
  [switch]$DryRun,
  [switch]$AllowUntrustedForTest
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

$CodeSigningOid = '1.3.6.1.5.5.7.3.3'
$SigningMarker = '> **Windows assets are being signed.**'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$version = $Tag.Substring(1)
$zipName = "lumina-studio-$Tag-windows-x64.zip"
$setupName = "lumina-studio-setup-$Tag-windows-x64.exe"
$offline = [bool]$FromDir
if (-not $InstallerSourceRef) { $InstallerSourceRef = $Tag }
if (-not $WorkDir) { $WorkDir = Join-Path ([IO.Path]::GetTempPath()) "lumina-sign-$Tag" }
if ($offline -and -not $OutDir) { $OutDir = Join-Path $FromDir 'signed' }
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Say([string]$Text) { Write-Host $Text }
function Step([string]$Text) { Write-Host ''; Write-Host "== $Text" -ForegroundColor Cyan }
function Fail([string]$Text) {
  Write-Host ''
  Write-Host "error: $Text" -ForegroundColor Red
  exit 1
}

# Runs a native program and returns its exit code and output (stdout and
# stderr together) without letting stderr turn into a PowerShell error.
function Invoke-Native([string]$Exe, [string[]]$Arguments, [switch]$Echo) {
  $eap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $output = @(& $Exe @Arguments 2>&1 | ForEach-Object { "$_" })
    $code = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $eap
  }
  if ($Echo) { $output | ForEach-Object { Say "    $_" } }
  return New-Object PSObject -Property @{ Code = $code; Output = $output }
}

function Find-SignTool {
  $roots = New-Object System.Collections.Generic.List[string]
  foreach ($key in 'HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots') {
    $value = (Get-ItemProperty -Path $key -Name KitsRoot10 -ErrorAction SilentlyContinue).KitsRoot10
    if ($value) { $roots.Add($value) }
  }
  if (${env:ProgramFiles(x86)}) { $roots.Add((Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10')) }
  foreach ($root in $roots) {
    $bin = Join-Path $root 'bin'
    if (-not (Test-Path $bin)) { continue }
    $candidates = Get-ChildItem $bin -Directory -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -match '^\d+(\.\d+){3}$' } |
      Sort-Object { [version]$_.Name } -Descending |
      ForEach-Object { Join-Path $_.FullName 'x64\signtool.exe' } |
      Where-Object { Test-Path $_ }
    if ($candidates) { return @($candidates)[0] }
    $flat = Join-Path $bin 'x64\signtool.exe'
    if (Test-Path $flat) { return $flat }
  }
  $cmd = Get-Command signtool.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

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

function Test-CodeSigningUsage($Cert) {
  foreach ($ext in $Cert.Extensions) {
    if ($ext -is [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]) {
      foreach ($oid in $ext.EnhancedKeyUsages) { if ($oid.Value -eq $CodeSigningOid) { return $true } }
    }
  }
  return $false
}

function Get-CommonName($Cert) {
  if (-not $Cert) { return '' }
  return $Cert.GetNameInfo([System.Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $false)
}

# The signing certificate, or a message saying what is wrong.
function Select-Certificate {
  $simplySign = 'Start SimplySign Desktop and log in (the certificate appears in the Windows certificate store while it is connected).'
  $store = @(Get-ChildItem Cert:\CurrentUser\My)
  if ($Thumbprint) {
    $wanted = ($Thumbprint -replace '[^0-9A-Fa-f]', '').ToUpperInvariant()
    $found = @($store | Where-Object { $_.Thumbprint -eq $wanted })
    $what = "thumbprint $wanted"
  } else {
    $found = @($store | Where-Object {
        $_.Subject -eq $CertificateSubject -or (Get-CommonName $_) -eq $CertificateSubject
      })
    $what = "subject '$CertificateSubject'"
  }
  if (-not $found) { return "No certificate with $what in Cert:\CurrentUser\My. $simplySign" }
  $now = Get-Date
  $usable = @($found | Where-Object { Test-CodeSigningUsage $_ })
  if (-not $usable) { return "The certificate with $what has no Code Signing usage ($CodeSigningOid)." }
  $usable = @($usable | Where-Object { $_.NotBefore -le $now -and $_.NotAfter -gt $now })
  if (-not $usable) { return "The certificate with $what has expired or is not valid yet." }
  $usable = @($usable | Where-Object { $_.HasPrivateKey })
  if (-not $usable) { return "The certificate with $what has no private key on this machine. $simplySign" }
  return @($usable | Sort-Object NotAfter -Descending)[0]
}

function Read-SidecarSeparator([string]$Path) {
  if (Test-Path $Path) {
    $m = [regex]::Match([IO.File]::ReadAllText($Path), '^[0-9a-fA-F]{64}( \*|  )')
    if ($m.Success) { return $m.Groups[1].Value }
  }
  return '  '
}

# Writes <file>.sha256 as "<hash><separator><name>\n", UTF-8 without BOM.
function Write-Sidecar([string]$File, [string]$Separator) {
  $hash = (Get-FileHash -Algorithm SHA256 $File).Hash.ToLowerInvariant()
  $name = Split-Path -Leaf $File
  [IO.File]::WriteAllText("$File.sha256", "$hash$Separator$name`n", $utf8)
  return $hash
}

function Test-Sidecar([string]$File) {
  $expected = (([IO.File]::ReadAllText("$File.sha256")) -split '\s+')[0].ToLowerInvariant()
  return $expected -eq (Get-FileHash -Algorithm SHA256 $File).Hash.ToLowerInvariant()
}

# Writes $Dest with the entries of $Template, in its order, with its names and
# timestamps, taking each file's content from $SourceDir.
function Write-ZipLike([string]$Template, [string]$SourceDir, [string]$Dest) {
  $in = [IO.Compression.ZipFile]::OpenRead($Template)
  try {
    $stream = [IO.File]::Open($Dest, [IO.FileMode]::CreateNew)
    $zip = New-Object IO.Compression.ZipArchive($stream, [IO.Compression.ZipArchiveMode]::Create)
    try {
      foreach ($entry in $in.Entries) {
        $isDir = $entry.FullName.EndsWith('/')
        $level = if ($isDir) { [IO.Compression.CompressionLevel]::NoCompression } else { [IO.Compression.CompressionLevel]::Optimal }
        $out = $zip.CreateEntry($entry.FullName, $level)
        $out.LastWriteTime = $entry.LastWriteTime
        if ($out.PSObject.Properties['ExternalAttributes']) { $out.ExternalAttributes = $entry.ExternalAttributes }
        if ($isDir) { continue }
        $src = [IO.File]::OpenRead((Join-Path $SourceDir ($entry.FullName -replace '/', '\')))
        $dst = $out.Open()
        try { $src.CopyTo($dst) } finally { $dst.Dispose(); $src.Dispose() }
      }
    } finally {
      $zip.Dispose()
      $stream.Dispose()
    }
  } finally {
    $in.Dispose()
  }
}

# signtool verify /pa, the signer and the timestamp of a file signed with
# $Cert. Returns the timestamp text; exits with an error when a check fails.
function Confirm-Signature([string]$File, $Cert) {
  $name = Split-Path -Leaf $File
  $sig = Get-AuthenticodeSignature -FilePath $File
  if (-not $sig.SignerCertificate -or $sig.SignerCertificate.Thumbprint -ne $Cert.Thumbprint) {
    Fail "$name is not signed with the selected certificate after signing."
  }
  if (-not $sig.TimeStamperCertificate) { Fail "$name has no timestamp countersignature." }
  $verify = Invoke-Native $script:signTool @('verify', '/pa', '/v', $File)
  $text = $verify.Output -join "`n"
  $m = [regex]::Match($text, 'The signature is timestamped: (.+)')
  $time = if ($m.Success) { $m.Groups[1].Value.Trim() } else { Get-CommonName $sig.TimeStamperCertificate }
  if ($verify.Code -ne 0) {
    $untrusted = $text -match 'not trusted by the trust provider'
    if ($untrusted -and $AllowUntrustedForTest) {
      Say "    $name`: signature and timestamp present, untrusted root (allowed for test)"
      return $time
    }
    $verify.Output | ForEach-Object { Say "    $_" }
    Fail "signtool verify /pa failed for $name."
  }
  Say "    $name`: verified (signtool verify /pa), timestamped $time"
  return $time
}

# ---------------------------------------------------------------------------
Step "Lumina release signing: $Tag ($(if ($offline) { "offline, from $FromDir" } else { $Repository }))"
if ($CertificateSubject -and $Thumbprint) { Fail 'Give either -CertificateSubject or -Thumbprint, not both.' }
if (-not $CertificateSubject -and -not $Thumbprint) { Fail 'Select the certificate with -CertificateSubject "<subject or CN>" or -Thumbprint <sha1>.' }
if ($Publish -and $offline) { Fail '-Publish needs the online mode (without -FromDir).' }

Step 'Prerequisites'
$problems = New-Object System.Collections.Generic.List[string]
$script:signTool = Find-SignTool
if ($script:signTool) { Say "  signtool    $script:signTool" } else {
  $problems.Add('signtool.exe not found: install the Windows SDK with its "Signing Tools for Desktop Apps" (Visual Studio Installer > Individual components > Windows SDK, or winget install Microsoft.WindowsSDK.10.0.26100).')
}
$iscc = Find-Iscc
if ($iscc) { Say "  ISCC        $iscc" } else { $problems.Add('ISCC.exe (Inno Setup 6) not found: winget install JRSoftware.InnoSetup') }
if ($InstallerSourceRef -ne 'worktree') {
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    $problems.Add('git not found on PATH (needed to read the installer sources of the tag).')
  } else {
    $has = Invoke-Native git @('-C', $repoRoot, 'rev-parse', '--verify', '--quiet', "$InstallerSourceRef^{commit}")
    if ($has.Code -ne 0 -and $InstallerSourceRef -eq $Tag) {
      Say "  fetching tag $Tag from origin"
      $null = Invoke-Native git @('-C', $repoRoot, 'fetch', '--quiet', 'origin', "refs/tags/${Tag}:refs/tags/${Tag}") -Echo
      $has = Invoke-Native git @('-C', $repoRoot, 'rev-parse', '--verify', '--quiet', "$InstallerSourceRef^{commit}")
    }
    if ($has.Code -eq 0) { Say "  installer   $InstallerSourceRef ($($has.Output[0].Substring(0, 12)))" } else {
      $problems.Add("git ref '$InstallerSourceRef' not found in $repoRoot.")
    }
  }
} else {
  Say "  installer   working tree of $repoRoot"
}
if (-not $offline) {
  if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    $problems.Add('gh (GitHub CLI) not found: winget install GitHub.cli, then gh auth login')
  } elseif ((Invoke-Native gh @('auth', 'status')).Code -ne 0) {
    $problems.Add('gh is not logged in: gh auth login')
  } else {
    Say '  gh          logged in'
  }
}
$cert = Select-Certificate
if ($cert -is [string]) {
  $problems.Add($cert)
  $cert = $null
} else {
  Say "  certificate $($cert.Subject)"
  Say "              thumbprint $($cert.Thumbprint), valid until $($cert.NotAfter.ToString('yyyy-MM-dd'))"
}
Say "  timestamp   $TimestampUrl"
if ($problems.Count) {
  $problems | ForEach-Object { Say "  missing: $_" }
  if (-not $DryRun) { Fail ($problems -join "`n       ") }
  Say '  (dry run: continuing with what is available)'
}
$thumb = if ($cert) { $cert.Thumbprint } else { '<thumbprint>' }
$signArgs = @('sign', '/fd', 'sha256', '/tr', $TimestampUrl, '/td', 'sha256', '/sha1', $thumb)

Step "Work folder $WorkDir"
$inputDir = Join-Path $WorkDir 'input'
$unpacked = Join-Path $WorkDir 'unpacked'
$srcDir = Join-Path $WorkDir 'src'
$outWork = Join-Path $WorkDir 'out'
foreach ($d in $unpacked, $srcDir, $outWork) { if (Test-Path $d) { Remove-Item -Recurse -Force $d } }
foreach ($d in $inputDir, $unpacked, $srcDir, $outWork) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
$assets = @($zipName, "$zipName.sha256", $setupName, "$setupName.sha256")
Get-ChildItem $inputDir -File | Remove-Item -Force

if ($offline) {
  foreach ($a in $assets) {
    $p = Join-Path $FromDir $a
    if (-not (Test-Path $p)) { Fail "$FromDir has no $a." }
    Copy-Item $p $inputDir
  }
  Say "  copied $($assets.Count) files from $FromDir"
} else {
  $view = Invoke-Native gh @('release', 'view', $Tag, '-R', $Repository, '--json', 'isDraft,isPrerelease,name')
  if ($view.Code -ne 0) { $view.Output | ForEach-Object { Say "    $_" }; Fail "Release $Tag not found in $Repository." }
  $info = ($view.Output -join "`n") | ConvertFrom-Json
  Say ("  release '{0}': {1}{2}" -f $info.name, $(if ($info.isDraft) { 'draft' } else { 'published' }), $(if ($info.isPrerelease) { ', pre-release' } else { '' }))
  $dl = @('release', 'download', $Tag, '-R', $Repository, '-D', $inputDir, '--clobber')
  foreach ($a in $assets) { $dl += @('-p', $a) }
  $r = Invoke-Native gh $dl -Echo
  if ($r.Code -ne 0) { Fail "gh release download failed (exit $($r.Code))." }
  foreach ($a in $assets) { if (-not (Test-Path (Join-Path $inputDir $a))) { Fail "Release $Tag has no $a." } }
  Say "  downloaded $($assets.Count) files"
}
$inZip = Join-Path $inputDir $zipName
$inSetup = Join-Path $inputDir $setupName
if (-not (Test-Sidecar $inZip)) { Fail "$zipName does not match its .sha256 sidecar." }
Say "  $zipName matches its sidecar"
$zipSeparator = Read-SidecarSeparator "$inZip.sha256"
$setupSeparator = Read-SidecarSeparator "$inSetup.sha256"

Step 'Editor files'
[IO.Compression.ZipFile]::ExtractToDirectory($inZip, $unpacked)
$summary = New-Object System.Collections.Generic.List[object]
$toSign = New-Object System.Collections.Generic.List[string]
$pe = @(Get-ChildItem $unpacked -Recurse -File | Where-Object { $_.Extension -eq '.exe' -or $_.Extension -eq '.dll' } | Sort-Object FullName)
foreach ($f in $pe) {
  $rel = $f.FullName.Substring($unpacked.Length + 1)
  $sig = Get-AuthenticodeSignature -FilePath $f.FullName
  $signer = Get-CommonName $sig.SignerCertificate
  if ($sig.Status -eq 'NotSigned') {
    $toSign.Add($f.FullName)
    Say "  sign        $rel"
  } elseif ($cert -and $sig.SignerCertificate -and $sig.SignerCertificate.Thumbprint -eq $cert.Thumbprint) {
    Say "  already     $rel (signed with this certificate)"
    $summary.Add([pscustomobject]@{ File = $rel; Action = 'already signed'; Signer = $signer; Timestamp = (Get-CommonName $sig.TimeStamperCertificate) })
  } elseif ($sig.Status -eq 'Valid') {
    Say "  leave       $rel (signed by $signer)"
    $summary.Add([pscustomobject]@{ File = $rel; Action = 'left as is'; Signer = $signer; Timestamp = (Get-CommonName $sig.TimeStamperCertificate) })
  } else {
    Fail "$rel carries a signature that does not verify ($($sig.Status): $($sig.StatusMessage)); not replacing someone else's signature."
  }
}
if (-not $pe) { Fail "$zipName holds no .exe or .dll." }

Step 'Installer sources'
if ($InstallerSourceRef -eq 'worktree') {
  New-Item -ItemType Directory -Force -Path (Join-Path $srcDir 'installer') | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $srcDir 'lumina_ui\windows\runner\resources') | Out-Null
  Copy-Item -Recurse (Join-Path $repoRoot 'installer\windows') (Join-Path $srcDir 'installer\windows')
  Copy-Item (Join-Path $repoRoot 'lumina_ui\windows\runner\resources\app_icon.ico') (Join-Path $srcDir 'lumina_ui\windows\runner\resources')
} else {
  $archive = Join-Path $WorkDir 'installer-src.zip'
  if (Test-Path $archive) { Remove-Item -Force $archive }
  $r = Invoke-Native git @('-C', $repoRoot, 'archive', '--format=zip', '-o', $archive, $InstallerSourceRef, '--', 'installer/windows', 'lumina_ui/windows/runner/resources/app_icon.ico') -Echo
  if ($r.Code -ne 0) { Fail "git archive $InstallerSourceRef failed." }
  [IO.Compression.ZipFile]::ExtractToDirectory($archive, $srcDir)
}
$build = Join-Path $srcDir 'installer\windows\build.ps1'
if (-not (Select-String -Path (Join-Path $srcDir 'installer\windows\lumina-studio.iss') -Pattern 'SignedUninstaller' -Quiet)) {
  $predates = "The installer sources of $InstallerSourceRef predate signed setup builds. Pass -InstallerSourceRef with a newer commit (or 'worktree')."
  if (-not $DryRun) { Fail $predates }
  Say "  missing: $predates"
} else {
  Say "  installer sources of $InstallerSourceRef in $srcDir"
}

# An Inno Setup sign tool command: $q is a double quote, $f the file.
$signToolCommand = '$q' + $script:signTool + '$q ' + ($signArgs -join ' ') + ' $f'
$outZip = Join-Path $outWork $zipName
$outSetup = Join-Path $outWork $setupName

if ($DryRun) {
  Step 'Plan (dry run: nothing is signed, built or uploaded)'
  Say "  signtool $($signArgs -join ' ') <$($toSign.Count) files>"
  Say "  then:     signtool verify /pa on each"
  if ($toSign.Count) { Say "  zip:      $zipName rewritten with the input's entries, .sha256 as '<hash>$zipSeparator<name>'" } else { Say "  zip:      unchanged (nothing to sign)" }
  Say "  setup:    installer/windows/build.ps1 -Version $version -Tag $Tag (sources: $InstallerSourceRef)"
  Say "            -SignToolCommand '$signToolCommand'"
  if ($offline) { Say "  output:   $OutDir" } else {
    Say "  upload:   gh release upload $Tag $($assets -join ' ') --clobber -R $Repository"
    if ($Publish) { Say "  publish:  gh release edit $Tag --draft=false (notes: the signing line replaced)" }
  }
  exit 0
}

if ($toSign.Count) {
  Step "Signing $($toSign.Count) files"
  $attempt = 0
  while ($true) {
    $attempt++
    $pending = @($toSign | Where-Object { (Get-AuthenticodeSignature -FilePath $_).Status -eq 'NotSigned' })
    if (-not $pending) { break }
    $r = Invoke-Native $script:signTool ($signArgs + $pending) -Echo
    if ($r.Code -eq 0) { break }
    if ($attempt -ge 3) { Fail 'signtool sign failed three times. Is SimplySign Desktop still logged in, and is the timestamp server reachable?' }
    Say "  signtool failed (exit $($r.Code)); retrying in 10 s"
    Start-Sleep -Seconds 10
  }
  Step 'Verifying'
  foreach ($file in $toSign) {
    $time = Confirm-Signature $file $cert
    $summary.Add([pscustomobject]@{ File = $file.Substring($unpacked.Length + 1); Action = 'signed'; Signer = (Get-CommonName $cert); Timestamp = $time })
  }
  Step "Writing $zipName"
  Write-ZipLike $inZip $unpacked $outZip
  $check = [IO.Compression.ZipFile]::OpenRead($outZip)
  $orig = [IO.Compression.ZipFile]::OpenRead($inZip)
  try {
    $same = (@($check.Entries | ForEach-Object { $_.FullName }) -join '|') -ceq (@($orig.Entries | ForEach-Object { $_.FullName }) -join '|')
    $count = $orig.Entries.Count
  } finally {
    $check.Dispose()
    $orig.Dispose()
  }
  if (-not $same) { Fail "The new $zipName does not have the original entries." }
  Say "  $count entries, same names and order as the original"
} else {
  Step "Nothing in $zipName needs signing; keeping it as it is"
  Copy-Item $inZip $outZip
}
$zipHash = Write-Sidecar $outZip $zipSeparator
Say "  sha256 $zipHash"

Step "Building $setupName (signed)"
& $build -Version $version -Tag $Tag -OutDir $outWork -SignToolCommand $signToolCommand
if (-not (Test-Path $outSetup)) { Fail "The setup build did not produce $setupName." }
$time = Confirm-Signature $outSetup $cert
$summary.Add([pscustomobject]@{ File = $setupName; Action = 'rebuilt, signed'; Signer = (Get-CommonName $cert); Timestamp = $time })
$was = (Get-Item $inSetup).VersionInfo
$now = (Get-Item $outSetup).VersionInfo
if ($was.FileVersion -ne $now.FileVersion -or $was.ProductVersion -ne $now.ProductVersion) {
  Fail "The rebuilt setup is version $($now.ProductVersion.Trim()) ($($now.FileVersion.Trim())), the release's is $($was.ProductVersion.Trim()) ($($was.FileVersion.Trim()))."
}
Say "  version $($now.ProductVersion.Trim()) ($($now.FileVersion.Trim())), as the release's setup"
$setupHash = Write-Sidecar $outSetup $setupSeparator
Say "  sha256 $setupHash"
$results = @($outZip, "$outZip.sha256", $outSetup, "$outSetup.sha256")
foreach ($f in $outZip, $outSetup) { if (-not (Test-Sidecar $f)) { Fail "$(Split-Path -Leaf $f) does not match its new sidecar." } }

if ($OutDir) {
  New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
  $results | ForEach-Object { Copy-Item $_ $OutDir -Force }
  Step "Copied the signed files to $OutDir"
}

if (-not $offline) {
  Step "Uploading to release $Tag"
  $r = Invoke-Native gh (@('release', 'upload', $Tag) + $results + @('--clobber', '-R', $Repository)) -Echo
  if ($r.Code -ne 0) { Fail "gh release upload failed (exit $($r.Code))." }
  $view = Invoke-Native gh @('release', 'view', $Tag, '-R', $Repository, '--json', 'assets,body,isDraft')
  if ($view.Code -ne 0) { Fail 'gh release view failed after the upload.' }
  $info = ($view.Output -join "`n") | ConvertFrom-Json
  foreach ($f in $results) {
    $name = Split-Path -Leaf $f
    $asset = @($info.assets | Where-Object { $_.name -eq $name })[0]
    if (-not $asset -or [int64]$asset.size -ne (Get-Item $f).Length) { Fail "The uploaded $name does not have the local size." }
  }
  Say '  uploaded sizes match'
  if ($Publish) {
    Step "Publishing release $Tag"
    $lines = @($info.body -split "`r?`n")
    $signed = "> Windows executables and DLLs are Authenticode-signed ($(Get-CommonName $cert))."
    $lines = @($lines | ForEach-Object { if ($_.StartsWith($SigningMarker)) { $signed } else { $_ } })
    $notes = Join-Path $WorkDir 'notes.md'
    [IO.File]::WriteAllText($notes, ($lines -join "`n"), $utf8)
    $r = Invoke-Native gh @('release', 'edit', $Tag, '-R', $Repository, '--draft=false', '--notes-file', $notes) -Echo
    if ($r.Code -ne 0) { Fail "gh release edit failed (exit $($r.Code))." }
    Say "  published"
  } elseif ($info.isDraft) {
    Say ''
    Say "The release is still a draft. Publish it with -Publish, or on GitHub."
  }
}

Step 'Summary'
$summary | Sort-Object File | Format-Table -AutoSize File, Action, Signer, Timestamp | Out-String -Width 220 | Write-Host
Say "Certificate: $($cert.Subject) ($($cert.Thumbprint))"
if ($offline) { Say "Signed files: $OutDir" }
