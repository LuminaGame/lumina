part of '../blueprint_function_library.dart';

// --- Lumina | Engine -------------------------------------------

LuminaWorld? _worldOf(LuminaActor self) => self.world;

double _getFrameRate(LuminaActor self) => _worldOf(self)?.frameRate ?? 0.0;

double _getFrameTimeMs(LuminaActor self) => _worldOf(self)?.lastFrameTimeMs ?? 0.0;

int _getFrameNumber(LuminaActor self) => _worldOf(self)?.frameNumber ?? 0;

double _getWorldDeltaSeconds(LuminaActor self) => _worldOf(self)?.deltaSeconds ?? 0.0;

double _getGameTimeInSeconds(LuminaActor self) => _worldOf(self)?.timeSeconds ?? 0.0;

double _getRealTimeSeconds(LuminaActor self) => _worldOf(self)?.realTimeSeconds ?? 0.0;

int _getActorCount(LuminaActor self) => _worldOf(self)?.actors.length ?? 0;

double _getTimeDilation(LuminaActor self) => _worldOf(self)?.timeDilation ?? 1.0;

void _setTimeDilation(LuminaActor self, [double timeDilation = 1.0]) {
  _worldOf(self)?.timeDilation = timeDilation < 0.0 ? 0.0 : timeDilation;
}

String _getPlatformName() {
  if (kIsWeb) return 'Web';
  final n = defaultTargetPlatform.name;
  return n == 'iOS' ? 'IOS' : n == 'macOS' ? 'MacOS' : n[0].toUpperCase() + n.substring(1);
}

bool _isEditor() => LuminaBlueprintRuntime.isEditor;

void _quitGame(LuminaActor self) {
  if (LuminaBlueprintRuntime.isEditor && LuminaGame.onQuitRequested == null) {
    developer.log('Quit Game: no Play-In-Editor session handles it.', name: 'Blueprint');
    return;
  }
  LuminaGame.requestQuit();
}

final RegExp _layerChannel = RegExp(r'^layer\s*([0-9]{1,2})$', caseSensitive: false);

bool _isTraceChannel(String channel) {
  if (LuminaBlueprintFunctionLibrary.traceChannels.any((c) => c.toLowerCase() == channel.trim().toLowerCase())) return true;
  final m = _layerChannel.firstMatch(channel.trim());
  if (m == null) return false;
  final n = int.parse(m.group(1)!);
  return n >= 1 && n <= 32;
}

({int layerMask, Set<CollisionObjectType>? objectTypes}) _channel(String channel) {
  switch (channel.trim().toLowerCase()) {
    case 'worldstatic':
      return (layerMask: CollisionLayers.all, objectTypes: {CollisionObjectType.worldStatic});
    case 'worlddynamic':
      return (layerMask: CollisionLayers.all, objectTypes: {CollisionObjectType.worldDynamic});
    case 'pawn':
      return (layerMask: CollisionLayers.all, objectTypes: {CollisionObjectType.pawn});
  }
  final m = _layerChannel.firstMatch(channel.trim());
  if (m != null) {
    final n = int.parse(m.group(1)!);
    if (n >= 1 && n <= 32) return (layerMask: CollisionLayers.layer(n), objectTypes: null);
  }
  return (layerMask: CollisionLayers.all, objectTypes: null);
}

List<LuminaActor> _actorList(Object? v) => [for (final o in LuminaBlueprintFunctionLibrary.arrayItems(v)) if (o is LuminaActor) o];

bool Function(LuminaActor)? _classFilter(String cls) =>
    cls.isEmpty || cls == LuminaBlueprintObjectClass.any || cls == LuminaBlueprintObjectClass.anyActor
        ? null
        : (a) => LuminaBlueprintFunctionLibrary.isA(a, cls);

Map<String, Object?> _hitToMap(HitResult h) => LuminaBlueprintFunctionLibrary.makeHitResult(h.blockingHit, LuminaBlueprintFunctionLibrary.toAuthoring(h.location),
    LuminaBlueprintFunctionLibrary.toAuthoring(h.impactPoint), LuminaBlueprintFunctionLibrary.toAuthoring(h.impactNormal), h.distance, h.actor, h.component);

Map<String, Object?> _hitEventOutputs(LuminaActor self, LuminaActor other, HitResult hit) => {
      'self_actor': self,
      'other_actor': other,
      // A physics contact's impulse, else the overlap depth.
      'normal_impulse': LuminaBlueprintFunctionLibrary.toAuthoring(hit.impactNormal * (hit.normalImpulse > 0 ? hit.normalImpulse : hit.penetrationDepth)),
      'hit': LuminaBlueprintFunctionLibrary.hitToMap(hit),
      'hit_normal': LuminaBlueprintFunctionLibrary.toAuthoring(hit.impactNormal),
      'impact_point': LuminaBlueprintFunctionLibrary.toAuthoring(hit.impactPoint),
    };

/// Records a trace segment for the editor's debug draw when [drawDebug]
/// is set: red where it went, green up to the hit.
void _debugTrace(LuminaActor self, Vector3 start, Vector3 end, bool drawDebug, HitResult? hit, {String? nodeId}) {
  if (!drawDebug) return;
  final world = self.world;
  if (world == null) return;
  final now = world.realTimeSeconds;
  final shapes = <LuminaDebugShape>[];
  if (hit != null && hit.blockingHit) {
    shapes.add(LuminaDebugShape(
        kind: LuminaDebugShapeKind.line, points: [start.clone(), hit.impactPoint.clone()], color: const [0.0, 1.0, 0.0, 1.0], expiresAt: now, nodeId: nodeId));
    shapes.add(LuminaDebugShape(
        kind: LuminaDebugShapeKind.point, points: [hit.impactPoint.clone()], color: const [0.0, 1.0, 0.0, 1.0], radius: 8.0, expiresAt: now, nodeId: nodeId));
    shapes.add(LuminaDebugShape(
        kind: LuminaDebugShapeKind.line, points: [hit.impactPoint.clone(), end.clone()], color: const [1.0, 0.0, 0.0, 1.0], expiresAt: now, nodeId: nodeId));
  } else {
    shapes.add(LuminaDebugShape(
        kind: LuminaDebugShapeKind.line, points: [start.clone(), end.clone()], color: const [1.0, 0.0, 0.0, 1.0], expiresAt: now, nodeId: nodeId));
  }
  for (final shape in shapes) {
    world.addDebugShape(shape);
  }
  _runtime(self)?.debugShapes.addAll(shapes);
}

LuminaCollisionSubsystem? _collision(LuminaActor self) => self.world?.getSubsystem<LuminaCollisionSubsystem>();

({Map<String, Object?> outHit, bool returnValue}) _lineTraceByChannel(LuminaActor self, Vector3 start, Vector3 end,
    [String channel = 'Visibility', Object? actorsToIgnore, bool drawDebug = false]) {
  final subsystem = _collision(self);
  final ch = _channel(channel);
  final hit = HitResult();
  final rs = LuminaBlueprintFunctionLibrary.toRuntime(start), re = LuminaBlueprintFunctionLibrary.toRuntime(end);
  final found = subsystem != null &&
      subsystem.lineTraceSingle(
          start: rs,
          end: re,
          out: hit,
          ignoreActors: [self, ..._actorList(actorsToIgnore)],
          layerMask: ch.layerMask,
          objectTypes: ch.objectTypes);
  _debugTrace(self, rs, re, drawDebug, found ? hit : null);
  return (outHit: found ? LuminaBlueprintFunctionLibrary.hitToMap(hit) : LuminaBlueprintFunctionLibrary.makeHitResult(false, start, end, Vector3(0, 0, 1), 0.0), returnValue: found);
}

({List<Object?> outHits, bool returnValue}) _multiLineTraceByChannel(LuminaActor self, Vector3 start, Vector3 end,
    [String channel = 'Visibility', Object? actorsToIgnore, bool drawDebug = false]) {
  final subsystem = _collision(self);
  final ch = _channel(channel);
  final rs = LuminaBlueprintFunctionLibrary.toRuntime(start), re = LuminaBlueprintFunctionLibrary.toRuntime(end);
  final hits = subsystem == null
      ? const <HitResult>[]
      : subsystem.lineTraceMulti(
          start: rs, end: re, ignoreActors: [self, ..._actorList(actorsToIgnore)], layerMask: ch.layerMask, objectTypes: ch.objectTypes);
  _debugTrace(self, rs, re, drawDebug, hits.firstOrNull);
  return (outHits: <Object?>[for (final h in hits) LuminaBlueprintFunctionLibrary.hitToMap(h)], returnValue: hits.isNotEmpty);
}

({Map<String, Object?> outHit, bool returnValue}) _sphereTraceByChannel(LuminaActor self, Vector3 start, Vector3 end,
    [double radius = 50.0, String channel = 'Visibility', Object? actorsToIgnore, bool drawDebug = false]) {
  final subsystem = _collision(self);
  final ch = _channel(channel);
  final hit = HitResult();
  final rs = LuminaBlueprintFunctionLibrary.toRuntime(start), re = LuminaBlueprintFunctionLibrary.toRuntime(end);
  final found = subsystem != null &&
      subsystem.sphereTraceSingle(
          start: rs,
          end: re,
          radius: radius,
          out: hit,
          ignoreActors: [self, ..._actorList(actorsToIgnore)],
          layerMask: ch.layerMask,
          objectTypes: ch.objectTypes);
  _debugTrace(self, rs, re, drawDebug, found ? hit : null);
  return (outHit: found ? LuminaBlueprintFunctionLibrary.hitToMap(hit) : LuminaBlueprintFunctionLibrary.makeHitResult(false, start, end, Vector3(0, 0, 1), 0.0), returnValue: found);
}

/// The segment a forward trace covers: from Self's eyes along its look direction.
(Vector3, Vector3) _forwardSegment(LuminaActor self, double distance) {
  final start = LuminaBlueprintFunctionLibrary.getActorEyesViewPoint(self).location;
  return (start, start + LuminaBlueprintFunctionLibrary.getLookForwardDirection(self) * distance);
}

({Map<String, Object?> outHit, bool returnValue}) _lineTraceForward(LuminaActor self,
    [double distance = 1000.0, String channel = 'Visibility', bool drawDebug = false]) {
  final (start, end) = _forwardSegment(self, distance);
  return LuminaBlueprintFunctionLibrary.lineTraceByChannel(self, start, end, channel, null, drawDebug);
}

({List<Object?> outHits, bool returnValue}) _multiLineTraceForward(LuminaActor self,
    [double distance = 1000.0, String channel = 'Visibility', bool drawDebug = false]) {
  final (start, end) = _forwardSegment(self, distance);
  return LuminaBlueprintFunctionLibrary.multiLineTraceByChannel(self, start, end, channel, null, drawDebug);
}

({Map<String, Object?> outHit, bool returnValue}) _sphereTraceForward(LuminaActor self,
    [double distance = 1000.0, double radius = 50.0, String channel = 'Visibility', bool drawDebug = false]) {
  final (start, end) = _forwardSegment(self, distance);
  return LuminaBlueprintFunctionLibrary.sphereTraceByChannel(self, start, end, radius, channel, null, drawDebug);
}

List<Object?> _sphereOverlapActors(LuminaActor self, Vector3 location, [double radius = 100.0, String cls = '', Object? actorsToIgnore]) {
  final subsystem = _collision(self);
  if (subsystem == null) return <Object?>[];
  return List<Object?>.from(subsystem.sphereOverlapActors(LuminaBlueprintFunctionLibrary.toRuntime(location), radius,
      ignoreActors: [self, ..._actorList(actorsToIgnore)], actorFilter: _classFilter(cls)));
}

// --- Self | View -------------------------------------------------

Vector3 _getLookForwardDirection(LuminaActor self) {
  final controller = self is LuminaPawn ? self.controller : null;
  return LuminaBlueprintFunctionLibrary.getForwardVector(controller == null ? LuminaBlueprintFunctionLibrary.getActorRotation(self) : LuminaBlueprintFunctionLibrary.getControlRotation(self));
}

({Vector3 location, LuminaRotator rotation}) _getActorEyesViewPoint(LuminaActor self) {
  if (self is LuminaPawn) {
    final eyes = self.getActorEyesViewPoint();
    return (location: LuminaBlueprintFunctionLibrary.toAuthoring(eyes.location), rotation: LuminaBlueprintFunctionLibrary.fromControlRotation(eyes.rotation));
  }
  return (location: LuminaBlueprintFunctionLibrary.getActorLocation(self), rotation: LuminaBlueprintFunctionLibrary.getActorRotation(self));
}

Vector3 _findLookAtLocation(LuminaActor self, [double distance = 1000.0]) =>
    LuminaBlueprintFunctionLibrary.getActorEyesViewPoint(self).location + LuminaBlueprintFunctionLibrary.getLookForwardDirection(self) * distance;

List<Object?> _getAllActorsOfClass(LuminaActor self, [String cls = LuminaBlueprintObjectClass.anyActor]) {
  final world = self.world;
  if (world == null) return <Object?>[];
  return <Object?>[for (final a in world.actors) if (LuminaBlueprintFunctionLibrary.isA(a, cls)) a];
}

List<Object?> _getAllActorsWithTag(LuminaActor self, [String tag = '']) {
  final world = self.world;
  if (world == null) return <Object?>[];
  return <Object?>[for (final a in world.actors) if (a.tags.contains(tag)) a];
}

List<Object?> _getActorsWithinRadius(LuminaActor self, Vector3 location, [double radius = 500.0, String cls = LuminaBlueprintObjectClass.anyActor]) {
  final world = self.world;
  if (world == null) return <Object?>[];
  final origin = LuminaBlueprintFunctionLibrary.toRuntime(location);
  final found = [for (final a in world.actors) if (LuminaBlueprintFunctionLibrary.isA(a, cls) && (a.actorLocation - origin).length <= radius) a];
  found.sort((a, b) => (a.actorLocation - origin).length2.compareTo((b.actorLocation - origin).length2));
  return List<Object?>.from(found);
}

List<Object?> _getActorsInViewCone(LuminaActor self,
    [String cls = LuminaBlueprintObjectClass.anyActor, double distance = 1000.0, double coneAngle = 45.0]) {
  final world = self.world;
  if (world == null) return <Object?>[];
  final eyes = LuminaBlueprintFunctionLibrary.toRuntime(LuminaBlueprintFunctionLibrary.getActorEyesViewPoint(self).location);
  final forward = LuminaBlueprintFunctionLibrary.toRuntime(LuminaBlueprintFunctionLibrary.getLookForwardDirection(self));
  final cosLimit = math.cos(coneAngle.clamp(0.0, 180.0) * math.pi / 180.0);
  final found = <(double, LuminaActor)>[];
  for (final a in world.actors) {
    if (identical(a, self) || !LuminaBlueprintFunctionLibrary.isA(a, cls)) continue;
    final to = a.actorLocation - eyes;
    final d = to.length;
    if (d > distance) continue;
    final cos = d < 1e-9 ? 1.0 : to.dot(forward) / d;
    if (cos < cosLimit - 1e-9) continue;
    found.add((d, a));
  }
  found.sort((a, b) => a.$1.compareTo(b.$1));
  return <Object?>[for (final f in found) f.$2];
}

Object? _getClosestActorOfClassInDirection(LuminaActor self,
        [String cls = LuminaBlueprintObjectClass.anyActor, double distance = 1000.0, double coneAngle = 45.0]) =>
    LuminaBlueprintFunctionLibrary.getActorsInViewCone(self, cls, distance, coneAngle).firstOrNull;

// --- Camera ---------------------------------------------------------

LuminaPlayerCameraManager? _cameraManager(LuminaActor self) {
  final pc = LuminaBlueprintFunctionLibrary.getPlayerController(self);
  return pc is LuminaPlayerController ? pc.cameraManager : null;
}

void _setViewTarget(LuminaActor self, Object? target) {
  if (target is LuminaActor) _cameraManager(self)?.setViewTarget(target);
}

void _setViewTargetWithBlend(LuminaActor self, Object? target,
    [double blendTime = 0.0, String blendFunc = 'Linear', double blendExp = 2.0]) {
  if (target is! LuminaActor) return;
  final manager = _cameraManager(self);
  if (manager == null) return;
  final function = LuminaBlueprintFunctionLibrary.blendFunctions[blendFunc] ??
      LuminaBlueprintFunctionLibrary.blendFunctions.entries.where((e) => e.key.toLowerCase() == blendFunc.toLowerCase()).firstOrNull?.value ??
      LuminaViewTargetBlendFunction.linear;
  manager.setViewTargetWithBlend(target, blendTime: blendTime, blendFunction: function, blendExponent: blendExp);
}

Object? _getViewTarget(LuminaActor self) {
  final manager = _cameraManager(self);
  if (manager == null) return null;
  return manager.viewTarget ?? (self is LuminaPawn ? self : null);
}

Object? _getPlayerCameraManager(LuminaActor self) => _cameraManager(self);

Object? _getActiveCamera(LuminaActor self) {
  LuminaCameraComponent? first;
  for (final c in self.components) {
    if (c is LuminaCameraComponent) {
      if (c.isActive) return c;
      first ??= c;
    }
  }
  return first;
}

({Vector3 location, Quaternion rotation})? _viewPov(LuminaActor self) {
  final pov = self.world?.viewPov;
  if (pov != null) return (location: pov.location, rotation: pov.rotation);
  final camera = LuminaBlueprintFunctionLibrary.getActiveCamera(self);
  if (camera is LuminaCameraComponent) return (location: camera.worldLocation, rotation: camera.worldRotation);
  return null;
}

Vector3 _getCameraLocation(LuminaActor self) {
  final pov = _viewPov(self);
  return pov == null ? LuminaBlueprintFunctionLibrary.getActorLocation(self) : LuminaBlueprintFunctionLibrary.toAuthoring(pov.location);
}

LuminaRotator _getCameraRotation(LuminaActor self) {
  final pov = _viewPov(self);
  return pov == null ? LuminaBlueprintFunctionLibrary.getActorRotation(self) : _rotator(pov.rotation);
}
