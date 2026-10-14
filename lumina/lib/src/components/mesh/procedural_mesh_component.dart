import 'package:flutter_filament/ffi.dart' as ffi;
import 'dart:typed_data';
import 'package:flutter_filament/ffi_package.dart';
import 'package:flutter_filament/filament.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/src/world/world.dart';
import 'package:lumina/src/components/base/scene_component.dart';

part 'procedural_mesh_component/section_creation.dart';
part 'procedural_mesh_component/section_updates.dart';

class _ProceduralMeshSection {
  final int sectionIndex;
  int vertexCount;
  int triangleCount;
  int stride;
  IndexType indexType;
  int entity;
  FilamentVertexBuffer? vertexBuffer;
  FilamentIndexBuffer? indexBuffer;
  FilamentMaterialInstance? material;
  ffi.Pointer<ffi.Uint8>? stagingBuffer;
  int stagingByteSize;
  bool visible;
  Aabb3 bounds;

  bool hasNormals;
  bool hasUv0;
  bool hasColors;
  bool hasTangents;

  /// True when the tangent builder handed back a remeshed geometry: the
  /// vertices may be split **or reordered** relative to the caller's arrays,
  /// so a vertex offset computed from those arrays no longer addresses them.
  bool remeshed;

  int normalOffset;
  int tangentOffset;
  int uv0Offset;

  /// Byte offset of the section's own `uv1` values, or -1 when `uv1` reads
  /// the `uv0` bytes (no explicit `uv1` was given) or there is none.
  int uv1Offset;
  int colorOffset;

  _ProceduralMeshSection({
    required this.sectionIndex,
    required this.vertexCount,
    required this.triangleCount,
    required this.stride,
    required this.indexType,
    required this.entity,
    this.vertexBuffer,
    this.indexBuffer,
    this.material,
    this.stagingBuffer,
    required this.stagingByteSize,
    required this.bounds,
    required this.hasNormals,
    required this.hasUv0,
    required this.hasColors,
    required this.hasTangents,
    this.remeshed = false,
    required this.normalOffset,
    required this.tangentOffset,
    required this.uv0Offset,
    required this.uv1Offset,
    required this.colorOffset,
  }) : visible = true;

  void dispose(FilamentEngine? engine, FilamentScene? scene) {
    if (scene != null && entity != 0) {
      scene.removeEntity(entity);
    }
    if (engine != null && entity != 0) {
      final rm = FilamentRenderableManager(engine);
      if (rm.hasComponent(entity)) {
        rm.destroy(entity);
      }
      final tm = FilamentTransformManager(engine);
      if (tm.hasComponent(entity)) {
        tm.destroy(entity);
      }
      EntityManager.get().destroy(entity);
    }
    vertexBuffer?.dispose();
    indexBuffer?.dispose();
    vertexBuffer = null;
    indexBuffer = null;

    if (stagingBuffer != null && stagingBuffer != ffi.nullptr) {
      calloc.free(stagingBuffer!);
      stagingBuffer = null;
    }
    entity = 0;
  }
}

/// Component that allows building and deforming 3D meshes dynamically at runtime.
class LuminaProceduralMeshComponent extends LuminaSceneComponent
    with _ProceduralMeshSectionCreation, _ProceduralMeshSectionUpdates {
  @override
  final Map<int, _ProceduralMeshSection> _sections = {};

  LuminaProceduralMeshComponent({
    super.key,
    super.location,
    super.rotation,
    super.scale,
  });

  /// Number of active mesh sections.
  int get sectionCount => _sections.length;

  /// Returns whether a section at [sectionIndex] exists.
  bool hasSection(int sectionIndex) => _sections.containsKey(sectionIndex);

  /// Returns the local AABB bounding box for [sectionIndex].
  Aabb3? sectionBounds(int sectionIndex) => _sections[sectionIndex]?.bounds;

  /// Returns the vertex count for [sectionIndex].
  int sectionVertexCount(int sectionIndex) => _sections[sectionIndex]?.vertexCount ?? 0;

  /// True when the tangent builder remeshed [sectionIndex]: its vertices may
  /// be split or reordered relative to the arrays [createMeshSection] was
  /// given, even when their count is unchanged (MIKKTSPACE welds a grid back
  /// to the same count in a different order). A caller that updates vertex
  /// windows in place must rebuild such a section whole instead.
  bool isSectionRemeshed(int sectionIndex) => _sections[sectionIndex]?.remeshed ?? false;

  /// The Filament entity drawing [sectionIndex], or 0 when it has none (no
  /// section, or no native context).
  int sectionEntity(int sectionIndex) => _sections[sectionIndex]?.entity ?? 0;

  /// Returns whether [sectionIndex] is currently visible.
  bool isSectionVisible(int sectionIndex) => _sections[sectionIndex]?.visible ?? false;

  /// Test inspection helper returning the byte stride of [sectionIndex].
  int getSectionStride(int sectionIndex) => _sections[sectionIndex]?.stride ?? 0;

  /// Test inspection helper returning the IndexType of [sectionIndex].
  IndexType? getSectionIndexType(int sectionIndex) => _sections[sectionIndex]?.indexType;

  /// Test inspection helper returning the raw native memory address of the staging buffer for [sectionIndex].
  int getSectionStagingPointerAddress(int sectionIndex) =>
      _sections[sectionIndex]?.stagingBuffer?.address ?? 0;

  /// Sets the material instance for [sectionIndex].
  void setSectionMaterial(int sectionIndex, FilamentMaterialInstance mi) {
    final section = _sections[sectionIndex];
    if (section == null) return;
    section.material = mi;

    final world = owner?.world;
    if (world != null && world.hasNativeContext && section.entity != 0) {
      final rm = FilamentRenderableManager(world.filamentEngine);
      if (rm.hasComponent(section.entity)) {
        rm.setMaterialInstanceAt(section.entity, 0, mi);
      }
    }
  }

  /// Sets the visibility of [sectionIndex].
  void setSectionVisible(int sectionIndex, bool visible) {
    final section = _sections[sectionIndex];
    if (section == null || section.visible == visible) return;
    section.visible = visible;
    _syncSection(section);
  }

  /// A section is in the scene when it is visible and the component is
  /// within its draw distances.
  void _syncSection(_ProceduralMeshSection section) {
    final world = owner?.world;
    if (world == null || !world.hasNativeContext || section.entity == 0) return;
    final scene = world.filamentScene;
    final drawn = section.visible && !isDistanceHidden;
    if (drawn && !scene.hasEntity(section.entity)) scene.addEntity(section.entity);
    if (!drawn && scene.hasEntity(section.entity)) scene.removeEntity(section.entity);
  }

  @override
  void onDistanceHiddenChanged(bool hidden) {
    for (final section in _sections.values) {
      _syncSection(section);
    }
  }

  /// The sections' bounds together, the origin without any.
  @override
  ({Vector3 center, double radius}) get drawDistanceSphere {
    Aabb3? all;
    for (final s in _sections.values) {
      all = all == null ? Aabb3.copy(s.bounds) : (all..hull(s.bounds));
    }
    if (all == null) return super.drawDistanceSphere;
    final m = worldTransform;
    return (center: m.transformed3(all.center), radius: (all.max - all.min).length / 2 * m.getMaxScaleOnAxis());
  }

  /// Clears and releases all native and staging resources for [sectionIndex].
  @override
  void clearMeshSection(int sectionIndex) {
    final section = _sections.remove(sectionIndex);
    if (section == null) return;

    final world = owner?.world;
    section.dispose(world?.filamentEngineOrNull, world?.filamentSceneOrNull);
  }

  /// Clears and releases all mesh sections.
  void clearAllMeshSections() {
    final keys = _sections.keys.toList();
    for (final k in keys) {
      clearMeshSection(k);
    }
  }

  @override
  Matrix4? _lastSyncedTransform;

  /// Moves every section's entity to this component's world transform when it
  /// changed since the last sync.
  @override
  void onRenderPrep(LuminaWorld world) {
    super.onRenderPrep(world);
    if (_sections.isEmpty || !world.hasNativeContext) return;

    final current = worldTransform;
    final last = _lastSyncedTransform;
    if (last != null && _sameMatrix(last, current)) return;

    final tm = FilamentTransformManager(world.filamentEngine);
    final storage = current.storage.toList();
    for (final section in _sections.values) {
      if (section.entity != 0 && tm.hasComponent(section.entity)) {
        tm.setTransform(section.entity, storage);
      }
    }
    _lastSyncedTransform = current;
  }

  static bool _sameMatrix(Matrix4 a, Matrix4 b) {
    for (var i = 0; i < 16; i++) {
      if ((a.storage[i] - b.storage[i]).abs() > 1e-6) return false;
    }
    return true;
  }

  @override
  void onUnregister() {
    clearAllMeshSections();
    _lastSyncedTransform = null;
    super.onUnregister();
  }
}
