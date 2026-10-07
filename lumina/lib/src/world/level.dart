import 'package:lumina/src/declarative/lumina_object.dart';
import 'package:lumina/src/declarative/build_context.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/world/level_script_actor.dart';
import 'package:lumina/src/world/world.dart';

/// 7-state asynchronous streaming and lifecycle state for a [LuminaLevel].
enum LevelState {
  unloaded,
  loading,
  loaded,
  makingVisible,
  visible,
  makingInvisible,
  unloading,
}

/// Container holding actors, script actors, and scene graph state for a level.
class LuminaLevel extends LuminaObject {
  /// The level's name as `Get Current Level Name` reports it:
  /// the asset's base name; '' for an unnamed level.
  String levelName = '';

  final List<LuminaActor> _actors = [];
  final List<LuminaObject> _declarativeChildren;
  final String? name;
  LuminaLevelScriptActor? _scriptActor;
  LevelState state;
  LuminaWorld? owningWorld;
  bool _isLevelLoadedNotified = false;

  /// Effective name for level identification in save games and streaming.
  String get effectiveName => name ?? key?.toString() ?? 'DefaultLevel';

  LuminaLevel({
    super.key,
    this.name,
    List<LuminaObject> children = const [],
    LuminaLevelScriptActor? scriptActor,
    this.state = LevelState.unloaded,
  }) : _declarativeChildren = children {
    if (scriptActor != null) this.scriptActor = scriptActor;
  }

  /// The level's script actor: told [LuminaLevelScriptActor.onLevelLoaded]
  /// before any actor's BeginPlay, unloaded last. Settable so a host that
  /// builds the level's actors itself — Play-In-Editor, the generated game —
  /// can attach the level's Blueprint script; the new script
  /// is registered into this level.
  LuminaLevelScriptActor? get scriptActor => _scriptActor;
  set scriptActor(LuminaLevelScriptActor? script) {
    if (identical(script, _scriptActor)) return;
    _scriptActor = script;
    if (script != null) registerActor(script);
  }

  /// Whether the level is currently visible and active in the world.
  bool get isVisible => state == LevelState.visible;

  /// Unmodifiable view of registered actors in this level.
  List<LuminaActor> get actors => List.unmodifiable(_actors);

  /// Registers an actor into this level, establishing ownership.
  void registerActor(LuminaActor actor) {
    if (_actors.contains(actor)) return;
    if (actor.owningLevel != null && actor.owningLevel != this) {
      actor.owningLevel!.unregisterActor(actor);
    }
    _actors.add(actor);
    actor.owningLevel = this;
    if (owningWorld != null && !actor.isRegistered) {
      actor.onRegister(owningWorld!);
    }
  }

  /// Unregisters an actor from this level, firing [onUnregister] and clearing ownership.
  void unregisterActor(LuminaActor actor) {
    if (_actors.remove(actor)) {
      actor.onUnregister();
    }
  }

  /// Notifies the script actor that the level has finished loading.
  void notifyLevelLoaded() {
    if (_isLevelLoadedNotified || scriptActor == null) return;
    _isLevelLoadedNotified = true;

    if (owningWorld != null && !scriptActor!.isRegistered) {
      scriptActor!.onRegister(owningWorld!);
    }
    if (!scriptActor!.isInitialized) {
      scriptActor!.onInitialize();
    }
    scriptActor!.onLevelLoaded();
  }

  /// Unloads all actors in reverse registration order, unregisters scriptActor, and resets state.
  void unloadActors() {
    // Unregister other actors first in reverse registration order
    for (final actor in List<LuminaActor>.from(_actors.reversed)) {
      if (actor != scriptActor) {
        unregisterActor(actor);
      }
    }

    // Notify and unregister script actor last
    if (scriptActor != null) {
      scriptActor!.onLevelUnloaded();
      unregisterActor(scriptActor!);
    }

    _actors.clear();
    _isLevelLoadedNotified = false;
    owningWorld = null;
    state = LevelState.unloaded;
  }

  @override
  LuminaObject? build(LuminaBuildContext context) {
    if (_declarativeChildren.isEmpty) return null;
    return LuminaNodeGroup(children: _declarativeChildren);
  }
}
