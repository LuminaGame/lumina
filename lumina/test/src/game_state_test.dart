import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

class TestActor extends LuminaActor {
  double recordedTime = -1.0;

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    if (owningLevel != null && owningLevel!.owningWorld != null) {
      recordedTime = owningLevel!.owningWorld!.gameState?.elapsedTime ?? -1.0;
    }
  }
}

void main() {
  group('LuminaGameState', () {
    test('Fresh state', () {
      final state = LuminaGameState();
      expect(state.matchState, equals(LuminaMatchState.waitingToStart));
      expect(state.playerArray, isEmpty);
      expect(state.elapsedTime, equals(0.0));
      expect(state.hasMatchStarted, isFalse);
      expect(state.hasMatchEnded, isFalse);
    });

    test('addPlayerState and listeners', () {
      final state = LuminaGameState();
      int listenerCalls = 0;
      state.addListener(() => listenerCalls++);

      final p1 = LuminaPlayerState(playerId: 0);
      final p2 = LuminaPlayerState(playerId: 1);

      state.addPlayerState(p1);
      state.addPlayerState(p2);

      expect(state.playerArray.length, equals(2));
      expect(listenerCalls, equals(2));

      // Adding the same state again
      state.addPlayerState(p1);
      expect(state.playerArray.length, equals(2));
      expect(listenerCalls, equals(2));
    });

    test('playerArray is unmodifiable', () {
      final state = LuminaGameState();
      expect(() => state.playerArray.add(LuminaPlayerState()), throwsUnsupportedError);
    });

    test('getPlayerStateById', () {
      final state = LuminaGameState();
      final p1 = LuminaPlayerState(playerId: 0);
      final p2 = LuminaPlayerState(playerId: 1);

      state.addPlayerState(p1);
      state.addPlayerState(p2);

      expect(state.getPlayerStateById(1), equals(p2));
      expect(state.getPlayerStateById(7), isNull);
    });

    test('tick and elapsedTime', () {
      final state = LuminaGameState();
      state.tick(0.5);
      state.tick(0.5);
      state.tick(0.5);
      expect(state.elapsedTime, equals(0.0));

      state.setMatchState(LuminaMatchState.inProgress);
      state.tick(0.5);
      state.tick(0.5);
      state.tick(0.5);
      expect(state.elapsedTime, equals(1.5));
    });

    test('matchState illegal transitions and idempotence', () {
      final state = LuminaGameState();
      int listenerCalls = 0;
      state.addListener(() => listenerCalls++);

      state.setMatchState(LuminaMatchState.inProgress);
      expect(listenerCalls, equals(1));

      // Illegal backward transition
      expect(() => state.setMatchState(LuminaMatchState.waitingToStart), throwsStateError);

      // Idempotent
      state.setMatchState(LuminaMatchState.inProgress);
      expect(listenerCalls, equals(1));

      state.setMatchState(LuminaMatchState.waitingPostMatch);
      expect(listenerCalls, equals(2));

      // Cannot transition out of waitingPostMatch
      expect(() => state.setMatchState(LuminaMatchState.inProgress), throwsStateError);
    });

    test('full legal walk', () {
      final state = LuminaGameState();
      int listenerCalls = 0;
      state.addListener(() => listenerCalls++);

      state.setMatchState(LuminaMatchState.inProgress);
      expect(state.hasMatchStarted, isTrue);
      expect(state.hasMatchEnded, isFalse);
      
      state.setMatchState(LuminaMatchState.waitingPostMatch);
      expect(state.hasMatchStarted, isTrue);
      expect(state.hasMatchEnded, isTrue);

      expect(listenerCalls, equals(2));
    });

    test('world integration', () {
      final mode = LuminaGameMode();
      final world = LuminaWorld();
      world.gameMode = mode;
      mode.initGame(world);
      
      final actor = TestActor();
      world.persistentLevel.registerActor(actor);

      world.beginPlay();
      
      mode.startMatch();
      
      world.tick(0.016);
      
      expect(world.gameState, isNotNull);
      expect(world.gameState!.elapsedTime, closeTo(0.016, 0.0001));
      expect(actor.recordedTime, closeTo(0.016, 0.0001));
    });
  });
}
