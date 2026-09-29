# lumina_ui tools

## Windows MSIX packages

`tool/package-windows.sh` builds an installable MSIX package of Lumina Studio. It is a POSIX
script, run from Git Bash on Windows as `tool/ci.sh` is. The logic is Dart: `tool/package_windows.dart` →
`lib/tooling/windows_packaging/`. It drives the [`msix`](https://pub.dev/packages/msix) dev dependency, and the
identity comes from `msix_config` in `pubspec.yaml`:

- `identity_name`: `LuminaEngine.LuminaEngine`
- display name: `Lumina Engine`
- execution alias: `lumina-studio`
- architecture: `x64`

```sh
tool/package-windows.sh                  # self-signed (the stable Lumina dev certificate)
tool/package-windows.sh --publish        # signed and timestamped with the certificate from the environment
tool/package-windows.sh --dry-run        # print the plan and the exact `dart run msix:create …`, touch nothing
tool/package-windows.sh --help
```

| Option | Meaning |
|---|---|
| `--publish` | Distribution signing (below). Without it the package is self-signed. |
| `--version a.b.c.d` | Package version. Default: pubspec `version: x.y.z+n` → `x.y.z.n` (0.0.1+1 → 0.0.1.1). |
| `--output <dir>` | Output folder, default `build/msix/`. Keep it short (MAX_PATH). |
| `--skip-build` | Reuse `build/windows/x64/runner/Release/` instead of running `flutter build windows`. |
| `--appinstaller <folder>` | Publish mode only: also run `msix:publish` into that folder, for App Installer updates. |
| `--dry-run` | Print the resolved plan and command. Passwords are masked. |

The output is `build/msix/LuminaEngine_<version>_x64.msix`. After `msix:create` the script reads the package back:

- The zip must hold `lumina_ui.exe`, `flutter_windows.dll`, the Filament / Assimp / RigLogic DLLs, `data/app.so`,
  `data/flutter_assets/` and `AppxManifest.xml`.
- The manifest's Identity Name, Publisher and Version must be the expected ones.
- `Get-AuthenticodeSignature` must name the expected signer.

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

### Microsoft Store (future)

The identity in `msix_config` is the Store reservation. The Store / Partner Center publisher is
`CN=76408633-2846-4256-BED6-0DF8748A95C6`, recorded as `msix_config: publisher`. A Store upload is unsigned
(`msix:create --store`, which the Store signs) and is not part of this script yet. A future `--store` mode would pass
that publisher and skip signing.

### Tests

The tests run real PowerShell, certificates and zip files, in temp folders:

- `test/tooling/package_windows_args_test.dart`
- `test/tooling/package_windows_plan_test.dart`
- `test/tooling/package_windows_certificate_test.dart`
- `test/tooling/package_windows_script_test.dart`
- `test/tooling/package_windows_verify_test.dart`, which packages the existing Release build. It is skipped when
  there is none, unless `LUMINA_PACKAGING_TESTS=1` (`tool/ci.sh --package`) allows a full build.

The smoke scenario is `integration_test/smoke/windows_packaging_smoke_test.dart`. It installs the package, starts it
through `lumina-studio` on DISPLAY1, opens a project's Filament viewport over MCP, and uninstalls. It is skipped until
the dev certificate is trusted.

### From an installed copy

An installed Studio lives in the read-only `C:\Program Files\WindowsApps\…`, with no workspace checkout and no
Flutter SDK. It starts to the launcher and opens existing plugin-less projects in its own editor. Creating projects
and per-project editor builds still need the workspace.
