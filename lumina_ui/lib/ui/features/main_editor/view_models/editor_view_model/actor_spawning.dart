part of '../editor_view_model.dart';

/// Spawning actors (by type, from assets, Blueprints) and loading the mesh
/// data placed actors render.
mixin _EditorActorSpawning on _EditorViewModelState {
  /// Geometry for `Primitive` actors, cached by shape+size+colour. The factory
  /// is deterministic, so one entry serves every crate of the same size.
  static final Map<String, GlbMeshData> _primitiveMeshCache = {};

  /// Builds (or reuses) the geometry a `Primitive` actor draws. Primitives
  /// carry a shape and a size instead of an imported model, so the shape is
  /// turned into a real glTF binary that goes down the same path as any mesh.
  Future<void> _loadPrimitiveMeshData(EditorActorNode actor) async {
    final component = actor.components.firstWhere(
      (c) => c.type == 'LuminaProceduralMeshComponent',
      orElse: () => EditorComponentNode(
        id: '${actor.id}_mesh',
        name: 'Shape',
        type: 'LuminaProceduralMeshComponent',
      ),
    );
    final props = component.properties;
    final shape = (props['shape'] ?? 'box').toString();
    double dim(String key, double fallback) {
      final v = props[key];
      return v is num ? v.toDouble() : fallback;
    }

    final sizeX = dim('sizeX', 1.0);
    final sizeY = dim('sizeY', 1.0);
    final sizeZ = dim('sizeZ', 1.0);
    final colorHex = (props['colorHex'] ?? '#9AA3AE').toString();
    final key = '$shape|$sizeX|$sizeY|$sizeZ|$colorHex';

    final cached = _primitiveMeshCache[key];
    if (cached != null) {
      actor.meshData = cached;
      return;
    }
    try {
      final bytes = PrimitiveGlbFactory.build(
        shape: shape,
        sizeX: sizeX,
        sizeY: sizeY,
        sizeZ: sizeZ,
        colorHex: colorHex,
      );
      final parsed = await GlbParserService.parseGlb(bytes);
      if (parsed != null) {
        _primitiveMeshCache[key] = parsed;
        actor.meshData = parsed;
      }
    } catch (e) {
      _logger.log(
        'Primitive "${actor.name}" ($shape) could not be built: $e',
        level: 'error',
        source: 'Viewport',
      );
    }
  }

  /// Scale for a mesh whose glTF was exported 100× too small (spans under
  /// 5 cm once drawn in centimetres); [1, 1, 1] for everything else.
  static List<double> _unitCorrectionFor(GlbMeshData? mesh) {
    if (mesh == null || mesh.minBounds.length < 3 || mesh.maxBounds.length < 3) return [1.0, 1.0, 1.0];
    var maxSpan = 0.0;
    for (var i = 0; i < 3; i++) {
      maxSpan = math.max(maxSpan, (mesh.maxBounds[i] - mesh.minBounds[i]).abs());
    }
    return maxSpan > 0 && maxSpan < 0.05 ? [100.0, 100.0, 100.0] : [1.0, 1.0, 1.0];
  }

  Future<void> _loadLandscapeMeshData(EditorActorNode actor) async {
    String? path = actor.meshAssetPath;
    if (path != null && path.isNotEmpty) {
      if (!File(path).existsSync()) {
        final rel = File('$projectDirPath/$path');
        if (rel.existsSync()) {
          path = rel.path;
        } else {
          path = null;
        }
      }
    }

    if (path == null || path.isEmpty) {
      final dir = Directory('$projectDirPath/contents/landscapes');
      if (dir.existsSync()) {
        final files = dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.lmas'))
            .toList();
        final baseName = actor.name.split('_').first.toLowerCase();
        for (final f in files) {
          final fName = f.uri.pathSegments.last.toLowerCase();
          if (fName.contains(baseName) || baseName.contains(fName.split('.').first)) {
            path = f.path;
            break;
          }
        }
        if (path == null && files.isNotEmpty) {
          path = files.first.path;
        }
      }
    }

    if (path != null && path.isNotEmpty) {
      try {
        final proxy = await LandscapeGlbBuilder.proxyMeshFor(path);
        if (proxy != null) {
          actor.meshData = proxy;
          actor.meshAssetPath = path;
          notifyListeners();
        }
      } catch (e) {
        _logger.log(
          'Landscape "${actor.name}" proxy mesh could not be built: $e',
          level: 'error',
          source: 'Viewport',
        );
      }
    }
  }

  @override
  Future<void> _loadActorMeshData(EditorActorNode actor) async {
    if (actor.meshData != null) return;
    if (actor.blueprintClass != null) {
      await _loadBlueprintPreview(actor);
      return;
    }
    if (actor.type == 'Primitive') {
      await _loadPrimitiveMeshData(actor);
      return;
    }
    if (actor.type == 'Landscape') {
      await _loadLandscapeMeshData(actor);
      return;
    }
    final baseName = actor.name.split('_').first.toLowerCase();

    final contentsDir = Directory('$projectDirPath/contents');
    if (!contentsDir.existsSync()) return;

    try {
      final files = contentsDir.listSync(recursive: true).whereType<File>();
      for (final f in files) {
        final fPath = f.path.toLowerCase();
        if (fPath.endsWith('.png') ||
            fPath.endsWith('.jpg') ||
            fPath.endsWith('.jpeg') ||
            fPath.endsWith('.tga') ||
            fPath.endsWith('.wav') ||
            fPath.endsWith('.mp3')) {
          continue;
        }
        final fName = f.uri.pathSegments.last.toLowerCase();
        final fBase = fName.split('.').first;

        final isMatch =
            fBase == baseName ||
            actor.name.toLowerCase().contains(fBase) ||
            fBase.contains(baseName) ||
            (baseName.contains('helicopter') && fName.contains('helicopter')) ||
            (baseName.contains('rock') && fName.contains('rock'));

        if (isMatch) {
          final parsed = await AssetRepository.loadMeshFromDisk(f.path);
          if (parsed != null) {
            actor.meshData = parsed;
            actor.meshAssetPath = f.path;
            return;
          }
        }
      }
    } catch (_) {}
  }

  /// Why [type] cannot be spawned right now, or null when it can.
  String? spawnRefusalFor(String type) {
    final entry = EditorActorCatalog.byId(type);
    if (entry != null && entry.unique && _actors.any((a) => a.type == type)) {
      return 'This level already has a ${entry.label}. Select it in the Outliner to edit it.';
    }
    return null;
  }

  /// Builds the geometry an actor draws with, if it has any. Exposed so tests
  /// can await what the viewport does lazily.
  @visibleForTesting
  Future<void> ensureActorMeshDataForTest(EditorActorNode actor) =>
      _loadActorMeshData(actor);

  /// A name and an id nothing else in the level is using.
  String _uniqueActorName(String base) {
    final taken = _actors.map((a) => a.name).toSet();
    var n = 1;
    while (taken.contains('${base}_$n')) {
      n++;
    }
    return '${base}_$n';
  }

  @override
  String _uniqueActorId() {
    final taken = _actors.map((a) => a.id).toSet();
    var n = _actors.length + 1;
    while (taken.contains('act_$n')) {
      n++;
    }
    return 'act_$n';
  }

  void spawnNewActor(String type, {String? parentId}) {
    final refusal = spawnRefusalFor(type);
    if (refusal != null) {
      _logger.log(refusal, level: 'warn', source: 'WorldTree');
      return;
    }
    final entry = EditorActorCatalog.byId(type);
    final id = _uniqueActorId();
    final name = _uniqueActorName(entry?.label.replaceAll(' ', '') ?? type);
    final node = EditorActorNode(
      id: id,
      name: name,
      type: type,
      location: switch (type) {
        'SpotLight' || 'PointLight' => [0.0, 0.0, 450.0],
        _ => [0.0, 0.0, 0.0],
      },
      rotation: switch (type) {
        'SpotLight' => [-90.0, 0.0, 0.0],
        _ => [0.0, 0.0, 0.0],
      },
      parentId: parentId,
      lightIntensity: (entry != null && entry.lightIntensity > 0)
          ? entry.lightIntensity
          : 5000.0,
      components: entry?.componentsBuilder?.call(id) ?? [],
    );
    if (node.type == 'Primitive') {
      // Give it geometry straight away so it is visible the moment it lands.
      _loadPrimitiveMeshData(node);
    }

    void apply() {
      _actors.add(node);
      _selectedActor = null;
      _logger.log(
        'Spawned new actor "$name" into scene tree',
        level: 'success',
        source: 'WorldTree',
      );
      _markDirty();
    }

    apply();

    transactions.record(
      EditorTransaction(
        label: 'Spawn $name',
        undo: () {
          _actors.removeWhere((a) => a.id == node.id);
          if (_selectedActor?.id == node.id) _selectedActor = null;
          _markDirty();
        },
        redo: apply,
      ),
    );
  }

  /// Places Blueprint [asset] as a `Blueprint` actor naming its class, drawn
  /// by its first mesh component.
  Future<void> _spawnBlueprintActor(RealAssetInfo asset, BlueprintActorPreview preview,
      {required String id, required String name, List<double>? location}) async {
    final node = EditorActorNode(
      id: id,
      name: name,
      type: 'Blueprint',
      location: location ?? [0.0, 0.0, 0.0],
      thumbnailBytes: asset.thumbnailBytes,
    )..blueprintClass = asset.relativePath;
    await _loadBlueprintPreview(node, preview: preview);
    void apply() {
      _actors.add(node);
      clearSelection();
      selectActors([node.id]);
      _logger.log('Placed Blueprint ${asset.relativePath} as "${node.name}"', level: 'success', source: 'Viewport');
      _markDirty();
      notifyListeners();
    }

    apply();
    transactions.record(EditorTransaction(
      label: 'Place ${node.name}',
      undo: () {
        _actors.removeWhere((a) => a.id == node.id);
        if (selectedActor?.id == node.id) clearSelection();
        _markDirty();
        notifyListeners();
      },
      redo: apply,
    ));
  }

  /// Reads a placed Blueprint's class and loads the mesh the viewport draws
  /// for it.
  Future<void> _loadBlueprintPreview(EditorActorNode actor, {BlueprintActorPreview? preview}) async {
    final path = actor.blueprintClass;
    if (path == null) return;
    final p = preview ?? BlueprintActorPreview.read(projectDirPath, path);
    actor.blueprintPreview = p;
    final mesh = p?.meshAsset;
    if (mesh == null || mesh.isEmpty) return;
    final file = mesh.startsWith('/') ? mesh : '$projectDirPath/$mesh';
    final parsed = await AssetRepository.loadMeshFromDisk(file);
    if (parsed != null) {
      actor.meshData = parsed;
      actor.meshAssetPath = file;
    }
  }

  Future<void> spawnActorFromAsset(
    RealAssetInfo asset, {
    List<double>? location,
  }) async {
    final count = _actors.length + 1;
    final baseName = asset.fileName.split('.').first;
    // A Blueprint class dropped into the level is an
    // instance of that class (a GameMode Blueprint cannot be placed).
    if (asset.type == AssetType.actor && asset.lmasPath != null) {
      final preview = BlueprintActorPreview.read(projectDirPath, asset.relativePath);
      if (preview != null && preview.parentClass == 'LuminaGameMode') {
        _logger.log('${asset.fileName} is a GameMode Blueprint; set it in Project Settings → Maps & Modes instead.',
            level: 'warning', source: 'SpawnActor');
        return;
      }
      if (preview != null) {
        await _spawnBlueprintActor(asset, preview, id: 'act_$count', name: '${baseName}_$count', location: location);
        return;
      }
    }
    final typeName = _getCategoryNameFromAssetType(asset.type);

    _logger.log(
      'Spawning actor from asset "${asset.fileName}" (type: $typeName, path: ${asset.relativePath})',
      level: 'info',
      source: 'SpawnActor',
    );

    GlbMeshData? meshData;
    String? resolvedMeshPath;
    List<EditorComponentNode> components = [];
    if (asset.lmasPath != null && File(asset.lmasPath!).existsSync()) {
      _logger.log(
        'Loading 3D mesh geometry from LMAS container: ${asset.lmasPath}',
        level: 'info',
        source: 'SpawnActor',
      );
      meshData = await AssetRepository.loadMeshFromDisk(asset.lmasPath!);
      if (meshData != null) resolvedMeshPath = asset.lmasPath;
    }

    // A LANDSCAPE .lmas holds a heightmap, not a mesh: lumina turns the same
    // payload the runtime LuminaLandscapeComponent draws into a glTF proxy so
    // the placed terrain really appears in the level viewport.
    if (meshData == null &&
        asset.type == AssetType.landscape &&
        asset.lmasPath != null) {
      meshData = await LandscapeGlbBuilder.proxyMeshFor(asset.lmasPath!);
      if (meshData != null) resolvedMeshPath = asset.lmasPath;
    }

    // Disk Raw 3D File Fallback (.glb, .gltf, .obj)
    if (meshData == null) {
      final contentsDir = Directory('$projectDirPath/contents');
      if (contentsDir.existsSync()) {
        try {
          final files = contentsDir.listSync(recursive: true).whereType<File>();
          for (final f in files) {
            final fName = f.uri.pathSegments.last;
            if (fName.split('.').first.toLowerCase() ==
                    baseName.toLowerCase() &&
                !fName.endsWith('.lmas')) {
              _logger.log(
                'Found companion 3D mesh file on disk: ${f.path}',
                level: 'info',
                source: 'SpawnActor',
              );
              meshData = await AssetRepository.loadMeshFromDisk(f.path);
              if (meshData != null) {
                resolvedMeshPath = f.path;
                break;
              }
            }
          }
        } catch (e) {
          _logger.log(
            'Failed during companion 3D mesh search: $e',
            level: 'warning',
            source: 'SpawnActor',
          );
        }
      }
    }

    if (meshData != null) {
      _logger.log(
        'Parsed 3D mesh for "$baseName": ${meshData.vertexCount} vertices, ${meshData.triangleCount} triangles, ${meshData.materialNames.length} material slots (${meshData.materialNames.join(", ")}), bounds: min=${meshData.minBounds} max=${meshData.maxBounds}',
        level: 'success',
        source: 'SpawnActor',
      );
    } else {
      _logger.log(
        'No 3D geometry found for asset "${asset.fileName}", using default primitive proxy',
        level: 'warning',
        source: 'SpawnActor',
      );
    }

    // Detect matched material asset for this mesh
    String? matchedMaterial;
    for (final a in _realAssets) {
      if (a.type == AssetType.filamat &&
          (a.fileName.contains(baseName) ||
              baseName.contains(a.fileName.split('.').first))) {
        matchedMaterial = a.fileName;
        break;
      }
    }
    if (matchedMaterial == null &&
        _realAssets.any((a) => a.type == AssetType.filamat)) {
      matchedMaterial = _realAssets
          .firstWhere((a) => a.type == AssetType.filamat)
          .fileName;
    }

    final spawnLoc = location ?? [0.0, 0.0, 0.0];

    // glTF is metres and every mesh draws ×100 in the centimetre world
    // so a correctly exported asset spawns at scale 1. Only an
    // asset exported a hundred times too small (a 1.8 m character spanning
    // 0.018) still needs a nudge.
    List<double> initialScale = _unitCorrectionFor(meshData);
    if (initialScale[0] != 1.0) {
      _logger.log(
        'Mesh "$baseName" spans under 5 cm; its export looks 100× too small, spawned at scale 100',
        level: 'info',
        source: 'SpawnActor',
      );
    }

    final node = EditorActorNode(
      id: 'act_$count',
      name: '${baseName}_$count',
      type: typeName,
      location: spawnLoc,
      scale: initialScale,
      materialPath: matchedMaterial ?? 'M_${baseName}_Mat',
      thumbnailBytes: asset.thumbnailBytes,
      meshData: meshData,
      meshAssetPath: resolvedMeshPath,
    );

    if (node.meshData == null) {
      await _loadActorMeshData(node);
      if (node.meshData != null && node.scale.every((s) => s == 1.0)) {
        node.scale = _unitCorrectionFor(node.meshData);
      }
    }

    void apply() {
      _actors.add(node);
      clearSelection();
      selectActors([node.id]);
      _logger.log(
        'Dropped & spawned actor "${node.name}" (#${node.id}) into 3D scene at [${spawnLoc[0].toStringAsFixed(1)}, ${spawnLoc[1].toStringAsFixed(1)}, ${spawnLoc[2].toStringAsFixed(1)}]',
        level: 'success',
        source: 'Viewport',
      );
      _markDirty();
      notifyListeners();
    }

    apply();

    transactions.record(
      EditorTransaction(
        label: 'Spawn ${node.name}',
        coalesceKey: null,
        undo: () {
          _actors.removeWhere((a) => a.id == node.id);
          if (selectedActor?.id == node.id) {
            clearSelection();
          }
          _logger.log(
            'Undo: Removed actor "${node.name}"',
            level: 'info',
            source: 'WorldTree',
          );
          _markDirty();
          notifyListeners();
        },
        redo: apply,
      ),
    );
  }

  /// Details → Static Mesh: [actorId] renders [mesh] instead,
  /// as one undo step; the viewport picks the new geometry up on its next
  /// sync. False when the asset holds no mesh.
  Future<bool> setActorMeshAsset(String actorId, RealAssetInfo mesh) async {
    final actor = _nodeById(actorId);
    final path = mesh.lmasPath;
    if (actor == null || path == null) return false;
    final parsed = await AssetRepository.loadMeshFromDisk(path);
    if (parsed == null) {
      _logger.log('"${mesh.fileName}" holds no mesh geometry; ${actor.name} keeps its mesh', level: 'warning', source: 'Details');
      return false;
    }
    final oldPath = actor.meshAssetPath;
    final oldData = actor.meshData;
    void set(String? p, GlbMeshData? data) {
      actor.meshAssetPath = p;
      actor.meshData = data;
      _markDirty();
      notifyListeners();
    }

    set(path, parsed);
    _logger.log('${actor.name} now renders ${mesh.fileName}', level: 'info', source: 'Details');
    transactions.record(EditorTransaction(
      label: 'Set ${actor.name} Static Mesh',
      coalesceKey: null,
      undo: () => set(oldPath, oldData),
      redo: () => set(path, parsed),
    ));
    return true;
  }

  /// Replaces the level's actors. Tests use this to set up a scene without
  /// going through disk; the editor itself loads them from the `.lmas`.
  @visibleForTesting
  void replaceActorsForTest(List<EditorActorNode> actors) {
    _actors
      ..clear()
      ..addAll(actors);
    notifyListeners();
  }

  String _getCategoryNameFromAssetType(AssetType type) =>
      EditorViewModel._categoryNameFromAssetType(type);
}
