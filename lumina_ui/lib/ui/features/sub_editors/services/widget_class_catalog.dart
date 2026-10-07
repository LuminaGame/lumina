import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/features/main_editor/services/widget_blueprint_assets.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';

/// The project's classes as the Blueprint type context needs them:
/// every widget `.lmas` under `contents/` as a
/// [LuminaBlueprintWidgetClass] (its designer elements become `Get <Element>`
/// rows and `Widget:<name>` pin classes), and every actor Blueprint's parent
/// class for assignability up the chain. Read from disk, refreshed on
/// [AssetRepository.onAssetsChanged] (the UMG editor saved → the next palette
/// open sees the new element), and registered into
/// [LuminaWidgetClassRegistry] when Play starts.
class WidgetClassCatalog extends ChangeNotifier {
  final String projectDir;
  List<LuminaBlueprintWidgetClass> _widgetClasses = const [];
  Map<String, String> _actorParents = const {};
  Map<String, List<LuminaBlueprintVariable>> _actorVariables = const {};
  Map<String, List<LuminaBlueprintComponentRef>> _actorComponents = const {};
  Map<String, List<LuminaBlueprintCustomEvent>> _actorEvents = const {};
  StreamSubscription<void>? _subscription;

  WidgetClassCatalog(this.projectDir, {bool watch = true}) {
    refresh();
    if (watch) _subscription = AssetRepository.onAssetsChanged.listen((_) => refresh());
  }

  /// The widget classes on disk, by name.
  List<LuminaBlueprintWidgetClass> get widgetClasses => _widgetClasses;

  /// Project Blueprint class → its parent class (`BP_Door` → `LuminaActor`).
  Map<String, String> get actorParents => _actorParents;

  /// Member variables of each project Actor Blueprint by class name.
  Map<String, List<LuminaBlueprintVariable>> get actorVariables => _actorVariables;

  /// Components of each project Actor Blueprint by class name.
  Map<String, List<LuminaBlueprintComponentRef>> get actorComponents => _actorComponents;

  /// Custom events of each project Actor Blueprint by class name.
  Map<String, List<LuminaBlueprintCustomEvent>> get actorEvents => _actorEvents;

  LuminaBlueprintWidgetClass? widgetClass(String? name) {
    for (final w in _widgetClasses) {
      if (w.name == name) return w;
    }
    return null;
  }

  /// Re-reads the project; listeners are told when anything changed.
  void refresh() {
    final widgets = scanWidgetClasses(projectDir);
    final actors = scanActorDefinitions(projectDir);
    final changed = jsonEncode(widgets.map((w) => w.toJson()).toList()) !=
            jsonEncode(_widgetClasses.map((w) => w.toJson()).toList()) ||
        !mapEquals(actors.parents, _actorParents);
    _widgetClasses = List.unmodifiable(widgets);
    _actorParents = Map.unmodifiable(actors.parents);
    _actorVariables = Map.unmodifiable(actors.variables);
    _actorComponents = Map.unmodifiable(actors.components);
    _actorEvents = Map.unmodifiable(actors.events);
    // The validator and the Dart generator resolve `Get <Element>` through
    // the registry (lumina's default type context), so the editor keeps it
    // current with the files on disk.
    registerRuntimeClasses();
    if (changed) notifyListeners();
  }

  /// Makes every widget class of this project known to the runtime
  /// (`Create Widget` seeds per-element state from it).
  void registerRuntimeClasses() => LuminaWidgetClassRegistry.registerAll(_widgetClasses);

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Disk
  // ---------------------------------------------------------------------------

  /// Every widget Blueprint under `contents/` of [projectDir], sorted by
  /// name: found through the project's asset index, so
  /// only the widget `.lmas` files are read.
  static List<LuminaBlueprintWidgetClass> scanWidgetClasses(String projectDir) {
    final contents = Directory('$projectDir/contents');
    if (!contents.existsSync()) return const [];
    final index = LuminaAssetIndex.open(projectDir)..refreshSync();
    final out = <LuminaBlueprintWidgetClass>[
      for (final e in index.entries)
        if (isWidgetBlueprintSummary(e.summary)) _widgetClassOf(e.file),
    ];
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  /// The widget class stored in the widget `.lmas` [file], or null when the
  /// file is not a widget Blueprint (or cannot be read).
  static LuminaBlueprintWidgetClass? readWidgetClass(File file) {
    if (!isWidgetBlueprintLmas(file.path)) return null;
    return _widgetClassOf(file);
  }

  static LuminaBlueprintWidgetClass _widgetClassOf(File file) {
    final name = file.uri.pathSegments.last.replaceAll('.lmas', '');
    try {
      final asset = LuminaAsset.fromBytes(file.readAsBytesSync());
      final payload = asset.rawPayload;
      if (payload == null || payload.isEmpty) return LuminaBlueprintWidgetClass(name: name);
      final json = jsonDecode(utf8.decode(payload));
      if (json is! Map) return LuminaBlueprintWidgetClass(name: name);
      return fromUmgDocument(name, UmgDocument.fromJson(Map<String, dynamic>.from(json)));
    } catch (_) {
      return LuminaBlueprintWidgetClass(name: name);
    }
  }

  /// [doc] as the engine sees it: one element per designer widget below
  /// the root, typed by its `UmgWidgetType` name and seeded with its stored
  /// properties.
  static LuminaBlueprintWidgetClass fromUmgDocument(String name, UmgDocument doc) => LuminaBlueprintWidgetClass(
        name: name,
        elements: [
          for (final n in doc.allNodes)
            if (n.id != doc.root.id)
              LuminaBlueprintWidgetElement(
                name: n.name,
                fieldName: n.fieldName.isEmpty ? n.name : n.fieldName,
                typeName: n.type.name,
                props: Map<String, dynamic>.from(n.props),
              ),
        ],
      );

  /// Every actor Blueprint under `contents/` → its definitions: parent class,
  /// member variables, components, and custom events, with inheritance resolved.
  static ({
    Map<String, String> parents,
    Map<String, List<LuminaBlueprintVariable>> variables,
    Map<String, List<LuminaBlueprintComponentRef>> components,
    Map<String, List<LuminaBlueprintCustomEvent>> events,
  }) scanActorDefinitions(String projectDir) {
    final contents = Directory('$projectDir/contents');
    if (!contents.existsSync()) {
      return (
        parents: const {},
        variables: const {},
        components: const {},
        events: const {},
      );
    }
    final index = LuminaAssetIndex.open(projectDir)..refreshSync();
    final parents = <String, String>{};
    final rawVariables = <String, List<LuminaBlueprintVariable>>{};
    final rawComponents = <String, List<LuminaBlueprintComponentRef>>{};
    final events = <String, List<LuminaBlueprintCustomEvent>>{};

    void processFile(File file, String baseName) {
      if (rawVariables.containsKey(baseName)) return;
      try {
        final asset = LuminaAsset.fromBytes(file.readAsBytesSync());
        if (asset.type != AssetType.actor) return;
        final payload = asset.rawPayload;
        if (payload == null || payload.isEmpty) return;
        final json = jsonDecode(utf8.decode(payload));
        if (json is! Map) return;
        final map = Map<String, dynamic>.from(json);
        if (luminaBlueprintDocumentKind(map) != 'class') return;
        final doc = LuminaBlueprintDocument.fromJson(map);
        final parent = doc.parentClass;
        if (parent.isNotEmpty && parent != kWidgetBlueprintParentClass) {
          parents[baseName] = parent;
        }
        rawVariables[baseName] = doc.variables;
        rawComponents[baseName] = LuminaBlueprintComponentRef.fromComponents(doc.components);
        events[baseName] = LuminaBlueprintNodeLibrary.customEventsOf(doc.eventGraph);
      } catch (_) {}
    }

    for (final e in index.entries) {
      if (e.type != AssetType.actor) continue;
      processFile(e.file, e.baseName);
    }

    // Also scan contents directory directly to find any actor .lmas files not yet indexed or in subfolders
    try {
      for (final entity in contents.listSync(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.endsWith('.lmas')) {
          final fileName = entity.uri.pathSegments.last;
          final baseName = fileName.replaceAll('.lmas', '');
          if (!rawVariables.containsKey(baseName)) {
            processFile(entity, baseName);
          }
        }
      }
    } catch (_) {}

    // Resolve inheritance for each actor
    final variables = <String, List<LuminaBlueprintVariable>>{};
    final components = <String, List<LuminaBlueprintComponentRef>>{};
    for (final name in rawVariables.keys) {
      final vars = <LuminaBlueprintVariable>[];
      final comps = <LuminaBlueprintComponentRef>[];
      final visited = <String>{name};
      var currentParent = parents[name];
      while (currentParent != null && !LuminaBlueprintClass.isEngineParent(currentParent) && visited.add(currentParent)) {
        final parentVars = rawVariables[currentParent];
        if (parentVars != null) vars.insertAll(0, parentVars);
        final parentComps = rawComponents[currentParent];
        if (parentComps != null) comps.insertAll(0, parentComps);
        currentParent = parents[currentParent];
      }
      final ownVars = rawVariables[name] ?? const [];
      final ownVarNames = {for (final v in ownVars) v.name};
      variables[name] = [
        for (final v in vars) if (!ownVarNames.contains(v.name)) v,
        ...ownVars,
      ];
      final ownComps = rawComponents[name] ?? const [];
      final ownCompNames = {for (final c in ownComps) c.name};
      components[name] = [
        for (final c in comps) if (!ownCompNames.contains(c.name)) c,
        ...ownComps,
      ];
    }

    return (
      parents: parents,
      variables: variables,
      components: components,
      events: events,
    );
  }

  /// Every actor Blueprint under `contents/` → its parent class.
  static Map<String, String> scanActorParents(String projectDir) =>
      scanActorDefinitions(projectDir).parents;
}
