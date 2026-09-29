import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumina/lumina.dart';

import '../../main_editor/services/widget_blueprint_assets.dart';
import '../models/umg_document.dart';

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
  StreamSubscription<void>? _subscription;

  WidgetClassCatalog(this.projectDir, {bool watch = true}) {
    refresh();
    if (watch) _subscription = AssetRepository.onAssetsChanged.listen((_) => refresh());
  }

  /// The widget classes on disk, by name.
  List<LuminaBlueprintWidgetClass> get widgetClasses => _widgetClasses;

  /// Project Blueprint class → its parent class (`BP_Door` → `LuminaActor`).
  Map<String, String> get actorParents => _actorParents;

  LuminaBlueprintWidgetClass? widgetClass(String? name) {
    for (final w in _widgetClasses) {
      if (w.name == name) return w;
    }
    return null;
  }

  /// Re-reads the project; listeners are told when anything changed.
  void refresh() {
    final widgets = scanWidgetClasses(projectDir);
    final actors = scanActorParents(projectDir);
    final changed = jsonEncode(widgets.map((w) => w.toJson()).toList()) !=
            jsonEncode(_widgetClasses.map((w) => w.toJson()).toList()) ||
        !mapEquals(actors, _actorParents);
    _widgetClasses = List.unmodifiable(widgets);
    _actorParents = Map.unmodifiable(actors);
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

  /// Every actor Blueprint under `contents/blueprints/` → its parent class,
  /// from the asset index's summaries (the Blueprint document's
  /// `parentClass`, else `metadata.parent_class`).
  static Map<String, String> scanActorParents(String projectDir) {
    final dir = Directory('$projectDir/contents/blueprints');
    if (!dir.existsSync()) return const {};
    final index = LuminaAssetIndex.open(projectDir)..refreshSync();
    final out = <String, String>{};
    for (final e in index.entries) {
      if (!e.path.startsWith('contents/blueprints/') || e.type != AssetType.actor) continue;
      final parent = e.summary.parentClass;
      if (parent == null || parent.isEmpty || parent == kWidgetBlueprintParentClass) continue;
      out[e.baseName] = parent;
    }
    return out;
  }
}
