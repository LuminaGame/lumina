part of '../procedural_mesh_component.dart';

/// Building a mesh section: vertex and index buffers, the tangent frame and
/// the renderable.
mixin _ProceduralMeshSectionCreation on LuminaSceneComponent {
  Map<int, _ProceduralMeshSection> get _sections;
  set _lastSyncedTransform(Matrix4? value);
  void clearMeshSection(int sectionIndex);

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

      // Beyond the draw distances it joins the scene when they allow.
      if (!isDistanceHidden) world.filamentScene.addEntity(entity);
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
}
