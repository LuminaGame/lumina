part of '../blueprint_vm.dart';

/// A Blueprint with parent `LuminaActor`.
class LuminaBlueprintActor extends LuminaActor with LuminaBlueprintRuntime, LuminaBlueprintInstance {
  LuminaBlueprintActor._(LuminaBlueprintClass cls, {super.key, super.location, super.rotation});
}

/// A Blueprint with parent `LuminaPawn`.
class LuminaBlueprintPawn extends LuminaPawn with LuminaBlueprintRuntime, LuminaBlueprintInstance {
  LuminaBlueprintPawn._(LuminaBlueprintClass cls, {super.key, super.location, super.rotation});

  @override
  void possessedBy(LuminaController newController) {
    super.possessedBy(newController);
    _bindInput();
  }

  @override
  void unpossessed() {
    unbindBlueprintInput();
    super.unpossessed();
  }
}

/// A Blueprint with parent `LuminaCharacter`.
class LuminaBlueprintCharacter extends LuminaCharacter with LuminaBlueprintRuntime, LuminaBlueprintInstance {
  LuminaBlueprintCharacter._(LuminaBlueprintClass cls, {super.key, super.location, super.rotation});

  @override
  void possessedBy(LuminaController newController) {
    super.possessedBy(newController);
    _bindInput();
  }

  @override
  void unpossessed() {
    unbindBlueprintInput();
    super.unpossessed();
  }
}

/// A Level Blueprint's script actor: the level's
/// [LuminaLevelScriptActor] running its graph in the VM. Event BeginPlay /
/// Event Level BeginPlay, Tick, End Play, Level Loaded (before any other
/// actor's BeginPlay) and Level Unloaded; `Get <Actor>` finds the
/// level's placed actors by name. Never spawnable from a class.
class LuminaBlueprintLevelScript extends LuminaLevelScriptActor
    with LuminaBlueprintRuntime, LuminaBlueprintInstance, LuminaBlueprintLevelActors {
  LuminaBlueprintLevelScript._(LuminaBlueprintClass cls, {super.key})
      : levelActorIds = {for (final a in cls.levelActors ?? const <LuminaBlueprintLevelActorRef>[]) a.name: a.id};

  @override
  final Map<String, String> levelActorIds;

  bool _levelBeginPlayPending = false;

  /// Event (Level) BeginPlay waits for the local player: while the
  /// world has a game mode that has logged no one in yet — Play-In-Editor
  /// logs in right after `beginPlay` — it runs on [onPostLogin], or on the
  /// first tick if no one logs in. A built game logs in inside its script's
  /// BeginPlay, ahead of the graph, so both see the player's pawn.
  @override
  void onBeginPlay() {
    super.onBeginPlay();
    final w = world;
    if (w != null && w.gameMode != null && !w.hasLoggedInPlayer) {
      _levelBeginPlayPending = true;
      return;
    }
    _dispatch(LuminaBlueprintNodeLibrary.eventLevelBeginPlay, 'exec_out', const {});
  }

  void _runPendingLevelBeginPlay() {
    if (!_levelBeginPlayPending) return;
    _levelBeginPlayPending = false;
    _dispatch(LuminaBlueprintNodeLibrary.eventLevelBeginPlay, 'exec_out', const {});
  }

  @override
  void onPostLogin(LuminaPlayerController controller) {
    super.onPostLogin(controller);
    _runPendingLevelBeginPlay();
  }

  @override
  void onTick(double deltaTime) {
    _runPendingLevelBeginPlay();
    super.onTick(deltaTime);
    _dispatch(LuminaBlueprintNodeLibrary.eventLevelTick, 'exec_tick_out', {'delta_seconds': deltaTime});
  }

  @override
  void onEndPlay(LuminaEndPlayReason reason) {
    super.onEndPlay(reason);
    _dispatch(LuminaBlueprintNodeLibrary.eventLevelEndPlay, 'exec_out', {'end_play_reason': reason.displayName});
  }

  @override
  void onLevelLoaded() {
    super.onLevelLoaded();
    _dispatch(LuminaBlueprintNodeLibrary.eventLevelLoaded, 'exec_out', const {});
  }

  @override
  void onLevelUnloaded() {
    _dispatch(LuminaBlueprintNodeLibrary.eventLevelUnloaded, 'exec_out', const {});
    super.onLevelUnloaded();
  }
}

/// A Widget Blueprint's script: the widget's [LuminaUserWidget]
/// running its graph in the VM. Event Pre Construct / Construct when the
/// widget is added to the viewport, Destruct when it is removed, Tick while
/// it is on screen, and each bound element event (`On Clicked (StartButton)`)
/// when [LuminaUserWidgets.fire] reports it.
class LuminaBlueprintUserWidget extends LuminaUserWidget with LuminaBlueprintRuntime, LuminaBlueprintInstance {
  LuminaBlueprintUserWidget._(LuminaBlueprintClass cls, {super.key});

  @override
  void onWidgetPreConstruct(bool isDesignTime) =>
      _dispatch(LuminaBlueprintNodeLibrary.eventWidgetPreConstruct, 'exec_out', {'is_design_time': isDesignTime});

  @override
  void onWidgetConstruct() => _dispatch(LuminaBlueprintNodeLibrary.eventWidgetConstruct, 'exec_out', const {});

  @override
  void onWidgetDestruct() => _dispatch(LuminaBlueprintNodeLibrary.eventWidgetDestruct, 'exec_out', const {});

  @override
  void onWidgetTick(double inDeltaTime) =>
      _dispatch(LuminaBlueprintNodeLibrary.eventWidgetTick, 'exec_out', {'in_delta_time': inDeltaTime});

  @override
  void onWidgetEvent(String element, String event, Map<String, Object?> args) {
    for (final node in _graph.nodes) {
      if (node.registryId == LuminaBlueprintNodeLibrary.eventWidgetElement &&
          node.literals['element'] == element &&
          node.literals['event'] == event) {
        _run(node.id, 'exec_out', _eventArgs(node, args));
      }
    }
  }
}
