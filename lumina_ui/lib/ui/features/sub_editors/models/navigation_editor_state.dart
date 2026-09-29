import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../main_editor/services/editor_transform.dart' show EditorTransforms;
import '../../main_editor/view_models/editor_view_model.dart' show EditorActorNode;

/// `NavMeshBoundsVolume` is a plain level actor: a 1 m box whose `scale` *is*
/// its size in metres along the authoring X / Y / Z (Z up), centred on
/// `location`. That way the outliner, undo, save and the viewport transform
/// gizmos work on it with no special plumbing.
///
/// Units and axes: the stored transform is authoring
/// space — centimetres, Z up — and the navigation grid is the runtime's X/Z
/// ground plane with Y up, also in centimetres. [LuminaAxes] is the only
/// conversion between the two and [LuminaUnits] the only metre ↔ unit factor.
class NavMeshBoundsVolume {
  const NavMeshBoundsVolume._();

  static const String actorType = 'NavMeshBoundsVolume';
  static const String defaultName = 'NavMeshBoundsVolume';

  /// Default size in metres along authoring X / Y / Z: a 20 × 20 m footprint,
  /// 5 m tall. Stored as the actor's `scale`.
  static const List<double> defaultExtentMetres = [20.0, 20.0, 5.0];

  /// Smallest edge the inspector accepts, in world units (cm).
  static const double minExtentCm = 10.0;

  static bool isVolume(EditorActorNode actor) => actor.type == actorType;

  /// Size in metres along authoring X / Y / Z (the stored `scale`).
  static List<double> extentMetresOf(EditorActorNode actor) => List<double>.from(actor.scale);

  /// Size in world units (cm) along authoring X / Y / Z.
  static List<double> extentCmOf(EditorActorNode actor) => [for (final s in actor.scale) LuminaUnits.metres(s)];

  /// Centre in runtime axes (Y up), world units.
  static Vector3 centreOf(EditorActorNode actor) => LuminaAxes.location(actor.location);

  /// Size in runtime axes (Y up), world units.
  static Vector3 sizeOf(EditorActorNode actor) {
    final s = LuminaAxes.scale(actor.scale)..absolute();
    return s..scale(LuminaUnits.unitsPerMetre);
  }

  /// Axis-aligned runtime bounds (Y up), world units — what the grid bake
  /// reads.
  static Aabb3 aabb(EditorActorNode actor) {
    final c = centreOf(actor);
    final half = sizeOf(actor)..scale(0.5);
    return Aabb3.minMax(c - half, c + half);
  }

  /// Union of all volumes' runtime bounds (world units), or null without
  /// volumes.
  static Aabb3? unionBounds(Iterable<EditorActorNode> volumes) {
    Aabb3? out;
    for (final v in volumes) {
      final b = aabb(v);
      if (out == null) {
        out = Aabb3.copy(b);
      } else {
        out.hull(b);
      }
    }
    return out;
  }
}

/// The editable navigation settings of a level: the `NavGridConfig` draft
/// (1:1 onto the engine's fields) plus the editor-only auto-rebuild flag.
/// Every length is in world units (cm), in the model, in the level's
/// persisted `navigation.config` and in the `NavGridConfig` handed to the
/// runtime.
@immutable
class NavigationEditorConfig {
  final double cellSize;
  final double agentRadius;
  final double agentHeight;
  final double maxStepHeight;
  final int walkableLayerMask;
  final bool autoRebuild;

  /// Cell size range, cm.
  static const double minCellSize = 10.0;
  static const double maxCellSize = 200.0;

  /// Agent / step ranges the setters clamp to, cm.
  static const double maxAgentRadius = 500.0;
  static const double minAgentHeight = 10.0;
  static const double maxAgentHeight = 1000.0;
  static const double maxStepHeightLimit = 500.0;

  const NavigationEditorConfig({
    required this.cellSize,
    required this.agentRadius,
    required this.agentHeight,
    required this.maxStepHeight,
    required this.walkableLayerMask,
    required this.autoRebuild,
  });

  /// The engine's own defaults (`NavGridConfig()`), auto-rebuild off.
  factory NavigationEditorConfig.defaults() {
    const d = NavGridConfig();
    return NavigationEditorConfig(
      cellSize: d.cellSize,
      agentRadius: d.agentRadius,
      agentHeight: d.agentHeight,
      maxStepHeight: d.maxStepHeight,
      walkableLayerMask: d.walkableLayerMask,
      autoRebuild: false,
    );
  }

  NavGridConfig toNavGridConfig() => NavGridConfig(
        cellSize: cellSize,
        agentRadius: agentRadius,
        agentHeight: agentHeight,
        maxStepHeight: maxStepHeight,
        walkableLayerMask: walkableLayerMask,
      );

  NavigationEditorConfig copyWith({
    double? cellSize,
    double? agentRadius,
    double? agentHeight,
    double? maxStepHeight,
    int? walkableLayerMask,
    bool? autoRebuild,
  }) =>
      NavigationEditorConfig(
        cellSize: cellSize ?? this.cellSize,
        agentRadius: agentRadius ?? this.agentRadius,
        agentHeight: agentHeight ?? this.agentHeight,
        maxStepHeight: maxStepHeight ?? this.maxStepHeight,
        walkableLayerMask: walkableLayerMask ?? this.walkableLayerMask,
        autoRebuild: autoRebuild ?? this.autoRebuild,
      );

  /// The level payload's `navigation` section. Volumes are level actors and
  /// serialize with the actor list; their ids are mirrored here so the
  /// section is self-describing.
  Map<String, dynamic> toSection({Iterable<EditorActorNode> volumes = const []}) => {
        'version': 1,
        'backend': 'LuminaNavigationSystem',
        'config': {
          'cellSize': cellSize,
          'agentRadius': agentRadius,
          'agentHeight': agentHeight,
          'maxStepHeight': maxStepHeight,
          'walkableLayerMask': walkableLayerMask,
        },
        'autoRebuild': autoRebuild,
        'volumes': [
          for (final v in volumes) {'id': v.id, 'name': v.name},
        ],
      };

  factory NavigationEditorConfig.fromSection(Map<String, dynamic> section) {
    final d = NavigationEditorConfig.defaults();
    final raw = section['config'];
    final cfg = raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
    double num_(String key, double fallback) {
      final v = cfg[key];
      return v is num ? v.toDouble() : fallback;
    }

    final mask = cfg['walkableLayerMask'];
    final auto = section['autoRebuild'];
    return NavigationEditorConfig(
      cellSize: num_('cellSize', d.cellSize).clamp(minCellSize, maxCellSize),
      agentRadius: num_('agentRadius', d.agentRadius),
      agentHeight: num_('agentHeight', d.agentHeight),
      maxStepHeight: num_('maxStepHeight', d.maxStepHeight),
      walkableLayerMask: mask is int ? mask & 0xFFFFFFFF : d.walkableLayerMask,
      autoRebuild: auto is bool ? auto : d.autoRebuild,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NavigationEditorConfig &&
          cellSize == other.cellSize &&
          agentRadius == other.agentRadius &&
          agentHeight == other.agentHeight &&
          maxStepHeight == other.maxStepHeight &&
          walkableLayerMask == other.walkableLayerMask &&
          autoRebuild == other.autoRebuild;

  @override
  int get hashCode => Object.hash(cellSize, agentRadius, agentHeight, maxStepHeight, walkableLayerMask, autoRebuild);

  @override
  String toString() => 'NavigationEditorConfig(${toSection()})';
}

/// Per-cell occupancy captured from a built `LuminaNavigationSystem` through
/// its public `isWalkable` / `projectPointToNavigation` queries — the engine
/// has no cell-enumeration accessor yet (see the task's engine note), so the
/// overlay walks the grid by cell centre, which is exact for a uniform grid.
class NavGridSnapshot {
  final int cols;
  final int rows;
  final double cellSize;
  final double originX;
  final double originZ;
  final double floorY;
  final Uint8List _walkable;
  final Float32List _floorHeights;
  final int walkableCount;

  NavGridSnapshot._(
    this._walkable,
    this._floorHeights, {
    required this.cols,
    required this.rows,
    required this.cellSize,
    required this.originX,
    required this.originZ,
    required this.floorY,
    required this.walkableCount,
  });

  int get cellCount => cols * rows;
  int get blockedCount => cellCount - walkableCount;

  bool isWalkableCell(int col, int row) => _walkable[row * cols + col] == 1;
  double floorHeightAt(int col, int row) => _floorHeights[row * cols + col];
  double cellCenterX(int col) => originX + (col + 0.5) * cellSize;
  double cellCenterZ(int row) => originZ + (row + 0.5) * cellSize;

  /// Enumerates the grid exactly as the engine laid it out
  /// (`cols = ceil(width / cellSize)`, cell centre = `min + (i + 0.5) * cellSize`).
  static NavGridSnapshot capture(LuminaNavigationSystem nav, Aabb3 bounds) {
    final cellSize = nav.config.cellSize;
    final width = bounds.max.x - bounds.min.x;
    final depth = bounds.max.z - bounds.min.z;
    final cols = (width / cellSize).ceil();
    final rows = (depth / cellSize).ceil();
    final total = cols * rows;
    final walkable = Uint8List(total);
    final floors = Float32List(total);
    var count = 0;
    for (var r = 0; r < rows; r++) {
      final z = bounds.min.z + (r + 0.5) * cellSize;
      for (var c = 0; c < cols; c++) {
        final x = bounds.min.x + (c + 0.5) * cellSize;
        final p = Vector3(x, bounds.min.y, z);
        final idx = r * cols + c;
        if (nav.isWalkable(p)) {
          walkable[idx] = 1;
          count++;
          floors[idx] = (nav.projectPointToNavigation(p, searchRadius: cellSize)?.y ?? bounds.min.y);
        } else {
          floors[idx] = bounds.min.y;
        }
      }
    }
    return NavGridSnapshot._(
      walkable,
      floors,
      cols: cols,
      rows: rows,
      cellSize: cellSize,
      originX: bounds.min.x,
      originZ: bounds.min.z,
      floorY: bounds.min.y,
      walkableCount: count,
    );
  }
}

/// Outcome of one `buildFromWorld` run — every number is measured.
@immutable
class NavBuildResult {
  final DateTime finishedAt;
  final Duration duration;
  final int walkableCells;
  final int cols;
  final int rows;
  final double cellSize;
  final Aabb3 bounds;
  final int obstacleCount;
  final int volumeCount;

  const NavBuildResult({
    required this.finishedAt,
    required this.duration,
    required this.walkableCells,
    required this.cols,
    required this.rows,
    required this.cellSize,
    required this.bounds,
    required this.obstacleCount,
    required this.volumeCount,
  });

  int get cellCount => cols * rows;
  double get durationMs => duration.inMicroseconds / 1000.0;
}

enum NavPathState { none, found, partial, noPath }

/// One A* query through `findPathSync` with its measured cost.
@immutable
class NavPathResult {
  final Vector3 start;
  final Vector3 goal;
  final NavPath? path;
  final double queryTimeMs;
  final NavPathState state;

  const NavPathResult({
    required this.start,
    required this.goal,
    required this.path,
    required this.queryTimeMs,
    required this.state,
  });

  int get pointCount => path?.points.length ?? 0;

  /// Path length in world units (cm).
  double get length => path?.length ?? 0.0;
}

/// A level actor's collision footprint as an oriented box in runtime axes
/// (Y up), world units (cm).
@immutable
class NavObstacleBox {
  final String actorId;
  final String actorName;
  final Vector3 center;
  final Vector3 halfExtent;
  final Quaternion rotation;

  const NavObstacleBox({
    required this.actorId,
    required this.actorName,
    required this.center,
    required this.halfExtent,
    required this.rotation,
  });

  double get top => center.y + halfExtent.y;
  double get bottom => center.y - halfExtent.y;
}

/// Turns the open level's actors into the collision world the nav bake reads.
class NavigationWorldBuilder {
  const NavigationWorldBuilder._();

  static const Set<String> meshActorTypes = {'Mesh', 'StaticMesh', 'SkeletalMesh', 'filamesh', 'MeshComponent'};
  static const String capsuleComponentType = 'LuminaCapsuleComponent';

  /// Collision boxes of every actor that carries real geometry, in runtime
  /// axes and world units: the stored (Z-up) transform goes through
  /// [LuminaAxes] exactly as the viewport draws it. Mesh actors use their
  /// parsed mesh bounds (asset units, glTF Y up) × the asset unit scale ×
  /// scale; capsule components use their authored radius / half height (cm,
  /// along the runtime Y axis). Volumes, pawns, lights, folders and
  /// environment actors carry no collision.
  static List<NavObstacleBox> obstaclesFrom(Iterable<EditorActorNode> actors) {
    final out = <NavObstacleBox>[];
    for (final actor in actors) {
      if (NavMeshBoundsVolume.isVolume(actor)) continue;
      final rotation = LuminaAxes.rotation(actor.rotation);
      final location = LuminaAxes.location(actor.location);
      final scale = LuminaAxes.scale(actor.scale);

      final mesh = actor.meshData;
      if (meshActorTypes.contains(actor.type) && mesh != null && mesh.minBounds.length >= 3 && mesh.maxBounds.length >= 3) {
        final u = EditorTransforms.assetUnitScaleFor(actor);
        final min = Vector3(mesh.minBounds[0], mesh.minBounds[1], mesh.minBounds[2])..scale(u);
        final max = Vector3(mesh.maxBounds[0], mesh.maxBounds[1], mesh.maxBounds[2])..scale(u);
        final mid = (min + max) * 0.5;
        final half = (max - min) * 0.5;
        final localCentre = Vector3(mid.x * scale.x, mid.y * scale.y, mid.z * scale.z);
        final worldCentre = location + rotation.rotated(localCentre);
        final halfScaled = Vector3((half.x * scale.x).abs(), (half.y * scale.y).abs(), (half.z * scale.z).abs());
        if (halfScaled.x <= 0 && halfScaled.z <= 0) continue;
        out.add(NavObstacleBox(
          actorId: actor.id,
          actorName: actor.name,
          center: worldCentre,
          halfExtent: halfScaled,
          rotation: rotation,
        ));
        continue;
      }

      for (final comp in actor.components) {
        if (comp.type != capsuleComponentType || !comp.enabled) continue;
        final radius = _num(comp.properties['capsuleRadius'], 34.0) * scale.x.abs();
        final halfHeight = _num(comp.properties['capsuleHalfHeight'], 88.0) * scale.y.abs();
        out.add(NavObstacleBox(
          actorId: actor.id,
          actorName: actor.name,
          center: Vector3.copy(location),
          halfExtent: Vector3(radius, halfHeight, radius),
          rotation: rotation,
        ));
      }
    }
    return out;
  }

  static double _num(dynamic v, double fallback) => v is num ? v.toDouble() : fallback;

  /// Agent-relative classification the engine does not do itself: a box
  /// whose top is within `maxStepHeight` of the ground is a floor/step the
  /// agent walks over; one whose bottom clears `agentHeight` is overhead.
  /// Everything else blocks.
  static bool blocksAgent(NavObstacleBox box, {required double groundY, required NavGridConfig config}) {
    if (box.top <= groundY + config.maxStepHeight) return false;
    if (box.bottom >= groundY + config.agentHeight) return false;
    return true;
  }

  static bool intersectsXZ(NavObstacleBox box, Aabb3 bounds) {
    // Conservative: use the box's rotated AABB half-extents.
    final m = box.rotation.asRotationMatrix();
    final ex = m.entry(0, 0).abs() * box.halfExtent.x + m.entry(0, 1).abs() * box.halfExtent.y + m.entry(0, 2).abs() * box.halfExtent.z;
    final ez = m.entry(2, 0).abs() * box.halfExtent.x + m.entry(2, 1).abs() * box.halfExtent.y + m.entry(2, 2).abs() * box.halfExtent.z;
    return box.center.x + ex >= bounds.min.x &&
        box.center.x - ex <= bounds.max.x &&
        box.center.z + ez >= bounds.min.z &&
        box.center.z - ez <= bounds.max.z;
  }

  /// A pure-Dart `LuminaWorld` (no native context) holding one actor with a
  /// block-all `LuminaCollisionComponent` per obstacle — exactly what
  /// `LuminaNavigationSystem.buildFromWorld` rasterizes.
  static LuminaWorld buildWorld(Iterable<NavObstacleBox> obstacles) {
    final world = LuminaWorld(worldType: LuminaWorldType.editor);
    for (final box in obstacles) {
      final actor = LuminaActor(location: box.center, rotation: box.rotation);
      final col = LuminaCollisionComponent(shapeType: CollisionShapeType.box)..boxExtent = Vector3.copy(box.halfExtent);
      CollisionProfile.applyBlockAll(col);
      actor.addComponent(col);
      world.persistentLevel.registerActor(actor);
    }
    return world;
  }

  /// A stable fingerprint of everything the bake depends on (volumes and
  /// obstacle transforms) so the editor can tell real scene changes from
  /// unrelated notifications.
  static String signature(Iterable<EditorActorNode> actors) {
    final parts = <String>[];
    for (final a in actors) {
      final isVolume = NavMeshBoundsVolume.isVolume(a);
      final hasMesh = meshActorTypes.contains(a.type) && a.meshData != null;
      final hasCapsule = a.components.any((c) => c.type == capsuleComponentType);
      if (!isVolume && !hasMesh && !hasCapsule) continue;
      final capsules = a.components
          .where((c) => c.type == capsuleComponentType)
          .map((c) => '${c.enabled}:${c.properties['capsuleRadius']}:${c.properties['capsuleHalfHeight']}')
          .join(',');
      final bounds = hasMesh ? '${a.meshData!.minBounds}${a.meshData!.maxBounds}' : '';
      parts.add('${a.id}|${a.type}|${a.location}|${a.rotation}|${a.scale}|$bounds|$capsules');
    }
    parts.sort();
    return parts.join('\n');
  }
}
