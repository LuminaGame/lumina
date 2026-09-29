import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina_runtime.dart'; // for LuminaPawn

class LuminaSpringArmComponent extends LuminaSceneComponent {
  double targetArmLength = 300.0; // cm
  Vector3 targetOffset = Vector3.zero();
  Vector3 socketOffset = Vector3.zero();

  bool bEnableCameraLag = true;
  double cameraLagSpeed = 10.0;
  bool bEnableCameraRotationLag = true;
  double cameraRotationLagSpeed = 10.0;
  double cameraLagMaxDistance = 0.0;
  
  bool bUsePawnControlRotation = false;
  bool bInheritPitch = true;
  bool bInheritYaw = true;
  bool bInheritRoll = true;

  bool bDoCollisionTest = true;
  double probeSize = 20.0; // Sphere sweep radius, cm
  double armRecoverySpeed = 5.0;
  int probeChannelMask = 0xFFFFFFFF; // Defaults to all for now
  
  bool get isCollisionAdjusted => _currentArmLength < targetArmLength;
  Vector3 get unfixedSocketWorldLocation => _unfixedSocketWorldLocation;

  double _currentArmLength = 300.0;
  
  final Vector3 _lagLocation = Vector3.zero();
  final Quaternion _currentRotation = Quaternion.identity();
  final Vector3 _socketWorldLocation = Vector3.zero();
  final Vector3 _unfixedSocketWorldLocation = Vector3.zero();
  final Quaternion _socketWorldRotation = Quaternion.identity();
  
  // Scratch objects for zero-allocation tick
  final Quaternion _scratchQuat = Quaternion.identity();
  final Vector3 _scratchVec = Vector3.zero();
  final Vector3 _armOrigin = Vector3.zero();
  final Vector3 _forwardVec = Vector3.zero();
  final Matrix4 _scratchMatrix = Matrix4.identity();
  final HitResult _hitResult = HitResult();

  LuminaSpringArmComponent({
    super.key,
    super.location,
    super.rotation,
    this.targetArmLength = 300.0,
  }) {
    _currentArmLength = targetArmLength;
  }

  double get currentArmLength => _currentArmLength;

  /// Calculates desired socket location in world space.
  Vector3 get socketWorldLocation => _socketWorldLocation.clone();
  
  /// Calculates desired socket rotation in world space.
  Quaternion get socketWorldRotation => _socketWorldRotation.clone();

  Quaternion getDesiredRotation({Quaternion? out}) {
    final result = out ?? Quaternion.identity();
    // An axis the boom does not inherit keeps the boom's own relative angle.
    // Both rotations are read in the control-rotation convention, the exact
    // inverse of `luminaControlRotationToQuaternion`.
    final relative = luminaQuaternionToControlRotation(relativeRotation);
    if (bUsePawnControlRotation && owner is LuminaPawn) {
      final pawn = owner as LuminaPawn;
      if (pawn.controller != null) {
        // The control rotation is in degrees.
        final controlRot = pawn.controller!.controlRotation;
        final cpitch = bInheritPitch ? controlRot.x : relative.x;
        final cyaw = bInheritYaw ? controlRot.y : relative.y;
        final croll = bInheritRoll ? controlRot.z : relative.z;
        return luminaControlRotationToQuaternion(cpitch, cyaw, croll, out: result);
      }
    }

    final world = luminaQuaternionToControlRotation(worldRotation);
    final cpitch = bInheritPitch ? world.x : relative.x;
    final cyaw = bInheritYaw ? world.y : relative.y;
    final croll = bInheritRoll ? world.z : relative.z;
    return luminaControlRotationToQuaternion(cpitch, cyaw, croll, out: result);
  }

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    
    // 1) Desired rotation
    getDesiredRotation(out: _scratchQuat);
    if (bEnableCameraRotationLag) {
      rInterpTo(_currentRotation, _scratchQuat, deltaTime, cameraRotationLagSpeed, out: _currentRotation);
    } else {
      _currentRotation.setFrom(_scratchQuat);
    }
    
    // 2) Arm origin
    _armOrigin.setFrom(targetOffset);
    _armOrigin.applyQuaternion(_currentRotation);
    _armOrigin.add(worldLocation);
    
    // 3) Location lag
    if (bEnableCameraLag) {
      vInterpTo(_lagLocation, _armOrigin, deltaTime, cameraLagSpeed, out: _lagLocation);
      if (cameraLagMaxDistance > 0.0) {
        _scratchVec.setFrom(_lagLocation);
        _scratchVec.sub(_armOrigin);
        if (_scratchVec.length > cameraLagMaxDistance) {
          _scratchVec.normalize();
          _scratchVec.scale(cameraLagMaxDistance);
          _lagLocation.setFrom(_armOrigin);
          _lagLocation.add(_scratchVec);
        }
      }
    } else {
      _lagLocation.setFrom(_armOrigin);
    }
    
    // 4) Desired socket
    _forwardVec.setValues(0, 0, -1);
    _forwardVec.applyQuaternion(_currentRotation); // -Z is forward for camera
    
    // Calculate unfixed target location
    _scratchVec.setFrom(_forwardVec);
    _scratchVec.scale(-targetArmLength);
    
    _unfixedSocketWorldLocation.setFrom(_lagLocation);
    _unfixedSocketWorldLocation.add(_scratchVec);
    
    _scratchVec.setFrom(socketOffset);
    _scratchVec.applyQuaternion(_currentRotation);
    _unfixedSocketWorldLocation.add(_scratchVec);
    
    // 5) Collision pull-in
    bool bHit = false;
    if (bDoCollisionTest && owner?.world != null) {
      final collisionSystem = owner!.world!.getSubsystem<LuminaCollisionSubsystem>();
      
      if (collisionSystem != null) {
        final delta = _unfixedSocketWorldLocation.clone();
        delta.sub(_lagLocation);
        
        _scratchMatrix.setIdentity();
        _scratchMatrix.setTranslation(_lagLocation);
        
        final shape = SphereShape(probeSize);
        _hitResult.reset();
        
        if (collisionSystem.sweep(shape, _scratchMatrix, delta, _hitResult, layerMask: probeChannelMask)) {
          if (_hitResult.blockingHit) {
            if (_hitResult.component != null && _hitResult.component!.owner == owner) {
              // Ignored owner component hit
            } else {
              bHit = true;
              // Snap instantly to hit
              _currentArmLength = targetArmLength * _hitResult.time;
            }
          }
        }
      }
    }
    
    if (!bHit) {
      if (_currentArmLength < targetArmLength) {
        // Recover gradually
        _currentArmLength += (targetArmLength - _currentArmLength) * (deltaTime * armRecoverySpeed);
        if (_currentArmLength > targetArmLength) {
          _currentArmLength = targetArmLength;
        }
      } else {
        _currentArmLength = targetArmLength;
      }
    }

    // Now calculate the real socketWorldLocation using _currentArmLength
    _forwardVec.scale(-_currentArmLength);
    _socketWorldLocation.setFrom(_lagLocation);
    _socketWorldLocation.add(_forwardVec);
    _socketWorldLocation.add(_scratchVec); // scratchVec still holds rotated socketOffset
    
    _socketWorldRotation.setFrom(_currentRotation);

    // 6) Write socket transform to every attached child
    for (final child in childComponents) {
      // Child relative location = socketWorldLocation - child's parent's world location (which is arm worldLocation? No, child parent is ARM)
      // Actually, we want child.worldLocation = socketWorldLocation.
      // So relative = socketWorldLocation in local space of ARM.
      
      // Let's invert ARM's world transform
      _scratchVec.setFrom(_socketWorldLocation);
      _scratchVec.sub(worldLocation);
      
      final invRot = worldRotation.clone();
      invRot.inverse();
      _scratchVec.applyQuaternion(invRot);
      
      child.relativeLocation.setFrom(_scratchVec);
      
      _scratchQuat.setFrom(_socketWorldRotation);
      final childRelRot = invRot * _scratchQuat;
      child.relativeRotation.setFrom(childRelRot);
    }
  }
}
