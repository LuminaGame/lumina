# lumina_ui tools

## Windows MSIX packages

`tool/package-windows.sh` builds an installable MSIX package of Lumina Studio. It is a POSIX
script, run from Git Bash on Windows as `tool/ci.sh` is. The logic is Dart: `tool/package_windows.dart` →
`lib/tooling/windows_packaging/`. It drives the [`msix`](https://pub.dev/packages/msix) dev dependency, and the
identity comes from `msix_config` in `pubspec.yaml`:

- `identity_name`: `LuminaEngine.LuminaEngine`
- display name: `Lumina Engine`
- execution alias: `lumina-studio`
- architecture: `x64`, `TargetDeviceFamily Windows.Desktop` from `os_min_version: 10.0.19041.0` (Windows 10 2004)
- the Partner Center publisher `CN=76408633-2846-4256-BED6-0DF8748A95C6` (`publisher`, used by `--store`)

```sh
tool/package-windows.sh                  # self-signed (the stable Lumina dev certificate)
tool/package-windows.sh --publish        # signed and timestamped with the certificate from the environment
tool/package-windows.sh --store          # unsigned Microsoft Store package (the Store signs it)
tool/package-windows.sh --dry-run        # print the plan and the exact `dart run msix:create …`, touch nothing
tool/package-windows.sh --help
```

| Option | Meaning |
|---|---|
| `--publish` | Distribution signing (below). Without it (and without `--store`) the package is self-signed. |
| `--store` | An unsigned Microsoft Store package (below). Excludes `--publish` and `--appinstaller`. |
| `--version a.b.c.d` | Package version. Default: the pubspec version through the version scheme below (`0.0.1-dev.10+10` → `1.0.1010.0`). |
| `--output <dir>` | Output folder, default `build/msix/`. Keep it short (MAX_PATH). |
| `--skip-build` | Reuse `build/windows/x64/runner/Release/` instead of running `flutter build windows`. |
| `--appinstaller <folder>` | Publish mode only: also run `msix:publish` into that folder, for App Installer updates. |
| `--dry-run` | Print the resolved plan and command. Passwords are masked. |

The output is `build/msix/LuminaEngine_<version>_x64.msix`. After `msix:create` the script reads the package back:

- The zip must hold `lumina_ui.exe`, `flutter_windows.dll`, the Filament / Assimp / RigLogic DLLs, `data/app.so`,
  `data/flutter_assets/` and `AppxManifest.xml`.
- The manifest's Identity Name, Publisher and Version must be the expected ones.
- The manifest must declare the restricted capability `runFullTrust`, `internetClient`, `privateNetworkClientServer`,
  `TargetDeviceFamily Windows.Desktop` with `os_min_version`, and the `lumina-studio` alias.
- `Images/` must hold every logo the manifest references at every scale (`Square44x44Logo`, `Square150x150Logo`,
  `Wide310x150Logo`, `StoreLogo`, `LargeTile`, `SmallTile`, `SplashScreen`, `BadgeLogo` at 100/125/150/200/400 %, plus
  the `Square44x44Logo.targetsize-*` taskbar sizes). msix generates them from `logo_path`.
- `Get-AuthenticodeSignature` must name the expected signer (a Store package must be `NotSigned`).

It then prints the path, size, mode, publisher, thumbprint and signature status. Any mismatch fails the run (exit 1).

### Self-signed (default): local and team testing

The first run creates the Lumina development code-signing certificate in `windows/packaging/dev/` (git-ignored):

- `lumina_dev.pfx` and `lumina_dev.cer`, subject `CN=Lumina Studio Dev, O=Lumina, C=TR`, valid for five years;
- `password.txt`, the generated `.pfx` password (or set `LUMINA_MSIX_DEV_PASSWORD`).

The key is made with `New-SelfSignedCertificate` in `Cert:\CurrentUser\My` and removed from there after export.
Every later build reuses the same certificate, so the publisher never changes. Installing a newer package upgrades
the installed one in place.

Windows installs only packages it trusts. Trust the dev certificate once per machine, in an **elevated** PowerShell
(the script prints this command and never touches the machine store itself):

```powershell
Import-Certificate -FilePath 'D:\lumina\lumina_ui\windows\packaging\dev\lumina_dev.cer' -CertStoreLocation Cert:\LocalMachine\TrustedPeople
Add-AppxPackage -Path D:\lumina\lumina_ui\build\msix\LuminaEngine_0.0.1.1_x64.msix
lumina-studio          # the execution alias; or Start menu → Lumina Engine
```

Uninstall with `Get-AppxPackage LuminaEngine.LuminaEngine | Remove-AppxPackage`.

**Rotating the dev certificate:** delete `windows/packaging/dev/`, and the next run creates a new certificate. A new
certificate is a new publisher, so Windows treats the package as a different app: uninstall the old package first,
then trust the new `.cer`.

### `--publish`: distribution

The certificate comes only from the environment and is never stored in the repo. The script refuses with exit 64,
naming the problem, when input is missing or inconsistent. It never falls back to self-signing.

| Variable | |
|---|---|
| `LUMINA_MSIX_PUBLISHER` | Required. The certificate subject, e.g. `CN=Arbwick Ltd, O=Arbwick Ltd, C=GB`. The package publisher must equal it. |
| `LUMINA_MSIX_CERT_PATH` + `LUMINA_MSIX_CERT_PASSWORD` | A `.pfx` and its password. It is opened and its subject compared with `LUMINA_MSIX_PUBLISHER` before the build. |
| `LUMINA_MSIX_SIGNTOOL_OPTIONS` | Instead of a `.pfx`: signtool options for a key in the certificate store, on a token or in a cloud HSM, e.g. `/sha1 <thumbprint>`. They must select the certificate with `/sha1`, `/n`, `/r`, `/i` or `/f`; otherwise msix would sign with its own test certificate. |
| `LUMINA_MSIX_TIMESTAMP_URL` | Optional. Default `http://timestamp.digicert.com`. |

The signature is always SHA-256 and timestamped (`/fd SHA256 /tr <url> /td SHA256`). A publish build must verify as
`Valid` and timestamped.

```sh
LUMINA_MSIX_PUBLISHER='CN=Arbwick Ltd, O=Arbwick Ltd, C=GB' \
LUMINA_MSIX_SIGNTOOL_OPTIONS='/sha1 0123456789ABCDEF0123456789ABCDEF01234567' \
  tool/package-windows.sh --publish --version 1.0.0.0
```

### `--store`: Microsoft Store

The identity in `msix_config` is the Store reservation (Store ID `9PHJG2NH6BQF`, package family
`LuminaEngine.LuminaEngine_w6wj9n9zwya6m`). `--store` runs `msix:create --store`: no signature (the Store re-signs
every package it accepts) and the Partner Center publisher `CN=76408633-2846-4256-BED6-0DF8748A95C6` from
`msix_config: publisher`. The result is a `.msix`, which Partner Center accepts for desktop apps (an `.msixupload` only
adds a symbol file). It does not install locally: Windows refuses an unsigned package until the Store has signed it.
Every GitHub release attaches one as `lumina-studio-<tag>-windows-x64-store.msix`.

**Version scheme.** The Store needs four sections, the fourth `0` (it is the Store's), the first not `0`, each at most
65535, and a higher version for every later submission. The tool and the release workflow
(`tool/release/release_info.dart`) map the release version the same way (`storeMsixVersion`):

| Release | MSIX version |
|---|---|
| `0.0.1-dev.10` | `1.0.1010.0` |
| `0.0.1-rc.2` | `1.0.1502.0` |
| `0.0.1` | `1.0.1999.0` |
| `0.0.2-dev.1` | `1.0.2001.0` |
| `1.0.0` | `2.0.999.0` |

`M.m.p[-dev.N|-rc.N]` → `(M+1).m.(p*1000 + s).0`, `s` = `N` for `dev.N` (1–499), `500+N` for `rc.N` (1–498), `999`
for a final release. Other pre-release labels and patch numbers above 64 are refused (raise the minor instead).

**Submission.** Partner Center asks why the package declares the restricted capability `runFullTrust`; the text to
paste is in the windows_packaging backlog task. The package brings no Git, Flutter or Visual Studio Build Tools
(`setup.exe` does): the first-launch screen lists what is missing, and the Store listing should say so.

### Checking a packaged first launch

An MSIX app's new files under `%LOCALAPPDATA%` (the engine checkout, Filament, OpenRigLogic, `lumina\hosts`,
`lumina\editor-builds`, the pub cache) land in `%LOCALAPPDATA%\Packages\<package family>\LocalCache\Local\…` and
appear at the usual path for the app and the processes it starts only; they go when the app is uninstalled. To check
a real first launch, package a release build (it carries `LUMINA_VERSION`, so it bootstraps) with the trusted dev
certificate, the same package as the Store one apart from the publisher:

```powershell
# 1. A release build in the Release folder (a published zip, or flutter build windows --release
#    --dart-define=LUMINA_VERSION=<tag> --dart-define=LUMINA_COMMIT=<sha>), then, from Git Bash in lumina_ui:
#      tool/package-windows.sh --skip-build --output build/msix-<tag>
# 2. Install and start it from the Start menu (Lumina Engine), not from a terminal:
Add-AppxPackage -Path <lumina_ui>\build\msix-<tag>\LuminaEngine_<version>_x64.msix
# 3. After the first-launch screen reaches the launcher:
$pfn  = (Get-AppxPackage LuminaEngine.LuminaEngine).PackageFamilyName
$priv = "$env:LOCALAPPDATA\Packages\$pfn\LocalCache\Local"
Get-ChildItem "$priv\Lumina", "$priv\Lumina\engine"
Get-Item "$priv\Lumina\engine\<tag>\filament", "$priv\Lumina\engine\<tag>\openriglogic" | Select-Object FullName, LinkType, Target
# 4. In the launcher: create a project, enable a code plugin (a per-project editor build), open it, place a mesh.
# 5. Outside the package, the setup's Flutter SDK (if %LOCALAPPDATA%\Lumina\flutter exists) must still work:
flutter --version
# 6. Uninstall; the private LocalCache goes with it, projects in Documents stay:
Get-AppxPackage LuminaEngine.LuminaEngine | Remove-AppxPackage
```

A complete checkout of the same tag already in the real `%LOCALAPPDATA%\Lumina` (from `setup.exe`) is read through,
so the packaged copy may skip the clone; that is expected. What to look for: the clone, downloads, junctions and
`flutter pub get` succeed; the per-project editor builds and starts; nothing new appears in the real
`%LOCALAPPDATA%\Lumina`.

### Tests

The tests run real PowerShell, certificates and zip files, in temp folders:

- `test/tooling/package_windows_args_test.dart`
- `test/tooling/store_msix_version_test.dart` (the version scheme, also through `tool/release/release_info.dart`)
- `test/tooling/package_windows_plan_test.dart`
- `test/tooling/package_windows_certificate_test.dart`
- `test/tooling/package_windows_script_test.dart`
- `test/tooling/package_windows_verify_test.dart`, which packages the existing Release build (self-signed and
  `--store`) and checks the Store manifest requirements. It is skipped when
  there is none, unless `LUMINA_PACKAGING_TESTS=1` (`tool/ci.sh --package`) allows a full build.

The smoke scenario is `integration_test/smoke/windows_packaging_smoke_test.dart`. It installs the package, starts it
through `lumina-studio` on DISPLAY1, opens a project's Filament viewport over MCP, and uninstalls. It is skipped until
the dev certificate is trusted.

### From an installed copy

An installed Studio lives in the read-only `C:\Program Files\WindowsApps\…`, with no workspace checkout and no
Flutter SDK. It starts to the launcher and opens existing plugin-less projects in its own editor. Creating projects
and per-project editor builds still need the workspace.
