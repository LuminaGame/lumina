import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/src/object/pawn.dart';

/// Abstract controller base class that can possess and manage a [LuminaPawn].
abstract class LuminaController {
  LuminaPawn? _possessedPawn;
  final Vector3 _controlRotation = Vector3.zero(); // Pitch, Yaw, Roll

  LuminaPawn? get pawn => _possessedPawn;
  Vector3 get controlRotation => _controlRotation;

  set controlRotation(Vector3 rot) {
    _controlRotation.setFrom(rot);
  }

  /// Possesses the specified [pawnToPossess].
  void possess(LuminaPawn pawnToPossess) {
    if (_possessedPawn == pawnToPossess) return;
    unpossess();

    // Steal semantics: if another controller already possesses this pawn, unpossess it first
    if (pawnToPossess.controller != null && pawnToPossess.controller != this) {
      pawnToPossess.controller!.unpossess();
    }

    _possessedPawn = pawnToPossess;
    pawnToPossess.possessedBy(this);
    onPossess(pawnToPossess);
  }

  /// Unpossesses the current pawn.
  void unpossess() {
    if (_possessedPawn != null) {
      final oldPawn = _possessedPawn!;
      _possessedPawn = null;
      oldPawn.unpossessed();
      onUnpossess(oldPawn);
    }
  }

  void onPossess(LuminaPawn pawn) {}
  void onUnpossess(LuminaPawn pawn) {}
  void onTick(double deltaTime) {}

  /// Returns the viewpoint (location and rotation) for camera and rendering systems.
  ({Vector3 location, Vector3 rotation}) getPlayerViewPoint() {
    if (_possessedPawn != null) {
      return _possessedPawn!.getActorEyesViewPoint();
    }
    return (
      location: Vector3.zero(),
      rotation: _controlRotation.clone(),
    );
  }
}
