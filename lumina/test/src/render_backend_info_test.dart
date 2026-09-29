import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart' show FilamentInfo;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// The editor reads the Filament version through
/// package:lumina, which reads it from the linked library (flutter_filament),
/// never from a hardcoded string.
void main() {
  test('filamentVersion is the linked Filament version, which is VERSION_NAME of gradle.properties', () {
    final String version;
    try {
      version = LuminaRenderBackendInfo.filamentVersion;
    } on ArgumentError catch (e) {
      markTestSkipped('flutter_filament native assets are not available: $e');
      return;
    }
    final gradle = File('${Directory.current.parent.path}/filament/android/gradle.properties').readAsStringSync();
    final expected = RegExp(r'^VERSION_NAME=(.+)$', multiLine: true).firstMatch(gradle)!.group(1)!.trim();
    expect(version, FilamentInfo.version);
    expect(version, expected);
    expect(LuminaRenderBackendInfo.filamentMaterialVersion, FilamentInfo.materialVersion);
    expect(LuminaRenderBackendInfo.filamentMaterialVersion, greaterThan(0));
    expect(LuminaRenderBackendInfo.filamentLicense, 'Apache-2.0');
    expect(LuminaRenderBackendInfo.filamentUrl, 'https://github.com/google/filament');
  });
}
