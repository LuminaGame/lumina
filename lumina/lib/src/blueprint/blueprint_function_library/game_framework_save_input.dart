part of '../blueprint_function_library.dart';

// --- Game framework --------------------------------------------

Object? _getGameInstance(LuminaActor self) => LuminaGameInstance.current;

Object? _getGameMode(LuminaActor self) => self.world?.gameMode;

Object? _getGameState(LuminaActor self) => self.world?.gameState;

Object? _getPlayerState(LuminaActor self, [int playerIndex = 0]) {
  final pc = LuminaBlueprintFunctionLibrary.getPlayerController(self, playerIndex);
  return pc is LuminaPlayerController ? pc.playerState : null;
}

void _setGamePaused(LuminaActor self, [bool paused = true]) => self.world?.isPaused = paused;

bool _isGamePaused(LuminaActor self) => self.world?.isPaused ?? false;

bool _executeConsoleCommand(LuminaActor self, String command) => LuminaConsole.execute(self.world, command);

String _getCurrentLevelName(LuminaActor self) => self.world?.persistentLevel.levelName ?? '';

void _openLevel(LuminaActor self, String levelName, [String options = '']) => LuminaGame.requestOpenLevel(levelName, options);

double _getGameTimeSinceCreation(LuminaActor self) {
  final world = self.world;
  final runtime = _runtime(self);
  if (world == null) return 0.0;
  return world.timeSeconds - (runtime?.blueprintBeginPlayTime ?? 0.0);
}

LuminaLevelStreaming? _streamingLevel(LuminaActor self, String name) {
  final manager = self.world?.getSubsystem<LuminaLevelStreamingManager>();
  if (manager == null) return null;
  return manager.findByName(name) ??
      manager.registeredLevels.where((l) => l.levelPath.split('/').last.replaceAll('.lmas', '') == name).firstOrNull;
}

void _loadStreamLevel(LuminaActor self, String levelName, bool makeVisibleAfterLoad, bool shouldBlockOnLoad, void Function() onCompleted) {
  final runtime = _runtime(self);
  final level = _streamingLevel(self, levelName);
  void complete() => runtime == null ? onCompleted() : runtime.blueprintLatentCompletions.add(onCompleted);
  if (level == null) {
    developer.log("Load Stream Level: '$levelName' is not a registered streaming level.", name: 'Blueprint', level: 900);
    complete();
    return;
  }
  level.bShouldBeLoaded = true;
  level.bShouldBeVisible = makeVisibleAfterLoad;
  level.loadLevelAsync().then((_) => makeVisibleAfterLoad ? level.setVisibleAsync(true) : Future<void>.value()).then((_) => complete(),
      onError: (Object e) {
    developer.log("Load Stream Level '$levelName' failed: $e", name: 'Blueprint', level: 900);
    complete();
  });
}

void _unloadStreamLevel(LuminaActor self, String levelName, [void Function()? onCompleted]) {
  final runtime = _runtime(self);
  final level = _streamingLevel(self, levelName);
  void complete() {
    if (onCompleted == null) return;
    runtime == null ? onCompleted() : runtime.blueprintLatentCompletions.add(onCompleted);
  }

  if (level == null) {
    complete();
    return;
  }
  level.bShouldBeLoaded = false;
  level.bShouldBeVisible = false;
  level.unloadLevelAsync().then((_) => complete(), onError: (Object e) => complete());
}

bool _isStreamLevelLoaded(LuminaActor self, String levelName) {
  final state = _streamingLevel(self, levelName)?.state;
  return state == LevelState.loaded || state == LevelState.visible || state == LevelState.makingVisible;
}

// --- Level loading with progress --------------------------------

Map<String, Object?> _levelLoadOutputs(LuminaLevelLoadProgress p) => {
      'percent': p.percent,
      'total_count': p.total,
      'loaded_count': p.loaded,
      'current_content': p.current,
      'error': p.error == null ? '' : '${p.error}',
      'stack_trace': p.stackTrace == null ? '' : '${p.stackTrace}',
    };

Map<String, Object?> _levelLoadEventArgs(Map<String, Object?> outputs) => {
      if (outputs.containsKey('percent')) 'Percent': outputs['percent'],
      if (outputs.containsKey('total_count')) 'TotalCount': outputs['total_count'],
      if (outputs.containsKey('loaded_count')) 'LoadedCount': outputs['loaded_count'],
      if (outputs.containsKey('current_content')) 'CurrentContent': outputs['current_content'],
      'Error': outputs['error'] ?? '',
      'StackTrace': outputs['stack_trace'] ?? '',
    };

void _levelResult(LuminaActor self, String pin, Map<String, Object?> outputs, Object? event,
    void Function(String pin, Map<String, Object?> outputs) resume, {required bool queued}) {
  void run() {
    resume(pin, outputs);
    if (event is LuminaBlueprintDelegate) event.call(LuminaBlueprintFunctionLibrary.levelLoadEventArgs(outputs));
  }

  // While the actor plays, the result runs at its next latent advance (as
  // Load Stream Level's Completed does); an actor whose level is gone — the
  // caller of a Change Level — gets it at once.
  final runtime = _runtime(self);
  if (queued && runtime != null && self.isRegistered && self.hasBegunPlay && !self.isPendingDestroy) {
    runtime.blueprintLatentCompletions.add(run);
  } else {
    run();
  }
}

void _loadLevel(LuminaActor self, String levelName, void Function(String pin, Map<String, Object?> outputs) resume,
    [Object? onProgressEvent, Object? onErrorEvent, Object? onSuccessEvent]) {
  LuminaLevelPreloader.instance.preload(levelName).listen((p) {
    final pin = p.hasError ? 'on_error' : (p.done ? 'on_success' : 'on_progress');
    final event = p.hasError ? onErrorEvent : (p.done ? onSuccessEvent : onProgressEvent);
    _levelResult(self, pin, LuminaBlueprintFunctionLibrary.levelLoadOutputs(p), event, resume, queued: true);
  });
}

void _afterChange(LuminaActor self, Future<void> change, void Function(String pin, Map<String, Object?> outputs) resume,
    Object? onErrorEvent, Object? onSuccessEvent) {
  change.then((_) {
    _levelResult(self, 'on_success', const {'error': '', 'stack_trace': ''}, onSuccessEvent, resume, queued: false);
  }, onError: (Object e, StackTrace st) {
    developer.log('$e', name: 'Blueprint', level: 900);
    _levelResult(self, 'on_error', {'error': '$e', 'stack_trace': '$st'}, onErrorEvent, resume, queued: false);
  });
}

void _changeLevel(LuminaActor self, String levelName, void Function(String pin, Map<String, Object?> outputs) resume,
    [Object? onErrorEvent, Object? onSuccessEvent]) =>
    _afterChange(self, LuminaGame.changeLevel(levelName), resume, onErrorEvent, onSuccessEvent);

void _loadAndChangeLevel(LuminaActor self, String levelName,
        void Function(String pin, Map<String, Object?> outputs) resume, [Object? onErrorEvent, Object? onSuccessEvent]) =>
    _afterChange(self, LuminaLevelPreloader.instance.ensureLoaded(levelName).then((_) => LuminaGame.changeLevel(levelName)),
        resume, onErrorEvent, onSuccessEvent);

void _cancelLevelLoad(LuminaActor self, [String levelName = '']) => LuminaLevelPreloader.instance.cancel(levelName);

bool _isLevelLoaded(LuminaActor self, String levelName) => LuminaLevelPreloader.instance.isLoaded(levelName);

// --- Save game ----------------------------------------------------

LuminaSaveGameSubsystem? _saves(LuminaActor self) {
  final w = self.world;
  if (w == null) return null;
  return w.getSubsystem<LuminaSaveGameSubsystem>() ?? w.registerSubsystem(LuminaSaveGameSubsystem());
}

String _saveClassName(String cls) => LuminaBlueprintObjectClass.kind(cls) == LuminaBlueprintObjectClass.saveGameKind ? LuminaBlueprintObjectClass.name(cls) : cls;

Object? _createSaveGameObject(LuminaActor self, String cls) {
  final name = _saveClassName(cls);
  return LuminaBlueprintSaveGame(name, document: LuminaBlueprintSaveGameClasses.lookup(name));
}

Object? _saveFieldPlain(Object? value) {
  if (value is Vector3) return _list3(value);
  if (value is Vector2) return [value.x, value.y];
  if (value is LuminaRotator) return value.toList();
  if (value is List) return [for (final v in value) LuminaBlueprintFunctionLibrary.saveFieldPlain(v)];
  if (value is Map) return {for (final e in value.entries) '${e.key}': LuminaBlueprintFunctionLibrary.saveFieldPlain(e.value)};
  if (value is num || value is bool || value is String || value == null) return value;
  return '$value';
}

void _setSaveField(LuminaActor self, Object? target, String cls, String field, Object? value) {
  if (target is LuminaSaveGame && field.isNotEmpty) target.customSaveData[field] = LuminaBlueprintFunctionLibrary.saveFieldPlain(value);
}

Object? _getSaveField(Object? target, String field, [String cls = '']) {
  if (target is! LuminaSaveGame) return null;
  final stored = target.customSaveData[field];
  final className = cls.isEmpty ? (target is LuminaBlueprintSaveGame ? target.className : '') : _saveClassName(cls);
  final declared = LuminaBlueprintSaveGameClasses.lookup(className)?.field(field);
  final type = declared?.type;
  if (type == null) return stored;
  return luminaBlueprintLiteral(type, stored) ?? luminaBlueprintZero(type);
}

bool _saveGameToSlot(LuminaActor self, Object? saveGameObject, [String slotName = 'Slot1', int userIndex = 0]) {
  if (saveGameObject is! LuminaSaveGame || slotName.isEmpty) return false;
  saveGameObject
    ..saveSlotName = slotName
    ..userIndex = userIndex;
  return _saves(self)?.saveGameToSlotSync(saveGameObject, slotName, userIndex) ?? false;
}

Object? _loadGameFromSlot(LuminaActor self, [String slotName = 'Slot1', int userIndex = 0]) =>
    slotName.isEmpty ? null : _saves(self)?.loadGameFromSlotSync(slotName, userIndex);

bool _doesSaveGameExist(LuminaActor self, [String slotName = 'Slot1', int userIndex = 0]) =>
    slotName.isNotEmpty && (_saves(self)?.doesSaveGameExistSync(slotName, userIndex) ?? false);

bool _deleteGameInSlot(LuminaActor self, [String slotName = 'Slot1', int userIndex = 0]) =>
    slotName.isNotEmpty && (_saves(self)?.deleteGameInSlot(slotName, userIndex) ?? false);

void _asyncSaveGameToSlot(LuminaActor self, Object? saveGameObject, String slotName, int userIndex, void Function(bool success) onCompleted) {
  final runtime = _runtime(self);
  void complete(bool ok) => runtime == null ? onCompleted(ok) : runtime.blueprintLatentCompletions.add(() => onCompleted(ok));
  final saves = _saves(self);
  if (saveGameObject is! LuminaSaveGame || saves == null || slotName.isEmpty) {
    complete(false);
    return;
  }
  saveGameObject
    ..saveSlotName = slotName
    ..userIndex = userIndex;
  saves.saveGameToSlotAsync(saveGameObject, slotName, userIndex).then((r) => complete(r.success), onError: (Object e) => complete(false));
}

// --- Input & screen -------------------------------------------------

LuminaInputSubsystem? _input(LuminaActor self) => self.world?.getSubsystem<LuminaInputSubsystem>();

bool _isInputKeyDown(LuminaActor self, String key) => _input(self)?.isKeyDown(LuminaKey.fromName(key)) ?? false;

double _getInputKeyTimeDown(LuminaActor self, String key) => _input(self)?.keyDownTime(LuminaKey.fromName(key)) ?? 0.0;

bool _wasInputKeyJustPressed(LuminaActor self, String key) => _input(self)?.wasKeyJustPressed(LuminaKey.fromName(key)) ?? false;

double _getInputAxisValue(LuminaActor self, String axisName) => _input(self)?.axisValue(LuminaKey.fromName(axisName)) ?? 0.0;

Vector2 _getMousePosition(LuminaActor self) => _input(self)?.mousePosition ?? Vector2.zero();

void _setMousePosition(LuminaActor self, Vector2 position) => _input(self)?.injectMousePosition(position);

String _getLastInputDevice(LuminaActor self) => _input(self)?.lastInputDevice ?? 'Keyboard';

Vector2 _getViewportSize(LuminaActor self) {
  final size = self.world?.viewportSize ?? (1280, 720);
  return Vector2(size.$1.toDouble(), size.$2.toDouble());
}

void _enableInput(LuminaActor self, [Object? playerController]) => _runtime(self)?.blueprintInputEnabled = true;

void _disableInput(LuminaActor self, [Object? playerController]) => _runtime(self)?.blueprintInputEnabled = false;

({Vector3 eye, Vector3 forward, Vector3 right, Vector3 up, double fov})? _view(LuminaActor self) {
  final pov = self.world?.viewPov;
  if (pov == null) return null;
  return (
    eye: pov.location,
    forward: pov.rotation.rotateVector(Vector3(0, 0, -1)),
    right: pov.rotation.rotateVector(Vector3(1, 0, 0)),
    up: pov.rotation.rotateVector(Vector3(0, 1, 0)),
    fov: pov.fovDegrees,
  );
}

({Vector2 screenPosition, bool returnValue}) _projectWorldToScreen(LuminaActor self, Vector3 worldLocation) {
  final v = _view(self);
  if (v == null) return (screenPosition: Vector2.zero(), returnValue: false);
  final size = LuminaBlueprintFunctionLibrary.getViewportSize(self);
  final d = LuminaBlueprintFunctionLibrary.toRuntime(worldLocation) - v.eye;
  final z = d.dot(v.forward);
  if (z <= 1e-6) return (screenPosition: Vector2.zero(), returnValue: false);
  final tanHalf = math.tan(v.fov * math.pi / 360.0);
  final aspect = size.y == 0 ? 1.0 : size.x / size.y;
  final ndcX = d.dot(v.right) / (z * tanHalf * aspect);
  final ndcY = d.dot(v.up) / (z * tanHalf);
  return (screenPosition: Vector2((ndcX + 1.0) * 0.5 * size.x, (1.0 - ndcY) * 0.5 * size.y), returnValue: true);
}

({Vector3 worldLocation, Vector3 worldDirection}) _deprojectScreenToWorld(LuminaActor self, Vector2 screenPosition) {
  final v = _view(self);
  if (v == null) return (worldLocation: LuminaBlueprintFunctionLibrary.getActorLocation(self), worldDirection: LuminaBlueprintFunctionLibrary.getLookForwardDirection(self));
  final size = LuminaBlueprintFunctionLibrary.getViewportSize(self);
  final tanHalf = math.tan(v.fov * math.pi / 360.0);
  final aspect = size.y == 0 ? 1.0 : size.x / size.y;
  final ndcX = size.x == 0 ? 0.0 : screenPosition.x / size.x * 2.0 - 1.0;
  final ndcY = size.y == 0 ? 0.0 : 1.0 - screenPosition.y / size.y * 2.0;
  final dir = (v.forward + v.right * (ndcX * tanHalf * aspect) + v.up * (ndcY * tanHalf)).normalized();
  return (worldLocation: LuminaBlueprintFunctionLibrary.toAuthoring(v.eye), worldDirection: LuminaBlueprintFunctionLibrary.toAuthoring(dir));
}
