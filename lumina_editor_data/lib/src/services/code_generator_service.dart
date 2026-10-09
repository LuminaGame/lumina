import 'dart:convert';
import 'dart:io';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_editor_data/src/services/blueprint_codegen/blueprint_dart_generator.dart';
import 'package:lumina_editor_data/src/services/blueprint_project_assets.dart';
import 'package:lumina_editor_data/src/services/mesh_collision_service.dart';

part 'code_generator_service/state.dart';
part 'code_generator_service/level.dart';
part 'code_generator_service/character_and_game_mode.dart';
part 'code_generator_service/blueprints_and_registries.dart';
part 'code_generator_service/literals.dart';

class DartCodeGeneratorService extends _DartCodeGeneratorServiceState
    with
        _LevelCodegen,
        _CharacterAndGameModeCodegen,
        _BlueprintsAndRegistriesCodegen {
  /// [gameModeClass] / [gameModeImport] come from
  /// [ProjectMapsAndModes.defaultGameMode]: when the manifest names a template
  /// game mode the emitted [LuminaGame] installs it on the world, otherwise the
  /// plain engine default is used.
  String generateMainDart({
    required String projectName,
    String levelName = 'L_DefaultLevel',
    String? gameModeClass,
    String? gameModeImport,
    String widgetLibrary = kUmgWidgetLibraryFlutter,
    double gravityZ = -980.0,
    ProjectMapsAndModes? mapsAndModes,
    bool hasBlueprints = false,
    bool projectInput = false,
    bool blueprintFunctions = false,
    bool widgetClasses = false,
    bool blueprintRegistry = false,
    List<String> levelNames = const [],
    int targetFps = 0,
    bool vsyncEnabled = false,
    bool startFullscreen = false,
  }) {
    // Every level the game can Open Level to, by authored name
    // (`L_Main` → `levels/l_main.dart`, class `LMain`).
    final levels = <String>{levelName, ...levelNames.where((n) => RegExp('[A-Za-z0-9]').hasMatch(n))}.toList();
    final levelImports = [for (final l in levels) "import 'levels/${dartFileName(l)}';"].join('\n');
    final levelTable = [for (final l in levels) "  '${_escape(l)}': () => ${dartTypeName(l)}(),"].join('\n');
    final manifestTable = [for (final l in levels) "  '${_escape(l)}': ${dartTypeName(l)}.assetManifest,"].join('\n');
    // The registries Spawn Actor from Class, Switch on Enum,
    // interface messages, save classes, montages and emitters resolve through.
    final registryImport = blueprintRegistry ? "import 'blueprint_registry.g.dart';\n" : '';
    final registerBlueprints = blueprintRegistry ? '  registerProjectBlueprints();\n' : '';
    // A GameMode Blueprint and the Maps & Modes Default Pawn
    // Class resolve through the compiled Blueprint factories.
    final modeBlueprint = (mapsAndModes?.gameModeIsBlueprint ?? false) ? mapsAndModes!.defaultGameMode : null;
    final pawnClass = mapsAndModes?.defaultPawnClass ?? '';
    final importsBlueprints = hasBlueprints || modeBlueprint != null || pawnClass.isNotEmpty;
    // Shadcn widgets need a shadcn Theme and overlay handlers above them.
    final shadcn = widgetLibrary == kUmgWidgetLibraryShadcn;
    final shadcnImport = shadcn ? "import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;\n" : '';
    // The game screen (lumina_widgets): the 3D view, the widget layer and the
    // keyboard / pointer / mouse-capture bridge into the world; Open Level
    // starts a new game from _createGame.
    final levelSet = [for (final l in levels) "'${_escape(l)}'"].join(', ');
    final host = 'LuminaGameHost(\n'
        "          initialLevel: '${_escape(levelName)}',\n"
        '          levelNames: {$levelSet},\n'
        '          createGame: _createGame,\n'
        '          targetFps: $targetFps,\n'
        '          vsyncEnabled: $vsyncEnabled,\n'
        '        )';
    final gameHost = shadcn ? 'shadcn.ShadcnLayer(theme: shadcn.ThemeData.dark(), child: $host)' : host;
    final gameClass = '${_sanitizeClassName(projectName)}Game';
    final modeClass = (gameModeClass == null || gameModeClass.isEmpty) ? 'LuminaGameMode' : gameModeClass;
    final modeImport = (modeBlueprint != null || gameModeImport == null || gameModeImport.isEmpty)
        ? ''
        : "import '${_escape(gameModeImport)}';\n";
    final blueprintImport = importsBlueprints ? "import 'actors/actors.g.dart';\n" : '';
    // Blueprint pawns bind their actions from their own graphs;
    // the project's mapping contexts come from lib/input/project_input.g.dart.
    final inputImport = projectInput ? "import 'input/project_input.g.dart';\n" : '';
    final registerInput = projectInput
        ? 'luminaAddProjectInput(world.registerSubsystem(LuminaInputSubsystem()));'
        : 'world.registerSubsystem(LuminaInputSubsystem());';
    // The project's @BlueprintCallable / @BlueprintPure functions,
    // registered for the Blueprint VM before the world starts.
    final functionsImport = blueprintFunctions ? "import 'blueprint/blueprint_functions.g.dart';\n" : '';
    final registerFunctions = blueprintFunctions ? '  registerProjectBlueprintFunctions();\n' : '';
    // The compiled widget classes (lib/widgets/widget_registry.g.dart)
    // are registered before the world starts, so Create Widget seeds their
    // elements and the LuminaWidgetLayer over the game can build them.
    final widgetsImport = widgetClasses ? "import 'widgets/widget_registry.g.dart';\n" : '';
    final registerWidgets = widgetClasses ? '  registerProjectWidgetClasses();\n' : '';
    final modeCreate = modeBlueprint != null ? "luminaGameModeFactories['${_escape(modeBlueprint)}']!()" : '$modeClass()';
    final modeExpr = pawnClass.isEmpty
        ? modeCreate
        : "($modeCreate..defaultPawnFactory = () => luminaBlueprintFactories['${_escape(pawnClass)}']!() as LuminaPawn)";
    // The window mode: the runner opens the window in the project's Start
    // Fullscreen mode; the player's own choice (Alt+Enter, F11, Set
    // Fullscreen Mode), kept next to the save games, is put back before the
    // first frame.
    final startMode = startFullscreen ? 'LuminaWindowMode.borderlessFullscreen' : 'LuminaWindowMode.windowed';
    return """
// GENERATED CODE - DO NOT MODIFY BY HAND
// Lumina Engine $kLuminaEngineVersion Auto-Generated Launcher
// ignore_for_file: unused_import

import 'dart:async';
import 'dart:io' show Platform, exit;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '$kLuminaGameLibrary';
$shadcnImport$levelImports
$blueprintImport$inputImport$functionsImport$widgetsImport$registryImport$modeImport
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The engine's Flutter services: platform, asset bundle, video player.
  LuminaWidgets.ensureInitialized();
$registerFunctions$registerWidgets$registerBlueprints  // Every asset the level names is read from the app bundle (pubspec.yaml
  // bundles contents/), so the same game runs on desktop and on the web.
  LuminaAssets.defaultProvider = (path) async {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  };
  // Load Level / Change Level preload a level from its generated asset
  // manifest, never by scanning the bundle.
  LuminaLevelPreloader.instance.manifestResolver = (levelName) => _projectLevelManifests[levelName];
  // Save Game to Slot writes to the platform's app-support directory.
  LuminaSaveGameSubsystem.defaultSaveDirectoryPath =
      LuminaSaveGameSubsystem.platformSaveDirectory('${_escape(projectName)}') ?? LuminaSaveGameSubsystem.defaultSaveDirectoryPath;
  // Windowed or borderless fullscreen (Project Settings > Start Fullscreen,
  // then the player's last choice); Alt+Enter and F11 toggle.
  await LuminaGameWindow.restore(
    startMode: $startMode,
    settingsFilePath: LuminaGameWindow.settingsFileFor(LuminaSaveGameSubsystem.defaultSaveDirectoryPath),
  );
  // Quit Game (a Blueprint node, or the console's `quit`) closes the game.
  LuminaGame.onQuitRequested = () {
    if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) exit(0);
    SystemNavigator.pop();
  };
  // Web builds: the renderer and the bundled assets load behind the page's
  // loading screen (Project Settings > Web Loading Style), which shows their
  // progress. Native builds go straight on.
  await LuminaWebLoading.prepareGame();
  runApp(const MyLuminaGameApp());
}

/// The levels Open Level can load, by name.
final Map<String, LuminaLevel Function()> _projectLevels = {
$levelTable
};

/// What each level loads, by name: what Load Level preloads.
final Map<String, List<LuminaAssetRef>> _projectLevelManifests = {
$manifestTable
};

/// The game: a declarative world that plays [levelName], `$levelName` first.
class $gameClass extends LuminaGame {
  $gameClass({this.levelName = '${_escape(levelName)}'});

  /// The level this game plays; Open Level starts a new game on another one.
  final String levelName;

  @override
  LuminaObject? build(LuminaBuildContext context) {
    final world = context.world;
    if (world != null) {
      if (world.getSubsystem<LuminaCollisionSubsystem>() == null) {
        world.registerSubsystem(LuminaCollisionSubsystem());
      }
      if (world.getSubsystem<LuminaInputSubsystem>() == null) {
        $registerInput
      }
      world.gameMode ??= $modeExpr;
      // Project Settings > Physics (cm/s², authoring Z-up).
      world.gravityZ = ${_f(gravityZ)};
    }
    // The level's actors mount straight into the world's persistent level
    // (and its script actor alongside them) so beginPlay, the tick pipeline
    // and the game mode's player-start search all see them.
    final level = (_projectLevels[levelName] ?? _projectLevels['${_escape(levelName)}']!)();
    final levelScript = level.scriptActor;
    // The level's script is the world's: told Level Loaded before any
    // actor's BeginPlay, its Level Blueprint included.
    if (world != null && levelScript != null) world.persistentLevel.scriptActor = levelScript;
    return LuminaNodeGroup(children: [
      ...?level.build(context)?.children,
      if (levelScript != null) levelScript,
    ]);
  }
}

/// The game for [levelName]: what the game host starts first and on every
/// Open Level / Change Level.
$gameClass _createGame(String levelName) => $gameClass(levelName: levelName);

class MyLuminaGameApp extends StatelessWidget {
  const MyLuminaGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${_escape(projectName)}',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      // The keys bound by the project's `Gameplay` mapping context reach the
      // possessed pawn through the host's keyboard and mouse bridge.
      home: const Scaffold(
        body: $gameHost,
      ),
    );
  }
}
""";
  }

  /// Editor fog/bloom sliders are authored in metres / 0–8 while levels are in
  /// centimetres; mirrors `EnvironmentState.toPostProcessSettings` in the editor.
  static const double _worldUnitsPerMetre = LuminaUnits.unitsPerMetre;
  static const double _bloomIntensityMax = 8.0;

  /// The `LuminaKey` constant a manifest key id names (any
  /// keyboard key, the mouse / gamepad sentinels), or null for an unknown id.
  /// Every constant is its id with a lower-case first letter (`KeyV` →
  /// `keyV`, `MouseX` → `mouseX`).
  static String? _keyConstant(int keyId) {
    final key = LuminaKey.fromKeyId(keyId);
    if (key == null) return null;
    return '${key.id[0].toLowerCase()}${key.id.substring(1)}';
  }

  /// The JSON document in the `.lmas` at [assetPath]'s `raw_payload`.
  static Map<String, dynamic>? _readPayload(String projectPath, String assetPath) {
    final file = File('$projectPath/$assetPath');
    if (!file.existsSync()) return null;
    try {
      final payload = LuminaAsset.fromBytes(file.readAsBytesSync()).rawPayload;
      if (payload == null) return null;
      final decoded = jsonDecode(utf8.decode(payload));
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  /// The project's input actions from its `.lmproject` manifest.
  static List<LuminaInputAction> projectInputActions(String projectPath) {
    final dir = Directory(projectPath);
    if (!dir.existsSync()) return const [];
    for (final f in dir.listSync().whereType<File>()) {
      if (!f.path.endsWith('.lmproject')) continue;
      try {
        final project = LuminaProject.fromMap(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>);
        return ProjectInputBinder.bind(project.input).actions.values.toList();
      } catch (_) {
        return const [];
      }
    }
    return const [];
  }

  // --- Project Blueprint registry -----------------------------

  /// The file [writeProjectBlueprintRegistry] writes, relative to `lib/`.
  static const String blueprintRegistryFileName = 'blueprint_registry.g.dart';

  /// `E_DoorState` → `e_door_state`, `BPI_Interactable` → `bpi_interactable`:
  /// the file names of generated enum and interface sources.
  static String snakeCaseFileName(String name) {
    final b = StringBuffer();
    for (var i = 0; i < name.length; i++) {
      final c = name[i];
      final isUpper = c.toUpperCase() == c && c.toLowerCase() != c;
      if (isUpper && i > 0) {
        final prev = name[i - 1];
        final prevLower = prev.toLowerCase() == prev && prev.toUpperCase() != prev || RegExp(r'[0-9]').hasMatch(prev);
        final nextLower = i + 1 < name.length && name[i + 1].toLowerCase() == name[i + 1] && name[i + 1].toUpperCase() != name[i + 1];
        final prevUpper = prev.toUpperCase() == prev && prev.toLowerCase() != prev;
        if (prevLower || (prevUpper && nextLower)) b.write('_');
      }
      b.write(RegExp(r'[A-Za-z0-9]').hasMatch(c) ? c.toLowerCase() : '_');
    }
    return b.toString().replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
  }

  /// JSON-plain data as a Dart literal (`<String, dynamic>{…}`, `<dynamic>[…]`).
  static String _dartLiteral(Object? value) {
    if (value == null || value is bool || value is int) return '$value';
    if (value is double) return value.isFinite ? '$value' : '0.0';
    if (value is List) return '<dynamic>[${value.map(_dartLiteral).join(', ')}]';
    if (value is Map) {
      return '<String, dynamic>{${value.entries.map((e) => '${_dartString('${e.key}')}: ${_dartLiteral(e.value)}').join(', ')}}';
    }
    return _dartString('$value');
  }

  /// [v] as a single-quoted Dart string literal (no interpolation).
  static String _dartString(String v) =>
      "'${v.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('\$', '\\\$').replaceAll('\n', '\\n').replaceAll('\r', '\\r')}'";

  /// The Dart class generated for the asset or project [name]
  /// ([dartTypeName]: `BP_Door` → `BpDoor`).
  static String _sanitizeClassName(String name) => dartTypeName(name, fallback: 'Lumina');

  /// The authored names of the levels generated into [projectDir]'s
  /// `lib/levels/` (the name each file's level passes to `LuminaLevel`),
  /// sorted: the levels `lib/main.dart` lists for Open Level. Generated
  /// files of earlier versions are migrated first
  /// ([LuminaGeneratedCodeMigration]).
  static List<String> generatedLevelNames(String projectDir) {
    LuminaGeneratedCodeMigration.migrate(projectDir);
    final dir = Directory('$projectDir/lib/levels');
    if (!dir.existsSync()) return const [];
    final authored = RegExp(r"super\(name: '((?:[^'\\]|\\.)*)'");
    final names = <String>{};
    for (final f in dir.listSync().whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final stem = f.uri.pathSegments.last.replaceAll('.dart', '');
      String? name;
      try {
        name = authored.firstMatch(f.readAsStringSync())?.group(1)?.replaceAllMapped(RegExp(r'\\(.)'), (m) => m.group(1)!);
      } catch (_) {}
      // Only a level main.dart would import from this very file.
      if (name != null && dartFileStem(name) == stem) names.add(name);
    }
    return names.toList()..sort();
  }
}
