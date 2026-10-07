import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/controller/controller.dart';
import 'package:lumina/src/math/euler.dart';
import 'package:lumina/src/controller/player_controller.dart';
import 'package:lumina/src/components/player/lumina_player_component.dart';

/// Base class for actors that can be possessed by a [LuminaController] (Player or AI).
class LuminaPawn extends LuminaActor {
  LuminaController? _controller;
  LuminaPlayerComponent? _playerInputComponent;

  final List<void Function(LuminaController)> _onPossessedListeners = [];
  final List<void Function(LuminaController)> _onUnpossessedListeners = [];

  bool bUseControllerRotationPitch = false;
  bool bUseControllerRotationYaw = true;
  bool bUseControllerRotationRoll = false;

  /// Height of the eyes above the actor location, in cm
  /// (`BaseEyeHeight`): [getPawnViewLocation] is `actorLocation + (0,
  /// baseEyeHeight, 0)`. For a [LuminaCharacter] the actor location is the
  /// capsule **centre**, so this is measured from there, not from the feet —
  /// the Third Person character's eyes, 160 cm above the ground
  /// with a 90 cm half-height capsule, are 70.
  double baseEyeHeight = 160.0; // cm
  final Vector3 _pendingMovementInput = Vector3.zero();
  final Vector3 _lastMovementInput = Vector3.zero();

  LuminaPawn({
    super.key,
    super.root,
    super.components,
    super.location,
    super.rotation,
  });

  LuminaController? get controller => _controller;

  /// Returns whether this pawn is currently controlled by an active controller.
  bool isPawnControlled() => _controller != null;

  /// Returns whether this pawn is controlled by a human player.
  bool isPlayerControlled() => _controller is LuminaPlayerController;

  /// Returns whether this pawn is controlled by AI.
  bool isBotControlled() => _controller != null && !isPlayerControlled();

  /// Adds a listener callback invoked when this pawn is possessed by a controller.
  void addOnPossessed(void Function(LuminaController) listener) {
    _onPossessedListeners.add(listener);
  }

  /// Removes a possession listener callback.
  void removeOnPossessed(void Function(LuminaController) listener) {
    _onPossessedListeners.remove(listener);
  }

  /// Adds a listener callback invoked when this pawn is unpossessed.
  void addOnUnpossessed(void Function(LuminaController) listener) {
    _onUnpossessedListeners.add(listener);
  }

  /// Removes an unpossession listener callback.
  void removeOnUnpossessed(void Function(LuminaController) listener) {
    _onUnpossessedListeners.remove(listener);
  }

  /// Resets transient movement and state on each new possession.
  void restart() {
    _pendingMovementInput.setZero();
    _lastMovementInput.setZero();
  }

  /// Called when possessed by a controller.
  void possessedBy(LuminaController newController) {
    _controller = newController;
    restart();

    if (newController is LuminaPlayerController) {
      var pic = getComponent<LuminaPlayerComponent>();
      if (pic == null) {
        pic = LuminaPlayerComponent();
        addComponent(pic);
      }
      _playerInputComponent = pic;
      setupPlayerInputComponent(pic);
    }

    for (final listener in List<void Function(LuminaController)>.from(_onPossessedListeners)) {
      listener(newController);
    }
  }

  /// Called when unpossessed.
  void unpossessed() {
    if (_playerInputComponent != null) {
      _playerInputComponent!.onUnregister();
      _playerInputComponent = null;
    }

    final oldController = _controller;
    _controller = null;

    if (oldController != null) {
      for (final listener in List<void Function(LuminaController)>.from(_onUnpossessedListeners)) {
        listener(oldController);
      }
    }
  }

  /// Hook for setting up input bindings on the player component.
  void setupPlayerInputComponent(LuminaPlayerComponent playerInput) {}

  /// Adds movement input along a world direction vector without per-call normalization.
  void addMovementInput(Vector3 worldDirection, double scale) {
    if (scale == 0.0 || (worldDirection.x == 0.0 && worldDirection.y == 0.0 && worldDirection.z == 0.0)) {
      return;
    }
    _pendingMovementInput.addScaled(worldDirection, scale);
  }

  /// Returns a defensive copy of currently pending accumulated input.
  Vector3 getPendingMovementInputVector() => _pendingMovementInput.clone();

  /// Returns a defensive copy of input consumed in the last frame.
  Vector3 getLastMovementInputVector() => _lastMovementInput.clone();

  /// Consumes and returns accumulated input vector, resetting pending input.
  Vector3 consumeMovementInputVector() {
    _lastMovementInput.setFrom(_pendingMovementInput);
    final result = _pendingMovementInput.clone();
    _pendingMovementInput.setZero();
    return result;
  }

  /// Forwards pitch input in degrees to the controlling controller.
  void addControllerPitchInput(double v) {
    if (_controller != null) {
      _controller!.controlRotation.x += v;
    }
  }

  /// Forwards yaw input in degrees to the controlling controller.
  void addControllerYawInput(double v) {
    if (_controller != null) {
      _controller!.controlRotation.y += v;
    }
  }

  /// Forwards roll input in degrees to the controlling controller.
  void addControllerRollInput(double v) {
    if (_controller != null) {
      _controller!.controlRotation.z += v;
    }
  }

  bool _freeLook = false;
  double _recenterRemaining = 0.0;

  /// Seconds the controller yaw takes to swing back behind the pawn when
  /// [freeLook] ends.
  double freeLookRecenterSeconds = 0.25;

  /// Free look: while true the body ignores the controller's
  /// yaw ([faceRotation] keeps [actorRotation]) although the controller keeps
  /// turning, so a camera boom on the control rotation orbits the standing
  /// or walking pawn. Turning it off keeps the heading and eases the
  /// controller's yaw back to the pawn's over [freeLookRecenterSeconds].
  bool get freeLook => _freeLook;
  set freeLook(bool value) {
    if (_freeLook == value) return;
    _freeLook = value;
    _recenterRemaining = value ? 0.0 : freeLookRecenterSeconds;
  }

  /// Whether the controller yaw is still swinging back after free look.
  bool get isRecenteringFromFreeLook => !_freeLook && _recenterRemaining > 0.0;

  /// Updates actor rotation towards control rotation per enabled axis flag.
  void faceRotation(Vector3 controlRotation, double deltaTime) {
    if (_freeLook) return;
    if (_recenterRemaining > 0.0) {
      // Recentre: the camera swings back behind the pawn, the pawn stays.
      final actorYaw = _quaternionToEulerDegrees(actorRotation).y;
      var delta = (actorYaw - controlRotation.y) % 360.0;
      if (delta > 180.0) delta -= 360.0;
      if (delta < -180.0) delta += 360.0;
      // Frame times summing to the recentre time finish it (no float residue).
      final done = deltaTime >= _recenterRemaining - 1e-9;
      controlRotation.y += done ? delta : delta * deltaTime / _recenterRemaining;
      _recenterRemaining = done ? 0.0 : _recenterRemaining - deltaTime;
      if (!done) return;
      controlRotation.y = actorYaw;
    }
    if (!bUseControllerRotationPitch && !bUseControllerRotationYaw && !bUseControllerRotationRoll) {
      return;
    }

    final currentEuler = _quaternionToEulerDegrees(actorRotation);
    final targetPitch = bUseControllerRotationPitch ? controlRotation.x : currentEuler.x;
    final targetYaw = bUseControllerRotationYaw ? controlRotation.y : currentEuler.y;
    final targetRoll = bUseControllerRotationRoll ? controlRotation.z : currentEuler.z;

    actorRotation = _eulerDegreesToQuaternion(targetPitch, targetYaw, targetRoll);
  }

  /// Returns the eye location of this pawn for camera tracking: [baseEyeHeight]
  /// above the actor location.
  Vector3 getPawnViewLocation() {
    return actorLocation + Vector3(0, baseEyeHeight, 0);
  }

  /// Returns the view rotation in (pitch, yaw, roll) degrees.
  Vector3 getViewRotation() {
    if (_controller != null) {
      return _controller!.controlRotation.clone();
    }
    return _quaternionToEulerDegrees(actorRotation);
  }

  /// Returns combined eye location and view rotation for camera binding.
  ({Vector3 location, Vector3 rotation}) getActorEyesViewPoint() {
    return (
      location: getPawnViewLocation(),
      rotation: getViewRotation(),
    );
  }

  static Quaternion _eulerDegreesToQuaternion(double pitchDeg, double yawDeg, double rollDeg) =>
      luminaPawnEulerToQuaternion(pitchDeg, yawDeg, rollDeg);

  static Vector3 _quaternionToEulerDegrees(Quaternion q) => luminaPawnQuaternionToEuler(q);
}
