import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../hook/native_inputs.dart' as hook;

/// The NDK's `llvm-nm` (ANDROID_HOME / ANDROID_SDK_ROOT, else the default SDK
/// folder), or null when no NDK is installed.
String? _llvmNm() {
  final env = Platform.environment;
  final sdk = env['ANDROID_HOME'] ??
      env['ANDROID_SDK_ROOT'] ??
      (Platform.isWindows ? '${env['LOCALAPPDATA']}\\Android\\Sdk' : '${env['HOME']}/Android/Sdk');
  final ndkRoot = Directory('$sdk/ndk');
  if (!ndkRoot.existsSync()) return null;
  final ndks = ndkRoot.listSync().whereType<Directory>().toList()..sort((a, b) => b.path.compareTo(a.path));
  final host = Platform.isWindows ? 'windows-x86_64' : (Platform.isMacOS ? 'darwin-x86_64' : 'linux-x86_64');
  for (final ndk in ndks) {
    final nm = File('${ndk.path}/toolchains/llvm/prebuilt/$host/bin/llvm-nm${Platform.isWindows ? '.exe' : ''}');
    if (nm.existsSync()) return nm.path;
  }
  return null;
}

void main() {
  final packageRoot = Directory.current;
  final filamentDir = Directory('${packageRoot.path}/../filament');
  final hookSource = File('${packageRoot.path}/hook/build.dart').readAsStringSync();

  group('Android Filament linking', () {
    test('pubspec declares android platform with ffiPlugin: true', () {
      final pubspec = File('${packageRoot.path}/pubspec.yaml').readAsStringSync();
      expect(pubspec.contains('android:'), isTrue);
      expect(RegExp(r'android:\s+ffiPlugin:\s+true').hasMatch(pubspec), isTrue);
    });

    for (final abi in const ['arm64-v8a', 'x86_64']) {
      test('every Android static library exists for $abi', () {
        final libDir = Directory('${filamentDir.path}/out/android-release/filament/lib/$abi');
        expect(libDir.existsSync(), isTrue,
            reason: 'Filament Android lib dir for $abi must exist at ${libDir.path} '
                '(dart run tool/filament/fetch_prebuilt.dart --android)');

        final missing = [
          for (final lib in hook.androidFilamentLibs)
            if (!File('${libDir.path}/$lib').existsSync()) lib,
        ];
        expect(missing, isEmpty,
            reason: 'All ${hook.androidFilamentLibs.length} Android libraries must exist for $abi, missing: $missing');
      });
    }

    test('the Android libraries are built from the patched Filament', () async {
      final nm = _llvmNm();
      if (nm == null) {
        markTestSkipped('no Android NDK (llvm-nm) on this machine');
        return;
      }
      final lib = '${filamentDir.path}/out/android-release/filament/lib/arm64-v8a/libfilament.a';
      final result = await Process.run(nm, ['-C', lib]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      final symbols = result.stdout as String;
      // One symbol per patch family: the external upscaler pass, ray query
      // scenes, the ray picking hook and ReSTIR options. An unpatched archive
      // has none of them, and the wrapper sources that call them would not link.
      for (final symbol in const [
        'View::setExternalUpscaler',
        'Scene::setRayTracingEnabled',
        'View::traceRay',
        'View::setRestirOptions',
      ]) {
        expect(symbols, contains(symbol), reason: '$lib lacks $symbol: it predates the Lumina patches');
      }
    });

    test('a built Android library exports the C API and leaves no C++ symbol for the device to find', () async {
      // `flutter build apk --target-platform android-arm64` in example/ leaves the
      // stripped library under build/; without one there is nothing to check.
      final nm = _llvmNm();
      final candidates = Directory('example/build/app/intermediates').existsSync()
          ? Directory('example/build/app/intermediates')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.replaceAll('\\', '/').endsWith('arm64-v8a/libflutter_filament.so'))
              .toList()
          : <File>[];
      if (nm == null || candidates.isEmpty) {
        markTestSkipped('no NDK or no Android build of the example');
        return;
      }
      candidates.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      final lib = candidates.first.path;
      final defined = (await Process.run(nm, ['-D', '--defined-only', lib])).stdout as String;
      final undefined = (await Process.run(nm, ['-D', '--undefined-only', lib])).stdout as String;
      expect(defined, contains(' T filament_engine_create\n'));
      // Every function the C headers declare is exported, stub or not.
      final declared = <String>{
        for (final f in Directory('src').listSync(recursive: true).whereType<File>())
          if (f.path.endsWith('.h'))
            for (final m in RegExp(r'FFI_PLUGIN_EXPORT[^(;]*?\b(filament_\w+)\s*\(').allMatches(f.readAsStringSync()))
              m.group(1)!,
      };
      final exported = {for (final m in RegExp(r' T (filament_\w+)').allMatches(defined)) m.group(1)!};
      expect(declared.difference(exported), isEmpty, reason: 'declared but not exported on Android');
      // libc++ and abseil are linked in; an undefined C++ symbol only fails at dlopen on the device.
      final cxx = [for (final m in RegExp(r'^\s+U (_Z\S+)', multiLine: true).allMatches(undefined)) m.group(1)!];
      expect(cxx, isEmpty, reason: '$lib leaves C++ symbols unresolved');
    });

    test('Android links the archives from out/android-release/filament/lib/<abi>/', () {
      expect(hookSource, contains(r"'$filament/out/android-release/filament/lib/$androidAbi'"));
      expect(hookSource, contains(r"for (final lib in androidFilamentLibs) '$androidLibDir/$lib'"));
    });

    test('Android takes its generated headers from its own install tree', () {
      // uberarchive.h carries the archive size as a macro; the desktop header
      // would describe the desktop archive, not the mobile one linked here.
      expect(hookSource, contains(r"'$filament/out/android-release/filament/include'"));
    });

    test('androidFilamentLibs contains all core Filament static libraries', () {
      expect(hook.androidFilamentLibs,
          containsAll(['libfilament.a', 'libbackend.a', 'libutils.a', 'libfilamat.a', 'libbluevk.a', 'libabseil.a', 'libgeometry.a']));
    });
  });

  group('one source list for every target', () {
    final sources = hook.nativeSources('../filament');

    test('every wrapper source in src/ is compiled, on desktop and on Android alike', () {
      final onDisk = [
        for (final f in Directory('src').listSync(recursive: true).whereType<File>())
          if (f.path.endsWith('.cpp')) f.path.replaceAll('\\', '/'),
      ];
      final missing = onDisk.where((f) => !sources.contains(f)).toList();
      expect(missing, isEmpty, reason: 'sources the hook no longer compiles: $missing');
    });

    test('the desktop-only features stay in the list (they compile to stubs on Android)', () {
      expect(sources, containsAll([
        'src/ui_overlay_c.cpp',
        'src/dlss_c.cpp',
        'src/ngx_c.cpp',
        'src/post_pass_c.cpp',
        'src/opendlss_nr_c.cpp',
        'src/opendlss_nr/vk_context.cpp',
        'src/opendlss_nr/neural_pass.cpp',
      ]));
    });
  });
}
