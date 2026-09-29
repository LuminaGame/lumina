import 'dart:math' as math;

/// How two touching surfaces combine a friction or restitution value.
/// When the two materials ask for different modes the later one in this
/// list wins.
enum LuminaPhysicsCombineMode {
  average,
  min,
  multiply,
  max;

  /// The display name: `Average`, `Min`, …
  String get displayName => name[0].toUpperCase() + name.substring(1);

  /// Parses a display or enum name; null when unknown.
  static LuminaPhysicsCombineMode? parse(Object? value) {
    final key = '$value'.toLowerCase();
    for (final m in values) {
      if (m.name == key) return m;
    }
    return null;
  }
}

/// A surface's physical response: Coulomb
/// [friction] (dynamic; [staticFriction] while at rest, the dynamic value when
/// null), [restitution] (bounciness, 0–1) and [density] in g/cm³, which gives
/// a body its mass from its volume when nothing else does.
class LuminaPhysicalMaterial {
  final double friction;
  final double? staticFriction;
  final double restitution;

  /// g/cm³: water is 1.
  final double density;

  final LuminaPhysicsCombineMode frictionCombineMode;
  final LuminaPhysicsCombineMode restitutionCombineMode;

  const LuminaPhysicalMaterial({
    this.friction = defaultFriction,
    this.staticFriction,
    this.restitution = defaultRestitution,
    this.density = defaultDensity,
    this.frictionCombineMode = LuminaPhysicsCombineMode.average,
    this.restitutionCombineMode = LuminaPhysicsCombineMode.average,
  });

  static const double defaultFriction = 0.7;
  static const double defaultRestitution = 0.1;
  static const double defaultDensity = 1.0;

  /// The material a surface without one uses.
  static const LuminaPhysicalMaterial standard = LuminaPhysicalMaterial();

  /// The friction that holds a body at rest.
  double get effectiveStaticFriction => staticFriction ?? friction;

  LuminaPhysicalMaterial copyWith({double? friction, double? restitution, double? density}) => LuminaPhysicalMaterial(
        friction: friction ?? this.friction,
        staticFriction: staticFriction,
        restitution: restitution ?? this.restitution,
        density: density ?? this.density,
        frictionCombineMode: frictionCombineMode,
        restitutionCombineMode: restitutionCombineMode,
      );

  /// Combines [a] and [b] by [mode].
  static double combine(double a, double b, LuminaPhysicsCombineMode mode) => switch (mode) {
        LuminaPhysicsCombineMode.average => (a + b) * 0.5,
        LuminaPhysicsCombineMode.min => math.min(a, b),
        LuminaPhysicsCombineMode.multiply => a * b,
        LuminaPhysicsCombineMode.max => math.max(a, b),
      };

  static LuminaPhysicsCombineMode _mode(LuminaPhysicsCombineMode a, LuminaPhysicsCombineMode b) =>
      a.index >= b.index ? a : b;

  /// The dynamic friction of [a] touching [b].
  static double combinedFriction(LuminaPhysicalMaterial a, LuminaPhysicalMaterial b) =>
      combine(a.friction, b.friction, _mode(a.frictionCombineMode, b.frictionCombineMode));

  /// The static friction of [a] touching [b].
  static double combinedStaticFriction(LuminaPhysicalMaterial a, LuminaPhysicalMaterial b) =>
      combine(a.effectiveStaticFriction, b.effectiveStaticFriction, _mode(a.frictionCombineMode, b.frictionCombineMode));

  /// The restitution of [a] touching [b].
  static double combinedRestitution(LuminaPhysicalMaterial a, LuminaPhysicalMaterial b) =>
      combine(a.restitution, b.restitution, _mode(a.restitutionCombineMode, b.restitutionCombineMode));

  @override
  bool operator ==(Object other) =>
      other is LuminaPhysicalMaterial &&
      other.friction == friction &&
      other.staticFriction == staticFriction &&
      other.restitution == restitution &&
      other.density == density &&
      other.frictionCombineMode == frictionCombineMode &&
      other.restitutionCombineMode == restitutionCombineMode;

  @override
  int get hashCode => Object.hash(friction, staticFriction, restitution, density, frictionCombineMode, restitutionCombineMode);

  @override
  String toString() => 'LuminaPhysicalMaterial(friction: $friction, restitution: $restitution, density: $density)';
}
