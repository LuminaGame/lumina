import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('LuminaLevelStreaming 7-State Lifecycle Tests (Task 01)', () {
    test('Fresh instance -> state == LevelState.unloaded, isTransitioning == false', () {
      final level = LuminaLevel();
      final streaming = LuminaLevelStreaming(
        levelPath: 'contents/levels/SubLevel_A.lmas',
        levelInstance: level,
      );

      expect(streaming.state, equals(LevelState.unloaded));
      expect(streaming.isTransitioning, isFalse);
      expect(streaming.bShouldBeLoaded, isTrue);
      expect(streaming.bShouldBeVisible, isFalse);
      expect(streaming.bDisableDistanceStreaming, isFalse);
    });

    test('Full linear sequence: loadLevelAsync() -> setVisibleAsync(true) -> setVisibleAsync(false) -> unloadLevelAsync() emits exact 7-state lifecycle', () async {
      final level = LuminaLevel();
      final streaming = LuminaLevelStreaming(
        levelPath: 'contents/levels/SubLevel_A.lmas',
        levelInstance: level,
      );

      final stateHistory = <LevelState>[];
      final sub = streaming.onStateChanged.listen(stateHistory.add);

      int loadedCallbackCount = 0;
      int shownCallbackCount = 0;
      int hiddenCallbackCount = 0;
      int unloadedCallbackCount = 0;

      streaming.onLevelLoaded = (_) => loadedCallbackCount++;
      streaming.onLevelShown = (_) => shownCallbackCount++;
      streaming.onLevelHidden = (_) => hiddenCallbackCount++;
      streaming.onLevelUnloaded = (_) => unloadedCallbackCount++;

      // 1. Load
      final res = await streaming.loadLevelAsync();
      expect(res, same(level));
      expect(streaming.state, equals(LevelState.loaded));
      expect(streaming.isTransitioning, isFalse);
      expect(loadedCallbackCount, equals(1));

      // 2. Show
      await streaming.setVisibleAsync(true);
      expect(streaming.state, equals(LevelState.visible));
      expect(streaming.isTransitioning, isFalse);
      expect(shownCallbackCount, equals(1));

      // 3. Hide
      await streaming.setVisibleAsync(false);
      expect(streaming.state, equals(LevelState.loaded));
      expect(streaming.isTransitioning, isFalse);
      expect(hiddenCallbackCount, equals(1));

      // 4. Unload
      await streaming.unloadLevelAsync();
      expect(streaming.state, equals(LevelState.unloaded));
      expect(streaming.isTransitioning, isFalse);
      expect(unloadedCallbackCount, equals(1));

      expect(stateHistory, equals([
        LevelState.loading,
        LevelState.loaded,
        LevelState.makingVisible,
        LevelState.visible,
        LevelState.makingInvisible,
        LevelState.loaded,
        LevelState.unloading,
        LevelState.unloaded,
      ]));

      await sub.cancel();
    });

    test('bShouldBeVisible: true at construction -> a single loadLevelAsync() ends in visible', () async {
      final level = LuminaLevel();
      final streaming = LuminaLevelStreaming(
        levelPath: 'contents/levels/SubLevel_A.lmas',
        levelInstance: level,
        bShouldBeVisible: true,
      );

      final stateHistory = <LevelState>[];
      final sub = streaming.onStateChanged.listen(stateHistory.add);

      final loadedLevel = await streaming.loadLevelAsync();
      expect(loadedLevel, same(level));
      expect(streaming.state, equals(LevelState.visible));
      expect(streaming.isTransitioning, isFalse);

      expect(stateHistory, equals([
        LevelState.loading,
        LevelState.loaded,
        LevelState.makingVisible,
        LevelState.visible,
      ]));

      await sub.cancel();
    });

    test('Two concurrent loadLevelAsync() calls -> both resolve to the same LuminaLevel, single-flight loading', () async {
      final level = LuminaLevel();
      final streaming = LuminaLevelStreaming(
        levelPath: 'contents/levels/SubLevel_A.lmas',
        levelInstance: level,
      );

      final stateHistory = <LevelState>[];
      final sub = streaming.onStateChanged.listen(stateHistory.add);

      final f1 = streaming.loadLevelAsync();
      final f2 = streaming.loadLevelAsync();

      final results = await Future.wait([f1, f2]);
      expect(results[0], same(level));
      expect(results[1], same(level));
      expect(streaming.state, equals(LevelState.loaded));

      expect(stateHistory.where((s) => s == LevelState.loading).length, equals(1));
      expect(stateHistory.where((s) => s == LevelState.loaded).length, equals(1));

      await sub.cancel();
    });

    test('setVisibleAsync(false) fired while state is makingVisible -> final settled state is loaded without consecutive duplicates', () async {
      final level = LuminaLevel();
      final streaming = LuminaLevelStreaming(
        levelPath: 'contents/levels/SubLevel_A.lmas',
        levelInstance: level,
      );

      await streaming.loadLevelAsync();

      final stateHistory = <LevelState>[];
      final sub = streaming.onStateChanged.listen(stateHistory.add);

      final showFuture = streaming.setVisibleAsync(true);
      final hideFuture = streaming.setVisibleAsync(false);

      await Future.wait([showFuture, hideFuture]);

      expect(streaming.state, equals(LevelState.loaded));
      expect(streaming.isTransitioning, isFalse);

      // Verify no state emitted twice consecutively
      for (int i = 0; i < stateHistory.length - 1; i++) {
        expect(stateHistory[i], isNot(equals(stateHistory[i + 1])));
      }

      await sub.cancel();
    });

    test('setVisibleAsync(true) while unloaded -> throws StateError naming transition, state remains unloaded', () async {
      final level = LuminaLevel();
      final streaming = LuminaLevelStreaming(
        levelPath: 'contents/levels/SubLevel_A.lmas',
        levelInstance: level,
      );

      expect(streaming.state, equals(LevelState.unloaded));

      expect(
        () => streaming.setVisibleAsync(true),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(contains('unloaded'), contains('visible')),
        )),
      );

      expect(streaming.state, equals(LevelState.unloaded));
      expect(streaming.isTransitioning, isFalse);
    });

    test('unloadLevelAsync() from visible -> every actor receives onUnregister(), actors list empty, final state unloaded', () async {
      final level = LuminaLevel();
      final actor1 = LuminaActor();
      final actor2 = LuminaActor();
      level.registerActor(actor1);
      level.registerActor(actor2);

      final streaming = LuminaLevelStreaming(
        levelPath: 'contents/levels/SubLevel_A.lmas',
        levelInstance: level,
      );

      await streaming.loadLevelAsync();
      await streaming.setVisibleAsync(true);
      expect(level.actors.length, equals(2));

      await streaming.unloadLevelAsync();
      expect(level.actors, isEmpty);
      expect(streaming.state, equals(LevelState.unloaded));
      expect(actor1.isRegistered, isFalse);
      expect(actor2.isRegistered, isFalse);
    });

    test('unloadLevelAsync() while already unloaded -> completes without error, emits nothing', () async {
      final level = LuminaLevel();
      final streaming = LuminaLevelStreaming(
        levelPath: 'contents/levels/SubLevel_A.lmas',
        levelInstance: level,
      );

      final stateHistory = <LevelState>[];
      final sub = streaming.onStateChanged.listen(stateHistory.add);

      await streaming.unloadLevelAsync();
      expect(stateHistory, isEmpty);
      expect(streaming.state, equals(LevelState.unloaded));

      await sub.cancel();
    });
  });
}
