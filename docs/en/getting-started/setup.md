[Türkçe](../../tr/getting-started/setup.md)

# Checkout and setup

How to lay out the Lumina repositories side by side, resolve the pub workspace, point the native-assets hooks at Filament and build the prebuilt Filament libraries.

## Checkout layout

The Lumina repositories are meant to be checked out side by side:

```
<dir>/
  lumina/        https://github.com/LuminaGame/lumina
  tools/         https://github.com/LuminaGame/tools
  plugins/       https://github.com/LuminaGame/plugins
  marketplace/   https://github.com/LuminaGame/marketplace
  filament/      patched Filament v1.77.2 with its prebuilt out/ folders
  test-assets/   https://github.com/LuminaGame/test-assets (optional, Git LFS)
```

Inside the `lumina` checkout, `filament/` and `test-assets/` are gitignored links to the shared folders:

```bash
git clone https://github.com/LuminaGame/lumina.git
cd lumina
ln -s ../filament filament            # Windows: mklink /J filament ..\filament
ln -s ../test-assets test-assets      # optional; Windows: mklink /J test-assets ..\test-assets
```

## Resolve the workspace

The repository is one Dart pub workspace, so a single command at the root resolves every package:

```bash
dart pub get
```

The packages from the tools, plugins and marketplace repositories are git dependencies. To work against your sibling checkouts instead, create a gitignored `pubspec_overrides.yaml` at the root with `dependency_overrides:` that point at `../tools/...`, `../plugins/...` and `../marketplace/shared` (the full list is on the [repository map](../overview/repositories.md#how-the-repositories-depend-on-each-other)), then run `dart pub get` again.

## Native-assets hook settings

The hooks read their paths from `hooks: user_defines:` in the workspace root `pubspec.yaml` (paths are relative to that file). This repository sets:

```yaml
hooks:
  user_defines:
    flutter_filament:
      filament_dir: filament
    flutter_assimp:
      filament_dir: filament
      libcxx_dir: flutter_filament/third_party/libcxx
    flutter_riglogic:
      riglogic_lib_dir: openriglogic/lib
      libcxx_dir: flutter_filament/third_party/libcxx
```

| Setting | Package | Environment override | Default |
|---|---|---|---|
| `filament_dir` | `flutter_filament`, `flutter_assimp` | `LUMINA_FILAMENT_DIR` | `<package>/../filament` |
| `libcxx_dir` (Linux) | `flutter_assimp`, `flutter_riglogic` | `LUMINA_LIBCXX_DIR` | `<package>/../../lumina/flutter_filament/third_party/libcxx` |
| `riglogic_lib_dir` | `flutter_riglogic` | `LUMINA_RIGLOGIC_LIB_DIR` | `<package>/third_party/openriglogic/lib` (also when the user-define's folder has no library) |

A package resolved from git lives in the pub cache and has no Filament next to it; the user-defines tell its hook where this repository's `filament/` link is. The environment overrides only reach a hook that is run directly: the Flutter/Dart hooks runner does not forward `LUMINA_*` variables.

`flutter_filament/hook/build.dart` is the authoritative list of include paths, compiler flags and linked Filament libraries. Because it declares the static libraries as hook dependencies, rebuilding one of them relinks every consumer on the next `flutter test` or `flutter run`.

## Build Filament

The hooks expect the static libraries in `filament/out/cmake-release/` (Linux and macOS) or `filament/out/cmake-release-windows/` (Windows). Lumina uses upstream Filament v1.77.2 with four local patches, kept in `third_party/filament/patches/` and explained in `third_party/filament/README.md`:

- a bounds fix in the bundled `libassimp`;
- a `RenderPass.cpp` change that keeps skinned and morphed renderables out of the screen-space reflections pass (without it the Vulkan backend loses the device);
- a `third_party/libwebp/tnt` change so that a WebAssembly build with WebP textures configures without SDL2;
- per-pixel motion vectors from the structure pass (`TemporalAntiAliasingOptions::motionVectors`), consumed by TAA and exportable through `View::setMotionVectorTexture`.

### Prebuilt archive

The quickest way to get Filament is the prebuilt archive. `tool/filament/VERSION` names it (for example `1.77.2-lumina.1`), and each version is published once, in its own GitHub release `filament-<VERSION>` (for example [`filament-1.77.2-lumina.1`](https://github.com/LuminaGame/lumina/releases/tag/filament-1.77.2-lumina.1)): `filament-<VERSION>-windows-x64.zip` and `filament-<VERSION>-linux-x64.tar.gz`, each with a `.sha256` file. That release is a pre-release that is never marked Latest, its notes list the upstream tag and the patches, and its assets never change; a new build gets a new version. Lumina releases up to v0.0.1-dev.6 attached the archives to their own release instead, and still carry them. The archive holds one folder that works as `filament_dir`: the headers, sources and static libraries the hooks read (listed in `tool/filament/prebuilt_manifest.txt`), `matc`, the patches and a `lumina-filament.json` describing the build.

Download, verify and unpack it with:

```bash
dart run tool/filament/fetch_prebuilt.dart
```

It downloads from the `filament-<VERSION>` release; `--tag <lumina release tag>` names a release to try when that one has no such asset (an older Lumina release that attached Filament itself). `--base-url`, `LUMINA_FILAMENT_BASE_URL` or `LUMINA_RELEASE_BASE_URL` point it at a mirror laid out like the GitHub release downloads. It prints the unpacked folder (by default `build/filament-prebuilt/cache/<VERSION>`). Link it as `filament`, or point `filament_dir` at it:

```bash
ln -s "$(dart run tool/filament/fetch_prebuilt.dart)" filament   # Windows: mklink /J filament <folder>
```

To build the archive yourself from upstream Filament and the patches:

```bash
tool/filament/build_prebuilt.sh                                               # Linux: clang 19+, CMake, Ninja
powershell -ExecutionPolicy Bypass -File tool\filament\build_prebuilt.ps1   # Windows: Visual Studio 2022, Python 3
```

Both clone Filament at the tag into `build/filament-src` (or the folder given as argument), apply the patches, build only the libraries the hooks link plus `matc`, and write the archive to `build/filament-prebuilt/`. The first build takes about an hour; later runs are incremental. A built `build/filament-src` is also a complete Filament checkout that `filament_dir` can point at. After changing a hook, run `dart tool/filament/prebuilt_manifest.dart` to update the manifest; after changing a patch or the build flags, bump the suffix in `tool/filament/VERSION`.

### Building in a Filament checkout

**Linux / macOS**, in the Filament checkout:

```bash
./build.sh -p desktop release
```

On Linux the system clang may ship without libc++ headers. In that case configure both `out/cmake-release` and `out/prebuilt-tools-release` with the libc++ bundled in `flutter_filament/third_party/libcxx`: add `-nostdinc++ -isystem <libcxx>/usr/lib/llvm-21/include/c++/v1 -isystem <libcxx>/usr/lib/llvm-21/include` to `CMAKE_CXX_FLAGS` and `-L<libcxx>/usr/lib/x86_64-linux-gnu` to the linker flags. A single library can be rebuilt with `ninja -C out/cmake-release filament`.

**Windows**, from the `lumina` checkout (needs Visual Studio 2022 with the C++ workload and Python 3):

```bat
flutter_filament\tool\build_filament_windows.bat            :: configure (first run) and build
flutter_filament\tool\build_filament_windows.bat filament   :: rebuild one target
```

It builds `filament/out/cmake-release-windows/` with the static CRT (`/MT`), the same feature set as the Linux build.

**Web**: `flutter_filament/tool/web/build_host_tools.sh` builds Filament's host tools, `flutter_filament/tool/web/build_filament_web.sh` builds Filament for WebAssembly into `filament/out/cmake-wasm-release`, and `flutter_filament/tool/web/build_module.sh` links `flutter_filament/web/flutter_filament.{js,wasm}`. The scripts need a Filament source tree (`LUMINA_FILAMENT_SRC`, or the `filament` link when it is a full checkout), not the pruned prebuilt. CI builds the module too (`.github/actions/filament-web`): the `web` job of `ci.yml` tests it in headless Chrome, and every release attaches it as `flutter-filament-web-<tag>.zip`. See `flutter_filament/tool/web/README.md`.

## Build OpenRigLogic

`flutter_riglogic` links a static OpenRigLogic library built in the tools checkout:

```bash
bash ../tools/flutter_riglogic/tool/build_openriglogic.sh      # Linux
..\tools\flutter_riglogic\tool\build_openriglogic.bat          # Windows
```

With the `pubspec_overrides.yaml` above, the hook finds the library in the tools checkout: the root pubspec's `riglogic_lib_dir: openriglogic/lib` names a folder that only an installed Lumina Studio's engine checkout has (it links the release's prebuilt library there), and a user-define whose folder holds no library yields to the package's own build. When `flutter_riglogic` is resolved from git in a development checkout, point `riglogic_lib_dir` at `../tools/flutter_riglogic/third_party/openriglogic/lib` instead.

## Compiled materials

`flutter_filament` and `lumina` ship compiled Filament materials (`.filamat`). After changing a material source or the Filament build, rebuild them with each package's `tool/build_materials.sh`: a material that no longer matches the engine is refused at load time, which shows up as a render that draws nothing rather than as a failing test.

## Releases and installation

To use Lumina Studio without building it, install it from the [GitHub releases](https://github.com/LuminaGame/lumina/releases). The installers do not embed the editor. They install what building Lumina projects needs, then download the latest editor build:

| Platform | Installer | Installs |
|---|---|---|
| Windows | `lumina-studio-setup-<tag>-windows-x64.exe` | Git, the Visual Studio 2022 C++ Build Tools and GStreamer (winget), Flutter stable unless one is on PATH, then the editor in `%LOCALAPPDATA%\Programs\Lumina Studio` |
| Linux | `lumina-studio_<version>-1_amd64.deb` / `lumina-studio-<version>-1.x86_64.rpm` | The build dependencies (clang, CMake, Ninja, GTK 3, GStreamer), Flutter in `/opt/lumina/flutter`, the editor in `/opt/lumina/studio`, started with `lumina-studio` |

The Windows setup accepts `/DRYRUN`, which lists what it would install and download without changing anything. Every release also carries the editor on its own (`lumina-studio-<tag>-windows-x64.zip`, `lumina-studio-<tag>-linux-x64.tar.gz`, the unsigned Microsoft Store package `lumina-studio-<tag>-windows-x64-store.msix` for the Partner Center submission, and a signed MSIX when the signing secrets exist) and the prebuilt OpenRigLogic library. Each file has a `.sha256` sidecar. The prebuilt Filament is not attached to Lumina releases: the release notes link the `filament-<VERSION>` release described above, which the editor downloads from at first launch (falling back to its own release's assets, which is where releases up to v0.0.1-dev.6 keep them). The installers' "latest" is the newest Lumina release with the editor for the platform; they never pick a `filament-*` release.

Pushing a `v*` tag that matches the version in `lumina_ui/pubspec.yaml` runs `.github/workflows/release.yml`. It checks the cross-repository pins, makes sure the `filament-<VERSION>` release exists and is complete (building Filament, or restoring it from the cache, only when it is not), builds Lumina Studio for Windows and Linux, flutter_filament's WebAssembly module and the installers, and publishes the release. `installer/README.md` describes each installer, how to build it locally and the signing secrets.

### Signing the Windows release (Certum)

The Windows zip and setup can be Authenticode-signed with a Certum "Open Source Code Signing in the Cloud" certificate. Its key is reachable only through SimplySign Desktop on the maintainer's Windows machine, so CI cannot sign: with the repository variable `LUMINA_WINDOWS_SIGNING=local` the workflow creates the release as a draft whose notes say the Windows assets are being signed, and the maintainer finishes it locally.

One-time setup: order the certificate from Certum, complete Certum's identity validation, install SimplySign Desktop and the SimplySign mobile app, log in (the certificate then appears in the Windows certificate store), and set the repository variable `LUMINA_WINDOWS_SIGNING` to `local`. The machine also needs the Windows SDK signing tools, Inno Setup 6, git and a logged-in GitHub CLI.

For every release, with SimplySign Desktop logged in:

```powershell
powershell -ExecutionPolicy Bypass -File tool\release\sign_windows_release.ps1 -Tag v0.1.0 -CertificateSubject "<subject or CN>" -Publish
```

It signs `lumina_ui.exe` and our DLLs (leaving Microsoft's Visual C++ runtime as it is), re-zips with the same layout, rebuilds the setup so setup.exe and its uninstaller are signed, rewrites the `.sha256` files, uploads the replacements and publishes the draft. `-DryRun` shows the plan first, and `-FromDir` / `-OutDir` sign a folder offline. A new certificate builds SmartScreen reputation as signed downloads accumulate, so early downloads may still show a warning. `installer/README.md` has the details.

---

[Previous: Requirements](requirements.md) | [Up: Lumina documentation](../../README.md) | [Next: Running the editor and tests](running.md)
