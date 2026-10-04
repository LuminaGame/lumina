import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:lumina/data/services/blueprint_function_manifest.dart';
import 'package:lumina/data/services/blueprint_codegen/blueprint_dart_generator.dart'
    show BlueprintAnimClassRef, BlueprintClassRef;
import 'package:lumina/lumina.dart';

import '../../main_editor/commands/editor_transaction.dart';
import '../models/blueprint_compile_status.dart';
import '../models/blueprint_editor_nodes.dart';
import '../models/blueprint_editor_type_context.dart';
import '../models/blueprint_graph_ref.dart';
import '../models/blueprint_palette.dart';
import '../models/blueprint_component_registry.dart';
import '../models/blueprint_pin_style.dart';
import '../services/blueprint_asset_catalog.dart';
import '../services/blueprint_preview_scene.dart';
import '../services/widget_class_catalog.dart';
import 'anim_blueprint_editor_view_model.dart' show AnimBlueprintEditorViewModel;
import 'blueprint_graph_editor.dart';

part 'blueprint_editor_view_model/state.dart';
part 'blueprint_editor_view_model/graph_and_variables.dart';
part 'blueprint_editor_view_model/components.dart';
part 'blueprint_editor_view_model/compile_and_disk_io.dart';
part 'blueprint_editor_view_model/graphs.dart';
part 'blueprint_editor_view_model/functions_and_macros.dart';
part 'blueprint_editor_view_model/collapse_expand.dart';

/// The Blueprint editor's state: lumina's
/// [LuminaBlueprintDocument] read from and written to the ACTOR `.lmas`, the
/// event graph edited through lumina's node library, the project's input
/// actions, and an honest compile status from lumina's validator and
/// `BlueprintDartGenerator`. Every document edit is one undo step.
class BlueprintEditorViewModel extends _BlueprintEditorViewModelState
    with
        _BlueprintEditorGraphAndVariables,
        _BlueprintEditorComponents,
        _BlueprintEditorCompileAndDiskIo,
        _BlueprintEditorGraphs,
        _BlueprintEditorFunctionsAndMacros,
        _BlueprintEditorCollapseExpand {
  /// [initialDocument] opens a document that does not live in an actor
  /// `.lmas` payload (a level's Blueprint, stored in
  /// the level) as the unedited baseline.
  BlueprintEditorViewModel({required super.assetPath, super.initialAsset, super.initialDocument});

  @override
  void _catalogChanged() {
    // Pin classes and the palette follow the widget classes on disk.
    notifyListeners();
    _graphsChanged();
  }

  @override
  void _rememberEnumValues() {
    _knownEnumValues = {for (final e in _assets?.enums ?? const <LuminaBlueprintEnumDocument>[]) e.name: List.of(e.values)};
  }

  /// An enum asset was saved: a reordered enum moves every `Switch on <enum>`
  /// case wire to follow its value by name.
  @override
  void _assetsChanged() {
    final assets = _assets;
    if (assets != null) {
      for (final e in assets.enums) {
        final old = _knownEnumValues[e.name];
        if (old != null && !listEquals(old, e.values)) {
          if (BlueprintAssetCatalog.remapDocumentSwitchWires(_document, e.name, old, e.values) > 0) _revision++;
        }
      }
      _rememberEnumValues();
    }
    notifyListeners();
    _graphsChanged();
  }

  @override
  void _graphsChanged() {
    eventGraph.documentChanged();
    for (final e in _graphEditors.values) {
      e.documentChanged();
    }
  }

  /// The project's widget classes as the type context sees them.
  WidgetClassCatalog? get widgetClassCatalog => _catalog;

  /// The project's enum / interface assets as the type context sees them.
  BlueprintAssetCatalog? get assetCatalog => _assets;

  /// The project's enum assets.
  List<LuminaBlueprintEnumDocument> get projectEnums => _assets?.enums ?? const [];

  /// The project's interface assets.
  List<LuminaBlueprintInterfaceDocument> get projectInterfaces => _assets?.interfaces ?? const [];

  @override
  String get fileBasename {
    final file = File(assetPath);
    return file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last.replaceAll('.lmas', '') : 'BP_Actor';
  }

  /// Whether this editor edits a level's Blueprint:
  /// an event graph with functions, macros, dispatchers and timelines, and
  /// no components, 3D viewport, construction script or class defaults.
  bool get isLevelBlueprint => false;

  /// Whether this editor edits a widget's own graph: the
  /// same configuration as a Level Blueprint, embedded in the UMG designer.
  bool get isWidgetBlueprint => false;

  /// What the toolbar and the close prompt call this Blueprint.
  String get displayName => fileBasename;

  /// The file the code preview names (`lib/actors/<blueprint>.dart`, snake_case).
  String get generatedFileName => dartFileName(fileBasename);

  /// Rows the right-click palette pins above everything else
  /// (`Create a Reference to <Actor>` for the actors
  /// selected in the outliner). None by default.
  @override
  List<BlueprintPaletteEntry> pinnedPaletteEntries() => const [];

  /// Makes [document] the editor's document as it is on disk (a load):
  /// undo history, graph tabs and compile results start over.
  @protected
  void adoptDocument(LuminaBlueprintDocument document) {
    _document = document;
    _selectedComponentId = null;
    _selectedVariable = null;
    _selectedFunction = null;
    _selectedMacro = null;
    _selectedDispatcher = null;
    for (final e in _graphEditors.values) {
      e.dispose();
    }
    _graphEditors.clear();
    _activeGraph = BlueprintGraphRef.eventGraph;
    _adoptWildcardTypes();
    _syncPreview();
    _onDiskJson = _document.toFormattedJson();
    transactions.clear();
    _compileStatus = BlueprintCompileStatus.unknown;
    _diagnostics = const [];
    _revision++;
    notifyListeners();
    _graphsChanged();
  }

  /// The document as it is now was written to disk.
  @protected
  void markSaved() {
    _onDiskJson = _document.toFormattedJson();
    notifyListeners();
  }

  /// A compile's findings: Compiler Results, the badge and the Output Log.
  @override
  @protected
  void applyCompileResult(List<LuminaBlueprintDiagnostic> issues) {
    _diagnostics = List.unmodifiable(issues);
    _compileStatus = issues.any((d) => d.isError)
        ? BlueprintCompileStatus.error
        : issues.isNotEmpty
            ? BlueprintCompileStatus.warning
            : BlueprintCompileStatus.upToDate;
    EngineLoggerService().log(
      'Compiled $displayName: ${_compileStatus.label} (${issues.where((d) => d.isError).length} errors, '
      '${issues.where((d) => !d.isError).length} warnings)',
      level: _compileStatus == BlueprintCompileStatus.error ? 'error' : 'success',
    );
    notifyListeners();
    _graphsChanged();
  }

  /// Re-reads what the project gives the graphs: its exposed functions,
  /// input actions, assets, widget classes, enums and interfaces.
  @protected
  void refreshProjectContext(String projectDir) {
    _declareProjectFunctions(projectDir);
    _inputActions = _readInputActions(projectDir);
    try {
      _scanProjectAssets(projectDir);
    } catch (e) {
      EngineLoggerService().log('Blueprint asset scan error: $e', level: 'warning');
    }
    _catalog?.refresh();
    _assets?.refresh();
    _rememberEnumValues();
  }

  /// Bumped on every document change (the code preview's cache key).
  @protected
  int get revision => _revision;

  /// Tells every graph the document changed outside an edit (a level actor
  /// renamed or deleted in the outliner): pins and banners resolve again.
  @protected
  void graphsChanged() {
    _revision++;
    notifyListeners();
    _graphsChanged();
  }

  @override
  LuminaBlueprintDocument get document => _document;
  String? get selectedComponentId => _selectedComponentId;
  bool get isDirty => _document.toFormattedJson() != _onDiskJson;

  /// The project's Enhanced Input actions (Project Settings), which input
  /// nodes pick from and the validator checks against.
  @override
  List<LuminaInputAction> get inputActions => _inputActions;

  @override
  LuminaBlueprintTypeContext get typeContext => _contextFor();

  /// The type context of the document, scoped to a [function] or [macro]
  /// graph when given; the project's enums and
  /// interfaces come from the asset catalog (lumina's registries otherwise).
  @override
  LuminaBlueprintTypeContext _contextFor({LuminaBlueprintFunctionGraph? function, LuminaBlueprintMacroGraph? macro}) =>
      buildTypeContext(function: function, macro: macro);

  /// The type context the graphs resolve in; a Level Blueprint
  /// resolves in lumina's level context instead.
  @protected
  LuminaBlueprintTypeContext buildTypeContext({LuminaBlueprintFunctionGraph? function, LuminaBlueprintMacroGraph? macro}) =>
      BlueprintEditorTypeContext.of(
        LuminaBlueprintTypeContext.forDocument(
          _document,
          inputActions: _inputActions,
          widgetClasses: _catalog?.widgetClasses ?? const [],
          className: fileBasename,
          actorParents: _catalog?.actorParents ?? const {},
          enums: _assets?.enums,
          interfaces: _assets?.interfaces,
          functionScope: function,
          macroScope: macro,
          inheritedVariables: inheritedVariables,
          inheritedComponents: inheritedComponents,
          customEventOwners: _catalog?.actorEvents ?? const {},
          variableOwners: _catalog?.actorVariables ?? const {},
          componentOwners: _catalog?.actorComponents ?? const {},
        ),
        implementedInterfaces: _document.interfaces,
      );

  /// Promote to Variable declares through here (inside one undo step); My
  /// Blueprint selects the new variable.
  @override
  void declareVariable(LuminaBlueprintVariable variable) {
    _document.variables.add(variable);
    _selectedVariable = variable.name;
  }

  /// Promote to Variable on [pin]: the
  /// variable appears in My Blueprint selected, its Set node wired.
  LuminaBlueprintNode? promoteToVariable(BlueprintPinRef pin, {Offset? position}) =>
      eventGraph.promoteToVariable(pin, position: position);

  BlueprintCompileStatus get compileStatus => _compileStatus;
  @override
  List<LuminaBlueprintDiagnostic> get diagnostics => _diagnostics;

  List<RealAssetInfo> get availableSkeletalMeshes => List.unmodifiable(_availableSkeletalMeshes);
  List<RealAssetInfo> get availableStaticMeshes => List.unmodifiable(_availableStaticMeshes);
  List<RealAssetInfo> get availableAnimations => List.unmodifiable(_availableAnimations);
  List<RealAssetInfo> get availableMaterials => List.unmodifiable(_availableMaterials);

  /// Animation Blueprints in the project that animate [meshPath] (the Anim
  /// Class picker of a Skeletal Mesh component lists only these).
  List<String> animBlueprintsFor(String? meshPath) => [
        for (final abp in _availableAnimBlueprints)
          if (meshPath != null && meshPath.isNotEmpty && abp.targetMesh == meshPath) abp.path,
      ];

  @override
  List<String> get availableWidgetClasses => List.unmodifiable(_availableWidgetClasses);

  /// Shows the preview in the 3D Viewport's world (flutter_filament renders it).
  void attachPreviewWorld(LuminaWorld world) => preview.attach(world);

  void detachPreviewWorld(LuminaWorld world) {
    if (identical(preview.world, world)) preview.detach();
  }

  /// A preview without a renderer (widget tests).
  void startHeadlessPreview() => preview.attachHeadless();

  /// Whether the blueprint has authored scene lights.
  bool get hasSceneLights => preview.hasSceneLights;

  /// Whether the preview is currently rendering with scene lights.
  bool get renderSceneLights => preview.renderSceneLights;

  /// Sets whether the preview is rendered using authored scene lights.
  void setRenderSceneLights(bool value) {
    preview.setRenderSceneLights(value);
    notifyListeners();
  }

  /// Toggles whether the preview is rendered using authored scene lights.
  void toggleRenderSceneLights() {
    preview.toggleRenderSceneLights();
    notifyListeners();
  }

  @override
  void _syncPreview() => preview.setDocument(_document, projectDir: _previewProjectDir, components: allComponents);

  @override
  void notifyListeners() {
    // Every selection change notifies: the viewport highlights the same one.
    preview.select(_selectedComponentId);
    super.notifyListeners();
  }

  @override
  void dispose() {
    _catalog?.dispose();
    _assets?.dispose();
    for (final e in _graphEditors.values) {
      e.dispose();
    }
    preview.dispose();
    super.dispose();
  }

  /// The document as the engine receives it: comments dropped and reroutes
  /// bypassed. Compile, the code preview and Play read
  /// this; the editor and the `.lmas` keep the annotated one.
  @override
  LuminaBlueprintDocument get engineDocument => BlueprintEditorNodes.forEngine(_document);

  /// What Compile would write to `lib/actors/`, regenerated per document
  /// revision (the live code preview).
  String get generatedDartCode {
    final cached = _codeCache;
    if (cached != null && cached.$1 == _revision) return cached.$2;
    final code = DartCodeGeneratorService().generateActorClassDart(
      fileBasename,
      engineDocument.toJson(),
      inputActions: _inputActions,
      typeContext: buildTypeContext(),
    );
    _codeCache = (_revision, code);
    return code;
  }

  // ---------------------------------------------------------------------------
  // Undo and document edits
  // ---------------------------------------------------------------------------

  String _snapshot() => jsonEncode(_document.toJson());

  @override
  void _restore(String json) {
    _document = LuminaBlueprintDocument.fromJson(Map<String, dynamic>.from(jsonDecode(json) as Map));
    // The Details transform fields rebuild with the restored values.
    _componentTransformRevision++;
    if (_selectedComponentId != null && getComponent(_selectedComponentId!) == null) _selectedComponentId = null;
    if (_selectedVariable != null && _document.variable(_selectedVariable!) == null) _selectedVariable = null;
    _pruneGraphState();
    _edited();
  }

  /// After an undo or a delete: a tab or editor whose graph is gone goes
  /// back to the event graph.
  @override
  void _pruneGraphState() {
    final gone = [for (final key in _graphEditors.keys) if (!_refExists(_refFromKey(key))) key];
    for (final key in gone) {
      _graphEditors.remove(key)?.dispose();
    }
    if (!_refExists(_activeGraph)) _activeGraph = BlueprintGraphRef.eventGraph;
    if (_selectedFunction != null && _document.function(_selectedFunction!) == null) _selectedFunction = null;
    if (_selectedMacro != null && _document.macro(_selectedMacro!) == null) _selectedMacro = null;
    if (_selectedDispatcher != null && _document.dispatcher(_selectedDispatcher!) == null) _selectedDispatcher = null;
  }

  void _edited({bool layoutOnly = false}) {
    _revision++;
    if (!layoutOnly) _compileStatus = BlueprintCompileStatus.dirty;
    _syncPreview();
    notifyListeners();
    _graphsChanged();
  }

  @override
  T mutate<T>(String label, T Function() mutation) {
    final before = _snapshot();
    final result = mutation();
    if (result == null || result == false) {
      _document = LuminaBlueprintDocument.fromJson(Map<String, dynamic>.from(jsonDecode(before) as Map));
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
      label: _interactionLabel ?? 'Edit',
      undo: () => _restore(before),
      redo: () => _restore(after),
    ));
    _edited(layoutOnly: layoutOnly);
  }

  @override
  void undo() => transactions.undo();
  @override
  void redo() => transactions.redo();

  // ---------------------------------------------------------------------------
  // Physics
  // ---------------------------------------------------------------------------

  /// Whether components of [type] have a Physics section:
  /// the collision shapes and static meshes.
  static bool isPhysicsCapable(String type) =>
      BlueprintComponentRegistry.isCollisionCapable(type) || type == 'LuminaStaticMeshComponent';

  static LuminaBlueprintDocument createDefaultDocument(String name, {String parentClass = 'LuminaCharacter'}) {
    if (parentClass == 'LuminaCharacter') {
      return LuminaBlueprintDocument(
        parentClass: 'LuminaCharacter',
        components: [
          LuminaBlueprintComponent(
            id: 'root_capsule',
            name: 'CapsuleComponent',
            type: 'LuminaCapsuleComponent',
            properties: {
              'location': [0.0, 0.0, 0.0],
              'rotation': [0.0, 0.0, 0.0],
              'scale': [1.0, 1.0, 1.0],
              'capsuleRadius': 35.0, // cm
              'capsuleHalfHeight': 90.0,
            },
          ),
          LuminaBlueprintComponent(
            id: 'arrow_comp',
            name: 'ArrowComponent',
            type: 'LuminaArrowComponent',
            parentId: 'root_capsule',
            properties: {
              'location': [0.0, 0.0, 0.0],
              'rotation': [0.0, 0.0, 0.0],
              'scale': [1.0, 1.0, 1.0],
              'arrowSize': 1.0,
              'arrowColor': '#0088ffff',
            },
          ),
          LuminaBlueprintComponent(
            id: 'spring_arm',
            name: 'CameraBoom',
            type: 'LuminaSpringArmComponent',
            parentId: 'root_capsule',
            properties: {
              'location': [0.0, 0.0, 0.0],
              'rotation': [0.0, 0.0, 0.0],
              'scale': [1.0, 1.0, 1.0],
              'targetArmLength': 400.0,
              'usePawnControlRotation': true,
              'inheritPitch': true,
              'inheritYaw': true,
              'inheritRoll': false,
            },
          ),
          LuminaBlueprintComponent(
            id: 'follow_cam',
            name: 'FollowCamera',
            type: 'LuminaCameraComponent',
            parentId: 'spring_arm',
            properties: {
              'location': [0.0, 0.0, 0.0],
              'rotation': [0.0, 0.0, 0.0],
              'scale': [1.0, 1.0, 1.0],
              'fieldOfView': 90.0,
              'usePawnControlRotation': false,
            },
          ),
          LuminaBlueprintComponent(
            id: 'skm_mesh',
            name: 'Mesh',
            type: 'LuminaSkeletalMeshComponent',
            parentId: 'root_capsule',
            properties: {
              'location': [0.0, 0.0, -90.0],
              'rotation': [0.0, 0.0, 0.0],
              'scale': [1.0, 1.0, 1.0],
              'skeletalMeshAsset': '',
              'animMode': 'Use Animation Asset',
              'castShadows': true,
              'receiveShadows': true,
            },
          ),
          LuminaBlueprintComponent(
            id: 'char_move',
            name: 'CharacterMovement',
            type: 'LuminaCharacterMovementComponent',
            properties: {
              'maxWalkSpeed': 600.0,
              'jumpZVelocity': 700.0,
              'gravityScale': 1.75,
              'airControl': 0.35,
            },
            isSceneComponent: false,
          ),
        ],
        classDefaults: {'initialHealth': 100.0},
      );
    } else if (parentClass == 'LuminaPawn') {
      return LuminaBlueprintDocument(
        parentClass: 'LuminaPawn',
        components: [
          LuminaBlueprintComponent(id: 'root_scene', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
          LuminaBlueprintComponent(
            id: 'sm_mesh',
            name: 'StaticMeshComponent',
            type: 'LuminaStaticMeshComponent',
            parentId: 'root_scene',
            properties: {'staticMeshAsset': ''},
          ),
          LuminaBlueprintComponent(
            id: 'follow_cam',
            name: 'CameraComponent',
            type: 'LuminaCameraComponent',
            parentId: 'root_scene',
            properties: {'fieldOfView': 90.0},
          ),
        ],
        classDefaults: {'initialHealth': 100.0},
      );
    }
    if (parentClass == gameModeParent) {
      // A GameMode Blueprint has no components; its
      // class defaults name the pawn and controller classes Play spawns.
      return LuminaBlueprintDocument(
        parentClass: gameModeParent,
        classDefaults: {'defaultPawnClass': '', 'playerControllerClass': ''},
      );
    }
    return LuminaBlueprintDocument(
      parentClass: parentClass == 'LuminaCharacter' || parentClass == 'LuminaPawn' ? 'LuminaActor' : parentClass,
      components: [
        LuminaBlueprintComponent(id: 'root_scene', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
      ],
      classDefaults: {'initialHealth': 100.0},
    );
  }

  static const String gameModeParent = 'LuminaGameMode';

  /// A function graph takes no event nodes (its entry is the event) and
  /// no latent nodes.
  static bool functionGraphAccepts(LuminaBlueprintNodeSpec spec) =>
      (spec.kind != LuminaBlueprintNodeKind.event || spec.id == LuminaBlueprintNodeLibrary.functionEntry) &&
      spec.kind != LuminaBlueprintNodeKind.latent &&
      spec.id != LuminaBlueprintNodeLibrary.macroInput &&
      spec.id != LuminaBlueprintNodeLibrary.macroOutput;

  /// A macro body takes no event nodes; its Inputs node is the entry.
  static bool macroGraphAccepts(LuminaBlueprintNodeSpec spec) =>
      (spec.kind != LuminaBlueprintNodeKind.event || spec.id == LuminaBlueprintNodeLibrary.macroInput) &&
      spec.id != LuminaBlueprintNodeLibrary.functionEntry &&
      spec.id != LuminaBlueprintNodeLibrary.functionResult &&
      spec.id != LuminaBlueprintNodeLibrary.localVariableGet &&
      spec.id != LuminaBlueprintNodeLibrary.localVariableSet;

  /// Which asset kind a string pin names, by the pin's id (and the node for
  /// `class` of Create Save Game Object); null for an ordinary string.
  static BlueprintAssetKind? assetKindOfPin(String registryId, String pinId) {
    switch (pinId) {
      case 'sound':
      case 'sound_asset':
      case 'sound_path':
        return BlueprintAssetKind.sound;
      case 'montage':
      case 'montage_asset':
        return BlueprintAssetKind.montage;
      case 'material':
      case 'material_asset':
        return BlueprintAssetKind.material;
      case 'particle':
      case 'particle_system':
      case 'emitter':
      case 'emitter_template':
      case 'template':
        return BlueprintAssetKind.particle;
      case 'level':
      case 'level_name':
        return BlueprintAssetKind.level;
      case 'save_game_class':
      case 'save_class':
        return BlueprintAssetKind.saveGame;
      case 'class':
        return registryId == 'create_save_game_object' ? BlueprintAssetKind.saveGame : null;
    }
    return null;
  }
}
