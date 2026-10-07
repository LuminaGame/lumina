import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/src/components/camera/camera_component.dart';
import 'package:lumina/src/controller/player_controller.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/object/pawn.dart';

class LuminaMinimalViewInfo {
  Vector3 location = Vector3.zero();
  Quaternion rotation = Quaternion.identity();
  double fovDegrees = 90.0;
  double nearClip = 10.0; // cm
  double farClip = 100000.0; // cm

  /// The camera component this point of view is, when the view target has
  /// one and no blend is running: the view then uses its projection, clip
  /// planes and exposure too. Null for a blend or a target without a camera.
  LuminaCameraComponent? camera;
}

enum LuminaViewTargetBlendFunction {
  linear,
  cubic,
  easeIn,
  easeOut,
  easeInOut,
}

class LuminaCameraShake {
  final Vector3 locationAmplitude;
  final Vector3 rotationAmplitudeDegrees;
  final Vector3 locationFrequency;
  final double duration;
  final double blendInTime;
  final double blendOutTime;
  final double initialPhase;

  double _elapsedTime = 0.0;

  LuminaCameraShake({
    required this.locationAmplitude,
    required this.locationFrequency,
    required this.duration,
    Vector3? rotationAmplitudeDegrees,
    this.blendInTime = 0.0,
    this.blendOutTime = 0.0,
    this.initialPhase = 0.0,
  }) : rotationAmplitudeDegrees = rotationAmplitudeDegrees ?? Vector3.zero();

  bool get isFinished => _elapsedTime >= duration;

  Vector3 updateAndGetShake(double deltaTime) {
    if (isFinished) return Vector3.zero();

    _elapsedTime += deltaTime;
    if (_elapsedTime > duration) {
      _elapsedTime = duration;
    }
    // Envelope for blendIn and blendOut
    double blendWeight = 1.0;
    if (blendInTime > 0 && _elapsedTime < blendInTime) {
      blendWeight = _elapsedTime / blendInTime;
    } else if (blendOutTime > 0 && _elapsedTime > (duration - blendOutTime)) {
      blendWeight = (duration - _elapsedTime) / blendOutTime;
    }

    final t = _elapsedTime;
    final phase = initialPhase;
    
    final x = locationAmplitude.x * math.sin(locationFrequency.x * math.pi * 2.0 * t + phase);
    final y = locationAmplitude.y * math.sin(locationFrequency.y * math.pi * 2.0 * t + phase);
    final z = locationAmplitude.z * math.sin(locationFrequency.z * math.pi * 2.0 * t + phase);

    return Vector3(x, y, z) * blendWeight;
  }
}

class LuminaPlayerCameraManager {
  final LuminaPlayerController playerController;
  final LuminaMinimalViewInfo cameraCachePov = LuminaMinimalViewInfo();
  
  LuminaActor? _viewTarget;
  LuminaActor? _pendingViewTarget;
  
  double _blendTimeToGo = 0.0;
  double _blendTimeTotal = 0.0;
  LuminaViewTargetBlendFunction _blendFunction = LuminaViewTargetBlendFunction.linear;
  double _blendExponent = 2.0;

  double? _overriddenFov;

  final List<LuminaCameraShake> _activeShakes = [];

  LuminaPlayerCameraManager(this.playerController);

  LuminaActor? get viewTarget => _viewTarget;

  /// The actor the view is blending towards, while a blend runs.
  LuminaActor? get pendingViewTarget => _pendingViewTarget;

  /// Whether a Set View Target with Blend is in progress.
  bool get isBlending => _pendingViewTarget != null && _blendTimeToGo > 0.0;

  /// Seconds left in the running blend, 0 when none.
  double get blendTimeRemaining => isBlending ? _blendTimeToGo : 0.0;

  void setViewTarget(LuminaActor target) {
    _viewTarget = target;
    _pendingViewTarget = null;
    _blendTimeToGo = 0.0;
  }

  void setViewTargetWithBlend(
    LuminaActor target, {
    required double blendTime,
    LuminaViewTargetBlendFunction blendFunction = LuminaViewTargetBlendFunction.linear,
    double blendExponent = 2.0,
  }) {
    if (blendTime <= 0.0) {
      setViewTarget(target);
      return;
    }
    
    // If we're already blending to it, just update parameters? 
    // Here we will start a new blend from the current cached POV to the new target.
    _pendingViewTarget = target;
    _blendTimeTotal = blendTime;
    _blendTimeToGo = blendTime;
    _blendFunction = blendFunction;
    _blendExponent = blendExponent;
  }

  void setFov(double newFov) {
    _overriddenFov = newFov;
  }

  void resetFov() {
    _overriddenFov = null;
  }

  void startCameraShake(LuminaCameraShake shake) {
    _activeShakes.add(shake);
  }

  void stopAllCameraShakes({bool immediately = false}) {
    if (immediately) {
      _activeShakes.clear();
    } else {
      for (var shake in _activeShakes) {
        // Set their elapsed time to the start of blend out
        if (shake.blendOutTime > 0) {
          final blendOutStart = shake.duration - shake.blendOutTime;
          if (shake._elapsedTime < blendOutStart) {
            shake._elapsedTime = blendOutStart;
          }
        } else {
          shake._elapsedTime = shake.duration; // Stop instantly if no blend out
        }
      }
    }
  }

  void updateCamera(double deltaTime) {
    // Determine the ideal view target to query
    _updateViewTarget();
    
    // Evaluate the target POV
    final targetPov = _evaluatePov(_viewTarget);
    
    // Handle blending
    if (_pendingViewTarget != null && _blendTimeToGo > 0) {
      _blendTimeToGo -= deltaTime;
      if (_blendTimeToGo <= 0) {
        _viewTarget = _pendingViewTarget;
        _pendingViewTarget = null;
        _blendTimeToGo = 0.0;
        
        final newPov = _evaluatePov(_viewTarget);
        cameraCachePov.location.setFrom(newPov.location);
        cameraCachePov.rotation.setFrom(newPov.rotation);
        cameraCachePov.fovDegrees = _overriddenFov ?? newPov.fovDegrees;
        _copyLens(newPov);
      } else {
        final pendingPov = _evaluatePov(_pendingViewTarget);
        final pct = 1.0 - (_blendTimeToGo / _blendTimeTotal);
        final alpha = _applyBlendFunction(pct);
        
        cameraCachePov.location = targetPov.location * (1.0 - alpha) + pendingPov.location * alpha;
        cameraCachePov.rotation = _slerp(targetPov.rotation, pendingPov.rotation, alpha);
        
        final baseFov = _overriddenFov ?? targetPov.fovDegrees;
        final pendingFov = _overriddenFov ?? pendingPov.fovDegrees;
        cameraCachePov.fovDegrees = baseFov * (1.0 - alpha) + pendingFov * alpha;
        cameraCachePov
          ..nearClip = targetPov.nearClip * (1.0 - alpha) + pendingPov.nearClip * alpha
          ..farClip = targetPov.farClip * (1.0 - alpha) + pendingPov.farClip * alpha
          ..camera = null;
      }
    } else {
      cameraCachePov.location.setFrom(targetPov.location);
      cameraCachePov.rotation.setFrom(targetPov.rotation);
      cameraCachePov.fovDegrees = _overriddenFov ?? targetPov.fovDegrees;
      _copyLens(targetPov);
    }
    
    // Apply shakes
    Vector3 totalShakeOffset = Vector3.zero();
    _activeShakes.removeWhere((shake) {
      totalShakeOffset += shake.updateAndGetShake(deltaTime);
      return shake.isFinished;
    });
    
    cameraCachePov.location += totalShakeOffset;
    _publishToWorld();
  }

  /// The clip planes and camera of [pov] onto [cameraCachePov].
  void _copyLens(LuminaMinimalViewInfo pov) {
    cameraCachePov
      ..nearClip = pov.nearClip
      ..farClip = pov.farClip
      ..camera = pov.camera;
  }

  /// Hands the world the POV to render from while the view is not simply
  /// the possessed pawn's own camera: another view target, a running blend,
  /// an FOV override or a shake. Otherwise the world follows its active
  /// camera component as before.
  void _publishToWorld() {
    final pawn = playerController.pawn;
    final world = pawn?.world ?? _viewTarget?.world;
    if (world == null) return;
    final plain = identical(_viewTarget, pawn) && !isBlending && _overriddenFov == null && _activeShakes.isEmpty;
    world.viewTargetPov = plain ? null : cameraCachePov;
  }

  void _updateViewTarget() {
    if (_viewTarget == null || _viewTarget!.isDestroyed) {
      _viewTarget = playerController.pawn;
    }
    if (_pendingViewTarget != null && _pendingViewTarget!.isDestroyed) {
      _pendingViewTarget = null;
    }
  }

  LuminaMinimalViewInfo _evaluatePov(LuminaActor? actor) {
    final pov = LuminaMinimalViewInfo();
    
    if (actor != null) {
      // An actor's own camera component wins: a pawn with a spring-arm
      // camera is seen through it, a pawn without one through its eyes
      // (view targets).
      LuminaCameraComponent? cam;
      for (var comp in actor.components) {
        if (comp is LuminaCameraComponent && (cam == null || (comp.isActive && !cam.isActive))) {
          cam = comp;
        }
      }
      if (cam != null) {
        pov.location = cam.worldLocation;
        pov.rotation = cam.worldRotation;
        pov.fovDegrees = cam.fieldOfViewInDegrees;
        pov.nearClip = cam.nearClipPlane;
        pov.farClip = cam.farClipPlane;
        pov.camera = cam;
      } else if (actor is LuminaPawn) {
        final eyes = actor.getActorEyesViewPoint();
        pov.location = eyes.location;
        // The pawn's view rotation is a control rotation (pitch X, yaw Y,
        // roll Z degrees): the camera's own convention.
        pov.rotation = luminaControlRotationToQuaternion(eyes.rotation.x, eyes.rotation.y, eyes.rotation.z);
      } else {
        pov.location = actor.actorLocation;
        pov.rotation = actor.actorRotation;
        pov.fovDegrees = 90.0;
      }
    }
    
    return pov;
  }

  double _applyBlendFunction(double alpha) {
    final a = alpha.clamp(0.0, 1.0);
    switch (_blendFunction) {
      case LuminaViewTargetBlendFunction.linear:
        return a;
      case LuminaViewTargetBlendFunction.cubic:
        return math.pow(a, _blendExponent).toDouble();
      case LuminaViewTargetBlendFunction.easeIn:
        return math.pow(a, _blendExponent).toDouble();
      case LuminaViewTargetBlendFunction.easeOut:
        return 1.0 - math.pow(1.0 - a, _blendExponent).toDouble();
      case LuminaViewTargetBlendFunction.easeInOut:
        if (a < 0.5) {
          return 0.5 * math.pow(2.0 * a, _blendExponent);
        } else {
          return 1.0 - 0.5 * math.pow(2.0 * (1.0 - a), _blendExponent);
        }
    }
  }

  Quaternion _slerp(Quaternion q1, Quaternion q2, double t) {
    double cosHalfTheta = q1.w * q2.w + q1.x * q2.x + q1.y * q2.y + q1.z * q2.z;
    Quaternion q2Mod = q2.clone();

    if (cosHalfTheta < 0) {
      q2Mod.setValues(-q2.x, -q2.y, -q2.z, -q2.w);
      cosHalfTheta = -cosHalfTheta;
    }

    if (cosHalfTheta >= 1.0) {
      return q1.clone();
    }

    double halfTheta = math.acos(cosHalfTheta);
    double sinHalfTheta = math.sqrt(1.0 - cosHalfTheta * cosHalfTheta);

    if (sinHalfTheta < 0.001) {
      return Quaternion(
        q1.x * 0.5 + q2Mod.x * 0.5,
        q1.y * 0.5 + q2Mod.y * 0.5,
        q1.z * 0.5 + q2Mod.z * 0.5,
        q1.w * 0.5 + q2Mod.w * 0.5,
      )..normalize();
    }

    double ratioA = math.sin((1 - t) * halfTheta) / sinHalfTheta;
    double ratioB = math.sin(t * halfTheta) / sinHalfTheta;

    return Quaternion(
      q1.x * ratioA + q2Mod.x * ratioB,
      q1.y * ratioA + q2Mod.y * ratioB,
      q1.z * ratioA + q2Mod.z * ratioB,
      q1.w * ratioA + q2Mod.w * ratioB,
    );
  }
}
