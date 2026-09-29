part of '../landscape_component.dart';

/// Foliage layers: mounting instanced chunks, adding / removing instances
/// and disposing layers.
mixin _LandscapeFoliage on _LuminaLandscapeComponentState {

  // --- Foliage -----------------------------------------------------------------

  /// Instances per foliage renderable, as the engine really allows.
  int get effectiveFoliageChunkCapacity => _effectiveChunkCapacity();

  int _effectiveChunkCapacity() {
    final requested = foliageChunkCapacity;
    if (requested != null && requested > 0) return requested;
    final w = owner?.world;
    if (w != null && w.hasNativeContext) {
      final cap = w.filamentEngine.maxAutomaticInstances;
      if (cap > 0) return cap;
    }
    return 64;
  }

  /// The volume the terrain (and the foliage standing on it) occupies, in
  /// component-local units.
  ///
  /// Filament bakes a renderable's bounds when it is built, so every foliage
  /// chunk is built with this box rather than with whatever instances happened
  /// to exist at that moment — otherwise a chunk painted far from the origin
  /// is culled against a placeholder box and silently disappears.
  @override
  Aabb3 get terrainBounds {
    final d = _data;
    if (d == null) return Aabb3.minMax(Vector3(-1, -1, -1), Vector3(1, 1, 1));
    final half = d.worldSize / 2 * unitsPerMetre;
    final top = d.maxHeight * unitsPerMetre;
    // Foliage stands on the surface, so allow generous headroom above it.
    return Aabb3.minMax(
      Vector3(-half, -top, -half),
      Vector3(half, top * 3 + 1.0, half),
    );
  }

  /// Creates (or resets) the instance batch of foliage layer [layerIndex],
  /// loading the real geometry of [meshAssetPath].
  ///
  /// Instances are added afterwards with [addFoliageInstance]; this is the
  /// seam the Landscape sub-editor paints through, and the same call the
  /// runtime build makes for every layer in the payload.
  @override
  Future<void> mountFoliageLayer(int layerIndex, {required String meshAssetPath}) async {
    final ownerActor = owner;
    if (ownerActor == null) return;
    final w = ownerActor.world;
    if (w == null || !w.hasNativeContext) {
      _foliageError = 'foliage needs a native Filament context; none is attached';
      return;
    }

    final existing = _batches[layerIndex];
    if (existing != null && existing.meshAssetPath == meshAssetPath) {
      _clearLayerInstances(layerIndex);
      return;
    }
    if (existing != null) _disposeLayer(layerIndex);
    // Painting can continue while the mesh asset is parsed; queue until then.
    _pendingInstances[layerIndex] = [];

    final geometry = _geometryCache.containsKey(meshAssetPath)
        ? _geometryCache[meshAssetPath]
        : (_geometryCache[meshAssetPath] = await LuminaLandscapeComponent._loadFoliageGeometry(meshAssetPath));
    if (geometry == null) {
      _foliageError = 'Foliage mesh "${meshAssetPath.split('/').last}" carries no readable geometry';
      return;
    }

    final engine = w.filamentEngine;
    try {
      final vb = FilamentVertexBuffer.create(
        engine: engine,
        vertexCount: geometry.vertexCount,
        bufferCount: 1,
        attributes: const [
          VertexAttributeDesc(
            attribute: VertexAttribute.position,
            type: AttributeType.float3,
            byteOffset: 0,
            byteStride: 32,
          ),
          VertexAttributeDesc(
            attribute: VertexAttribute.tangents,
            type: AttributeType.short4,
            byteOffset: 12,
            byteStride: 32,
            normalized: true,
          ),
          VertexAttributeDesc(
            attribute: VertexAttribute.uv0,
            type: AttributeType.float2,
            byteOffset: 20,
            byteStride: 32,
          ),
          // Every gltfio ubershader variant requires uv1; it reads
          // the uv0 bytes, as procedural sections do.
          VertexAttributeDesc(
            attribute: VertexAttribute.uv1,
            type: AttributeType.float2,
            byteOffset: 20,
            byteStride: 32,
          ),
          // The gltfio ubershader requires a COLOR attribute; a primitive that
          // does not declare one is dropped without drawing at all (the same
          // family of gaps as a missing uv1).
          VertexAttributeDesc(
            attribute: VertexAttribute.color,
            type: AttributeType.ubyte4,
            byteOffset: 28,
            byteStride: 32,
            normalized: true,
          ),
        ],
      );
      vb.setBufferAt(engine, 0, NativeBuffer.copy(geometry.packed));
      final ib = FilamentIndexBuffer.create(
        engine: engine,
        indexCount: geometry.indices.length,
        type: IndexType.uint,
      );
      ib.setIndicesU32(geometry.indices);

      _provider ??= FilamentMaterialProvider.ubershader(engine);
      final mi = _provider!
          .createMaterialInstance(
            MaterialKey(unlit: false, doubleSided: true, hasVertexColors: true),
            label: 'lumina_landscape_foliage_$layerIndex',
          )
          .instance;
      if (mi == null) {
        _foliageError = 'No instancing-capable material available for foliage layer $layerIndex';
        vb.dispose();
        ib.dispose();
        return;
      }
      // Lit, in the mesh's own base colour (the glTF factor, or the average of
      // its base-colour texture); the geometry-only path carries no textures.
      final c = geometry.baseColor;
      mi.setFloat4('baseColorFactor', c[0], c[1], c[2], 1.0);
      mi.setFloat('metallicFactor', 0.0);
      mi.setFloat('roughnessFactor', 0.8);
      mi.setCullingMode(CullingMode.none);

      _batches[layerIndex] = _FoliageBatch(
        meshAssetPath: meshAssetPath,
        vb: vb,
        ib: ib,
        material: mi,
        indexCount: geometry.indices.length,
      );
      _foliageError = null;
    } catch (e) {
      _foliageError = 'Foliage layer $layerIndex geometry upload failed: $e';
      _pendingInstances.remove(layerIndex);
      return;
    }

    final queued = _pendingInstances.remove(layerIndex) ?? const <Matrix4>[];
    for (final t in queued) {
      addFoliageInstance(layerIndex, t);
    }
  }

  /// Appends one instance to layer [layerIndex]; returns its global index in
  /// the layer, or `-1` when the layer is not mounted.
  ///
  /// Instances are laid down in contiguous chunks of
  /// [effectiveFoliageChunkCapacity], so the batch order always matches the
  /// payload order.
  @override
  int addFoliageInstance(int layerIndex, Matrix4 transform) {
    final batch = _batches[layerIndex];
    final ownerActor = owner;
    if (batch == null) {
      final queue = _pendingInstances[layerIndex];
      if (queue == null) return -1;
      queue.add(transform);
      return queue.length - 1;
    }
    if (ownerActor == null) return -1;
    final capacity = _effectiveChunkCapacity();
    final globalIndex = batch.transforms.length;
    final chunkIndex = globalIndex ~/ capacity;
    while (batch.chunks.length <= chunkIndex) {
      final chunk = LuminaInstancedStaticMeshComponent(
        lods: [
          LuminaStaticMeshLod(vb: batch.vb, ib: batch.ib, indexCount: batch.indexCount, switchDistance: 1e9),
        ],
        material: batch.material,
        capacity: capacity,
        initialBounds: terrainBounds,
        castShadows: true,
        receiveShadows: true,
      );
      chunk.attachToComponent(this);
      chunk.onRegister(ownerActor);
      batch.chunks.add(chunk);
    }
    try {
      batch.chunks[chunkIndex].addInstance(transform);
      batch.chunks[chunkIndex].flushTransformsToGpu();
    } catch (e) {
      _foliageError = 'Foliage layer $layerIndex chunk $chunkIndex refused an instance: $e';
      return -1;
    }
    batch.transforms.add(transform);
    return globalIndex;
  }

  /// Swap-removes an instance: the layer's last instance moves into the hole,
  /// exactly as `LuminaInstancedStaticMeshComponent.removeInstance` does, so a
  /// caller mirroring the batch in its own array stays in step.
  void removeFoliageInstance(int layerIndex, int instanceIndex) {
    final batch = _batches[layerIndex];
    if (batch == null) {
      final queue = _pendingInstances[layerIndex];
      if (queue == null || instanceIndex < 0 || instanceIndex >= queue.length) return;
      final last = queue.removeLast();
      if (instanceIndex < queue.length) queue[instanceIndex] = last;
      return;
    }
    final lastIndex = batch.transforms.length - 1;
    if (instanceIndex < 0 || instanceIndex > lastIndex) return;
    final capacity = _effectiveChunkCapacity();
    try {
      if (instanceIndex != lastIndex) {
        final moved = batch.transforms[lastIndex];
        batch.transforms[instanceIndex] = moved;
        final chunk = batch.chunks[instanceIndex ~/ capacity];
        chunk.updateInstanceTransform(instanceIndex % capacity, moved);
        chunk.flushTransformsToGpu();
      }
      final lastChunk = batch.chunks[lastIndex ~/ capacity];
      lastChunk.removeInstance(lastIndex % capacity);
      lastChunk.flushTransformsToGpu();
      batch.transforms.removeLast();
    } catch (e) {
      _foliageError = 'Foliage layer $layerIndex could not drop instance $instanceIndex: $e';
    }
  }

  /// Drops every mounted foliage layer (the batches and their renderables).
  void clearFoliage() {
    for (final layerIndex in _batches.keys.toList()) {
      _disposeLayer(layerIndex);
    }
    _pendingInstances.clear();
  }

  void _clearLayerInstances(int layerIndex) {
    final batch = _batches[layerIndex];
    if (batch == null) return;
    for (final chunk in batch.chunks) {
      chunk.onUnregister();
    }
    batch.chunks.clear();
    batch.transforms.clear();
  }

  void _disposeLayer(int layerIndex) {
    _clearLayerInstances(layerIndex);
    final batch = _batches.remove(layerIndex);
    if (batch == null) return;
    batch.material.dispose();
    batch.vb.dispose();
    batch.ib.dispose();
  }

  Future<void> _buildFoliage() async {
    final ownerActor = owner;
    final d = _loadData();
    if (ownerActor == null || d == null) return;
    if (d.layers.isEmpty) return;
    final w = ownerActor.world;
    if (w == null || !w.hasNativeContext) {
      _foliageError = 'foliage needs a native Filament context; none is attached';
      return;
    }
    for (var layerIndex = 0; layerIndex < d.layers.length; layerIndex++) {
      final layer = d.layers[layerIndex];
      await mountFoliageLayer(layerIndex, meshAssetPath: layer.meshAssetPath);
      if (_batches[layerIndex] == null) continue;
      for (var i = 0; i < layer.instanceCount; i++) {
        addFoliageInstance(layerIndex, foliageMatrixOf(layer.instanceAt(i)));
      }
    }
  }
}

/// One foliage layer's GPU state: its geometry and material plus the chunked
/// renderables holding its instances.
class _FoliageBatch {
  final String meshAssetPath;
  final FilamentVertexBuffer vb;
  final FilamentIndexBuffer ib;
  final FilamentMaterialInstance material;
  final int indexCount;
  final List<LuminaInstancedStaticMeshComponent> chunks = [];
  final List<Matrix4> transforms = [];

  _FoliageBatch({
    required this.meshAssetPath,
    required this.vb,
    required this.ib,
    required this.material,
    required this.indexCount,
  });
}

/// Interleaved foliage vertices in the layout the instanced batch's vertex
/// buffer declares: position `float3`, packed tangent frame `short4`, `uv0`
/// `float2`, colour `ubyte4` — 32 bytes per vertex.
class _FoliageGeometry {
  final Uint8List packed;
  final Uint32List indices;
  final int vertexCount;

  /// Linear RGB the lit foliage material is tinted with.
  final List<double> baseColor;

  const _FoliageGeometry({
    required this.packed,
    required this.indices,
    required this.vertexCount,
    this.baseColor = const [0.75, 0.75, 0.75],
  });

  static _FoliageGeometry fromParsed(List<double> positions, List<int> indices, {List<double>? baseColor}) {
    final count = positions.length ~/ 3;
    final pos = Float32List(count * 3);
    for (var i = 0; i < count * 3; i++) {
      pos[i] = positions[i];
    }
    // Area-weighted vertex normals from the real triangles.
    final normals = Float32List(count * 3);
    for (var t = 0; t + 2 < indices.length; t += 3) {
      final a = indices[t], b = indices[t + 1], c = indices[t + 2];
      if (a >= count || b >= count || c >= count) continue;
      final ux = pos[b * 3] - pos[a * 3];
      final uy = pos[b * 3 + 1] - pos[a * 3 + 1];
      final uz = pos[b * 3 + 2] - pos[a * 3 + 2];
      final vx = pos[c * 3] - pos[a * 3];
      final vy = pos[c * 3 + 1] - pos[a * 3 + 1];
      final vz = pos[c * 3 + 2] - pos[a * 3 + 2];
      final nx = uy * vz - uz * vy;
      final ny = uz * vx - ux * vz;
      final nz = ux * vy - uy * vx;
      for (final i in [a, b, c]) {
        normals[i * 3] += nx;
        normals[i * 3 + 1] += ny;
        normals[i * 3 + 2] += nz;
      }
    }

    const stride = 32;
    final packed = Uint8List(count * stride);
    final view = ByteData.view(packed.buffer);
    for (var i = 0; i < count; i++) {
      final base = i * stride;
      view.setFloat32(base, pos[i * 3], Endian.host);
      view.setFloat32(base + 4, pos[i * 3 + 1], Endian.host);
      view.setFloat32(base + 8, pos[i * 3 + 2], Endian.host);

      var nx = normals[i * 3], ny = normals[i * 3 + 1], nz = normals[i * 3 + 2];
      final len2 = nx * nx + ny * ny + nz * nz;
      if (len2 < 1e-12) {
        nx = 0.0;
        ny = 1.0;
        nz = 0.0;
      } else {
        final inv = 1.0 / math.sqrt(len2);
        nx *= inv;
        ny *= inv;
        nz *= inv;
      }
      final frame = packTangentFrame(_tangentFrameFromNormal(nx, ny, nz));
      for (var c = 0; c < 4; c++) {
        view.setInt16(base + 12 + c * 2, frame[c], Endian.host);
      }
      view.setFloat32(base + 20, 0.0, Endian.host);
      view.setFloat32(base + 24, 0.0, Endian.host);
      view.setUint8(base + 28, 255);
      view.setUint8(base + 29, 255);
      view.setUint8(base + 30, 255);
      view.setUint8(base + 31, 255);
    }

    final indexList = Uint32List(indices.length);
    for (var i = 0; i < indices.length; i++) {
      indexList[i] = indices[i];
    }
    return _FoliageGeometry(
      packed: packed,
      indices: indexList,
      vertexCount: count,
      baseColor: (baseColor != null && baseColor.length >= 3) ? baseColor.sublist(0, 3) : const [0.75, 0.75, 0.75],
    );
  }

  /// Filament's TBN frame: a unit quaternion whose third column is the normal.
  static Quaternion _tangentFrameFromNormal(double nx, double ny, double nz) {
    final n = Vector3(nx, ny, nz)..normalize();
    final helper = n.y.abs() < 0.99 ? Vector3(0, 1, 0) : Vector3(1, 0, 0);
    final t = helper.cross(n)..normalize();
    final b = n.cross(t)..normalize();
    final q = Quaternion.fromRotation(Matrix3.columns(t, b, n))..normalize();
    if (q.w < 0) q.scale(-1.0);
    return q;
  }
}
