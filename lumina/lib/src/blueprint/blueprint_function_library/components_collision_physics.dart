part of '../blueprint_function_library.dart';

// --- Components ---------------------------------------------

LuminaBlueprintRuntime? _runtime(LuminaActor self) => self is LuminaBlueprintRuntime ? self : null;

Object? _getComponent(LuminaActor self, String component) {
  final runtime = _runtime(self);
  if (runtime != null) return runtime.blueprintComponentNamed(component);
  for (final c in self.components) {
    if (c.componentName == component) return c;
  }
  return null;
}

Object? _getComponentByClass(LuminaActor self, String cls) {
  final name = cls.contains(':') ? LuminaBlueprintObjectClass.name(cls) : cls;
  if (LuminaBlueprintComponents.isA(self.rootComponent, name)) return self.rootComponent;
  for (final c in self.components) {
    if (LuminaBlueprintComponents.isA(c, name)) return c;
  }
  return null;
}

Object? _addComponent(LuminaActor self, String cls, [String name = '']) {
  final type = cls.contains(':') ? LuminaBlueprintObjectClass.name(cls) : cls;
  final id = LuminaBlueprintComponents.nextDynamicId();
  final component = LuminaBlueprintComponents.addDynamic(self, type, name: name.isEmpty ? null : name, id: id);
  final runtime = _runtime(self);
  if (component != null && runtime != null) {
    // So Get <Name> and Get Display Name find it later.
    runtime.blueprintComponentTree = [
      ...runtime.blueprintComponentTree,
      LuminaBlueprintComponent(id: id, name: name.isEmpty ? type.replaceAll('Lumina', '') : name, type: type, parentId: 'root'),
    ];
    runtime.blueprintComponents = {...runtime.blueprintComponents, id: component};
  }
  return component;
}

Quaternion _quat(LuminaRotator r) {
  final e = LuminaBlueprintFunctionLibrary.toControlRotation(r);
  return luminaPawnEulerToQuaternion(e.x, e.y, e.z);
}

LuminaRotator _rotator(Quaternion q) => LuminaBlueprintFunctionLibrary.fromControlRotation(luminaPawnQuaternionToEuler(q));

void _setRelativeLocation(Object? target, Vector3 newLocation) {
  if (target is LuminaSceneComponent) target.relativeLocation = LuminaBlueprintFunctionLibrary.toRuntime(newLocation);
}

void _setRelativeRotation(Object? target, LuminaRotator newRotation) {
  if (target is LuminaSceneComponent) target.relativeRotation = _quat(newRotation);
}

void _setRelativeScale(Object? target, Vector3 newScale) {
  if (target is LuminaSceneComponent) target.relativeScale = Vector3(newScale.x, newScale.z, newScale.y);
}

Vector3 _getRelativeLocation(Object? target) =>
    target is LuminaSceneComponent ? LuminaBlueprintFunctionLibrary.toAuthoring(target.relativeLocation) : Vector3.zero();

LuminaRotator _getRelativeRotation(Object? target) =>
    target is LuminaSceneComponent ? _rotator(target.relativeRotation) : const LuminaRotator.zero();

Vector3 _getRelativeScale(Object? target) {
  if (target is! LuminaSceneComponent) return Vector3(1, 1, 1);
  final s = target.relativeScale;
  return Vector3(s.x, s.z, s.y);
}

void _setWorldLocation(Object? target, Vector3 newLocation) {
  if (target is! LuminaSceneComponent) return;
  final world = LuminaBlueprintFunctionLibrary.toRuntime(newLocation);
  final parent = target.parentComponent;
  if (parent == null) {
    target.relativeLocation = world;
  } else {
    target.relativeLocation = parent.worldRotation.inverted().rotateVector(world - parent.worldLocation);
  }
}

void _setWorldRotation(Object? target, LuminaRotator newRotation) {
  if (target is! LuminaSceneComponent) return;
  final world = _quat(newRotation);
  final parent = target.parentComponent;
  target.relativeRotation = parent == null ? world : (parent.worldRotation.inverted() * world)..normalize();
}

Vector3 _getWorldLocation(Object? target) =>
    target is LuminaSceneComponent ? LuminaBlueprintFunctionLibrary.toAuthoring(target.worldLocation) : Vector3.zero();

LuminaRotator _getWorldRotation(Object? target) =>
    target is LuminaSceneComponent ? _rotator(target.worldRotation) : const LuminaRotator.zero();

void _attachToComponent(Object? target, Object? parent, [String socketName = '']) {
  if (target is! LuminaSceneComponent || parent is! LuminaSceneComponent || identical(target, parent)) return;
  if (socketName.isNotEmpty && parent is LuminaSkinnedMeshComponent) {
    parent.attachToSocket(target, socketName);
    return;
  }
  target.attachToComponent(parent);
}

void _setComponentVisibility(Object? target, [bool newVisibility = true]) {
  if (target is LuminaSceneComponent) target.isVisible = newVisibility;
  if (target is LuminaStaticMeshComponent) target.visible = newVisibility;
}

void _setHiddenInGame(Object? target, [bool newHidden = false]) => LuminaBlueprintFunctionLibrary.setComponentVisibility(target, !newHidden);

Vector3 _getSocketLocation(Object? target, [String inSocketName = '']) {
  if (target is LuminaSkinnedMeshComponent && inSocketName.isNotEmpty && target.findSocket(inSocketName) != null) {
    return LuminaBlueprintFunctionLibrary.toAuthoring(target.getSocketLocation(inSocketName));
  }
  if (target is LuminaSpringArmComponent) return LuminaBlueprintFunctionLibrary.toAuthoring(target.socketWorldLocation);
  return LuminaBlueprintFunctionLibrary.getWorldLocation(target);
}

void _setTargetArmLength(Object? target, [double targetArmLength = 300.0]) {
  if (target is LuminaSpringArmComponent) target.targetArmLength = targetArmLength;
}

double _getTargetArmLength(Object? target) => target is LuminaSpringArmComponent ? target.targetArmLength : 0.0;

void _setCameraLagEnabled(Object? target, [bool enabled = true]) {
  if (target is LuminaSpringArmComponent) target.bEnableCameraLag = enabled;
}

void _setCameraLagSpeed(Object? target, [double speed = 10.0]) {
  if (target is LuminaSpringArmComponent) target.cameraLagSpeed = speed;
}

void _setSocketOffset(Object? target, Vector3 offset) {
  if (target is LuminaSpringArmComponent) target.socketOffset = LuminaBlueprintFunctionLibrary.toRuntime(offset);
}

void _setFieldOfView(Object? target, [double inFieldOfView = 90.0]) {
  if (target is LuminaCameraComponent) target.fieldOfViewInDegrees = inFieldOfView;
}

double _getFieldOfView(Object? target) => target is LuminaCameraComponent ? target.fieldOfViewInDegrees : 0.0;

void _setCameraActive(Object? target, [bool active = true]) {
  if (target is LuminaCameraComponent) active ? target.activate() : target.deactivate();
}

bool _isCameraActive(Object? target) => target is LuminaCameraComponent && target.isActive;

void _playAnimation(Object? target, String clip, [bool loop = true]) {
  if (target is! LuminaAnimatedMeshComponent) return;
  try {
    target.play(clip, loop: loop);
  } on ArgumentError catch (e) {
    developer.log('Play Animation: $e', name: 'Blueprint', level: 900);
  }
}

void _stopAnimation(Object? target) {
  if (target is LuminaAnimatedMeshComponent) target.stop();
}

void _setAnimClass(LuminaActor self, Object? target, [String animClass = '']) {
  if (target is! LuminaAnimatedMeshComponent) return;
  final runtime = _runtime(self);
  if (runtime == null) return;
  String? id;
  for (final e in runtime.blueprintComponents.entries) {
    if (identical(e.value, target)) id = e.key;
  }
  if (id == null) return;
  final old = runtime.blueprintComponents['$id.anim'];
  if (old != null) {
    self.removeComponent(old);
    runtime.blueprintComponents = {...runtime.blueprintComponents}..remove('$id.anim');
  }
  final factory = animClass.isEmpty ? null : runtime.blueprintAnimClasses?.call(animClass);
  if (factory == null) return;
  final anim = factory(target);
  runtime.blueprintComponents = {...runtime.blueprintComponents, '$id.anim': anim};
  self.addComponent(anim);
}

void _setPlayRate(Object? target, [double rate = 1.0]) {
  if (target is LuminaAnimatedMeshComponent) target.playRate = rate;
}

String _getCurrentClip(Object? target) => target is LuminaAnimatedMeshComponent ? target.currentClip ?? '' : '';

void _setStaticMesh(LuminaActor self, Object? target, [String newMesh = '']) {
  if (target is! LuminaStaticMeshComponent || newMesh.isEmpty) return;
  final path = luminaBlueprintMeshPath(newMesh);
  final LuminaStaticMeshComponent replacement = target is LuminaAnimatedMeshComponent
      ? LuminaAnimatedMeshComponent(
          meshAssetPath: path,
          castShadows: target.castShadows,
          receiveShadows: target.receiveShadows,
          assetProvider: target.assetProvider)
      : LuminaStaticMeshComponent(
          meshAssetPath: path,
          castShadows: target.castShadows,
          receiveShadows: target.receiveShadows,
          assetProvider: target.assetProvider);
  replacement
    ..relativeLocation = target.relativeLocation
    ..relativeRotation = target.relativeRotation
    ..relativeScale = target.relativeScale
    ..visible = target.visible;
  final parent = target.parentComponent;
  final children = List.of(target.childComponents);
  if (parent != null) replacement.attachToComponent(parent);
  for (final child in children) {
    child.attachToComponent(replacement);
  }
  final runtime = _runtime(self);
  if (runtime != null) {
    runtime.blueprintComponents = {
      for (final e in runtime.blueprintComponents.entries) e.key: identical(e.value, target) ? replacement : e.value,
    };
  }
  self.removeComponent(target);
  self.addComponent(replacement);
}

void _setMaterial(LuminaActor self, Object? target, [int elementIndex = 0, String material = '']) {
  if (target is! LuminaStaticMeshComponent || material.isEmpty) return;
  final world = self.world;
  if (world == null || !world.hasNativeContext) return;
  target.setMaterialAsset(material, primitiveIndex: elementIndex).catchError((Object e) {
    developer.log('Set Material: cannot load $material: $e', name: 'Blueprint', level: 900);
  });
}

void _setCollisionEnabled(Object? target, [Object? newType = 'QueryAndPhysics']) {
  if (target is! LuminaCollisionComponent) return;
  if (newType is bool) {
    target.collisionEnabled = newType;
    return;
  }
  final key = '$newType'.replaceAll(RegExp(r'[\s_-]'), '').toLowerCase();
  if (key == 'nocollision' || key == 'false') {
    target.collisionEnabled = false;
  } else {
    target.collisionEnabled = true;
    target.generateOverlapEvents = true;
  }
}

// --- Collision presets and shapes ------------------------------

void _setCollisionPreset(Object? target, [String preset = 'BlockAllDynamic']) {
  final p = LuminaCollisionPreset.parse(preset);
  if (target is LuminaCollisionComponent && p != null) target.applyPreset(p);
}

String _getCollisionPreset(Object? target) =>
    target is LuminaCollisionComponent ? target.preset.displayName : '';

void _setCollisionResponseToChannel(Object? target, [String channel = 'Pawn', String response = 'Block']) {
  final t = luminaParseCollisionObjectType(channel);
  final r = luminaParseCollisionResponse(response);
  if (target is LuminaCollisionComponent && t != null && r != null) target.setResponse(t, r);
}

void _setCollisionResponseToAllChannels(Object? target, [String response = 'Block']) {
  final r = luminaParseCollisionResponse(response);
  if (target is LuminaCollisionComponent && r != null) target.setResponseToAll(r);
}

String _getCollisionResponseToChannel(Object? target, [String channel = 'Pawn']) {
  final t = luminaParseCollisionObjectType(channel);
  if (target is! LuminaCollisionComponent || t == null) return '';
  return luminaCollisionResponseName(target.getResponse(t));
}

void _setCollisionObjectType(Object? target, [String objectType = 'WorldDynamic']) {
  final t = luminaParseCollisionObjectType(objectType);
  if (target is LuminaCollisionComponent && t != null) target.objectType = t;
}

String _getCollisionObjectType(Object? target) =>
    target is LuminaCollisionComponent ? luminaCollisionObjectTypeName(target.objectType) : '';

void _setGenerateOverlapEvents(Object? target, [bool generate = true]) {
  if (target is LuminaCollisionComponent) target.generateOverlapEvents = generate;
}

void _setBoxExtent(Object? target, Vector3 boxExtent) {
  if (target is LuminaBoxComponent) target.setBoxExtent(Vector3(boxExtent.x.abs(), boxExtent.z.abs(), boxExtent.y.abs()));
}

Vector3 _getBoxExtent(Object? target) =>
    target is LuminaBoxComponent ? Vector3(target.boxExtent.x, target.boxExtent.z, target.boxExtent.y) : Vector3.zero();

void _setSphereRadius(Object? target, [double radius = 50.0]) {
  if (target is LuminaSphereComponent) target.sphereRadius = radius;
}

double _getSphereRadius(Object? target) => target is LuminaSphereComponent ? target.radius : 0.0;

void _setCapsuleSize(Object? target, [double radius = 40.0, double halfHeight = 80.0]) {
  if (target is LuminaCapsuleComponent) {
    target.capsuleRadius = radius;
    target.capsuleHalfHeight = halfHeight;
  }
}

double _relativeScaleMax(LuminaSceneComponent c) {
  final s = c.relativeScale;
  return math.max(s.x.abs(), s.z.abs());
}

double _getScaledCapsuleRadius(Object? target) =>
    target is LuminaCapsuleComponent ? target.radius * _relativeScaleMax(target) : 0.0;

double _getScaledCapsuleHalfHeight(Object? target) =>
    target is LuminaCapsuleComponent ? target.halfHeight * target.relativeScale.y.abs() : 0.0;

List<Object?> _getOverlappingActors(Object? target, [String cls = '']) {
  if (target is! LuminaCollisionComponent) return <Object?>[];
  final filter = _classFilter(cls);
  final out = <Object?>[];
  for (final c in target.overlappingComponents) {
    final owner = c.owner;
    if (owner == null || identical(owner, target.owner) || out.contains(owner)) continue;
    if (filter != null && !filter(owner)) continue;
    out.add(owner);
  }
  return out;
}

List<Object?> _getOverlappingComponents(Object? target) =>
    target is LuminaCollisionComponent ? List<Object?>.from(target.overlappingComponents) : <Object?>[];

bool _isOverlappingActor(Object? target, Object? other) {
  if (target is! LuminaCollisionComponent || other is! LuminaActor) return false;
  return target.overlappingComponents.any((c) => identical(c.owner, other));
}

// --- Physics ------------------------------------------------------
// Vectors are authoring space (cm, Z up); angular vectors follow the same
// axes. Impulses are kg·cm/s, forces kg·cm/s², torques kg·cm²/s², masses kg.
// [boneName] is accepted but ignored; a component is one body.

/// −0.0 (a flipped axis of a zero) reads as 0.
Vector3 _noNegativeZero(Vector3 v) => Vector3(v.x + 0.0, v.y + 0.0, v.z + 0.0);

LuminaPrimitivePhysics? _primitive(Object? target) => target is LuminaPrimitivePhysics ? target : null;

void _setSimulatePhysics(Object? target, [bool simulate = true]) => _primitive(target)?.simulatePhysics = simulate;

bool _isSimulatingPhysics(Object? target) => _primitive(target)?.isSimulatingPhysics ?? false;

void _addImpulse(Object? target, Vector3 impulse, [String boneName = '', bool velChange = false]) =>
    _primitive(target)?.addImpulse(LuminaBlueprintFunctionLibrary.toRuntime(impulse), velocityChange: velChange);

void _addImpulseAtLocation(Object? target, Vector3 impulse, Vector3 location, [String boneName = '']) =>
    _primitive(target)?.addImpulseAtLocation(LuminaBlueprintFunctionLibrary.toRuntime(impulse), LuminaBlueprintFunctionLibrary.toRuntime(location));

void _addForce(Object? target, Vector3 force, [String boneName = '', bool accelChange = false]) =>
    _primitive(target)?.addForce(LuminaBlueprintFunctionLibrary.toRuntime(force), accelChange: accelChange);

void _addForceAtLocation(Object? target, Vector3 force, Vector3 location, [String boneName = '']) =>
    _primitive(target)?.addForceAtLocation(LuminaBlueprintFunctionLibrary.toRuntime(force), LuminaBlueprintFunctionLibrary.toRuntime(location));

void _addTorqueInRadians(Object? target, Vector3 torque, [String boneName = '', bool accelChange = false]) =>
    _primitive(target)?.addTorque(LuminaBlueprintFunctionLibrary.toRuntime(torque), accelChange: accelChange);

void _addAngularImpulseInRadians(Object? target, Vector3 impulse, [String boneName = '', bool velChange = false]) =>
    _primitive(target)?.addAngularImpulse(LuminaBlueprintFunctionLibrary.toRuntime(impulse), velocityChange: velChange);

void _setPhysicsLinearVelocity(Object? target, Vector3 newVel, [bool addToCurrent = false, String boneName = '']) =>
    _primitive(target)?.setPhysicsLinearVelocity(LuminaBlueprintFunctionLibrary.toRuntime(newVel), addToCurrent: addToCurrent);

Vector3 _getPhysicsLinearVelocity(Object? target, [String boneName = '']) {
  final p = _primitive(target);
  return p == null ? Vector3.zero() : _noNegativeZero(LuminaBlueprintFunctionLibrary.toAuthoring(p.physicsLinearVelocity));
}

void _setPhysicsAngularVelocityInDegrees(Object? target, Vector3 newAngVel,
        [bool addToCurrent = false, String boneName = '']) =>
    _primitive(target)?.setPhysicsAngularVelocity(LuminaBlueprintFunctionLibrary.toRuntime(newAngVel) * (math.pi / 180.0), addToCurrent: addToCurrent);

Vector3 _getPhysicsAngularVelocityInDegrees(Object? target, [String boneName = '']) {
  final p = _primitive(target);
  return p == null ? Vector3.zero() : _noNegativeZero(LuminaBlueprintFunctionLibrary.toAuthoring(p.physicsAngularVelocity) * (180.0 / math.pi));
}

double _getMass(Object? target) => _primitive(target)?.resolvedMassKg ?? 0.0;

void _setMassOverrideInKg(Object? target, [String boneName = '', double massInKg = 1.0, bool overrideMass = true]) {
  final p = _primitive(target);
  if (p == null) return;
  p.massKg = massInKg;
  p.overrideMass = overrideMass;
}

void _setEnableGravity(Object? target, [bool gravityEnabled = true]) => _primitive(target)?.enableGravity = gravityEnabled;

void _setLinearDamping(Object? target, [double damping = 0.01]) => _primitive(target)?.linearDamping = damping;

void _setAngularDamping(Object? target, [double damping = 0.0]) => _primitive(target)?.angularDamping = damping;

void _wakeRigidBody(Object? target, [String boneName = '']) => _primitive(target)?.wakeRigidBody();

void _putRigidBodyToSleep(Object? target, [String boneName = '']) => _primitive(target)?.putRigidBodyToSleep();

bool _isAnyRigidBodyAwake(Object? target) => _primitive(target)?.isAnyRigidBodyAwake ?? false;

void _setCollisionLayer(Object? target, [int layer = 1]) {
  if (target is LuminaCollisionComponent) target.collisionLayer = layer;
}

LuminaCharacterMovementComponent? _movementOf(LuminaActor self, Object? target) =>
    target is LuminaCharacterMovementComponent ? target : _movement(self);

void _setMaxWalkSpeed(LuminaActor self, Object? target, [double maxWalkSpeed = 600.0]) =>
    _movementOf(self, target)?.maxWalkSpeed = maxWalkSpeed;

double _getMaxWalkSpeed(LuminaActor self, Object? target) => _movementOf(self, target)?.maxWalkSpeed ?? 0.0;

void _setJumpZVelocity(LuminaActor self, Object? target, [double jumpZVelocity = 500.0]) =>
    _movementOf(self, target)?.jumpZVelocity = jumpZVelocity;

double _getJumpZVelocity(LuminaActor self, Object? target) => _movementOf(self, target)?.jumpZVelocity ?? 0.0;

void _setGravityScale(LuminaActor self, Object? target, [double gravityScale = 1.0]) =>
    _movementOf(self, target)?.gravityScale = gravityScale;

double _getGravityScale(LuminaActor self, Object? target) => _movementOf(self, target)?.gravityScale ?? 0.0;

void _setAirControl(LuminaActor self, Object? target, [double airControl = 0.35]) =>
    _movementOf(self, target)?.airControl = airControl;

double _getAirControl(LuminaActor self, Object? target) => _movementOf(self, target)?.airControl ?? 0.0;

void _setMovementMode(LuminaActor self, Object? target, [String newMovementMode = 'Walking']) {
  final mode = LuminaBlueprintFunctionLibrary.movementModes[newMovementMode];
  if (mode != null) _movementOf(self, target)?.setMovementMode(mode);
}

String _getMovementMode(LuminaActor self, Object? target) {
  final mode = _movementOf(self, target)?.movementMode;
  if (mode == null) return 'None';
  return LuminaBlueprintFunctionLibrary.movementModes.entries.firstWhere((e) => e.value == mode).key;
}

void _crouch(LuminaActor self, Object? target) => _movementOf(self, target)?.crouch();

void _unCrouch(LuminaActor self, Object? target) => _movementOf(self, target)?.unCrouch();

bool _isCrouched(LuminaActor self, Object? target) => _movementOf(self, target)?.isCrouched ?? false;

void _launchCharacter(LuminaActor self, Object? target, Vector3 launchVelocity,
        [bool xyOverride = false, bool zOverride = false]) =>
    _movementOf(self, target)?.launch(LuminaBlueprintFunctionLibrary.toRuntime(launchVelocity), xyOverride: xyOverride, zOverride: zOverride);

void _stopMovementImmediately(LuminaActor self, Object? target) =>
    _movementOf(self, target)?.stopMovementImmediately();
