import 'dart:async';
import 'dart:developer' as developer;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:lumina_core/lumina_core.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/components/base/actor_component.dart';
import 'package:lumina/src/components/mesh/animated_mesh_component.dart';
import 'package:lumina/src/components/mesh/mesh_asset_cache.dart';
import 'package:lumina/src/components/mesh/mesh_pose_modifier.dart';
import 'package:lumina/src/components/mesh/pose_authoring/pose_handle.dart';
import 'package:lumina/src/components/mesh/pose_authoring/pose_library.dart';
import 'package:lumina/src/components/mesh/pose_authoring/pose_quat.dart';
import 'package:lumina/src/components/mesh/pose_authoring/pose_rig.dart';
import 'package:lumina/src/components/mesh/pose_authoring/pose_solve_state.dart';
import 'package:lumina/src/components/mesh/pose_authoring/pose_solvers.dart';
import 'package:lumina/src/save/save_game_subsystem.dart';
import 'package:lumina/src/utility/lumina_assets.dart';

part 'pose_authoring_solve.dart';

/// Poses a skinned character like a mannequin through handles: move a hand
/// and the elbow and shoulder bend, move an elbow and the arm plane swings,
/// turn the head and the neck shares the turn, pull the chest and the spine
/// bends, move the pelvis and planted feet stay. What is set holds every
/// frame until it changes.
///
/// The component adds itself to its mesh's `poseModifiers` and solves
/// after the animation, in the GLB's model frame: handles take world units
/// (cm), converted through the mesh's render transform once per frame.
/// Solve order: pelvis → spine → head → arms → legs (one pass).
///
/// The rig is detected from the mesh's skeleton ([LuminaPoseRig.detect]) or
/// read from the pose rig asset at [rigAssetPath]; [setUp] hands one over.
class LuminaPoseAuthoringComponent extends LuminaActorComponent implements LuminaMeshPoseModifier {
  LuminaPoseAuthoringComponent({
    super.key,
    this.mesh,
    this.rigAssetPath = '',
    double weight = 1.0,
    this.captureMode = LuminaPoseCaptureMode.holdTargets,
  }) : _weight = weight.clamp(0.0, 1.0) {
    _ready.future.ignore();
  }

  /// Builds the component from its Blueprint / level JSON properties.
  factory LuminaPoseAuthoringComponent.fromProperties(Map<String, dynamic> p) => LuminaPoseAuthoringComponent(
        rigAssetPath: p['rigAsset'] is String ? p['rigAsset'] as String : '',
        weight: p['weight'] is num ? (p['weight'] as num).toDouble() : 1.0,
        captureMode:
            p['captureMode'] == 'bakeToPose' ? LuminaPoseCaptureMode.bakeToPose : LuminaPoseCaptureMode.holdTargets,
      );

  /// The posed mesh (the owner's first animated mesh when null at BeginPlay).
  LuminaAnimatedMeshComponent? mesh;

  /// A pose rig `.lmas` to use instead of detecting the rig.
  String rigAssetPath;

  LuminaPoseCaptureMode captureMode;

  double _weight;

  /// The solved pose's blend over the incoming animation (0–1).
  double get weight => _weight;
  set weight(double v) => _weight = v.clamp(0.0, 1.0);

  /// Called with a handle's name whenever its target is set or cleared.
  void Function(String handle)? onHandleChanged;

  LuminaPoseRig? _rig;
  LuminaPoseSolveState? _state;
  final Map<String, LuminaPoseHandle> _handles = {};
  final Map<String, (Vector3, Quaternion?)> _early = {};

  /// The rig, once loaded.
  LuminaPoseRig? get rig => _rig;

  /// The handles of the rig by name (empty until the rig is loaded).
  Map<String, LuminaPoseHandle> get handles => Map.unmodifiable(_handles);

  final Completer<void> _ready = Completer();

  /// Completes when the rig is ready.
  Future<void> get ready => _ready.future;

  /// Why loading the rig failed, if it did.
  String? loadError;

  // Solve bookkeeping (see pose_authoring_solve.dart).
  Float64List? _base, _written, _held, _applied, _blendFrom;
  Uint8List? _appliedMask;
  double _appliedAlpha = 1.0, _appliedRate = 0.0;
  final Matrix4 _meshTransform = Matrix4.identity();
  bool _solvedOnce = false;

  /// Microseconds the last solve took.
  int lastSolveMicros = 0;

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    final target = mesh ??= owner?.components.whereType<LuminaAnimatedMeshComponent>().firstOrNull;
    if (target == null) {
      loadError = 'the actor has no animated mesh';
      return;
    }
    if (!target.poseModifiers.contains(this)) target.poseModifiers.add(this);
    if (_rig == null) unawaited(load());
  }

  @override
  void onUnregister() {
    mesh?.poseModifiers.remove(this);
    super.onUnregister();
  }

  /// Attaches to [target] (adds the component to its pose modifiers).
  void attachTo(LuminaAnimatedMeshComponent target) {
    mesh?.poseModifiers.remove(this);
    mesh = target;
    if (!target.poseModifiers.contains(this)) target.poseModifiers.add(this);
  }

  static final Map<String, Future<GlbSkeleton>> _skeletons = {};

  /// Loads the mesh's skeleton (once per mesh path, parsed on a worker
  /// isolate) and the rig.
  Future<void> load() async {
    if (_rig != null || loadError != null) return;
    final target = mesh;
    if (target == null) return;
    try {
      final read = LuminaAssets.resolve(target.assetProvider);
      final skeleton = await _skeletons.putIfAbsent(
          target.meshAssetPath, () async => _parseSkeleton(await LuminaMeshAssetCache.meshBytes(read, target.meshAssetPath)));
      final definition = rigAssetPath.isEmpty
          ? null
          : LuminaPoseRigDefinition.fromAssetBytes(await read(rigAssetPath));
      setUp(definition == null ? LuminaPoseRig.detect(skeleton) : LuminaPoseRig.fromDefinition(skeleton, definition));
    } catch (e, st) {
      _skeletons.remove(target.meshAssetPath);
      loadError = '$e';
      developer.log('Pose authoring: cannot load the rig: $e', name: 'LuminaPoseAuthoring', level: 900);
      if (!_ready.isCompleted) _ready.completeError(e, st);
    }
  }

  /// The skeleton of the GLB [bytes], parsed on a worker isolate (the
  /// closure captures nothing but the bytes).
  static Future<GlbSkeleton> _parseSkeleton(Uint8List bytes) async {
    try {
      return await Isolate.run(() => GlbSkeleton.fromGlb(bytes), debugName: 'pose rig skeleton');
    } on UnsupportedError {
      return GlbSkeleton.fromGlb(bytes);
    }
  }

  /// Uses [rig] from now on; targets set before keep their handles.
  void setUp(LuminaPoseRig rig) {
    _rig = rig;
    _state = LuminaPoseSolveState(rig);
    _handles
      ..clear()
      ..addAll({
        for (final name in rig.handleNames)
          name: LuminaPoseHandle(name, LuminaPoseHandle.kindOf(name), rig.nodeNames[rig.handleSlot(name)]),
      });
    _base = _written = _held = _applied = null;
    _solvedOnce = false;
    final early = Map.of(_early);
    _early.clear();
    early.forEach((name, t) => setHandleTarget(name, t.$1, worldRotation: t.$2));
    if (!_ready.isCompleted) _ready.complete();
  }

  // --- Pose modifier --------------------------------------------------------------

  @override
  List<String> get poseModifierNodes => _rig?.nodeNames ?? const [];

  @override
  bool modifyPose(Float64List pose, Matrix4 meshTransform, double deltaTime) =>
      _solve(this, pose, meshTransform, deltaTime);

  // --- Handles ----------------------------------------------------------------------

  /// Sets [name]'s target: [worldLocation] in world units, and the handle
  /// bone's world rotation [worldRotation] (a hand or foot keeps it; the
  /// head takes its roll; the pelvis takes it whole). Before the rig loads
  /// the target is kept for when it does. False for a handle the rig lacks.
  bool setHandleTarget(String name, Vector3 worldLocation, {Quaternion? worldRotation}) {
    if (_rig == null) {
      _early[name] = (worldLocation.clone(), worldRotation?.clone());
      return true;
    }
    final handle = _handles[name];
    if (handle == null) return false;
    handle
      ..modelTarget = null
      ..modelRotation = null
      ..pendingWorldTarget = worldLocation.clone()
      ..pendingWorldRotation = worldRotation?.clone();
    _changed(name);
    return true;
  }

  /// Drops [name]'s target (with [captureMode] `holdTargets` its part of the
  /// body goes back to the incoming pose; with `bakeToPose` it stays).
  void clearHandle(String name) {
    _early.remove(name);
    final handle = _handles[name];
    if (handle == null || !handle.hasTarget) return;
    handle.clear();
    _changed(name);
  }

  /// Drops every target, an applied pose and what was baked: the incoming
  /// pose (the reference pose of a mesh that plays nothing) shows again.
  void resetToReference() {
    _early.clear();
    for (final h in _handles.values) {
      if (!h.hasTarget) continue;
      h.clear();
      _changed(h.name);
    }
    _held = null;
    _applied = null;
    _appliedMask = null;
  }

  void _changed(String name) {
    onHandleChanged?.call(name);
    owner?.onPoseHandleChanged(name);
  }

  /// The world transform of [name]'s bone after the last solve (before any,
  /// in the rest pose under the mesh's render transform), with unit scale;
  /// null for a handle the rig lacks or before the rig loads.
  Matrix4? handleWorldTransform(String name) {
    final rig = _rig, state = _state;
    if (rig == null || state == null) return null;
    final slot = rig.handleSlot(name);
    if (slot < 0) return null;
    if (!_solvedOnce) {
      final m = mesh;
      if (m != null) _meshTransform.setFrom(m.renderTransform);
      state.load(rig.restPose);
    }
    final model = name == 'head' ? LuminaPoseSolvers.headHandle(state) : state.pos[slot].clone();
    final location = _meshTransform.transformed3(model);
    final meshRotation = Quaternion.identity();
    _meshTransform.decompose(Vector3.zero(), meshRotation, Vector3.zero());
    final rotation = LuminaPoseQuat.qMul(meshRotation, state.rot[slot])..normalize();
    return Matrix4.compose(location, rotation, Vector3.all(1));
  }

  /// The world location of [name]'s bone (see [handleWorldTransform]).
  Vector3? handleWorldLocation(String name) => handleWorldTransform(name)?.getTranslation();

  /// The handle nearest [worldLocation] within [maxDistance] (world units),
  /// with its distance; null when none is that close.
  ({String name, double distance})? findNearestHandle(Vector3 worldLocation, {double maxDistance = double.infinity}) {
    ({String name, double distance})? best;
    for (final name in _handles.keys) {
      final at = handleWorldLocation(name);
      if (at == null) continue;
      final d = at.distanceTo(worldLocation);
      if (d <= maxDistance && (best == null || d < best.distance)) best = (name: name, distance: d);
    }
    return best;
  }

  // --- Poses ------------------------------------------------------------------------

  /// The pose shown now (the last solve's local transforms) as an
  /// [AuthoredPose] named [name], by bone name.
  AuthoredPose toAuthoredPose([String name = 'Pose']) {
    final rig = _rig;
    if (rig == null) return AuthoredPose(name, const {});
    final pose = _written ?? rig.restPose;
    return AuthoredPose(name, {
      for (var i = 0; i < rig.length; i++)
        if (rig.skeleton.isJoint(rig.nodes[i])) rig.nodeNames[i]: BoneTrs.fromList(pose.sublist(i * 10, i * 10 + 10)),
    });
  }

  /// Shows [pose] from now on, blended in over [blendSeconds]: its bones
  /// replace the incoming pose (others keep it), every handle target is
  /// dropped, and handles set later solve over it.
  void applyAuthoredPose(AuthoredPose pose, {double blendSeconds = 0.0}) {
    final rig = _rig;
    if (rig == null) return;
    for (final h in _handles.values) {
      if (!h.hasTarget) continue;
      h.clear();
      _changed(h.name);
    }
    final applied = Float64List(rig.length * 10);
    final mask = Uint8List(rig.length);
    for (var i = 0; i < rig.length; i++) {
      final trs = pose.bones[rig.nodeNames[i]];
      if (trs == null) continue;
      applied.setAll(i * 10, trs.toList());
      mask[i] = 1;
    }
    _applied = applied;
    _appliedMask = mask;
    _blendFrom = _written == null ? null : Float64List.fromList(_written!);
    _held = null;
    if (blendSeconds <= 0) {
      _appliedAlpha = 1.0;
      _appliedRate = 0.0;
    } else {
      _appliedAlpha = 0.0;
      _appliedRate = 1.0 / blendSeconds;
    }
  }

  /// The save game subsystem poses go to: the world's, else one on the
  /// default save directory.
  LuminaSaveGameSubsystem get saves => world?.getSubsystem<LuminaSaveGameSubsystem>() ?? LuminaSaveGameSubsystem();

  /// Saves the pose shown now as [name] in save game slot [slot]; in
  /// Play-In-Editor also into the mesh's `PoseLibrary.lmas`.
  Future<bool> savePose(String slot, String name, {int userIndex = 0}) async {
    final pose = toAuthoredPose(name);
    final ok = await LuminaPoseLibrary.saveToSlot(saves, slot, name, pose, userIndex: userIndex);
    final project = LuminaPoseLibrary.editorProjectDir, m = mesh;
    if (project != null && m != null) await LuminaPoseLibrary.saveToProject(project, m.meshAssetPath, name, pose);
    return ok;
  }

  /// Applies the pose [name] from save game slot [slot]; false when the slot
  /// has none.
  Future<bool> loadPose(String slot, String name, {int userIndex = 0, double blendSeconds = 0.0}) async {
    final pose = await LuminaPoseLibrary.loadFromSlot(saves, slot, name, userIndex: userIndex);
    if (pose == null) return false;
    applyAuthoredPose(pose, blendSeconds: blendSeconds);
    return true;
  }
}
