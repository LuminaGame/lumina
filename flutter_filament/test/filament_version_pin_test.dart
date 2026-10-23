import 'dart:convert';
import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Filament the package pins, documents, ships as a prebuilt and links are
/// one and the same release.
void main() {
  final root = Directory.current.parent; // the lumina repository
  final version = File('${root.path}/tool/filament/VERSION').readAsStringSync().trim();
  final upstream = version.split('-').first;

  test('the version pin is an upstream release with a lumina suffix', () {
    expect(RegExp(r'^\d+\.\d+\.\d+-lumina\.\d+$').hasMatch(version), isTrue, reason: version);
    expect(upstream, '1.78.1');
  });

  test('the patch README documents the pinned upstream tag only', () {
    final readme = File('${root.path}/third_party/filament/README.md').readAsStringSync();
    expect(readme, contains('v$upstream'));
    expect(readme, isNot(contains('v1.78.0')), reason: 'the previous tag must not linger in the patch workflow');
  });

  test('the shared prebuilt is the pinned version, built from the pinned tag', () {
    final manifest = File('${root.path}/../filament/lumina-filament.json');
    if (!manifest.existsSync()) {
      markTestSkipped('no shared prebuilt beside the repository');
      return;
    }
    final json = jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
    expect(json['version'], version);
    expect((json['upstream'] as Map)['tag'], 'v$upstream');
    expect((json['patches'] as List).length, 20);
  });

  test('the linked engine reports the pinned release', () {
    expect(FilamentInfo.version, upstream);
    expect(FilamentInfo.materialVersion, int.parse(upstream.split('.')[1]));
  });
}
