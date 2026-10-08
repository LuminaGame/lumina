import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import 'package:lumina_ui/ui/features/main_editor/commands/editor_transaction.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_compile_status.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_pin_style.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/anim_blueprint_retarget_worker.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/anim_graph_asset_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/anim_preview_scene.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_graph_editor.dart';

part 'anim_blueprint_editor_view_model/state.dart';
part 'anim_blueprint_editor_view_model/load_save_and_retarget.dart';
part 'anim_blueprint_editor_view_model/state_machine.dart';
part 'anim_blueprint_editor_view_model/variables_and_compile.dart';
part 'anim_blueprint_editor_view_model/preview.dart';

/// Which graph of an Animation Blueprint the editor shows.
enum AnimGraphView { animGraph, stateMachine, state, transition, eventGraph }

/// A place in the Animation Blueprint's graph hierarchy: the AnimGraph, a
/// state machine, a state's pose, a transition's rule, or the EventGraph.
@immutable
class AnimGraphLocation {
  final AnimGraphView view;
  final String? machine;
  final String? state;
  final String? transition;

  const AnimGraphLocation._(this.view, {this.machine, this.state, this.transition});
  const AnimGraphLocation.animGraph() : this._(AnimGraphView.animGraph);
  const AnimGraphLocation.eventGraph() : this._(AnimGraphView.eventGraph);
  const AnimGraphLocation.stateMachine(String machine) : this._(AnimGraphView.stateMachine, machine: machine);
  const AnimGraphLocation.state(String machine, String state) : this._(AnimGraphView.state, machine: machine, state: state);
  const AnimGraphLocation.transition(String machine, String transition)
      : this._(AnimGraphView.transition, machine: machine, transition: transition);

  @override
  bool operator ==(Object other) =>
      other is AnimGraphLocation &&
      other.view == view &&
      other.machine == machine &&
      other.state == state &&
      other.transition == transition;

  @override
  int get hashCode => Object.hash(view, machine, state, transition);
}

/// One Compiler Results row, with the graph its node lives in.
class AnimCompileRow {
  final LuminaBlueprintDiagnostic diagnostic;
  final AnimGraphLocation? location;
  final String? nodeTitle;
  const AnimCompileRow(this.diagnostic, this.location, this.nodeTitle);
}

/// The Animation Blueprint editor's state: lumina's
/// [LuminaAnimBlueprintDocument] from the ANIM_BLUEPRINT
/// `.lmas`, its AnimGraph / state machine / transition rules / update event
/// graph, compile through lumina's validator and generator, and a live
/// preview of the Blueprint on its target mesh. Every edit is one undo step.
class AnimBlueprintEditorViewModel extends _AnimBlueprintEditorViewModelState
    with
        _AnimBlueprintEditorLoadSaveAndRetarget,
        _AnimBlueprintEditorStateMachine,
        _AnimBlueprintEditorVariablesAndCompile,
        _AnimBlueprintEditorPreview {
  AnimBlueprintEditorViewModel({required super.assetPath});

  static bool _eventGraphAccepts(LuminaBlueprintNodeSpec spec) {
    if (spec.id == LuminaBlueprintNodeLibrary.transitionResult) return false;
    if (spec.kind == LuminaBlueprintNodeKind.latent) return false;
    if (spec.kind == LuminaBlueprintNodeKind.event) return spec.id == LuminaBlueprintNodeLibrary.updateAnimation;
    return true;
  }

  /// A transition rule takes pure nodes and its Result only.
  static bool ruleAccepts(LuminaBlueprintNodeSpec spec) => spec.kind == LuminaBlueprintNodeKind.pure;

  @override
  String get name => AnimGraphAssetService.baseName(assetPath);
  @override
  String get relativePath {
    final dir = projectDir;
    final abs = File(assetPath).absolute.path;
    return dir != null && abs.startsWith('$dir/') ? abs.substring(dir.length + 1) : assetPath;
  }

  @override
  LuminaAnimBlueprintDocument get document => _document;
  bool get isDirty => _json(_document) != _onDiskJson;
  int get revision => _revision;
  @override
  String get targetMesh => _document.targetMesh;
  @override
  List<String> get clips => _clips;
  List<String> get blendSpacePaths => _blendSpacePaths;

  /// [clips] as assets for the shared asset picker: the
  /// project's animation asset of that name (with its thumbnail) where one
  /// exists, otherwise the clip inside the target mesh (`<mesh>#<clip>`).
  List<RealAssetInfo> get clipAssets {
    final scanned = {
      for (final a in _projectAssets())
        if (a.type == AssetType.animation) AnimGraphAssetService.baseName(a.relativePath): a,
    };
    return [
      for (final c in _clips)
        scanned[c] ??
            RealAssetInfo(
              fileName: c,
              relativePath: '${_document.targetMesh}#$c',
              type: AssetType.animation,
              bytes: 0,
            ),
    ];
  }

  /// Pose search databases made for the target mesh.
  List<String> get poseDatabasePaths => _poseDatabasePaths;

  /// [poseDatabasePaths] as assets for the shared asset picker.
  List<RealAssetInfo> get poseDatabaseAssets {
    final wanted = _poseDatabasePaths.toSet();
    return [for (final a in _projectAssets()) if (wanted.contains(a.relativePath)) a];
  }

  /// [blendSpacePaths] as assets for the shared asset picker.
  List<RealAssetInfo> get blendSpaceAssets {
    final wanted = _blendSpacePaths.toSet();
    return [for (final a in _projectAssets()) if (wanted.contains(a.relativePath)) a];
  }

  /// The project's scanned assets, rescanned when the target mesh changes.
  List<RealAssetInfo> _projectAssets() {
    final dir = projectDir;
    if (dir == null) return const [];
    if (_projectAssetsCache == null || _projectAssetsRevision != _targetMeshRevision) {
      _projectAssetsCache = AssetRepository().scanProjectContents(dir);
      _projectAssetsRevision = _targetMeshRevision;
    }
    return _projectAssetsCache!;
  }
  @override
  LuminaAnimStateMachine? get machine => _document.stateMachine;
  @override
  AnimGraphLocation get location => _location;
  String? get selectedState => _selectedState;
  String? get selectedTransition => _selectedTransition;
  String? get selectedVariable => _selectedVariable;
  BlueprintCompileStatus get compileStatus => _compileStatus;
  List<AnimCompileRow> get compileRows => _rows;
  String get generatedCode => _generatedCode;

  /// Available skeletal meshes in the project for target mesh selection.
  ///
  /// The project scan behind it is made once and kept until the next [load]
  /// or retarget: the Details panel reads this on every build, and a scan per
  /// build (a walk of every `.lmas` plus an asset index write) froze the
  /// editor while thumbnails or the preview were updating.
  List<RealAssetInfo> get availableSkeletalMeshes {
    final dir = projectDir;
    if (dir == null) return const [];
    final list = _skeletalMeshCache ??= AnimGraphAssetService.skeletalMeshes(dir);
    if (_document.targetMesh.isNotEmpty && !list.any((m) => m.relativePath == _document.targetMesh)) {
      final name = _document.targetMesh.split('/').last;
      return [
        RealAssetInfo(
          fileName: name,
          relativePath: _document.targetMesh,
          type: AssetType.filameshSk,
          bytes: 0,
        ),
        ...list,
      ];
    }
    return list;
  }

  @override
  LuminaBlueprintTypeContext get typeContext => LuminaBlueprintTypeContext(variables: _document.variables);

  @override
  List<String> get availableWidgetClasses => const [];

  @override
  void declareVariable(LuminaBlueprintVariable variable) => _document.variables.add(variable);

  static String _json(LuminaAnimBlueprintDocument doc) => const JsonEncoder.withIndent('  ').convert(doc.toJson());

  // ---------------------------------------------------------------------------
  // Undo
  // ---------------------------------------------------------------------------

  @override
  String _snapshot() => jsonEncode(_document.toJson());

  void _restore(String json) {
    final prevTarget = _document.targetMesh;
    _document = LuminaAnimBlueprintDocument.fromJson(Map<String, dynamic>.from(jsonDecode(json) as Map));
    final m = machine;
    if (_selectedState != null && m?.state(_selectedState!) == null) _selectedState = null;
    if (_selectedTransition != null && transition(_selectedTransition!) == null) _selectedTransition = null;
    if (_location.state != null && m?.state(_location.state!) == null) _location = AnimGraphLocation.stateMachine(m?.name ?? '');
    if (_location.transition != null && transition(_location.transition!) == null) {
      _location = AnimGraphLocation.stateMachine(m?.name ?? '');
    }
    if (_document.targetMesh != prevTarget) {
      _syncTargetMesh();
    }
    _edited();
  }

  void _edited({bool layoutOnly = false}) {
    _revision++;
    if (!layoutOnly) _compileStatus = BlueprintCompileStatus.dirty;
    notifyListeners();
    eventGraph.documentChanged();
    for (final e in _ruleEditors.values) {
      e.documentChanged();
    }
  }

  @override
  T mutate<T>(String label, T Function() mutation) {
    final before = _snapshot();
    final result = mutation();
    if (result == null || result == false) {
      _document = LuminaAnimBlueprintDocument.fromJson(Map<String, dynamic>.from(jsonDecode(before) as Map));
      return result;
    }
    final after = _snapshot();
    if (after == before) return result;
    transactions.record(EditorTransaction(label: label, undo: () => _restore(before), redo: () => _restore(after)));
    _edited();
    return result;
  }

  @override
  void beginInteraction(String label) {
    _interactionBefore ??= _snapshot();
    _interactionLabel = label;
  }

  @override
  void endInteraction({bool layoutOnly = false}) {
    final before = _interactionBefore;
    _interactionBefore = null;
    if (before == null) return;
    final after = _snapshot();
    if (after == before) return;
    transactions.record(EditorTransaction(
        label: _interactionLabel ?? 'Edit', undo: () => _restore(before), redo: () => _restore(after)));
    _edited(layoutOnly: layoutOnly);
  }

  void undo() => transactions.undo();
  void redo() => transactions.redo();

  // ---------------------------------------------------------------------------
  // State machine
  // ---------------------------------------------------------------------------

  static final RegExp _identifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_ ]*$');

  // ---------------------------------------------------------------------------
  // Compile
  // ---------------------------------------------------------------------------

  /// The Dart class the Blueprint [rawName] compiles into ([dartTypeName]:
  /// `ABP_Character` → `AbpCharacter`).
  static String className(String rawName) => dartTypeName(rawName);

  @override
  void dispose() {
    preview.detach();
    for (final e in _ruleEditors.values) {
      e.dispose();
    }
    eventGraph.dispose();
    super.dispose();
  }
}
