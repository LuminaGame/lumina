import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/material_slot_binding.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/skeletal_mesh_socket.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/skeletal_socket_attachment.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_sampler_parser.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';

class SkeletalMeshEditorViewModel extends ChangeNotifier {
  final String assetPath;
  LuminaAsset? _asset;
  GlbMeshData? _glbMesh;

  bool _isLoading = true;
  bool _hasError = false;
  bool _isDirty = false;

  int _triangleCount = 0;
  int _vertexCount = 0;
  int _boneCount = 0;
  final int _maxInfluences = 4;

  List<GlbNode> _allBones = [];
  List<GlbNode> _rootBones = [];
  GlbNode? _selectedBone;
  SkeletalMeshSocket? _selectedSocket;

  List<SkeletalMeshSocket> _sockets = [];
  Map<String, String> _boneRetargeting = {}; // boneName -> 'Animation'|'Skeleton'|'AnimationScaled'
  final Map<String, double> _morphWeights = {};

  RigLogicEvaluator? _rigLogicEvaluator;
  String? _dnaPath;
  final Map<String, double> _rigLogicControlValues = {};
  final Map<String, List<double>> _jointDeltas = {};

  bool _showBones = true;
  bool _displaySockets = true;
  bool _heatmapEnabled = false;
  int? _inspectedVertex;
  String _boneSearchFilter = '';

  Float32List? _reusedDeformedPositions;
  Uint8List? _reusedHeatmapColors;

  List<MaterialSlotBinding> _materialSlots = [];
  List<RealAssetInfo> _availableMaterials = const [];
  List<RealAssetInfo> _availableTextures = const [];
  List<RealAssetInfo> _availablePreviewMeshes = const [];
  final Map<int, Uint8List> _slotCompiledMaterials = {};

  /// Socket preview meshes by `.lmas` path: parsed once, null while loading
  /// or when the file is not a mesh.
  final Map<String, GlbMeshData?> _previewMeshes = {};
  bool _disposed = false;

  SkeletalMeshEditorViewModel({
    required this.assetPath,
    LuminaAsset? initialAsset,
  }) : _asset = initialAsset;

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  bool get isDirty => _isDirty;
  LuminaAsset? get asset => _asset;
  GlbMeshData? get glbMesh => _glbMesh;

  int get triangleCount => _triangleCount;
  int get vertexCount => _vertexCount;
  int get boneCount => _boneCount;
  int get maxInfluences => _glbMesh?.maxInfluences ?? _maxInfluences;

  List<GlbNode> get allBones => List.unmodifiable(_allBones);
  List<GlbNode> get rootBones => List.unmodifiable(_rootBones);
  GlbNode? get selectedBone => _selectedBone;
  SkeletalMeshSocket? get selectedSocket => _selectedSocket;

  List<SkeletalMeshSocket> get sockets => List.unmodifiable(_sockets);
  Map<String, String> get boneRetargeting => Map.unmodifiable(_boneRetargeting);

  List<GlbMorphTarget> get morphTargets => _glbMesh?.morphTargets ?? const [];
  Map<String, double> get morphWeights => Map.unmodifiable(_morphWeights);
  int get activeMorphTargetCount => _morphWeights.values.where((w) => w != 0.0).length;

  bool get hasRigLogic => _rigLogicEvaluator != null;
  RigLogicEvaluator? get rigLogic => _rigLogicEvaluator;
  String? get dnaPath => _dnaPath;
  List<String> get rigLogicControlNames => _rigLogicEvaluator?.rawControlNames ?? const [];
  Map<String, double> get rigLogicControlValues => Map.unmodifiable(_rigLogicControlValues);
  Map<String, List<double>> get jointDeltas => Map.unmodifiable(_jointDeltas);

  bool get showBones => _showBones;
  bool get displaySockets => _displaySockets;
  bool get heatmapEnabled => _heatmapEnabled;
  int? get inspectedVertex => _inspectedVertex;
  String get boneSearchFilter => _boneSearchFilter;

  List<String> get allBoneNames => _allBones.map((b) => b.name).toList();

  /// One entry per geometry section, keyed `element_<i>`.
  List<MaterialSlotBinding> get materialSlots => List.unmodifiable(_materialSlots);

  /// Real FILAMAT `.lmas` in this project, for the slot picker.
  List<RealAssetInfo> get availableMaterials => List.unmodifiable(_availableMaterials);

  /// Real texture `.lmas` in this project, for the sampler pickers.
  List<RealAssetInfo> get availableTextures => List.unmodifiable(_availableTextures);

  /// Real static and skeletal mesh `.lmas` in this project (what MCP
  /// `set_skeletal_socket` accepts), for a socket's Preview Asset picker.
  List<RealAssetInfo> get availablePreviewMeshes => List.unmodifiable(_availablePreviewMeshes);

  /// A socket's stored preview path (project-relative, or absolute) as a file.
  String? resolvePreviewAssetPath(String? stored) {
    if (stored == null || stored.isEmpty) return null;
    final normalised = stored.replaceAll(r'\', '/');
    final isAbsolute = normalised.startsWith('/') || RegExp(r'^[A-Za-z]:/').hasMatch(normalised);
    if (isAbsolute) return stored;
    final root = projectRoot;
    return root == null ? null : '$root/$normalised';
  }

  /// The meshes previewed on sockets, each at `entityWorld × G_bone × offset`.
  /// A socket whose mesh is still being read, or whose bone or file is missing, has none.
  List<SkeletalSocketAttachment> get socketAttachments {
    final mesh = _glbMesh;
    if (mesh == null) return const [];
    final result = <SkeletalSocketAttachment>[];
    for (final socket in _sockets) {
      final path = resolvePreviewAssetPath(socket.previewAssetPath);
      if (path == null) continue;
      final preview = _previewMeshes[path];
      if (preview == null) {
        _loadPreviewMesh(path);
        continue;
      }
      final world = SkeletalSocketMath.worldTransform(mesh, socket);
      if (world == null) continue;
      result.add(SkeletalSocketAttachment(
        socketName: socket.name,
        boneName: socket.parentBone,
        assetPath: path,
        mesh: preview,
        localOffset: SkeletalSocketMath.localOffset(socket),
        restWorld: world,
      ));
    }
    return result;
  }

  /// Reads a preview mesh once; the attachment appears when it is parsed.
  void _loadPreviewMesh(String path) {
    if (_previewMeshes.containsKey(path)) return;
    _previewMeshes[path] = null;
    AssetRepository.loadMeshFromDisk(path).then((mesh) {
      if (_disposed || mesh == null) return;
      _previewMeshes[path] = mesh;
      notifyListeners();
    });
  }

  /// Completes once every socket's preview mesh has been read (tests, MCP).
  Future<void> loadSocketPreviews() async {
    for (final socket in _sockets) {
      final path = resolvePreviewAssetPath(socket.previewAssetPath);
      if (path == null || _previewMeshes[path] != null) continue;
      final mesh = await AssetRepository.loadMeshFromDisk(path);
      if (_disposed) return;
      _previewMeshes[path] = mesh;
    }
    notifyListeners();
  }

  /// Section indices hidden because another slot is isolated.
  Set<int> get hiddenSectionIndices {
    final isolated = _materialSlots.where((s) => s.isIsolated).map((s) => s.index).toSet();
    if (isolated.isEmpty) return const {};
    return _materialSlots.map((s) => s.index).where((i) => !isolated.contains(i)).toSet();
  }

  /// Section indices the user asked to highlight in the preview.
  Set<int> get highlightedSectionIndices =>
      _materialSlots.where((s) => s.isHighlighted).map((s) => s.index).toSet();

  /// Compiled `.filamat` bytes per geometry section, for the slots whose bound
  /// material could be compiled. The viewport swaps these onto the matching
  /// primitives so picking a material actually changes what is on screen.
  Map<int, Uint8List> get slotCompiledMaterials => Map.unmodifiable(_slotCompiledMaterials);

  /// Compiles each bound slot's material so the preview can show it.
  ///
  /// A material `.lmas` saved from the Material Editor already carries compiled
  /// bytes; one emitted by the importer carries only source, so it is compiled
  /// here through the editor's own view model rather than a second parsing and
  /// compiling path.
  Future<void> refreshSlotMaterials() async {
    var changed = false;
    for (final slot in _materialSlots) {
      final path = slot.assignedMaterialPath;
      if (path == null) {
        if (_slotCompiledMaterials.remove(slot.index) != null) changed = true;
        continue;
      }
      final bytes = await _compiledMaterialFor(path);
      if (bytes == null) {
        if (_slotCompiledMaterials.remove(slot.index) != null) changed = true;
        continue;
      }
      _slotCompiledMaterials[slot.index] = bytes;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  Future<Uint8List?> _compiledMaterialFor(String materialAssetPath) async {
    try {
      final file = File(materialAssetPath);
      if (!file.existsSync()) return null;

      final asset = LuminaAsset.fromBytes(await file.readAsBytes());
      final payload = asset.rawPayload;
      if (payload != null && payload.isNotEmpty) return payload;
      if (asset.rawMatSource.trim().isEmpty) return null;

      // load() compiles when the asset carries no bytes, so this needs no second
      // compile pass.
      final editor = MaterialEditorViewModel(assetPath: materialAssetPath);
      await editor.load();
      final compiled = editor.compiledBytes;
      editor.dispose();
      if (compiled == null || compiled.isEmpty) {
        EngineLoggerService().log(
          'Could not compile "$materialAssetPath" for the slot preview; the section '
          'keeps the material the mesh shipped.',
          level: 'warning',
          source: 'SkeletalMeshEditor',
        );
        return null;
      }
      return compiled;
    } catch (e) {
      EngineLoggerService().log(
        'Slot material compile failed for "$materialAssetPath": $e',
        level: 'warning',
        source: 'SkeletalMeshEditor',
      );
      return null;
    }
  }

  /// Sampler parameter names the material bound to [slotIndex] declares.
  List<String> samplerNamesForSlot(int slotIndex) {
    if (slotIndex < 0 || slotIndex >= _materialSlots.length) return const [];
    return List.unmodifiable(_materialSlots[slotIndex].samplerNames);
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
      } catch (_) {}

      try {
        _glbMesh = await AssetRepository.loadMeshFromDisk(assetPath);
      } catch (_) {}

      // Extract geometry and bone statistics
      if (_glbMesh != null) {
        _triangleCount = _glbMesh!.triangleCount;
        _vertexCount = _glbMesh!.vertexCount;
        _boneCount = _glbMesh!.boneCount;

        _allBones = _glbMesh!.allNodes.where((n) => n.type == GlbNodeType.bone).toList();

        // If no explicit skin joints found, treat all non-mesh nodes as potential hierarchy
        if (_allBones.isEmpty && _glbMesh!.allNodes.isNotEmpty) {
          _allBones = _glbMesh!.allNodes.where((n) => n.type != GlbNodeType.mesh).toList();
        }

        // Build filtered root bones
        _rootBones = _glbMesh!.rootNodes.where((n) => _nodeOrChildrenContainBone(n)).toList();
        if (_rootBones.isEmpty && _allBones.isNotEmpty) {
          _rootBones = [_allBones.first];
        }

        // Initialize morph targets
        _morphWeights.clear();
        for (final target in _glbMesh!.morphTargets) {
          _morphWeights[target.name] = 0.0;
        }
      } else if (_asset?.metadata != null) {
        final meta = _asset!.metadata;
        _triangleCount = int.tryParse(meta['triangle_count'] ?? '0') ?? 0;
        _vertexCount = int.tryParse(meta['vertex_count'] ?? '0') ?? 0;
        _boneCount = int.tryParse(meta['bone_count'] ?? '0') ?? 0;

        if (meta.containsKey('bones')) {
          final boneNames = meta['bones']!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          _allBones = List.generate(boneNames.length, (i) => GlbNode(index: i, name: boneNames[i], type: GlbNodeType.bone));
          if (_allBones.isNotEmpty) {
            _rootBones = [_allBones.first];
            for (int i = 0; i < _allBones.length - 1; i++) {
              _allBones[i].children.add(_allBones[i + 1]);
            }
          }
        }
      }

      // Load Sockets
      if (_asset?.metadata.containsKey('sockets') == true) {
        try {
          final socketsRaw = jsonDecode(_asset!.metadata['sockets']!);
          if (socketsRaw is Map && socketsRaw.containsKey('sockets')) {
            final list = socketsRaw['sockets'] as List;
            _sockets = list.map((s) => SkeletalMeshSocket.fromJson(Map<String, dynamic>.from(s as Map))).toList();
          } else if (socketsRaw is List) {
            _sockets = socketsRaw.map((s) => SkeletalMeshSocket.fromJson(Map<String, dynamic>.from(s as Map))).toList();
          }
        } catch (e) {
          _sockets = [];
        }
      } else {
        _sockets = [];
      }

      // Load Retargeting Options
      if (_asset?.metadata.containsKey('bone_retargeting') == true) {
        try {
          final retargetMap = jsonDecode(_asset!.metadata['bone_retargeting']!) as Map;
          _boneRetargeting = Map<String, String>.from(retargetMap);
        } catch (_) {
          _boneRetargeting = {};
        }
      }

      // Load Morph Defaults
      if (_asset?.metadata.containsKey('morph_defaults') == true) {
        try {
          final morphMap = jsonDecode(_asset!.metadata['morph_defaults']!) as Map;
          for (final entry in morphMap.entries) {
            final w = (entry.value as num?)?.toDouble() ?? 0.0;
            _morphWeights[entry.key.toString()] = w;
          }
        } catch (_) {}
      }

      // Load Associated DNA Rig if recorded or auto-detected
      if (_asset?.metadata.containsKey('dna_path') == true) {
        final path = _asset!.metadata['dna_path']!;
        if (File(path).existsSync()) {
          await loadDnaFile(path);
        }
      }
      if (_rigLogicEvaluator == null) {
        // Auto-detect matching .dna file next to the asset
        final dnaSibling = File(assetPath.replaceAll('.lmas', '.dna'));
        if (dnaSibling.existsSync()) {
          await loadDnaFile(dnaSibling.path);
        } else if (file.parent.existsSync()) {
          for (final entity in file.parent.listSync()) {
            if (entity is File && entity.path.endsWith('.dna')) {
              await loadDnaFile(entity.path);
              break;
            }
          }
        }
      }

      _initializeMaterialSlots();
      _scanProjectMaterialsAndTextures();
      await refreshSlotSamplers();

      _isDirty = false;
      _isLoading = false;
      notifyListeners();
    } catch (e, st) {
      _hasError = true;
      _isLoading = false;
      EngineLoggerService().log('Failed to load skeletal mesh: $e\n$st', level: 'error');
      notifyListeners();
    }
  }

  /// Builds one slot per geometry section and merges any bindings already
  /// recorded on the asset. Sections come from the parsed sub-primitives —
  /// `materialNames` is a parallel display list and two sections may share a
  /// name, so it must never key the slots.
  void _initializeMaterialSlots() {
    var sectionCount = _glbMesh?.subPrimitives.length ?? 0;
    if (sectionCount == 0) sectionCount = _glbMesh?.materialNames.length ?? 0;
    if (sectionCount == 0) sectionCount = 1;

    final overrides = _loadTextureOverrides();

    _materialSlots = List.generate(sectionCount, (i) {
      final slotName = 'element_$i';
      final existing = _asset?.references.where((r) => r.slotName == slotName).firstOrNull;
      final slotOverrides = <String, MaterialTextureBinding>{};
      for (final entry in overrides.entries) {
        final prefix = '$slotName/';
        if (entry.key.startsWith(prefix)) {
          slotOverrides[entry.key.substring(prefix.length)] = entry.value;
        }
      }
      final subPrims = _glbMesh?.subPrimitives ?? const [];
      final names = _glbMesh?.materialNames ?? const [];
      final sourceName = i < subPrims.length
          ? subPrims[i].materialName
          : (i < names.length ? names[i] : null);

      return MaterialSlotBinding(
        index: i,
        slotName: slotName,
        assignedMaterialPath: existing?.assetPath,
        assignedMaterialId: existing?.assetId,
        sourceMaterialName: sourceName,
        textureBindings: slotOverrides,
      );
    });
  }

  Map<String, MaterialTextureBinding> _loadTextureOverrides() {
    final raw = _asset?.metadata['materialTextures'];
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(
          key,
          MaterialTextureBinding.fromJson(Map<String, dynamic>.from(value as Map)),
        ),
      );
    } catch (_) {
      return const {};
    }
  }

  /// Project root for this asset: the nearest ancestor that owns a `contents/`
  /// directory. Returns null when the asset lives outside a project.
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

  void _scanProjectMaterialsAndTextures() {
    final root = projectRoot;
    if (root == null) {
      _availableMaterials = const [];
      _availableTextures = const [];
      return;
    }
    final all = AssetRepository().scanProjectContents(root);
    _availableMaterials = all.where((a) => a.type == AssetType.filamat).toList();
    _availableTextures = all.where((a) => a.type == AssetType.texture).toList();
    _availablePreviewMeshes = all.where((a) => a.type == AssetType.filamesh || a.type == AssetType.filameshSk).toList();
  }

  /// Re-reads each bound material's `.lmas` and refreshes the sampler names its
  /// slot offers. Called on load and after a material binding changes.
  Future<void> refreshSlotSamplers() async {
    for (final slot in _materialSlots) {
      final path = slot.assignedMaterialPath;
      if (path == null) {
        slot.samplerNames = const [];
        slot.textureBindings.clear();
        continue;
      }
      slot.samplerNames = await _samplersOf(path);
      // Drop overrides for samplers the newly bound material does not declare.
      slot.textureBindings.removeWhere((name, _) => !slot.samplerNames.contains(name));
    }
    notifyListeners();
  }

  Future<List<String>> _samplersOf(String materialAssetPath) async {
    try {
      final file = File(materialAssetPath);
      if (!file.existsSync()) return const [];
      final asset = LuminaAsset.fromBytes(await file.readAsBytes());
      return MaterialSamplerParser.declaredSamplers(asset.rawMatSource);
    } catch (_) {
      return const [];
    }
  }

  void assignMaterial(
    int slotIndex, {
    required String materialAssetPath,
    required String materialAssetId,
  }) {
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
      ..assignedMaterialId = null
      ..samplerNames = const []
      ..textureBindings.clear();
    _isDirty = true;
    notifyListeners();
  }

  void assignTexture(
    int slotIndex,
    String parameterName, {
    required String textureAssetPath,
    required String textureAssetId,
  }) {
    if (slotIndex < 0 || slotIndex >= _materialSlots.length) return;
    _materialSlots[slotIndex].textureBindings[parameterName] =
        MaterialTextureBinding(assetId: textureAssetId, assetPath: textureAssetPath);
    _isDirty = true;
    notifyListeners();
  }

  void clearTexture(int slotIndex, String parameterName) {
    if (slotIndex < 0 || slotIndex >= _materialSlots.length) return;
    if (_materialSlots[slotIndex].textureBindings.remove(parameterName) == null) return;
    _isDirty = true;
    notifyListeners();
  }

  void highlightMaterial(int slotIndex, bool enabled) {
    if (slotIndex < 0 || slotIndex >= _materialSlots.length) return;
    _materialSlots[slotIndex].isHighlighted = enabled;
    notifyListeners();
  }

  void isolateMaterial(int slotIndex, bool enabled) {
    if (slotIndex < 0 || slotIndex >= _materialSlots.length) return;
    _materialSlots[slotIndex].isIsolated = enabled;
    notifyListeners();
  }

  bool _nodeOrChildrenContainBone(GlbNode node) {
    if (node.type == GlbNodeType.bone) return true;
    for (final child in node.children) {
      if (_nodeOrChildrenContainBone(child)) return true;
    }
    return false;
  }

  void setBoneSearchFilter(String filter) {
    _boneSearchFilter = filter.trim().toLowerCase();
    notifyListeners();
  }

  void selectBone(GlbNode? bone) {
    _selectedBone = bone;
    _selectedSocket = null;
    notifyListeners();
  }

  void selectSocket(SkeletalMeshSocket? socket) {
    _selectedSocket = socket;
    if (socket != null) {
      _selectedBone = _allBones.where((b) => b.name == socket.parentBone).firstOrNull;
    }
    notifyListeners();
  }

  void toggleShowBones() {
    _showBones = !_showBones;
    notifyListeners();
  }

  void toggleDisplaySockets() {
    _displaySockets = !_displaySockets;
    notifyListeners();
  }

  void toggleHeatmap() {
    _heatmapEnabled = !_heatmapEnabled;
    notifyListeners();
  }

  void setHeatmapEnabled(bool enabled) {
    if (_heatmapEnabled != enabled) {
      _heatmapEnabled = enabled;
      notifyListeners();
    }
  }

  void setInspectedVertex(int? vertIndex) {
    _inspectedVertex = vertIndex;
    notifyListeners();
  }

  void setMorphWeight(String name, double weight) {
    _morphWeights[name] = weight;
    _isDirty = true;
    notifyListeners();
  }

  void resetMorphs() {
    for (final key in _morphWeights.keys.toList()) {
      _morphWeights[key] = 0.0;
    }
    _isDirty = true;
    notifyListeners();
  }

  Future<bool> loadDnaFile(String path) async {
    try {
      final file = File(path);
      if (!file.existsSync()) return false;
      _rigLogicEvaluator?.dispose();
      _rigLogicEvaluator = RigLogicEvaluator.fromFile(path);
      _dnaPath = path;
      _rigLogicControlValues.clear();
      for (final name in _rigLogicEvaluator!.rawControlNames) {
        _rigLogicControlValues[name] = 0.0;
      }
      _evaluateRigLogic();
      _isDirty = true;
      notifyListeners();
      return true;
    } catch (e) {
      EngineLoggerService().log('Failed to load DNA from $path: $e', level: 'error');
      return false;
    }
  }

  Future<bool> loadDnaBytes(Uint8List bytes, {String? filename}) async {
    try {
      _rigLogicEvaluator?.dispose();
      _rigLogicEvaluator = RigLogicEvaluator.fromMemory(bytes);
      _dnaPath = filename ?? 'in_memory.dna';
      _rigLogicControlValues.clear();
      for (final name in _rigLogicEvaluator!.rawControlNames) {
        _rigLogicControlValues[name] = 0.0;
      }
      _evaluateRigLogic();
      _isDirty = true;
      notifyListeners();
      return true;
    } catch (e) {
      EngineLoggerService().log('Failed to load DNA from memory: $e', level: 'error');
      return false;
    }
  }

  void unloadDna() {
    if (_rigLogicEvaluator != null) {
      _rigLogicEvaluator!.dispose();
      _rigLogicEvaluator = null;
      _dnaPath = null;
      _rigLogicControlValues.clear();
      _jointDeltas.clear();
      _isDirty = true;
      notifyListeners();
    }
  }

  void setRigLogicControl(String name, double value) {
    if (_rigLogicEvaluator == null) return;
    _rigLogicControlValues[name] = value;
    _rigLogicEvaluator!.setControlByName(name, value);
    _evaluateRigLogic();
    _isDirty = true;
    notifyListeners();
  }

  void resetRigLogicControls() {
    if (_rigLogicEvaluator == null) return;
    for (final key in _rigLogicControlValues.keys.toList()) {
      _rigLogicControlValues[key] = 0.0;
    }
    _rigLogicEvaluator!.resetControls();
    _evaluateRigLogic();
    _isDirty = true;
    notifyListeners();
  }

  void _evaluateRigLogic() {
    if (_rigLogicEvaluator == null) return;
    final result = _rigLogicEvaluator!.evaluate();
    for (final entry in result.blendShapeWeights.entries) {
      _morphWeights[entry.key] = entry.value;
    }
    _jointDeltas.clear();
    final jointNames = _rigLogicEvaluator!.jointNames;
    final outputs = result.jointOutputs;
    final count = jointNames.length;
    for (int i = 0; i < count; i++) {
      final offset = i * 9;
      if (offset + 9 <= outputs.length) {
        final sub = outputs.sublist(offset, offset + 9);
        if (sub.any((v) => v.abs() > 1e-5)) {
          _jointDeltas[jointNames[i]] = sub;
        }
      }
    }
  }

  Float32List deformedPositions() {
    final basePositions = _glbMesh?.positions ?? const <double>[];
    final count = basePositions.length;
    if (_reusedDeformedPositions == null || _reusedDeformedPositions!.length != count) {
      _reusedDeformedPositions = Float32List(count);
    }
    final out = _reusedDeformedPositions!;
    for (int i = 0; i < count; i++) {
      out[i] = basePositions[i];
    }

    final targets = _glbMesh?.morphTargets ?? const [];
    for (final target in targets) {
      final weight = _morphWeights[target.name] ?? 0.0;
      if (weight != 0.0) {
        final deltas = target.positionDeltas;
        final len = deltas.length < count ? deltas.length : count;
        for (int i = 0; i < len; i++) {
          out[i] += deltas[i] * weight;
        }
      }
    }
    return out;
  }

  Uint8List? heatmapColors(int? boneNodeIndex) {
    if (!_heatmapEnabled || _glbMesh == null) return null;
    final vertCount = _glbMesh!.vertexCount;
    if (vertCount == 0) return null;

    final byteCount = vertCount * 3;
    if (_reusedHeatmapColors == null || _reusedHeatmapColors!.length != byteCount) {
      _reusedHeatmapColors = Uint8List(byteCount);
    }
    final out = _reusedHeatmapColors!;
    final joints = _glbMesh!.jointsPerVertex;
    final weights = _glbMesh!.weightsPerVertex;

    for (int v = 0; v < vertCount; v++) {
      double weight = 0.0;
      if (joints != null && weights != null && boneNodeIndex != null) {
        final base = v * 4;
        if (base + 3 < joints.length && base + 3 < weights.length) {
          for (int i = 0; i < 4; i++) {
            if (joints[base + i] == boneNodeIndex) {
              weight += weights[base + i];
            }
          }
        }
      }
      weight = weight.clamp(0.0, 1.0);

      // Blue (0, 0, 255) -> Cyan -> Green -> Yellow -> Red (255, 0, 0)
      int r, g, b;
      if (weight <= 0.25) {
        final t = weight / 0.25;
        r = 0;
        g = (255 * t).round();
        b = 255;
      } else if (weight <= 0.5) {
        final t = (weight - 0.25) / 0.25;
        r = 0;
        g = 255;
        b = (255 * (1.0 - t)).round();
      } else if (weight <= 0.75) {
        final t = (weight - 0.5) / 0.25;
        r = (255 * t).round();
        g = 255;
        b = 0;
      } else {
        final t = (weight - 0.75) / 0.25;
        r = 255;
        g = (255 * (1.0 - t)).round();
        b = 0;
      }

      final outIdx = v * 3;
      out[outIdx] = r;
      out[outIdx + 1] = g;
      out[outIdx + 2] = b;
    }

    return out;
  }

  Map<String, double> getVertexInfluences(int vertIndex) {
    final influences = <String, double>{};
    if (_glbMesh?.jointsPerVertex != null && _glbMesh?.weightsPerVertex != null) {
      final joints = _glbMesh!.jointsPerVertex!;
      final weights = _glbMesh!.weightsPerVertex!;
      final base = vertIndex * 4;
      if (base + 3 < joints.length && base + 3 < weights.length) {
        for (int i = 0; i < 4; i++) {
          final jIdx = joints[base + i];
          final w = weights[base + i];
          if (w > 0.0 || i == 0) {
            String boneName = 'Bone_$jIdx';
            if (_glbMesh!.allNodes.length > jIdx) {
              boneName = _glbMesh!.allNodes[jIdx].name;
            } else if (_allBones.length > jIdx) {
              boneName = _allBones[jIdx].name;
            }
            influences[boneName] = w;
          }
        }
      }
    }
    final sorted = influences.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }

  double getVertexWeightSum(int vertIndex) {
    if (_glbMesh?.weightsPerVertex != null) {
      final weights = _glbMesh!.weightsPerVertex!;
      final base = vertIndex * 4;
      if (base + 3 < weights.length) {
        return weights[base] + weights[base + 1] + weights[base + 2] + weights[base + 3];
      }
    }
    return 1.0;
  }

  String _generateUniqueSocketName(String baseName) {
    if (!_sockets.any((s) => s.name == baseName)) {
      return baseName;
    }
    int counter = 1;
    while (_sockets.any((s) => s.name == '${baseName}_$counter')) {
      counter++;
    }
    return '${baseName}_$counter';
  }

  bool addSocket({String? parentBone, String? name}) {
    final parent = parentBone ?? _selectedBone?.name ?? (_allBones.isNotEmpty ? _allBones.first.name : 'root');
    final baseName = name ?? '${parent}_socket';
    final uniqueName = _generateUniqueSocketName(baseName);

    final socket = SkeletalMeshSocket(
      name: uniqueName,
      parentBone: parent,
      relativeLocation: [0.0, 0.0, 0.0],
      relativeRotation: [0.0, 0.0, 0.0],
      relativeScale: [1.0, 1.0, 1.0],
    );

    _sockets.add(socket);
    _selectedSocket = socket;
    _isDirty = true;
    notifyListeners();
    return true;
  }

  bool renameSocket(String oldName, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == oldName) return false;
    if (_sockets.any((s) => s.name == trimmed && s.name != oldName)) {
      return false; // Name must be unique
    }

    final index = _sockets.indexWhere((s) => s.name == oldName);
    if (index >= 0) {
      _sockets[index].name = trimmed;
      if (_selectedSocket?.name == oldName) {
        _selectedSocket = _sockets[index];
      }
      _isDirty = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  bool reparentSocket(String socketName, String newParentBone) {
    final socket = _sockets.where((s) => s.name == socketName).firstOrNull;
    if (socket != null) {
      socket.parentBone = newParentBone;
      _isDirty = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  void setSocketTransform(
    String socketName, {
    List<double>? location,
    List<double>? rotation,
    List<double>? scale,
  }) {
    final socket = _sockets.where((s) => s.name == socketName).firstOrNull;
    if (socket != null) {
      if (location != null && location.length == 3) {
        socket.relativeLocation = List.from(location);
      }
      if (rotation != null && (rotation.length == 3 || rotation.length == 4)) {
        socket.relativeRotation = List.from(rotation);
      }
      if (scale != null && scale.length == 3) {
        socket.relativeScale = List.from(scale);
      }
      _isDirty = true;
      notifyListeners();
    }
  }

  void setSocketPreviewAsset(String socketName, String? assetPath) {
    final socket = _sockets.where((s) => s.name == socketName).firstOrNull;
    if (socket != null) {
      socket.previewAssetPath = assetPath;
      _isDirty = true;
      notifyListeners();
    }
  }

  bool removeSocket(String socketName) {
    final index = _sockets.indexWhere((s) => s.name == socketName);
    if (index >= 0) {
      _sockets.removeAt(index);
      if (_selectedSocket?.name == socketName) {
        _selectedSocket = null;
      }
      _isDirty = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  void setBoneRetargeting(String boneName, String option) {
    _boneRetargeting[boneName] = option;
    _isDirty = true;
    notifyListeners();
  }

  List<SkeletalMeshSocket> getSocketsForBone(String boneName) {
    return _sockets.where((s) => s.parentBone == boneName).toList();
  }

  Future<bool> save() async {
    final file = File(assetPath);
    final updatedMetadata = Map<String, String>.from(_asset?.metadata ?? {});

    updatedMetadata['last_modified'] = DateTime.now().toIso8601String();
    updatedMetadata['triangle_count'] = _triangleCount.toString();
    updatedMetadata['vertex_count'] = _vertexCount.toString();
    updatedMetadata['bone_count'] = _boneCount.toString();

    // Sockets serialization
    final socketsJson = {
      'v': 1,
      'sockets': _sockets.map((s) => s.toJson()).toList(),
    };
    updatedMetadata['sockets'] = jsonEncode(socketsJson);

    // Bone retargeting serialization
    if (_boneRetargeting.isNotEmpty) {
      updatedMetadata['bone_retargeting'] = jsonEncode(_boneRetargeting);
    } else {
      updatedMetadata.remove('bone_retargeting');
    }

    // Morph defaults serialization
    if (_morphWeights.isNotEmpty) {
      updatedMetadata['morph_defaults'] = jsonEncode(_morphWeights);
    } else {
      updatedMetadata.remove('morph_defaults');
    }

    // DNA Rig Path serialization
    if (_dnaPath != null) {
      updatedMetadata['dna_path'] = _dnaPath!;
    } else {
      updatedMetadata.remove('dna_path');
    }

    // Material slot bindings: one AssetReference per bound slot, replacing any
    // element_* references the asset already carried so a re-save cannot
    // accumulate duplicates. References for other slot namespaces pass through.
    final updatedRefs = <AssetReference>[
      ...?_asset?.references.where((r) => !r.slotName.startsWith('element_')),
    ];
    final textureOverrides = <String, dynamic>{};
    for (final slot in _materialSlots) {
      if (slot.assignedMaterialPath != null && slot.assignedMaterialId != null) {
        updatedRefs.add(AssetReference(
          assetId: slot.assignedMaterialId!,
          assetPath: slot.assignedMaterialPath!,
          slotName: slot.slotName,
        ));
      }
      for (final entry in slot.textureBindings.entries) {
        textureOverrides['${slot.slotName}/${entry.key}'] = entry.value.toJson();
      }
    }

    if (textureOverrides.isNotEmpty) {
      updatedMetadata['materialTextures'] = jsonEncode(textureOverrides);
    } else {
      updatedMetadata.remove('materialTextures');
    }

    final updatedAsset = LuminaAsset(
      assetId: _asset?.assetId ?? fileBasename,
      name: _asset?.name ?? fileBasename,
      type: AssetType.filamesh,
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
      EngineLoggerService().log('Saved SkeletalMesh asset to $assetPath', level: 'info');
      notifyListeners();
      return true;
    } catch (e, st) {
      EngineLoggerService().log('Failed to save SkeletalMesh asset: $e\n$st', level: 'error');
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _rigLogicEvaluator?.dispose();
    super.dispose();
  }
}
