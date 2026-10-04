import 'package:flutter_filament/flutter_filament.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3, Quaternion;
import '../math/units.dart';
import '../declarative/lumina_object.dart';
import '../declarative/build_context.dart';
import '../declarative/build_owner.dart';
import '../object/actor.dart';
import 'level.dart';
import 'world_type.dart';
import 'subsystem/world_subsystem.dart';
import '../components/mesh/mesh_asset_cache.dart';
import '../material/material_cache.dart';
import '../controller/player_controller.dart';
import '../game/game_mode.dart';
import '../game/game_state.dart';
import '../post_process/post_process_blender.dart';
import '../post_process/post_process_controller.dart';
import '../post_process/post_process_settings.dart';
import '../post_process/scalability_profile.dart';
import '../components/camera/camera_component.dart';
import '../components/light/directional_light_component.dart';
import '../components/light/auto_exposure.dart';
import 'entity_registry.dart';
import '../utility/viewport_statics.dart';
import 'debug_shapes.dart';
import '../math/euler.dart';
import '../game/player_camera_manager.dart' show LuminaMinimalViewInfo;

class _PendingSpawnItem {
  final LuminaActor actor;
  final LuminaLevel targetLevel;
  _PendingSpawnItem(this.actor, this.targetLevel);
}

/// Orchestrates levels, actors, Filament scene bindings, and the 5-phase deterministic tick pipeline.
class LuminaWorld extends LuminaObject {
  final LuminaWorldType worldType;
  LuminaLevel persistentLevel;
  final List<LuminaLevel> streamingLevels = [];
  final LuminaSubsystemCollection subsystems = LuminaSubsystemCollection();

  /// Central registry of native Filament entity IDs mapped to owning components/actors.
  final LuminaEntityRegistry entityRegistry = LuminaEntityRegistry();

  /// All levels associated with this world (persistent and streaming sub-levels).
  List<LuminaLevel> get levels => [persistentLevel, ...streamingLevels];

  /// The active primary level for this world.
  LuminaLevel? get currentLevel => persistentLevel;

  FilamentEngine? _filamentEngine;
  FilamentScene? _filamentScene;

  /// The game mode defining the rules for this world.
  LuminaGameMode? gameMode;

  /// The game state for this world, managed by the game mode.
  LuminaGameState? get gameState => gameMode?.gameState;

  bool _isTicking = false;
  bool _hasBegunPlay = false;
  bool _isCleanedUp = false;
  bool _isPaused = false;
  int _tickCount = 0;
  double _timeSeconds = 0.0;

  /// Accumulated game time in seconds (does not advance while [isPaused]).
  double get timeSeconds => _timeSeconds;

  /// Number of ticks actually executed by [tick] / [step]; paused no-op ticks are not counted.
  int get tickCount => _tickCount;

  // --- Engine stats -----------------------------------------

  double _realTimeSeconds = 0.0;
  double _lastFrameTimeMs = 0.0;
  double _frameRate = 0.0;
  double _timeDilation = 1.0;
  double _lastDeltaSeconds = 0.0;

  /// The frames stepped so far: what `Get Frame Number` reads.
  int get frameNumber => _tickCount;

  /// The last frame's real (undilated) duration in milliseconds.
  double get lastFrameTimeMs => _lastFrameTimeMs;

  /// Frames per second, an exponential moving average over about half a
  /// second of real frame time; 0 before the first frame. It converges from
  /// the deltas given to [step], not the wall clock, so fixed-step tests read
  /// exactly what they step.
  double get frameRate => _frameRate;

  /// Real (undilated) seconds stepped so far; a paused world does not advance it.
  double get realTimeSeconds => _realTimeSeconds;

  /// The delta the actors received in the last frame (dilated): `Get World Delta Seconds`.
  double get deltaSeconds => _lastDeltaSeconds;

  /// Scales the delta time gameplay receives (global time dilation;
  /// `slomo`). 1.0 is real time; 0 freezes actors while [realTimeSeconds]
  /// keeps running. Must not be negative.
  double get timeDilation => _timeDilation;
  set timeDilation(double value) {
    if (value.isNaN || value < 0.0) {
      throw ArgumentError.value(value, 'timeDilation', 'must be zero or positive');
    }
    _timeDilation = value;
  }

  /// Debug shapes Blueprint nodes recorded for the editor to draw;
  /// expired ones are dropped at the start of every frame.
  final List<LuminaDebugShape> debugShapes = [];

  /// On-screen messages (`Print String` with Print to Screen) by key, drawn
  /// by the PIE HUD overlay; expired ones are dropped every frame.
  final Map<String, LuminaScreenMessage> screenMessages = {};

  /// Records [shape] with its expiry at the current real time.
  void addDebugShape(LuminaDebugShape shape) => debugShapes.add(shape);

  /// Drops every debug shape at once (`Flush Debug Shapes`).
  void flushDebugShapes() => debugShapes.clear();

  /// Adds or replaces the screen message [key]; a duration of 0 keeps it for
  /// one frame. A null / empty key gets a unique one.
  void addScreenMessage(String? key, String text, {List<double> color = const [0.0, 1.0, 0.0, 1.0], double duration = 2.0}) {
    final k = key == null || key.isEmpty ? '#${_screenMessageSerial++}' : key;
    screenMessages[k] = LuminaScreenMessage(k, text, color, _realTimeSeconds + duration);
  }

  int _screenMessageSerial = 0;

  void _expireDebugRecords() {
    final now = _realTimeSeconds;
    debugShapes.removeWhere((s) => s.expiresAt <= now);
    screenMessages.removeWhere((_, m) => m.expiresAt <= now);
  }

  /// Whether the world is paused. While paused, [tick] is a silent no-op — no phases run,
  /// so subsystems (timers, audio), actors and [timeSeconds] all freeze together. Only [step]
  /// advances a paused world. Subsystems are notified via
  /// [LuminaWorldSubsystem.onWorldPauseChanged] on every actual change.
  bool get isPaused => _isPaused;
  set isPaused(bool value) {
    if (_isPaused == value) return;
    _isPaused = value;
    subsystems.notifyPauseChanged(value);
  }

  /// Gravity along the authoring Z axis, cm/s² (negative pulls down; the
  /// runtime applies it along −Y). The generated game sets it from the
  /// project's `physics.gravity_z`.
  double gravityZ = -LuminaUnits.gravity;

  /// Optional vertical threshold (Y coordinate) below which actors are automatically destroyed.
  double? killZ;

  /// Delegate invoked whenever an actor falls below [killZ].
  void Function(LuminaActor victim)? onActorFellOutOfWorld;

  /// Optional attached build owner for flushing declarative rebuilds during pre-physics phase.
  LuminaBuildOwner? buildOwner;

  /// Test seam / callback for recording phase executions.
  void Function(String phase)? onPhaseExecuted;

  /// Test seam / hook for render prep phase.
  void Function(LuminaActor actor)? onRenderPrepCallback;

  // Double-buffering for allocation-free deferred spawn and destroy command execution
  final List<_PendingSpawnItem> _pendingSpawnA = [];
  final List<_PendingSpawnItem> _pendingSpawnB = [];
  final List<LuminaActor> _pendingDestroyA = [];
  final List<LuminaActor> _pendingDestroyB = [];

  late List<_PendingSpawnItem> _activeSpawnBuffer;
  late List<LuminaActor> _activeDestroyBuffer;

  LuminaWorld({
    super.key,
    this.worldType = LuminaWorldType.game,
    LuminaLevel? initialLevel,
    List<LuminaObject> children = const [],
  }) : persistentLevel = initialLevel ?? LuminaLevel(children: children) {
    _activeSpawnBuffer = _pendingSpawnA;
    _activeDestroyBuffer = _pendingDestroyA;

    persistentLevel.owningWorld = this;
    persistentLevel.state = LevelState.visible;
    registerSubsystem<LuminaWidgetSubsystem>(LuminaWidgetSubsystem());
    registerSubsystem<LuminaUserSettingsSubsystem>(LuminaUserSettingsSubsystem());
    for (final actor in persistentLevel.actors) {
      actor.onRegister(this);
    }
  }

  /// Whether a native Filament engine and scene context are currently bound.
  bool get hasNativeContext => _filamentEngine != null && _filamentScene != null;

  /// Whether this world has been cleaned up and is no longer usable.
  bool get isCleanedUp => _isCleanedUp;

  /// The bound native Filament engine. Throws [StateError] if unbound.
  FilamentEngine get filamentEngine {
    if (_filamentEngine == null) {
      throw StateError('World has no native context — call initializeNativeContext first.');
    }
    return _filamentEngine!;
  }

  /// The bound native Filament scene. Throws [StateError] if unbound.
  FilamentScene get filamentScene {
    if (_filamentScene == null) {
      throw StateError('World has no native context — call initializeNativeContext first.');
    }
    return _filamentScene!;
  }

  /// The bound native Filament engine, or null if unbound.
  FilamentEngine? get filamentEngineOrNull => _filamentEngine;

  /// Alias for bound native Filament engine, or null if unbound.
  FilamentEngine? get nativeEngine => _filamentEngine;

  /// The bound native Filament scene, or null if unbound.
  FilamentScene? get filamentSceneOrNull => _filamentScene;

  /// Optional pre-tick hook callback called at the start of tick.
  void Function(double deltaTime)? onPreTick;

  LuminaWorldMeshCache? _meshAssetCache;

  /// This world's view of its engine's mesh cache: meshes are
  /// uploaded once per engine and shared with every other world and viewport
  /// on it; [cleanup] releases only what this world holds.
  LuminaWorldMeshCache get meshAssetCache {
    if (_meshAssetCache == null) {
      if (!hasNativeContext) {
        throw StateError('Cannot access meshAssetCache without active Filament native context.');
      }
      _meshAssetCache = LuminaWorldMeshCache(LuminaMeshAssetCache.forEngine(_filamentEngine!), _filamentScene!);
    }
    return _meshAssetCache!;
  }

  LuminaMaterialCache? _materialCache;

  /// Refcounted material cache for this world's native Filament context.
  LuminaMaterialCache get materialCache {
    if (_materialCache == null) {
      if (!hasNativeContext) {
        throw StateError('Cannot access materialCache without active Filament native context.');
      }
      _materialCache = LuminaMaterialCache(world: this, engine: _filamentEngine!);
    }
    return _materialCache!;
  }

  /// Whether [beginPlay] has already been called on this world.
  bool get hasBegunPlay => _hasBegunPlay;

  final List<LuminaPlayerController> _playerControllers = [];

  /// The controllers of the players the game mode has logged in, in login
  /// order. A controller is listed from
  /// its login on, before its pawn's buffered spawn registers.
  List<LuminaPlayerController> get playerControllers => List.unmodifiable(_playerControllers);

  /// Whether the game mode has logged a player in ([notifyPostLogin]).
  bool get hasLoggedInPlayer => _playerControllers.isNotEmpty;

  /// Tells every level's script actor that [controller]'s player has logged
  /// in and got its pawn (Post Login). [LuminaGameMode.login] calls
  /// it, so a Level Blueprint's BeginPlay sees the player in Play-In-Editor
  /// as in a built game.
  void notifyPostLogin(LuminaPlayerController controller) {
    if (!_playerControllers.contains(controller)) _playerControllers.add(controller);
    for (final level in levels) {
      level.scriptActor?.onPostLogin(controller);
    }
  }

  /// Forgets [controller]'s player ([LuminaGameMode.logout]).
  void notifyLogout(LuminaPlayerController controller) => _playerControllers.remove(controller);

  /// All active registered actors across persistent and visible streaming levels.
  List<LuminaActor> get actors {
    final result = <LuminaActor>[...persistentLevel.actors];
    for (final level in streamingLevels) {
      if (level.state == LevelState.visible) {
        result.addAll(level.actors);
      }
    }
    return result;
  }

  // Debug test seams for double-buffering verification
  List<dynamic> get debugActiveSpawnBuffer => _activeSpawnBuffer;
  List<dynamic> get debugSecondarySpawnBuffer =>
      (_activeSpawnBuffer == _pendingSpawnA) ? _pendingSpawnB : _pendingSpawnA;
  List<LuminaActor> get debugActiveDestroyBuffer => _activeDestroyBuffer;
  List<LuminaActor> get debugSecondaryDestroyBuffer =>
      (_activeDestroyBuffer == _pendingDestroyA) ? _pendingDestroyB : _pendingDestroyA;
  int get debugAllocatedBufferCount => 4;

  FilamentView? _filamentView;
  LuminaPostProcessController? _postProcessController;

  /// Post-process volume blending over the bound view's single
  /// post-processing state: the height fog component and
  /// the post-process / local fog volumes publish here; the world resolves
  /// and applies the result at the end of every tick.
  final LuminaPostProcessBlender postProcessBlender = LuminaPostProcessBlender();

  /// The settings the blender last applied, or null when nothing was.
  LuminaPostProcessSettings? _blendApplied;
  double? _blendFocusDistance;

  /// Binds [view] for post-processing only — the world does not take over the
  /// view's camera (the editor viewport and Play-In-Editor keep theirs). The
  /// blender then applies to it every tick.
  void attachPostProcessView(FilamentView view) {
    if (_isCleanedUp) {
      throw StateError('Cannot attach a post-process view on a cleaned-up world.');
    }
    view.setDynamicLightingOptions(LuminaUnits.dynamicLightingNear, LuminaUnits.dynamicLightingFar);
    _postProcessController = LuminaPostProcessController(
      world: this,
      engine: filamentEngine,
      view: view,
    );
    _blendApplied = null;
    _blendFocusDistance = null;
  }

  /// The camera position the blender evaluates volumes at (runtime axes):
  /// the active camera component, else [LuminaPostProcessBlender.cameraPositionOverride].
  Vector3? get postProcessCameraPosition =>
      activeCamera?.worldLocation ?? postProcessBlender.cameraPositionOverride;

  /// Resolves the blender for the current camera and applies the result when
  /// it changed. Runs for every world type that renders (editor and game).
  void _applyPostProcessBlend() {
    final controller = _postProcessController;
    if (controller == null) return;
    final result = postProcessBlender.resolve(postProcessCameraPosition);
    if (_blendApplied != result.settings) {
      controller.apply(result.settings, asBaseline: false);
      _blendApplied = result.settings;
    }
    final focus = result.focusDistance;
    if (focus != null && focus != _blendFocusDistance) {
      final camera = controller.view.camera;
      if (camera != null) camera.focusDistance = focus;
      _blendFocusDistance = focus;
    } else if (focus == null) {
      _blendFocusDistance = null;
    }
  }

  /// The bound native Filament view, or null if unbound.
  FilamentView? get filamentViewOrNull => _filamentView;

  /// The post-process controller for this world. Throws [StateError] if no FilamentView is bound.
  LuminaPostProcessController get postProcess {
    if (_postProcessController == null) {
      throw StateError('Cannot access postProcess without an active bound FilamentView.');
    }
    return _postProcessController!;
  }

  /// Binds native Filament engine and scene handles (and optional view) to this world.
  ///
  /// **Ownership Contract**: The world borrows these references and will detach its entities
  /// on [cleanup], but does NOT own their creation or destruction.
  void initializeNativeContext(
    FilamentEngine engine,
    FilamentScene scene, {
    FilamentView? view,
  }) {
    if (_isCleanedUp) {
      throw StateError('Cannot initialize native context on a cleaned-up world.');
    }
    if (_filamentEngine != null || _filamentScene != null) {
      throw StateError('Native context is already initialized. Call cleanup() before re-binding.');
    }
    _filamentEngine = engine;
    _filamentScene = scene;
    _filamentView = view;
    if (view != null) {
      // The froxel light grid in centimetres, as [bindView] sets it: left at
      // Filament's 5–100 unit default, point and spot lights further than
      // 1 m from the game's camera lit nothing.
      view.setDynamicLightingOptions(LuminaUnits.dynamicLightingNear, LuminaUnits.dynamicLightingFar);
      _dynamicLightingRange = (LuminaUnits.dynamicLightingNear, LuminaUnits.dynamicLightingFar);
      _postProcessController = LuminaPostProcessController(
        world: this,
        engine: engine,
        view: view,
      );
    }
  }

  (double, double)? _dynamicLightingRange;

  /// The froxel light range last applied to the bound view (near, far).
  (double, double)? get dynamicLightingRange => _dynamicLightingRange;

  /// Binds a native [FilamentView] to this world and initializes the post-process controller.
  void bindView(FilamentView view) {
    if (_isCleanedUp) {
      throw StateError('Cannot bind view on a cleaned-up world.');
    }
    _filamentView = view;
    _viewCameraSource = null;
    // Froxel lights cover 10 cm – 500 m of the centimetre world.
    view.setDynamicLightingOptions(LuminaUnits.dynamicLightingNear, LuminaUnits.dynamicLightingFar);
    _dynamicLightingRange = (LuminaUnits.dynamicLightingNear, LuminaUnits.dynamicLightingFar);
    _postProcessController = LuminaPostProcessController(
      world: this,
      engine: filamentEngine,
      view: view,
    );
  }

  /// The active primary camera component in this world, if one exists.
  LuminaCameraComponent? get activeCamera {
    final allLevels = [persistentLevel, ...streamingLevels];
    for (final level in allLevels) {
      for (final actor in level.actors) {
        for (final comp in actor.components) {
          if (comp is LuminaCameraComponent && comp.isActive) {
            return comp;
          }
        }
      }
    }
    return null;
  }

  LuminaScalabilityProfile? _appliedScalability;

  /// The currently applied engine scalability profile, or null if unconfigured.
  LuminaScalabilityProfile? get appliedScalability => _appliedScalability;

  ShadowOptions? _stagedSunShadowOptions;

  /// The staged sun shadow options computed from scalability/shadow settings.
  ShadowOptions? get stagedSunShadowOptions => _stagedSunShadowOptions;

  /// Pushes updated [shadowOpts] to all shadow-casting directional sun lights in this world.
  void updateDirectionalLightShadows(ShadowOptions shadowOpts) {
    _stagedSunShadowOptions = shadowOpts;
    final allLevels = [persistentLevel, ...streamingLevels];
    for (final level in allLevels) {
      for (final actor in level.actors) {
        for (final comp in actor.components) {
          if (comp is LuminaDirectionalLightComponent && comp.castShadows) {
            comp.shadowOptions = shadowOpts;
          }
        }
      }
    }
  }

  /// Applies a full engine scalability profile across post-processing and lighting.
  void applyScalability(LuminaScalabilityProfile profile) {
    if (hasNativeContext && _postProcessController != null) {
      // From the baseline, not the (possibly volume-blended) applied state,
      // or a bloom volume the camera stands in would become permanent.
      final currentPp = postProcess.baseline;
      final newPp = currentPp.copyWith(
        renderQuality: profile.renderQuality,
        dynamicResolution: profile.dynamicResolution,
        taa: profile.taa,
        msaa: profile.msaa,
        antiAliasing: profile.antiAliasing,
      );
      postProcess.apply(newPp);
      postProcess.applyShadowSettings(profile.shadows);
    } else {
      try {
        _stagedSunShadowOptions = profile.shadows.toShadowOptions(
          cameraNear: 10.0,
          cameraFar: 10000.0,
        );
      } catch (_) {
        // In headless unit tests without native assets, staging shadow options is skipped.
      }
    }
    _appliedScalability = profile;
  }

  /// Registers a subsystem with this world.
  T registerSubsystem<T extends LuminaWorldSubsystem>(T subsystem) {
    subsystems.registerSubsystem<T>(subsystem, this);
    return subsystem;
  }

  /// Retrieves a registered subsystem of type [T] from this world.
  T? getSubsystem<T extends LuminaWorldSubsystem>() {
    return subsystems.getSubsystem<T>();
  }

  /// The user settings and scalability subsystem for this world.
  LuminaUserSettingsSubsystem get userSettings =>
      getSubsystem<LuminaUserSettingsSubsystem>() ??
      registerSubsystem<LuminaUserSettingsSubsystem>(LuminaUserSettingsSubsystem());

  /// Spawns an actor into [level] (defaulting to [persistentLevel]), deferred to Phase 5.
  T spawnActor<T extends LuminaActor>(T actor, {LuminaLevel? level}) {
    final targetLevel = level ?? persistentLevel;
    _activeSpawnBuffer.add(_PendingSpawnItem(actor, targetLevel));
    return actor;
  }

  /// Spawns [actor] into [level] (default: the persistent level) right now:
  /// registered, initialised and, once the world plays, begun — the
  /// Spawn Actor Blueprints use so the spawned actor can be used on the
  /// same exec chain. Safe during a tick: the levels hand out
  /// copies of their actor lists.
  T spawnActorImmediately<T extends LuminaActor>(T actor, {LuminaLevel? level}) {
    if (_isCleanedUp) throw StateError('Cannot spawn into a cleaned-up world.');
    final targetLevel = level ?? persistentLevel;
    targetLevel.registerActor(actor);
    if (!actor.isRegistered) actor.onRegister(this);
    if (!actor.isInitialized) actor.onInitialize();
    if (worldType.runsGameplay && _hasBegunPlay && !actor.hasBegunPlay) actor.onBeginPlay();
    return actor;
  }

  /// Schedules an actor for destruction, deferred to Phase 5. The actor's
  /// Destroyed and End Play (reason Destroyed) hooks run when it is removed.
  void destroyActor(LuminaActor actor) {
    actor.markPendingDestroy();
    if (!_activeDestroyBuffer.contains(actor)) _activeDestroyBuffer.add(actor);
  }

  /// Initializes gameplay state and triggers [beginPlay] across subsystems and actors.
  void beginPlay() {
    if (_hasBegunPlay) return;
    _hasBegunPlay = true;
    
    if (worldType.runsGameplay) {
      gameMode?.initGame(this);
    }

    persistentLevel.notifyLevelLoaded();
    for (final level in streamingLevels) {
      level.notifyLevelLoaded();
    }

    if (!worldType.runsGameplay) {
      return;
    }

    subsystems.notifyBeginPlay();

    for (final actor in persistentLevel.actors) {
      if (!actor.isInitialized) actor.onInitialize();
      if (!actor.hasBegunPlay) actor.onBeginPlay();
    }

    for (final level in streamingLevels) {
      if (level.state == LevelState.visible) {
        for (final actor in level.actors) {
          if (!actor.isInitialized) actor.onInitialize();
          if (!actor.hasBegunPlay) actor.onBeginPlay();
        }
      }
    }
  }

  /// Executes the 5-phase Deterministic Tick Pipeline for each frame update.
  ///
  /// Returns immediately (no phases, no [onPreTick], no [tickCount] increment) while [isPaused].
  void tick(double deltaTime) {
    if (_isCleanedUp) {
      throw StateError('Cannot tick a cleaned-up world.');
    }
    if (_isPaused) return;
    step(deltaTime);
  }

  /// Executes exactly one full 5-phase tick regardless of [isPaused] (the pause flag is untouched).
  void step(double deltaTime) {
    if (_isCleanedUp) {
      throw StateError('Cannot tick a cleaned-up world.');
    }
    if (_isTicking) {
      throw StateError('Re-entrant world tick is not allowed.');
    }
    if (worldType.runsGameplay && !_hasBegunPlay) {
      throw StateError('Cannot tick world before beginPlay() is called.');
    }

    _isTicking = true;
    // Real time first: the stats and the debug records live in real time;
    // gameplay below gets the dilated delta.
    final realDelta = deltaTime;
    _realTimeSeconds += realDelta;
    _lastFrameTimeMs = realDelta * 1000.0;
    if (realDelta > 0.0) {
      final fps = 1.0 / realDelta;
      final alpha = (realDelta / 0.5).clamp(0.0, 1.0);
      _frameRate = _frameRate == 0.0 ? fps : _frameRate + (fps - _frameRate) * alpha;
    }
    _expireDebugRecords();
    deltaTime = realDelta * _timeDilation;
    _lastDeltaSeconds = deltaTime;
    _timeSeconds += deltaTime;
    _tickCount++;
    try {
      onPreTick?.call(deltaTime);
      _prePhysicsTick(deltaTime);
      _physicsAndSubsystemUpdate(deltaTime);
      _actorTick(deltaTime);
      _postPhysicsRenderPrep(deltaTime);
      _executeDeferredCommands();
    } finally {
      _isTicking = false;
    }
  }

  void _prePhysicsTick(double deltaTime) {
    onPhaseExecuted?.call('prePhysics');
    buildOwner?.flushBuild();
  }

  void _physicsAndSubsystemUpdate(double deltaTime) {
    onPhaseExecuted?.call('subsystemTick');
    
    if (worldType.runsGameplay) {
      gameState?.tick(deltaTime);
    }

    if (worldType.ticksSubsystems) {
      subsystems.notifyTick(deltaTime);
    }
  }

  void _actorTick(double deltaTime) {
    if (!worldType.runsGameplay) return;

    // An actor registered into the persistent level after the world began
    // play (a pawn added to a running scene, a declarative rebuild,
    // a save-game factory) begins play here, before any actor ticks, as a
    // streaming level's actors do below; spawnActor / spawnActorImmediately
    // begin theirs on spawn.
    final persistentActors = persistentLevel.actors;
    for (final actor in persistentActors) {
      if (actor.hasBegunPlay || actor.isPendingDestroy) continue;
      if (!actor.isInitialized) actor.onInitialize();
      actor.onBeginPlay();
    }
    for (final actor in persistentActors) {
      if (actor.isInitialized && actor.hasBegunPlay) {
        actor.onTick(deltaTime);
      }
    }
    for (final level in streamingLevels) {
      if (level.state == LevelState.visible) {
        level.notifyLevelLoaded();
        for (final actor in level.actors) {
          if (!actor.isInitialized) actor.onInitialize();
          if (!actor.hasBegunPlay) actor.onBeginPlay();
          if (actor.isInitialized && actor.hasBegunPlay) {
            actor.onTick(deltaTime);
          }
        }
      }
    }

    if (killZ != null) {
      final kz = killZ!;
      final toKill = <LuminaActor>[];
      for (final actor in persistentLevel.actors) {
        if (actor.actorLocation.y < kz) {
          toKill.add(actor);
        }
      }
      for (final level in streamingLevels) {
        if (level.state == LevelState.visible) {
          for (final actor in level.actors) {
            if (actor.actorLocation.y < kz) {
              toKill.add(actor);
            }
          }
        }
      }
      for (final actor in toKill) {
        if (actor.bCanBeDamaged) {
          actor.takeDamage(1e9);
        }
        destroyActor(actor);
        onActorFellOutOfWorld?.call(actor);
      }
    }
  }

  void _postPhysicsRenderPrep(double deltaTime) {
    onPhaseExecuted?.call('renderPrep');
    if (worldType.runsRenderPrep) {
      for (final actor in persistentLevel.actors) {
        actor.onRenderPrep(this);
        onRenderPrepCallback?.call(actor);
      }
      for (final level in streamingLevels) {
        if (level.state == LevelState.visible) {
          for (final actor in level.actors) {
            actor.onRenderPrep(this);
            onRenderPrepCallback?.call(actor);
          }
        }
      }
      _syncViewCamera();
      _applyPostProcessBlend();
    }
  }

  LuminaCameraComponent? _viewCameraSource;
  (int, int)? _viewCameraViewportSize;

  /// The bound view's size in pixels, for `Get Viewport Size` and the screen
  /// projections; the host sets it, the bound view updates it.
  (int, int) viewportSize = (1280, 720);

  /// The point of view the player camera manager asks the world to render
  /// from instead of [activeCamera]: another view target or a running blend.
  /// Null: the active camera component is rendered as usual.
  LuminaMinimalViewInfo? viewTargetPov;

  /// What the bound view renders from this frame: [viewTargetPov] when set,
  /// else the active camera component's transform and FOV; null without a
  /// camera. Runtime axes.
  ({Vector3 location, Quaternion rotation, double fovDegrees})? get viewPov {
    final override = viewTargetPov;
    if (override != null) {
      return (location: override.location.clone(), rotation: override.rotation.clone(), fovDegrees: override.fovDegrees);
    }
    final camera = activeCamera;
    if (camera == null) return null;
    return (location: camera.worldLocation, rotation: camera.worldRotation, fovDegrees: camera.fieldOfViewInDegrees);
  }

  /// Points the bound view's camera through [activeCamera], once every
  /// transform of the frame is final. Projection and exposure are pushed again
  /// whenever the viewport or the active camera changes, since the view's
  /// owner may reset its camera's projection on a resize.
  void _syncViewCamera() {
    final view = _filamentView;
    if (view == null || !hasNativeContext) return;
    final camera = activeCamera;
    final target = view.camera;
    final (_, _, width, height) = view.viewport;
    if (target == null || width <= 0 || height <= 0) return;
    viewportSize = (width, height);
    final override = viewTargetPov;
    if (override != null) {
      // A view target or blend: look from the manager's POV, and let the
      // camera component re-sync everything once it is in charge again.
      _viewCameraSource = null;
      final eye = override.location;
      final forward = override.rotation.rotateVector(Vector3(0, 0, -1));
      final up = override.rotation.rotateVector(Vector3(0, 1, 0));
      // A camera view target (a placed camera actor) is seen through its
      // own lens: projection, clip planes and exposure; the pose and field of
      // view stay the manager's (shakes, FOV overrides).
      final lens = override.camera;
      final aspect = width / height;
      final near = lens?.nearClipPlane ?? camera?.nearClipPlane ?? override.nearClip;
      final far = lens?.farClipPlane ?? camera?.farClipPlane ?? override.farClip;
      if (lens != null && lens.projectionMode == CameraProjectionMode.orthographic) {
        final halfWidth = lens.orthographicWidth * 0.5;
        final halfHeight = halfWidth / aspect;
        target.setProjectionOrtho(left: -halfWidth, right: halfWidth, bottom: -halfHeight, top: halfHeight, near: near, far: far);
      } else {
        target.setProjection(fovDegrees: override.fovDegrees, aspect: aspect, near: near, far: far);
      }
      if (lens != null) {
        LuminaAutoExposure.applyTo(lens, LuminaAutoExposure.ev100ForWorld(this));
        target.setExposure(aperture: lens.aperture, shutterSpeed: lens.shutterSpeed, sensitivity: lens.sensitivity);
      }
      target.lookAt(
        eyeX: eye.x, eyeY: eye.y, eyeZ: eye.z,
        centerX: eye.x + forward.x, centerY: eye.y + forward.y, centerZ: eye.z + forward.z,
        upX: up.x, upY: up.y, upZ: up.z,
      );
      return;
    }
    if (camera == null) return;
    if (!identical(camera, _viewCameraSource) || _viewCameraViewportSize != (width, height)) {
      camera.invalidateNativeSync();
      _viewCameraSource = camera;
      _viewCameraViewportSize = (width, height);
    }
    camera.aspectRatio = width / height;
    // Auto-exposed for the level's lights:
    // a lamp-lit level is not rendered at sunny 16.
    LuminaAutoExposure.applyTo(camera, LuminaAutoExposure.ev100ForWorld(this));
    camera.syncWithFilamentCamera(target);
  }

  void _executeDeferredCommands() {
    onPhaseExecuted?.call('deferredCommands');

    // 1. Swap and drain spawn buffer
    final toSpawn = _activeSpawnBuffer;
    _activeSpawnBuffer = (_activeSpawnBuffer == _pendingSpawnA) ? _pendingSpawnB : _pendingSpawnA;

    // Drain a snapshot so a throwing actor can never replay the buffer on the
    // next swap; the level owns registration (LuminaLevel.registerActor calls
    // onRegister when it is attached to a world), the world only fills in
    // for detached levels.
    final spawnBatch = List.of(toSpawn);
    toSpawn.clear();
    Object? firstError;
    StackTrace? firstStack;
    for (final item in spawnBatch) {
      final actor = item.actor;
      final targetLevel = item.targetLevel;
      try {
        targetLevel.registerActor(actor);
        if (!actor.isRegistered) {
          actor.onRegister(this);
        }
        actor.onInitialize();
        if (worldType.runsGameplay) {
          actor.onBeginPlay();
        }
      } catch (e, st) {
        // Keep spawning the rest of the batch; surface the first failure once.
        firstError ??= StateError('spawnActor failed for ${actor.runtimeType}: $e');
        firstStack ??= st;
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStack!);
    }

    // 2. Swap and drain destroy buffer
    final toDestroy = _activeDestroyBuffer;
    _activeDestroyBuffer = (_activeDestroyBuffer == _pendingDestroyA) ? _pendingDestroyB : _pendingDestroyA;

    for (final actor in toDestroy) {
      if (actor.owningLevel != null) {
        actor.owningLevel!.unregisterActor(actor);
      } else {
        persistentLevel.unregisterActor(actor);
      }
    }
    toDestroy.clear();
  }

  /// Releases resources and cleans up native scene bindings.
  ///
  /// The world detaches its references but does NOT destroy the native Filament engine/scene.
  void cleanup() {
    if (_isCleanedUp) return;
    _isCleanedUp = true;

    _pendingSpawnA.clear();
    _pendingSpawnB.clear();
    _pendingDestroyA.clear();
    _pendingDestroyB.clear();

    // Unregister actors in reverse order across all levels
    for (final level in streamingLevels.reversed) {
      level.unloadActors();
    }
    persistentLevel.unloadActors();

    streamingLevels.clear();
    subsystems.shutdown();
    entityRegistry.clear();
    LuminaViewportStatics.cancelAllPending('World cleaned up');

    // Only this world's meshes: the cache is the engine's, shared with
    // other worlds and viewports, and dies with the engine.
    _meshAssetCache?.close();
    _meshAssetCache = null;

    _materialCache?.dispose();
    _materialCache = null;

    _appliedScalability = null;
    _stagedSunShadowOptions = null;

    _postProcessController?.dispose();
    _postProcessController = null;
    _blendApplied = null;
    _blendFocusDistance = null;
    postProcessBlender.clearVolumes();
    _filamentView = null;
    _viewCameraSource = null;
    _viewCameraViewportSize = null;

    _filamentScene = null;
    _filamentEngine = null;
  }

  @override
  LuminaObject? build(LuminaBuildContext context) {
    return persistentLevel;
  }
}
