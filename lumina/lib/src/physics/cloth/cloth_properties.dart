import 'dart:math' as math;

import 'package:lumina_core/lumina_core.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/game/primitive_actor.dart' show luminaHexToRgb;

/// Reads cloth keys from Blueprint / level properties: numbers, flags, the
/// wind (authoring axes) and the colour (`#RRGGBB` sRGB or a linear list).
class LuminaClothPropertyReader {
  const LuminaClothPropertyReader(this.p);

  final Map<String, dynamic> p;

  double number(String key, double fallback) => (p[key] as num?)?.toDouble() ?? fallback;

  /// A number, or null when missing (or negative with [negativeIsNull]).
  double? optionalNumber(String key, {bool negativeIsNull = true}) {
    final v = (p[key] as num?)?.toDouble();
    return v == null || (negativeIsNull && v < 0) ? null : v;
  }

  int integer(String key, int fallback) => (p[key] as num?)?.toInt() ?? fallback;

  bool flag(String key, bool fallback) => p[key] as bool? ?? fallback;

  /// A string, or an asset reference's path (`{asset_path: ...}`); null
  /// when missing or empty.
  String? text(String key) {
    final raw = p[key];
    final v = raw is Map ? raw['asset_path'] as String? : raw as String?;
    return v == null || v.isEmpty ? null : v;
  }

  List<int> integers(String key) => [for (final v in (p[key] as List? ?? const [])) (v as num).toInt()];

  List<double>? numbers(String key) {
    final list = p[key] as List?;
    return list == null ? null : [for (final v in list) (v as num).toDouble()];
  }

  /// The wind (cm/s): stored in authoring axes, returned in runtime axes.
  Vector3? get wind {
    final list = numbers('wind');
    return list == null || list.length < 3 ? null : LuminaAxes.location(list);
  }

  /// The colour (linear 0..1): a list is linear, the editor's `#RRGGBB` sRGB.
  Vector3? get color {
    final value = p['color'];
    if (value is String) {
      final hex = luminaHexToRgb(value);
      return Vector3(_linear(hex.x), _linear(hex.y), _linear(hex.z));
    }
    if (value is List && value.length >= 3) {
      return Vector3((value[0] as num).toDouble(), (value[1] as num).toDouble(), (value[2] as num).toDouble());
    }
    return null;
  }

  static double _linear(double srgb) => math.pow(srgb, 2.2).toDouble();
}
