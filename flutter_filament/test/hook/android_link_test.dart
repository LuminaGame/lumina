import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../hook/build.dart' as hook;

void main() {
  final packageRoot = Directory.current;
  final filamentDir = Directory('${packageRoot.path}/../filament');

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
            reason: 'Filament Android lib dir for $abi must exist at ${libDir.path}');

        final missing = <String>[];
        for (final lib in hook.androidFilamentLibs) {
          final file = File('${libDir.path}/$lib');
          if (!file.existsSync()) {
            missing.add(lib);
          }
        }
        expect(missing, isEmpty,
            reason: 'All ${hook.androidFilamentLibs.length} Android libraries must exist for $abi, missing: $missing');
      });
    }

    test('androidFilamentLibs contains all core Filament static libraries', () {
      expect(hook.androidFilamentLibs, contains('libfilament.a'));
      expect(hook.androidFilamentLibs, contains('libbackend.a'));
      expect(hook.androidFilamentLibs, contains('libutils.a'));
      expect(hook.androidFilamentLibs, contains('libfilamat.a'));
      expect(hook.androidFilamentLibs, contains('libbluevk.a'));
      expect(hook.androidFilamentLibs, contains('libabseil.a'));
      expect(hook.androidFilamentLibs, contains('libgeometry.a'));
    });
  });
}
