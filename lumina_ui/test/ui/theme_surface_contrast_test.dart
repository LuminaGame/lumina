import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The panel surfaces are lifted off pure black onto a grey
/// ramp whose steps can actually be told apart, while text stays readable on
/// every one of them.
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

  final Map<String, Color> surfaces = <String, Color>{
    'background': EditorColors.background,
    'sidebar': EditorColors.sidebar,
    'card': EditorColors.card,
    'cardHeader': EditorColors.cardHeader,
    'rail': EditorColors.rail,
    'popover': EditorColors.popover,
  };

  test('every surface is opaque and hueless', () {
    surfaces.forEach((String name, Color c) {
      expect(c.a, 1.0, reason: '$name must be opaque');
      expect(c.r, c.g, reason: '$name ${hex(c)} must carry no hue');
      expect(c.g, c.b, reason: '$name ${hex(c)} must carry no hue');
    });
  });

  test('adjacent surfaces on the lightness ramp differ by at least 4 L*', () {
    final List<MapEntry<String, Color>> ramp = surfaces.entries.toList()
      ..sort((MapEntry<String, Color> a, MapEntry<String, Color> b) =>
          lStar(a.value).compareTo(lStar(b.value)));
    final List<String> tooClose = <String>[];
    for (int i = 1; i < ramp.length; i++) {
      final double step = lStar(ramp[i].value) - lStar(ramp[i - 1].value);
      if (step < 4) {
        tooClose.add('${ramp[i - 1].key} ${hex(ramp[i - 1].value)} → '
            '${ramp[i].key} ${hex(ramp[i].value)}: ${step.toStringAsFixed(2)} L*');
      }
    }
    expect(tooClose, isEmpty, reason: tooClose.join('\n'));
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

  test('no surface is darker than #121212; the viewport backdrop stays darker', () {
    final double floor = lStar(const Color(0xFF121212));
    surfaces.forEach((String name, Color c) {
      expect(lStar(c), greaterThanOrEqualTo(floor), reason: '$name ${hex(c)} is near-black');
    });
    final double darkest = surfaces.values.map(lStar).reduce(math.min);
    expect(lStar(EditorColors.viewportBackdrop), lessThan(darkest),
        reason: 'the 3D view reads as recessed below every panel');
  });

  test('borders stay visible over the lifted surfaces', () {
    // Translucent white, so it keeps its weight on each surface; the solid
    // variant is that border composited over the background.
    expect(EditorColors.border.a, lessThan(1.0));
    expect(EditorColors.border.a, greaterThanOrEqualTo(0x1F / 255 - 1e-6));
    expect(lStar(EditorColors.borderSolid) - lStar(EditorColors.background), greaterThanOrEqualTo(8));
  });
}
