part of '../anim_blueprint_editor_view_model.dart';

/// The Anim Preview Editor: owner/override inputs, the preview world and
/// stepping the previewed Anim Blueprint instance.
mixin _AnimBlueprintEditorPreview on _AnimBlueprintEditorViewModelState {

  // ---------------------------------------------------------------------------
  // Preview (Anim Preview Editor)
  // ---------------------------------------------------------------------------

  double get ownerSpeed => _ownerSpeed;
  double get ownerDirection => _ownerDirection;
  bool get ownerFalling => _ownerFalling;
  Map<String, Object?> get overrides => Map.unmodifiable(_overrides);
  String? get previewError => _previewError;
  String? get previewState => preview.animInstance?.currentState;
  String? get previewClip => preview.currentClip;

  /// The stand-in owner's ground speed (cm/s), walk direction (°, right
  /// positive) and falling state: what Get Velocity and Is Falling return.
  void setOwner({double? speed, double? direction, bool? falling}) {
    _ownerSpeed = speed ?? _ownerSpeed;
    _ownerDirection = direction ?? _ownerDirection;
    _ownerFalling = falling ?? _ownerFalling;
    notifyListeners();
  }

  /// Pins variable [name] to [value]: the update graph no longer writes it.
  void setOverride(String name, Object? value) {
    final v = _document.variables.where((x) => x.name == name).firstOrNull;
    if (v == null) return;
    _overrides[name] = luminaBlueprintLiteral(v.type ?? LuminaPinType.float, value);
    notifyListeners();
  }

  void clearOverride(String name) {
    if (_overrides.remove(name) != null) notifyListeners();
  }

  /// Shows the preview in the viewport's world (flutter_filament renders it).
  void attachPreviewWorld(LuminaWorld world) {
    preview.attach(world);
    _previewRevision = -1;
  }

  void detachPreviewWorld(LuminaWorld world) {
    if (identical(preview.world, world)) preview.detach();
  }

  /// A preview without a renderer (tests, or before the viewport is up).
  void startHeadlessPreview({bool ticker = true}) {
    preview.attachHeadless(startTicker: ticker);
    _previewRevision = -1;
  }

  /// The document the preview runs: overridden variables' Set nodes are
  /// spliced out of the update graph (so the graph no longer writes them),
  /// and the state machine resumes from [resumeState].
  LuminaAnimBlueprintDocument previewDocument(Set<String> overridden, {String? resumeState}) {
    final doc = LuminaAnimBlueprintDocument.fromJson(Map<String, dynamic>.from(jsonDecode(_snapshot()) as Map));
    final g = doc.eventGraph;
    for (final n in [...g.nodes]) {
      if (n.registryId != LuminaBlueprintNodeLibrary.variableSet || !overridden.contains(n.literals['variable'])) continue;
      final ins = g.wires.where((w) => w.toNodeId == n.id && w.toPinId == 'exec_in').toList();
      final out = g.wires.where((w) => w.fromNodeId == n.id && w.fromPinId == 'exec_out').firstOrNull;
      g.wires.removeWhere((w) => w.fromNodeId == n.id || w.toNodeId == n.id);
      if (out != null) {
        for (final w in ins) {
          g.wires.add(LuminaBlueprintWire(
              id: '${w.id}_spliced', fromNodeId: w.fromNodeId, fromPinId: w.fromPinId, toNodeId: out.toNodeId, toPinId: out.toPinId));
        }
      }
      g.nodes.remove(n);
    }
    final m = doc.stateMachine;
    if (m != null && resumeState != null && m.state(resumeState) != null) {
      doc.stateMachines[0] = LuminaAnimStateMachine(
        name: m.name,
        entryState: resumeState,
        states: m.states,
        transitions: m.transitions,
        sampleCrossFade: m.sampleCrossFade,
      );
    }
    return doc;
  }

  void _ensurePreviewInstance() {
    final mesh = preview.mesh;
    if (mesh == null) return;
    final keys = _overrides.keys.toSet();
    if (_previewRevision == _revision && setEquals(keys, _previewOverrideKeys)) return;
    _previewRevision = _revision;
    _previewOverrideKeys = keys;
    final current = preview.animInstance;
    final doc = previewDocument(keys, resumeState: current?.currentState);
    final cls = LuminaAnimBlueprintClass.fromDocument(doc,
        name: name, blendSpaces: stateBlendSpaces, poseDatabases: statePoseDatabases);
    if (cls.hasErrors) {
      _previewError = 'Preview paused: ${cls.diagnostics.firstWhere((d) => d.isError).message}';
      preview.setAnimInstance(null);
      notifyListeners();
      return;
    }
    _previewError = null;
    preview.setAnimInstance(cls.instantiate(mesh), carryVariables: Map.of(current?.variables ?? const {}));
  }

  @override
  void _beforePreviewTick(double dt) {
    _ensurePreviewInstance();
    final d = _ownerDirection * math.pi / 180.0;
    final authoring = Vector3(math.sin(d) * _ownerSpeed, math.cos(d) * _ownerSpeed, 0.0);
    preview.movement.standInVelocity.setFrom(LuminaBlueprintFunctionLibrary.toRuntime(authoring));
    preview.movement.standInFalling = _ownerFalling;
    final anim = preview.animInstance;
    if (anim == null) return;
    _overrides.forEach((k, v) => anim.variables[k] = v);
  }

  @override
  void _afterPreviewTick() {
    final state = previewState;
    final clip = previewClip;
    if (state != _lastPreviewState || clip != _lastPreviewClip) {
      _lastPreviewState = state;
      _lastPreviewClip = clip;
      notifyListeners();
    }
  }

  /// Advances the preview [frames] frames of 1/60 s (tests, Step).
  void stepPreview([int frames = 1]) {
    for (var i = 0; i < frames; i++) {
      preview.advance(AnimPreviewScene.tickSeconds);
    }
  }
}
