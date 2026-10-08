part of '../filament_thumbnail_renderer.dart';

/// Posed thumbnails of one mesh, drawn from one loaded asset.
///
/// An animation library's thumbnails are its skeletal mesh posed by each
/// clip, and every clip lives in that mesh's GLB. Loading a 300 MB GLB into
/// gltfio (parse, buffers, textures, GPU upload) and destroying it again
/// costs seconds on the thread that drives the engine, so the asset of the
/// last posed render is kept: the next pose of the same GLB (the same bytes
/// instance, which [ThumbnailMeshLoader] hands out for an unchanged mesh)
/// puts every node back to the transform it had when loaded and applies the
/// new clip (or none, for the rest pose). A different mesh,
/// [releasePosedMesh] or [dispose] destroys it.
///
/// A GLB whose clips drive morph-target weights is never kept: there is no
/// way to read the weights back, so a reused asset could show the previous
/// clip's expression.
mixin _ThumbnailPosedMeshCache on _FilamentThumbnailRendererState {
  Uint8List? _posedGlb;
  FilamentAsset? _posedAsset;
  FilamentAssetInstance? _posedInstance;
  final Map<int, List<double>> _posedRest = {};

  /// How many times a posed mesh was loaded into gltfio, for tests.
  int posedMeshLoads = 0;

  /// Destroys the kept posed mesh (the thumbnail queue calls this when it
  /// has nothing left to render).
  Future<void> releasePosedMesh() =>
      _tail = _tail.then((_) => _dropPosedMesh());

  /// Whether [part] can be drawn from the kept asset: its GLB is the mesh
  /// [ThumbnailMeshLoader] keeps (posed by a clip, or at rest for the mesh
  /// itself, an Animation Blueprint or a Blend Space without a sample).
  bool _posedCacheable(ThumbnailMeshPart part) =>
      ThumbnailMeshLoader.animatesMorphWeights(part.glb) == false;

  void _dropPosedMesh() {
    final asset = _posedAsset;
    _posedAsset = null;
    _posedInstance = null;
    _posedGlb = null;
    _posedRest.clear();
    if (asset == null) return;
    try {
      _loader?.destroyAsset(asset);
      _engine?.flushAndWait();
    } catch (e) {
      _logger.log(
        'Thumbnail renderer: releasing the posed mesh failed: $e',
        level: 'warning',
        source: 'ThumbnailRenderer',
      );
    }
  }

  /// [part]'s mesh, loaded once and reset to its rest transforms: the kept
  /// asset when [part] draws the same GLB, else a newly loaded one (which is
  /// kept). Null when it cannot be loaded.
  Future<FilamentAssetInstance?> _posedInstanceFor(
    ThumbnailMeshPart part,
    FilamentTransformManager tm,
  ) async {
    if (_posedAsset != null && identical(_posedGlb, part.glb)) {
      final instance = _posedInstance!;
      _posedRest.forEach(tm.setTransform);
      return instance;
    }
    _dropPosedMesh();
    final loader = _loader!;
    final (asset, instances) = loader.createInstancedAsset(part.glb, 1);
    if (asset == null) return null;
    if (instances.isEmpty) {
      loader.destroyAsset(asset);
      return null;
    }
    try {
      await _resources!.loadAsync(asset).timeout(const Duration(seconds: 60));
    } on TimeoutException {
      _resources!.asyncCancelLoad();
      loader.destroyAsset(asset);
      return null;
    }
    posedMeshLoads++;
    final instance = instances.first;
    for (final e in instance.entities) {
      _posedRest[e] = tm.getTransform(e);
    }
    _posedRest[instance.root] = tm.getTransform(instance.root);
    _posedAsset = asset;
    _posedInstance = instance;
    _posedGlb = part.glb;
    return instance;
  }
}
