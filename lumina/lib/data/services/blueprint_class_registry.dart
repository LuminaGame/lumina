import 'dart:convert';
import 'dart:io';

import 'package:lumina/src/object/lumina_object_key.dart';

import 'package:lumina/src/blueprint/blueprint.dart';
import 'package:lumina/src/blueprint/level_blueprint_storage.dart';
import 'package:lumina/src/blueprint/vm/anim_blueprint_vm.dart';
import 'package:lumina/src/blueprint/vm/blueprint_vm.dart';
import 'package:lumina/src/game/game_mode.dart';
import 'package:lumina/src/input/input_action.dart';
import 'package:lumina/src/object/pawn.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/data/services/blueprint_project_assets.dart';
import 'package:lumina/data/services/code_generator_service.dart';

/// A project's Blueprint classes for the VM: what the editor's
/// Play resolves a class reference — a project-relative `.lmas` path — to,
/// where a generated game uses `luminaBlueprintFactories`.
///
/// Classes are compiled once and cached by path. A path whose file changed on
/// disk (its modification time) is compiled again on its next use, so a
/// Blueprint saved or recompiled in the editor is what the next Play spawns.
/// Animation Blueprints a mesh names as its Anim Class are served the same
/// way, with the blend spaces their states play.
class LuminaBlueprintClassRegistry {
  final String projectDir;
  final List<LuminaInputAction> inputActions;

  /// Maps a stored mesh reference to the file a mesh component loads.
  final LuminaBlueprintAssetResolver resolveAsset;

  LuminaBlueprintClassRegistry(
    this.projectDir, {
    List<LuminaInputAction>? inputActions,
    LuminaBlueprintAssetResolver? resolveAsset,
    Map<String, String>? actorParents,
    Map<String, List<LuminaBlueprintVariable>>? variableOwners,
    Map<String, List<LuminaBlueprintComponentRef>>? componentOwners,
    Map<String, List<LuminaBlueprintCustomEvent>>? customEventOwners,
  })  : inputActions = inputActions ?? DartCodeGeneratorService.projectInputActions(projectDir),
        resolveAsset = resolveAsset ?? _projectResolver(projectDir) {
    if (actorParents != null) this.actorParents.addAll(actorParents);
    if (variableOwners != null) this.variableOwners.addAll(variableOwners);
    if (componentOwners != null) this.componentOwners.addAll(componentOwners);
    if (customEventOwners != null) this.customEventOwners.addAll(customEventOwners);
  }

  final Map<String, ({DateTime stamp, LuminaBlueprintClass cls})> _classes = {};
  final Map<String, ({String stamp, LuminaAnimBlueprintClass cls})> _anims = {};
  final Set<String> _loading = {};
  final Map<String, String> actorParents = {};
  final Map<String, List<LuminaBlueprintVariable>> variableOwners = {};
  final Map<String, List<LuminaBlueprintComponentRef>> componentOwners = {};
  final Map<String, List<LuminaBlueprintCustomEvent>> customEventOwners = {};

  bool _definitionsScanned = false;

  /// Scans the project's contents directory for all actor Blueprints to populate
  /// actorParents, variableOwners, componentOwners, and customEventOwners with
  /// inheritance resolved, so cross-actor references compile cleanly.
  void scanDefinitions() {
    if (_definitionsScanned) return;
    _definitionsScanned = true;
    final contents = Directory('$projectDir/contents');
    if (!contents.existsSync()) return;
    final rawParents = <String, String>{};
    final rawVariables = <String, List<LuminaBlueprintVariable>>{};
    final rawComponents = <String, List<LuminaBlueprintComponentRef>>{};
    try {
      for (final entity in contents.listSync(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.endsWith('.lmas')) {
          final fileName = entity.path.split(RegExp(r'[\\/]')).last;
          final baseName = fileName.replaceAll('.lmas', '');
          final raw = _payload(entity);
          if (raw != null) {
            try {
              final doc = LuminaBlueprintDocument.fromJson(raw);
              final parent = doc.parentClass;
              if (parent.isNotEmpty && parent != 'LuminaWidgetBlueprint') {
                rawParents[baseName] = parent;
                rawVariables[baseName] = doc.variables;
                rawComponents[baseName] = LuminaBlueprintComponentRef.fromComponents(doc.components);
                if (!customEventOwners.containsKey(baseName)) {
                  customEventOwners[baseName] = LuminaBlueprintNodeLibrary.customEventsOf(doc.eventGraph);
                }
              }
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    // Resolve inheritance so inherited variables/components are available on derived classes
    for (final name in rawVariables.keys) {
      final vars = <LuminaBlueprintVariable>[];
      final comps = <LuminaBlueprintComponentRef>[];
      final visited = <String>{name};
      var currentParent = rawParents[name];
      while (currentParent != null && !LuminaBlueprintClass.isEngineParent(currentParent) && visited.add(currentParent)) {
        final parentVars = rawVariables[currentParent] ?? variableOwners[currentParent];
        if (parentVars != null) vars.insertAll(0, parentVars);
        final parentComps = rawComponents[currentParent] ?? componentOwners[currentParent];
        if (parentComps != null) comps.insertAll(0, parentComps);
        currentParent = rawParents[currentParent] ?? actorParents[currentParent];
      }
      final ownVars = rawVariables[name] ?? const [];
      final ownVarNames = {for (final v in ownVars) v.name};
      if (!variableOwners.containsKey(name)) {
        variableOwners[name] = [
          for (final v in vars) if (!ownVarNames.contains(v.name)) v,
          ...ownVars,
        ];
      }
      final ownComps = rawComponents[name] ?? const [];
      final ownCompNames = {for (final c in ownComps) c.name};
      if (!componentOwners.containsKey(name)) {
        componentOwners[name] = [
          for (final c in comps) if (!ownCompNames.contains(c.name)) c,
          ...ownComps,
        ];
      }
      if (!actorParents.containsKey(name) && rawParents.containsKey(name)) {
        actorParents[name] = rawParents[name]!;
      }
    }
  }

  List<LuminaBlueprintVariable> resolvedVariablesFor(String name, LuminaBlueprintDocument doc) {
    final vars = <LuminaBlueprintVariable>[];
    final visited = <String>{name};
    var currentParent = doc.parentClass;
    while (currentParent.isNotEmpty && !LuminaBlueprintClass.isEngineParent(currentParent) && visited.add(currentParent)) {
      final parentVars = variableOwners[currentParent];
      if (parentVars != null) vars.insertAll(0, parentVars);
      currentParent = actorParents[currentParent] ?? '';
    }
    final ownVarNames = {for (final v in doc.variables) v.name};
    return [
      for (final v in vars) if (!ownVarNames.contains(v.name)) v,
      ...doc.variables,
    ];
  }

  List<LuminaBlueprintComponentRef> resolvedComponentsFor(String name, LuminaBlueprintDocument doc) {
    final comps = <LuminaBlueprintComponentRef>[];
    final visited = <String>{name};
    var currentParent = doc.parentClass;
    while (currentParent.isNotEmpty && !LuminaBlueprintClass.isEngineParent(currentParent) && visited.add(currentParent)) {
      final parentComps = componentOwners[currentParent];
      if (parentComps != null) comps.insertAll(0, parentComps);
      currentParent = actorParents[currentParent] ?? '';
    }
    final ownComps = LuminaBlueprintComponentRef.fromComponents(doc.components);
    final ownCompNames = {for (final c in ownComps) c.name};
    return [
      for (final c in comps) if (!ownCompNames.contains(c.name)) c,
      ...ownComps,
    ];
  }

  /// What went wrong loading or compiling classes, newest last. Each message
  /// names the Blueprint it is about.
  final List<LuminaBlueprintDiagnostic> diagnostics = [];

  /// Project-relative paths resolve against [projectDir]; a mesh `.lmas`
  /// loads through its `.entity.glb` companion.
  static LuminaBlueprintAssetResolver _projectResolver(String projectDir) => (stored) {
        final absolute = stored.startsWith('/') ? stored : '$projectDir/$stored';
        return luminaBlueprintMeshPath(absolute);
      };

  String? _findBlueprintPath(String name) {
    final contents = Directory('$projectDir/contents');
    if (!contents.existsSync()) return null;
    try {
      for (final entity in contents.listSync(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.endsWith('.lmas')) {
          final fileName = entity.path.split(RegExp(r'[\\/]')).last;
          if (fileName == '$name.lmas') {
            final rel = entity.path.substring(projectDir.length).replaceAll('\\', '/');
            return rel.startsWith('/') ? rel.substring(1) : rel;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// The Blueprint class at [path] (project-relative `.lmas`), or null when it
  /// cannot be read. A class with compile errors is returned too — check
  /// `hasErrors` — and its errors are added to [diagnostics].
  LuminaBlueprintClass? classFor(String path) {
    var resolvedPath = path;
    var file = File('$projectDir/$resolvedPath');
    if (!file.existsSync()) {
      final name = path.replaceAll('.lmas', '').split('/').last;
      final found = _findBlueprintPath(name);
      if (found != null) {
        resolvedPath = found;
        file = File('$projectDir/$resolvedPath');
      }
    }
    if (!file.existsSync()) {
      _report(LuminaBlueprintSeverity.error, "Blueprint '$path' cannot be loaded: no such file.");
      return null;
    }
    final stamp = file.lastModifiedSync();
    final cached = _classes[resolvedPath];
    if (cached != null && cached.stamp == stamp) return cached.cls;
    // A class that (indirectly) names itself resolves to what is cached.
    if (!_loading.add(resolvedPath)) return cached?.cls;
    try {
      scanDefinitions();
      final rawDocument = _payload(file);
      if (rawDocument == null) {
        _report(LuminaBlueprintSeverity.error, "Blueprint '$resolvedPath' cannot be loaded: it holds no Blueprint document.");
        return null;
      }
      final name = resolvedPath.split('/').last.replaceAll('.lmas', '');
      final blueprintDoc = LuminaBlueprintDocument.fromJson(rawDocument);
      actorParents[name] = blueprintDoc.parentClass;
      variableOwners[name] = resolvedVariablesFor(name, blueprintDoc);
      componentOwners[name] = resolvedComponentsFor(name, blueprintDoc);
      customEventOwners[name] = LuminaBlueprintNodeLibrary.customEventsOf(blueprintDoc.eventGraph);
      final cls = LuminaBlueprintClass.fromDocument(
        blueprintDoc,
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
      for (final d in cls.diagnostics.where((d) => d.isError)) {
        _report(d.severity, '$name: ${d.message}', nodeId: d.nodeId);
      }
      _classes[resolvedPath] = (stamp: stamp, cls: cls);
      // Spawn Actor from Class finds the class by name; the
      // newest compiled version is served at every spawn.
      if (!cls.isGameMode) {
        LuminaBlueprintActorClasses.register(name, () => (classFor(resolvedPath) ?? cls).instantiate());
      }
      return cls;
    } finally {
      _loading.remove(resolvedPath);
    }
  }

  /// Makes every actor Blueprint of [classes] spawnable by name — `Spawn
  /// Actor from Class` in Play-In-Editor, as the generated
  /// `registerProjectBlueprints()` does in a built game. Each class compiles
  /// now; one without errors is registered (GameMode Blueprints never are)
  /// and every spawn is served the class as last compiled. Returns the
  /// registered class names.
  List<String> registerActorClasses(Iterable<LuminaProjectBlueprintClass> classes) {
    final registered = <String>[];
    for (final c in classes) {
      if (c.isGameMode) continue;
      final cls = classFor(c.path);
      if (cls == null || cls.hasErrors || cls.isGameMode) continue;
      LuminaBlueprintActorClasses.register(c.name, () => (classFor(c.path) ?? cls).instantiate());
      registered.add(c.name);
    }
    return registered;
  }

  /// The Level Blueprint of the level at [levelPath],
  /// compiled for the VM: [document] when given (an editor's unsaved graph),
  /// else the level's `metadata.levelBlueprint`; its placed actors are
  /// [actorMaps] (the editor's current level) or the level's saved ones.
  /// The placed Blueprint actors' classes give `Get <Actor>` its types and
  /// targeted Call Custom Event its events. Null when the level has no
  /// Blueprint (or an empty one); a class with errors is returned too and its
  /// errors are added to [diagnostics]. Level scripts are never registered
  /// with `Spawn Actor from Class`.
  LuminaBlueprintClass? levelClassFor(String levelPath,
      {List<Map<String, dynamic>>? actorMaps, LuminaLevelBlueprintDocument? document}) {
    final level = LuminaLevelRepository(projectDir).load(levelPath);
    final doc = document ?? level?.levelBlueprint;
    if (doc == null || doc.isEmpty) return null;
    final actors = actorMaps ?? level?.actors ?? const <Map<String, dynamic>>[];
    final parents = <String, String>{};
    final events = <String, List<LuminaBlueprintCustomEvent>>{};
    for (final a in actors) {
      final path = a['blueprintClass'];
      if (path is! String || path.isEmpty) continue;
      final cls = classFor(path);
      if (cls == null) continue;
      parents[cls.name] = cls.document.parentClass;
      events[cls.name] = LuminaBlueprintNodeLibrary.customEventsOf(cls.document.eventGraph);
    }
    final cls = LuminaBlueprintClass.forLevel(
      doc,
      levelActors: LuminaBlueprintLevelActorRef.fromActorMaps(actors),
      inputActions: inputActions,
      resolveAsset: resolveAsset,
      resolveClass: classFor,
      actorParents: {...actorParents, ...parents},
      customEventOwners: {...customEventOwners, ...events},
      variableOwners: variableOwners,
      componentOwners: componentOwners,
    );
    for (final d in cls.diagnostics.where((d) => d.isError)) {
      _report(d.severity, '${cls.name} (Level Blueprint): ${d.message}', nodeId: d.nodeId);
    }
    return cls;
  }

  /// A new script actor of [levelPath]'s Level Blueprint (see
  /// [levelClassFor]), keyed `<Level>_script` as the generated level's is;
  /// null when the level has no Blueprint or it has errors. Set it as the
  /// level's `scriptActor` before the world begins play.
  LuminaBlueprintLevelScript? levelScriptFor(String levelPath,
      {List<Map<String, dynamic>>? actorMaps, LuminaLevelBlueprintDocument? document}) {
    final cls = levelClassFor(levelPath, actorMaps: actorMaps, document: document);
    if (cls == null || cls.hasErrors) return null;
    return cls.instantiateLevelScript(key: LuminaObjectKey('${cls.name}_script'));
  }

  /// The Animation Blueprint at [path], compiled with the blend spaces its
  /// states play; null when it cannot be read or has errors.
  LuminaAnimBlueprintClass? animClassFor(String path) {
    final file = File('$projectDir/$path');
    if (!file.existsSync()) {
      _report(LuminaBlueprintSeverity.error, "Animation Blueprint '$path' cannot be loaded: no such file.");
      return null;
    }
    final json = _payload(file);
    if (json == null) {
      _report(LuminaBlueprintSeverity.error, "Animation Blueprint '$path' holds no document.");
      return null;
    }
    final document = LuminaAnimBlueprintDocument.fromJson(json);
    final spacePaths = {
      for (final machine in document.stateMachines)
        for (final state in machine.states)
          if (state.pose.blendSpace != null) state.pose.blendSpace!,
    };
    final stamp = [
      file.lastModifiedSync().toIso8601String(),
      for (final s in spacePaths) _stampOf('$projectDir/$s'),
    ].join('|');
    final cached = _anims[path];
    if (cached != null && cached.stamp == stamp) return cached.cls.hasErrors ? null : cached.cls;
    final spaces = <String, LuminaBlendSpaceDocument>{};
    for (final s in spacePaths) {
      final space = File('$projectDir/$s');
      final spaceJson = space.existsSync() ? _payload(space) : null;
      if (spaceJson != null) spaces[s] = LuminaBlendSpaceDocument.fromJson(spaceJson);
    }
    final name = path.split('/').last.replaceAll('.lmas', '');
    final cls = LuminaAnimBlueprintClass.fromDocument(document, name: name, blendSpaces: spaces);
    for (final d in cls.diagnostics.where((d) => d.isError)) {
      _report(d.severity, '$name: ${d.message}', nodeId: d.nodeId);
    }
    _anims[path] = (stamp: stamp, cls: cls);
    return cls.hasErrors ? null : cls;
  }

  /// The pawn factory [mapsAndModes] selects: its Default Pawn Class, else
  /// the Default Pawn Class of its GameMode Blueprint; null when neither
  /// names a Blueprint (the caller's game mode keeps its own pawn). The class
  /// is resolved again at every spawn.
  LuminaPawn Function()? resolvePawnFactory(ProjectMapsAndModes mapsAndModes) {
    var path = mapsAndModes.defaultPawnClass;
    if (path.isEmpty && mapsAndModes.gameModeIsBlueprint) {
      path = classFor(mapsAndModes.defaultGameMode)?.defaultPawnClass ?? '';
    }
    if (path.isEmpty) return null;
    final cls = classFor(path);
    if (cls == null || cls.hasErrors) return null;
    if (!cls.isPawn) {
      _report(LuminaBlueprintSeverity.error,
          "Default Pawn Class '$path' is not a Pawn or Character Blueprint (it is a ${cls.document.parentClass}).");
      return null;
    }
    return () => (classFor(path) ?? cls).instantiate() as LuminaPawn;
  }

  /// The game mode of the GameMode Blueprint [mapsAndModes] selects, with its
  /// Default Pawn Class overridden by Maps & Modes when that is set; null when
  /// the project's game mode is a Dart class or the Blueprint has errors.
  LuminaGameMode? createGameMode(ProjectMapsAndModes mapsAndModes) {
    if (!mapsAndModes.gameModeIsBlueprint) return null;
    final path = mapsAndModes.defaultGameMode;
    final cls = classFor(path);
    if (cls == null || cls.hasErrors) return null;
    if (!cls.isGameMode) {
      _report(LuminaBlueprintSeverity.error, "Game mode '$path' is not a GameMode Blueprint (it is a ${cls.document.parentClass}).");
      return null;
    }
    final override = mapsAndModes.defaultPawnClass.isEmpty ? null : resolvePawnFactory(mapsAndModes);
    return cls.createGameMode(pawnOverride: override);
  }

  void _report(LuminaBlueprintSeverity severity, String message, {String? nodeId}) =>
      diagnostics.add(LuminaBlueprintDiagnostic(severity, message, nodeId: nodeId));

  static String _stampOf(String path) {
    final f = File(path);
    return f.existsSync() ? f.lastModifiedSync().toIso8601String() : 'missing';
  }

  static Map<String, dynamic>? _payload(File file) {
    try {
      final payload = LuminaAsset.fromBytes(file.readAsBytesSync()).rawPayload;
      if (payload == null) return null;
      final decoded = jsonDecode(utf8.decode(payload));
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }
}
