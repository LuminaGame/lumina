import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/components/base/actor_component.dart';
import 'package:lumina/src/components/mesh/animated_mesh_component.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/src/blueprint/blueprint_model.dart';
import 'package:lumina/src/blueprint/blueprint_runtime.dart';
import 'package:lumina/src/blueprint/anim/anim_blueprint_model.dart';
import 'package:lumina/src/blueprint/anim/anim_motion_matching_driver.dart';

/// Makes the Animation Blueprint instance for a skeletal mesh component.
typedef LuminaAnimBlueprintFactory = LuminaAnimBlueprintInstance Function(LuminaAnimatedMeshComponent mesh);

/// A running Animation Blueprint: each tick it runs the update
/// graph ([updateAnimation]), takes the first true transition out of the
/// current state, and plays that state's pose on [mesh] — a clip, the nearest
/// blend-space sample (crossfaded, phase-synced between samples of one blend
/// space) at a rate from a speed variable, or the current pose held still.
///
/// Add it to the actor before [mesh], so a frame's pose is chosen before the
/// mesh applies it (as the locomotion driver is). The VM
/// ([LuminaVmAnimBlueprintInstance]) and generated classes override
/// [updateAnimation] and [evaluateRule]; the rest is shared, so both animate
/// the same way.
///
/// Before the update graph runs, three **reserved variables** are written for
/// the graphs to read (declare them in the Animation Blueprint to use them):
/// [stateTimeVariable] (seconds in the current state), [clipFinishedVariable]
/// (the state's clip has played through once, see [clipFinished]) and
/// [rootYawOffsetVariable] (degrees the planted mesh lags behind the pawn's
/// yaw, see [rootYawOffsetDegrees]). Transitions may also gate on
/// [LuminaAnimTransition.minStateTime] / [LuminaAnimTransition.automaticRule].
/// While a Motion Matching state plays, [matchedClipVariable] holds the clip
/// the motion matching player matched ('' while its database loads).
abstract class LuminaAnimBlueprintInstance extends LuminaActorComponent {
  static const String stateTimeVariable = 'StateTime';
  static const String clipFinishedVariable = 'ClipFinished';
  static const String rootYawOffsetVariable = 'RootYawOffset';
  static const String matchedClipVariable = 'MatchedClip';

  /// How fast [rootYawOffsetDegrees] blends back to 0 while the current pose
  /// does not plant the feet (degrees per second).
  static const double rootYawBlendOutDegreesPerSecond = 540.0;

  final LuminaAnimatedMeshComponent mesh;
  final LuminaAnimStateMachine stateMachine;
  final Map<String, LuminaBlendSpaceDocument> blendSpaces;
  final double meshYawOffsetDegrees;

  /// The aim offset layered over the pose, if any.
  final LuminaAnimAimOffset? aimOffset;

  /// The pose search databases Motion Matching states play, by asset path.
  final Map<String, LuminaPoseSearchDatabaseDocument> poseDatabases;

  /// Runs the Motion Matching states.
  late final LuminaAnimMotionMatchingDriver motionMatching = LuminaAnimMotionMatchingDriver(mesh, poseDatabases);

  double _aimYaw = 0.0;
  double _aimPitch = 0.0;

  /// The aim the bones show now (degrees), interpolating toward the clamped
  /// variables; 0 without an aim offset.
  double get aimYaw => _aimYaw;
  double get aimPitch => _aimPitch;

  Map<String, double> _blendWeights = const {};

  /// The current blend-space pose's sample weights by clip,
  /// summing to 1; the mesh plays the largest (gltfio crossfades two clips,
  /// it does not blend four). Empty outside a blend-space state.
  Map<String, double> get blendWeights => Map.unmodifiable(_blendWeights);

  /// Variable values by name, read by poses and written by the update graph.
  final Map<String, Object?> variables = {};

  /// Called for every executed node, as [LuminaBlueprintRuntime.trace].
  void Function(LuminaBlueprintTraceEvent event)? trace;

  /// Picks the clip of a random pose on state entry; seed it for a
  /// deterministic run.
  math.Random random = math.Random();

  /// Clip lengths (seconds) for clips [mesh] cannot report yet — before its
  /// asset loads, or in a headless test where it never does. A clip whose
  /// length is known nowhere counts as finished at once.
  final Map<String, double> clipDurationFallbacks = {};

  String? _state;
  String? _stateClip;
  double _stateTime = 0.0;
  double _rootYawOffset = 0.0;
  double _rootYawApplied = 0.0;
  double? _lastOwnerYaw;

  /// The state machine's current state.
  String? get currentState => _state;

  /// The clip the current state plays (the one picked for a random pose), if
  /// it plays a clip.
  String? get currentStateClip => _stateClip;

  /// Seconds since the current state was entered.
  double get stateTime => _stateTime;

  /// Degrees the mesh is turned away from its owner's facing to keep its feet
  /// planted (negative after the pawn turned right); see
  /// [LuminaAnimPose.plantsFeet] and [LuminaAnimPose.rootYawDegrees].
  double get rootYawOffsetDegrees => _rootYawOffset;

  /// Length of [clip] from the mesh, else [clipDurationFallbacks], else null.
  double? clipDurationOf(String clip) => mesh.hasClip(clip) ? mesh.clipDuration(clip) : clipDurationFallbacks[clip];

  /// Seconds until the current state's clip has played through once at its
  /// rate; null when the state plays no clip or the length is unknown.
  double? get stateTimeRemaining {
    final pose = _currentPose;
    final clip = _stateClip;
    if (pose == null || pose.kind != LuminaAnimPoseKind.clip || clip == null) return null;
    final duration = clipDurationOf(clip);
    if (duration == null) return null;
    if (pose.rate <= 0.0) return double.infinity;
    return math.max(0.0, duration / pose.rate - _stateTime);
  }

  /// Whether the current state's clip has played through once (a looping
  /// clip: its first cycle). True for a clip of unknown length, false for a
  /// blend space or a held pose. Frame times accumulate in floating point,
  /// so a microsecond short of the length counts as finished.
  bool get clipFinished {
    final pose = _currentPose;
    if (pose == null || pose.kind != LuminaAnimPoseKind.clip) return false;
    final remaining = stateTimeRemaining;
    return remaining == null || remaining <= 1e-6;
  }

  LuminaAnimPose? get _currentPose => _state == null ? null : stateMachine.state(_state!)?.pose;

  LuminaAnimBlueprintInstance({
    super.key,
    required this.mesh,
    required this.stateMachine,
    this.blendSpaces = const {},
    this.meshYawOffsetDegrees = 0.0,
    this.aimOffset,
    this.poseDatabases = const {},
    Map<String, Object?> initialVariables = const {},
  }) {
    variables.addAll(initialVariables);
  }

  /// Runs the update graph (Event Blueprint Update Animation).
  void updateAnimation(double deltaTimeX);

  /// Whether [transition]'s rule holds.
  bool evaluateRule(LuminaAnimTransition transition);

  void blueprintTrace(String eventNodeId, String nodeId, String registryId, Map<String, Object?> values,
      {String? printed}) {
    trace?.call(LuminaBlueprintTraceEvent(
      eventNodeId: eventNodeId,
      nodeId: nodeId,
      registryId: registryId,
      values: values,
      printed: printed,
    ));
  }

  final Set<String> _warnedClips = {};

  bool get _meshLoaded => mesh.clipNames.isNotEmpty;

  void _warnMissingClip(String clip) {
    if (_warnedClips.add(clip)) {
      developer.log(
        'AnimBlueprint: clip "$clip" not in mesh "${mesh.meshAssetPath}"; holding current pose',
        name: 'LuminaAnimBlueprint',
        level: 800,
      );
    }
  }

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    _enterState(stateMachine.entryState);
    unawaited(_preloadPoseDatabases());
    _lastOwnerYaw = _ownerYaw;
    if (mesh.currentClip == null) {
      final pose = _currentPose;
      final (clip, _) = _target(pose);
      if (clip != null) {
        if (!_meshLoaded || mesh.hasClip(clip)) {
          mesh.play(clip, loop: pose!.loop);
        } else {
          _warnMissingClip(clip);
        }
      }
    }
    _faceOwnerForward();
  }

  /// Loads every Motion Matching state's database one after the other, the
  /// entry state's first, so entering a state later does not hold the pose
  /// while its database loads.
  Future<void> _preloadPoseDatabases() async {
    final entry = stateMachine.state(stateMachine.entryState);
    final paths = <String>{
      for (final s in [?entry, ...stateMachine.states])
        if (s.pose.kind == LuminaAnimPoseKind.motionMatching && (s.pose.database ?? '').isNotEmpty) s.pose.database!,
    };
    for (final path in paths) {
      try {
        await motionMatching.load(path);
      } catch (_) {
        // Reported by the driver (lastError) when the state runs.
      }
    }
  }

  /// While a montage plays on the mesh the state machine
  /// keeps its state and time but leaves the mesh's clip alone.
  bool montagePlaying = false;

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    if (owner == null || _state == null) return;
    if (montagePlaying) {
      _stateTime += deltaTime;
      return;
    }
    _trackRootYaw(deltaTime);
    _faceOwnerForward();
    _stateTime += deltaTime;
    variables[stateTimeVariable] = _stateTime;
    variables[clipFinishedVariable] = clipFinished;
    variables[rootYawOffsetVariable] = _rootYawOffset;
    updateAnimation(deltaTime);
    _applyAimOffset(deltaTime);

    LuminaAnimTransition? taken;
    for (final t in stateMachine.transitionsFrom(_state!)) {
      if (_stateTime < t.minStateTime) continue;
      if (t.automaticRule && !clipFinished) continue;
      if (evaluateRule(t)) {
        taken = t;
        break;
      }
    }
    if (taken != null) _enterState(taken.to);

    final pose = _currentPose;
    if (pose != null && pose.kind == LuminaAnimPoseKind.motionMatching) {
      variables[matchedClipVariable] = motionMatching.drive(owner!, pose, deltaTime) ?? '';
      return;
    }
    motionMatching.leave();
    final (target, rate) = _target(pose);
    if (target != null && mesh.currentClip != target) {
      if (!_meshLoaded || mesh.hasClip(target)) {
        final space = pose?.blendSpace == null ? null : blendSpaces[pose!.blendSpace];
        final sync = space != null && space.containsClip(mesh.currentClip) && space.containsClip(target);
        mesh.crossFadeTo(target,
            duration: taken?.blendDuration ?? stateMachine.sampleCrossFade, syncPhase: sync, loop: pose?.loop ?? true);
      } else {
        _warnMissingClip(target);
      }
    }
    mesh.playRate = rate;
  }

  void _enterState(String name) {
    _state = name;
    _stateTime = 0.0;
    _rootYawApplied = 0.0;
    final pose = stateMachine.state(name)?.pose;
    if (pose == null || pose.kind != LuminaAnimPoseKind.clip) {
      _stateClip = null;
    } else if (pose.isRandom) {
      final available = _meshLoaded
          ? pose.clips.where(mesh.hasClip).toList()
          : pose.clips;
      if (available.isNotEmpty) {
        _stateClip = available[random.nextInt(available.length)];
      } else {
        _stateClip = pose.clip;
      }
    } else {
      _stateClip = pose.clip;
    }
  }

  /// The owner's yaw in degrees, as `get_actor_rotation` reports it.
  double get _ownerYaw => luminaPawnQuaternionToEuler(owner!.actorRotation).y;

  static double _wrapDegrees(double d) {
    var r = d % 360.0;
    if (r > 180.0) r -= 360.0;
    if (r < -180.0) r += 360.0;
    return r;
  }

  /// Keeps the mesh planted while the pose asks for it (the pawn's yaw
  /// change goes into [rootYawOffsetDegrees]), turns it through the pose's
  /// [LuminaAnimPose.rootYawDegrees] over the clip's length, and blends the
  /// offset out otherwise.
  void _trackRootYaw(double deltaTime) {
    final yaw = _ownerYaw;
    final delta = _lastOwnerYaw == null ? 0.0 : _wrapDegrees(yaw - _lastOwnerYaw!);
    _lastOwnerYaw = yaw;
    final pose = _currentPose;
    final plants = pose != null && pose.kind == LuminaAnimPoseKind.clip && pose.plantsFeet;
    if (plants) {
      _rootYawOffset = _wrapDegrees(_rootYawOffset - delta);
    } else if (_rootYawOffset != 0.0) {
      final step = rootYawBlendOutDegreesPerSecond * deltaTime;
      _rootYawOffset = _rootYawOffset.abs() <= step ? 0.0 : _rootYawOffset - step * _rootYawOffset.sign;
    }
    final turn = pose?.rootYawDegrees ?? 0.0;
    if (turn != 0.0 && _stateClip != null) {
      final duration = clipDurationOf(_stateClip!);
      final rate = pose!.rate;
      final total = duration == null || duration <= 0.0 || rate <= 0.0 ? 0.0 : duration / rate;
      var step = total <= 0.0 ? turn - _rootYawApplied : turn * deltaTime / total;
      if ((_rootYawApplied + step).abs() > turn.abs()) step = turn - _rootYawApplied;
      _rootYawApplied += step;
      _rootYawOffset = _wrapDegrees(_rootYawOffset + step);
    }
  }

  /// Turns the aim offset's bones toward the clamped, interpolated aim: the
  /// controller's yaw / pitch relative to the body ([aimOffset]'s variables),
  /// each bone by its weight, as a joint override in the bone's local frame
  /// (the world-space turn conjugated by the joint's world rotation, so pitch
  /// stays about the character's right axis whatever the bone's own axes; a
  /// mesh with no joint frames yet takes the plain rotation).
  void _applyAimOffset(double deltaTime) {
    final offset = aimOffset;
    if (offset == null) return;
    final targetYaw = _number(offset.yawVariable).clamp(-offset.maxYaw, offset.maxYaw).toDouble();
    final targetPitch = _number(offset.pitchVariable).clamp(-offset.maxPitch, offset.maxPitch).toDouble();
    final k = offset.interpSpeed <= 0.0 ? 1.0 : 1.0 - math.exp(-offset.interpSpeed * deltaTime);
    _aimYaw += (targetYaw - _aimYaw) * k;
    _aimPitch += (targetPitch - _aimPitch) * k;
    if ((_aimYaw - targetYaw).abs() < 1e-4) _aimYaw = targetYaw;
    if ((_aimPitch - targetPitch).abs() < 1e-4) _aimPitch = targetPitch;
    final bodyYaw = luminaPawnEulerToQuaternion(0.0, _ownerYaw, 0.0);
    final bodyYawInverse = bodyYaw.clone()..inverse();
    for (final bone in offset.bones) {
      final turn = luminaPawnEulerToQuaternion(_aimPitch * bone.weight, _aimYaw * bone.weight, 0.0);
      final world = mesh.jointWorldTransform(bone.name);
      Quaternion local;
      if (world == null) {
        local = turn;
      } else {
        // World turn about the body's axes, then into the joint's frame.
        final worldTurn = bodyYaw * turn * bodyYawInverse;
        final jointRotation = _rotationOf(world);
        final jointInverse = jointRotation.clone()..inverse();
        local = (jointInverse * worldTurn * jointRotation)..normalize();
      }
      mesh.setJointOverride(bone.name, rotation: local);
    }
  }

  /// The rotation of [m] with its scale divided out (Filament joint
  /// transforms carry the asset's unit scale).
  static Quaternion _rotationOf(Matrix4 m) {
    final r = m.getRotation();
    for (var c = 0; c < 3; c++) {
      final len = math.sqrt(r.entry(0, c) * r.entry(0, c) + r.entry(1, c) * r.entry(1, c) + r.entry(2, c) * r.entry(2, c));
      if (len > 1e-12) {
        for (var row = 0; row < 3; row++) {
          r.setEntry(row, c, r.entry(row, c) / len);
        }
      }
    }
    return Quaternion.fromRotation(r)..normalize();
  }

  /// The clip [pose] plays now and its rate; a null clip holds the current one.
  (String?, double) _target(LuminaAnimPose? pose) {
    _blendWeights = const {};
    if (pose == null) return (null, 0.0);
    switch (pose.kind) {
      case LuminaAnimPoseKind.clip:
        return (_stateClip ?? pose.clip, pose.rate);
      case LuminaAnimPoseKind.hold:
        return (null, 0.0);
      case LuminaAnimPoseKind.motionMatching:
        return (null, 1.0);
      case LuminaAnimPoseKind.blendSpace:
        final space = blendSpaces[pose.blendSpace];
        final x = _number(pose.xVariable);
        final y = _number(pose.yVariable);
        // A 2D space plays its dominant bilinear sample; a 1D
        // one its nearest, as before.
        final sample = space == null ? null : (space.axes.length > 1 ? space.dominant(x, y) : space.nearest(x, y));
        _blendWeights = space == null ? const {} : space.weights(x, y);
        var rate = pose.rate;
        final reference = pose.rateRows && sample != null && sample.y > 0 ? sample.y : pose.rateReference;
        if (pose.rateVariable != null && reference > 0) {
          rate = (_number(pose.rateVariable) / reference).clamp(pose.minRate, pose.maxRate).toDouble();
        }
        return (sample?.clip, rate);
    }
  }

  double _number(String? variable) {
    final v = variable == null ? null : variables[variable];
    return v is num ? v.toDouble() : 0.0;
  }

  static final Vector3 _up = Vector3(0.0, 1.0, 0.0);

  /// Turns the mesh from its authored forward (glTF +Z, see
  /// [meshYawOffsetDegrees]) to its owner's −Z, as the locomotion driver does,
  /// plus the root yaw offset that keeps its feet planted; the mesh otherwise
  /// inherits the owner's rotation, whose `forwardVector` is the drawn −Z.
  void _faceOwnerForward() {
    // The pawn's yaw is right-positive (luminaPawnEulerToQuaternion), a plain
    // axis-angle about +Y is left-positive: subtract to turn the mesh right.
    mesh.relativeRotation =
        Quaternion.axisAngle(_up, math.pi + (meshYawOffsetDegrees - _rootYawOffset) * math.pi / 180.0);
  }

  /// The pawn this instance animates: the function library's `self`.
  LuminaActor get pawnOwner => owner!;
}

/// Initial variable values of [variables], as the pin types' values.
Map<String, Object?> luminaAnimVariableDefaults(List<LuminaBlueprintVariable> variables) => {
      for (final v in variables) v.name: luminaBlueprintLiteral(v.type ?? LuminaPinType.float, v.defaultValue) ?? _zero(v.type),
    };

Object? _zero(LuminaPinType? type) => switch (type) {
      LuminaPinType.float => 0.0,
      LuminaPinType.integer => 0,
      LuminaPinType.boolean => false,
      LuminaPinType.string || LuminaPinType.name => '',
      LuminaPinType.vector => Vector3.zero(),
      LuminaPinType.vector2D => Vector2.zero(),
      LuminaPinType.rotator => const LuminaRotator.zero(),
      _ => null,
    };
