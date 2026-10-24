import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The Aurora surfaces are an ordered near-black ramp with a faint cool
/// cast, separated by solid borders rather than by big lightness steps; text
/// stays readable on every one of them.
///
/// L* is CIE 1976 lightness (D65, from relative luminance); contrast is the
/// WCAG 2.x ratio `(L1 + 0.05) / (L2 + 0.05)`.
void main() {
  double channel(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  double luminance(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);

  double lStar(Color c) {
    final double y = luminance(c);
    return y <= 216 / 24389 ? y * 24389 / 27 : 116 * math.pow(y, 1 / 3) - 16;
  }

  double contrast(Color a, Color b) {
    final double la = luminance(a), lb = luminance(b);
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  String hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  // Darkest to lightest, as the ramp is meant to read.
  final List<MapEntry<String, Color>> ramp = <MapEntry<String, Color>>[
    const MapEntry<String, Color>('rail', EditorColors.rail),
    const MapEntry<String, Color>('sidebar', EditorColors.sidebar),
    const MapEntry<String, Color>('background', EditorColors.background),
    const MapEntry<String, Color>('cardHeader', EditorColors.cardHeader),
    const MapEntry<String, Color>('card', EditorColors.card),
    const MapEntry<String, Color>('muted', EditorColors.muted),
    const MapEntry<String, Color>('secondary', EditorColors.secondary),
  ];
  final Map<String, Color> surfaces = Map<String, Color>.fromEntries(ramp)
    ..['popover'] = EditorColors.popover
    ..['viewportBackdrop'] = EditorColors.viewportBackdrop;

  test('every surface is opaque and carries at most the faint Obsidian cast', () {
    surfaces.forEach((String name, Color c) {
      expect(c.a, 1.0, reason: '$name must be opaque');
      // Blue leads red by a few steps: the cast, never a hue.
      final int r = (c.r * 255).round(), g = (c.g * 255).round(), b = (c.b * 255).round();
      expect(b - r, inInclusiveRange(0, 8), reason: '$name ${hex(c)} carries more than the cast');
      expect((g - r).abs(), lessThanOrEqualTo(4), reason: '$name ${hex(c)} carries more than the cast');
    });
  });

  test('the ramp is strictly ordered, each step at least 0.7 L* apart', () {
    final List<String> wrong = <String>[];
    for (int i = 1; i < ramp.length; i++) {
      final double step = lStar(ramp[i].value) - lStar(ramp[i - 1].value);
      if (step < 0.7) {
        wrong.add('${ramp[i - 1].key} ${hex(ramp[i - 1].value)} → '
            '${ramp[i].key} ${hex(ramp[i].value)}: ${step.toStringAsFixed(2)} L*');
      }
    }
    expect(wrong, isEmpty, reason: wrong.join('\n'));
    // Islands sit on the window, and fields on the islands: 2+ L* in all.
    expect(lStar(EditorColors.card) - lStar(EditorColors.sidebar), greaterThan(2));
  });

  test('foreground reaches 7:1 and mutedForeground 4.5:1 on every surface', () {
    final List<String> failures = <String>[];
    surfaces.forEach((String name, Color c) {
      final double fg = contrast(EditorColors.foreground, c);
      final double muted = contrast(EditorColors.mutedForeground, c);
      if (fg < 7) failures.add('foreground on $name ${hex(c)}: ${fg.toStringAsFixed(2)}');
      if (muted < 4.5) failures.add('mutedForeground on $name ${hex(c)}: ${muted.toStringAsFixed(2)}');
    });
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('borders separate the islands: the border is lighter than every surface it frames', () {
    for (final String name in <String>['rail', 'sidebar', 'background', 'cardHeader', 'card']) {
      expect(lStar(EditorColors.border), greaterThan(lStar(surfaces[name]!) + 2),
          reason: 'border ${hex(EditorColors.border)} must stand off $name ${hex(surfaces[name]!)}');
    }
    expect(lStar(EditorColors.fieldBorder), greaterThan(lStar(EditorColors.card) + 2));
  });

  test('the viewport backdrop sits just above the islands, and the amber reads dark text', () {
    expect(lStar(EditorColors.viewportBackdrop), greaterThan(lStar(EditorColors.sidebar)));
    expect(lStar(EditorColors.viewportBackdrop), lessThan(lStar(EditorColors.muted)));
    expect(contrast(EditorColors.primaryForeground, EditorColors.primary), greaterThan(7));
  });
}
