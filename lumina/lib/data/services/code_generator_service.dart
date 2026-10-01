import 'dart:convert';
import 'dart:io';
import '../../data/models/lumina_asset.dart';
import '../models/lumina_project.dart';
import 'level_template_service.dart' show kWorldPartitionDefaultCellSize, kWorldPartitionDefaultLoadingRange;
import '../../src/game/primitive_actor.dart' show luminaPrimitiveSize;
import '../../src/game/template_character.dart';
import '../../src/game/template_content.dart';
import '../../src/collision/collision_hull.dart';
import '../../src/components/camera/camera_settings.dart' show LuminaCameraSettings;
import '../../src/collision/collision_primitive.dart';
import '../../src/components/environment/exponential_height_fog_component.dart' show LuminaHeightFogSettings;
import '../../src/components/light/auto_exposure.dart' show luminaLightColorFromHex;
import '../../src/math/axes.dart';
import '../../src/math/units.dart';
import '../../src/blueprint/blueprint.dart';
import '../../src/input/input_action.dart';
import '../../src/input/input_key.dart';
import 'blueprint_codegen/blueprint_dart_generator.dart';
import 'blueprint_project_assets.dart';
import 'dart_identifiers.dart';
import 'generated_code_migration.dart';
import 'level_actor_material.dart';
import 'level_asset_manifest.dart';
import 'mesh_collision_service.dart';
import 'project_input_binder.dart';
import '../repositories/level_repository.dart';

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
    final gameHost = shadcn
        ? 'shadcn.ShadcnLayer(theme: shadcn.ThemeData.dark(), child: _GameHost())'
        : '_GameHost()';
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
    return """
// GENERATED CODE - DO NOT MODIFY BY HAND
// Lumina Engine $kLuminaEngineVersion Auto-Generated Launcher
// ignore_for_file: unused_import

import 'dart:async';
import 'dart:io' show Platform, exit;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lumina/lumina_runtime.dart';
$shadcnImport$levelImports
$blueprintImport$inputImport$functionsImport$widgetsImport$registryImport$modeImport
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class MyLuminaGameApp extends StatelessWidget {
  const MyLuminaGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${_escape(projectName)}',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const Scaffold(body: $gameHost),
    );
  }
}

/// Bridges Flutter keyboard and mouse events into the running world's
/// [LuminaInputSubsystem], so the keys bound by the project's `Gameplay`
/// mapping context actually reach the possessed pawn.
class _GameHost extends StatefulWidget {
  const _GameHost();

  @override
  State<_GameHost> createState() => _GameHostState();
}

class _GameHostState extends State<_GameHost> {
  $gameClass _game = $gameClass();
  final FocusNode _focusNode = FocusNode();
  StreamSubscription<MouseCaptureEvent>? _mouseEvents;
  MouseCaptureSupport? _captureSupport;
  bool _isCaptured = false;
  bool _captureInFlight = false;
  // Whether a capture ever succeeded: until then the pointer arriving over
  // the game retries it.
  bool _hadLock = false;
  // Player 0's controller and whether it wants a free, visible pointer
  // (Set Show Mouse Cursor, a UI input mode).
  LuminaPlayerController? _followedController;
  bool _freeCursor = false;

  LuminaInputSubsystem? get _input => _game.world?.getSubsystem<LuminaInputSubsystem>();

  @override
  void initState() {
    super.initState();
    // Change Level swaps the game for a new one on that
    // level, after the tick that asked for it and after preloading it; Open
    // Level (a Blueprint node, or the console's `open`) is a Change Level
    // nobody waits for.
    LuminaGame.onChangeLevelRequested = _changeLevel;
    LuminaGame.onOpenLevelRequested = (levelName, options) => scheduleMicrotask(() => _openLevel(levelName));
    _initMouseCapture();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _capture(_centre());
    });
    WidgetsBinding.instance.addPostFrameCallback(_followController);
  }

  /// After every frame: follow player 0's controller of the running game
  /// (it appears after BeginPlay, and Open Level brings a new one).
  void _followController(Duration _) {
    if (!mounted) return;
    final world = _game.world;
    final controller = world == null ? null : LuminaGameplayStatics.getPlayerController(world, playerIndex: 0);
    if (!identical(controller, _followedController)) {
      _followedController?.cursorState.removeListener(_onCursorState);
      _followedController = controller;
      controller?.cursorState.addListener(_onCursorState);
      _onCursorState();
    }
    WidgetsBinding.instance.addPostFrameCallback(_followController);
  }

  /// The game shows the cursor or gives input to its UI: the pointer is free
  /// and visible; when it hides the cursor again, the game takes it back.
  void _onCursorState() {
    final free = _followedController?.wantsFreeCursor ?? false;
    if (free == _freeCursor || !mounted) return;
    setState(() => _freeCursor = free);
    if (free) {
      _isCaptured = false;
      LuminaMouseCapture.backend.release();
    } else {
      _capture(_centre());
    }
  }

  Future<void> _initMouseCapture() async {
    final backend = LuminaMouseCapture.backend;
    _mouseEvents = backend.events.listen((event) {
      if (event is MouseCaptureMotion) {
        final input = _input;
        if (input != null) {
          input.injectAnalog(LuminaKey.mouseX, event.dx);
          input.injectAnalog(LuminaKey.mouseY, event.dy);
        }
      } else if (event is MouseCaptureLocked) {
        _isCaptured = true;
        _hadLock = true;
      } else if (event is MouseCaptureLost) {
        _isCaptured = false;
      }
    });
    _captureSupport = await backend.support();
  }

  void _openLevel(String levelName) {
    _changeLevel(levelName).catchError((Object e) => debugPrint('Open Level: \$e'));
  }

  /// Switches to [levelName] once it is preloaded (at once when Load Level
  /// preloaded it already); completes after the new level's BeginPlay.
  Future<void> _changeLevel(String levelName) async {
    if (!_projectLevels.containsKey(levelName)) {
      throw StateError("Change Level: no level named '\$levelName' in this game.");
    }
    await LuminaLevelPreloader.instance.changeLevel(levelName, () async {
      if (!mounted) throw StateError('Change Level: the game is closing.');
      final game = $gameClass(levelName: levelName);
      setState(() => _game = game);
      while (mounted && !(game.world?.hasBegunPlay ?? false)) {
        await WidgetsBinding.instance.endOfFrame;
      }
    });
  }

  Offset? _centre() {
    final box = context.findRenderObject() as RenderBox?;
    final size = box?.size;
    return size != null ? Offset(size.width / 2, size.height / 2) : null;
  }

  /// Captures the pointer; a capture the platform refuses (on Wayland the
  /// window has no pointer until the pointer enters it) leaves the game
  /// uncaptured, so hover keeps turning the view and the next try can run.
  Future<void> _capture([Offset? centre]) async {
    if (_captureInFlight) return;
    _captureInFlight = true;
    try {
      final ok = await LuminaMouseCapture.backend.capture(centre: centre);
      if (!mounted) return;
      _isCaptured = ok;
      if (ok) _hadLock = true;
    } finally {
      _captureInFlight = false;
    }
  }

  /// Until one capture has succeeded, the pointer entering or moving over
  /// the game tries again; after a loss (focus went elsewhere) a click takes
  /// the pointer back.
  void _captureUntilFirstLock() {
    if (_hadLock || _captureInFlight || _freeCursor) return;
    _capture(_centre());
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    // Every keyboard key, through the engine's one key table.
    final key = LuminaKey.fromKeyId(event.logicalKey.keyId);
    final input = _input;
    if (key == null || input == null) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      input.injectKeyDown(key);
    } else if (event is KeyUpEvent) {
      input.injectKeyUp(key);
    }
    return KeyEventResult.handled;
  }

  void _onPointerDelta(PointerEvent event) {
    _captureUntilFirstLock();
    // Captured with relative motion, the backend's deltas turn the view;
    // otherwise the pointer's own deltas do.
    if (_isCaptured && _captureSupport?.relativeMotion == true) return;
    final input = _input;
    if (input == null) return;
    input.injectAnalog(LuminaKey.mouseX, event.delta.dx);
    input.injectAnalog(LuminaKey.mouseY, event.delta.dy);
  }

  @override
  void dispose() {
    LuminaGame.onOpenLevelRequested = null;
    _followedController?.cursorState.removeListener(_onCursorState);
    LuminaGame.onChangeLevelRequested = null;
    _mouseEvents?.cancel();
    LuminaMouseCapture.backend.release();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: MouseRegion(
        // The game owns the mouse: pointer lock and relative motion keep it
        // from escaping the window while turning.
        cursor: _freeCursor ? SystemMouseCursors.basic : SystemMouseCursors.none,
        onEnter: (_) => _captureUntilFirstLock(),
        onHover: _onPointerDelta,
        child: Listener(
          onPointerDown: (event) {
            _focusNode.requestFocus();
            if (!_isCaptured && !_freeCursor) _capture(_centre());
          },
          onPointerMove: _onPointerDelta,
          // The widgets the game's Blueprints add to the viewport (Create
          // Widget → Add to Viewport) render above the 3D view.
          // A new game (Open Level) mounts a fresh 3D view and widget layer.
          child: KeyedSubtree(
            key: ObjectKey(_game),
            child: Stack(
              fit: StackFit.expand,
              children: [
                LuminaGameWidget(game: _game),
                LuminaWidgetLayer.forGame(game: _game),
              ],
            ),
          ),
        ),
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
