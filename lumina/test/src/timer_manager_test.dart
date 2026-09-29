import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('LuminaTimerManager Tests', () {
    test('One-shot timer fires on crossing rate and expires', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final timerMgr = LuminaTimerManager();
      world.registerSubsystem<LuminaTimerManager>(timerMgr);
      world.beginPlay();

      int fires = 0;
      final handle = timerMgr.setTimer(() => fires++, rate: 1.0);

      expect(timerMgr.isTimerActive(handle), isTrue);
      expect(timerMgr.getTimerRate(handle), equals(1.0));

      world.tick(0.4);
      expect(fires, equals(0));
      expect(timerMgr.getTimerRemaining(handle), closeTo(0.6, 1e-5));
      expect(timerMgr.getTimerElapsed(handle), closeTo(0.4, 1e-5));

      world.tick(0.4);
      expect(fires, equals(0));
      expect(timerMgr.getTimerRemaining(handle), closeTo(0.2, 1e-5));

      world.tick(0.4);
      expect(fires, equals(1));
      expect(timerMgr.isTimerActive(handle), isFalse);
      expect(timerMgr.getTimerRemaining(handle), equals(-1.0));
    });

    test('Looping timer fires repeatedly and preserves remaining fraction', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final timerMgr = LuminaTimerManager();
      world.registerSubsystem<LuminaTimerManager>(timerMgr);
      world.beginPlay();

      int fires = 0;
      final handle = timerMgr.setTimer(() => fires++, rate: 0.5, looping: true);

      for (int i = 0; i < 10; i++) {
        world.tick(0.25);
      }

      expect(fires, equals(5));
      expect(timerMgr.isTimerActive(handle), isTrue);
      expect(timerMgr.getTimerRemaining(handle), closeTo(0.5, 1e-5));
    });

    test('Catch-up: large dt fires looping timer multiple times in one tick', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final timerMgr = LuminaTimerManager();
      world.registerSubsystem<LuminaTimerManager>(timerMgr);
      world.beginPlay();

      int fires = 0;
      final handle = timerMgr.setTimer(() => fires++, rate: 0.1, looping: true);

      world.tick(0.35);

      expect(fires, equals(3));
      expect(timerMgr.getTimerRemaining(handle), closeTo(0.05, 1e-5));
    });

    test('firstDelay overrides first interval only', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final timerMgr = LuminaTimerManager();
      world.registerSubsystem<LuminaTimerManager>(timerMgr);
      world.beginPlay();

      int fires = 0;
      final handle = timerMgr.setTimer(
        () => fires++,
        rate: 0.5,
        firstDelay: 2.0,
        looping: true,
      );

      world.tick(1.5);
      expect(fires, equals(0));

      world.tick(0.5); // total 2.0s -> first fire
      expect(fires, equals(1));

      world.tick(0.5); // total 2.5s -> second fire
      expect(fires, equals(2));
    });

    test('pauseTimer and unpauseTimer preserve remaining time', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final timerMgr = LuminaTimerManager();
      world.registerSubsystem<LuminaTimerManager>(timerMgr);
      world.beginPlay();

      int fires = 0;
      final handle = timerMgr.setTimer(() => fires++, rate: 1.0);

      world.tick(0.6);
      expect(timerMgr.getTimerRemaining(handle), closeTo(0.4, 1e-5));

      timerMgr.pauseTimer(handle);
      expect(timerMgr.isTimerPaused(handle), isTrue);
      expect(timerMgr.isTimerActive(handle), isFalse);

      for (int i = 0; i < 5; i++) {
        world.tick(0.2);
      }
      expect(fires, equals(0));
      expect(timerMgr.getTimerRemaining(handle), closeTo(0.4, 1e-5));

      timerMgr.unpauseTimer(handle);
      expect(timerMgr.isTimerPaused(handle), isFalse);
      expect(timerMgr.isTimerActive(handle), isTrue);

      world.tick(0.4);
      expect(fires, equals(1));
    });

    test('clearTimer prevents callback from running', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final timerMgr = LuminaTimerManager();
      world.registerSubsystem<LuminaTimerManager>(timerMgr);
      world.beginPlay();

      int fires = 0;
      final handle = timerMgr.setTimer(() => fires++, rate: 1.0);

      world.tick(0.5);
      timerMgr.clearTimer(handle);
      world.tick(1.0);

      expect(fires, equals(0));
      expect(timerMgr.isTimerActive(handle), isFalse);
    });

    test('setTimerForNextTick fires on next tick even with dt 0', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final timerMgr = LuminaTimerManager();
      world.registerSubsystem<LuminaTimerManager>(timerMgr);
      world.beginPlay();

      int fires = 0;
      timerMgr.setTimerForNextTick(() => fires++);

      world.tick(0.0);
      expect(fires, equals(1));

      world.tick(0.0);
      expect(fires, equals(1));
    });

    test('Reentrancy: timer set inside callback does not fire in current tick', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final timerMgr = LuminaTimerManager();
      world.registerSubsystem<LuminaTimerManager>(timerMgr);
      world.beginPlay();

      int parentFires = 0;
      int childFires = 0;

      timerMgr.setTimer(() {
        parentFires++;
        timerMgr.setTimer(() => childFires++, rate: 0.1);
      }, rate: 0.1);

      // Tick 1.0s in one tick
      world.tick(1.0);

      expect(parentFires, equals(1));
      expect(childFires, equals(0));

      world.tick(0.1);
      expect(childFires, equals(1));
    });

    test('Reentrancy: callback clearing sibling due timer prevents sibling fire', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final timerMgr = LuminaTimerManager();
      world.registerSubsystem<LuminaTimerManager>(timerMgr);
      world.beginPlay();

      int firstFires = 0;
      int secondFires = 0;

      late LuminaTimerHandle handle2;

      timerMgr.setTimer(() {
        firstFires++;
        timerMgr.clearTimer(handle2);
      }, rate: 0.5);

      handle2 = timerMgr.setTimer(() {
        secondFires++;
      }, rate: 0.5);

      world.tick(0.5);

      expect(firstFires, equals(1));
      expect(secondFires, equals(0));
    });

    test('onWorldShutdown clears all active timers', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final timerMgr = LuminaTimerManager();
      world.registerSubsystem<LuminaTimerManager>(timerMgr);
      world.beginPlay();

      final handle = timerMgr.setTimer(() {}, rate: 1.0, looping: true);
      expect(timerMgr.activeTimerCount, equals(1));

      world.cleanup();
      expect(timerMgr.activeTimerCount, equals(0));
      expect(timerMgr.isTimerActive(handle), isFalse);
    });
  });
}
