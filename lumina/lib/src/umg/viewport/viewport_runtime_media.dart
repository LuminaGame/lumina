part of 'viewport_runtime.dart';

/// A motion file playing on a skeletal node (`Play Animation File`).
class _NodeMotion {
  _NodeMotion(this.motion, this.order, {required this.loop, required this.rate});
  final LuminaViewportMotion motion;
  final List<String> order;
  final bool loop;
  final double rate;
  double time = 0.0;
}

/// What a [LuminaViewportSceneRuntime] reads beyond meshes: texture material
/// parameters, ghost poses sampled from an animation, and the motion and
/// animation files a plugin process writes (`Play Animation File`).
mixin _ViewportMedia {
  Map<String, _RuntimeNode> get _nodes;
  FilamentEngine get engine;
  LuminaAssetProvider? get assetProvider;
  bool get allowFiles;
  bool get isDisposed;
  void _fail(String asset, String message);
  void _replaceMesh(_RuntimeNode node, String asset);
  void _writePose(_RuntimeNode node, Map pose);

  /// Meshes made in memory (an animation retargeted onto a node's mesh),
  /// served by [_read] by key.
  final Map<String, Uint8List> _memoryAssets = {};
  int _memorySerial = 0;

  static const String _memoryPrefix = 'memory://viewport/';

  /// Reads an asset: a mesh made in memory, else through [assetProvider] /
  /// [LuminaAssets].
  Future<Uint8List> _read(String path) {
    final memory = _memoryAssets[path];
    if (memory != null) return Future<Uint8List>.value(memory);
    return LuminaAssets.resolve(assetProvider)(path);
  }

  // --- Texture parameters ------------------------------------------------------

  /// Binds the texture asset [path] to sampler [name] of material instance
  /// [mi] of [node] (`Viewport Set Material Parameter` with a texture).
  Future<void> _bindTexture(_RuntimeNode node, FilamentMaterialInstance mi, String slot, String name, String path) async {
    final key = '$slot/$name';
    final request = node.textureRequests[key] = (node.textureRequests[key] ?? 0) + 1;
    LuminaMaterialTextures textures;
    try {
      textures = await LuminaMaterialTextures.load(
        engine,
        mi.material,
        [AssetReference(slotName: name, assetId: '', assetPath: path)],
        materialPath: node.asset,
        assetProvider: _read,
      );
    } catch (e) {
      if (!isDisposed) _fail(path, '$e');
      return;
    }
    final bound = textures.bound[name];
    if (isDisposed || node.removed || node.textureRequests[key] != request || bound == null) {
      textures.release();
      if (bound == null && !isDisposed) _fail(path, "material slot $slot has no texture parameter '$name' or the texture cannot load");
      return;
    }
    mi.setTexture(name, bound.texture, sampler: bound.sampler);
    node.textures.remove(key)?.release();
    node.textures[key] = textures;
  }

  /// Textures bound to node [id]'s material parameters.
  int boundTextureCount(String id) => _nodes[id]?.textures.length ?? 0;

  /// Whether node [id] plays a motion file.
  bool playsMotion(String id) => _nodes[id]?.motion != null;

  /// Releases every texture [node] bound.
  void _releaseTextures(_RuntimeNode node) {
    for (final t in node.textures.values) {
      t.release();
    }
    node.textures.clear();
  }

  // --- Animation clips and ghost poses -------------------------------------

  /// The clip an animation names: the `clip_name` of an animation `.lmas`,
  /// or the name itself.
  Future<String> _clipOf(String animation) async {
    if (!animation.toLowerCase().endsWith('.lmas')) return animation;
    final meta = LuminaAsset.fromBytes(await _read(animation)).metadata;
    final clip = meta['clip_name'] ?? '';
    if (clip.isEmpty) throw StateError('$animation names no clip (clip_name)');
    return clip;
  }

  /// The local pose (joint → `[x, y, z, qx, qy, qz, qw]`) of skeletal node
  /// [node] at [time] seconds of [animation], sampled on the node's own
  /// skeleton and put back; null when it cannot be sampled.
  Future<Map<String, Object?>?> _samplePose(_RuntimeNode node, String animation, double time) async {
    final mesh = node.skeletal;
    final instance = mesh?.assetInstance;
    if (mesh == null || instance == null || instance.skinCount == 0) return null;
    String clip;
    try {
      clip = await _clipOf(animation);
    } catch (e) {
      _fail(animation, '$e');
      return null;
    }
    final index = mesh.clipNames.indexOf(clip);
    if (index < 0 || isDisposed || !identical(node.root, mesh)) {
      if (index < 0) _fail(animation, "${node.asset} has no clip '$clip'");
      return null;
    }
    final tm = FilamentTransformManager(engine);
    final entities = instance.jointsAt(0);
    final saved = [for (final e in entities) tm.getTransform(e)];
    instance.animator.applyAnimation(index, time);
    final pose = <String, Object?>{};
    for (var i = 0; i < entities.length && i < node.jointNames.length; i++) {
      final m = Matrix4.fromList(tm.getTransform(entities[i]));
      final t = Vector3.zero();
      final r = Quaternion.identity();
      final s = Vector3.zero();
      m.decompose(t, r, s);
      pose[node.jointNames[i]] = <Object?>[t.x, t.y, t.z, r.x, r.y, r.z, r.w];
    }
    for (var i = 0; i < entities.length; i++) {
      tm.setTransform(entities[i], saved[i]);
    }
    instance.animator.updateBoneMatrices();
    return pose;
  }

  /// The ghost pose an overlay shows: its `ghostPose`, or its
  /// `ghostAnimation` (`{asset, time}`) sampled once and kept.
  Map<String, Object?>? ghostPoseFor(String nodeId, Map<String, Object?> overlay) {
    final pose = overlay['ghostPose'];
    if (pose is Map<String, Object?>) return pose;
    final g = overlay['ghostAnimation'];
    final node = _nodes[nodeId];
    if (g is! Map || node == null || !node.loaded) return null;
    final key = '${g['asset']}@${g['time']}';
    if (node.ghostKey == key) return node.ghostPose;
    node.ghostKey = key;
    node.ghostPose = null;
    final time = g['time'] is num ? (g['time']! as num).toDouble() : 0.0;
    unawaited(_samplePose(node, '${g['asset'] ?? ''}', time).then((p) {
      if (node.ghostKey == key) {
        node.ghostPose = p;
        _onOverlayChanged();
      }
    }));
    return null;
  }

  /// The overlays changed outside a description diff (a sampled ghost).
  void _onOverlayChanged();

  // --- Animation files ----------------------------------------------------------

  /// Plays a file a plugin process wrote on [node]: a packed motion
  /// (`KMO1`, joints in the mesh's skeleton order) or an animation (an
  /// animation `.lmas` whose clip the mesh has, or one carrying its own GLB
  /// clip, or a `.glb` clip), retargeted onto the node's mesh in a
  /// background isolate. Editor panels only ([allowFiles]).
  Future<void> _playFile(_RuntimeNode node, LuminaAnimatedMeshComponent mesh, Map a) async {
    final path = '${a['file']}';
    if (!allowFiles) {
      _fail(path, 'Play Animation File plays files in editor panels only');
      return;
    }
    final loop = a['loop'] != false;
    final rate = a['rate'] is num ? (a['rate']! as num).toDouble() : 1.0;
    final Uint8List bytes;
    try {
      bytes = await _read(path);
    } catch (e) {
      if (!isDisposed) _fail(path, '$e');
      return;
    }
    if (isDisposed || !identical(node.root, mesh)) return;
    try {
      if (LuminaViewportMotion.isPacked(bytes)) {
        final motion = LuminaViewportMotion.decode(bytes);
        final order = LuminaViewportMotion.skeletonOrder(await LuminaMeshAssetCache.meshBytes(_read, node.meshAsset));
        if (order.length != motion.joints) {
          throw FormatException('the motion has ${motion.joints} joints, ${node.asset} has ${order.length}');
        }
        mesh.stop();
        node.motion = _NodeMotion(motion, order, loop: loop, rate: rate);
        _advanceMotion(node, 0.0);
        return;
      }
      node.motion = null;
      Uint8List? clipGlb;
      String clipName;
      if (path.toLowerCase().endsWith('.lmas')) {
        final asset = LuminaAsset.fromBytes(bytes);
        clipName = asset.metadata['clip_name'] ?? asset.name;
        final payload = asset.rawPayload;
        if (mesh.hasClip(clipName)) {
          mesh.play(clipName, loop: loop);
          mesh.playRate = rate;
          return;
        }
        if (payload == null || payload.isEmpty) throw StateError('$path carries no clip for ${node.asset}');
        clipGlb = payload;
      } else {
        clipGlb = bytes;
        clipName = path.replaceAll(r'\', '/').split('/').last.replaceAll(RegExp(r'\.[^.]*$'), '');
      }
      final meshGlb = await LuminaMeshAssetCache.meshBytes(_read, node.meshAsset);
      final clip = clipGlb;
      final name = clipName;
      final result = await Isolate.run(() => GlbAnimationRetargeter.retargetInto(target: meshGlb, clip: clip, clipName: name));
      if (isDisposed || !identical(node.root, mesh)) return;
      final key = '$_memoryPrefix${_memorySerial++}/${node.id}.glb';
      _memoryAssets[key] = result.glb;
      node.pendingClip = (result.clipName, loop, rate);
      _replaceMesh(node, key);
    } catch (e) {
      if (!isDisposed) _fail(path, '$e');
    }
  }

  /// Advances [node]'s motion file by [dt] seconds and writes its pose.
  void _advanceMotion(_RuntimeNode node, double dt) {
    final m = node.motion;
    if (m == null) return;
    m.time += dt * m.rate;
    _writePose(node, m.motion.poseAt(m.time, m.order, loop: m.loop));
  }
}
