/// World units: one world unit is one **centimetre**. This is the only
/// place the metre ↔ unit factor is written; every
/// conversion goes through it.
abstract final class LuminaUnits {
  /// World units in one metre.
  static const double unitsPerMetre = 100.0;

  /// Standard gravity, cm/s² (magnitude; it pulls down).
  static const double gravity = 980.0;

  /// [m] metres in world units.
  static double metres(double m) => m * unitsPerMetre;

  /// [units] world units in metres.
  static double toMetres(double units) => units / unitsPerMetre;

  /// The Filament power for a physical point/spot light value (lumens or
  /// candela). Filament is physically based in metres: illuminance
  /// is I/d² with d in world units, so a centimetre world needs the power
  /// scaled by the square of [unitsPerMetre] to light the same at the same
  /// physical distance.
  static double lightPower(double physical) => physical * unitsPerMetre * unitsPerMetre;

  /// Range the froxel light grid covers, in world units (10 cm to 500 m).
  static const double dynamicLightingNear = 10.0;
  static const double dynamicLightingFar = 50000.0;
}
