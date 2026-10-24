import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The glyph a TrueType font maps [codePoint] to (0 = none), read from its
/// `cmap` table's Unicode BMP subtable (format 4), as a text shaper does.
int glyphFor(ByteData font, int codePoint) {
  final numTables = font.getUint16(4);
  var cmap = -1;
  for (var i = 0; i < numTables; i++) {
    final record = 12 + i * 16;
    final tag = String.fromCharCodes([for (var k = 0; k < 4; k++) font.getUint8(record + k)]);
    if (tag == 'cmap') cmap = font.getUint32(record + 8);
  }
  expect(cmap, isNonNegative, reason: 'the font has a cmap table');
  final subtables = font.getUint16(cmap + 2);
  for (var i = 0; i < subtables; i++) {
    final platform = font.getUint16(cmap + 4 + i * 8), encoding = font.getUint16(cmap + 6 + i * 8);
    final table = cmap + font.getUint32(cmap + 8 + i * 8);
    final unicodeBmp = (platform == 3 && encoding == 1) || (platform == 0 && encoding <= 4);
    if (!unicodeBmp || font.getUint16(table) != 4) continue;
    final segCount = font.getUint16(table + 6) ~/ 2;
    final ends = table + 14, starts = ends + segCount * 2 + 2, deltas = starts + segCount * 2, offsets = deltas + segCount * 2;
    for (var s = 0; s < segCount; s++) {
      final end = font.getUint16(ends + s * 2);
      if (codePoint > end) continue;
      final start = font.getUint16(starts + s * 2);
      if (codePoint < start) return 0;
      final delta = font.getInt16(deltas + s * 2), rangeOffset = font.getUint16(offsets + s * 2);
      if (rangeOffset == 0) return (codePoint + delta) & 0xFFFF;
      final glyph = font.getUint16(offsets + s * 2 + rangeOffset + (codePoint - start) * 2);
      return glyph == 0 ? 0 : (glyph + delta) & 0xFFFF;
    }
    return 0;
  }
  fail('no Unicode BMP cmap subtable');
}

/// Manrope for UI text and JetBrains Mono for numbers resolve from the app's
/// asset bundle, the way the engine registers them at startup, and every
/// glyph of an editor line is the bundled font's own: none falls back.
void main() {
  const sample = 'Warehouse_Demo · 182k tris';
  late Map<String, List<String>> manifest;

  setUpAll(() async {
    final entries = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
    manifest = {
      for (final e in entries.cast<Map<String, dynamic>>())
        e['family'] as String: [for (final f in (e['fonts'] as List).cast<Map<String, dynamic>>()) f['asset'] as String],
    };
  });

  test('the font manifest bundles Manrope (5 weights) and JetBrains Mono (3 weights)', () {
    expect(manifest[EditorTypography.uiFamily], hasLength(5));
    expect(manifest[EditorTypography.monoFamily], hasLength(3));
    expect(manifest[EditorTypography.uiFamily], everyElement(startsWith('assets/fonts/Manrope-')));
    expect(manifest[EditorTypography.monoFamily], everyElement(startsWith('assets/fonts/JetBrainsMono-')));
  });

  for (final family in [EditorTypography.uiFamily, EditorTypography.monoFamily]) {
    test('every weight of $family maps every character of "$sample" to a glyph of its own', () async {
      for (final asset in manifest[family]!) {
        final font = await rootBundle.load(asset);
        for (final rune in sample.runes) {
          expect(glyphFor(font, rune), isNot(0), reason: '$asset has a glyph for U+${rune.toRadixString(16).padLeft(4, '0')}');
        }
        // A character the font does not cover reads as no glyph.
        expect(glyphFor(font, 0x4E2D), 0, reason: '$asset has no CJK glyph');
      }
    });
  }

  testWidgets('loaded from the bundle, the sample lays out with the fonts\' own advances, not the test font\'s squares',
      (tester) async {
    for (final family in [EditorTypography.uiFamily, EditorTypography.monoFamily]) {
      final loader = FontLoader(family);
      for (final asset in manifest[family]!) {
        loader.addFont(rootBundle.load(asset));
      }
      await tester.runAsync(loader.load);
    }
    const size = 20.0;
    double width(String text, TextStyle style) {
      final painter = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
      final w = painter.width;
      painter.dispose();
      return w;
    }

    // The test font draws every character 1 em wide: a character the
    // family failed to cover would measure exactly [size].
    final ui = EditorTypography.ui(fontSize: size);
    final mono = EditorTypography.mono(fontSize: size);
    expect(ui.fontFamily, EditorTypography.uiFamily);
    expect(mono.fontFamily, EditorTypography.monoFamily);
    for (final ch in ['W', 'a', '_', '·', '1', 'k', ' ']) {
      expect(width(ch, ui), isNot(closeTo(size, 0.01)), reason: 'Manrope draws "$ch" itself');
    }
    // JetBrains Mono is monospaced at 0.6 em.
    final advances = {for (final ch in sample.split('')) width(ch, mono).toStringAsFixed(2)};
    expect(advances, {(size * 0.6).toStringAsFixed(2)}, reason: 'every character of the sample at JetBrains Mono\'s 0.6 em');
    expect(width(sample, mono), closeTo(sample.length * size * 0.6, 0.5));
    // Manrope is proportional: the line is narrower than the mono one.
    expect(width(sample, ui), lessThan(width(sample, mono)));
  });
}
