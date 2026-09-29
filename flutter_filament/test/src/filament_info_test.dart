import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Filament version the wrapper was built with, and the
/// material version its headers accept — read from the same files the build
/// takes them from, never hardcoded here.
void main() {
  final filamentRoot = '${Directory.current.parent.path}/filament';

  String gradleVersion() {
    final text = File('$filamentRoot/android/gradle.properties').readAsStringSync();
    return RegExp(r'^VERSION_NAME=(.+)$', multiLine: true).firstMatch(text)!.group(1)!.trim();
  }

  int headerMaterialVersion() {
    final text = File('$filamentRoot/libs/filabridge/include/filament/MaterialEnums.h').readAsStringSync();
    return int.parse(RegExp(r'MATERIAL_VERSION\s*=\s*(\d+)').firstMatch(text)!.group(1)!);
  }

  test('version equals VERSION_NAME of filament/android/gradle.properties', () {
    expect(FilamentInfo.version, gradleVersion());
    expect(FilamentInfo.version, matches(RegExp(r'^\d+\.\d+\.\d+$')));
  });

  test('materialVersion equals MATERIAL_VERSION of MaterialEnums.h', () {
    expect(FilamentInfo.materialVersion, greaterThan(0));
    expect(FilamentInfo.materialVersion, headerMaterialVersion());
  });

  test('readable before any engine exists, and memoised', () {
    final first = FilamentInfo.version;
    expect(identical(FilamentInfo.version, first), isTrue, reason: 'the same String instance every time');
    expect(FilamentInfo.materialVersion, FilamentInfo.materialVersion);
  });
}
