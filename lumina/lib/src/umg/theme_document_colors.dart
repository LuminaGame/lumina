import 'dart:ui' show Color;

import 'package:lumina_core/lumina_core.dart';

/// A theme's component colours as Flutter [Color]s (`lumina_core` stores
/// them as ARGB ints).
extension LuminaComponentStyleColors on LuminaComponentStyle {
  /// [LuminaComponentStyle.backgroundColor] as a [Color], or null.
  Color? get bgColor => backgroundColor != null ? Color(backgroundColor!) : null;

  /// [LuminaComponentStyle.foregroundColor] as a [Color], or null.
  Color? get fgColor => foregroundColor != null ? Color(foregroundColor!) : null;

  /// [LuminaComponentStyle.borderColor] as a [Color], or null.
  Color? get bColor => borderColor != null ? Color(borderColor!) : null;
}

/// A theme's colour tokens as Flutter [Color]s.
extension LuminaThemeDocumentColors on LuminaThemeDocument {
  /// The colour of [token], or [fallback] when the theme does not set it.
  Color colorOf(String token, {Color fallback = const Color(0xFF888888)}) {
    final val = colors[token];
    if (val == null) return fallback;
    return Color(val);
  }
}
