/// What a fall should turn into.
enum LuminaFallOutcome { none, hardLanding, ragdoll }

/// Watches a character's vertical speed and decides what a fall becomes:
/// falling faster than [ragdollFallSpeed] goes limp in the air; touching
/// down faster than [ragdollLandingSpeed] goes limp on landing, faster than
/// [hardLandingSpeed] lands heavily. Speeds are world units per second
/// (cm/s): 750 is a drop of about 2.9 m, 1300 about 8.6 m.
class LuminaFallMonitor {
  double hardLandingSpeed;
  double ragdollLandingSpeed;
  double ragdollFallSpeed;

  LuminaFallMonitor({this.hardLandingSpeed = 750.0, this.ragdollLandingSpeed = 1200.0, this.ragdollFallSpeed = 1300.0});

  bool _falling = false;
  double _lastVerticalSpeed = 0.0;
  bool _ragdolledInAir = false;

  /// The downward speed at the last touchdown (cm/s).
  double lastImpactSpeed = 0.0;

  /// The fastest downward speed of the fall in progress (cm/s).
  double fallSpeed = 0.0;

  /// One frame: [falling] the movement mode, [verticalVelocity] its vertical
  /// velocity (up positive). Returns what to do now.
  LuminaFallOutcome update({required bool falling, required double verticalVelocity}) {
    if (falling) {
      _falling = true;
      _lastVerticalSpeed = verticalVelocity;
      fallSpeed = fallSpeed > -verticalVelocity ? fallSpeed : -verticalVelocity;
      if (!_ragdolledInAir && -verticalVelocity > ragdollFallSpeed) {
        _ragdolledInAir = true;
        return LuminaFallOutcome.ragdoll;
      }
      return LuminaFallOutcome.none;
    }
    if (!_falling) return LuminaFallOutcome.none;
    // Touchdown: the speed of the last falling frame.
    _falling = false;
    final impact = -_lastVerticalSpeed;
    lastImpactSpeed = impact;
    fallSpeed = 0.0;
    final inAir = _ragdolledInAir;
    _ragdolledInAir = false;
    if (inAir) return LuminaFallOutcome.none;
    if (impact > ragdollLandingSpeed) return LuminaFallOutcome.ragdoll;
    if (impact > hardLandingSpeed) return LuminaFallOutcome.hardLanding;
    return LuminaFallOutcome.none;
  }

  /// Forgets the fall in progress (after a ragdoll, a teleport).
  void reset() {
    _falling = false;
    _ragdolledInAir = false;
    _lastVerticalSpeed = 0.0;
    fallSpeed = 0.0;
  }
}
