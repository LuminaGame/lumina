import 'package:flutter/foundation.dart';
import 'package:flutter_filament/flutter_filament.dart';
import '../world/world.dart';
import '../controller/player_controller.dart';
import '../world/level.dart';

/// Base class for global, lifetime-bound services attached to a [LuminaGameInstance].
abstract class LuminaGameInstanceSubsystem {
  LuminaGameInstance? _owner;
  bool _isInitialized = false;

  /// The game instance this subsystem is bound to.
  LuminaGameInstance? get owner => _owner;

  /// Whether this subsystem has been initialized.
  bool get isInitialized => _isInitialized;

  /// Called when the subsystem is registered with the game instance.
  void onInitialize(LuminaGameInstance owner) {
    _owner = owner;
    _isInitialized = true;
  }

  /// Called when the game instance is shutting down.
  void onDeinitialize() {
    _owner = null;
    _isInitialized = false;
  }
}

/// The engine-lifetime singleton surviving world transitions.
class LuminaGameInstance extends ChangeNotifier {
  /// The instance of the running game, set by [init] and cleared by
  /// [shutdown]: what `Get Game Instance` returns.
  static LuminaGameInstance? current;

  LuminaWorld? _world;
  FilamentEngine? _filamentEngine;
  FilamentScene? _filamentScene;
  FilamentView? _filamentView;
  
  final Map<Type, LuminaGameInstanceSubsystem> _subsystems = {};
  final List<LuminaGameInstanceSubsystem> _subsystemRegistrationOrder = [];
  
  LuminaPlayerController? _primaryPlayerController;

  void Function(LuminaWorld? oldWorld, LuminaWorld? newWorld)? onWorldChanged;

  /// The currently mounted world (null before mount / during transition).
  LuminaWorld? get world => _world;

  /// The local player's controller, created once at first world mount.
  LuminaPlayerController? get primaryPlayerController => _primaryPlayerController;

  /// Initializes the game instance and its subsystems.
  void init() {
    // Subsystem initialization can happen here if they are pre-registered
    current = this;
  }

  /// Called after the last world is cleaned up to deinitialize subsystems.
  void shutdown() {
    if (identical(current, this)) current = null;
    for (final subsystem in _subsystemRegistrationOrder.reversed) {
      subsystem.onDeinitialize();
    }
    _subsystems.clear();
    _subsystemRegistrationOrder.clear();
    _filamentEngine = null;
    _filamentScene = null;
    _primaryPlayerController = null;
  }

  /// Registers a subsystem with the game instance.
  void registerSubsystem<T extends LuminaGameInstanceSubsystem>(T subsystem) {
    if (_subsystems.containsKey(T)) {
      throw StateError('Subsystem of type $T is already registered.');
    }
    _subsystems[T] = subsystem;
    _subsystemRegistrationOrder.add(subsystem);
    subsystem.onInitialize(this);
  }

  /// Retrieves a registered subsystem by type.
  T? getSubsystem<T extends LuminaGameInstanceSubsystem>() {
    return _subsystems[T] as T?;
  }
  
  /// Called by the Game to establish native context before first world mount.
  /// The [view], when given, is bound into every world this instance opens, so
  /// the world renders through its active camera.
  void setNativeContext(FilamentEngine engine, FilamentScene scene, {FilamentView? view}) {
    _filamentEngine = engine;
    _filamentScene = scene;
    _filamentView = view;
  }

  /// Sets the initial world.
  void setInitialWorld(LuminaWorld newWorld) {
    _world = newWorld;
    _primaryPlayerController ??= LuminaPlayerController();
  }

  /// Replaces the current world with [newWorld] (used by `LuminaGame.restart`).
  ///
  /// Cleans up the old world, installs the new one, unpossesses the retained
  /// [primaryPlayerController], then fires [onWorldChanged] and notifies listeners.
  /// Unlike [openLevel] the caller owns the new world's native context and level tree.
  void replaceWorld(LuminaWorld newWorld) {
    final oldWorld = _world;
    if (identical(oldWorld, newWorld)) return;
    oldWorld?.cleanup();
    _world = newWorld;
    _primaryPlayerController ??= LuminaPlayerController();
    _primaryPlayerController!.unpossess();
    onWorldChanged?.call(oldWorld, newWorld);
    notifyListeners();
  }

  /// Disposes the current world and creates a new one.
  Future<void> openLevel(LuminaLevel Function() levelBuilder) async {
    final oldWorld = _world;
    oldWorld?.cleanup();

    final newWorld = LuminaWorld(initialLevel: levelBuilder());
    newWorld.initializeNativeContext(_filamentEngine!, _filamentScene!, view: _filamentView);
    
    _world = newWorld;

    if (_primaryPlayerController != null) {
      _primaryPlayerController!.unpossess();
      if (newWorld.gameMode != null) {
        newWorld.gameMode!.gameState.addPlayerState(_primaryPlayerController!.playerState);
        newWorld.gameMode!.restartPlayer(_primaryPlayerController!);
      }
    }

    onWorldChanged?.call(oldWorld, newWorld);
    notifyListeners();
  }
}
