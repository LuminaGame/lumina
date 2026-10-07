import 'package:lumina/src/controller/player_controller.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/world/level.dart';

/// Special actor attached to a level for executing level-specific scenarios and events.
class LuminaLevelScriptActor extends LuminaActor {
  bool _hasLevelLoaded = false;
  bool _hasLevelUnloaded = false;

  LuminaLevelScriptActor({super.key});

  /// The owning level for this script actor.
  LuminaLevel? get level => owningLevel;

  /// Whether [onLevelLoaded] has already been called.
  bool get hasLevelLoaded => _hasLevelLoaded;

  /// Whether [onLevelUnloaded] has already been called.
  bool get hasLevelUnloaded => _hasLevelUnloaded;

  /// Called exactly once when the owning level finishes loading,
  /// before any actor in the level receives `onBeginPlay`.
  void onLevelLoaded() {
    _hasLevelLoaded = true;
  }

  /// Called when the world's game mode has logged [controller]'s player in
  /// and spawned its pawn (Post Login; [LuminaWorld.notifyPostLogin]).
  /// A level script that must see the player on BeginPlay waits for
  /// it.
  void onPostLogin(LuminaPlayerController controller) {}

  /// Called exactly once when the level begins teardown/unload,
  /// after all other actors in the level have been unregistered.
  void onLevelUnloaded() {
    _hasLevelUnloaded = true;
  }

  @override
  void onUnregister() {
    _hasLevelLoaded = false;
    _hasLevelUnloaded = false;
    super.onUnregister();
  }
}
