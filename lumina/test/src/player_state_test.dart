import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('PlayerState Tests (Player Task 02)', () {
    setUp(() {
      LuminaPlayerState.resetPlayerIdCounterForTesting();
    });

    test('state.score setter notifies listener once and updates value', () {
      final state = LuminaPlayerState();
      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      state.score = 10.0;
      expect(state.score, equals(10.0));
      expect(notifyCount, equals(1));
    });

    test('Writing the same value twice fires listener only once (dirty check)', () {
      final state = LuminaPlayerState();
      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      state.score = 10.0;
      state.score = 10.0;
      expect(notifyCount, equals(1));
    });

    test('addScore(5.0) twice from 0 results in score 10.0 and 2 notifications', () {
      final state = LuminaPlayerState();
      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      state.addScore(5.0);
      state.addScore(5.0);

      expect(state.score, equals(10.0));
      expect(notifyCount, equals(2));
    });

    test('health is clamped to >= 0 and isAlive correctly reflects health > 0', () {
      final state = LuminaPlayerState();
      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      state.health = -20.0;
      expect(state.health, equals(0.0));
      expect(state.isAlive, isFalse);
      expect(notifyCount, equals(1));

      state.health = 100.0;
      expect(state.health, equals(100.0));
      expect(state.isAlive, isTrue);
      expect(notifyCount, equals(2));
    });

    test('teamId and playerName each fire one notification', () {
      final state = LuminaPlayerState();
      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      state.teamId = 2;
      expect(notifyCount, equals(1));

      state.playerName = 'Can';
      expect(notifyCount, equals(2));
    });

    test('removeListener prevents notifications and self-removal inside callback is safe', () {
      final state = LuminaPlayerState();
      int countA = 0;
      int countB = 0;

      void Function()? listenerA;
      listenerA = () {
        countA++;
        state.removeListener(listenerA!);
      };

      void listenerB() {
        countB++;
      }

      state.addListener(listenerA);
      state.addListener(listenerB);

      state.score = 10.0;
      expect(countA, equals(1));
      expect(countB, equals(1));

      state.score = 20.0;
      expect(countA, equals(1));
      expect(countB, equals(2));
    });

    test('Two listeners registered fire in registration order', () {
      final state = LuminaPlayerState();
      final log = <String>[];

      state.addListener(() => log.add('first'));
      state.addListener(() => log.add('second'));

      state.score = 5.0;
      expect(log, equals(['first', 'second']));
    });

    test('reset() restores score to 0 and health to 100 with exactly one notification', () {
      final state = LuminaPlayerState(playerName: 'Player1', teamId: 3);
      state.score = 50.0;
      state.health = 30.0;

      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      state.reset();

      expect(state.score, equals(0.0));
      expect(state.health, equals(100.0));
      expect(state.playerName, equals('Player1'));
      expect(state.teamId, equals(3));
      expect(notifyCount, equals(1));
    });

    test('LuminaPlayerController assigns unique increasing playerId', () {
      final pc1 = LuminaPlayerController();
      final pc2 = LuminaPlayerController();
      final pc3 = LuminaPlayerController();

      expect(pc1.playerState.playerId, equals(0));
      expect(pc2.playerState.playerId, equals(1));
      expect(pc3.playerState.playerId, equals(2));
    });
  });
}
