import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumina/data/services/blueprint_codegen/blueprint_dart_generator.dart';
import 'package:lumina/lumina.dart';

import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_editor_nodes.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_editor_type_context.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_graph_ref.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_palette.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';

/// The Level Blueprint editor's state: the Blueprint editor configured for a level. Its document
/// is the level's [LuminaLevelBlueprintDocument], read from and saved into
/// the level `.lmas` (`metadata.levelBlueprint`) through
/// [LuminaLevelRepository]; its graphs resolve in lumina's level context, so
/// `Get <Actor>` is typed by the placed actor's class and the palette lists
/// the level's actors under **Level Actors**; the actors selected in the
/// outliner are offered as `Create a Reference to <Actor>`. It has no
/// components, 3D viewport, construction script or class defaults.
class LevelBlueprintEditorViewModel extends BlueprintEditorViewModel {
  /// The project the level belongs to.
  final String projectDirectory;

  /// The project-relative level (`contents/levels/L_DefaultLevel.lmas`).
  final String levelPath;

  /// The level's placed actors as the outliner has them now; the level's
  /// saved actors when null.
  final List<LuminaBlueprintLevelActorRef> Function()? levelActorsSource;

  /// The names of the actors selected in the outliner.
  final List<String> Function()? selectedActorNames;

  /// Called after [save] wrote the Blueprint into the level.
  final void Function(LuminaLevelBlueprintDocument saved)? onSaved;

  LevelBlueprintEditorViewModel({
    required this.projectDirectory,
    required this.levelPath,
    this.levelActorsSource,
    this.selectedActorNames,
    this.onSaved,
    LuminaLevelBlueprintDocument? initial,
  }) : super(
          assetPath: '$projectDirectory/$levelPath',
          initialDocument: (initial ?? LuminaLevelRepository(projectDirectory).loadLevelBlueprint(levelPath)).blueprint,
        );

  /// The level's name (`L_DefaultLevel`).
  String get levelName => levelPath.split('/').last.replaceAll('.lmas', '');

  /// The generated level script class (`_LDefaultLevelScript`).
  String get scriptClassName => '_${dartTypeName(levelName)}Script';

  @override
  bool get isLevelBlueprint => true;

  @override
  String get displayName => levelName;

  @override
  String get fileBasename => levelName;

  @override
  String get generatedFileName => 'levels/${dartFileName(levelName)}';

  @override
  String? get projectDir => projectDirectory;

  /// A Level Blueprint has no construction script.
  @override
  List<BlueprintGraphRef> get graphs => [
        for (final g in super.graphs)
          if (g.kind != BlueprintGraphKind.constructionScript) g,
      ];

  /// The document as lumina stores it in the level.
  LuminaLevelBlueprintDocument get levelDocument => LuminaLevelBlueprintDocument(levelPath: levelPath, blueprint: document);

  // ---------------------------------------------------------------------------
  // Level actors
  // ---------------------------------------------------------------------------

  List<LuminaBlueprintLevelActorRef>? _savedActors;

  /// The level's placed actors a reference can name, in level order.
  List<LuminaBlueprintLevelActorRef> get levelActors {
    final source = levelActorsSource;
    if (source != null) return source();
    return _savedActors ??= LuminaLevelRepository(projectDirectory).load(levelPath)?.levelActorRefs ?? const [];
  }

  String _actorsSignature = '';

  /// The outliner's actors changed (added, renamed, deleted, reclassed):
  /// references re-type and banners follow, once per real change.
  void levelActorsChanged() {
    final signature = _signatureOf(levelActors);
    if (signature == _actorsSignature) return;
    _actorsSignature = signature;
    _refreshOwners();
    graphsChanged();
  }

  static String _signatureOf(List<LuminaBlueprintLevelActorRef> refs) => [for (final r in refs) '${r.name}\u0000${r.actorClass}'].join('\u0001');

  /// Renames every reference to placed actor [oldName] (`Get Door_01` →
  /// `FrontDoor`), keeping its wires: the outliner renamed the actor. Not an
  /// undo step — the reference follows the actor — and a
  /// document that was saved stays saved (the level's copy is renamed too).
  int renameLevelActor(String oldName, String newName) {
    if (oldName == newName) return 0;
    final wasSaved = !isDirty;
    final count = renameActorReferences(document, oldName, newName);
    if (count > 0 && wasSaved) markSaved();
    levelActorsChanged();
    if (count > 0) graphsChanged();
    return count;
  }

  /// Renames the `Get <Actor>` nodes of [doc] naming [oldName] to [newName];
  /// returns how many changed.
  static int renameActorReferences(LuminaBlueprintDocument doc, String oldName, String newName) {
    var count = 0;
    for (final g in [doc.eventGraph, for (final f in doc.functions) f.graph, for (final m in doc.macros) m.graph]) {
      for (final n in g.nodes) {
        if (n.registryId == LuminaBlueprintNodeLibrary.getLevelActor && n.literals['actor'] == oldName) {
          n.literals['actor'] = newName;
          n.title = newName;
          count++;
        }
      }
    }
    return count;
  }

  // ---------------------------------------------------------------------------
  // Placed Blueprint actors' classes
  // ---------------------------------------------------------------------------

  Map<String, String> _ownerParents = const {};
  Map<String, List<LuminaBlueprintCustomEvent>> _ownerEvents = const {};
  bool _ownersRead = false;

  /// Reads the Blueprint classes the level's placed actors are: their parent
  /// (for `Cast To` and assignability) and custom events (a targeted
  /// `Call <Event>` on `Get <Actor>`).
  void _refreshOwners() {
    _ownersRead = true;
    final parents = <String, String>{};
    final events = <String, List<LuminaBlueprintCustomEvent>>{};
    final names = <String>{
      for (final a in levelActors)
        if (a.actorClass.startsWith('${LuminaBlueprintObjectClass.actorKind}:')) LuminaBlueprintObjectClass.name(a.actorClass),
    };
    for (final name in names) {
      final file = _blueprintFileOf(name);
      if (file == null) continue;
      try {
        final payload = LuminaAsset.fromBytes(file.readAsBytesSync()).rawPayload;
        if (payload == null || payload.isEmpty) continue;
        final doc = LuminaBlueprintDocument.fromJson(Map<String, dynamic>.from(jsonDecode(utf8.decode(payload)) as Map));
        parents[name] = doc.parentClass;
        events[name] = LuminaBlueprintNodeLibrary.customEventsOf(doc.eventGraph);
      } catch (_) {
        continue;
      }
    }
    _ownerParents = parents;
    _ownerEvents = events;
  }

  /// `contents/blueprints/<name>.lmas`, else the first `<name>.lmas` under
  /// `contents/`; null for an engine class.
  File? _blueprintFileOf(String name) {
    final direct = File('$projectDirectory/contents/blueprints/$name.lmas');
    if (direct.existsSync()) return direct;
    final contents = Directory('$projectDirectory/contents');
    if (!contents.existsSync()) return null;
    for (final f in contents.listSync(recursive: true, followLinks: false)) {
      if (f is File && f.path.replaceAll(r'\', '/').endsWith('/$name.lmas') && !f.path.replaceAll(r'\', '/').contains('/levels/')) return f;
    }
    return null;
  }

  Map<String, String> get _actorParents => {...?widgetClassCatalog?.actorParents, ..._ownerParents};

  // ---------------------------------------------------------------------------
  // Type context and palette
  // ---------------------------------------------------------------------------

  @override
  LuminaBlueprintTypeContext buildTypeContext({LuminaBlueprintFunctionGraph? function, LuminaBlueprintMacroGraph? macro}) {
    if (!_ownersRead) _refreshOwners();
    return BlueprintEditorTypeContext.of(
      LuminaBlueprintTypeContext.forDocument(
        document,
        inputActions: inputActions,
        widgetClasses: widgetClassCatalog?.widgetClasses ?? const [],
        className: LuminaLevelBlueprintDocument.parentClass,
        actorParents: _actorParents,
        enums: assetCatalog?.enums,
        interfaces: assetCatalog?.interfaces,
        functionScope: function,
        macroScope: macro,
        levelActors: levelActors,
        customEventOwners: {...?widgetClassCatalog?.actorEvents, ..._ownerEvents},
        variableOwners: widgetClassCatalog?.actorVariables ?? const {},
        componentOwners: widgetClassCatalog?.actorComponents ?? const {},
      ),
      implementedInterfaces: document.interfaces,
    );
  }

  /// `Create a Reference to <Actor>` for each actor selected in the
  /// outliner, pinned at the top of the right-click palette.
  @override
  List<BlueprintPaletteEntry> pinnedPaletteEntries() {
    final selected = selectedActorNames?.call() ?? const <String>[];
    if (selected.isEmpty) return const [];
    final refs = {for (final r in levelActors) r.name: r};
    return [
      for (final name in selected)
        if (refs[name] case final ref?) BlueprintPalette.levelActorReference(ref, createReference: true),
    ];
  }

  // ---------------------------------------------------------------------------
  // Load, save, compile
  // ---------------------------------------------------------------------------

  /// Readies a freshly opened editor: the project's input actions,
  /// functions and assets, and the placed actors' classes, without
  /// replacing the document it opened with.
  void prepare() {
    refreshProjectContext(projectDirectory);
    _refreshOwners();
    _actorsSignature = _signatureOf(levelActors);
    graphsChanged();
  }

  @override
  Future<void> load() async {
    refreshProjectContext(projectDirectory);
    _savedActors = null;
    _refreshOwners();
    _actorsSignature = _signatureOf(levelActors);
    adoptDocument(LuminaLevelRepository(projectDirectory).loadLevelBlueprint(levelPath).blueprint);
  }

  /// Writes the Blueprint into the level `.lmas` (`metadata.levelBlueprint`),
  /// keeping everything else of the level as it is on disk.
  @override
  Future<bool> save() async {
    try {
      final saved = LuminaLevelBlueprintDocument(
        levelPath: levelPath,
        blueprint: LuminaBlueprintDocument.fromJson(Map<String, dynamic>.from(jsonDecode(jsonEncode(document.toJson())) as Map)),
      );
      LuminaLevelRepository(projectDirectory).saveLevelBlueprint(saved);
      markSaved();
      onSaved?.call(saved);
      EngineLoggerService().log('Saved the Level Blueprint of $levelName into $levelPath', level: 'info', source: 'Blueprint');
      return true;
    } catch (e, st) {
      EngineLoggerService().log('Failed to save the Level Blueprint of $levelName: $e\n$st', level: 'error', source: 'Blueprint');
      return false;
    }
  }

  BlueprintGenerationResult _generate() => const BlueprintDartGenerator().generateLevelScript(
        LuminaLevelBlueprintDocument(levelPath: levelPath, blueprint: BlueprintEditorNodes.forEngine(document)),
        className: scriptClassName,
        levelName: levelName,
        levelActors: levelActors,
        inputActions: inputActions,
        actorParents: _actorParents,
        customEventOwners: _ownerEvents,
      );

  /// lumina's validator and level script generator on the graph as it is
  /// now (components, unknown or duplicate actor names, level
  /// nodes); Save writes it into the level, Save Level writes the script
  /// into `lib/levels/`.
  @override
  Future<bool> compile() async {
    refreshProjectContext(projectDirectory);
    _savedActors = null;
    _refreshOwners();
    final result = _generate();
    final issues = [...result.issues];
    if (!result.ok && !issues.any((d) => d.isError)) {
      issues.add(const LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.error, 'The level script could not be generated.'));
    }
    applyCompileResult(issues);
    return !issues.any((d) => d.isError);
  }

  (int, String)? _codeCache;

  /// The level script class Save Level writes into `lib/levels/<Level>.dart`.
  @override
  String get generatedDartCode {
    final cached = _codeCache;
    if (cached != null && cached.$1 == revision) return cached.$2;
    final result = _generate();
    final code = result.code ??
        '// $scriptClassName is not generated while the graph has errors:\n'
            '${result.errors.map((d) => '//   ${d.message}').join('\n')}';
    _codeCache = (revision, code);
    return code;
  }

  @override
  @protected
  void graphsChanged() {
    _codeCache = null;
    super.graphsChanged();
  }
}
