import 'dart:convert';
import 'dart:io';

import 'package:lumina/data/services/blueprint_class_registry.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../sub_editors/models/blueprint_compile_status.dart';
import '../../sub_editors/models/blueprint_editor_nodes.dart';
import '../../sub_editors/services/blueprint_asset_catalog.dart';
import '../../sub_editors/view_models/blueprint_editor_view_model.dart';

import '../../sub_editors/services/widget_class_catalog.dart';

/// Play's Blueprint classes: lumina's
/// [LuminaBlueprintClassRegistry], except that a Blueprint open in an editor
/// plays its document as it is in the editor, compiled but not necessarily
/// saved — Play runs the in-memory class. Every document,
/// open or on disk, reaches the VM without its editor-only comment and
/// reroute nodes, and the project's enum, interface and widget class
/// assets are registered with lumina before any class compiles.
class EditorBlueprintClassRegistry extends LuminaBlueprintClassRegistry {
  /// Open Blueprint editors' documents by project-relative `.lmas` path.
  final Map<String, LuminaBlueprintDocument> Function() openDocuments;

  EditorBlueprintClassRegistry(
    super.projectDir, {
    super.inputActions,
    Map<String, LuminaBlueprintDocument> Function()? openDocuments,
  }) : openDocuments = openDocuments ?? (() => const {}) {
    registerProjectAssets();
  }

  /// Registers the project's enums, interfaces, and widget classes into lumina's registries.
  void registerProjectAssets() {
    LuminaBlueprintEnums.registerAll([for (final e in BlueprintAssetCatalog.scanEnums(projectDir)) e.document]);
    LuminaBlueprintInterfaces.registerAll([for (final i in BlueprintAssetCatalog.scanInterfaces(projectDir)) i.document]);
    final widgetClasses = WidgetClassCatalog.scanWidgetClasses(projectDir);
    LuminaWidgetClassRegistry.registerAll(widgetClasses);
  }

  final Map<String, ({DateTime stamp, LuminaBlueprintClass cls})> _flattened = {};

  void _syncDefinitions() {
    scanDefinitions();
    final openDocs = openDocuments();
    for (final entry in openDocs.entries) {
      final name = entry.key.split('/').last.replaceAll('.lmas', '');
      final doc = entry.value;
      if (doc.parentClass.isNotEmpty) {
        actorParents[name] = doc.parentClass;
      }
      customEventOwners[name] = LuminaBlueprintNodeLibrary.customEventsOf(doc.eventGraph);
    }
    for (final entry in openDocs.entries) {
      final name = entry.key.split('/').last.replaceAll('.lmas', '');
      final doc = entry.value;
      variableOwners[name] = resolvedVariablesFor(name, doc);
      componentOwners[name] = resolvedComponentsFor(name, doc);
    }
  }

  @override
  LuminaBlueprintClass? classFor(String path) {
    _syncDefinitions();
    final openDocs = openDocuments();
    final name = path.replaceAll('.lmas', '').split('/').last;
    final entry = openDocs.entries
        .where((e) =>
            e.key == path ||
            e.key == 'contents/$path' ||
            (path.startsWith('contents/') && e.key == path.substring('contents/'.length)) ||
            e.key.replaceAll('.lmas', '').split('/').last == name)
        .firstOrNull;
    if (entry == null) return _diskClassFor(path);
    return _compile(entry.key, entry.value);
  }

  LuminaBlueprintClass _compile(String path, LuminaBlueprintDocument document) {
    final name = path.split('/').last.replaceAll('.lmas', '');
    final engineDoc = BlueprintEditorNodes.forEngine(document);
    return LuminaBlueprintClass.fromDocument(
      engineDoc,
      name: name,
      inputActions: inputActions,
      resolveAsset: resolveAsset,
      animBlueprints: (animClass) => animClassFor(animClass)?.factory,
      resolveClass: classFor,
      actorParents: actorParents,
      variableOwners: variableOwners,
      componentOwners: componentOwners,
      customEventOwners: customEventOwners,
    );
  }

  /// A saved document is compiled here (cached by file stamp).
  LuminaBlueprintClass? _diskClassFor(String path) {
    var resolvedPath = path;
    var file = File('$projectDir/$resolvedPath');
    if (!file.existsSync() && !path.startsWith('contents/')) {
      final inContents = File('$projectDir/contents/$path');
      if (inContents.existsSync()) {
        resolvedPath = 'contents/$path';
        file = inContents;
      }
    }
    if (!file.existsSync()) return super.classFor(path);
    LuminaBlueprintDocument? doc;
    try {
      final payload = LuminaAsset.fromBytes(file.readAsBytesSync()).rawPayload;
      if (payload != null && payload.isNotEmpty) {
        final json = jsonDecode(utf8.decode(payload));
        if (json is Map) doc = LuminaBlueprintDocument.fromJson(Map<String, dynamic>.from(json));
      }
    } catch (_) {
      doc = null;
    }
    if (doc == null) return super.classFor(path);
    final stamp = file.lastModifiedSync();
    final cached = _flattened[resolvedPath];
    if (cached != null && cached.stamp == stamp) return cached.cls;
    final cls = _compile(resolvedPath, doc);
    _flattened[resolvedPath] = (stamp: stamp, cls: cls);
    if (!cls.isGameMode) {
      LuminaBlueprintActorClasses.register(cls.name, () => (classFor(resolvedPath) ?? cls).instantiate());
    }
    return cls;
  }

  /// [levelPath]'s Level Blueprint: the one open in a
  /// Level Blueprint editor as it is there (compiled, not necessarily
  /// saved), else the level's stored one — either without its editor-only
  /// comment and reroute nodes.
  @override
  LuminaBlueprintClass? levelClassFor(String levelPath,
      {List<Map<String, dynamic>>? actorMaps, LuminaLevelBlueprintDocument? document}) {
    _syncDefinitions();
    if (document == null) {
      final open = openDocuments()[levelPath];
      document = open != null && open.parentClass == LuminaLevelBlueprintDocument.parentClass
          ? LuminaLevelBlueprintDocument(levelPath: levelPath, blueprint: open)
          : LuminaLevelRepository(projectDir).loadLevelBlueprint(levelPath);
    }
    final flattened = LuminaLevelBlueprintDocument(levelPath: levelPath, blueprint: BlueprintEditorNodes.forEngine(document.blueprint));
    return super.levelClassFor(levelPath, actorMaps: actorMaps, document: flattened);
  }

  /// The Pawn / Character Blueprint Play possesses for [mapsAndModes]: its
  /// Default Pawn Class, else its GameMode Blueprint's; null when neither
  /// names one.
  String? pawnClassPath(ProjectMapsAndModes mapsAndModes) {
    if (mapsAndModes.defaultPawnClass.isNotEmpty) return mapsAndModes.defaultPawnClass;
    if (!mapsAndModes.gameModeIsBlueprint) return null;
    final pawn = classFor(mapsAndModes.defaultGameMode)?.defaultPawnClass ?? '';
    return pawn.isEmpty ? null : pawn;
  }
}

/// A reason Play did not start: a Blueprint with a compile error, and the
/// node it is on when there is one (a row of Play's compile errors dialog).
class PlayBlocker {
  final String blueprintPath;
  final String message;
  final String? nodeId;
  final String? nodeTitle;

  const PlayBlocker({required this.blueprintPath, required this.message, this.nodeId, this.nodeTitle});

  String get blueprintName => blueprintPath.split('/').last.replaceAll('.lmas', '');

  @override
  String toString() => '$blueprintName${nodeTitle == null ? '' : ' → $nodeTitle'}: $message';
}

/// Play's compile step: open Blueprints whose badge is
/// Dirty or Unknown compile first; then every class Play will use — the
/// GameMode Blueprint, the pawn class and placed Blueprint actors — must load
/// and validate. Warnings never block.
abstract final class BlueprintPlayPreflight {
  /// Whether an open editor must compile before Play.
  static bool needsCompile(BlueprintEditorViewModel vm) =>
      vm.compileStatus == BlueprintCompileStatus.dirty || vm.compileStatus == BlueprintCompileStatus.unknown;

  static String relativePath(String projectDir, String path) {
    final abs = File(path).absolute.path;
    return abs.startsWith('$projectDir/') ? abs.substring(projectDir.length + 1) : path;
  }

  /// Compiles [editors] and returns the errors, by Blueprint and node; their
  /// warnings go to [warnings] when given.
  static Future<List<PlayBlocker>> compileEditors(String projectDir, Iterable<BlueprintEditorViewModel> editors,
      {List<PlayBlocker>? warnings}) async {
    final out = <PlayBlocker>[];
    for (final vm in editors) {
      await vm.compile();
      for (final d in vm.diagnostics) {
        (d.isError ? out : (warnings ?? <PlayBlocker>[])).add(PlayBlocker(
          blueprintPath: relativePath(projectDir, vm.assetPath),
          message: d.message,
          nodeId: d.nodeId,
          nodeTitle: vm.diagnosticNodeTitle(d),
        ));
      }
    }
    return out;
  }

  /// Loads and validates the classes Play will use; their warnings go to
  /// [warnings] when given.
  static List<PlayBlocker> validate(
    EditorBlueprintClassRegistry registry,
    ProjectMapsAndModes mapsAndModes,
    Iterable<String> placedClasses, {
    List<PlayBlocker>? warnings,
  }) {
    final out = <PlayBlocker>[];
    final seen = <String>{};
    void check(String path, {String? role}) {
      if (path.isEmpty || !seen.add(path)) return;
      final cls = registry.classFor(path);
      if (cls == null) {
        out.add(PlayBlocker(blueprintPath: path, message: '${role ?? 'Blueprint'} $path cannot be loaded.'));
        return;
      }
      for (final d in cls.diagnostics) {
        (d.isError ? out : (warnings ?? <PlayBlocker>[])).add(PlayBlocker(
          blueprintPath: path,
          message: d.message,
          nodeId: d.nodeId,
          nodeTitle: d.nodeId == null ? null : cls.document.eventGraph.node(d.nodeId!)?.title,
        ));
      }
    }

    if (mapsAndModes.gameModeIsBlueprint) check(mapsAndModes.defaultGameMode, role: 'Game mode');
    final pawn = registry.pawnClassPath(mapsAndModes);
    if (pawn != null) {
      check(pawn, role: 'Default Pawn Class');
      final cls = registry.classFor(pawn);
      if (cls != null && !cls.hasErrors && !cls.isPawn) {
        out.add(PlayBlocker(
            blueprintPath: pawn, message: 'Default Pawn Class is a ${cls.document.parentClass}, not a Pawn or Character.'));
      }
    }
    for (final path in placedClasses) {
      check(path);
    }
    return out;
  }
}

/// How the level viewport draws a placed Blueprint:
/// its first mesh component (the GLB, and that component's transform
/// relative to the actor, composed through its parents as lumina builds
/// them) and, for a Character, its capsule.
class BlueprintActorPreview {
  /// The project-relative mesh asset the viewport loads.
  final String? meshAsset;

  /// The mesh component's transform relative to the actor, runtime space.
  final Matrix4 meshRelative;
  final bool isCharacter;
  final double capsuleRadius;
  final double capsuleHalfHeight;
  final String parentClass;

  const BlueprintActorPreview({
    required this.meshAsset,
    required this.meshRelative,
    required this.isCharacter,
    required this.capsuleRadius,
    required this.capsuleHalfHeight,
    required this.parentClass,
  });

  static const Set<String> _meshTypes = {'LuminaStaticMeshComponent', 'LuminaSkeletalMeshComponent', 'LuminaAnimatedMeshComponent'};

  static Matrix4 _relative(LuminaBlueprintComponent c) {
    List<num>? list(Object? v) => v is List ? v.cast<num>() : null;
    final p = c.properties;
    return Matrix4.compose(
      LuminaAxes.location(list(p['location']) ?? const [0, 0, 0]),
      LuminaAxes.rotation(list(p['rotation']) ?? const [0, 0, 0]),
      LuminaAxes.scale(list(p['scale']) ?? const [1, 1, 1]),
    );
  }

  /// Reads the Blueprint at [path] (project-relative) in [projectDir].
  static BlueprintActorPreview? read(String projectDir, String path) {
    final file = File('$projectDir/$path');
    if (!file.existsSync()) return null;
    LuminaBlueprintDocument doc;
    try {
      final payload = LuminaAsset.fromBytes(file.readAsBytesSync()).rawPayload;
      if (payload == null) return null;
      doc = LuminaBlueprintDocument.fromJson(Map<String, dynamic>.from(jsonDecode(utf8.decode(payload)) as Map));
    } catch (_) {
      return null;
    }
    return of(doc);
  }

  static BlueprintActorPreview of(LuminaBlueprintDocument doc) {
    final isCharacter = doc.parentClass == 'LuminaCharacter';
    LuminaBlueprintComponent? byId(String? id) => id == null ? null : doc.components.where((c) => c.id == id).firstOrNull;
    LuminaBlueprintComponent? mesh;
    for (final c in doc.components) {
      final asset = c.properties['staticMeshAsset'] ?? c.properties['skeletalMeshAsset'];
      if (_meshTypes.contains(c.type) && asset is String && asset.isNotEmpty) {
        mesh = c;
        break;
      }
    }
    var relative = Matrix4.identity();
    if (mesh != null) {
      // Parents first; the root is the actor's own root (its transform is
      // the actor's), and a Character's capsule is the root.
      final chain = <LuminaBlueprintComponent>[];
      LuminaBlueprintComponent c = mesh;
      while (true) {
        chain.insert(0, c);
        final parent = byId(c.parentId);
        if (parent == null || parent.parentId == null) break;
        if (isCharacter && parent.type == 'LuminaCapsuleComponent') break;
        c = parent;
      }
      for (final link in chain) {
        relative = relative * _relative(link);
      }
    }
    final capsule = doc.components.where((c) => c.type == 'LuminaCapsuleComponent').firstOrNull;
    double number(Object? v, double d) => v is num ? v.toDouble() : d;
    return BlueprintActorPreview(
      meshAsset: (mesh?.properties['staticMeshAsset'] ?? mesh?.properties['skeletalMeshAsset']) as String?,
      meshRelative: relative,
      isCharacter: isCharacter,
      capsuleRadius: number(capsule?.properties['capsuleRadius'], 35.0),
      capsuleHalfHeight: number(capsule?.properties['capsuleHalfHeight'], 90.0),
      parentClass: doc.parentClass,
    );
  }
}
