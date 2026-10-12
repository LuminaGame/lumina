import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_jolt/flutter_jolt.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/physics/cloth/cloth_component.dart';
import 'package:lumina/src/physics/cloth/cloth_simulator.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/physics/cloth/skinned_cloth_component.dart';
import 'package:lumina/src/physics/jolt/jolt_body_shapes.dart';
import 'package:lumina/src/physics/jolt/jolt_cloth_skinning.dart';

class _Cloth {
  _Cloth(this.body, this.version, List<int> pinned, this.pinnedLocal, this.phase, this.inverseMass)
      : pinned = Uint32List.fromList(pinned);

  final int body;
  final int version;
  Uint32List pinned;

  /// The pinned vertices' positions in the component frame (cm): their rest
  /// positions, or where a vertex pinned later was then.
  final List<Vector3> pinnedLocal;
  final double phase;

  /// A free vertex's inverse mass.
  final double inverseMass;

  /// A skinned cloth's limb colliders, the pose version it was last skinned
  /// to (−1: never, so the first skin is hard).
  LuminaJoltClothColliders? colliders;
  int skinnedVersion = -1;
}

/// Cloth on Jolt soft bodies. Each cloth is built in the world from its rest
/// pose at the component's transform; before every step its pinned vertices
/// are driven to where the component (and so its parent or socket) puts them
/// now and the wind pulls its free vertices; the component reads the pose in
/// its own frame when it draws.
///
/// Settings map to Jolt as compliances scaled by the vertices' inverse mass
/// `w = vertices / massKg`: stretch `1e-4 · w · (1/stiffness − 1)` (at least
/// `1e-6 · w`), shear twice that, dihedral bend
/// `4.5e-3 · w · (1/bendStiffness − 1)` (at least `1e-5 · w`; 0 disables bending),
/// per-vertex mass
/// `massKg / vertices`, the thickness as the vertex radius, tethers to the
/// pinned vertices so a hanging cloth does not stretch under its weight.
class LuminaJoltClothSimulator implements LuminaClothSimulator {
  LuminaJoltClothSimulator(this._world, {int Function(LuminaActor? actor)? ownerOf, int Function()? colliderProfile})
      : _ownerOf = ownerOf ?? ((_) => 0),
        _colliderProfile = colliderProfile ?? (() => 0);

  final JoltWorld Function() _world;
  final int Function(LuminaActor? actor) _ownerOf;
  final int Function() _colliderProfile;
  final Map<LuminaClothComponent, _Cloth> _cloths = {};
  double _time = 0;

  /// The Jolt body of [cloth] (tests and diagnostics).
  int? bodyOf(LuminaClothComponent cloth) => _cloths[cloth]?.body;

  @override
  bool contains(LuminaClothComponent cloth) => _cloths.containsKey(cloth);

  @override
  void add(LuminaClothComponent cloth) {
    if (_cloths.containsKey(cloth)) return;
    final record = _create(cloth);
    if (record != null) _cloths[cloth] = record;
  }

  @override
  void remove(LuminaClothComponent cloth) {
    final c = _cloths.remove(cloth);
    if (c == null) return;
    c.colliders?.destroy();
    _world().destroyBody(c.body);
  }

  @override
  void rebuild(LuminaClothComponent cloth) {
    remove(cloth);
    add(cloth);
  }

  /// Compliance of a 0..1 stiffness: `scale · (1/stiffness − 1)`, at least
  /// [floor] (null: stiffness 0 switches the constraint off).
  static double? compliance(double stiffness, double scale, {double floor = 0}) {
    if (stiffness <= 0) return null;
    final c = stiffness >= 1 ? 0.0 : scale * (1 / math.max(stiffness, 0.01) - 1);
    return math.max(c, floor);
  }

  _Cloth? _create(LuminaClothComponent cloth) {
    final g = cloth.geometry;
    if (g == null || g.simTriangles.length < 3) return null;
    final world = _world();
    final transform = cloth.worldTransform;
    final n = g.simVertexCount;
    final pinned = cloth.resolvePinnedVertices();
    final pinnedSet = pinned.toSet();
    final inverseMass = n / cloth.massKg;
    final world0 = [for (var i = 0; i < n; i++) transform.transform3(g.simVertex(i)) * kJoltScale];
    // Jolt keeps soft body vertices relative to the body: build it at their
    // centre (vertices far from the body origin made the cloth unstable).
    final centre = world0.fold(Vector3.zero(), (a, v) => a..add(v))..scale(1 / n);
    final vertices = [for (final v in world0) v - centre];
    // XPBD compliances act against the vertices' inverse mass: scaled by it,
    // a light cloth behaves like a heavy one, and never gets the near-rigid
    // constraints that made light cloth over sharp edges unstable.
    final stretch = compliance(cloth.stiffness, 1e-4 * inverseMass, floor: 1e-6 * inverseMass);
    final skin = cloth is LuminaSkinnedClothComponent ? clothSkinFor(cloth, centre) : null;
    final id = world.createCloth(
      skin: skin,
      vertices,
      g.simTriangles,
      inverseMasses: [for (var i = 0; i < n; i++) pinnedSet.contains(i) ? 0.0 : inverseMass],
      position: centre,
      settings: JoltClothSettings(
        edgeCompliance: stretch,
        shearCompliance: stretch == null ? null : stretch * 2,
        // Bending resists through angle constraints whose effective stiffness
        // grows with 1 / vertex mass: scale the compliance with it so a light
        // cloth drapes like a heavy one.
        bendCompliance: compliance(cloth.bendStiffness, 4.5e-3 * inverseMass, floor: 1e-5 * inverseMass),
        bend: cloth.bendStiffness <= 0 ? JoltClothBend.none : JoltClothBend.dihedral,
        tethers: pinned.isEmpty ? JoltClothTethers.none : JoltClothTethers.euclidean,
        tetherMaxDistanceMultiplier: 1.02,
        iterations: cloth.iterations,
        linearDamping: cloth.damping,
        friction: cloth.friction,
        vertexRadius: cloth.thickness * kJoltScale,
        gravityFactor: cloth.gravityScale,
      ),
    );
    world.setBodyOwner(id, _ownerOf(cloth.owner));
    final record = _Cloth(
      id,
      cloth.settingsVersion,
      pinned,
      [for (final i in pinned) g.simVertex(i)],
      _cloths.length * 0.37,
      inverseMass,
    );
    if (cloth is LuminaSkinnedClothComponent) _skin(cloth, record, 0);
    return record;
  }

  /// Skins [cloth] to its character's latest pose (hard the first time) and
  /// moves its limb colliders there.
  void _skin(LuminaSkinnedClothComponent cloth, _Cloth c, double dt) {
    final pose = cloth.worldAffines;
    if (pose == null || cloth.skin == null) return;
    final world = _world();
    final first = c.skinnedVersion < 0;
    if (cloth.poseVersion != c.skinnedVersion) {
      world.skinCloth(c.body, clothJointMatrices(pose), hardSkinAll: first);
      c.skinnedVersion = cloth.poseVersion;
    }
    if (!cloth.collideWithBody) return;
    final colliders = c.colliders;
    if (colliders == null) {
      final skeleton = cloth.skeleton, sampler = cloth.sampler;
      if (skeleton == null || sampler == null) return;
      c.colliders = LuminaJoltClothColliders.create(world, LuminaPhysicsAssetGenerator.fromSampler(sampler), skeleton, pose,
          owner: _ownerOf(cloth.owner), profile: _colliderProfile());
    } else if (dt > 0) {
      colliders.move(pose, dt);
    }
  }

  /// Before a step of [dt]: settings changes, pins, wind.
  void beforeStep(double dt) {
    _time += dt;
    if (_cloths.isEmpty) return;
    final world = _world();
    for (final cloth in _cloths.keys.toList()) {
      var c = _cloths[cloth]!;
      if (c.version != cloth.settingsVersion) {
        rebuild(cloth);
        final rebuilt = _cloths[cloth];
        if (rebuilt == null) continue;
        c = rebuilt;
      }
      if (cloth is LuminaSkinnedClothComponent) _skin(cloth, c, dt);
      if (c.pinned.isNotEmpty) {
        final transform = cloth.worldTransform;
        final targets = Float32List(c.pinned.length * 3);
        for (var k = 0; k < c.pinned.length; k++) {
          final p = transform.transform3(c.pinnedLocal[k].clone()) * kJoltScale;
          targets
            ..[3 * k] = p.x
            ..[3 * k + 1] = p.y
            ..[3 * k + 2] = p.z;
        }
        world.driveClothVertices(c.body, c.pinned, targets, dt);
      }
      final wind = cloth.wind;
      if (wind.length2 > 0 && cloth.windDrag > 0) {
        final t = _time + c.phase;
        final gust = 1 + cloth.windTurbulence * (0.6 * math.sin(1.7 * t) + 0.4 * math.sin(4.3 * t + c.phase));
        world.applyClothWind(c.body, wind * (gust * kJoltScale), drag: cloth.windDrag, dt: dt);
      }
    }
  }

  @override
  void setPinned(LuminaClothComponent cloth, int vertex, bool pinned) {
    final c = _cloths[cloth];
    final g = cloth.geometry;
    if (c == null || g == null || vertex < 0 || vertex >= g.simVertexCount) return;
    final list = c.pinned.toList();
    final at = list.indexOf(vertex);
    if (pinned && at < 0) {
      final positions = Float32List(g.simVertexCount * 3), normals = Float32List(g.simVertexCount * 3);
      final here = read(cloth, positions, normals)
          ? Vector3(positions[3 * vertex], positions[3 * vertex + 1], positions[3 * vertex + 2])
          : g.simVertex(vertex);
      list.add(vertex);
      c.pinnedLocal.add(here);
      _world().setClothInverseMass(c.body, vertex, 0);
    } else if (!pinned && at >= 0) {
      list.removeAt(at);
      c.pinnedLocal.removeAt(at);
      _world().setClothInverseMass(c.body, vertex, c.inverseMass);
    } else {
      return;
    }
    c.pinned = Uint32List.fromList(list);
  }

  @override
  bool read(LuminaClothComponent cloth, Float32List positions, Float32List normals) {
    final c = _cloths[cloth];
    if (c == null) return false;
    final toLocal = Matrix4.inverted(cloth.worldTransform)..scaleByDouble(kLuminaScale, kLuminaScale, kLuminaScale, 1);
    return _world().clothLocalVertices(c.body, toLocal, positions, normals) > 0;
  }

  /// The limb colliders of a skinned [cloth] (tests and diagnostics).
  int colliderCount(LuminaClothComponent cloth) => _cloths[cloth]?.colliders?.length ?? 0;

  /// Forgets every cloth (the world is going away).
  void clear() => _cloths.clear();
}
