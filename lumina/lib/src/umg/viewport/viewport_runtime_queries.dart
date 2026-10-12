part of 'viewport_runtime.dart';

/// What a pick hit: the node, the nearest bone of a skeletal mesh (null
/// for other nodes) and the hit location (authoring space, cm).
class LuminaViewportPick {
  const LuminaViewportPick(this.nodeId, this.bone, this.location);
  final String nodeId;
  final String? bone;
  final Vector3 location;

  /// The `On Picked` event's outputs.
  Map<String, Object?> get eventArgs => {'node_id': nodeId, 'bone': bone ?? '', 'hit_location': location};
}


/// The parts of a [LuminaViewportSceneRuntime] the widget's taps, overlays
/// and adapters use: picking, joints, poses, projection, material
/// parameters and a timeline's local animation time.
mixin _ViewportQueries {
  Map<String, _RuntimeNode> get _nodes;
  FilamentEngine get engine;
  Future<void> _applyTexture(_RuntimeNode node, FilamentMaterialInstance mi, String slot, String name, String path);
  LuminaViewportCamera get orbit;
  Aabb3? _worldBounds(_RuntimeNode node);

  /// A bound timeline's time for node [id]'s animation (null: the
  /// description's), applied without a description diff.
  void setLocalAnimationTime(String id, double? seconds) {
    final node = _nodes[id];
    final mesh = node?.skeletal;
    if (node == null || mesh == null) return;
    node.localTime = seconds;
    final clip = mesh.currentClip;
    if (seconds == null || clip == null) return;
    final loop = (node.json['animation'] is Map) ? (node.json['animation']! as Map)['loop'] != false : true;
    final rate = mesh.playRate;
    mesh.play(clip, startTime: seconds, loop: loop);
    mesh.playRate = rate;
    mesh.onTick(0.0);
  }

  /// Writes node [node]'s `pose` (joint → local `[x, y, z, qx, qy, qz, qw,
  /// sx, sy, sz]` in the mesh's glTF frame) over its animation.
  void _applyPose(_RuntimeNode node) {
    final pose = node.json['pose'];
    if (pose is Map) _writePose(node, pose);
  }

  /// Writes [pose] (joint → local transform values) onto [node]'s joints.
  void _writePose(_RuntimeNode node, Map pose) {
    final mesh = node.skeletal;
    final instance = mesh?.assetInstance;
    if (pose.isEmpty || instance == null || instance.skinCount == 0) return;
    final tm = FilamentTransformManager(engine);
    final entities = _jointEntities(node);
    final names = node.jointNames;
    for (var i = 0; i < entities.length && i < names.length; i++) {
      final v = pose[names[i]];
      if (v is! List || v.length < 7 || entities[i] == 0) continue;
      double at(int k, double d) => k < v.length && v[k] is num ? (v[k] as num).toDouble() : d;
      tm.setTransform(
        entities[i],
        Matrix4.compose(Vector3(at(0, 0), at(1, 0), at(2, 0)), Quaternion(at(3, 0), at(4, 0), at(5, 0), at(6, 1)),
                Vector3(at(7, 1), at(8, 1), at(9, 1)))
            .storage
            .toList(),
      );
    }
    instance.animator.updateBoneMatrices();
  }

  /// Writes [node]'s material parameters onto its material instances.
  void _applyMaterialParams(_RuntimeNode node) {
    final instance = node.mesh?.assetInstance;
    final params = node.json['materialParams'];
    if (instance == null || params is! Map) return;
    final materials = instance.materialInstances;
    for (final slot in params.entries) {
      final index = int.tryParse('${slot.key}');
      if (index == null || index < 0 || index >= materials.length || slot.value is! Map) continue;
      final mi = materials[index];
      for (final p in (slot.value as Map).entries) {
        final name = '${p.key}';
        final v = p.value;
        try {
          if (v is List && v.length >= 4) {
            mi.setFloat4(name, LuminaViewportSceneRuntime._n(v, 0, 0), LuminaViewportSceneRuntime._n(v, 1, 0), LuminaViewportSceneRuntime._n(v, 2, 0), LuminaViewportSceneRuntime._n(v, 3, 1));
          } else if (v is List && v.length == 3) {
            mi.setFloat3(name, LuminaViewportSceneRuntime._n(v, 0, 0), LuminaViewportSceneRuntime._n(v, 1, 0), LuminaViewportSceneRuntime._n(v, 2, 0));
          } else if (v is num) {
            mi.setFloat(name, v.toDouble());
          } else if (v is bool) {
            mi.setBool(name, v);
          } else if (v is String && v.isNotEmpty) {
            unawaited(_applyTexture(node, mi, '${slot.key}', name, v));
          } else {
            developer.log('Viewport: material parameter $name of ${node.id} takes a colour or a scalar', name: 'UMG', level: 900);
          }
        } catch (e) {
          developer.log('Viewport: material parameter $name of ${node.id}: $e', name: 'UMG', level: 900);
        }
      }
    }
  }

  /// The skeletons read per mesh asset.
  static final Map<String, LuminaViewportSkeleton> _skeletonCache = {};

  /// The entities of [node]'s skeleton on its current instance (resolved
  /// once per instance); empty before load.
  List<int> _jointEntities(_RuntimeNode node) {
    final instance = node.skeletal?.assetInstance;
    if (instance == null || instance.skinCount == 0) return const [];
    if (!identical(node.jointEntitiesOf, instance) || node.jointEntities.length != node.skeleton.length) {
      final tm = FilamentTransformManager(engine);
      node.jointEntities = node.skeleton.entities(instance.jointsAt, tm.getParent);
      node.jointEntitiesOf = instance;
    }
    return node.jointEntities;
  }

  // --- Picking and joints ----------------------------------------------------

  /// The node under pixel ([x], [y]) (top-left origin), the nearest bone of
  /// a skeletal mesh and the hit location; null over the background.
  LuminaViewportPick? pick(double x, double y) {
    final ray = orbit.rayAt(x, y);
    _RuntimeNode? best;
    var bestT = double.infinity;
    for (final node in _nodes.values) {
      if (node.json['pickable'] == false || node.json['visible'] == false) continue;
      final box = _worldBounds(node);
      if (box == null) continue;
      final t = ray.hitAabb(box);
      if (t != null && t < bestT) {
        bestT = t;
        best = node;
      }
    }
    if (best == null) return null;
    var hit = ray.at(bestT);
    String? bone;
    final joints = jointsOf(best.id);
    if (joints.isNotEmpty) {
      var bestD = double.infinity;
      for (final j in joints) {
        final d = ray.distanceTo(j.position);
        if (d < bestD) {
          bestD = d;
          bone = j.name;
          hit = ray.at(ray.closestT(j.position));
        }
      }
    }
    final a = LuminaAxes.toAuthoringLocation(hit);
    return LuminaViewportPick(best.id, bone, Vector3(a[0], a[1], a[2]));
  }

  /// The joints of skeletal node [id] with their world positions (runtime
  /// frame); empty for other nodes or before load.
  List<LuminaViewportJoint> jointsOf(String id) {
    final mesh = _nodes[id]?.skeletal;
    final instance = mesh?.assetInstance;
    if (instance == null || instance.skinCount == 0) return const [];
    final tm = FilamentTransformManager(engine);
    final names = _nodes[id]!.jointNames;
    final entities = _jointEntities(_nodes[id]!);
    final index = {for (var i = 0; i < entities.length; i++) entities[i]: i};
    return [
      for (var i = 0; i < entities.length; i++)
        LuminaViewportJoint(
          i < names.length ? names[i] : '#${entities[i]}',
          index[tm.getParent(entities[i])] ?? -1,
          Matrix4.fromList(tm.getWorldTransform(entities[i])).getTranslation(),
        ),
    ];
  }

  /// The joints of skeletal node [id] posed by [pose] (joint → local `[x,
  /// y, z, qx, qy, qz, qw]` in the mesh's frame, glTF metres); joints the
  /// pose leaves out keep their current local transform. Empty before load.
  List<LuminaViewportJoint> ghostJointsOf(String id, Map<String, Object?> pose) {
    final node = _nodes[id];
    final instance = node?.skeletal?.assetInstance;
    if (node == null || instance == null || instance.skinCount == 0) return const [];
    final tm = FilamentTransformManager(engine);
    final entities = _jointEntities(node);
    final names = node.jointNames;
    final index = {for (var i = 0; i < entities.length; i++) entities[i]: i};
    final worlds = List<Matrix4?>.filled(entities.length, null);
    Matrix4 worldOf(int i) {
      final cached = worlds[i];
      if (cached != null) return cached;
      final e = entities[i];
      final parent = tm.getParent(e);
      final parentIndex = index[parent];
      final parentWorld = parentIndex != null
          ? worldOf(parentIndex)
          : (parent == 0 ? Matrix4.identity() : Matrix4.fromList(tm.getWorldTransform(parent)));
      final p = i < names.length ? pose[names[i]] : null;
      final Matrix4 local;
      if (p is List && p.length >= 7) {
        double at(int k) => (p[k] as num).toDouble();
        local = Matrix4.compose(Vector3(at(0), at(1), at(2)), Quaternion(at(3), at(4), at(5), at(6)), Vector3.all(1));
      } else {
        local = Matrix4.fromList(tm.getTransform(e));
      }
      return worlds[i] = parentWorld * local;
    }

    return [
      for (var i = 0; i < entities.length; i++)
        LuminaViewportJoint(i < names.length ? names[i] : '#${entities[i]}', index[tm.getParent(entities[i])] ?? -1,
            worldOf(i).getTranslation()),
    ];
  }

  /// [world] (runtime frame) in the glTF frame of node [id]'s mesh (its
  /// own units, before the node's transform and the asset scale); null
  /// before load.
  Vector3? toMeshFrame(String id, Vector3 world) {
    final mesh = _nodes[id]?.mesh;
    if (mesh == null || !mesh.isLoaded) return null;
    return Matrix4.inverted(mesh.renderTransform).transform3(world.clone());
  }

  /// The world transform of joint [name] of [node]'s own instance (by the
  /// skin's joint order, so two Viewports showing one cached mesh each
  /// follow their own skeleton); null when the node has no such joint.
  Matrix4? _jointWorld(_RuntimeNode node, String name) {
    final instance = node.skeletal?.assetInstance;
    final i = node.jointNames.indexOf(name);
    if (instance == null || i < 0 || instance.skinCount == 0) return null;
    final entities = _jointEntities(node);
    if (i >= entities.length || entities[i] == 0) return null;
    return Matrix4.fromList(FilamentTransformManager(engine).getWorldTransform(entities[i]));
  }

  /// [world] (runtime frame) in pixels, or null behind the camera.
  (double, double)? project(Vector3 world) => orbit.project(world);

  /// An authoring point (cm, Z up) in pixels, or null behind the camera.
  (double, double)? projectAuthoring(List<double> p) => orbit.project(LuminaAxes.location(p));

  /// Reads a node's `sockets` from its skeletal mesh `.lmas` (name → bone).
  static Map<String, String> socketsOf(String metadataSockets) {
    try {
      final decoded = jsonDecode(metadataSockets);
      final list = decoded is Map ? decoded['sockets'] : decoded;
      if (list is! List) return const {};
      return {
        for (final s in list)
          if (s is Map && s['name'] is String && s['bone'] is String) s['name'] as String: s['bone'] as String,
      };
    } catch (_) {
      return const {};
    }
  }

}
