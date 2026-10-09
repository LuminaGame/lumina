part of '../skeletal_mesh_editor_view_model.dart';

/// Material slots: bindings, sampler overrides and the compiled preview materials.
mixin _SkeletalMeshMaterialSlots on _SkeletalMeshEditorViewModelState {
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
}
