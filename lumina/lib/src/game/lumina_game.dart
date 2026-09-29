import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show debugPrint, objectRuntimeType;
import 'package:flutter_filament/flutter_filament.dart';
import '../declarative/lumina_object.dart';
import '../declarative/build_context.dart';
import '../declarative/element.dart';
import '../world/world.dart';
import 'game_instance.dart';
import 'play_state.dart';

export 'play_state.dart';

/// Entrypoint class for building declarative Lumina game applications.
///
/// Besides the mount / tick / dispose lifecycle it exposes the editor-facing play
/// control surface (Play-In-Editor): [pause], [resume], [step], [restart] and a
/// broadcast [playStateStream] a toolbar can bind to.
abstract class LuminaGame extends LuminaObject {
  // ---------------------------------------------------------------------------
  // Host hooks Blueprint nodes call
  // ---------------------------------------------------------------------------

  /// What `Quit Game` runs: the generated `main()` exits the app, the editor's
  /// Play-In-Editor stops the session. Unset: the request is only logged.
  static void Function()? onQuitRequested;

  /// What `Open Level` runs with the level name and options string: the
  /// generated `main()` swaps the world for that level, Play-In-Editor loads
  /// it. Unset: the request is only logged.
  static void Function(String levelName, String options)? onOpenLevelRequested;

  /// The last `Open Level` request, for hosts that poll instead of hooking.
  static ({String levelName, String options})? lastOpenLevelRequest;

  /// What [changeLevel] runs: the host switches the running
  /// game to the level — the generated `main()`'s game host, Play-In-Editor —
  /// reusing a `LuminaLevelPreloader` preload when there is one, and the
  /// future completes once the new level has begun play; it throws when the
  /// level is unknown or fails to load.
  static Future<void> Function(String levelName)? onChangeLevelRequested;

  /// Switches the running game to [levelName] (Blueprint `Change Level` /
  /// `Load And Change Level`); completes after the new level's BeginPlay,
  /// throws on failure or when no host changes levels.
  static Future<void> changeLevel(String levelName) {
    final hook = onChangeLevelRequested;
    if (hook == null) {
      return Future<void>.error(StateError("Change Level '$levelName': no game host changes levels."));
    }
    return hook(levelName);
  }

  /// Asks the host to quit (Blueprint `Quit Game`).
  static void requestQuit() {
    final hook = onQuitRequested;
    if (hook == null) {
      developer.log('Quit Game requested; no host handles it.', name: 'LuminaGame');
      return;
    }
    hook();
  }

  /// Asks the host to open [levelName] with [options] (Blueprint `Open Level`).
  static void requestOpenLevel(String levelName, [String options = '']) {
    lastOpenLevelRequest = (levelName: levelName, options: options);
    final hook = onOpenLevelRequested;
    if (hook != null) {
      hook(levelName, options);
      return;
    }
    // A host that only changes levels: Open Level is a Change Level whose
    // result nobody waits for.
    if (onChangeLevelRequested != null) {
      changeLevel(levelName).catchError((Object e) {
        developer.log("Open Level '$levelName' failed: $e", name: 'LuminaGame', level: 900);
      });
      return;
    }
    developer.log("Open Level '$levelName' requested; no host handles it.", name: 'LuminaGame');
  }

  final LuminaGameInstance Function()? gameInstanceFactory;
  LuminaGameInstance? _gameInstance;

  /// The game instance [mountGame] created. Throws before the first mount.
  LuminaGameInstance get gameInstance =>
      _gameInstance ?? (throw StateError('LuminaGame.gameInstance was read before mountGame.'));

  /// Sets the game instance for a host that plays a world without
  /// [mountGame] (a headless editor test mounts its own world).
  set gameInstance(LuminaGameInstance instance) => _gameInstance = instance;
  LuminaElement? _rootElement;
  FilamentEngine? _engine;
  FilamentScene? _scene;
  FilamentView? _view;

  LuminaPlayState _playState = LuminaPlayState.stopped;
  StreamController<LuminaPlayState>? _playStateController;

  LuminaGame({super.key, this.gameInstanceFactory});

  /// The running world; null before [mountGame] (a widget stacked over the
  /// game, like [LuminaWidgetLayer.forGame], may ask before the scene exists).
  LuminaWorld? get world => _gameInstance?.world;

  // ---------------------------------------------------------------------------
  // Play state
  // ---------------------------------------------------------------------------

  /// Current play state: `stopped` before [mountGame] / after [disposeGame],
  /// `playing` after [mountGame], `paused` after [pause].
  LuminaPlayState get playState => _playState;

  /// Whether the game is paused ([tickGame] is a no-op; only [step] advances the world).
  bool get isPaused => _playState == LuminaPlayState.paused;

  /// Broadcast stream emitting one event per play-state *transition*
  /// (idempotent [pause] / [resume] calls emit nothing). Closed by [disposeGame]
  /// after the final `stopped` event.
  Stream<LuminaPlayState> get playStateStream {
    _playStateController ??= StreamController<LuminaPlayState>.broadcast();
    return _playStateController!.stream;
  }

  void _setPlayState(LuminaPlayState next) {
    if (_playState == next) return;
    _playState = next;
    final controller = _playStateController;
    if (controller != null && !controller.isClosed) {
      controller.add(next);
    }
  }

  /// Pauses the mounted world: timers, subsystem ticks, actor ticks, audio and
  /// `timeSeconds` freeze. Idempotent; no-op while `stopped`.
  void pause() {
    if (_playState != LuminaPlayState.playing) return;
    gameInstance.world?.isPaused = true;
    _setPlayState(LuminaPlayState.paused);
  }

  /// Resumes a paused world. Idempotent; no-op while `stopped`.
  void resume() {
    if (_playState != LuminaPlayState.paused) return;
    gameInstance.world?.isPaused = false;
    _setPlayState(LuminaPlayState.playing);
  }

  /// Advances the world by exactly one tick of [deltaTime] regardless of the
  /// pause flag (the game stays paused). Equivalent to one [tickGame] while
  /// playing. Throws [StateError] while `stopped`.
  void step(double deltaTime) {
    if (_playState == LuminaPlayState.stopped) {
      throw StateError('Cannot step a game that is not mounted.');
    }
    gameInstance.world?.step(deltaTime);
    gameInstance.primaryPlayerController?.onTick(deltaTime);
  }

  /// Tears the current world down and starts a fresh one from the same
  /// declarative tree on the same engine/scene ([LuminaGameInstance.replaceWorld]).
  /// If the old world had begun play, `beginPlay()` is called on the new one.
  /// Ends in the `playing` state. Throws [StateError] while `stopped`.
  void restart() {
    if (_playState == LuminaPlayState.stopped) {
      throw StateError('Cannot restart a game that is not mounted.');
    }
    final engine = _engine!;
    final scene = _scene!;
    final hadBegunPlay = gameInstance.world?.hasBegunPlay ?? false;

    _rootElement?.unmount();
    _rootElement = null;

    final freshWorld = LuminaWorld();
    freshWorld.initializeNativeContext(engine, scene, view: _view);
    gameInstance.replaceWorld(freshWorld);
    _mountTree(freshWorld);

    if (hadBegunPlay) {
      freshWorld.beginPlay();
    }
    _setPlayState(LuminaPlayState.playing);
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Initializes declarative game tree and mounts [LuminaWorld]; returns
  /// whether it did.
  ///
  /// With a [view], every world the game runs renders through its active
  /// camera component. A game that is already mounted stays as it
  /// is: the call logs a warning and returns false. After
  /// [disposeGame] the game can be mounted again.
  bool mountGame(FilamentEngine engine, FilamentScene scene, {FilamentView? view}) {
    if (_playState != LuminaPlayState.stopped) {
      debugPrint('[LuminaGame] mountGame: ${objectRuntimeType(this, 'LuminaGame')} is already mounted; the second scene is ignored.');
      return false;
    }
    _engine = engine;
    _scene = scene;
    _view = view;
    final instance = _gameInstance = gameInstanceFactory?.call() ?? LuminaGameInstance();
    instance.setNativeContext(engine, scene, view: view);
    instance.init();

    final initialWorld = LuminaWorld();
    initialWorld.initializeNativeContext(engine, scene, view: view);
    gameInstance.setInitialWorld(initialWorld);

    _mountTree(initialWorld);
    _setPlayState(LuminaPlayState.playing);
    return true;
  }

  /// Mounts this game's declarative tree into [targetWorld]. The root context carries
  /// the world **and its persistent level**, so actors returned from [build] (directly or
  /// inside a [LuminaNodeGroup]) register into the world's persistent level.
  void _mountTree(LuminaWorld targetWorld) {
    _rootElement = LuminaElement(this);
    final rootContext = LuminaElementContext(
      node: this,
      world: targetWorld,
      level: targetWorld.persistentLevel,
    );
    _rootElement!.mount(rootContext);
  }

  /// Ticks the game loop and mounted world. No-op while [isPaused] (use [step]).
  void tickGame(double deltaTime) {
    if (isPaused) return;
    gameInstance.world?.tick(deltaTime);
    gameInstance.primaryPlayerController?.onTick(deltaTime);
  }

  /// Disposes game tree and world resources.
  void disposeGame() {
    _rootElement?.unmount();
    _rootElement = null;
    gameInstance.world?.cleanup();
    gameInstance.shutdown();
    _engine = null;
    _scene = null;
    _view = null;
    _setPlayState(LuminaPlayState.stopped);
    _playStateController?.close();
    _playStateController = null;
  }
}
