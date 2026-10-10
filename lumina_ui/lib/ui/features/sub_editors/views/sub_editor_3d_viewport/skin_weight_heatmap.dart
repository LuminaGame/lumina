part of '../sub_editor_3d_viewport.dart';

/// The Skin Weight Heatmap on the native mesh: while
/// [SubEditor3DViewport.showSkinWeightHeatmap] is on, every primitive of the
/// loaded mesh is drawn with [SkinWeightHeatmap.material], one instance per
/// renderable carrying the selected bone's index in that renderable's skin;
/// off, the primitives get back the material instances they had (and the
/// section overrides are applied again).
mixin _SubEditor3DViewportSkinWeightHeatmap on _SubEditor3DViewportStateBase {
  FilamentMaterial? _heatmapMaterial;
  final List<FilamentMaterialInstance> _heatmapInstances = [];

  /// The instance each (entity, primitive) had before the heatmap.
  final Map<(int, int), FilamentMaterialInstance> _heatmapSavedInstances = {};

  /// What is applied: null when the heatmap is off; else the bone's node
  /// index (-1 for none).
  int? _heatmapApplied;
  bool _heatmapCompiling = false;

  @override
  bool get _heatmapActive => _heatmapApplied != null;

  /// The renderable count the heatmap is drawn on (tests).
  int get heatmapRenderableCount => _heatmapApplied == null ? 0 : _heatmapInstances.length;

  @override
  void _applySkinWeightHeatmap({bool force = false}) {
    final engine = _nativeEngine;
    final asset = _nativeAsset;
    if (engine == null || asset == null) return;
    final wanted = widget.showSkinWeightHeatmap ? (widget.skinWeightHeatmapBone ?? -1) : null;
    if (!force && wanted == _heatmapApplied) return;
    if (wanted == null) {
      _restoreHeatmapMaterials();
      return;
    }
    final material = _heatmapMaterial;
    if (material == null) {
      if (_heatmapCompiling) return;
      _heatmapCompiling = true;
      SkinWeightHeatmap.material().then((bytes) {
        _heatmapCompiling = false;
        if (!mounted || bytes == null || _nativeEngine == null || _nativeEngine!.isDisposed) {
          if (bytes == null) debugPrint('[SubEditor3DViewport] heatmap material: ${SkinWeightHeatmap.lastDiagnostics}');
          return;
        }
        _heatmapMaterial ??= FilamentMaterial.fromBuffer(engine: _nativeEngine!, filamatBuffer: bytes);
        _applySkinWeightHeatmap(force: true);
        // Shader compilation for the new material: skip readbacks a moment.
        _skipReadPixelsFrames = math.max(_skipReadPixelsFrames, 15);
        _startWarmupTimer();
        setState(() {});
      });
      return;
    }
    try {
      final payload = widget.glbMesh?.rawPayload;
      final slots = payload == null ? const <int>[] : SkinWeightHeatmap.jointSlots(payload, wanted < 0 ? null : wanted);
      final rm = FilamentRenderableManager(engine);
      var i = 0;
      for (final entity in asset.renderableEntities) {
        if (!rm.hasComponent(entity)) continue;
        if (i >= _heatmapInstances.length) {
          _heatmapInstances.add(material.createInstance('LuminaSkinWeightHeatmap$i'));
        }
        final instance = _heatmapInstances[i];
        instance.setInt(SkinWeightHeatmap.jointParameter, i < slots.length ? slots[i] : -1);
        for (var primitive = 0; primitive < rm.getPrimitiveCount(entity); primitive++) {
          if (!_heatmapSavedInstances.containsKey((entity, primitive))) {
            final current = rm.getMaterialInstanceAt(entity, primitive);
            if (current != null) _heatmapSavedInstances[(entity, primitive)] = current;
          }
          rm.setMaterialInstanceAt(entity, primitive, instance);
        }
        i++;
      }
      _heatmapApplied = wanted;
    } catch (e) {
      debugPrint('[SubEditor3DViewport] skin weight heatmap failed: $e');
    }
  }

  void _restoreHeatmapMaterials() {
    final engine = _nativeEngine;
    if (_heatmapApplied == null || engine == null) return;
    _heatmapApplied = null;
    try {
      final rm = FilamentRenderableManager(engine);
      for (final MapEntry(key: (entity, primitive), value: instance) in _heatmapSavedInstances.entries) {
        if (rm.hasComponent(entity)) rm.setMaterialInstanceAt(entity, primitive, instance);
      }
    } catch (e) {
      debugPrint('[SubEditor3DViewport] restoring materials after the heatmap failed: $e');
    }
    _heatmapSavedInstances.clear();
    _applySectionMaterials(force: true);
    _applyPreviewMaterialToSections();
  }

  /// Forgets the mesh the heatmap was on (it was released) and releases
  /// the heatmap's instances; [material] too when the engine goes.
  @override
  void _releaseSkinWeightHeatmap({bool material = false}) {
    _heatmapSavedInstances.clear();
    _heatmapApplied = null;
    for (final instance in _heatmapInstances) {
      instance.dispose();
    }
    _heatmapInstances.clear();
    if (material) {
      _heatmapMaterial?.dispose();
      _heatmapMaterial = null;
    }
  }
}
