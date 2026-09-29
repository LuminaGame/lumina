import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

class TestPawnWithInput extends LuminaPawn {
  int jumpStartedCount = 0;
  int jumpCompletedCount = 0;
  int jumpTriggeredCount = 0;
  int fireCount = 0;
  final List<double> moveForwardValues = [];
  final List<String> callSequence = [];

  @override
  void setupPlayerInputComponent(LuminaPlayerComponent playerInput) {
    super.setupPlayerInputComponent(playerInput);

    playerInput.bindAction('Jump', () {
      jumpStartedCount++;
      callSequence.add('Jump:started');
    }, state: InputTriggerState.started);

    playerInput.bindAction('Jump', () {
      jumpCompletedCount++;
      callSequence.add('Jump:completed');
    }, state: InputTriggerState.completed);

    playerInput.bindAction('Jump', () {
      jumpTriggeredCount++;
      callSequence.add('Jump:triggered');
    }, state: InputTriggerState.triggered);

    playerInput.bindAction('Fire', () {
      fireCount++;
      callSequence.add('Fire');
    });

    playerInput.bindAxis('MoveForward', (v) {
      moveForwardValues.add(v);
      callSequence.add('MoveForward:$v');
    });
  }
}

void main() {
  group('PlayerComponent & InputBinding Tests (Player Task 01)', () {
    test('Two bindings on Jump with started and completed states trigger filtered by state', () {
      final pawn = LuminaPawn();
      final playerComp = LuminaPlayerComponent();
      pawn.addComponent(playerComp);

      int startedCount = 0;
      int completedCount = 0;

      playerComp.bindAction('Jump', () => startedCount++, state: InputTriggerState.started);
      playerComp.bindAction('Jump', () => completedCount++, state: InputTriggerState.completed);

      playerComp.triggerAction('Jump', InputTriggerState.started);

      expect(startedCount, equals(1));
      expect(completedCount, equals(0));
    });

    test('Two bindings on same name and same state both fire in bind order', () {
      final pawn = LuminaPawn();
      final playerComp = LuminaPlayerComponent();
      pawn.addComponent(playerComp);

      final log = <String>[];
      playerComp.bindAction('Attack', () => log.add('first'), state: InputTriggerState.triggered);
      playerComp.bindAction('Attack', () => log.add('second'), state: InputTriggerState.triggered);

      playerComp.triggerAction('Attack', InputTriggerState.triggered);

      expect(log, equals(['first', 'second']));
    });

    test('Default state responds to triggered and nothing else across all 5 states', () {
      final pawn = LuminaPawn();
      final playerComp = LuminaPlayerComponent();
      pawn.addComponent(playerComp);

      int fireCount = 0;
      playerComp.bindAction('Fire', () => fireCount++);

      for (final state in InputTriggerState.values) {
        playerComp.triggerAction('Fire', state);
      }

      expect(fireCount, equals(1));
    });

    test('bindAxis triggers with values [1.0, -1.0, 0.0]', () {
      final pawn = LuminaPawn();
      final playerComp = LuminaPlayerComponent();
      pawn.addComponent(playerComp);

      final values = <double>[];
      playerComp.bindAxis('MoveForward', (v) => values.add(v));

      playerComp.triggerAxis('MoveForward', 1.0);
      playerComp.triggerAxis('MoveForward', -1.0);
      playerComp.triggerAxis('MoveForward', 0.0);

      expect(values, equals([1.0, -1.0, 0.0]));
    });

    test('unbindAction removes binding and subsequent trigger does not fire', () {
      final pawn = LuminaPawn();
      final playerComp = LuminaPlayerComponent();
      pawn.addComponent(playerComp);

      int count = 0;
      final handle = playerComp.bindAction('Jump', () => count++);

      playerComp.triggerAction('Jump', InputTriggerState.triggered);
      expect(count, equals(1));

      final unbindSuccess = playerComp.unbindAction(handle);
      expect(unbindSuccess, isTrue);

      playerComp.triggerAction('Jump', InputTriggerState.triggered);
      expect(count, equals(1));

      final unbindAgain = playerComp.unbindAction(handle);
      expect(unbindAgain, isFalse);
    });

    test('Attaching to non-Pawn LuminaActor throws StateError; attaching to LuminaPawn succeeds', () {
      final plainActor = LuminaActor();
      final playerComp1 = LuminaPlayerComponent();

      expect(() => plainActor.addComponent(playerComp1), throwsStateError);

      final pawn = LuminaPawn();
      final playerComp2 = LuminaPlayerComponent();
      pawn.addComponent(playerComp2);

      expect(playerComp2.isRegistered, isTrue);
    });

    test('Removing component clears bindings and triggers become silent no-ops', () {
      final pawn = LuminaPawn();
      final playerComp = LuminaPlayerComponent();
      pawn.addComponent(playerComp);

      int count = 0;
      playerComp.bindAction('Jump', () => count++);
      playerComp.bindAxis('Move', (v) => count++);

      pawn.removeComponent(playerComp);

      playerComp.triggerAction('Jump', InputTriggerState.triggered);
      playerComp.triggerAxis('Move', 1.0);

      expect(count, equals(0));
    });

    test('triggerAction and triggerAxis on unknown names do not throw or allocate map entries', () {
      final pawn = LuminaPawn();
      final playerComp = LuminaPlayerComponent();
      pawn.addComponent(playerComp);

      expect(() => playerComp.triggerAction('Unknown', InputTriggerState.triggered), returnsNormally);
      expect(() => playerComp.triggerAxis('Unknown', 1.0), returnsNormally);
    });

    test('Possession integration: setupPlayerInputComponent binds actions; unpossession tears down', () {
      final pawn = TestPawnWithInput();
      final controller = LuminaPlayerController();

      controller.possess(pawn);
      final pic = pawn.getComponent<LuminaPlayerComponent>();
      expect(pic, isNotNull);

      pic!.triggerAction('Jump', InputTriggerState.started);
      pic.triggerAction('Jump', InputTriggerState.completed);
      pic.triggerAction('Fire', InputTriggerState.triggered);
      pic.triggerAxis('MoveForward', 1.0);

      expect(pawn.jumpStartedCount, equals(1));
      expect(pawn.jumpCompletedCount, equals(1));
      expect(pawn.fireCount, equals(1));
      expect(pawn.moveForwardValues, equals([1.0]));

      controller.unpossess();

      // Triggering old pic has no effect as bindings were cleared
      pic.triggerAction('Jump', InputTriggerState.started);
      pic.triggerAxis('MoveForward', 1.0);

      expect(pawn.jumpStartedCount, equals(1));
      expect(pawn.moveForwardValues.length, equals(1));
    });
  });
}
