import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// A paused world still runs the input actions that execute when paused (a
/// pause menu's key) and nothing else.
void main() {
  late LuminaWorld world;
  late LuminaInputSubsystem input;
  late LuminaInputComponent component;
  late List<String> events;

  const settings = ProjectInputSettings(
    actions: [
      ProjectInputAction(name: 'IA_Menu', executeWhenPaused: true),
      ProjectInputAction(name: 'IA_Forward'),
    ],
    mappingContexts: [
      ProjectMappingContext(name: 'Gameplay', mappings: [
        ProjectInputMapping(action: 'IA_Menu', keyId: 0x10000001b, keyLabel: 'Escape'),
        ProjectInputMapping(action: 'IA_Forward', keyId: 0x77, keyLabel: 'W'),
      ]),
    ],
  );

  setUp(() {
    world = LuminaWorld(worldType: LuminaWorldType.game);
    input = world.registerSubsystem(LuminaInputSubsystem());
    final bound = ProjectInputBinder.bind(settings);
    for (final c in bound.contexts) {
      input.addMappingContext(c.context, priority: c.priority);
    }
    component = LuminaInputComponent(subsystem: input);
    input.registerComponent(component);
    events = [];
    for (final name in ['IA_Menu', 'IA_Forward']) {
      // A Blueprint binds by name and value type, without the flag.
      final action = LuminaInputAction(name);
      for (final state in [TriggerState.started, TriggerState.completed]) {
        component.bindAction(action, state, (_) => events.add('$name ${state.name}'));
      }
    }
    world.beginPlay();
  });

  test('the binder carries Execute When Paused onto the runtime action', () {
    final actions = ProjectInputBinder.bind(settings).actions;
    expect(actions['IA_Menu']!.executeWhenPaused, isTrue);
    expect(actions['IA_Forward']!.executeWhenPaused, isFalse);
    // Not part of equality: a Blueprint's action without the flag still matches.
    expect(actions['IA_Menu'], const LuminaInputAction('IA_Menu'));
  });

  test('while paused only the flagged action fires', () {
    world.isPaused = true;
    input.injectKeyDown(LuminaKey.keyEscape);
    input.injectKeyDown(LuminaKey.keyW);
    world.tick(1 / 60);
    expect(events, ['IA_Menu started']);
    input.injectKeyUp(LuminaKey.keyEscape);
    input.injectKeyUp(LuminaKey.keyW);
    world.tick(1 / 60);
    expect(events, ['IA_Menu started', 'IA_Menu completed']);
    expect(world.timeSeconds, 0.0, reason: 'game time stays frozen');

    // W went down and up during the pause: nothing stale on resume.
    world.isPaused = false;
    world.tick(1 / 60);
    world.tick(1 / 60);
    expect(events, ['IA_Menu started', 'IA_Menu completed']);
  });

  test('the flagged handler can unpause, and the game resumes on the next tick', () {
    component.bindAction(const LuminaInputAction('IA_Menu'), TriggerState.started, (_) => world.isPaused = !world.isPaused);
    world.isPaused = true;
    input.injectKeyDown(LuminaKey.keyEscape);
    world.tick(1 / 60);
    expect(world.isPaused, isFalse);
    input.injectKeyUp(LuminaKey.keyEscape);
    input.injectKeyDown(LuminaKey.keyW);
    world.tick(1 / 60);
    expect(events, ['IA_Menu started', 'IA_Menu completed', 'IA_Forward started']);
    expect(world.timeSeconds, greaterThan(0.0));
  });

  test('a key held when the game paused keeps its state and completes on resume', () {
    input.injectKeyDown(LuminaKey.keyW);
    world.tick(1 / 60);
    world.isPaused = true;
    input.injectKeyUp(LuminaKey.keyW);
    world.tick(1 / 60);
    expect(events, ['IA_Forward started'], reason: 'frozen while paused');
    world.isPaused = false;
    world.tick(1 / 60);
    expect(events, ['IA_Forward started', 'IA_Forward completed']);
  });

  test('ProjectInputAction writes execute_when_paused only when true', () {
    const paused = ProjectInputAction(name: 'IA_Menu', executeWhenPaused: true);
    expect(paused.toMap(), {'name': 'IA_Menu', 'value_type': 'digital', 'execute_when_paused': true});
    expect(ProjectInputAction.fromMap(paused.toMap()).executeWhenPaused, isTrue);
    expect(const ProjectInputAction(name: 'IA_Jump').toMap(), {'name': 'IA_Jump', 'value_type': 'digital'});
    expect(ProjectInputAction.fromMap({'name': 'IA_Old', 'value_type': 'digital'}).executeWhenPaused, isFalse);
    expect(paused.copyWith(executeWhenPaused: false).executeWhenPaused, isFalse);
  });
}
