import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/components/base/actor_component.dart';
import 'package:lumina/src/components/mesh/pose_authoring/pose_authoring_component.dart';
import 'package:lumina/src/components/mesh/pose_authoring/pose_handle.dart';
import 'package:lumina/src/interaction/grab/grabber.dart';
import 'package:lumina/src/interaction/grab/mouse_grabber.dart';
import 'package:lumina/src/interaction/grab/pose_handle_visuals.dart';

/// A pose handle of one character.
typedef LuminaPoseHandleRef = ({LuminaPoseAuthoringComponent poser, String handle});

class _GrabberState {
  bool pressed = false;
  LuminaPoseHandleRef? hovered;
  LuminaPoseHandleRef? held;
  Matrix4? offset;
}

/// Grab-to-pose: grabbers (tracked controllers, the mouse) pick up the pose
/// handles of characters in reach, drag them, and let go of them where they
/// are, so the pose stays.
///
/// Per frame, per grabber:
/// - **Hover**: the nearest handle within [grabRadius] (per handle:
///   [handleRadius], head 12 cm, pelvis 15 cm), else with a ray the handle
///   within [rayAngleDegrees] of it up to [rayMaxDistance].
/// - **Grab** when the grip crosses [pressThreshold] (it lets go below
///   [releaseThreshold]): the handle's pose relative to the grabber is kept
///   (no jump), a 0.5 / 30 ms haptic pulse, [onHandleGrabbed], the
///   character's targets pushed as an undo step. A grabber taking a handle
///   another holds steals it (both pulse).
/// - **Drag**: the handle's target is the grabber's pose times that offset,
///   set before the character's solve (through its `beforeSolve`); hands,
///   feet and the head follow the grabber's rotation too.
/// - **Release**: the handle keeps its last target, a 0.2 / 15 ms pulse,
///   [onHandleReleased].
///
/// Characters come from [register] or, with [findPosersInReach], from every
/// pose authoring component of the world within [reach] cm of a grabber.
class LuminaPoseGrabInteractor extends LuminaActorComponent {
  LuminaPoseGrabInteractor({
    super.key,
    this.grabRadius = 8.0,
    Map<String, double>? handleRadius,
    this.rayAngleDegrees = 3.0,
    this.rayMaxDistance = 300.0,
    this.pressThreshold = 0.7,
    this.releaseThreshold = 0.3,
    this.reach = 300.0,
    this.findPosersInReach = true,
    this.useMouse = false,
    this.showHandles = true,
    this.idleAlpha = 0.2,
  }) : handleRadius = handleRadius ?? {'head': 12.0, 'pelvis': 15.0};

  /// Builds the component from its Blueprint / level JSON properties.
  factory LuminaPoseGrabInteractor.fromProperties(Map<String, dynamic> p) => LuminaPoseGrabInteractor(
        grabRadius: p['grabRadius'] is num ? (p['grabRadius'] as num).toDouble() : 8.0,
        useMouse: p['useMouse'] == true,
        showHandles: p['showHandles'] != false,
      );

  double grabRadius;
  final Map<String, double> handleRadius;
  double rayAngleDegrees;
  double rayMaxDistance;
  double pressThreshold;
  double releaseThreshold;
  double reach;
  bool findPosersInReach;

  /// Drive a [LuminaMouseGrabber] from the world's view and input (desktop,
  /// Play-In-Editor).
  bool useMouse;

  /// Draw the handles in reach ([LuminaPoseHandleVisuals]).
  bool showHandles;

  /// Alpha of a handle in reach that is neither hovered nor held (0 hides).
  double idleAlpha;

  void Function(LuminaPoseHandleRef handle, String grabber)? onHandleGrabbed;
  void Function(LuminaPoseHandleRef handle, String grabber)? onHandleReleased;
  void Function(LuminaPoseHandleRef? handle, String grabber)? onHandleHovered;

  final List<LuminaGrabber> _grabbers = [];
  final Map<LuminaGrabber, _GrabberState> _states = {};
  final List<LuminaPoseAuthoringComponent> _registered = [];
  final Set<LuminaPoseAuthoringComponent> _hooked = {};
  final List<LuminaPoseAuthoringComponent> _grabHistory = [];
  LuminaMouseGrabber? _mouse;
  LuminaPoseHandleVisuals? _visuals;
  int _lastFrame = -1;

  /// The grabbers in use.
  List<LuminaGrabber> get grabbers => List.unmodifiable(_grabbers);

  /// The mouse grabber [useMouse] drives, once created.
  LuminaMouseGrabber? get mouseGrabber => _mouse;

  /// The handle [grabber] hovers, or null.
  LuminaPoseHandleRef? hoveredBy(LuminaGrabber grabber) => _states[grabber]?.hovered;

  /// The handle [grabber] holds, or null.
  LuminaPoseHandleRef? heldBy(LuminaGrabber grabber) => _states[grabber]?.held;

  void registerGrabber(LuminaGrabber grabber) {
    if (_grabbers.contains(grabber)) return;
    _grabbers.add(grabber);
    _states[grabber] = _GrabberState();
  }

  void unregisterGrabber(LuminaGrabber grabber) {
    final s = _states.remove(grabber);
    _grabbers.remove(grabber);
    if (s?.held != null) _release(grabber, s!, pulse: false);
  }

  /// Makes [poser]'s handles grabbable (in addition to those found in reach).
  void register(LuminaPoseAuthoringComponent poser) {
    if (!_registered.contains(poser)) _registered.add(poser);
    _hook(poser);
  }

  void unregister(LuminaPoseAuthoringComponent poser) {
    _registered.remove(poser);
    poser.beforeSolve.remove(_beforeSolve);
    _hooked.remove(poser);
  }

  void _hook(LuminaPoseAuthoringComponent poser) {
    if (_hooked.add(poser)) poser.beforeSolve.add(_beforeSolve);
  }

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    if (useMouse && _mouse == null) {
      _mouse = LuminaMouseGrabber();
      registerGrabber(_mouse!);
    }
  }

  @override
  void onUnregister() {
    for (final p in _hooked) {
      p.beforeSolve.remove(_beforeSolve);
    }
    _hooked.clear();
    _visuals?.dispose();
    _visuals = null;
    super.onUnregister();
  }

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    _once(deltaTime);
    _drawHandles();
  }

  /// A character is about to solve: the grabbers drive their handles first
  /// (once per world frame).
  void _beforeSolve(double deltaTime) => _once(deltaTime);

  void _once(double deltaTime) {
    final frame = world?.frameNumber;
    if (frame != null && frame == _lastFrame) return;
    if (frame != null) _lastFrame = frame;
    update(deltaTime);
  }

  /// The characters whose handles can be grabbed now.
  List<LuminaPoseAuthoringComponent> get posers {
    final out = <LuminaPoseAuthoringComponent>[..._registered];
    final w = world;
    if (findPosersInReach && w != null) {
      for (final actor in w.actors) {
        for (final p in actor.components.whereType<LuminaPoseAuthoringComponent>()) {
          if (out.contains(p) || p.rig == null) continue;
          final pelvis = p.handleWorldLocation('pelvis') ?? p.handleWorldLocation('chest');
          if (pelvis == null) continue;
          if (_grabbers.any((g) => g.worldTransform.getTranslation().distanceTo(pelvis) <= reach + 100 ||
              (g.ray != null && g.ray!.origin.distanceTo(pelvis) <= rayMaxDistance + 100))) {
            out.add(p);
          }
        }
      }
    }
    for (final p in out) {
      _hook(p);
    }
    return out;
  }

  double radiusOf(String handle) => handleRadius[handle] ?? grabRadius;

  /// One step of the interaction (what [onTick] and the characters' solves
  /// run once per frame; tests call it directly).
  void update(double deltaTime) {
    final mouse = _mouse;
    final w = world;
    if (mouse != null && w != null) mouse.syncFromWorld(w);
    final candidates = posers;
    for (final g in List.of(_grabbers)) {
      final s = _states[g]!;
      if (!g.isTracked) {
        if (s.held != null) _release(g, s);
        s.pressed = false;
        _hover(g, s, null);
        continue;
      }
      final grip = g.grip;
      final wasPressed = s.pressed;
      s.pressed = wasPressed ? grip > releaseThreshold : grip > pressThreshold;
      if (s.held != null && !s.pressed) {
        _release(g, s);
      }
      if (s.held == null) {
        _hover(g, s, _pick(g, candidates));
        if (s.pressed && !wasPressed && s.hovered != null) _grab(g, s, s.hovered!);
      }
      final held = s.held;
      if (held != null) _drag(g, s, held);
    }
  }

  /// The handle [g] would grab: the nearest within its radius, else the one
  /// nearest its ray within the ray's cone.
  LuminaPoseHandleRef? _pick(LuminaGrabber g, List<LuminaPoseAuthoringComponent> candidates) {
    final at = g.worldTransform.getTranslation();
    LuminaPoseHandleRef? best;
    var bestDistance = double.infinity;
    for (final p in candidates) {
      for (final name in p.handles.keys) {
        final h = p.handleWorldLocation(name);
        if (h == null) continue;
        final d = h.distanceTo(at);
        if (d <= radiusOf(name) && d < bestDistance) {
          best = (poser: p, handle: name);
          bestDistance = d;
        }
      }
    }
    if (best != null) return best;
    final ray = g.ray;
    if (ray == null) return null;
    final cone = rayAngleDegrees * math.pi / 180;
    var bestAngle = double.infinity;
    for (final p in candidates) {
      for (final name in p.handles.keys) {
        final h = p.handleWorldLocation(name);
        if (h == null) continue;
        final v = h - ray.origin;
        final distance = v.length;
        if (distance < 1e-6 || distance > rayMaxDistance) continue;
        final angle = math.acos((v.dot(ray.direction) / distance).clamp(-1.0, 1.0));
        if (angle <= cone && angle < bestAngle) {
          best = (poser: p, handle: name);
          bestAngle = angle;
        }
      }
    }
    return best;
  }

  void _hover(LuminaGrabber g, _GrabberState s, LuminaPoseHandleRef? handle) {
    final before = s.hovered;
    if (before?.poser == handle?.poser && before?.handle == handle?.handle) return;
    s.hovered = handle;
    onHandleHovered?.call(handle, g.id);
    if (handle != null) owner?.onPoseHandleHovered(handle.handle, g.id);
  }

  void _grab(LuminaGrabber g, _GrabberState s, LuminaPoseHandleRef handle) {
    // A handle another grabber holds is taken from it.
    for (final e in _states.entries) {
      final other = e.value.held;
      if (e.key != g && other != null && identical(other.poser, handle.poser) && other.handle == handle.handle) {
        _release(e.key, e.value);
      }
    }
    final transform = handle.poser.handleWorldTransform(handle.handle);
    if (transform == null) return;
    handle.poser.pushUndo();
    _grabHistory.add(handle.poser);
    if (_grabHistory.length > LuminaPoseAuthoringComponent.undoCapacity * 4) _grabHistory.removeAt(0);
    g.grabbedAt(transform.getTranslation());
    s.held = handle;
    s.offset = Matrix4.inverted(g.worldTransform)..multiply(transform);
    g.pulse(0.5, 0.03);
    onHandleGrabbed?.call(handle, g.id);
    owner?.onPoseHandleGrabbed(handle.handle, g.id);
  }

  void _drag(LuminaGrabber g, _GrabberState s, LuminaPoseHandleRef held) {
    final target = g.worldTransform.clone()..multiply(s.offset!);
    final rotation = Quaternion.identity();
    final location = Vector3.zero();
    target.decompose(location, rotation, Vector3.zero());
    final kind = LuminaPoseHandle.kindOf(held.handle);
    final turns = kind == LuminaPoseHandleKind.effector || kind == LuminaPoseHandleKind.look;
    held.poser.setHandleTarget(held.handle, location, worldRotation: turns ? (rotation..normalize()) : null);
  }

  void _release(LuminaGrabber g, _GrabberState s, {bool pulse = true}) {
    final held = s.held;
    if (held == null) return;
    s.held = null;
    s.offset = null;
    if (pulse) g.pulse(0.2, 0.015);
    onHandleReleased?.call(held, g.id);
    owner?.onPoseHandleReleased(held.handle, g.id);
  }

  /// Undoes the last grab: the targets of the character it moved go back to
  /// what they were before it. False when there is nothing to undo.
  bool undoLastGrab() {
    while (_grabHistory.isNotEmpty) {
      final poser = _grabHistory.removeLast();
      // A grab still held is let go first.
      for (final e in _states.entries) {
        if (identical(e.value.held?.poser, poser)) _release(e.key, e.value, pulse: false);
      }
      if (poser.undo()) return true;
    }
    return false;
  }

  void _drawHandles() {
    final w = world, engine = w?.nativeEngine, scene = w?.filamentSceneOrNull;
    if (!showHandles || engine == null || scene == null) return;
    final visuals = _visuals ??= LuminaPoseHandleVisuals(engine, scene);
    visuals.update(this);
  }
}
