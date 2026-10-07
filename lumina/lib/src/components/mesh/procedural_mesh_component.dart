import 'package:flutter_filament/ffi.dart' as ffi;
import 'dart:typed_data';
import 'package:flutter_filament/ffi_package.dart';
import 'package:flutter_filament/filament.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/src/world/world.dart';
import 'package:lumina/src/components/base/scene_component.dart';

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
class LuminaProceduralMeshComponent extends LuminaSceneComponent {
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

  /// Creates a new procedural mesh section at [sectionIndex].
  ///
  /// A section with [uv0] always declares `uv1` too, because every gltfio
  /// ubershader variant requires it: pass [uv1] for a
  /// second UV set of its own, or leave it null and `uv1` reads the `uv0`
  /// values (the attribute points at the same bytes; nothing is copied, and a
  /// later [updateMeshSection] of `uv0` updates both). Those materials also
  /// require [uv0] and [colors]: a section without them draws, but the
  /// shader reads undefined values for the missing attributes.
  ///
  /// [generateTangents] builds the tangent frame (normals) that lit materials
  /// need. By default it uses MIKKTSPACE when [uv0] is given, which may split
  /// **or reorder** vertices (see [isSectionRemeshed]), and Frisvad (normals
  /// only, order-preserving) otherwise. [tangentAlgorithm] overrides that
  /// choice: a caller that updates vertex windows in place and has no normal
  /// map to honour (a heightfield) passes [TsmAlgorithm.frisvad] so its rows
  /// stay addressable. Pass `generateTangents: false` when the material is
  /// unlit and needs no tangent frame at all.
  ///
  /// [castShadows] / [receiveShadows] are the renderable's shadow flags; the
  /// defaults are Filament's own (not a caster, a receiver).
  void createMeshSection(
    int sectionIndex, {
    required Float32List positions,
    Float32List? normals,
    Float32List? uv0,
    Float32List? uv1,
    Uint8List? colors,
    required Uint32List indices,
    FilamentMaterialInstance? material,
    bool generateTangents = true,
    TsmAlgorithm? tangentAlgorithm,
    bool dynamic = false,
    Aabb3? bounds,
    bool castShadows = false,
    bool receiveShadows = true,
  }) {
    if (positions.length % 3 != 0) {
      throw ArgumentError(
        'positions length must be divisible by 3 (got ${positions.length}) for section $sectionIndex',
      );
    }
    final inputVertexCount = positions.length ~/ 3;
    if (inputVertexCount == 0) {
      throw ArgumentError('positions cannot be empty for section $sectionIndex');
    }
    if (normals != null && normals.length != inputVertexCount * 3) {
      throw ArgumentError(
        'normals count (${normals.length ~/ 3}) must match vertex count ($inputVertexCount) for section $sectionIndex',
      );
    }
    if (uv0 != null && uv0.length != inputVertexCount * 2) {
      throw ArgumentError(
        'uv0 count (${uv0.length ~/ 2}) must match vertex count ($inputVertexCount) for section $sectionIndex',
      );
    }
    if (uv1 != null && uv1.length != inputVertexCount * 2) {
      throw ArgumentError(
        'uv1 count (${uv1.length ~/ 2}) must match vertex count ($inputVertexCount) for section $sectionIndex',
      );
    }
    if (colors != null && colors.length != inputVertexCount * 4) {
      throw ArgumentError(
        'colors count (${colors.length ~/ 4}) must match vertex count ($inputVertexCount) for section $sectionIndex',
      );
    }
    if (indices.length % 3 != 0) {
      throw ArgumentError('indices length must be divisible by 3 for section $sectionIndex');
    }
    for (int i = 0; i < indices.length; i++) {
      final idx = indices[i];
      if (idx >= inputVertexCount) {
        throw RangeError('index $idx at position $i out of range (vertexCount: $inputVertexCount) for section $sectionIndex');
      }
    }

    // Clear existing section if present
    clearMeshSection(sectionIndex);

    // Compute bounding box if not provided
    double minX = double.infinity, minY = double.infinity, minZ = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity, maxZ = -double.infinity;
    for (int i = 0; i < inputVertexCount; i++) {
      final x = positions[i * 3 + 0];
      final y = positions[i * 3 + 1];
      final z = positions[i * 3 + 2];
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (z < minZ) minZ = z;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
      if (z > maxZ) maxZ = z;
    }
    final sectionBounds = bounds ??
        Aabb3.minMax(
          Vector3(minX, minY, minZ),
          Vector3(maxX, maxY, maxZ),
        );

    // Tangent generation
    int finalVertexCount = inputVertexCount;
    Float32List finalPositions = positions;
    Float32List? finalNormals = normals;
    Float32List? finalUv0 = uv0;
    Float32List? finalUv1 = uv1;
    Uint32List finalIndices = indices;
    Int16List? finalQuats;
    var remeshed = false;

    if (generateTangents) {
      try {
        final tsmBuilder = TangentSpaceMeshBuilder();
        tsmBuilder.vertexCount(inputVertexCount);
        tsmBuilder.positions(positions);
        if (normals != null) tsmBuilder.normals(normals);
        if (uv0 != null) tsmBuilder.uvs(uv0);
        if (uv1 != null) tsmBuilder.aux(TsmAuxAttribute.uv1, uv1);
        tsmBuilder.triangleCount(indices.length ~/ 3);
        tsmBuilder.trianglesUint(indices);
        tsmBuilder.algorithm(tangentAlgorithm ?? (uv0 != null ? TsmAlgorithm.mikktspace : TsmAlgorithm.frisvad));

        final tsm = tsmBuilder.build();
        finalVertexCount = tsm.vertexCount;
        remeshed = tsm.remeshed;
        if (tsm.remeshed) {
          finalPositions = tsm.getPositions();
          if (uv0 != null) finalUv0 = tsm.getUVs();
          if (uv1 != null) finalUv1 = tsm.getAuxFloat(TsmAuxAttribute.uv1);
          finalIndices = tsm.getTrianglesUint32();
        }
        finalQuats = tsm.getQuatsShort4();
        tsm.destroy();
      } catch (_) {
        // Fallback if tangent generation fails on mock or zero-area geometry
        finalVertexCount = inputVertexCount;
        finalPositions = positions;
        finalUv0 = uv0;
        finalUv1 = uv1;
        finalIndices = indices;
        remeshed = false;
      }
    }

    final hasTangents = finalQuats != null;
    final hasUv = finalUv0 != null;
    final hasOwnUv1 = finalUv1 != null;
    final hasCol = colors != null;
    final hasNorm = finalNormals != null;

    int offset = 12; // Position is always float3 (12 bytes)
    int tangentOffset = -1;
    int uv0Offset = -1;
    int uv1Offset = -1;
    int colorOffset = -1;
    int normalOffset = -1;

    if (hasTangents) {
      tangentOffset = offset;
      offset += 8; // short4 normalized = 8 bytes
    }
    if (hasUv) {
      uv0Offset = offset;
      offset += 8; // float2 = 8 bytes
    }
    if (hasOwnUv1) {
      uv1Offset = offset;
      offset += 8; // float2 = 8 bytes
    }
    if (hasCol) {
      colorOffset = offset;
      offset += 4; // ubyte4 normalized = 4 bytes
    }
    final stride = offset;

    // Select index buffer element type
    final indexType = finalVertexCount <= 65535 ? IndexType.ushort : IndexType.uint;

    // Allocate staging buffer
    final stagingByteSize = finalVertexCount * stride;
    final stagingPtr = calloc<ffi.Uint8>(stagingByteSize);
    final byteData = stagingPtr.asTypedList(stagingByteSize).buffer.asByteData();

    // Pack interleaved vertex attributes
    for (int i = 0; i < finalVertexCount; i++) {
      final base = i * stride;
      // Position
      byteData.setFloat32(base + 0, finalPositions[i * 3 + 0], Endian.host);
      byteData.setFloat32(base + 4, finalPositions[i * 3 + 1], Endian.host);
      byteData.setFloat32(base + 8, finalPositions[i * 3 + 2], Endian.host);

      // Tangents
      if (hasTangents) {
        byteData.setInt16(base + tangentOffset + 0, finalQuats[i * 4 + 0], Endian.host);
        byteData.setInt16(base + tangentOffset + 2, finalQuats[i * 4 + 1], Endian.host);
        byteData.setInt16(base + tangentOffset + 4, finalQuats[i * 4 + 2], Endian.host);
        byteData.setInt16(base + tangentOffset + 6, finalQuats[i * 4 + 3], Endian.host);
      }

      // UV0
      if (hasUv) {
        byteData.setFloat32(base + uv0Offset + 0, finalUv0[i * 2 + 0], Endian.host);
        byteData.setFloat32(base + uv0Offset + 4, finalUv0[i * 2 + 1], Endian.host);
      }

      // UV1
      if (hasOwnUv1) {
        byteData.setFloat32(base + uv1Offset + 0, finalUv1[i * 2 + 0], Endian.host);
        byteData.setFloat32(base + uv1Offset + 4, finalUv1[i * 2 + 1], Endian.host);
      }

      // Color
      if (hasCol) {
        final colIdx = (i < inputVertexCount ? i : (i % inputVertexCount)) * 4;
        byteData.setUint8(base + colorOffset + 0, colors[colIdx + 0]);
        byteData.setUint8(base + colorOffset + 1, colors[colIdx + 1]);
        byteData.setUint8(base + colorOffset + 2, colors[colIdx + 2]);
        byteData.setUint8(base + colorOffset + 3, colors[colIdx + 3]);
      }
    }

    final world = owner?.world;
    int entity = 0;
    FilamentVertexBuffer? vb;
    FilamentIndexBuffer? ib;

    if (world != null && world.hasNativeContext) {
      final engine = world.filamentEngine;
      final attributes = <VertexAttributeDesc>[
        VertexAttributeDesc(
          attribute: VertexAttribute.position,
          type: AttributeType.float3,
          byteOffset: 0,
          byteStride: stride,
        ),
      ];
      if (hasTangents) {
        attributes.add(
          VertexAttributeDesc(
            attribute: VertexAttribute.tangents,
            type: AttributeType.short4,
            byteOffset: tangentOffset,
            byteStride: stride,
            normalized: true,
          ),
        );
      }
      if (hasUv) {
        attributes.add(
          VertexAttributeDesc(
            attribute: VertexAttribute.uv0,
            type: AttributeType.float2,
            byteOffset: uv0Offset,
            byteStride: stride,
          ),
        );
      }
      // Every gltfio ubershader variant requires uv1. Without an
      // explicit set it reads the uv0 bytes.
      if (hasOwnUv1 || hasUv) {
        attributes.add(
          VertexAttributeDesc(
            attribute: VertexAttribute.uv1,
            type: AttributeType.float2,
            byteOffset: hasOwnUv1 ? uv1Offset : uv0Offset,
            byteStride: stride,
          ),
        );
      }
      if (hasCol) {
        attributes.add(
          VertexAttributeDesc(
            attribute: VertexAttribute.color,
            type: AttributeType.ubyte4,
            byteOffset: colorOffset,
            byteStride: stride,
            normalized: true,
          ),
        );
      }

      vb = FilamentVertexBuffer.create(
        engine: engine,
        vertexCount: finalVertexCount,
        bufferCount: 1,
        attributes: attributes,
      );

      final nativeBuf = NativeBuffer.copy(stagingPtr.asTypedList(stagingByteSize));
      vb.setBufferAt(engine, 0, nativeBuf);

      ib = FilamentIndexBuffer.create(
        engine: engine,
        indexCount: finalIndices.length,
        type: indexType,
      );

      if (indexType == IndexType.ushort) {
        final u16List = Uint16List(finalIndices.length);
        for (int i = 0; i < finalIndices.length; i++) {
          u16List[i] = finalIndices[i];
        }
        ib.setIndicesU16(u16List);
      } else {
        ib.setIndicesU32(finalIndices);
      }

      entity = EntityManager.get().create();
      final builder = RenderableBuilder(1);
      builder.geometry(0, PrimitiveType.triangles, vb, ib: ib);
      if (dynamic) {
        builder.geometryType(GeometryType.dynamicGeometry);
      }
      builder.boundingBox(
        sectionBounds.min.x,
        sectionBounds.min.y,
        sectionBounds.min.z,
        sectionBounds.max.x,
        sectionBounds.max.y,
        sectionBounds.max.z,
      );

      if (material != null) {
        builder.material(0, material);
      }
      builder.castShadows(castShadows);
      builder.receiveShadows(receiveShadows);
      builder.build(engine, entity);

      // Without a transform component a renderable is drawn with the identity
      // matrix — at the world origin, wherever this component is.
      final transform = worldTransform;
      FilamentTransformManager(engine).create(entity, localTransform: transform);
      _lastSyncedTransform = transform;

      final scene = world.filamentScene;
      scene.addEntity(entity);
    }

    final section = _ProceduralMeshSection(
      sectionIndex: sectionIndex,
      vertexCount: finalVertexCount,
      triangleCount: finalIndices.length ~/ 3,
      stride: stride,
      indexType: indexType,
      entity: entity,
      vertexBuffer: vb,
      indexBuffer: ib,
      material: material,
      stagingBuffer: stagingPtr,
      stagingByteSize: stagingByteSize,
      bounds: sectionBounds,
      hasNormals: hasNorm,
      hasUv0: hasUv,
      hasColors: hasCol,
      hasTangents: hasTangents,
      remeshed: remeshed,
      normalOffset: normalOffset,
      tangentOffset: tangentOffset,
      uv0Offset: uv0Offset,
      uv1Offset: uv1Offset,
      colorOffset: colorOffset,
    );

    _sections[sectionIndex] = section;
  }

  /// Partially or fully updates vertex data of an existing section without
  /// changing triangle topology.
  ///
  /// [normals] re-derive the tangent frame of every updated vertex (Frisvad,
  /// from the normal alone — the frame a lit material shades with); a section
  /// built without tangents ignores them. [positions] grow the section's
  /// bounds, and the renderable's, to contain the moved vertices: Filament
  /// culls and fits shadow maps against those bounds.
  void updateMeshSection(
    int sectionIndex, {
    Float32List? positions,
    Float32List? normals,
    Float32List? uv0,
    Float32List? uv1,
    Uint8List? colors,
    int vertexOffset = 0,
    bool regenerateTangents = false,
  }) {
    final section = _sections[sectionIndex];
    if (section == null) {
      throw StateError('Section $sectionIndex does not exist');
    }

    int updateCount = 0;
    if (positions != null) {
      if (positions.length % 3 != 0) {
        throw ArgumentError('positions length must be divisible by 3');
      }
      updateCount = positions.length ~/ 3;
    } else if (normals != null) {
      if (normals.length % 3 != 0) {
        throw ArgumentError('normals length must be divisible by 3');
      }
      updateCount = normals.length ~/ 3;
    } else if (uv0 != null) {
      if (uv0.length % 2 != 0) {
        throw ArgumentError('uv0 length must be divisible by 2');
      }
      updateCount = uv0.length ~/ 2;
    } else if (uv1 != null) {
      if (uv1.length % 2 != 0) {
        throw ArgumentError('uv1 length must be divisible by 2');
      }
      updateCount = uv1.length ~/ 2;
    } else if (colors != null) {
      if (colors.length % 4 != 0) {
        throw ArgumentError('colors length must be divisible by 4');
      }
      updateCount = colors.length ~/ 4;
    }

    if (uv1 != null && section.uv1Offset < 0) {
      throw StateError(
        'Section $sectionIndex has no uv1 of its own (its uv1 reads uv0); create it with uv1 to update uv1',
      );
    }

    if (vertexOffset < 0 || vertexOffset + updateCount > section.vertexCount) {
      throw RangeError(
        'Update vertex range ($vertexOffset..${vertexOffset + updateCount}) exceeds section vertex count (${section.vertexCount}) for section $sectionIndex',
      );
    }

    if (normals != null && normals.length != updateCount * 3) {
      throw ArgumentError('normals count (${normals.length ~/ 3}) must match the updated vertex count ($updateCount)');
    }

    final byteData = section.stagingBuffer!.asTypedList(section.stagingByteSize).buffer.asByteData();
    final stride = section.stride;

    // The section stores its normals only inside the packed tangent frame, so
    // new normals mean new frames.
    final Int16List? quats =
        normals != null && section.hasTangents && section.tangentOffset >= 0 && updateCount > 0
            ? _frisvadFrames(normals, updateCount)
            : null;

    for (int i = 0; i < updateCount; i++) {
      final vIdx = vertexOffset + i;
      final base = vIdx * stride;

      if (positions != null) {
        byteData.setFloat32(base + 0, positions[i * 3 + 0], Endian.host);
        byteData.setFloat32(base + 4, positions[i * 3 + 1], Endian.host);
        byteData.setFloat32(base + 8, positions[i * 3 + 2], Endian.host);
      }

      if (quats != null) {
        final t = base + section.tangentOffset;
        byteData.setInt16(t + 0, quats[i * 4 + 0], Endian.host);
        byteData.setInt16(t + 2, quats[i * 4 + 1], Endian.host);
        byteData.setInt16(t + 4, quats[i * 4 + 2], Endian.host);
        byteData.setInt16(t + 6, quats[i * 4 + 3], Endian.host);
      }

      if (uv0 != null && section.uv0Offset >= 0) {
        byteData.setFloat32(base + section.uv0Offset + 0, uv0[i * 2 + 0], Endian.host);
        byteData.setFloat32(base + section.uv0Offset + 4, uv0[i * 2 + 1], Endian.host);
      }

      if (uv1 != null && section.uv1Offset >= 0) {
        byteData.setFloat32(base + section.uv1Offset + 0, uv1[i * 2 + 0], Endian.host);
        byteData.setFloat32(base + section.uv1Offset + 4, uv1[i * 2 + 1], Endian.host);
      }

      if (colors != null && section.colorOffset >= 0) {
        byteData.setUint8(base + section.colorOffset + 0, colors[i * 4 + 0]);
        byteData.setUint8(base + section.colorOffset + 1, colors[i * 4 + 1]);
        byteData.setUint8(base + section.colorOffset + 2, colors[i * 4 + 2]);
        byteData.setUint8(base + section.colorOffset + 3, colors[i * 4 + 3]);
      }
    }

    if (positions != null) _growBounds(section, positions, updateCount);

    // Upload touched byte range to GPU vertex buffer
    final world = owner?.world;
    if (world != null && world.hasNativeContext && section.vertexBuffer != null) {
      final byteOffset = vertexOffset * stride;
      final uploadBytes = updateCount * stride;
      final sliceBytes = section.stagingBuffer!.asTypedList(section.stagingByteSize).sublist(byteOffset, byteOffset + uploadBytes);
      final nativeSlice = NativeBuffer.copy(sliceBytes);
      section.vertexBuffer!.setBufferAt(
        world.filamentEngine,
        0,
        nativeSlice,
        byteOffset: byteOffset,
      );
    }
  }

  /// Packed tangent frames for [count] normals, from Filament's Frisvad
  /// builder (normals only; one frame per vertex, order preserved).
  static Int16List _frisvadFrames(Float32List normals, int count) {
    final tsm = (TangentSpaceMeshBuilder()
          ..vertexCount(count)
          ..normals(normals)
          ..algorithm(TsmAlgorithm.frisvad))
        .build();
    try {
      return tsm.getQuatsShort4();
    } finally {
      tsm.destroy();
    }
  }

  /// Grows [section]'s bounds to contain [positions] and hands the new box to
  /// its renderable. Grow-only: a vertex window never sees the rest of the
  /// section, so it cannot know whether the box may shrink.
  void _growBounds(_ProceduralMeshSection section, Float32List positions, int count) {
    final b = section.bounds;
    var minX = b.min.x, minY = b.min.y, minZ = b.min.z;
    var maxX = b.max.x, maxY = b.max.y, maxZ = b.max.z;
    for (var i = 0; i < count; i++) {
      final x = positions[i * 3], y = positions[i * 3 + 1], z = positions[i * 3 + 2];
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (z < minZ) minZ = z;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
      if (z > maxZ) maxZ = z;
    }
    if (minX == b.min.x && minY == b.min.y && minZ == b.min.z && maxX == b.max.x && maxY == b.max.y && maxZ == b.max.z) {
      return;
    }
    section.bounds = Aabb3.minMax(Vector3(minX, minY, minZ), Vector3(maxX, maxY, maxZ));
    final world = owner?.world;
    if (world != null && world.hasNativeContext && section.entity != 0) {
      final rm = FilamentRenderableManager(world.filamentEngine);
      if (rm.hasComponent(section.entity)) {
        rm.setBoundingBox(
          entity: section.entity,
          minX: minX,
          minY: minY,
          minZ: minZ,
          maxX: maxX,
          maxY: maxY,
          maxZ: maxZ,
        );
      }
    }
  }

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

    final world = owner?.world;
    if (world != null && world.hasNativeContext && section.entity != 0) {
      final scene = world.filamentScene;
      if (visible) {
        scene.addEntity(section.entity);
      } else {
        scene.removeEntity(section.entity);
      }
    }
  }

  /// Clears and releases all native and staging resources for [sectionIndex].
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
