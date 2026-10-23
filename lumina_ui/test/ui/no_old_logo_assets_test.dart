import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Prism L is the only mark: nothing in `lib/` draws the retired star-burst
/// PNGs, and the brand source lives under `assets/brand/`.
void main() {
  test('no widget references the retired logo assets', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final text = f.readAsStringSync();
      for (final old in ['assets/logo_color.png', 'assets/logo_white.png', 'assets/logo_black.png', 'assets/logo.svg', 'assets/logo_color.svg']) {
        if (text.contains(old)) offenders.add('${f.path}: $old');
      }
    }
    expect(offenders, isEmpty);
  });

  test('the retired assets are gone and the brand sources exist', () {
    for (final old in ['logo.svg', 'logo_color.svg', 'logo_color.png', 'logo_white.png', 'logo_black.png']) {
      expect(File('assets/$old').existsSync(), isFalse, reason: old);
    }
    expect(File('assets/brand/prism_l.svg').existsSync(), isTrue);
    expect(File('assets/brand/prism_l_mono.svg').existsSync(), isTrue);
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- assets/brand/'));
    expect(pubspec, contains('logo_path: assets/brand/store_logo.png'));
  });
}
