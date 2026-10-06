[Türkçe](README.tr.md)

# Lumina Studio installers

Native installers for Lumina Studio, the editor of the Lumina engine. None of them embeds the editor. Each one
installs what building and running Lumina projects needs, then downloads the latest editor build from the
[GitHub releases](https://github.com/LuminaGame/lumina/releases). A later update only needs a new release, not a
new installer.

| Platform | Package | Built by | Status |
|---|---|---|---|
| Windows | `lumina-studio-setup-<tag>-windows-x64.exe` (Inno Setup) | `windows/build.ps1` | released |
| Windows | `lumina-studio-<tag>-windows-x64-store.msix` (the editor, unsigned, for the Microsoft Store) | `lumina_ui/tool/package_windows.dart --store` | released |
| Windows | `lumina-studio-<tag>-windows-x64.msix` (the editor itself) | `lumina_ui/tool/package_windows.dart` | released when the signing secrets exist |
| Linux x64 | `lumina-studio_<version>-1_amd64.deb`, `lumina-studio-<version>-1.x86_64.rpm` (nfpm) | `linux/build.sh` | released |
| Linux arm64 | `lumina-studio_<version>-1_arm64.deb`, `lumina-studio-<version>-1.aarch64.rpm` (nfpm, `linux/build.sh <version> <tag> <out> arm64`) | `linux/build.sh` | released |
| macOS | `lumina-studio-<tag>-macos.pkg` (pkgbuild + productbuild) | `macos/build-pkg.sh` | written, not verified, disabled in the workflow |

The release workflow (`.github/workflows/release.yml`) builds all of them for every `v*` tag. Every asset has a
`.sha256` sidecar, and the installers check the editor download against it.

## Release assets

| Asset | Content |
|---|---|
| `lumina-studio-<tag>-windows-x64.zip` | `flutter build windows --release` output with the Visual C++ runtime DLLs next to `lumina_ui.exe`, at the archive root |
| `lumina-studio-<tag>-linux-x64.tar.gz`, `lumina-studio-<tag>-linux-arm64.tar.gz` | `flutter build linux --release` bundle (`lumina_ui`, `lib/`, `data/`), at the archive root |
| `openriglogic-<os>-x64.{zip,tar.gz}` | Prebuilt OpenRigLogic static library (built from the pinned tools commit), downloaded by the editor at first launch |

Both editor builds carry `--dart-define=LUMINA_VERSION=<tag>` and `--dart-define=LUMINA_COMMIT=<sha>`.

The prebuilt Filament (upstream v1.77.2 with this repository's patches) is not attached to the Lumina releases.
Each Filament version (`tool/filament/VERSION`) is published once, in its own release `filament-<VERSION>`:
`filament-<VERSION>-windows-x64.zip`, `filament-<VERSION>-linux-x64.tar.gz`, `filament-<VERSION>-linux-arm64.tar.gz` and their `.sha256` sidecars. It is a
pre-release that is never marked Latest and never changes once complete; the workflow creates it from the first
tag that needs it (`.github/scripts/filament_release.sh`) and later tags only link it in their notes. The editor
downloads from it at first launch and falls back to its own release's assets, which is where releases up to
v0.0.1-dev.6 keep their Filament.

**"Latest"** for the installers (setup.exe, `install-studio.sh`, "Update Lumina Studio", `lumina-studio --update`)
is `/releases/latest` when that release has the editor for the platform, else the newest published release,
pre-releases included, that has it. `filament-*` releases, drafts and releases without the
`lumina-studio-*` asset are never taken. `lumina-setup.ps1 -SelectReleaseFrom <file>` and
`install-studio.sh --select-release-from <file>` apply that choice to a saved `GET /repos/<repo>/releases` answer
(they print `tag=` and `asset=`), which is how it is tested.

## Windows: setup.exe

A per-user setup. It does not need administrator rights itself; winget asks for elevation for the machine-wide
packages.

1. **Prerequisites through winget.** Anything already present is skipped.
   - `Git.Git`
   - `Microsoft.VisualStudio.2022.BuildTools` with
     `--override "--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"`.
     An existing Visual Studio with the C++ tools (found with `vswhere`) counts as present.
   - `gstreamerproject.gstreamer`
   - `Gyan.FFmpeg.Essentials`, only with the "Install FFmpeg" task or `/FFMPEG`
2. **Flutter.** A `flutter` already on PATH is used as is. Otherwise the stable channel is cloned into
   `%LOCALAPPDATA%\Lumina\flutter` (`git clone --filter=blob:none -b stable`), and its `bin` folder is added to
   the user PATH.
3. **Lumina Studio.** Setup finds the latest release with the editor (above: `/releases/latest`, else the
   newest pre-release that has it), downloads `lumina-studio-<tag>-windows-x64.zip`, verifies its SHA-256 and unpacks it into
   `%LOCALAPPDATA%\Programs\Lumina Studio`. Setup offers a retry when the download fails.
4. **Shortcuts.** Start menu entries "Lumina Studio", "Update Lumina Studio" (downloads the latest release
   again) and the uninstaller, plus an optional desktop shortcut.

Setup runs with Inno Setup's `RedirectionGuard=no`. Windows hands that mitigation on to every process setup
starts, and a Lumina Studio started from the finish page could then not traverse the junctions of its engine
checkout and projects. Lumina Studio itself also checks the policy at startup on Windows: when whatever started it
enforced redirection trust, it starts again as a child of the Windows shell with the same arguments, and if that is
not possible it says to start it from the Start menu.

Uninstalling removes the editor folder. It asks before removing a Flutter SDK that setup installed, and removes
its PATH entry too. Git, the Build Tools, GStreamer and FFmpeg stay installed, because other programs may use
them.

The work is done by `windows/lumina-setup.ps1`, which setup installs into `{app}\setup\`. It also runs on its own:

```powershell
powershell -ExecutionPolicy Bypass -File installer\windows\lumina-setup.ps1 -DryRun
powershell -ExecutionPolicy Bypass -File installer\windows\lumina-setup.ps1 -StudioOnly   # just (re)download the editor
```

Exit codes: 0 done, 10 a prerequisite failed, 20 Flutter failed, 30 the editor could not be downloaded, 1 other.
The log is `{app}\setup\install.log`.

### Dry run

```powershell
lumina-studio-setup-v0.1.0-windows-x64.exe /DRYRUN
lumina-studio-setup-v0.1.0-windows-x64.exe /DRYRUN /FFMPEG /DRYRUNLOG=C:\temp\plan.txt /VERYSILENT
```

`/DRYRUN` shows the plan and exits with 0 before the wizard opens. The plan lists each prerequisite as present or
as the exact winget command, the Flutter step, and the release asset with its URL and size. Nothing is installed
or downloaded; the only network access is the read of the release metadata. The report is written to
`/DRYRUNLOG` (default `%TEMP%\lumina-studio-setup-dryrun.txt`) and shown in a message box unless setup runs with
`/VERYSILENT`.

### Build locally

```powershell
winget install JRSoftware.InnoSetup
./installer/windows/build.ps1 -Version 0.1.0 -Tag v0.1.0 -OutDir dist
```

The result is `dist/lumina-studio-setup-v0.1.0-windows-x64.exe` plus its `.sha256`. The setup icon is
`lumina_ui/windows/runner/resources/app_icon.ico`.

### MSIX

The release also carries the editor as an MSIX, made by the existing `lumina_ui/tool/package_windows.dart --publish`
with the identity in `lumina_ui/pubspec.yaml` `msix_config` (the Store reservation `LuminaEngine.LuminaEngine`).
The certificate comes from GitHub secrets (below). Without them the workflow skips the MSIX with a notice. The
certificate and its password never enter the repository or the logs. The `.pfx` is decoded into the runner's temp
folder and deleted after signing.

Every release also carries `lumina-studio-<tag>-windows-x64-store.msix`, the Microsoft Store package
(`package_windows.dart --store`): unsigned, because the Store re-signs every package it accepts, with the Partner
Center publisher `CN=76408633-2846-4256-BED6-0DF8748A95C6` from `msix_config`. It needs no secrets. Upload it in
Partner Center (Store ID `9PHJG2NH6BQF`); it does not install locally until the Store has signed it. Its version is
the check job's `msix_version` (`tool/release/release_info.dart`): `0.0.1-dev.10` → `1.0.1010.0`, `0.0.1` →
`1.0.1999.0`, `1.0.0` → `2.0.999.0`, so it grows with every tag and keeps the Store's rules (fourth section 0, first
not 0). `lumina_ui/tool/README.md` has the scheme and the manifest checks.

### Signing the Windows release (Certum)

The Windows zip and setup of a release can be Authenticode-signed with a Certum "Open Source Code Signing in the
Cloud" certificate. Its key stays in Certum's cloud (SimplySign): it is reachable only through SimplySign Desktop on
the maintainer's Windows machine, unlocked with a one-time code from the phone, so CI cannot sign with it. With the
repository variable `LUMINA_WINDOWS_SIGNING=local` the release workflow creates the release as a **draft** (a
pre-release stays a pre-release) whose notes start with "Windows assets are being signed", and
`tool/release/sign_windows_release.ps1` finishes it on that machine.

One-time setup:

1. Order the Certum "Open Source Code Signing in the Cloud" certificate. It is issued to an open-source developer,
   whose name appears in the certificate subject.
2. Identity validation: Certum checks your identity (an ID document; follow the instructions of the order) and the
   open-source project before it issues the certificate.
3. Install SimplySign Desktop on the Windows machine and the SimplySign app on the phone, and activate the account
   with the data Certum sends. Log in to SimplySign Desktop with a code from the app: the certificate then appears in
   the Windows certificate store. Note its subject or thumbprint:
   ```powershell
   Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Format-List Subject, Thumbprint, NotAfter
   ```
4. On the same machine: the Windows SDK signing tools (`signtool.exe`), Inno Setup 6, git with a checkout of this
   repository, and the GitHub CLI logged in (`gh auth login`) with write access to the repository.
5. Set the repository variable `LUMINA_WINDOWS_SIGNING` to `local` (Settings > Secrets and variables > Actions >
   Variables, or `gh variable set LUMINA_WINDOWS_SIGNING --body local -R LuminaGame/lumina`).

For every release, once the workflow has finished and SimplySign Desktop is logged in, from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File tool\release\sign_windows_release.ps1 -Tag v0.1.0 -CertificateSubject "<subject or CN>" -DryRun
powershell -ExecutionPolicy Bypass -File tool\release\sign_windows_release.ps1 -Tag v0.1.0 -CertificateSubject "<subject or CN>" -Publish
```

`-Thumbprint <sha1>` selects the certificate instead of `-CertificateSubject`. The script:

1. checks `signtool.exe`, `ISCC.exe`, git, `gh` and the certificate (private key present, Code Signing usage, not
   expired); without SimplySign Desktop it says "Start SimplySign Desktop and log in";
2. downloads `lumina-studio-<tag>-windows-x64.zip`, `lumina-studio-setup-<tag>-windows-x64.exe` and their `.sha256`
   files from the draft, and checks the zip against its sidecar;
3. signs `lumina_ui.exe` and our DLLs (`signtool sign /fd sha256 /tr http://time.certum.pl /td sha256 /sha1 <thumbprint>`)
   and verifies each (`signtool verify /pa`). Files that are already validly signed, such as Microsoft's Visual C++
   runtime DLLs, are left untouched;
4. writes the zip again with the same entries in the same order, and its `.sha256` in the original format;
5. rebuilds the setup from the tag's `installer/windows` sources (`git archive`) with the same version, through
   `build.ps1 -SignToolCommand`, so setup.exe and the uninstaller it installs are both signed (signing the CI-built
   setup.exe afterwards would leave the uninstaller unsigned), and rewrites its `.sha256`;
6. replaces the four files in the release (`gh release upload --clobber`) and, with `-Publish`, publishes the draft
   and replaces the "being signed" line of the notes. Without `-Publish` the release stays a draft for you to check.

It prints a table of every file with its signer and timestamp. All work happens in `%TEMP%\lumina-sign-<tag>`
(`-WorkDir`), which each run starts again from the downloaded originals, so a run can simply be repeated.
`-TimestampUrl` changes the timestamp server (default Certum's `http://time.certum.pl`). Offline,
`-FromDir <folder>` takes the four files from a folder and writes the signed ones to `-OutDir` (default
`<folder>\signed`) without touching GitHub. `tool/release/sign_windows_release_test.ps1 -FromDir <folder> -Tag <tag>`
runs the offline mode end to end with a throwaway self-signed certificate (`-AllowUntrustedForTest`) and removes the
certificate afterwards.

Re-running the release workflow for a tag whose release exists replaces the Windows assets with unsigned builds
again; in this mode it also turns the release back into a draft, so run the script again. Tags whose installer
sources predate signed setup builds need `-InstallerSourceRef <commit>`.

A new certificate has no SmartScreen reputation yet: Windows may still warn about the first signed downloads, and
the warning fades as signed downloads accumulate. The MSIX is signed separately, in CI (above).

## Linux: .deb and .rpm

The editor and the libc++ it builds projects with need glibc 2.38 or newer (Ubuntu 24.04, Debian 13, Fedora 39 or later). The package declares the build and run dependencies:

| Debian / Ubuntu | Fedora / RHEL | Why |
|---|---|---|
| `git`, `curl`, `ca-certificates`, `tar`, `unzip`, `xz-utils`, `zip` | same (`xz`) | Flutter, downloads |
| `clang`, `cmake`, `ninja-build`, `pkg-config` | `clang`, `cmake`, `ninja-build`, `pkgconf-pkg-config` | `flutter build linux`, native-assets hooks |
| `libgtk-3-dev`, `liblzma-dev`, `libstdc++-1{4,3,2}-dev` | `gtk3-devel`, `xz-devel`, `libstdc++-devel` | the Flutter Linux runner |
| `libwayland-dev`, `wayland-protocols` | `wayland-devel`, `wayland-protocols-devel` | pointer capture (Wayland) |
| `libgstreamer1.0-0`, `gstreamer1.0-plugins-base`, `gstreamer1.0-plugins-good`, `gstreamer1.0-tools` | `gstreamer1`, `gstreamer1-plugins-base`, `gstreamer1-plugins-good`, `gstreamer1-plugins-base-tools` | video recording |
| `libgl1`, `libvulkan1` | `libglvnd-glx`, `vulkan-loader` | the renderer's OpenGL / Vulkan backends |

The package installs:

- `/usr/bin/lumina-studio`: the launcher. It puts `/opt/lumina/flutter/bin` first on PATH and starts the editor.
  When the editor is missing, it downloads it first. `lumina-studio --update` downloads the latest release.
- `/usr/lib/lumina-studio/install-studio.sh`: downloads and verifies the Linux tarball, then swaps it in.
- `/usr/share/applications/io.github.luminagame.LuminaStudio.desktop`: the menu entry, with an "Update Lumina Studio" action.
- `/usr/share/icons/hicolor/scalable/apps/lumina-studio.svg` and `/usr/share/pixmaps/lumina-studio.png`: the
  `lumina_ui/assets/app_icon.png` icon (the Lumina emblem).

The postinstall script:

1. Creates the `lumina` system group. `/opt/lumina` belongs to it (setgid, group-writable), and the user who ran
   `sudo` / `pkexec` joins it; the membership takes effect at the next login. Group members can update the editor
   and use the shared Flutter SDK.
2. Keeps a Flutter already in `/opt/lumina/flutter` or on PATH. Otherwise it clones the stable channel into
   `/opt/lumina/flutter`, adds a `safe.directory` entry to the system git config, runs `flutter precache --linux`
   and hands the tree to the group.
3. Downloads the latest `lumina-studio-<tag>-linux-<x64|arm64>.tar.gz` (the machine's architecture) (see "Latest" above) into `/opt/lumina/studio`.
4. Warns when `clang` is older than 19. The engine's native code builds against the libc++ 21 headers it
   bundles; on older distributions install a newer clang from <https://apt.llvm.org>.

Network problems never fail the installation. When GitHub cannot be reached, the script says so, and the
launcher downloads the editor on its first run. `LUMINA_SKIP_DOWNLOAD=1` skips all downloads. A user who cannot
write `/opt/lumina` gets the editor in `~/.local/share/lumina/studio`.

On removal (`apt remove`, `dnf remove`, but not on upgrade) the package deletes `/opt/lumina/studio`, and also
`/opt/lumina/flutter` and its `safe.directory` entry when the package installed them. Purging (deb) or erasing
(rpm) also removes the `lumina` group. Per-user downloads in `~/.local/share/lumina` stay.

### Build locally

```bash
installer/linux/build.sh 0.1.0 v0.1.0 dist    # uses nfpm from PATH or downloads nfpm 2.47.0 into build/nfpm/
dpkg-deb -I dist/lumina-studio_0.1.0-1_amd64.deb
dpkg-deb -c dist/lumina-studio_0.1.0-1_amd64.deb
```

On Windows run it inside WSL. Pre-release versions follow nfpm's semver rules (`0.1.0-beta.1` becomes
`0.1.0~beta.1` in the .deb).

## macOS: .pkg (not verified)

`macos/build-pkg.sh <version> [<tag>] [<out-dir>]` builds a `.pkg` whose payload is only the
`/usr/local/bin/lumina-studio` launcher and a download script. Its postinstall script:

1. checks the Xcode Command Line Tools and starts their installer when they are missing;
2. installs `git cmake ninja gstreamer` with Homebrew as the logged-in user, or prints the command when Homebrew is
   missing;
3. clones Flutter (stable) into `/opt/lumina/flutter` unless one is on PATH;
4. downloads the latest `lumina-studio-<tag>-macos-*.zip` into `/Applications/Lumina Studio.app`.

`LUMINA_PKG_SIGN_IDENTITY` signs the product with a Developer ID Installer identity. The release workflow's
macOS job is disabled (`if: false`) because no macOS build has been verified yet. Its comment lists what is
missing.

## GitHub configuration

| Name | Kind | Used for |
|---|---|---|
| `LUMINA_MSIX_PUBLISHER` | secret | MSIX: the certificate subject, which must equal the package publisher |
| `LUMINA_MSIX_CERT_BASE64` | secret | MSIX: the code-signing `.pfx`, base64-encoded |
| `LUMINA_MSIX_CERT_PASSWORD` | secret | MSIX: the `.pfx` password |
| `LUMINA_MSIX_TIMESTAMP_URL` | variable (optional) | MSIX: RFC 3161 timestamp server |
| `LUMINA_WINDOWS_SIGNING` | variable (optional) | `local`: releases are created as drafts, and the Windows zip and setup are signed with `tool/release/sign_windows_release.ps1` (above) |

Everything else uses the workflow's own `GITHUB_TOKEN`. Only the `release` job gets `contents: write`.
