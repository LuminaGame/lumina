import 'package:flutter/foundation.dart' show Key;
import 'package:vector_math/vector_math_64.dart';

import '../components/camera/camera_component.dart';
import '../object/actor.dart';

/// A camera placed in a level: a [LuminaCameraComponent] at the actor's
/// transform (looking down its −Z, the authored +Y) carrying the level's
/// [LuminaCameraSettings].
///
/// Its camera stays inactive, so it never takes the view from the possessed
/// pawn by itself; it is looked through as a view target —
/// `Set View Target with Blend` from a Blueprint, or
/// [LuminaCameraSettings.autoActivateForPlayer], which makes it the
/// view target of each player logging in (`LuminaGameMode.login`). The
/// world then renders it with its own projection, clip planes and exposure.
class LuminaCameraActor extends LuminaActor {
  LuminaCameraActor({
    Key? key,
    Vector3? location,
    Quaternion? rotation,
    Vector3? scale,
    LuminaCameraSettings settings = const LuminaCameraSettings(),
  }) : this._(key, location, rotation, scale, settings, LuminaCameraComponent());

  LuminaCameraActor._(Key? key, Vector3? location, Quaternion? rotation, Vector3? scale, this.settings, this.cameraComponent)
      : super(key: key, root: cameraComponent, location: location, rotation: rotation) {
    // The authored scale, kept for transform parity; the lens ignores it.
    if (scale != null) actorScale = scale;
    settings.applyTo(cameraComponent);
    cameraComponent.isActive = false;
  }

  /// The settings the camera was built with.
  final LuminaCameraSettings settings;

  /// The camera looked through; the actor's root.
  final LuminaCameraComponent cameraComponent;

  /// Whether a player looks through this camera from login on.
  bool get autoActivateForPlayer => settings.autoActivateForPlayer;
}
