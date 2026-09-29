import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import '../models/static_mesh_collision.dart';
import '../models/material_slot_binding.dart';
import '../models/static_mesh_lod.dart';

class StaticMeshEditorViewModel extends ChangeNotifier {
  final String assetPath;
  LuminaAsset? _asset;
  GlbMeshData? _glbMesh;

  bool _isLoading = true;
  bool _hasError = false;
  bool _isDirty = false;

  int _triangleCount = 0;
  int _vertexCount = 0;
  int _uvChannelsCount = 1;
  int _sectionCount = 1;

  /// The mesh's bounds in the authoring frame: cm, Z up, like
  /// every stored transform. Shapes are generated from these.
  List<double> _minBounds = [-50.0, -50.0, -50.0];
  List<double> _maxBounds = [50.0, 50.0, 50.0];

  /// The GLB's own bounds (metres, Y up), as the `min_bounds`/`max_bounds`
  /// metadata stores them (they describe geometry, not authored data).
  List<double> _gltfMinBounds = [-0.5, -0.5, -0.5];
  List<double> _gltfMaxBounds = [0.5, 0.5, 0.5];

  List<MaterialSlotBinding> _materialSlots = [];
  List<RealAssetInfo> _availableMaterials = const [];
  List<StaticMeshCollisionShape> _collisionShapes = [];
  String _collisionComplexity = 'default';

  double _massKg = 10.0;
  List<double> _centerOfMassOffset = [0.0, 0.0, 0.0];

  bool _showCollisionWireframe = true;

  /// Whether the loaded `collision` document was written in the GLB's
  /// metres / Y up (an older document) and converted on load.
  bool _collisionMigratedFromMetres = false;

  // LOD Management
  List<LodSlot> _lods = [];
  int? _forcedLod; // null -> LOD0 or auto
  String _lodGroup = 'SmallProp';
  bool _autoComputeLodDistances = true;

  StaticMeshEditorViewModel({
    required this.assetPath,
    LuminaAsset? initialAsset,
    GlbMeshData? initialGlbMesh,
  })  : _asset = initialAsset,
        _glbMesh = initialGlbMesh,
        _isLoading = initialGlbMesh == null;

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  bool get isDirty => _isDirty;
  LuminaAsset? get asset => _asset;
  GlbMeshData? get glbMesh => _glbMesh;

  int get triangleCount => _triangleCount;
  int get vertexCount => _vertexCount;
  int get uvChannelsCount => _uvChannelsCount;
  int get sectionCount => _sectionCount;

  /// Bounds in the authoring frame: cm, Z up.
  List<double> get minBounds => List.unmodifiable(_minBounds);
  List<double> get maxBounds => List.unmodifiable(_maxBounds);

  /// Size along X, Y and Z (height), cm.
  double get boundsWidth => (_maxBounds[0] - _minBounds[0]).abs();
  double get boundsDepth => (_maxBounds[1] - _minBounds[1]).abs();
  double get boundsHeight => (_maxBounds[2] - _minBounds[2]).abs();

  List<MaterialSlotBinding> get materialSlots => List.unmodifiable(_materialSlots);

  /// Real FILAMAT `.lmas` in this asset's project, for the slot pickers.
  List<RealAssetInfo> get availableMaterials => List.unmodifiable(_availableMaterials);
  List<StaticMeshCollisionShape> get collisionShapes => List.unmodifiable(_collisionShapes);
  String get collisionComplexity => _collisionComplexity;

  double get massKg => _massKg;
  List<double> get centerOfMassOffset => List.unmodifiable(_centerOfMassOffset);
  bool get showCollisionWireframe => _showCollisionWireframe;
  bool get collisionMigratedFromMetres => _collisionMigratedFromMetres;

  List<StaticMeshCollisionShape>? _overlayShapes;
  ({List<double> positions, List<int> indices})? _overlayLines;

  /// The collision shapes as one line list in the preview viewport's frame —
  /// the GLB as it is drawn there: metres, Y up — while the collision view is
  /// on; null when it is off or there is nothing to draw. The same
  /// instance until the shapes change, so the viewport rebuilds its lines
  /// only then.
  ({List<double> positions, List<int> indices})? get collisionOverlayLines {
    if (!_showCollisionWireframe || _collisionShapes.isEmpty) return null;
    if (identical(_overlayShapes, _collisionShapes) && _overlayLines != null) return _overlayLines;
    final positions = <double>[];
    final indices = <int>[];
    for (final shape in _collisionShapes) {
      final lines = shape.lineSegments();
      final base = positions.length ~/ 3;
      for (var i = 0; i + 2 < lines.positions.length; i += 3) {
        // Authoring cm, Z up → runtime cm, Y up → glTF metres.
        final p = LuminaAxes.location([lines.positions[i], lines.positions[i + 1], lines.positions[i + 2]]);
        positions
          ..add(LuminaUnits.toMetres(p.x))
          ..add(LuminaUnits.toMetres(p.y))
          ..add(LuminaUnits.toMetres(p.z));
      }
      indices.addAll(lines.indices.map((i) => base + i));
    }
    _overlayShapes = _collisionShapes;
    return _overlayLines = indices.isEmpty ? null : (positions: positions, indices: indices);
  }

  // LOD Getters
  List<LodSlot> get lods => List.unmodifiable(_lods);
  int? get forcedLod => _forcedLod;
  String get lodGroup => _lodGroup;
  bool get autoComputeLodDistances => _autoComputeLodDistances;

  LodSlot get activePreviewLod {
    if (_forcedLod != null && _forcedLod! >= 0 && _forcedLod! < _lods.length) {
      return _lods[_forcedLod!];
    }
    return _lods.isNotEmpty ? _lods.first : LodSlot(level: 0, triangleCount: _triangleCount, vertexCount: _vertexCount);
  }

  String get fileBasename {
    final file = File(assetPath);
    return file.path.split(Platform.pathSeparator).last.replaceAll('.lmas', '');
  }

  Future<void> load() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      final file = File(assetPath);
      if (!file.existsSync()) {
        _hasError = true;
        _isLoading = false;
        notifyListeners();
        return;
      }

      final bytes = await file.readAsBytes();
      try {
        _asset = LuminaAsset.fromBytes(bytes);
      } catch (_) {
        // Fallback for non-protobuf raw file
      }

      // Try loading mesh geometry
      if (_glbMesh == null) {
        try {
          _glbMesh = await AssetRepository.loadMeshFromDisk(assetPath);
        } catch (_) {}
      }

      // Extract geometry stats
      if (_glbMesh != null) {
        _triangleCount = _glbMesh!.triangleCount;
        _vertexCount = _glbMesh!.vertexCount;
        _sectionCount = _glbMesh!.materialNames.isNotEmpty ? _glbMesh!.materialNames.length : 1;
        _uvChannelsCount = 1;
        _setGltfBounds(_glbMesh!.minBounds, _glbMesh!.maxBounds);
      } else if (_asset?.metadata != null) {
        final meta = _asset!.metadata;
        _triangleCount = int.tryParse(meta['triangle_count'] ?? '0') ?? 0;
        _vertexCount = int.tryParse(meta['vertex_count'] ?? '0') ?? 0;
        _uvChannelsCount = int.tryParse(meta['uv_channels'] ?? '1') ?? 1;
        _sectionCount = int.tryParse(meta['sections'] ?? '1') ?? 1;

        if (meta.containsKey('min_bounds') && meta.containsKey('max_bounds')) {
          _setGltfBounds(
            meta['min_bounds']!.split(',').map((e) => double.tryParse(e.trim()) ?? 0.0).toList(),
            meta['max_bounds']!.split(',').map((e) => double.tryParse(e.trim()) ?? 0.0).toList(),
          );
        }
      }

      // Initialize Material Slots
      _materialSlots = List.generate(_sectionCount, (i) {
        final slotName = 'element_$i';
        // An import names the binding `material_slot_<n>`.
        final existingRef = _asset?.references.where((r) => r.slotName == slotName).firstOrNull ??
            _asset?.references.where((r) => r.slotName == _importedSlotName(i)).firstOrNull;
        return MaterialSlotBinding(
          index: i,
          slotName: slotName,
          assignedMaterialPath: existingRef?.assetPath,
          assignedMaterialId: existingRef?.assetId,
        );
      });

      _scanProjectMaterials();

      // Initialize Collision: always in cm, Z up; a document written in the
      // GLB's metres / Y up (an older document) goes through lumina's one
      // converter, the one the runtime reads it with.
      _collisionMigratedFromMetres = false;
      if (_asset?.metadata.containsKey('collision') == true) {
        try {
          final stored = Map<String, dynamic>.from(jsonDecode(_asset!.metadata['collision']!) as Map);
          final colJson = MeshCollisionService.authoredCollisionInCentimetres(stored);
          _collisionMigratedFromMetres = !identical(colJson, stored);
          _collisionComplexity = colJson['complexity']?.toString() ?? 'default';
          final shapesRaw = (colJson['shapes'] as List?) ?? [];
          _collisionShapes = shapesRaw.map((s) => StaticMeshCollisionShape.fromJson(Map<String, dynamic>.from(s as Map))).toList();
          if (_collisionMigratedFromMetres) {
            EngineLoggerService().log(
              'Collision of $fileBasename was stored in metres, Y up; converted to cm, Z up (Save writes it back in cm)',
              level: 'info',
              source: 'StaticMeshEditor',
            );
          }
        } catch (_) {}
      }

      // Initialize Physics
      if (_asset?.metadata.containsKey('physics') == true) {
        try {
          final physJson = jsonDecode(_asset!.metadata['physics']!);
          _massKg = (physJson['massKg'] as num?)?.toDouble() ?? 10.0;
          final comRaw = (physJson['centerOfMassOffset'] as List?)?.map((e) => (e as num).toDouble()).toList();
          if (comRaw != null && comRaw.length == 3) {
            _centerOfMassOffset = comRaw;
          }
        } catch (_) {}
      }

      // Initialize LODs
      if (_asset?.metadata.containsKey('lods') == true) {
        try {
          final lodsRaw = jsonDecode(_asset!.metadata['lods']!) as List;
          _lods = lodsRaw.map((e) => LodSlot.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        } catch (_) {
          _initDefaultLods();
        }
      } else {
        _initDefaultLods();
      }

      _isDirty = false;
      _isLoading = false;
      notifyListeners();
    } catch (e, st) {
      _hasError = true;
      _isLoading = false;
      EngineLoggerService().log('Failed to load static mesh: $e\n$st', level: 'error');
      notifyListeners();
    }
  }

  /// Takes the GLB's bounds (metres, Y up) and derives the authoring ones.
  void _setGltfBounds(List<double> gltfMin, List<double> gltfMax) {
    _gltfMinBounds = List.of(gltfMin);
    _gltfMaxBounds = List.of(gltfMax);
    final a = MeshCollisionService.toAuthoring(gltfMin[0], gltfMin[1], gltfMin[2]);
    final b = MeshCollisionService.toAuthoring(gltfMax[0], gltfMax[1], gltfMax[2]);
    _minBounds = [for (var i = 0; i < 3; i++) math.min(a[i], b[i])];
    _maxBounds = [for (var i = 0; i < 3; i++) math.max(a[i], b[i])];
  }

  void _initDefaultLods() {
    _lods = [
      LodSlot(
        level: 0,
        reductionRatio: 1.0,
        screenSize: 1.0,
        triangleCount: _triangleCount,
        vertexCount: _vertexCount,
      ),
    ];
  }

  void addLod() {
    if (_lods.length >= 4) return; // Max LOD3
    final newLevel = _lods.length;
    double defaultRatio = 0.5;
    if (newLevel == 2) defaultRatio = 0.25;
    if (newLevel == 3) defaultRatio = 0.12;

    final prevScreenSize = _lods.last.screenSize;
    final newScreenSize = (prevScreenSize * 0.5).clamp(0.01, 0.99);

    final decCounts = _estimateDecimatedCounts(defaultRatio);

    _lods.add(LodSlot(
      level: newLevel,
      reductionRatio: defaultRatio,
      screenSize: newScreenSize,
      triangleCount: decCounts.$1,
      vertexCount: decCounts.$2,
    ));

    _isDirty = true;
    notifyListeners();
  }

  void removeLod(int level) {
    if (level <= 0 || level >= _lods.length) return; // Cannot remove LOD0
    _lods.removeAt(level);

    // Re-index remaining LODs
    for (int i = 0; i < _lods.length; i++) {
      _lods[i].level = i;
    }

    if (_forcedLod != null && _forcedLod! >= _lods.length) {
      _forcedLod = null;
    }

    _isDirty = true;
    notifyListeners();
  }

  void setLodRatio(int level, double ratio) {
    if (level <= 0 || level >= _lods.length) return;
    _lods[level].reductionRatio = ratio.clamp(0.05, 1.0);
    final decCounts = _estimateDecimatedCounts(_lods[level].reductionRatio);
    _lods[level].triangleCount = decCounts.$1;
    _lods[level].vertexCount = decCounts.$2;
    _isDirty = true;
    notifyListeners();
  }

  bool setLodScreenSize(int level, double screenSize) {
    if (level <= 0 || level >= _lods.length) return false;
    final prevScreenSize = _lods[level - 1].screenSize;
    if (screenSize >= prevScreenSize) return false; // Strictly decreasing

    if (level < _lods.length - 1) {
      final nextScreenSize = _lods[level + 1].screenSize;
      if (screenSize <= nextScreenSize) return false;
    }

    _lods[level].screenSize = screenSize.clamp(0.01, 1.0);
    _isDirty = true;
    notifyListeners();
    return true;
  }

  void setLodMaterialOverride(int level, String slotName, String? materialPath) {
    if (level < 0 || level >= _lods.length) return;
    if (materialPath != null && materialPath.isNotEmpty) {
      _lods[level].materialOverrides[slotName] = materialPath;
    } else {
      _lods[level].materialOverrides.remove(slotName);
    }
    _isDirty = true;
    notifyListeners();
  }

  void setLodGroup(String group) {
    _lodGroup = group;
    // Apply presets
    switch (group) {
      case 'SmallProp':
        if (_lods.length > 1) _lods[1].screenSize = 0.4;
        if (_lods.length > 2) _lods[2].screenSize = 0.2;
        if (_lods.length > 3) _lods[3].screenSize = 0.08;
        break;
      case 'LargeProp':
        if (_lods.length > 1) _lods[1].screenSize = 0.6;
        if (_lods.length > 2) _lods[2].screenSize = 0.3;
        if (_lods.length > 3) _lods[3].screenSize = 0.15;
        break;
      case 'Foliage':
        if (_lods.length > 1) _lods[1].screenSize = 0.5;
        if (_lods.length > 2) _lods[2].screenSize = 0.25;
        if (_lods.length > 3) _lods[3].screenSize = 0.1;
        break;
      case 'Architecture':
        if (_lods.length > 1) _lods[1].screenSize = 0.7;
        if (_lods.length > 2) _lods[2].screenSize = 0.4;
        if (_lods.length > 3) _lods[3].screenSize = 0.2;
        break;
      case 'Decal':
        if (_lods.length > 1) _lods[1].screenSize = 0.3;
        if (_lods.length > 2) _lods[2].screenSize = 0.15;
        if (_lods.length > 3) _lods[3].screenSize = 0.05;
        break;
    }
    _isDirty = true;
    notifyListeners();
  }

  void setAutoComputeLodDistances(bool enabled) {
    _autoComputeLodDistances = enabled;
    if (enabled) {
      // The LOD heuristic is tuned in metres.
      final maxDim = LuminaUnits.toMetres(math.max(boundsWidth, math.max(boundsDepth, boundsHeight))).clamp(0.1, 100.0);
      final factor = (maxDim / 2.0).clamp(0.5, 1.5);
      for (int i = 1; i < _lods.length; i++) {
        _lods[i].screenSize = ((1.0 / (i + 1)) * (1.0 / factor)).clamp(0.01, 0.99);
      }
    }
    _isDirty = true;
    notifyListeners();
  }

  void setForcedLod(int? level) {
    if (level == null || (level >= 0 && level < _lods.length)) {
      _forcedLod = level;
      notifyListeners();
    }
  }

  (int, int) _estimateDecimatedCounts(double ratio) {
    if (_glbMesh != null && _glbMesh!.positions.isNotEmpty && _glbMesh!.indices.isNotEmpty) {
      final dec = MeshDecimationService.decimate(
        positions: Float32List.fromList(_glbMesh!.positions),
        indices: _glbMesh!.indices,
        targetRatio: ratio,
      );
      return (dec.triangleCount, dec.vertexCount);
    }
    final tris = math.max(4, (_triangleCount * ratio).round());
    final verts = math.max(4, (_vertexCount * math.sqrt(ratio)).round());
    return (tris, verts);
  }

  /// Project root for this asset: the nearest ancestor that owns a `contents/`
  /// directory. Null when the asset lives outside a project.
  String? get projectRoot {
    var dir = File(assetPath).parent;
    for (var i = 0; i < 12; i++) {
      if (Directory('${dir.path}/contents').existsSync()) return dir.path;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  /// The slot name the import pipeline gives material slot [index].
  static String _importedSlotName(int index) => 'material_slot_$index';

  void _scanProjectMaterials() {
    final root = projectRoot;
    _availableMaterials = root == null
        ? const []
        : AssetRepository().scanProjectContents(root).where((a) => a.type == AssetType.filamat).toList();
  }

  void assignMaterial(int slotIndex, {required String materialAssetPath, required String materialAssetId}) {
    if (slotIndex < 0 || slotIndex >= _materialSlots.length) return;
    _materialSlots[slotIndex].assignedMaterialPath = materialAssetPath;
    _materialSlots[slotIndex].assignedMaterialId = materialAssetId;
    _isDirty = true;
    notifyListeners();
  }

  void clearMaterial(int slotIndex) {
    if (slotIndex < 0 || slotIndex >= _materialSlots.length) return;
    _materialSlots[slotIndex]
      ..assignedMaterialPath = null
      ..assignedMaterialId = null;
    _isDirty = true;
    notifyListeners();
  }

  void highlightMaterial(int slotIndex, bool enabled) {
    if (slotIndex >= 0 && slotIndex < _materialSlots.length) {
      _materialSlots[slotIndex].isHighlighted = enabled;
      notifyListeners();
    }
  }

  void isolateMaterial(int slotIndex, bool enabled) {
    if (slotIndex >= 0 && slotIndex < _materialSlots.length) {
      _materialSlots[slotIndex].isIsolated = enabled;
      notifyListeners();
    }
  }

  void generateCollision(StaticMeshCollisionShapeType type) {
    StaticMeshCollisionShape shape;
    switch (type) {
      case StaticMeshCollisionShapeType.box:
        shape = StaticMeshCollisionShape.createBox(_minBounds, _maxBounds);
        break;
      case StaticMeshCollisionShapeType.sphere:
        shape = StaticMeshCollisionShape.createSphere(_minBounds, _maxBounds);
        break;
      case StaticMeshCollisionShapeType.capsule:
        shape = StaticMeshCollisionShape.createCapsule(_minBounds, _maxBounds);
        break;
      case StaticMeshCollisionShapeType.convex:
        // One hull over the mesh's vertices, in cm, Z up; the
        // bounds' corners only when no geometry is loaded.
        shape = StaticMeshCollisionShape.createConvexHull(_minBounds, _maxBounds, samplePoints: _meshHullPoints());
        break;
    }
    _collisionShapes = [shape];
    _isDirty = true;
    notifyListeners();
  }

  /// The corners of the convex hull of the mesh's vertices in the authoring
  /// frame, or null without geometry.
  List<List<double>>? _meshHullPoints() {
    final positions = _glbMesh?.positions;
    if (positions == null || positions.length < 12) return null;
    final points = [
      for (var i = 0; i + 2 < positions.length; i += 3)
        Vector3.array(MeshCollisionService.toAuthoring(positions[i], positions[i + 1], positions[i + 2])),
    ];
    final hull = ConvexHullShape(points);
    if (hull.isDegenerate) return null;
    return [for (final v in hull.vertices) [v.x, v.y, v.z]];
  }

  void removeCollision() {
    _collisionShapes = [];
    _isDirty = true;
    notifyListeners();
  }

  void setCollisionComplexity(String val) {
    _collisionComplexity = val;
    _isDirty = true;
    notifyListeners();
  }

  void setMass(double val) {
    _massKg = val;
    _isDirty = true;
    notifyListeners();
  }

  void setCenterOfMassOffset(List<double> offset) {
    if (offset.length == 3) {
      _centerOfMassOffset = offset;
      _isDirty = true;
      notifyListeners();
    }
  }

  void toggleCollisionWireframe() {
    _showCollisionWireframe = !_showCollisionWireframe;
    notifyListeners();
  }

  Future<bool> save() async {
    final file = File(assetPath);
    final updatedMetadata = Map<String, String>.from(_asset?.metadata ?? {});

    updatedMetadata['last_modified'] = DateTime.now().toIso8601String();
    updatedMetadata['triangle_count'] = _triangleCount.toString();
    updatedMetadata['vertex_count'] = _vertexCount.toString();
    updatedMetadata['uv_channels'] = _uvChannelsCount.toString();
    updatedMetadata['sections'] = _sectionCount.toString();
    updatedMetadata['min_bounds'] = '${_gltfMinBounds[0]},${_gltfMinBounds[1]},${_gltfMinBounds[2]}';
    updatedMetadata['max_bounds'] = '${_gltfMaxBounds[0]},${_gltfMaxBounds[1]},${_gltfMaxBounds[2]}';

    // Collision metadata, marked with its frame.
    if (_collisionShapes.isNotEmpty || _collisionComplexity != 'default') {
      updatedMetadata['collision'] = jsonEncode({
        'world_units': 'cm',
        'up_axis': 'z',
        'complexity': _collisionComplexity,
        'shapes': _collisionShapes.map((s) => s.toJson()).toList(),
      });
    } else {
      updatedMetadata.remove('collision');
    }

    // Physics metadata
    updatedMetadata['physics'] = jsonEncode({
      'massKg': _massKg,
      'centerOfMassOffset': _centerOfMassOffset,
    });

    // LODs metadata
    updatedMetadata['lods'] = jsonEncode(_lods.map((l) => l.toJson()).toList());

    // Updated references: the slots own `element_<n>` and the import's
    // `material_slot_<n>` for their indices; every other reference is kept.
    final ownedSlotNames = {
      for (final slot in _materialSlots) ...[slot.slotName, _importedSlotName(slot.index)],
    };
    final updatedRefs = <AssetReference>[
      ...?_asset?.references.where((r) => !ownedSlotNames.contains(r.slotName)),
    ];
    for (final slot in _materialSlots) {
      if (slot.assignedMaterialPath != null && slot.assignedMaterialId != null) {
        updatedRefs.add(AssetReference(
          assetId: slot.assignedMaterialId!,
          assetPath: slot.assignedMaterialPath!,
          slotName: slot.slotName,
        ));
      }
    }

    final updatedAsset = LuminaAsset(
      assetId: _asset?.assetId ?? fileBasename,
      name: _asset?.name ?? fileBasename,
      type: AssetType.filamesh,
      hasThumbnail: _asset?.hasThumbnail ?? false,
      thumbnailPng: _asset?.thumbnailPng,
      rawPayload: _asset?.rawPayload,
      rawMatSource: _asset?.rawMatSource ?? '',
      metadata: updatedMetadata,
      references: updatedRefs,
    );

    try {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(updatedAsset.toProtoBufferBytes());
      _asset = updatedAsset;
      _isDirty = false;
      EngineLoggerService().log('Saved StaticMesh asset to $assetPath', level: 'info');
      notifyListeners();
      return true;
    } catch (e, st) {
      EngineLoggerService().log('Failed to save StaticMesh asset: $e\n$st', level: 'error');
      return false;
    }
  }
}
