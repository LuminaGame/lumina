// ignore_for_file: avoid_print

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

import 'dlss_sdk_dependencies.dart';
import 'native_library_cache.dart';
import 'windows_cl_response.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    final packageName = input.packageName;
    final targetOS = input.config.code.targetOS;
    // The Filament build this platform links (and takes generated headers
    // from): the MSVC one lives beside the Linux one.
    final filamentOut =
        targetOS == OS.windows ? 'cmake-release-windows' : 'cmake-release';
    // Filament's checkout: `../filament` from the package root unless
    // LUMINA_FILAMENT_DIR or the `filament_dir` user-define says otherwise
    // (see filamentDir). Relative when it is the default, so the paths and
    // the native library cache key stay what they were.
    final filament = filamentDir(input);
    // cl.exe runs in the hook's output directory, so the Windows link inputs
    // are absolute paths (the Linux/macOS relative ones resolve against the
    // package root, where clang runs).
    String windowsLib(String path) => input.packageRoot
        .resolveUri(Uri.file('$filament/out/$filamentOut/$path'))
        .toFilePath();

    // The bundled libc++ (third_party/libcxx) carries static libraries per
    // Linux architecture: x86_64-linux-gnu and aarch64-linux-gnu.
    final linuxTriplet = targetOS != OS.linux
        ? null
        : switch (input.config.code.targetArchitecture) {
            Architecture.x64 => 'x86_64-linux-gnu',
            Architecture.arm64 => 'aarch64-linux-gnu',
            final other => throw UnsupportedError('Unsupported Linux architecture: $other'),
          };

    final String? androidAbi;
    final List<String> androidLibs;
    if (targetOS == OS.android) {
      switch (input.config.code.targetArchitecture) {
        case Architecture.arm64:
          androidAbi = 'arm64-v8a';
        case Architecture.x64:
          androidAbi = 'x86_64';
        case Architecture.arm:
          androidAbi = 'armeabi-v7a';
        default:
          throw UnsupportedError(
              'Unsupported Android architecture: ${input.config.code.targetArchitecture}');
      }
      final androidLibDir = '$filament/out/android-release/filament/lib/$androidAbi';
      final libDir = Directory(input.packageRoot.resolveUri(Uri.file(androidLibDir)).toFilePath());
      if (!libDir.existsSync()) {
        throw StateError(
            'Filament Android libraries for $androidAbi not found at ${libDir.path}.\n'
            'Build them with flutter_filament/tool/build_filament_android.bat first.');
      }
      androidLibs = [
        for (final lib in androidFilamentLibs) '$androidLibDir/$lib',
      ];
    } else {
      androidAbi = null;
      androidLibs = const <String>[];
    }
    // The Filament version the wrapper is built against, from the
    // file Filament's bump-version.sh treats as primary.
    final gradleProperties = input.packageRoot.resolveUri(Uri.file('$filament/android/gradle.properties'));
    final filamentVersion = RegExp(r'^VERSION_NAME=(.+)$', multiLine: true)
        .firstMatch(File.fromUri(gradleProperties).readAsStringSync())
        ?.group(1)
        ?.trim();
    if (filamentVersion == null || filamentVersion.isEmpty) {
      throw StateError('No VERSION_NAME in ${gradleProperties.toFilePath()}: cannot stamp the Filament version');
    }
    final sources = [
        'src/engine_c.cpp',
        'src/gpu_c.cpp',
        'src/gpu_engine_c.cpp',
        'src/view_c.cpp',
        'src/geometry_c.cpp',
        'src/lighting_c.cpp',
        'src/gltf_c.cpp',
        'src/manipulator_c.cpp',
        'src/filamat_c.cpp',
        'src/matc_c.cpp',
        'src/tools_c.cpp',
        'src/buffer_descriptor_c.cpp',
        'src/callback_bridge_c.cpp',
        'src/enum_check_c.cpp',
        'src/math_abi_c.cpp',
        'src/instance_c.cpp',
        'src/texture_sampler_c.cpp',
        'src/texture_c.cpp',
        'src/vertex_buffer_c.cpp',
        'src/buffer_object_c.cpp',
        'src/skinning_buffer_c.cpp',
        'src/index_buffer_c.cpp',
        'src/material_c.cpp',
        'src/material_instance_c.cpp',
        'src/utils_c.cpp',
        'src/tangent_space_mesh_c.cpp',
        'src/filamesh_c.cpp',
        'src/ktx2_reader_c.cpp',
        'src/ktx1_c.cpp',
        'src/iblprefilter_c.cpp',
        'src/color_grading_c.cpp',
        'src/camera_c.cpp',
        'src/renderer_c.cpp',
        'src/swap_chain_c.cpp',
        'src/fence_c.cpp',
        'src/frame_pacer_c.cpp',
        'src/debug_registry_c.cpp',
        'src/morph_target_buffer_c.cpp',
        'src/instance_buffer_c.cpp',
        'src/linear_image_c.cpp',
        'src/image_sampler_c.cpp',
        'src/dlss_c.cpp',
        'src/ray_tracing_c.cpp',
        'src/restir_c.cpp',
        'src/image_ops_c.cpp',
        'src/color_transform_c.cpp',
        'src/image_sdf_c.cpp',
        'src/imageio_c.cpp',
        'src/ibl_cubemap_c.cpp',
        'src/ibl_sh_c.cpp',
        'src/ibl_bake_c.cpp',
        'src/web_c.cpp',
        'src/web_stubs_c.cpp',
        '$filament/third_party/smol-v/source/smolv.cpp',
        // Filament's .mat parser (matc's matp library), vendored: the
        // prebuilt Filament archives carry no matp (third_party/filament_matp/README.md).
        for (final matp in _matpSources) 'third_party/filament_matp/src/$matp',
    ];
    final includes = [
        'src',
        // The vendored copy under `third_party/filament/include` used to sit
        // here, ahead of the real headers, and it is a stale snapshot: its
        // MATERIAL_VERSION says 75 where the engine these libraries were built
        // from says 77, and Engine.h, Texture.h, LightManager.h,
        // RenderableManager.h and VertexBuffer.h all differ too. Compiling
        // against it while linking libraries built from the other one is an ABI
        // mismatch, and it is what made runtime material compilation fail.
        // Everything now compiles against the same source the
        // static libraries came from.
        // External Filament repository source & library include paths
        '$filament/filament/include',
        // The backend headers the vendored copy used to supply.
        '$filament/filament/backend/include',
        '$filament/libs/filabridge/include',
        '$filament/libs/bluevk/include',
        '$filament/libs/gltfio/include',
        '$filament/libs/geometry/include',
        '$filament/libs/filamat/include',
        '$filament/libs/camutils/include',
        '$filament/libs/utils/include',
        '$filament/libs/math/include',
        '$filament/libs/matdbg/include',
        '$filament/libs/filameshio/include',
        '$filament/libs/ktxreader/include',
        '$filament/libs/iblprefilter/include',
        '$filament/libs/image/include',
        '$filament/libs/imageio/include',
        '$filament/libs/ibl/include',
        '$filament/third_party/smol-v/source',
        '$filament/third_party/stb',
        '$filament/out/$filamentOut/samples/generated/resources',
        '$filament/out/$filamentOut/libs',
        '$filament/libs/filaflat/include',
        '$filament/third_party/zstd/lib',
        '$filament/third_party/robin-map/include',
        '$filament/third_party/draco/src',
        '$filament/third_party/draco/tnt',
        '$filament/third_party/cgltf',
        'third_party/filament_matp/include',
        'third_party/filament_matp/src',
    ];
    // On Windows the sources, includes and Filament libraries go to a
    // response file; cl runs through cmd.exe, whose command line holds 8 191
    // characters, and a long package root (a project's editor copy) passes it.
    // The fetched NGX SDK, when present: its headers join the includes and its
    // static entry-point library the link inputs (desktop Vulkan targets only).
    final dlssSdk = _dlssSdkDir(input, targetOS);
    if (dlssSdk != null) {
      includes.add('build/dlss-sdk/include');
    }
    final isWindows = targetOS == OS.windows;
    final windowsLibs = isWindows
        ? [
            for (final lib in _windowsFilamentLibs) windowsLib(lib),
            if (dlssSdk != null) '$dlssSdk/lib/Windows_x86_64/x64/nvsdk_ngx_s.lib',
          ]
        : const <String>[];
    String abs(String rel) => input.packageRoot.resolveUri(Uri.file(rel)).toFilePath();
    final responseFile = input.outputDirectory.resolve('${packageName}_cl.rsp').toFilePath();
    if (isWindows) {
      Directory.fromUri(input.outputDirectory).createSync(recursive: true);
      File(responseFile).writeAsStringSync(windowsClResponse(
        includes: [for (final i in includes) abs(i)],
        sources: [for (final s in sources) abs(s)],
        libraries: windowsLibs,
      ));
    }
    final cbuilder = CBuilder.library(
      name: packageName,
      assetName: 'src/third_party/filament_c.g.dart',
      sources: isWindows ? const [] : sources,
      includes: isWindows ? const [] : includes,
      flags: [
        if (targetOS == OS.windows) ...[
          // MSVC, matching the Filament Windows build (out/cmake-release-windows:
          // cl, /MT static CRT, C++ exceptions on).
          '/std:c++20',
          '/EHsc',
          '/Zc:__cplusplus',
          '/utf-8',
          '/bigobj',
          '/W0',
          '/MT',
          // CMake adds these to every MSVC build; Filament's headers test
          // `WIN32` (not `_WIN32`) for memalign and the JobSystem layout.
          '/DWIN32',
          '/D_WINDOWS',
          '/D_USE_MATH_DEFINES=1',
          '/DNOMINMAX',
          '/DWIN32_LEAN_AND_MEAN',
          '/D_CRT_SECURE_NO_WARNINGS',
          '/D_CRT_NONSTDC_NO_DEPRECATE',
          windowsClResponseFlag(responseFile),
        ] else ...[
          '-std=c++20',
          '-fexceptions',
          '-fno-rtti',
          '-Wno-deprecated-declarations',
        ],
        if (targetOS == OS.macOS) ...[
          '$filament/out/cmake-release/filament/libfilament.a',
          '$filament/out/cmake-release/filament/backend/libbackend.a',
          '$filament/out/cmake-release/libs/utils/libutils.a',
          '$filament/out/cmake-release/libs/gltfio/libgltfio.a',
          '$filament/out/cmake-release/libs/gltfio/libuberarchive.a',
          '$filament/out/cmake-release/libs/filabridge/libfilabridge.a',
          '$filament/out/cmake-release/libs/filamat/libfilamat.a',
          '$filament/out/cmake-release/libs/camutils/libcamutils.a',
          '$filament/out/cmake-release/libs/matdbg/libmatdbg.a',
          '$filament/out/cmake-release/libs/matdbg/libmatdbg_resources.a',
          '$filament/out/cmake-release/third_party/civetweb/tnt/libcivetweb.a',
          '$filament/out/cmake-release/third_party/abseil/tnt/libfilament-abseil.a',
          '$filament/out/cmake-release/shaders/libshaders.a',
          '$filament/out/cmake-release/libs/bluegl/libbluegl.a',
          '$filament/out/cmake-release/libs/bluevk/libbluevk.a',
          '$filament/out/cmake-release/libs/geometry/libgeometry.a',
          '$filament/out/cmake-release/third_party/draco/tnt/libdracodec.a',
          '$filament/out/cmake-release/third_party/basisu/tnt/libbasis_transcoder.a',
          '$filament/out/cmake-release/third_party/meshoptimizer/tnt/libmeshoptimizer.a',
          '$filament/out/cmake-release/third_party/mikktspace/libmikktspace.a',
          '$filament/out/cmake-release/libs/filameshio/libfilameshio.a',
          '$filament/out/cmake-release/samples/libsuzanne-resources.a',
          '$filament/out/cmake-release/samples/libsample-resources.a',
          '$filament/out/cmake-release/libs/filaflat/libfilaflat.a',
          '$filament/out/cmake-release/libs/gltfio/libgltfio_core.a',
          '$filament/out/cmake-release/third_party/spirv-cross/tnt/libspirv-cross-glsl.a',
          '$filament/out/cmake-release/third_party/spirv-cross/tnt/libspirv-cross-core.a',
          '$filament/out/cmake-release/third_party/spirv-cross/tnt/libspirv-cross-msl.a',
          '$filament/out/cmake-release/third_party/spirv-tools/source/libSPIRV-Tools.a',
          '$filament/out/cmake-release/third_party/spirv-tools/source/opt/libSPIRV-Tools-opt.a',
          '$filament/out/cmake-release/third_party/glslang/tnt/glslang/libglslang.a',
          '$filament/out/cmake-release/third_party/glslang/tnt/SPIRV/libSPIRV.a',
          '$filament/out/cmake-release/third_party/glslang/tnt/glslang/OSDependent/Unix/libOSDependent.a',
          '$filament/out/cmake-release/third_party/smol-v/tnt/libsmol-v.a',
          '$filament/out/cmake-release/third_party/zstd/tnt/libzstd.a',
          '$filament/out/cmake-release/libs/image/libimage.a',
          '$filament/out/cmake-release/libs/imageio/libimageio.a',
          '$filament/out/cmake-release/libs/ibl/libibl.a',
          '$filament/out/cmake-release/libs/ktxreader/libktxreader.a',
          '$filament/out/cmake-release/libs/iblprefilter/libfilament-iblprefilter.a',
          '$filament/out/cmake-release/third_party/libwebp/libwebpdecoder.a',
          '$filament/out/cmake-release/third_party/stb/tnt/libstb.a',
          '$filament/out/cmake-release/third_party/basisu/tnt/libbasis_encoder.a',
          '-framework', 'Cocoa',
          '-framework', 'Metal',
          '-framework', 'QuartzCore',
          '-framework', 'CoreVideo',
          '-framework', 'OpenGL',
          '-lpng',
          '-lz',
          '-lc++',
          '-lc++abi',
        ] else if (targetOS == OS.android) ...[
          '-Wl,--whole-archive',
          ...androidLibs,
          '-Wl,--no-whole-archive',
          '-llog',
          '-landroid',
          '-lEGL',
          '-lGLESv3',
          '-lm',
          '-ldl',
        ] else if (targetOS == OS.linux) ...[
          '-nostdinc++',
          '-isystem', 'third_party/libcxx/usr/lib/llvm-21/include/c++/v1',
          '-isystem', 'third_party/libcxx/usr/lib/llvm-21/include',
          '-Wl,--whole-archive',
          '$filament/out/cmake-release/filament/libfilament.a',
          '$filament/out/cmake-release/filament/backend/libbackend.a',
          '$filament/out/cmake-release/libs/utils/libutils.a',
          '$filament/out/cmake-release/libs/gltfio/libgltfio.a',
          '$filament/out/cmake-release/libs/gltfio/libuberarchive.a',
          '$filament/out/cmake-release/libs/filabridge/libfilabridge.a',
          '$filament/out/cmake-release/libs/filamat/libfilamat.a',
          '$filament/out/cmake-release/libs/camutils/libcamutils.a',
          '$filament/out/cmake-release/libs/matdbg/libmatdbg.a',
          '$filament/out/cmake-release/libs/matdbg/libmatdbg_resources.a',
          '$filament/out/cmake-release/third_party/civetweb/tnt/libcivetweb.a',
          '$filament/out/cmake-release/third_party/abseil/tnt/libfilament-abseil.a',
          '$filament/out/cmake-release/shaders/libshaders.a',
          '$filament/out/cmake-release/libs/bluegl/libbluegl.a',
          '$filament/out/cmake-release/libs/bluevk/libbluevk.a',
          '$filament/out/cmake-release/libs/geometry/libgeometry.a',
          '$filament/out/cmake-release/third_party/draco/tnt/libdracodec.a',
          '$filament/out/cmake-release/third_party/basisu/tnt/libbasis_transcoder.a',
          '$filament/out/cmake-release/third_party/basisu/tnt/libbasis_encoder.a',
          '$filament/out/cmake-release/third_party/meshoptimizer/tnt/libmeshoptimizer.a',
          '$filament/out/cmake-release/third_party/mikktspace/libmikktspace.a',
          '$filament/out/cmake-release/libs/filameshio/libfilameshio.a',
          '$filament/out/cmake-release/samples/libsuzanne-resources.a',
          '$filament/out/cmake-release/samples/libsample-resources.a',
          '$filament/out/cmake-release/libs/filaflat/libfilaflat.a',
          '$filament/out/cmake-release/libs/gltfio/libgltfio_core.a',
          '$filament/out/cmake-release/third_party/spirv-cross/tnt/libspirv-cross-glsl.a',
          '$filament/out/cmake-release/third_party/spirv-cross/tnt/libspirv-cross-core.a',
          '$filament/out/cmake-release/third_party/spirv-cross/tnt/libspirv-cross-msl.a',
          '$filament/out/cmake-release/third_party/spirv-tools/source/libSPIRV-Tools.a',
          '$filament/out/cmake-release/third_party/spirv-tools/source/opt/libSPIRV-Tools-opt.a',
          '$filament/out/cmake-release/third_party/glslang/tnt/glslang/libglslang.a',
          '$filament/out/cmake-release/third_party/glslang/tnt/SPIRV/libSPIRV.a',
          '$filament/out/cmake-release/third_party/glslang/tnt/glslang/OSDependent/Unix/libOSDependent.a',
          '$filament/out/cmake-release/third_party/zstd/tnt/libzstd.a',
          '$filament/out/cmake-release/libs/image/libimage.a',
          '$filament/out/cmake-release/libs/imageio/libimageio.a',
          '$filament/out/cmake-release/libs/ibl/libibl.a',
          '$filament/out/cmake-release/libs/ktxreader/libktxreader.a',
          '$filament/out/cmake-release/libs/iblprefilter/libfilament-iblprefilter.a',
          '$filament/out/cmake-release/libs/uberz/libuberzlib.a',
          '$filament/out/cmake-release/third_party/libwebp/libwebpdecoder.a',
          '$filament/out/cmake-release/third_party/stb/tnt/libstb.a',
          '-Wl,--no-whole-archive',
          if (dlssSdk != null) '$dlssSdk/lib/Linux_x86_64/libnvsdk_ngx.a',
          'third_party/libcxx/usr/lib/$linuxTriplet/libc++.a',
          'third_party/libcxx/usr/lib/$linuxTriplet/libc++abi.a',
          '-lpng',
          '-lz',
          '-lGL',
          '-lEGL',
          '-lX11',
          '-ldl',
          '-lpthread',
        ],
      ],
      // Unquoted: engine_c.cpp stringizes it. A quoted value breaks on
      // Windows, where cl runs through cmd and the embedded quotes end its
      // quoting ('C:\Program' is not recognized…).
      defines: {
        'FLUTTER_FILAMENT_FILAMENT_VERSION': filamentVersion,
        // DLSS: only when tool/dlss/fetch_sdk.dart filled build/dlss-sdk/ (the NGX SDK is
        // NVIDIA-licensed and never committed); a checkout without it builds as before.
        // (The folder itself is found at run time: LUMINA_DLSS_DIR, the executable's
        // folder or build/dlss-sdk under the working directory; a quoted path define
        // would break cl's command line.)
        if (dlssSdk != null) 'FLUTTER_FILAMENT_DLSS': '1',
      },
      libraries: [
        if (targetOS == OS.windows) ..._windowsSystemLibs,
      ],
      cppLinkStdLib: targetOS == OS.macOS ? 'c++' : (targetOS == OS.android ? 'c++_static' : null),
    );
    // A machine-wide cache of the built library, keyed
    // by the very lists the CBuilder above compiles with.
    // The same dependencies CBuilder.run declares for its sources and
    // include dirs.
    List<Uri> sourceDependencies() => [
          for (final s in sources) input.packageRoot.resolveUri(Uri.file(s)),
          for (final include in includes)
            for (final f in Directory.fromUri(input.packageRoot.resolveUri(Uri.file(include)))
                .listSync(recursive: true)
                .whereType<File>())
              f.uri,
        ];
    final cache = NativeLibraryCache();
    final cacheOn = cache.enabled();
    final libName = targetOS.libraryFileName(packageName, DynamicLoadingBundled());
    final outLib = input.outputDirectory.resolve(libName);
    final key = cacheOn ? cache.key(_cacheInputs(input, cbuilder, sources: sources, includes: includes, windowsLibs: windowsLibs)) : null;
    final cached = key == null ? null : cache.lookup(packageName, key, libName);
    if (cached != null) {
      // A hit: no compiler runs. The same asset and the same dependencies as
      // CBuilder.run declares, so a changed source still reruns this hook.
      await Directory.fromUri(input.outputDirectory).create(recursive: true);
      await cached.copy(outLib.toFilePath());
      output.assets.code.add(CodeAsset(
        package: packageName,
        name: cbuilder.assetName!,
        linkMode: DynamicLoadingBundled(),
        file: outLib,
      ));
      output.dependencies.addAll(sourceDependencies());
      print('native cache hit $key');
    } else {
      await cbuilder.run(
        input: input,
        output: output,
        logger: Logger('')
          ..level = Level.ALL
          ..onRecord.listen((record) => print(record.message)),
      );
      // On Windows the sources and includes reached cl through the response
      // file, so CBuilder declared none of them.
      if (isWindows) output.dependencies.addAll(sourceDependencies());
      if (key != null) {
        await cache.publish(packageName, key, File.fromUri(outLib));
        print('native cache store $key');
      }
    }

    // The Filament static libraries are link inputs the C builder does not
    // track. Declared here, rebuilding Filament (a local patch, an upgrade)
    // relinks every consumer's cached libflutter_filament; undeclared, each
    // package kept running the engine it first linked.
    output.dependencies.addAll([
      // A VERSION_NAME bump rebuilds the wrapper.
      gradleProperties,
      for (final flag in cbuilder.flags)
        if (flag.endsWith('.a')) input.packageRoot.resolveUri(Uri.file(flag)),
      for (final lib in windowsLibs) Uri.file(lib),
      // The NGX SDK markers, or (while one is missing) the deepest existing
      // folder on its path, build/dlss-sdk created empty if need be: fetching
      // (or deleting) the SDK makes the next build re-run this hook once and
      // compile the DLSS path in or out. Never a missing file: the runner
      // dates one "now" and would re-run the hook on every build.
      ...dlssSdkDependencies(_dlssSdkRoot(input), _dlssSdkMarkers(input, targetOS)),
    ]);
  });
}

/// The files whose presence switches the DLSS build on: the NGX Vulkan header
/// and the platform's static entry-point library.
List<String> _dlssSdkMarkers(BuildInput input, OS targetOS) {
  if (targetOS != OS.windows && targetOS != OS.linux) return const [];
  if (input.config.code.targetArchitecture != Architecture.x64) return const [];
  final dir = _dlssSdkRoot(input);
  return [
    '$dir/include/nvsdk_ngx_vk.h',
    targetOS == OS.windows ? '$dir/lib/Windows_x86_64/x64/nvsdk_ngx_s.lib' : '$dir/lib/Linux_x86_64/libnvsdk_ngx.a',
  ];
}

/// `build/dlss-sdk` under the package root (absolute), where
/// `tool/dlss/fetch_sdk.dart` puts the NGX SDK.
String _dlssSdkRoot(BuildInput input) => input.packageRoot.resolveUri(Uri.file('build/dlss-sdk')).toFilePath();

/// Filament's checkout (patched v1.77.2 with its prebuilt `out/` folders), in
/// order:
/// 1. `LUMINA_FILAMENT_DIR` — reaches the hook only when it runs directly: the
///    hooks runner forwards an allow-list of variables, never `LUMINA_*`;
/// 2. the `filament_dir` user-define in the workspace root pubspec
///    (`hooks: user_defines: flutter_filament: filament_dir: filament`),
///    relative to that pubspec — how a checkout in the pub cache (a git
///    dependency) finds the app's Filament;
/// 3. `../filament`, relative to the package root: the repo's own gitignored
///    `filament/` link.
/// Returned `/`-separated without a trailing slash; the default stays
/// relative.
String filamentDir(BuildInput input) {
  final env = Platform.environment['LUMINA_FILAMENT_DIR'];
  final uri = env != null && env.isNotEmpty ? Uri.directory(env) : input.userDefines.path('filament_dir');
  if (uri == null) return '../filament';
  // A user-define such as `D:/filament` resolves to a URI whose scheme is the
  // drive letter; read it back as that Windows path.
  final path = (uri.scheme.length == 1 ? '${uri.scheme.toUpperCase()}:${uri.path}' : uri.toFilePath())
      .replaceAll(r'\', '/');
  final dir = path.endsWith('/') ? path.substring(0, path.length - 1) : path;
  // The user-define that names the default location keeps the relative form.
  final fallback = input.packageRoot.resolve('../filament').toFilePath().replaceAll(r'\', '/');
  return _samePath(dir, fallback) ? '../filament' : dir;
}

bool _samePath(String a, String b) =>
    Platform.isWindows ? a.toLowerCase() == b.toLowerCase() : a == b;

/// The native library cache key's inputs, from the lists [cbuilder] compiles
/// and links with (so they cannot drift): sources and `src/` headers by
/// content, the static archives by path + size + mtime, the rest verbatim.
/// On Windows [sources], [includes] and [windowsLibs] reach cl through a
/// response file; the key is the same as when they were flags.
NativeBuildInputs _cacheInputs(BuildInput input, CBuilder cbuilder,
    {required List<String> sources, required List<String> includes, required List<String> windowsLibs}) {
  String abs(String rel) => input.packageRoot.resolveUri(Uri.file(rel)).toFilePath();
  bool isArchive(String f) => f.endsWith('.a') || f.endsWith('.lib');
  final code = input.config.code;
  return NativeBuildInputs(
    sources: [for (final s in sources) abs(s)],
    headers: [
      for (final f in Directory(abs('src')).listSync().whereType<File>())
        if (f.path.endsWith('.h')) f.path,
      for (final f in Directory(abs('third_party/filament_matp')).listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.h')) f.path,
    ],
    archives: [
      for (final f in cbuilder.flags) if (isArchive(f)) File(f).isAbsolute ? f : abs(f),
      ...windowsLibs,
    ],
    includes: includes,
    defines: cbuilder.defines,
    flags: [for (final f in cbuilder.flags) if (!isArchive(f) && !f.startsWith('@')) f],
    libraries: cbuilder.libraries,
    targetOS: code.targetOS.name,
    targetArchitecture: code.targetArchitecture.name,
    linkMode: code.linkModePreference.name,
    buildMode: cbuilder.buildMode.name,
    compiler: _compilerId(code.targetOS),
  );
}

/// The compiler's identity for the cache key: MSVC's default tools version
/// on Windows, `clang --version` elsewhere.
String _compilerId(OS targetOS) {
  try {
    if (targetOS == OS.windows) {
      final vswhere = '${Platform.environment['ProgramFiles(x86)'] ?? r'C:\Program Files (x86)'}'
          r'\Microsoft Visual Studio\Installer\vswhere.exe';
      final install = (Process.runSync(vswhere, ['-latest', '-products', '*', '-property', 'installationPath']).stdout as String).trim();
      final tools = File('$install\\VC\\Auxiliary\\Build\\Microsoft.VCToolsVersion.default.txt');
      return 'msvc ${tools.existsSync() ? tools.readAsStringSync().trim() : install}';
    }
    final result = Process.runSync('clang', ['--version']);
    return (result.stdout as String).split('\n').first.trim();
  } catch (_) {
    return 'unknown';
  }
}

/// The Filament static libraries the Windows build links, relative to
/// `filament/out/cmake-release-windows/` — the MSVC counterparts of the Linux
/// list above, plus the zlib/libpng/tinyexr Filament builds itself (Linux
/// takes `-lpng -lz` from the system).
const _windowsFilamentLibs = [
  'filament/filament.lib',
  'filament/backend/backend.lib',
  'libs/utils/utils.lib',
  'libs/gltfio/gltfio.lib',
  'libs/gltfio/uberarchive.lib',
  'libs/filabridge/filabridge.lib',
  'libs/filamat/filamat.lib',
  'libs/camutils/camutils.lib',
  'libs/matdbg/matdbg.lib',
  'libs/matdbg/matdbg_resources.lib',
  'third_party/civetweb/tnt/civetweb.lib',
  'third_party/abseil/tnt/filament-abseil.lib',
  'shaders/shaders.lib',
  'libs/bluegl/bluegl.lib',
  'libs/bluevk/bluevk.lib',
  'libs/geometry/geometry.lib',
  'third_party/draco/tnt/dracodec.lib',
  'third_party/basisu/tnt/basis_transcoder.lib',
  'third_party/basisu/tnt/basis_encoder.lib',
  'third_party/meshoptimizer/tnt/meshoptimizer.lib',
  'third_party/mikktspace/mikktspace.lib',
  'libs/filameshio/filameshio.lib',
  'samples/suzanne-resources.lib',
  'samples/sample-resources.lib',
  'libs/filaflat/filaflat.lib',
  'libs/gltfio/gltfio_core.lib',
  'third_party/spirv-cross/tnt/spirv-cross-glsl.lib',
  'third_party/spirv-cross/tnt/spirv-cross-core.lib',
  'third_party/spirv-cross/tnt/spirv-cross-msl.lib',
  'third_party/spirv-tools/source/SPIRV-Tools.lib',
  'third_party/spirv-tools/source/opt/SPIRV-Tools-opt.lib',
  'third_party/glslang/tnt/glslang/glslang.lib',
  'third_party/glslang/tnt/SPIRV/SPIRV.lib',
  'third_party/glslang/tnt/glslang/OSDependent/Windows/OSDependent.lib',
  'third_party/zstd/tnt/zstd.lib',
  'libs/image/image.lib',
  'libs/imageio/imageio.lib',
  'libs/ibl/ibl.lib',
  'libs/ktxreader/ktxreader.lib',
  'libs/iblprefilter/filament-iblprefilter.lib',
  'libs/uberz/uberzlib.lib',
  'third_party/libwebp/libwebpdecoder.lib',
  'third_party/stb/tnt/stb.lib',
  'third_party/tinyexr/tnt/tinyexr.lib',
  'third_party/libpng/tnt/png.lib',
  'third_party/libz/tnt/z.lib',
];

/// The vendored matp sources (`third_party/filament_matp/src/`).
const _matpSources = [
  'DirIncluder.cpp',
  'Includes.cpp',
  'JsonishLexer.cpp',
  'JsonishParser.cpp',
  'MaterialLexer.cpp',
  'MaterialParser.cpp',
  'ParametersProcessor.cpp',
];

/// Win32 import libraries the Filament backends and civetweb need.
const _windowsSystemLibs = [
  'opengl32',
  'gdi32',
  'user32',
  'shell32',
  'shlwapi',
  'advapi32',
  'ole32',
  'ws2_32',
];

/// The static libraries linked on Android, relative to
/// `out/android-release/filament/lib/<abi>/`.
const androidFilamentLibs = [
  'libfilament.a',
  'libbackend.a',
  'libutils.a',
  'libgltfio_core.a',
  'libuberarchive.a',
  'libfilabridge.a',
  'libfilamat.a',
  'libcamutils.a',
  'libabseil.a',
  'libcivetweb.a',
  'libshaders.a',
  'libbluevk.a',
  'libgeometry.a',
  'libdracodec.a',
  'libbasis_transcoder.a',
  'libmeshoptimizer.a',
  'libmikktspace.a',
  'libfilameshio.a',
  'libfilaflat.a',
  'libzstd.a',
  'libimage.a',
  'libibl.a',
  'libktxreader.a',
  'libfilament-iblprefilter.a',
  'libuberzlib.a',
  'libwebpdecoder.a',
  'libstb.a',
  'libsmol-v.a',
];

/// `build/dlss-sdk` (absolute) when `tool/dlss/fetch_sdk.dart` has filled it
/// for this target OS; null otherwise.
String? _dlssSdkDir(BuildInput input, OS targetOS) {
  if (targetOS != OS.windows && targetOS != OS.linux) return null;
  // The NGX SDK ships x64 libraries only.
  if (input.config.code.targetArchitecture != Architecture.x64) return null;
  final dir = _dlssSdkRoot(input);
  final stub = targetOS == OS.windows
      ? '$dir/lib/Windows_x86_64/x64/nvsdk_ngx_s.lib'
      : '$dir/lib/Linux_x86_64/libnvsdk_ngx.a';
  if (!File('$dir/include/nvsdk_ngx_vk.h').existsSync() || !File(stub).existsSync()) return null;
  return dir;
}
