import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/components/base/actor_component.dart';
import 'package:lumina/src/components/mesh/animated_mesh_component.dart';
import 'package:lumina/src/components/mesh/morph_spring_solver.dart';
import 'package:lumina/src/components/mesh/morph_target_set.dart';
import 'package:lumina/src/components/mesh/morph_targets.dart';
import 'package:lumina/src/components/mesh/skeletal_mesh_component.dart';

/// One soft mass of a mesh: where it is (a bone and an offset from it, or
/// an offset in the mesh), how its spring behaves, and the morph targets
/// that show its offset, one per axis direction of the mesh's frame
/// (`+x`, `-x`, `+y`, `-y`, `+z`, `-z`); a target is at weight 1 when the
/// offset along its direction reaches [range].
class LuminaMorphSpring {
  final String name;

  /// The bone carrying the mass; null: the mesh itself.
  final String? bone;

  /// The mass's position relative to [bone] (or the mesh), centimetres.
  final Vector3 offset;
  final double frequency, damping, inertia, gravity;

  /// Offset at target weight 1, centimetres.
  final double range;

  /// The largest offset, centimetres.
  final double limit;

  /// Morph target name by axis direction (`+x` … `-z`).
  final Map<String, String> morphs;

  static const directions = ['+x', '-x', '+y', '-y', '+z', '-z'];

  LuminaMorphSpring({
    required this.name,
    this.bone,
    Vector3? offset,
    this.frequency = 2.5,
    this.damping = 0.25,
    this.inertia = 1,
    this.gravity = 1,
    this.range = 3,
    this.limit = 6,
    this.morphs = const {},
  }) : offset = offset ?? Vector3.zero();

  Map<String, Object?> toJson() => {
    'name': name,
    if (bone != null) 'bone': bone,
    'offset': [offset.x, offset.y, offset.z],
    'frequency': frequency,
    'damping': damping,
    'inertia': inertia,
    'gravity': gravity,
    'range': range,
    'limit': limit,
    'morphs': morphs,
  };

  factory LuminaMorphSpring.fromJson(Map<String, Object?> j) {
    double d(String key, double fallback) => (j[key] as num?)?.toDouble() ?? fallback;
    final o = (j['offset'] as List?)?.map((e) => (e as num).toDouble()).toList();
    return LuminaMorphSpring(
      name: j['name'] as String? ?? 'spring',
      bone: j['bone'] as String?,
      offset: o == null || o.length < 3 ? null : Vector3(o[0], o[1], o[2]),
      frequency: d('frequency', 2.5),
      damping: d('damping', 0.25),
      inertia: d('inertia', 1),
      gravity: d('gravity', 1),
      range: d('range', 3),
      limit: d('limit', 6),
      morphs: {
        for (final e in ((j['morphs'] as Map?) ?? const {}).entries)
          if (directions.contains(e.key)) e.key as String: e.value as String,
      },
    );
  }
}

/// Secondary motion through morph targets: every [springs] mass lags behind
/// the body's acceleration and bounces back, and its offset is written as
/// weights of its morph targets on the owner's mesh (an animated or skinned
/// mesh component with morph targets) each frame, right after the mesh
/// ticked (add this component after the mesh).
class LuminaSpringMorphComponent extends LuminaActorComponent {
  /// World gravity, cm/s² (the runtime is Y-up).
  static final Vector3 worldGravity = Vector3(0, -980, 0);

  /// A frame speed above this (cm/s) is a teleport: the springs rest again.
  static const double teleportSpeed = 5000;

  List<LuminaMorphSpring> springs;
  bool enabled;

  /// Scales every offset before it becomes weights (0: no motion).
  double amplitude;

  /// Scale the springs' frequencies and damping ratios.
  double stiffnessScale, dampingScale;

  final List<_SpringState> _states = [];
  final Set<String> _reported = {};

  LuminaSpringMorphComponent({
    super.key,
    super.componentName,
    List<LuminaMorphSpring>? springs,
    this.enabled = true,
    this.amplitude = 1,
    this.stiffnessScale = 1,
    this.dampingScale = 1,
  }) : springs = springs ?? [];

  /// From a level / Blueprint component's properties ([toProperties]).
  factory LuminaSpringMorphComponent.fromProperties(Map<String, Object?> properties, {String? componentName}) {
    double d(String key, double fallback) => (properties[key] as num?)?.toDouble() ?? fallback;
    return LuminaSpringMorphComponent(
      componentName: componentName,
      springs: [
        for (final s in (properties['springs'] as List?) ?? const [])
          LuminaMorphSpring.fromJson((s as Map).cast<String, Object?>()),
      ],
      enabled: properties['enabled'] as bool? ?? true,
      amplitude: d('amplitude', 1),
      stiffnessScale: d('stiffnessScale', 1),
      dampingScale: d('dampingScale', 1),
    );
  }

  Map<String, Object?> toProperties() => {
    'enabled': enabled,
    'amplitude': amplitude,
    'stiffnessScale': stiffnessScale,
    'dampingScale': dampingScale,
    'springs': [for (final s in springs) s.toJson()],
  };

  /// The current offset of the spring named [name] (mesh frame, cm), before
  /// [amplitude]; null for an unknown spring.
  Vector3? offsetOf(String name) {
    for (var i = 0; i < springs.length && i < _states.length; i++) {
      if (springs[i].name == name) return _states[i].solver.offset.clone();
    }
    return null;
  }

  /// Every spring back at rest.
  void resetSprings() {
    for (final state in _states) {
      state.reset();
    }
  }

  LuminaMorphTargets? get _mesh {
    final actor = owner;
    if (actor == null) return null;
    for (final c in actor.components) {
      if (c is LuminaMorphTargets) return c;
    }
    return null;
  }

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    final mesh = _mesh;
    if (mesh == null || !mesh.hasMorphTargets || deltaTime <= 0) return;
    while (_states.length < springs.length) {
      _states.add(_SpringState());
    }
    final toLocal = mesh.worldRotation.conjugated();
    final gravityLocal = toLocal.rotated(worldGravity);
    for (var i = 0; i < springs.length; i++) {
      final spring = springs[i];
      final state = _states[i];
      state.solver
        ..frequency = spring.frequency * stiffnessScale
        ..damping = spring.damping * dampingScale
        ..inertia = spring.inertia
        ..gravity = spring.gravity
        ..limit = spring.limit;
      final position = _positionOf(mesh, spring);
      if (position == null) continue;
      final acceleration = state.accelerationAt(position, deltaTime);
      if (!enabled) {
        state.solver.reset();
      } else if (acceleration != null) {
        state.solver.advance(deltaTime, toLocal.rotated(acceleration), gravityLocal);
      }
      _write(mesh, spring, state, state.solver.offset.scaled(enabled ? amplitude : 0));
    }
    mesh.flushMorphTargets();
  }

  /// The mass's world position now.
  Vector3? _positionOf(LuminaMorphTargets mesh, LuminaMorphSpring spring) {
    final bone = spring.bone;
    if (bone != null) {
      if (mesh is LuminaAnimatedMeshComponent) {
        final joint = mesh.jointWorldTransform(bone);
        if (joint != null) return joint.transformed3(spring.offset);
      } else if (mesh is LuminaSkinnedMeshComponent) {
        final index = mesh.skeleton?.indexOfBone(bone) ?? -1;
        if (index >= 0) return mesh.getSocketWorldTransform(index, Matrix4.translation(spring.offset)).getTranslation();
      }
      _report('bone', "the mesh has no bone '$bone' (spring '${spring.name}'); the mesh carries it instead");
    }
    return mesh.worldTransform.transformed3(spring.offset);
  }

  void _write(LuminaMorphTargets mesh, LuminaMorphSpring spring, _SpringState state, Vector3 offset) {
    final range = math.max(spring.range, 1e-3);
    for (var axis = 0; axis < 3; axis++) {
      final value = offset[axis] / range;
      _set(mesh, spring, state, LuminaMorphSpring.directions[axis * 2], value.clamp(0.0, 1.0));
      _set(mesh, spring, state, LuminaMorphSpring.directions[axis * 2 + 1], (-value).clamp(0.0, 1.0));
    }
  }

  void _set(LuminaMorphTargets mesh, LuminaMorphSpring spring, _SpringState state, String direction, double weight) {
    final name = spring.morphs[direction];
    if (name == null) return;
    var handle = state.handles[direction];
    if (handle == null) {
      if (!mesh.hasMorphTarget(name)) {
        _report(name, "the mesh has no morph target '$name' (spring '${spring.name}' $direction)");
        return;
      }
      handle = state.handles[direction] = mesh.resolveMorphTarget(name);
    }
    mesh.setMorphTargetByHandle(handle, weight);
  }

  void _report(String key, String message) {
    if (_reported.add(key)) developer.log(message, name: 'LuminaSpringMorphComponent', level: 900);
  }
}

class _SpringState {
  final LuminaMorphSpringSolver solver = LuminaMorphSpringSolver();
  final Map<String, MorphTargetHandle> handles = {};
  Vector3? _position, _velocity;

  void reset() {
    solver.reset();
    _position = null;
    _velocity = null;
  }

  /// The mass's acceleration from its last two frames; null until there are
  /// two, or after a teleport (which also puts the spring at rest).
  Vector3? accelerationAt(Vector3 position, double deltaTime) {
    final last = _position;
    _position = position.clone();
    if (last == null) return null;
    final velocity = (position - last)..scale(1 / deltaTime);
    if (velocity.length > LuminaSpringMorphComponent.teleportSpeed) {
      reset();
      _position = position.clone();
      return null;
    }
    final previous = _velocity;
    _velocity = velocity;
    if (previous == null) return null;
    return (velocity - previous)..scale(1 / deltaTime);
  }
}
