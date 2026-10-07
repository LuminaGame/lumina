import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  _thumbnailNeutrality();
}

/// The generated thumbnails were painted on a blue-tinted card while
/// every editor surface is a neutral grey. This package sits below the editor
/// and cannot import its palette, so the rule is asserted on the source.
void _thumbnailNeutrality() {
  test('generated thumbnail colours carry no hue', () {
    final source = File('lib/data/repositories/asset_repository.dart');
    expect(source.existsSync(), isTrue);
    // The library and its part files (split by domain).
    final lines = [
      ...source.readAsLinesSync(),
      for (final m in RegExp(r"^part '([^']+)';", multiLine: true).allMatches(source.readAsStringSync()))
        ...File('lib/data/repositories/${m.group(1)}').readAsLinesSync(),
    ];

    final tinted = <String>[];
    final literal = RegExp(r'ui\.Color\(0x([0-9A-Fa-f]{8})\)');
    for (final line in lines) {
      for (final match in literal.allMatches(line)) {
        final value = int.parse(match.group(1)!, radix: 16);
        final r = (value >> 16) & 0xFF, g = (value >> 8) & 0xFF, b = value & 0xFF;
        final spread = [r, g, b].reduce((a, c) => a > c ? a : c) -
            [r, g, b].reduce((a, c) => a < c ? a : c);
        // Only the greys matter: an icon may be any colour it likes, but a
        // surface that is meant to be grey must actually be grey.
        final isMeantToBeGrey = r < 0x60 && g < 0x60 && b < 0x60;
        if (isMeantToBeGrey && spread > 4) {
          tinted.add('${match.group(0)} (channel spread $spread) in: ${line.trim()}');
        }
      }
    }

    expect(tinted, isEmpty,
        reason: 'these dark surfaces have a hue; the editor\'s neutrals do '
            'not:\n${tinted.join('\n')}');
  });
}
