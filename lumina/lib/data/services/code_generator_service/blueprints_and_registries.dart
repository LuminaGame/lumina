part of '../code_generator_service.dart';

/// Blueprint classes, the actor / Blueprint registries and project input
/// actions, compiled and written into the project.
mixin _BlueprintsAndRegistriesCodegen on _DartCodeGeneratorServiceState {

  /// Generates a real declarative Dart class from a Blueprint document map.
  /// The Blueprint [assetName]'s generated Dart class, or, when
  /// the Blueprint has errors, a comment listing them (the editor's live code
  /// preview shows either).
  String generateActorClassDart(
    String assetName,
    Map<String, dynamic> docMap, {
    String? existingContent,
    List<LuminaInputAction> inputActions = const [],
    LuminaBlueprintTypeContext? typeContext,
  }) {
    final result = generateBlueprintClass(assetName, docMap,
        existingContent: existingContent, inputActions: inputActions, typeContext: typeContext);
    if (result.ok) return result.code!;
    final b = StringBuffer('// Blueprint $assetName cannot be generated:\n');
    for (final e in result.errors) {
      b.writeln('// - ${e.message}${e.nodeId == null ? '' : ' (node ${e.nodeId})'}');
    }
    return b.toString();
  }

  /// Generates the Blueprint [assetName] with [BlueprintDartGenerator].
  BlueprintGenerationResult generateBlueprintClass(
    String assetName,
    Map<String, dynamic> docMap, {
    String? existingContent,
    List<LuminaInputAction> inputActions = const [],
    Map<String, BlueprintAnimClassRef> animBlueprints = const {},
    Map<String, BlueprintClassRef> blueprintClasses = const {},
    String? assetPath,
    LuminaBlueprintTypeContext? typeContext,
  }) {
    final rawName = assetName.replaceAll('.lmas', '');
    return const BlueprintDartGenerator().generate(
      LuminaBlueprintDocument.fromJson(docMap),
      className: DartCodeGeneratorService._sanitizeClassName(rawName),
      assetPath: assetPath ?? 'contents/blueprints/$rawName.lmas',
      inputActions: inputActions,
      existingContent: existingContent,
      animBlueprints: animBlueprints,
      blueprintClasses: blueprintClasses,
      typeContext: typeContext,
    );
  }

  /// The factories of the Blueprint actors [actorNames] (files in
  /// `lib/actors/`), assumed under `contents/blueprints/`.
  String generateActorRegistryDart(List<String> actorNames) => generateBlueprintRegistryDart([
        for (final name in actorNames)
          (file: dartFileStem(name), className: DartCodeGeneratorService._sanitizeClassName(name), assetPath: 'contents/blueprints/$name.lmas', gameMode: false),
      ]);

  /// `lib/actors/actors.g.dart`: every compiled Blueprint by
  /// its project-relative `.lmas` path — the actors as constructors that take
  /// a placed actor's key and transform (`luminaBlueprintFactories`), the
  /// GameMode Blueprints as game-mode factories (`luminaGameModeFactories`) —
  /// plus the actor classes by class name.
  String generateBlueprintRegistryDart(List<({String file, String className, String assetPath, bool gameMode})> entries) {
    final sorted = [...entries]..sort((a, b) => a.file.compareTo(b.file));
    final actors = sorted.where((e) => !e.gameMode).toList();
    final modes = sorted.where((e) => e.gameMode).toList();
    final b = StringBuffer();
    b.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    b.writeln('// Lumina Engine $kLuminaEngineVersion Blueprint class factories: every compiled');
    b.writeln('// Blueprint, by its project-relative .lmas path.');
    b.writeln('// ignore_for_file: unused_import');
    b.writeln();
    b.writeln("import 'package:flutter/foundation.dart' show Key;");
    b.writeln("import 'package:lumina/lumina_runtime.dart';");
    b.writeln("import 'package:vector_math/vector_math_64.dart';");
    for (final e in sorted) {
      b.writeln("import '${_escape(e.file)}.dart';");
    }
    b.writeln();
    b.writeln("/// A Blueprint actor class's constructor, as a level places it.");
    b.writeln('typedef LuminaBlueprintActorFactory = LuminaActor Function({Key? key, Vector3? location, Quaternion? rotation});');
    b.writeln();
    b.writeln('/// Every compiled Blueprint actor class, by its `.lmas` path.');
    b.writeln('final Map<String, LuminaBlueprintActorFactory> luminaBlueprintFactories = {');
    for (final e in actors) {
      b.writeln("  '${_escape(e.assetPath)}': ({key, location, rotation}) => "
          '${e.className}(key: key, location: location, rotation: rotation),');
    }
    b.writeln('};');
    b.writeln();
    b.writeln('/// Every compiled GameMode Blueprint, by its `.lmas` path.');
    b.writeln('final Map<String, LuminaGameMode Function()> luminaGameModeFactories = {');
    for (final e in modes) {
      b.writeln("  '${_escape(e.assetPath)}': () => ${e.className}(),");
    }
    b.writeln('};');
    b.writeln();
    b.writeln('/// The Blueprint actor classes by class name.');
    b.writeln('final Map<String, LuminaActor Function()> blueprintActorFactories = {');
    for (final e in actors) {
      b.writeln("  '${e.className}': () => ${e.className}(),");
    }
    b.writeln('};');
    return b.toString();
  }

  /// `lib/input/project_input.g.dart`: the project's input
  /// actions and mapping contexts (Project Settings > Input) as code, mapped
  /// exactly as `ProjectInputBinder.bind` maps them for Play. A generated game
  /// with Blueprint pawns adds them at startup; the pawns bind their actions
  /// from their own Enhanced Input event nodes.
  String generateProjectInputDart(ProjectInputSettings settings) {
    String valueType(ProjectInputValueType t) => switch (t) {
          ProjectInputValueType.axis1D => 'InputValueType.axis1D',
          ProjectInputValueType.axis2D => 'InputValueType.axis2D',
          ProjectInputValueType.digital => 'InputValueType.digitalBool',
        };
    final types = {for (final a in settings.actions) a.name: a.valueType};
    final b = StringBuffer();
    b.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    b.writeln("// Lumina Engine $kLuminaEngineVersion: the project's Enhanced Input (Project Settings > Input).");
    b.writeln('// ignore_for_file: prefer_const_constructors, unused_import');
    b.writeln();
    b.writeln("import 'package:lumina/lumina_runtime.dart';");
    b.writeln();
    b.writeln("/// The project's input actions, by name.");
    b.writeln('const Map<String, LuminaInputAction> luminaProjectInputActions = {');
    for (final a in settings.actions) {
      b.writeln("  '${_escape(a.name)}': LuminaInputAction('${_escape(a.name)}', valueType: ${valueType(a.valueType)}),");
    }
    b.writeln('};');
    b.writeln();
    b.writeln("/// Adds the project's mapping contexts to [input] for the player.");
    b.writeln('void luminaAddProjectInput(LuminaInputSubsystem input) {');
    var i = 0;
    for (final context in settings.mappingContexts) {
      final name = 'context${i++}';
      b.writeln('  // ${context.name.replaceAll(RegExp(r'[\r\n]'), ' ')}');
      b.writeln('  final $name = LuminaInputMappingContext();');
      for (final m in context.mappings) {
        final key = DartCodeGeneratorService._keyConstant(m.keyId);
        final type = types[m.action];
        if (key == null || type == null) {
          b.writeln('  // Unbound: ${(m.keyLabel.isEmpty ? '#${m.keyId}' : m.keyLabel).replaceAll(RegExp(r'[\r\n]'), ' ')} → ${m.action}');
          continue;
        }
        final action = "luminaProjectInputActions['${_escape(m.action)}']!";
        if (type == ProjectInputValueType.digital) {
          // Implicit Down, as ProjectInputBinder.
          b.writeln('  $name.mapKey(LuminaKey.$key, $action);');
        } else {
          final axis = m.axis.toUpperCase();
          final toX = axis == 'X' ? m.scale : 0.0;
          final toY = axis == 'Y' ? m.scale : 0.0;
          b.writeln('  $name.mapKey(LuminaKey.$key, $action, '
              'modifiers: const [LuminaAxisPlacementModifier(toX: ${_f(toX)}, toY: ${_f(toY)})]);');
        }
      }
      b.writeln('  input.addMappingContext($name, priority: ${context.priority});');
    }
    b.writeln('}');
    return b.toString();
  }

  /// Compiles a Blueprint document into the project's `lib/actors/` file
  /// (`BP_Door` → `lib/actors/bp_door.dart`, class `BpDoor`),
  /// typed against the project's input actions. Returns
  /// false, writing nothing, when the Blueprint has errors; skips the write
  /// when the output is unchanged; keeps the user-code region.
  Future<bool> compileAndWriteActor(String projectPath, String assetName, Map<String, dynamic> docMap,
      {String? assetPath, List<LuminaInputAction>? inputActions, LuminaBlueprintTypeContext? typeContext}) async {
    final rawName = assetName.split('/').last.replaceAll('.lmas', '');
    // Files an earlier version named after the asset move first, with their user code.
    LuminaGeneratedCodeMigration.migrate(projectPath);
    final file = File('$projectPath/lib/actors/${dartFileName(rawName)}');
    final document = LuminaBlueprintDocument.fromJson(docMap);
    // A GameMode Blueprint's Default Pawn Class is compiled
    // first; the game mode constructs it directly.
    final blueprintClasses = <String, BlueprintClassRef>{};
    final pawn = document.parentClass == 'LuminaGameMode' ? document.classDefaults['defaultPawnClass'] : null;
    if (pawn is String && pawn.isNotEmpty) {
      final pawnDoc = DartCodeGeneratorService._readPayload(projectPath, pawn);
      final parent = pawnDoc?['parentClass'];
      if (pawnDoc == null || (parent != 'LuminaPawn' && parent != 'LuminaCharacter')) return false;
      final pawnName = pawn.split('/').last.replaceAll('.lmas', '');
      if (!await compileAndWriteActor(projectPath, pawnName, pawnDoc, assetPath: pawn, inputActions: inputActions)) {
        return false;
      }
      blueprintClasses[pawn] = BlueprintClassRef(DartCodeGeneratorService._sanitizeClassName(pawnName), dartFileName(pawnName));
    }
    final animBlueprints = <String, BlueprintAnimClassRef>{};
    for (final c in document.components) {
      final animClass = c.properties['animClass'];
      if (c.properties['animMode'] != 'Use Animation Blueprint' || animClass is! String || animClass.isEmpty) continue;
      if (!File('$projectPath/$animClass').existsSync()) continue; // the generator warns
      final compiled = await compileAndWriteAnimBlueprint(projectPath, animClass);
      if (!compiled.ok) return false;
      animBlueprints[animClass] = compiled.ref!;
    }
    final existingContent = file.existsSync() ? await file.readAsString() : null;
    final result = generateBlueprintClass(rawName, docMap,
        existingContent: existingContent,
        inputActions: inputActions ?? DartCodeGeneratorService.projectInputActions(projectPath),
        animBlueprints: animBlueprints,
        blueprintClasses: blueprintClasses,
        assetPath: assetPath,
        typeContext: typeContext);
    if (!result.ok) return false;
    if (existingContent != result.code) {
      await file.parent.create(recursive: true);
      await file.writeAsString(result.code!);
    }
    await _updateProjectActorRegistry(projectPath);
    return true;
  }

  /// Compiles the Animation Blueprint stored at [assetPath] (relative to the
  /// project, e.g. `contents/animations/.../ABP_Character.lmas`) into the
  /// project's `lib/anim/`, with the blend spaces its states
  /// play read from their own `.lmas` files. Nothing is written when it has
  /// errors, and unchanged output is not rewritten. [ref] is the class a
  /// generated Blueprint in `lib/actors/` imports.
  Future<({bool ok, BlueprintAnimClassRef? ref, List<LuminaBlueprintDiagnostic> issues})> compileAndWriteAnimBlueprint(
      String projectPath, String assetPath) async {
    final document = DartCodeGeneratorService._readPayload(projectPath, assetPath);
    if (document == null) {
      return (
        ok: false,
        ref: null,
        issues: [LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.error, "Animation Blueprint '$assetPath' cannot be read.")],
      );
    }
    final anim = LuminaAnimBlueprintDocument.fromJson(document);
    final blendSpaces = <String, LuminaBlendSpaceDocument>{
      for (final machine in anim.stateMachines)
        for (final state in machine.states)
          if (state.pose.blendSpace != null)
            if (DartCodeGeneratorService._readPayload(projectPath, state.pose.blendSpace!) case final space?)
              state.pose.blendSpace!: LuminaBlendSpaceDocument.fromJson(space),
    };
    final rawName = assetPath.split('/').last.replaceAll('.lmas', '');
    LuminaGeneratedCodeMigration.migrate(projectPath);
    final file = File('$projectPath/lib/anim/${dartFileName(rawName)}');
    final existingContent = file.existsSync() ? await file.readAsString() : null;
    final className = DartCodeGeneratorService._sanitizeClassName(rawName);
    final result = const BlueprintDartGenerator().generateAnimBlueprint(anim,
        className: className, assetPath: assetPath, blendSpaces: blendSpaces, existingContent: existingContent);
    if (!result.ok) return (ok: false, ref: null, issues: result.issues);
    if (existingContent != result.code) {
      await file.parent.create(recursive: true);
      await file.writeAsString(result.code!);
    }
    return (ok: true, ref: BlueprintAnimClassRef(className, '../anim/${dartFileName(rawName)}'), issues: result.issues);
  }

  /// The project Blueprint classes a level's placed actors are:
  /// class → parent and class → custom events, read from their `.lmas`.
  @override
  ({Map<String, String> parents, Map<String, List<LuminaBlueprintCustomEvent>> events}) _levelActorClasses(
      List<Map<String, dynamic>> maps, String? projectDir) {
    final parents = <String, String>{};
    final events = <String, List<LuminaBlueprintCustomEvent>>{};
    if (projectDir == null) return (parents: parents, events: events);
    for (final a in maps) {
      final path = a['blueprintClass'];
      if (path is! String || path.isEmpty) continue;
      final file = File(path.startsWith('/') ? path : '$projectDir/$path');
      if (!file.existsSync()) continue;
      try {
        final payload = LuminaAsset.fromBytes(file.readAsBytesSync()).rawPayload;
        if (payload == null || payload.isEmpty) continue;
        final doc = LuminaBlueprintDocument.fromJson(Map<String, dynamic>.from(jsonDecode(utf8.decode(payload)) as Map));
        final name = path.split('/').last.replaceAll('.lmas', '');
        parents[name] = doc.parentClass;
        events[name] = LuminaBlueprintNodeLibrary.customEventsOf(doc.eventGraph);
      } catch (_) {
        continue;
      }
    }
    return (parents: parents, events: events);
  }

  Future<void> _updateProjectActorRegistry(String projectPath) async {
    final actorsDir = Directory('$projectPath/lib/actors');
    if (!actorsDir.existsSync()) return;
    final registryCode = generateBlueprintRegistryDart(_compiledActorEntries(projectPath));
    final registryFile = File('$projectPath/lib/actors/actors.g.dart');
    await registryFile.writeAsString(registryCode);
    // The project registry names every compiled class.
    writeProjectBlueprintRegistry(projectPath);
  }

  /// The Blueprint classes compiled into `lib/actors/` (their headers name
  /// the `.lmas` they came from).
  List<({String file, String className, String assetPath, bool gameMode})> _compiledActorEntries(String projectPath) {
    final actorsDir = Directory('$projectPath/lib/actors');
    if (!actorsDir.existsSync()) return const [];
    final header = RegExp(r'^// Blueprint (\S+), compiled by Lumina', multiLine: true);
    final declaration = RegExp(r'^class (\w+) extends (\w+)', multiLine: true);
    final entries = <({String file, String className, String assetPath, bool gameMode})>[];
    for (final f in actorsDir.listSync().whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('actors.g.dart')) continue;
      final name = f.path.split(Platform.pathSeparator).last.replaceAll('.dart', '');
      final source = f.readAsStringSync();
      final cls = declaration.firstMatch(source);
      final path = header.firstMatch(source)?.group(1);
      entries.add((
        file: name,
        className: cls?.group(1) ?? DartCodeGeneratorService._sanitizeClassName(name),
        assetPath: (path != null && path.endsWith('.lmas')) ? path : 'contents/blueprints/$name.lmas',
        gameMode: cls?.group(2) == 'LuminaGameMode',
      ));
    }
    entries.sort((a, b) => a.file.compareTo(b.file));
    return entries;
  }

  /// Writes the project's Blueprint assets as code:
  /// `lib/enums/<name>.g.dart` and `lib/interfaces/<name>.g.dart` (snake_case,
  /// [dartFileStem]) for every
  /// enum and interface asset (stale ones are removed), and
  /// `lib/blueprint_registry.g.dart` with `registerProjectBlueprints()` —
  /// the compiled actor classes, enums, interfaces, save-game classes,
  /// montages and particle templates the runtime resolves by name. Without
  /// any of those the registry file is deleted. Returns whether it exists.
  bool writeProjectBlueprintRegistry(String projectPath) {
    LuminaGeneratedCodeMigration.migrate(projectPath);
    final assets = LuminaProjectBlueprintAssets.scan(projectPath);
    final lib = Directory('$projectPath/lib');
    void sync(String folder, Map<String, String> files) {
      final dir = Directory('${lib.path}/$folder');
      if (dir.existsSync()) {
        for (final f in dir.listSync().whereType<File>()) {
          final name = f.uri.pathSegments.last;
          if (name.endsWith('.g.dart') && !files.containsKey(name)) f.deleteSync();
        }
      }
      if (files.isEmpty) return;
      dir.createSync(recursive: true);
      for (final e in files.entries) {
        final file = File('${dir.path}/${e.key}');
        if (!file.existsSync() || file.readAsStringSync() != e.value) file.writeAsStringSync(e.value);
      }
    }

    const generator = BlueprintDartGenerator();
    sync('enums', {
      for (final e in assets.enums) '${dartFileStem(e.document.name)}.g.dart': generator.generateEnum(e.document, assetPath: e.path),
    });
    sync('interfaces', {
      for (final i in assets.interfaces)
        '${dartFileStem(i.document.name)}.g.dart': generator.generateInterface(i.document, assetPath: i.path),
    });
    final actors = [
      for (final e in _compiledActorEntries(projectPath))
        if (!e.gameMode) (name: e.assetPath.split('/').last.replaceAll('.lmas', ''), assetPath: e.assetPath),
    ];
    final registry = File('${lib.path}/${DartCodeGeneratorService.blueprintRegistryFileName}');
    if (actors.isEmpty && !assets.hasRegistryAssets) {
      if (registry.existsSync()) registry.deleteSync();
      return false;
    }
    final code = generateProjectBlueprintRegistryDart(assets, actorClasses: actors);
    if (!registry.existsSync() || registry.readAsStringSync() != code) {
      lib.createSync(recursive: true);
      registry.writeAsStringSync(code);
    }
    return true;
  }

  /// `lib/blueprint_registry.g.dart`: `registerProjectBlueprints()`
  /// fills `LuminaBlueprintActorClasses` (from `actors/actors.g.dart`'s
  /// factories, by class name), `LuminaBlueprintEnums` /
  /// `LuminaBlueprintInterfaces` (the generated types' documents),
  /// `LuminaBlueprintSaveGameClasses`, `LuminaBlueprintMontages` (by name and
  /// path) and `LuminaBlueprintParticleTemplates` (by path). Plain
  /// registrations: no file or `dart:io` access at run time.
  String generateProjectBlueprintRegistryDart(LuminaProjectBlueprintAssets assets,
      {List<({String name, String assetPath})> actorClasses = const []}) {
    final b = StringBuffer();
    b.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    b.writeln('// Lumina Engine $kLuminaEngineVersion: every Blueprint asset the runtime resolves by name,');
    b.writeln('// registered by main() before the game starts.');
    b.writeln('// ignore_for_file: unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables');
    b.writeln();
    b.writeln("import 'package:lumina/lumina_runtime.dart';");
    b.writeln();
    if (actorClasses.isNotEmpty) b.writeln("import 'actors/actors.g.dart';");
    for (final e in assets.enums) {
      b.writeln("import 'enums/${dartFileStem(e.document.name)}.g.dart';");
    }
    for (final i in assets.interfaces) {
      b.writeln("import 'interfaces/${dartFileStem(i.document.name)}.g.dart';");
    }
    if (actorClasses.isNotEmpty || assets.enums.isNotEmpty || assets.interfaces.isNotEmpty) b.writeln();
    b.writeln("/// Registers the project's Blueprint classes, enums, interfaces, save-game");
    b.writeln('/// classes, montages and particle templates with the runtime.');
    b.writeln('void registerProjectBlueprints() {');
    if (actorClasses.isNotEmpty) {
      b.writeln('  // Spawn Actor from Class: every compiled Blueprint actor class, by name.');
      b.writeln('  LuminaBlueprintActorClasses.registerAll({');
      for (final a in actorClasses) {
        b.writeln('    ${DartCodeGeneratorService._dartString(a.name)}: () => luminaBlueprintFactories[${DartCodeGeneratorService._dartString(a.assetPath)}]!(),');
      }
      b.writeln('  });');
    }
    if (assets.enums.isNotEmpty) {
      b.writeln('  LuminaBlueprintEnums.registerAll(const [');
      for (final e in assets.enums) {
        b.writeln('    ${BlueprintDartGenerator.typeNameOf(e.document.name)}.document,');
      }
      b.writeln('  ]);');
    }
    if (assets.interfaces.isNotEmpty) {
      b.writeln('  LuminaBlueprintInterfaces.registerAll(const [');
      for (final i in assets.interfaces) {
        b.writeln('    ${BlueprintDartGenerator.typeNameOf(i.document.name)}.document,');
      }
      b.writeln('  ]);');
    }
    if (assets.saveGameClasses.isNotEmpty) {
      b.writeln('  LuminaBlueprintSaveGameClasses.registerAll([');
      for (final c in assets.saveGameClasses) {
        b.writeln('    // ${c.path}');
        b.writeln('    LuminaBlueprintSaveGameDocument.fromJson(${DartCodeGeneratorService._dartLiteral(c.document.toJson())}),');
      }
      b.writeln('  ]);');
    }
    for (final m in assets.montages) {
      b.writeln('  LuminaBlueprintMontages.register(LuminaBlueprintMontageDocument.fromJson(${DartCodeGeneratorService._dartLiteral(m.document.toJson())}),');
      b.writeln('      path: ${DartCodeGeneratorService._dartString(m.path)});');
    }
    for (final p in assets.particleTemplates) {
      b.writeln('  LuminaBlueprintParticleTemplates.register(${DartCodeGeneratorService._dartString(p.path)},');
      b.writeln('      LuminaParticleEmitterConfig.fromJson(${DartCodeGeneratorService._dartLiteral(p.config)}));');
    }
    b.writeln('}');
    return b.toString();
  }
}
