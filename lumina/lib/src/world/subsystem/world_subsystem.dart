import 'package:lumina/src/world/world.dart';
export 'package:lumina/src/world/subsystem/subsystem_collection.dart';
export 'package:lumina/src/world/subsystem/physics_world_subsystem.dart';
export 'package:lumina/src/world/subsystem/widget_subsystem.dart';
export 'package:lumina/src/world/subsystem/user_settings_subsystem.dart';

/// Base class for global, lifetime-bound services attached to a [LuminaWorld].
abstract class LuminaWorldSubsystem {
  LuminaWorld? _world;
  bool _isInitialized = false;

  /// The world instance this subsystem is bound to.
  LuminaWorld? get world => _world;

  /// Whether this subsystem has been initialized.
  bool get isInitialized => _isInitialized;

  /// Called when the subsystem is registered with the world.
  void onWorldInitialize(LuminaWorld world) {
    _world = world;
    _isInitialized = true;
  }

  /// Called when gameplay begins in the world.
  void onWorldBeginPlay() {}

  /// Called on each frame during Phase 2 of the world tick pipeline.
  void onWorldTick(double deltaTime) {}

  /// Called when [LuminaWorld.isPaused] changes (`true` = paused, `false` = resumed).
  void onWorldPauseChanged(bool paused) {}

  /// Called when the world is shutting down or cleaned up.
  void onWorldShutdown() {
    _world = null;
    _isInitialized = false;
  }
}
