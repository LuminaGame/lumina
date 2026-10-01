import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show Listenable, ValueKey;
import 'package:flutter/services.dart';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/data/services/game_template_service.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_debugger.dart';
import 'package:vector_math/vector_math_64.dart' as vm64;

import '../../sub_editors/services/umg_widget_codegen.dart';
import '../../sub_editors/services/widget_class_catalog.dart';
import 'blueprint_play_support.dart';
import 'camera_actor_properties.dart';
import 'environment_actor_properties.dart';
import 'light_actor_properties.dart';
import 'pie_mouse_capture.dart';
import '../../details/services/blueprint_collision_overrides.dart';

part 'pie_controller/editor_pie_game.dart';

/// Ticks the local player's controller inside the world tick, ahead of the
/// pawn it possesses (the pawn is spawned later, so it ticks after this).
class _PieControllerDriver extends LuminaLevelScriptActor {
  final LuminaPlayerController controller;

  _PieControllerDriver(this.controller);

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    controller.onTick(deltaTime);
  }
}

class PieController {
  final EditorViewModel viewModel;
  EditorPieGame? _game;
  bool isPlaying = false;
  bool isPaused = false;
  bool isEjected = false;

  /// Last error raised while mounting or ticking the runtime world, or null.
  String? lastError;

  List<EditorActorNode>? _editorSnapshot;
  String? _selectedActorIdSnapshot;
  List<double>? _cameraSnapshot;

  PieController(this.viewModel);

  /// The game's hold on the mouse: captured from Play, F4
  /// releases it, a click on the game view takes it again, Esc stops Play.
  late final PieMouseCapture mouseCapture = PieMouseCapture(
    gameAcceptsInput: () => acceptsGameInput,
    gameWantsFreeCursor: () => _game?.playerController?.wantsFreeCursor ?? false,
    onMotion: injectMouseDelta,
  )..addListener(viewModel.notifyListeners);

  /// The possessed controller whose cursor state Play follows: Set Show Mouse Cursor / Set Input Mode free or take the
  /// pointer as the game runs.
  Listenable? _followedCursor;

  void _followCursorOf(EditorPieGame? game) {
    final next = game?.playerController?.cursorState;
    if (!identical(next, _followedCursor)) {
      _followedCursor?.removeListener(mouseCapture.sync);
      _followedCursor = next?..addListener(mouseCapture.sync);
    }
    mouseCapture.sync();
  }

  /// The mounted runtime game while playing, or null.
  EditorPieGame? get game => _game;

  /// The possessed character while playing, or null.
  LuminaTemplateCharacter? get playerPawn => _game?.playerPawn;

  /// Which pawn this project's template scaffolds, read from the manifest.
  GameTemplateKind templateKindForProject() =>
      GameTemplateCatalog.byId(viewModel.project.template).kind;

  /// The Third Person character mesh the project carries
  /// ([LuminaThirdPersonContent.projectMeshGlbPath]), or null — a
  /// project created before the template shipped it plays with no body.
  String? mannequinPathForProject() {
    final file = File('${viewModel.projectDirPath}/${LuminaThirdPersonContent.projectMeshGlbPath}');
    return file.existsSync() ? file.path : null;
  }

  /// The project's input actions and key bindings, bound to the runtime.
  ///
  /// A project created before the template work has no input section; it falls
  /// back to its template's defaults so Play still moves, and the user can then
  /// edit them in Project Settings.
  BoundProjectInput boundInputForProject() {
    final manifest = viewModel.project.input;
    final settings = manifest.mappingContexts.isEmpty
        ? GameTemplateCatalog.byId(viewModel.project.template).input
        : manifest;
    return ProjectInputBinder.bind(settings);
  }

  /// With [postProcessView] the Play world blends its post-process volumes
  /// and fog onto that view (post-processing only — the world never takes
  /// the view's camera), starting from [postProcessBaseline] (the editor
  /// viewport's baseline) so Play looks like the editor outside every volume.
  void startPie(
    FilamentEngine engine,
    FilamentScene scene, {
    FilamentView? postProcessView,
    LuminaPostProcessSettings? postProcessBaseline,
  }) {
    if (isPlaying) return;

    _editorSnapshot = viewModel.actors.map((a) => EditorActorNode.fromMap(a.toMap())).toList();
    _selectedActorIdSnapshot = viewModel.selectedActorId;
    _cameraSnapshot = [
      viewModel.cameraYaw,
      viewModel.cameraPitch,
      viewModel.cameraDistance,
      viewModel.cameraPanX,
      viewModel.cameraPanY,
      viewModel.cameraPanZ,
    ];

    isPlaying = true;
    isPaused = false;
    isEjected = false;
    lastError = null;

    viewModel.clearSelection();
    viewModel.transactions.isFrozen = true;

    final boundInput = boundInputForProject();
    _engine = engine;
    _scene = scene;
    _postProcessView = postProcessView;
    _postProcessBaseline = postProcessBaseline;
    _headless = false;
    _playingLevel = viewModel.project.activeLevel;
    _installHostHooks();
    _game = createGame(_editorSnapshot!, input: boundInput);
    try {
      _mountAndBeginPlay(_game!);
      _followCursorOf(_game);
      _publishDebugTargets();

      final pawn = _game!.playerPawn;
      final blueprintPawn = _game!.possessedPawn;
      if (pawn == null && blueprintPawn != null) {
        viewModel.logger.log(
          'PIE possessed ${_game!.pawnClassLabel} at (${blueprintPawn.actorLocation.x.toStringAsFixed(2)}, '
          '${blueprintPawn.actorLocation.y.toStringAsFixed(2)}, ${blueprintPawn.actorLocation.z.toStringAsFixed(2)})',
          level: 'success',
          source: 'PIE',
        );
      } else if (pawn != null) {
        final body = pawn.bodyMesh;
        viewModel.logger.log(
          'PIE possessed a ${pawn.thirdPerson ? 'third' : 'first'}-person character '
          'at (${pawn.actorLocation.x.toStringAsFixed(2)}, '
          '${pawn.actorLocation.y.toStringAsFixed(2)}, '
          '${pawn.actorLocation.z.toStringAsFixed(2)})'
          '${body != null ? ' playing ${body.meshAssetPath.split('/').last}' : ''}',
          level: 'success',
          source: 'PIE',
        );
      } else if (_game!.hasPlayerSession) {
        viewModel.logger.log(
          'PIE found no player start to spawn the template character at; '
          'the level plays with no player.',
          level: 'warning',
          source: 'PIE',
        );
      } else {
        viewModel.logger.log(
          'PIE is simulating: this project has no game mode template, so no pawn is spawned.',
          level: 'info',
          source: 'PIE',
        );
      }
      for (final key in boundInput.unboundKeys) {
        viewModel.logger.log(
          'Input key "$key" has no runtime equivalent and is not bound in PIE.',
          level: 'warning',
          source: 'PIE',
        );
      }
      _installKeyboardHandler();
      unawaited(mouseCapture.begin());
      viewModel.logger.log(
        'PIE started with ${_editorSnapshot!.length} actors',
        level: 'success',
        source: 'PIE',
      );
    } catch (e, st) {
      lastError = e.toString();
      _removeKeyboardHandler();
      _removeHostHooks();
      _followCursorOf(null);
      mouseCapture.end();
      viewModel.logger.log('PIE failed to mount runtime world: $e\n$st', level: 'error', source: 'PIE');
      _game = null;
      isPlaying = false;
      viewModel.transactions.isFrozen = false;
      _restoreEditorState();
      rethrow;
    }
  }

  // --- Blueprints in Play -----------------------------

  EditorBlueprintClassRegistry? _registry;

  /// The registry the next Play resolves Blueprint classes through: the
  /// project's `.lmas` files, with open Blueprint editors' documents as they
  /// are in the editor.
  EditorBlueprintClassRegistry get registry => _registry ??= EditorBlueprintClassRegistry(
        viewModel.projectDirPath,
        inputActions: boundInputForProject().actions.values.toList(),
        openDocuments: () => viewModel.openBlueprintDocuments,
      );

  /// Play's compile step without the editors: loads and validates every
  /// Blueprint class Play will use. Empty when Play can start.
  List<PlayBlocker> preflight({List<PlayBlocker>? warnings}) {
    _registry = null; // the manifest's input actions may have changed
    return BlueprintPlayPreflight.validate(
      registry,
      viewModel.project.mapsAndModes,
      [
        for (final a in viewModel.actors)
          if (a.blueprintClass != null && a.blueprintClass!.isNotEmpty) a.blueprintClass!,
      ],
      warnings: warnings,
    );
  }

  /// The game Play mounts for [actors] (the level snapshot) of [levelPath]
  /// (default: the level Play is running, else the editor's).
  EditorPieGame createGame(List<EditorActorNode> actors, {BoundProjectInput? input, String? levelPath}) {
    final templateKind = templateKindForProject();
    final logged = <String>{};
    registerWidgetClasses();
    registerWidgetScripts();
    registerBlueprintAssets();
    // Simulating components inherit their static mesh's
    // mass (the Static Mesh editor's `metadata.physics`), read fresh.
    final projectDir = viewModel.projectDirPath;
    LuminaBlueprintComponents.meshPhysicsResolver = (stored) => MeshPhysicsService.forMeshAsset(stored, projectDir: projectDir);
    // Blueprints name assets project-relative (a Set Material node's
    // `contents/materials/…`); Play reads them from this project.
    LuminaAssets.projectDir = projectDir;
    return EditorPieGame(
      actors,
      templateKind: templateKind,
      input: input ?? boundInputForProject(),
      mannequinMeshPath: templateKind == GameTemplateKind.thirdPerson ? mannequinPathForProject() : null,
      registry: registry,
      mapsAndModes: viewModel.project.mapsAndModes,
      onBlueprintInstance: (instance) => _attachProjectCodeNotice(instance, logged),
      levelScript: levelScriptFor(levelPath ?? _playingLevel ?? viewModel.project.activeLevel, actors),
    );
  }

  /// The script of [levelPath]'s Level Blueprint over
  /// the placed [actors], or null when the level has none. One with compile
  /// errors does not run; the Output Log names them.
  LuminaBlueprintLevelScript? levelScriptFor(String levelPath, List<EditorActorNode> actors) {
    if (levelPath.isEmpty) return null;
    final cls = registry.levelClassFor(levelPath, actorMaps: [for (final a in actors) a.toMap()]);
    if (cls == null) return null;
    if (cls.hasErrors) {
      viewModel.logger.log(
        'The Level Blueprint of ${cls.name} has errors and does not run: '
        '${cls.diagnostics.where((d) => d.isError).map((d) => d.message).join('; ')}',
        level: 'warning',
        source: 'PIE',
      );
      return null;
    }
    viewModel.logger.log('Level Blueprint of ${cls.name} runs in Play', level: 'info', source: 'PIE');
    return cls.instantiateLevelScript(key: ValueKey('${cls.name}_script'));
  }

  /// Makes the project's widget Blueprints known to the runtime before Play:
  /// `Create Widget` seeds each instance's per-element
  /// state (`elements.FPSCounter.text`) from the class registered here, read
  /// fresh from the `.lmas` files so the designer's last save is what plays.
  void registerWidgetClasses() {
    final classes = WidgetClassCatalog.scanWidgetClasses(viewModel.projectDirPath);
    LuminaWidgetClassRegistry.registerAll(classes);
    if (classes.isNotEmpty) {
      viewModel.logger.log(
        'Registered ${classes.length} widget class${classes.length == 1 ? '' : 'es'}: ${classes.map((c) => c.name).join(', ')}',
        level: 'info',
        source: 'PIE',
      );
    }
  }

  /// Every widget graph plays in the VM (an open designer's
  /// as it is in the editor, the others as saved) — `Create
  /// Widget` gives each instance a `LuminaBlueprintUserWidget` over it, as the
  /// built game's registry gives it the compiled `WBP<Name>Graph`. A graph
  /// with errors does not run; the Output Log names them.
  void registerWidgetScripts() {
    LuminaUserWidgets.clear();
    final input = boundInputForProject().actions.values.toList();
    final names = <String>[];
    final documents = UmgWidgetCodegen.widgetDocuments(viewModel.projectDirPath);
    for (final open in viewModel.openWidgetEditors) {
      if (open.isLoaded) documents[UmgWidgetCodegen.fileBaseName(open.fileBasename)] = open.documentForPlay;
    }
    for (final e in documents.entries) {
      final graph = UmgWidgetCodegen.widgetGraphOf(e.value, e.key);
      if (graph == null) continue;
      final cls = LuminaBlueprintClass.forWidget(graph, inputActions: input);
      if (cls.hasErrors) {
        viewModel.logger.log(
          'The graph of ${e.key} has errors and does not run: ${cls.diagnostics.where((d) => d.isError).map((d) => d.message).join('; ')}',
          level: 'warning',
          source: 'PIE',
        );
        continue;
      }
      LuminaUserWidgets.register(e.key, cls.instantiateUserWidget);
      names.add(e.key);
    }
    if (names.isNotEmpty) {
      viewModel.logger.log('Widget graphs run in Play: ${names.join(', ')}', level: 'info', source: 'PIE');
    }
  }

  // --- Blueprint registries and host hooks -----------

  /// Makes the project's Blueprint assets known to the runtime before Play,
  /// as a built game's `registerProjectBlueprints()` does: enums, interfaces,
  /// save-game classes, montages and particle templates from the `.lmas`
  /// files, and every actor Blueprint class (compiled through [registry], so
  /// an open editor's document plays) for `Spawn Actor from Class`.
  void registerBlueprintAssets() {
    final assets = LuminaProjectBlueprintAssets.scan(viewModel.projectDirPath);
    assets.registerRuntime();
    final spawnable = registry.registerActorClasses(assets.actorClasses);
    final counts = [
      if (spawnable.isNotEmpty) '${spawnable.length} actor class${spawnable.length == 1 ? '' : 'es'}',
      if (assets.enums.isNotEmpty) '${assets.enums.length} enum${assets.enums.length == 1 ? '' : 's'}',
      if (assets.interfaces.isNotEmpty) '${assets.interfaces.length} interface${assets.interfaces.length == 1 ? '' : 's'}',
      if (assets.saveGameClasses.isNotEmpty) '${assets.saveGameClasses.length} save-game class${assets.saveGameClasses.length == 1 ? '' : 'es'}',
      if (assets.montages.isNotEmpty) '${assets.montages.length} montage${assets.montages.length == 1 ? '' : 's'}',
      if (assets.particleTemplates.isNotEmpty) '${assets.particleTemplates.length} particle template${assets.particleTemplates.length == 1 ? '' : 's'}',
    ];
    if (counts.isNotEmpty) {
      viewModel.logger.log('Registered Blueprint assets: ${counts.join(', ')}', level: 'info', source: 'PIE');
    }
  }

  FilamentEngine? _engine;
  FilamentScene? _scene;
  FilamentView? _postProcessView;
  LuminaPostProcessSettings? _postProcessBaseline;

  /// Whether the session runs through [startHeadlessForTest] (no engine).
  bool _headless = false;

  /// The project-relative level Play is running: the editor's level, or the
  /// one `Open Level` switched to. Null when not playing.
  String? get playingLevelPath => _playingLevel;
  String? _playingLevel;

  String? _savedDefaultSaveDirectory;
  bool _hooksInstalled = false;

  /// Where Play's `Save Game to Slot` writes: `<project>/Saved/SaveGames`.
  String get saveGamesDirectory => '${viewModel.projectDirPath}/Saved/SaveGames';

  /// While playing, Blueprints run in the editor (`Is Editor` is true), save
  /// under [saveGamesDirectory], and `Open Level` / `Quit Game` reach this
  /// session: Open Level plays another level, Quit Game stops Play.
  /// Both run after the tick that asked.
  void _installHostHooks() {
    LuminaBlueprintRuntime.isEditor = true;
    if (!_hooksInstalled) _savedDefaultSaveDirectory = LuminaSaveGameSubsystem.defaultSaveDirectoryPath;
    LuminaSaveGameSubsystem.defaultSaveDirectoryPath = saveGamesDirectory;
    LuminaGame.onOpenLevelRequested = (levelName, options) => scheduleMicrotask(() => openLevel(levelName));
    LuminaGame.onQuitRequested = () => scheduleMicrotask(requestStop);
    // Load Level preloads a project level from its
    // `.lmas`, found through the asset index; its meshes upload to Play's
    // engine. Change Level / Load And Change Level play it (changeLevel).
    final projectDir = viewModel.projectDirPath;
    LuminaLevelPreloader.instance
      ..manifestResolver = ((levelName) => LuminaLevelAssetManifest.forProjectLevel(projectDir, levelName))
      ..engine = _headless ? null : _engine;
    LuminaGame.onChangeLevelRequested = changeLevel;
    _hooksInstalled = true;
  }

  void _removeHostHooks() {
    if (!_hooksInstalled) return;
    _hooksInstalled = false;
    LuminaBlueprintRuntime.isEditor = false;
    LuminaSaveGameSubsystem.defaultSaveDirectoryPath = _savedDefaultSaveDirectory ?? kLuminaLegacySaveDirectory;
    LuminaGame.onOpenLevelRequested = null;
    LuminaGame.onQuitRequested = null;
    LuminaGame.onChangeLevelRequested = null;
    // Preloads a session left behind are dropped with it.
    LuminaLevelPreloader.instance.reset();
    _playingLevel = null;
  }

  /// `Quit Game` in Play: stops the session the way the toolbar's Stop does.
  void requestStop() {
    if (!isPlaying) return;
    viewModel.logger.log('Quit Game: stopping Play', level: 'info', source: 'PIE');
    if (_headless) stopHeadlessForTest();
    if (viewModel.isPlaying) viewModel.stopSimulation();
  }

  /// The project-relative level `.lmas` `Open Level` means by [levelName]:
  /// `L_Arena`, `L_Arena.lmas` or a project-relative path; levels live in
  /// `contents/levels/`, else anywhere under `contents/`. Null when none.
  String? levelPathFor(String levelName) {
    final dir = viewModel.projectDirPath;
    final trimmed = levelName.trim();
    if (trimmed.isEmpty) return null;
    final base = trimmed.split('/').last.replaceAll('.lmas', '');
    final candidates = [
      if (trimmed.startsWith('contents/')) trimmed.endsWith('.lmas') ? trimmed : '$trimmed.lmas',
      'contents/levels/$base.lmas',
    ];
    for (final c in candidates) {
      if (_readLevelActors(c) != null) return c;
    }
    final contents = Directory('$dir/contents');
    if (!contents.existsSync()) return null;
    final matches = contents
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((f) => f.path.endsWith('/$base.lmas'))
        .map((f) => f.path.substring(dir.length + 1))
        .toList()
      ..sort();
    for (final m in matches) {
      if (_readLevelActors(m) != null) return m;
    }
    return null;
  }

  /// The placed actors of the level at [relativePath] as saved, or null when
  /// the file is not a level.
  List<EditorActorNode>? _readLevelActors(String relativePath) {
    final file = File('${viewModel.projectDirPath}/$relativePath');
    if (!file.existsSync()) return null;
    try {
      final map = jsonDecode(file.readAsStringSync());
      if (map is! Map || map['metadata'] is! Map) return null;
      final actors = (map['metadata'] as Map)['actors'];
      return [
        if (actors is List)
          for (final a in actors.whereType<Map>()) EditorActorNode.fromMap(Map<String, dynamic>.from(a)),
      ];
    } catch (_) {
      return null;
    }
  }

  /// `Open Level` in Play: the running game is replaced by one built from
  /// level [levelName]'s saved actors on the same engine and scene (stop,
  /// load, play). The editor keeps its own level, which Stop restores.
  /// Returns whether the level was found and started.
  bool openLevel(String levelName) {
    if (!isPlaying) return false;
    final path = levelPathFor(levelName);
    final actors = path == null ? null : _readLevelActors(path);
    if (path == null || actors == null) {
      viewModel.logger.log("Open Level: no level named '$levelName' in this project.", level: 'warning', source: 'PIE');
      return false;
    }
    BlueprintPieDebugger.instance.clear();
    BlueprintBreakpoints.instance.clear();
    final previous = _game;
    _game = null;
    try {
      if (!_headless) previous?.disposeGame();
      final game = createGame(actors, levelPath: path);
      _game = game;
      if (_headless) {
        game.mountIntoWorldForTest(LuminaWorld());
      } else {
        _mountAndBeginPlay(game);
      }
      _followCursorOf(game);
      if (isPaused) game.pause();
      _playingLevel = path;
      _publishDebugTargets();
      viewModel.logger.log('PIE opened level ${path.split('/').last.replaceAll('.lmas', '')} (${actors.length} actors)',
          level: 'success', source: 'PIE');
      viewModel.notifyListeners();
      return true;
    } catch (e, st) {
      lastError = e.toString();
      viewModel.logger.log("Open Level '$levelName' failed: $e\n$st", level: 'error', source: 'PIE');
      return false;
    }
  }

  /// `Change Level` / `Load And Change Level` in Play:
  /// level [levelName] is preloaded — at once when Load Level preloaded it —
  /// then played as [openLevel] plays it, the editor keeping its own level.
  /// Completes after the new level's BeginPlay; throws when Play is not
  /// running, the level is unknown or it fails to load.
  Future<void> changeLevel(String levelName) async {
    if (!isPlaying) throw StateError("Change Level '$levelName': Play is not running.");
    if (levelPathFor(levelName) == null) throw StateError("Change Level: no level named '$levelName' in this project.");
    await LuminaLevelPreloader.instance.changeLevel(levelName, () async {
      if (!openLevel(levelName)) {
        throw StateError("Change Level '$levelName' failed${lastError == null ? '' : ': $lastError'}.");
      }
    });
  }

  /// Mounts [game] on Play's engine and scene and runs its play sequence.
  void _mountAndBeginPlay(EditorPieGame game) {
    game.mountGame(_engine!, _scene!);
    final world = game.gameInstance.world;
    final postProcessView = _postProcessView;
    if (world != null && postProcessView != null) {
      postProcessView.setDynamicLightingOptions(LuminaUnits.dynamicLightingNear, LuminaUnits.dynamicLightingFar);
      world.attachPostProcessView(postProcessView);
      if (_postProcessBaseline != null) world.postProcess.apply(_postProcessBaseline!);
    }
    // The game mode must exist before beginPlay, which is what calls
    // initGame; login must come after it, because findPlayerStart walks the
    // levels that beginPlay populates.
    if (world != null) {
      game.installSubsystems(world);
      game.installGameMode(world);
    }
    world?.beginPlay();
    game.startPlayerSession();
  }

  /// Plays [world] without Filament (widget tests): the same game, player
  /// session and debugger targets as [startPie].
  EditorPieGame startHeadlessForTest(LuminaWorld world) {
    _headless = true;
    _playingLevel = viewModel.project.activeLevel;
    _installHostHooks();
    final game = createGame(viewModel.actors.map((a) => EditorActorNode.fromMap(a.toMap())).toList());
    _game = game;
    // Playing from here: a breakpoint reached in BeginPlay must pause.
    isPlaying = true;
    isPaused = false;
    game.mountIntoWorldForTest(world);
    _followCursorOf(game);
    _publishDebugTargets();
    unawaited(mouseCapture.begin());
    return game;
  }

  /// Ends a [startHeadlessForTest] session.
  void stopHeadlessForTest() {
    BlueprintPieDebugger.instance.clear();
    BlueprintBreakpoints.instance.clear();
    _removeHostHooks();
    _headless = false;
    _game = null;
    isPlaying = false;
    isPaused = false;
    isEjected = false;
    _followCursorOf(null);
    mouseCapture.end();
  }

  /// The possessed pawn when it is a Blueprint instance, whatever its class.
  LuminaPawn? get possessedPawn => _game?.possessedPawn;

  /// The camera Play looks through.
  LuminaCameraComponent? get playerCamera => _game?.playerCamera;

  /// The camera the player's view goes through ([EditorPieGame.viewCamera]).
  LuminaCameraComponent? get viewCamera => _game?.viewCamera;

  /// The player camera manager's point of view while it is not the pawn's own
  /// camera ([EditorPieGame.viewTargetPov]).
  LuminaMinimalViewInfo? get viewTargetPov => _game?.viewTargetPov;

  /// `BP_ThirdPersonCharacter (VM)` while a Blueprint pawn plays.
  String? get pawnClassLabel => _game?.pawnClassLabel;

  String? _debugSelection;

  /// A Blueprint instance whose graph calls a project
  /// function (declared from the project's manifest, never run in the editor)
  /// says so in the Output Log the first time such a node is reached —
  /// lumina's VM skips it with zero outputs and plays the rest of the graph.
  /// A `breakpoint` node reached by any instance pauses
  /// Play and frames the node. Attached as each instance is created, before
  /// its BeginPlay.
  void _attachProjectCodeNotice(LuminaBlueprintInstance instance, Set<String> logged) {
    final cls = instance.blueprintClass;
    final graph = cls.document.eventGraph;
    final hasDeclaredOnly = graph.nodes.any((n) => LuminaBlueprintFunctionRegistry.isDeclaredOnly(n.registryId));
    final hasBreakpoint = _classHasBreakpoint(cls);
    if (!hasDeclaredOnly && !hasBreakpoint) return;
    instance.trace = (event) {
      if (hasBreakpoint && event.registryId == 'breakpoint') {
        _hitBreakpoint(cls, event.nodeId);
        return;
      }
      if (!hasDeclaredOnly || !LuminaBlueprintFunctionRegistry.isDeclaredOnly(event.registryId)) return;
      if (!logged.add('${cls.name}|${event.nodeId}')) return;
      final title = graph.node(event.nodeId)?.title ?? event.registryId;
      viewModel.logger.log(
        '${cls.name}: $title ${LuminaBlueprintFunctionRegistry.unavailableMessage}; skipped in the editor.',
        level: 'warning',
        source: 'PIE',
      );
    };
  }

  static bool _classHasBreakpoint(LuminaBlueprintClass cls) {
    bool any(LuminaBlueprintGraph g) => g.nodes.any((n) => n.registryId == 'breakpoint');
    final doc = cls.document;
    return any(doc.eventGraph) || doc.functions.any((f) => any(f.graph)) || doc.macros.any((m) => any(m.graph));
  }

  /// The project-relative `.lmas` of Blueprint class [name]
  /// (`contents/blueprints/<name>.lmas`, else the first match under contents/).
  String? _blueprintPathOf(String name) {
    final direct = 'contents/blueprints/$name.lmas';
    if (File('${viewModel.projectDirPath}/$direct').existsSync()) return direct;
    final contents = Directory('${viewModel.projectDirPath}/contents');
    if (!contents.existsSync()) return null;
    for (final f in contents.listSync(recursive: true, followLinks: false)) {
      if (f is File && f.path.endsWith('/$name.lmas')) return f.path.substring(viewModel.projectDirPath.length + 1);
    }
    return null;
  }

  /// The breakpoint Play last stopped on (null when none, or after resume).
  BlueprintBreakpointHit? get breakpointHit => BlueprintBreakpoints.instance.current;

  void _hitBreakpoint(LuminaBlueprintClass cls, String nodeId) {
    if (!isPlaying || isPaused) return;
    final path = _blueprintPathOf(cls.name) ?? 'contents/blueprints/${cls.name}.lmas';
    if (!BlueprintBreakpoints.instance.hit(path, nodeId)) return;
    final title = cls.document.eventGraph.node(nodeId)?.title ?? 'Breakpoint';
    viewModel.logger.log('Breakpoint hit in ${cls.name} ($title): Play paused. Resume or step to continue.', level: 'warning', source: 'PIE');
    pause();
    // Frame the node in the Blueprint editor showing this class (or the
    // docked debug panel); the editor opens on demand from the log line.
    BlueprintNavigation.instance.request(path, nodeId);
    viewModel.notifyListeners();
  }

  /// Hands the running Blueprint instances to the Blueprint debugger: the
  /// level's Blueprint script, the possessed pawn's, and the selected placed
  /// Blueprint actor's.
  void _publishDebugTargets() {
    final game = _game;
    if (game == null) return;
    final targets = <String, LuminaBlueprintInstance>{};
    // The level's Blueprint script, beside the pawn.
    final levelScript = game.gameInstance.world?.persistentLevel.scriptActor;
    final levelPath = _playingLevel ?? viewModel.project.activeLevel;
    if (levelScript is LuminaBlueprintLevelScript && levelPath.isNotEmpty) targets[levelPath] = levelScript;
    final pawn = game.possessedPawn;
    final pawnPath = game.registry?.pawnClassPath(game.mapsAndModes);
    if (pawn is LuminaBlueprintInstance && pawnPath != null) targets[pawnPath] = pawn as LuminaBlueprintInstance;
    final selected = viewModel.primarySelectedActor;
    final placedPath = selected?.blueprintClass;
    final world = game.gameInstance.world;
    if (selected != null && placedPath != null && placedPath.isNotEmpty && world != null) {
      final runtime = world.persistentLevel.actors.where((a) => a.key == ValueKey(selected.id)).firstOrNull;
      if (runtime is LuminaBlueprintInstance) targets[placedPath] = runtime;
    }
    _debugSelection = selected?.id;
    BlueprintPieDebugger.instance.setTargets(targets);
  }

  void stopPie(FilamentEngine engine, FilamentScene scene) {
    if (!isPlaying) return;
    BlueprintPieDebugger.instance.clear();
    BlueprintBreakpoints.instance.clear();
    _removeKeyboardHandler();
    _removeHostHooks();
    _followCursorOf(null);
    mouseCapture.end();

    try {
      _game?.disposeGame();
    } catch (e) {
      lastError = e.toString();
      viewModel.logger.log('PIE dispose raised: $e', level: 'warning', source: 'PIE');
    }
    _game = null;
    _engine = null;
    _scene = null;
    _postProcessView = null;
    _postProcessBaseline = null;

    isPlaying = false;
    isPaused = false;
    isEjected = false;

    viewModel.transactions.isFrozen = false;
    _restoreEditorState();
    viewModel.logger.log('PIE stopped, editor state restored', level: 'info', source: 'PIE');
  }

  void _restoreEditorState() {
    if (_editorSnapshot != null) {
      viewModel.restoreSnapshot(_editorSnapshot!);
    }
    if (_selectedActorIdSnapshot != null) {
      viewModel.selectActors([_selectedActorIdSnapshot!]);
    } else {
      viewModel.clearSelection();
    }
    if (_cameraSnapshot != null) {
      viewModel.restoreCameraSnapshot(_cameraSnapshot!);
    }
    _editorSnapshot = null;
    _cameraSnapshot = null;
    _selectedActorIdSnapshot = null;
  }

  /// Pauses the runtime world (timers, subsystems and audio freeze) and the
  /// editor tick. No-op unless playing.
  void pause() {
    if (!isPlaying || isPaused) return;
    isPaused = true;
    try {
      _game?.pause();
    } catch (e) {
      lastError = e.toString();
      viewModel.logger.log('PIE pause raised: $e', level: 'warning', source: 'PIE');
    }
    viewModel.setSimulationPaused(true);
    mouseCapture.sync();
  }

  void resume() {
    if (!isPlaying || !isPaused) return;
    isPaused = false;
    BlueprintBreakpoints.instance.clear();
    try {
      _game?.resume();
    } catch (e) {
      lastError = e.toString();
      viewModel.logger.log('PIE resume raised: $e', level: 'warning', source: 'PIE');
    }
    viewModel.setSimulationPaused(false);
    mouseCapture.sync();
  }

  /// Advances the paused world by exactly one tick of [dt] seconds
  /// (frame stepping). No-op unless playing and paused. Without [log] the
  /// step writes no Output Log line (the MCP server's `pie_advance` steps
  /// hundreds of frames and logs one line for them all).
  void step([double dt = 1 / 60, bool log = true]) {
    if (!isPlaying || !isPaused) return;
    BlueprintBreakpoints.instance.clear();
    try {
      _game?.step(dt);
      if (log) viewModel.logger.log('PIE stepped one frame (${(dt * 1000).toStringAsFixed(1)} ms)', level: 'info', source: 'PIE');
    } catch (e) {
      lastError = e.toString();
      viewModel.logger.log('PIE step raised: $e', level: 'error', source: 'PIE');
    }
    viewModel.notifyListeners();
  }

  /// Restarts the running session: the runtime world is rebuilt from the
  /// same editor snapshot on the same engine/scene, resuming play.
  void restart() {
    if (!isPlaying) return;
    try {
      _game?.restart();
      isPaused = false;
      viewModel.setSimulationPaused(false);
      mouseCapture.sync();
      viewModel.logger.log('PIE restarted', level: 'info', source: 'PIE');
    } catch (e) {
      lastError = e.toString();
      viewModel.logger.log('PIE restart raised: $e', level: 'error', source: 'PIE');
    }
  }

  bool _keyboardHandlerInstalled = false;

  /// Takes the keyboard for the running game.
  ///
  /// This is deliberately not routed through the viewport's focus node: the
  /// editor's focus can sit on any panel when the user presses Play, and a
  /// running game that ignores W because a tree view has focus is not playing.
  /// Every keyboard key reaches the game through the engine's one key table
  /// (`LuminaKey.fromKeyId`) — the same the project input
  /// binder and a shipped game's `main.dart` use. Only the keys the project's
  /// mapping contexts bind are swallowed, and only while the session accepts
  /// input, so editor shortcuts (Alt+P) and Stop keep working.
  bool _onHardwareKey(KeyEvent event) {
    // While the game has the mouse, F4 gives the cursor back and
    // Esc stops Play, wherever keyboard focus sits. Once released, Esc still
    // stops Play through the editor shell's `shell.cancel`.
    if (event.logicalKey == LogicalKeyboardKey.f4) {
      if (event is! KeyDownEvent || !mouseCapture.isCaptured) return false;
      mouseCapture.release();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (event is! KeyDownEvent || !isPlaying || !mouseCapture.isCaptured) return false;
      viewModel.stopSimulation();
      return true;
    }
    final key = LuminaKey.fromKeyId(event.logicalKey.keyId);
    if (key == null) return false;
    if (event is KeyDownEvent) {
      if (!acceptsGameInput) return false;
      injectKeyDown(key);
    } else if (event is KeyUpEvent) {
      injectKeyUp(key);
    } else if (event is! KeyRepeatEvent) {
      return false;
    }
    return acceptsGameInput && (_game?.bindsKey(key) ?? false);
  }

  /// Feeds [event] to the keyboard handler Play installs (widget tests).
  bool handleKeyEventForTest(KeyEvent event) => _onHardwareKey(event);

  void _installKeyboardHandler() {
    if (_keyboardHandlerInstalled) return;
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    _keyboardHandlerInstalled = true;
  }

  void _removeKeyboardHandler() {
    if (!_keyboardHandlerInstalled) return;
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _keyboardHandlerInstalled = false;
  }

  /// Whether the running world should receive keyboard and mouse events.
  /// An ejected user drives the editor flycam instead of the pawn.
  bool get acceptsGameInput => isPlaying && !isPaused && !isEjected;

  /// Whether scripted input (an agent's play-test) reaches
  /// the world: as [acceptsGameInput], but a paused world takes it too, and
  /// the next [step] sees it — frame-exact testing presses keys while paused.
  bool get acceptsScriptedInput => isPlaying && !isEjected;

  /// A key press; [scripted] input also lands while paused
  /// ([acceptsScriptedInput]).
  void injectKeyDown(LuminaKey key, {bool scripted = false}) {
    if (!(scripted ? acceptsScriptedInput : acceptsGameInput)) return;
    _game?.injectKeyDown(key);
  }

  void injectKeyUp(LuminaKey key) {
    // A release is always forwarded, even after an eject, so a key held at the
    // moment of ejecting does not stay stuck down in the world.
    _game?.injectKeyUp(key);
  }

  void injectMouseDelta(double dx, double dy, {bool scripted = false}) {
    if (!(scripted ? acceptsScriptedInput : acceptsGameInput)) return;
    _game?.injectMouseDelta(dx, dy);
  }

  /// An analog axis value (`MouseX`, `GamepadLeftStickX`, …) for the next
  /// tick, beside [injectMouseDelta] (the MCP server's `pie_axis`).
  void injectAnalog(LuminaKey key, double value, {bool scripted = false}) {
    if (!(scripted ? acceptsScriptedInput : acceptsGameInput)) return;
    _game?.injectAnalog(key, value);
  }

  /// A delta from Flutter's own pointer events (the viewport's hover/move,
  /// the window shield): the game's mouse look only while the game has the
  /// mouse, and only when the capture backend does not report relative
  /// motion itself.
  void injectPointerDelta(double dx, double dy) {
    if (!mouseCapture.acceptsPointerDeltas) return;
    injectMouseDelta(dx, dy);
  }

  void eject() {
    isEjected = true;
    mouseCapture.sync();
  }

  void possess() {
    isEjected = false;
    mouseCapture.sync();
  }

  void tick(double dt) {
    if (!isPlaying || isPaused) return;
    // The debugged placed instance follows the selection.
    if (viewModel.primarySelectedActor?.id != _debugSelection) _publishDebugTargets();
    try {
      _game?.tickGame(dt);
    } catch (e) {
      lastError = e.toString();
      viewModel.logger.log('PIE tick raised: $e', level: 'error', source: 'PIE');
    }
  }
}
