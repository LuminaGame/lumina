part of '../procedural_mesh_component.dart';

/// Updating a mesh section's vertices in place.
mixin _ProceduralMeshSectionUpdates on LuminaSceneComponent {
  Map<int, _ProceduralMeshSection> get _sections;

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
}
