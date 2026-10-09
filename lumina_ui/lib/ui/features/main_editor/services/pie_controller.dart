import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_debugger.dart';
import 'package:vector_math/vector_math_64.dart' as vm64;

import 'package:lumina_ui/ui/features/sub_editors/services/umg_widget_codegen.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/widget_class_catalog.dart';
import 'package:lumina_ui/ui/features/main_editor/services/blueprint_play_support.dart';
import 'package:lumina_ui/ui/features/main_editor/services/camera_actor_properties.dart';
import 'package:lumina_ui/ui/features/main_editor/services/environment_actor_properties.dart';
import 'package:lumina_ui/ui/features/main_editor/services/light_actor_properties.dart';
import 'package:lumina_ui/ui/features/main_editor/services/pie_mouse_capture.dart';
import 'package:lumina_ui/ui/features/main_editor/services/pie_pointer_input.dart';
import 'package:lumina_ui/ui/features/details/services/blueprint_collision_overrides.dart';

part 'pie_controller/editor_pie_game.dart';
part 'pie_controller/blueprints_in_play.dart';
part 'pie_controller/game_input.dart';

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

class PieController with _PieBlueprintsInPlay, _PieGameInput {
  @override
  final EditorViewModel viewModel;
  @override
  EditorPieGame? _game;
  @override
  bool isPlaying = false;
  @override
  bool isPaused = false;
  @override
  bool isEjected = false;

  /// Last error raised while mounting or ticking the runtime world, or null.
  String? lastError;

  List<EditorActorNode>? _editorSnapshot;
  String? _selectedActorIdSnapshot;
  List<double>? _cameraSnapshot;

  PieController(this.viewModel);

  /// The game's hold on the mouse: captured from Play, F4
  /// releases it, a click on the game view takes it again, Esc stops Play.
  @override
  late final PieMouseCapture mouseCapture = PieMouseCapture(
    gameAcceptsInput: () => acceptsGameInput,
    gameWantsFreeCursor: () => _game?.playerController?.wantsFreeCursor ?? false,
    onMotion: injectMouseDelta,
  )..addListener(viewModel.notifyListeners);

  /// The game's mouse position and buttons, from the viewport's pointer.
  late final PiePointerInput pointer = PiePointerInput(
    acceptsGameInput: () => acceptsGameInput,
    gameHoldsCursor: () => mouseCapture.isCaptured,
    cursorReleased: () => mouseCapture.isReleased,
    uiOnly: () => _game?.playerController?.inputMode == 'UIOnly',
    injectPosition: (x, y) => _game?.injectMousePosition(x, y),
    injectKeyDown: injectKeyDown,
    injectKeyUp: injectKeyUp,
    setViewportSize: (w, h) => _game?.world?.viewportSize = (w, h),
  );

  /// The possessed controller whose cursor state Play follows: Set Show Mouse Cursor / Set Input Mode free or take the
  /// pointer as the game runs.
  ChangeSignal? _followedCursor;

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
  @override
  GameTemplateKind templateKindForProject() =>
      GameTemplateCatalog.byId(viewModel.project.template).kind;

  /// The Third Person character mesh the project carries
  /// ([LuminaThirdPersonContent.projectMeshGlbPath]), or null — a
  /// project created before the template shipped it plays with no body.
  @override
  String? mannequinPathForProject() {
    final file = File('${viewModel.projectDirPath}/${LuminaThirdPersonContent.projectMeshGlbPath}');
    return file.existsSync() ? file.path : null;
  }

  /// The project's input actions and key bindings, bound to the runtime.
  ///
  /// A project created before the template work has no input section; it falls
  /// back to its template's defaults so Play still moves, and the user can then
  /// edit them in Project Settings.
  @override
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
    // Play needs the engine's Flutter services (the procedural sky's bundled
    // assets, the Blueprint video player) even where the editor's start-up
    // did not run (tests, an embedded editor). Idempotent.
    LuminaWidgets.ensureInitialized();

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
    _game = createGame(_actorsForPlay(_editorSnapshot!), input: boundInput);
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

  /// The game Play mounts for [actors] (the level snapshot) of [levelPath]
  /// (default: the level Play is running, else the editor's).
  /// The actors as Play spawns them: one hidden in the outliner, itself or
  /// through a folder above it, is hidden in the game too (the editor keeps
  /// its own per-actor flags; this bakes the folders in for the level code).
  static List<EditorActorNode> _actorsForPlay(List<EditorActorNode> actors) {
    final byId = {for (final a in actors) a.id: a};
    bool effectivelyVisible(EditorActorNode a) {
      EditorActorNode? current = a;
      var guard = 0;
      while (current != null && ++guard < 64) {
        if (!current.isVisible) return false;
        final parent = current.parentId;
        if (parent == null) break;
        current = byId[parent];
      }
      return true;
    }
    return [
      for (final a in actors)
        if (a.isVisible == effectivelyVisible(a)) a else EditorActorNode.fromMap({...a.toMap(), 'isVisible': false}),
    ];
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
  @override
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
      final game = createGame(_actorsForPlay(actors), levelPath: path);
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
    final game = createGame(_actorsForPlay(viewModel.actors.map((a) => EditorActorNode.fromMap(a.toMap())).toList()));
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

  void stopPie(FilamentEngine engine, FilamentScene scene) {
    if (!isPlaying) return;
    BlueprintPieDebugger.instance.clear();
    BlueprintBreakpoints.instance.clear();
    _removeKeyboardHandler();
    _removeHostHooks();
    _followCursorOf(null);
    pointer.releaseAll();
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
  @override
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
    pointer.releaseAll();
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

  void eject() {
    pointer.releaseAll();
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
    pointer.syncViewportSize();
    try {
      _game?.tickGame(dt);
    } catch (e) {
      lastError = e.toString();
      viewModel.logger.log('PIE tick raised: $e', level: 'error', source: 'PIE');
    }
  }
}
