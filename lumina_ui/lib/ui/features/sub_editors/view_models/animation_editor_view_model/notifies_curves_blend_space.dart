part of '../animation_editor_view_model.dart';

/// AnimNotify and AnimCurve CRUD, BlendSpace samples/parameters and
/// root motion.
mixin _AnimationEditorNotifiesCurvesBlendSpace on _AnimationEditorViewModelState {

  // --- AnimNotify CRUD ---
  void addNotify(String name, double time, {AnimNotifyType type = AnimNotifyType.custom, bool isSyncMarker = false}) {
    final clampedTime = duration > 0 ? time.clamp(0.0, duration) : time;
    final notify = EditorAnimNotify(
      id: 'notify_${DateTime.now().microsecondsSinceEpoch}_${_notifies.length}',
      name: name,
      time: clampedTime,
      type: type,
      isSyncMarker: isSyncMarker,
    );
    _notifies.add(notify);
    _notifies.sort((a, b) => a.time.compareTo(b.time));
    _isDirty = true;
    notifyListeners();
  }

  void moveNotify(String id, double newTime) {
    final index = _notifies.indexWhere((n) => n.id == id);
    if (index >= 0) {
      final clampedTime = duration > 0 ? newTime.clamp(0.0, duration) : newTime;
      _notifies[index].time = clampedTime;
      _notifies.sort((a, b) => a.time.compareTo(b.time));
      _isDirty = true;
      notifyListeners();
    }
  }

  void renameNotify(String id, String newName) {
    final index = _notifies.indexWhere((n) => n.id == id);
    if (index >= 0) {
      _notifies[index].name = newName;
      _isDirty = true;
      notifyListeners();
    }
  }

  void removeNotify(String id) {
    _notifies.removeWhere((n) => n.id == id);
    _isDirty = true;
    notifyListeners();
  }

  // --- AnimCurves CRUD ---
  @override
  void addCurve(String name) {
    if (_curves.any((c) => c.name == name)) return;
    _curves.add(AnimCurveData(name: name, keys: []));
    _isDirty = true;
    notifyListeners();
  }

  void removeCurve(String name) {
    _curves.removeWhere((c) => c.name == name);
    _isDirty = true;
    notifyListeners();
  }

  @override
  void addCurveKey(String curveName, double time, double value) {
    final curve = _curves.where((c) => c.name == curveName).firstOrNull;
    if (curve != null) {
      curve.keys.add(AnimCurveKey(time: time, value: value));
      curve.sortKeys();
      _isDirty = true;
      notifyListeners();
    }
  }

  void removeCurveKey(String curveName, int keyIndex) {
    final curve = _curves.where((c) => c.name == curveName).firstOrNull;
    if (curve != null && keyIndex >= 0 && keyIndex < curve.keys.length) {
      curve.keys.removeAt(keyIndex);
      _isDirty = true;
      notifyListeners();
    }
  }

  void deleteCurveKey(String curveName, double timeSeconds, {double tolerance = 1e-4}) {
    final curve = _curves.where((c) => c.name == curveName).firstOrNull;
    if (curve != null) {
      curve.keys.removeWhere((k) => (k.time - timeSeconds).abs() < tolerance);
      _isDirty = true;
      notifyListeners();
    }
  }

  double evaluateCurve(String curveName) {
    final curve = _curves.where((c) => c.name == curveName).firstOrNull;
    if (curve == null) return 0.0;
    return curve.evaluate(_positionSeconds);
  }

  // --- BlendSpace CRUD ---
  void setBlendSpace2D(bool is2D) {
    _blendSpace.is2D = is2D;
    _isDirty = true;
    notifyListeners();
  }

  void setBlendParam(double x, double y) {
    _blendParamX = x;
    _blendParamY = y;
    final dominant = dominantSample;
    if (dominant != null && _clips.isNotEmpty) {
      final clipIdx = _clips.indexWhere((c) => c.name == dominant.assetName);
      if (clipIdx >= 0 && clipIdx != _selectedClip) {
        selectClip(clipIdx);
      }
    }
    notifyListeners();
  }

  void addBlendSample(String assetPath, String assetName, double x, double y) {
    final sample = EditorBlendSample(
      id: 'sample_${DateTime.now().microsecondsSinceEpoch}_${_blendSpace.samples.length}',
      assetPath: assetPath,
      assetName: assetName,
      x: x,
      y: y,
    );
    _blendSpace.samples.add(sample);
    _isDirty = true;
    notifyListeners();
  }

  void moveBlendSample(String id, double x, double y) {
    final s = _blendSpace.samples.where((s) => s.id == id).firstOrNull;
    if (s != null) {
      s.x = x;
      s.y = y;
      _isDirty = true;
      notifyListeners();
    }
  }

  void removeBlendSample(String id) {
    _blendSpace.samples.removeWhere((s) => s.id == id);
    _isDirty = true;
    notifyListeners();
  }

  /// "Extract to Blend Space asset": writes this
  /// animation's metadata blend space as a BLEND_SPACE `.lmas` (lumina's
  /// blend space document) for the preview mesh, which Animation
  /// Blueprints can play. Nothing is converted automatically; the animation
  /// keeps its own copy. Returns the new asset's project-relative path.
  String? extractBlendSpaceAsset() {
    final projectDir = AnimationEditorViewModel._findProjectDir(assetPath);
    if (projectDir == null || _blendSpace.samples.isEmpty) return null;
    final bs = _blendSpace;
    final document = LuminaBlendSpaceDocument(
      axes: [
        LuminaBlendSpaceAxis(bs.xAxis.name, bs.xAxis.min, bs.xAxis.max),
        if (bs.is2D) LuminaBlendSpaceAxis(bs.yAxis.name, bs.yAxis.min, bs.yAxis.max),
      ],
      samples: [for (final s in bs.samples) LuminaBlendSpaceSample(s.assetName, s.x, bs.is2D ? s.y : 0.0)],
    );
    final name = File(assetPath).uri.pathSegments.last.replaceAll('.lmas', '');
    final path = AnimGraphAssetService.createBlendSpace(projectDir,
        name: 'BS_$name', meshRelPath: _previewMeshPath ?? '', document: document);
    EngineLoggerService().log('Extracted the blend space of $name to $path', level: 'success', source: 'AnimationEditor');
    return path;
  }

  // --- Root Motion ---
  void toggleRootMotion() {
    _enableRootMotion = !_enableRootMotion;
    _isDirty = true;
    notifyListeners();
  }

  void setRootMotion(bool enable) {
    _enableRootMotion = enable;
    _isDirty = true;
    notifyListeners();
  }
}
