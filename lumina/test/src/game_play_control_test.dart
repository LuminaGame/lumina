import 'package:flutter/widgets.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

// ---------------------------------------------------------------------------
// Fakes for the frame driver scenario (mirrors test/src/world/frame_driver_test.dart)
// ---------------------------------------------------------------------------

class FakeFilamentRenderer implements FilamentRenderer {
  final List<String> callLog = [];
  bool shouldRender = true;

  @override
  bool beginFrame(FilamentSwapChain swapChain, {int vsyncSteadyClockTimeNano = 0, int vsyncNs = 0}) {
    callLog.add('beginFrame');
    return true;
  }

  @override
  void render(FilamentView view) => callLog.add('render');

  @override
  void endFrame() => callLog.add('endFrame');

  @override
  void skipFrame({int vsyncSteadyClockNanos = 0}) => callLog.add('skipFrame');

  @override
  bool get shouldRenderFrame => shouldRender;

  @override
  List<FrameInfo> getFrameInfoHistory([int count = 1]) => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFilamentSwapChain implements FilamentSwapChain {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFilamentView implements FilamentView {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Game-side fixtures
// ---------------------------------------------------------------------------

class CountingActor extends LuminaActor {
  int tickCount = 0;
  final List<double> deltas = [];
  CountingActor({super.key});

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    tickCount++;
    deltas.add(deltaTime);
  }
}

/// Pawn that counts how often its controller drove it (LuminaPlayerController.onTick -> faceRotation).
class CountingPawn extends LuminaPawn {
  int faceRotationCalls = 0;

  @override
  void faceRotation(Vector3 newRotation, double deltaTime) {
    faceRotationCalls++;
    super.faceRotation(newRotation, deltaTime);
  }
}

/// A game whose declarative tree contributes one [CountingActor] to the persistent level.
class PlayControlGame extends LuminaGame {
  CountingActor? lastBuiltActor;
  int buildCount = 0;

  PlayControlGame({super.gameInstanceFactory});

  @override
  LuminaObject? build(LuminaBuildContext context) {
    buildCount++;
    lastBuiltActor = CountingActor();
    return LuminaNodeGroup(children: [lastBuiltActor!]);
  }
}

void main() {
  late FilamentEngine engine;
  late FilamentScene scene;

  setUp(() {
    engine = FilamentEngine.create()!;
    scene = engine.createScene();
  });

  tearDown(() {
    scene.dispose();
    engine.dispose();
  });

  /// Mounts a game, begins play and returns it together with the actor the tree built.
  (PlayControlGame, CountingActor) mountPlaying() {
    final game = PlayControlGame();
    game.mountGame(engine, scene);
    game.world!.beginPlay();
    final actor = game.world!.actors.whereType<CountingActor>().single;
    return (game, actor);
  }

  group('LuminaGame play control', () {
    test('playState transitions and stream emits one event per transition', () async {
      final game = PlayControlGame();
      expect(game.playState, LuminaPlayState.stopped);
      expect(game.isPaused, isFalse);

      final events = <LuminaPlayState>[];
      final sub = game.playStateStream.listen(events.add);

      game.mountGame(engine, scene);
      expect(game.playState, LuminaPlayState.playing);

      game.pause();
      game.pause(); // idempotent
      expect(game.isPaused, isTrue);
      expect(game.playState, LuminaPlayState.paused);

      game.resume();
      game.resume(); // idempotent
      expect(game.isPaused, isFalse);
      expect(game.playState, LuminaPlayState.playing);

      game.disposeGame();
      expect(game.playState, LuminaPlayState.stopped);

      await Future<void>.delayed(Duration.zero);
      expect(events, [
        LuminaPlayState.playing,
        LuminaPlayState.paused,
        LuminaPlayState.playing,
        LuminaPlayState.stopped,
      ]);
      await sub.cancel();
    });

    test('pause/resume while stopped are no-ops', () {
      final game = PlayControlGame();
      game.pause();
      expect(game.playState, LuminaPlayState.stopped);
      game.resume();
      expect(game.playState, LuminaPlayState.stopped);
    });

    test('tickGame is a no-op while paused; resume advances again', () {
      final (game, actor) = mountPlaying();
      final world = game.world!;

      game.tickGame(0.016);
      game.tickGame(0.016);
      expect(actor.tickCount, 2);
      expect(world.tickCount, 2);
      final timeBefore = world.timeSeconds;

      game.pause();
      expect(world.isPaused, isTrue);
      for (var i = 0; i < 5; i++) {
        game.tickGame(0.016);
      }
      expect(actor.tickCount, 2);
      expect(world.tickCount, 2);
      expect(world.timeSeconds, timeBefore);

      game.resume();
      expect(world.isPaused, isFalse);
      game.tickGame(0.016);
      expect(actor.tickCount, 3);
      expect(world.tickCount, 3);
      expect(world.timeSeconds, closeTo(timeBefore + 0.016, 1e-9));

      game.disposeGame();
    });

    test('step advances exactly one tick while paused and keeps the game paused', () {
      final (game, actor) = mountPlaying();
      final world = game.world!;
      final pc = game.gameInstance.primaryPlayerController!;
      final pawn = CountingPawn();
      world.spawnActor(pawn);
      game.tickGame(0.016); // registers the pawn (deferred spawn)
      pc.possess(pawn);
      final pawnCallsBefore = pawn.faceRotationCalls;

      game.pause();
      game.step(0.016);
      expect(world.tickCount, 2);
      expect(actor.tickCount, 2);
      expect(actor.deltas, [0.016, 0.016]);
      expect(pawn.faceRotationCalls, pawnCallsBefore + 1);
      expect(game.isPaused, isTrue);
      expect(game.playState, LuminaPlayState.paused);

      // Ordinary ticks still do nothing after the step.
      game.tickGame(0.016);
      expect(world.tickCount, 2);
      expect(pawn.faceRotationCalls, pawnCallsBefore + 1);

      game.disposeGame();
      expect(() => game.step(0.016), throwsStateError);
    });

    test('step while stopped throws StateError', () {
      final game = PlayControlGame();
      expect(() => game.step(0.016), throwsStateError);
    });

    test('timer manager does not advance while paused', () {
      final (game, _) = mountPlaying();
      final world = game.world!;
      final timers = world.registerSubsystem(LuminaTimerManager());
      var fired = 0;
      timers.setTimer(() => fired++, rate: 0.05);

      game.pause();
      for (var i = 0; i < 10; i++) {
        game.tickGame(0.016);
      }
      expect(fired, 0);

      game.resume();
      for (var i = 0; i < 4; i++) {
        game.tickGame(0.016);
      }
      expect(fired, 1);
      game.disposeGame();
    });

    test('audio subsystem pauses and resumes only what the world pause paused', () async {
      final (game, _) = mountPlaying();
      final world = game.world!;
      final backend = NullAudioBackend();
      world.registerSubsystem(LuminaAudioSubsystem(backend: backend));

      final sound = LuminaSoundWave(assetPath: 'sounds/a.wav', duration: 10.0);
      final playing = LuminaAudioComponent(sound: sound, spatialized: false);
      final stoppedBefore = LuminaAudioComponent(sound: sound, spatialized: false);
      final host = LuminaActor();
      host.addComponent(playing);
      host.addComponent(stoppedBefore);
      world.spawnActor(host);
      game.tickGame(0.016);

      playing.play();
      stoppedBefore.play();
      await Future<void>.delayed(Duration.zero);
      final playingHandle = playing.handle!;
      final stoppedHandle = stoppedBefore.handle!;
      stoppedBefore.stop();
      backend.callLog.clear();

      game.pause();
      expect(backend.callLog, contains('pause($playingHandle)'));
      expect(backend.callLog, isNot(contains('pause($stoppedHandle)')));
      expect(backend.isPlaying(playingHandle), isFalse);

      game.resume();
      expect(backend.callLog, contains('resume($playingHandle)'));
      expect(backend.callLog, isNot(contains('resume($stoppedHandle)')));
      expect(backend.isPlaying(playingHandle), isTrue);

      game.disposeGame();
    });

    test('frame driver keeps rendering while the world is paused and resumes without a dt hitch', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.beginPlay();
      final renderer = FakeFilamentRenderer();
      final driver = LuminaFrameDriver(
        world,
        renderer: renderer,
        swapChain: FakeFilamentSwapChain(),
        view: FakeFilamentView(),
        useFramePacer: false,
      );
      final deltas = <double>[];
      world.onPreTick = deltas.add;

      driver.onVsync(1000000000);
      expect(world.tickCount, 1);

      world.isPaused = true;
      renderer.callLog.clear();
      for (var i = 1; i <= 3; i++) {
        driver.onVsync(1000000000 + i * 16666667);
      }
      expect(world.tickCount, 1);
      expect(renderer.callLog, ['beginFrame', 'render', 'endFrame', 'beginFrame', 'render', 'endFrame', 'beginFrame', 'render', 'endFrame']);
      expect(driver.hitchCount, 0);

      world.isPaused = false;
      driver.onVsync(3000000000 + 1000000000); // 2 s after the last paused vsync
      expect(world.tickCount, 2);
      expect(deltas.last, closeTo(0.016666667, 1e-6));
      expect(driver.hitchCount, 0);

      driver.dispose();
      world.cleanup();
    });

    test('restart rebuilds a fresh world on the same engine/scene and ends playing', () {
      final (game, oldActor) = mountPlaying();
      final oldWorld = game.world!;
      final instance = game.gameInstance;
      game.tickGame(0.016);
      game.tickGame(0.016);
      expect(oldWorld.tickCount, 2);

      LuminaWorld? changedFrom;
      LuminaWorld? changedTo;
      instance.onWorldChanged = (o, n) {
        changedFrom = o;
        changedTo = n;
      };

      game.pause();
      game.restart();

      final newWorld = game.world!;
      expect(oldWorld.isCleanedUp, isTrue);
      expect(newWorld, isNot(same(oldWorld)));
      expect(newWorld.isCleanedUp, isFalse);
      expect(newWorld.filamentEngine, same(engine));
      expect(newWorld.filamentScene, same(scene));
      expect(newWorld.hasBegunPlay, isTrue);
      expect(newWorld.tickCount, 0);
      expect(changedFrom, same(oldWorld));
      expect(changedTo, same(newWorld));
      expect(game.playState, LuminaPlayState.playing);
      expect(game.buildCount, 2);

      final actors = newWorld.actors.whereType<CountingActor>().toList();
      expect(actors, hasLength(1));
      expect(actors.single, isNot(same(oldActor)));
      expect(actors.single, same(game.lastBuiltActor));

      game.tickGame(0.016);
      expect(actors.single.tickCount, 1);
      expect(oldActor.tickCount, 2);

      game.disposeGame();
      expect(() => game.restart(), throwsStateError);
    });

    test('restart on a world that never began play does not begin play', () {
      final game = PlayControlGame();
      game.mountGame(engine, scene);
      expect(game.world!.hasBegunPlay, isFalse);
      game.restart();
      expect(game.world!.hasBegunPlay, isFalse);
      game.disposeGame();
    });
  });

  group('LuminaGameWidget play control', () {
    testWidgets('paused flag and onPlayStateChanged are wired to the game', (tester) async {
      final game = PlayControlGame();
      final states = <LuminaPlayState>[];

      Widget build(bool paused) => Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 64,
              height: 64,
              child: LuminaGameWidget(
                game: game,
                paused: paused,
                useHeadlessSwapChain: false,
                onPlayStateChanged: states.add,
              ),
            ),
          );

      await tester.pumpWidget(build(true));
      await tester.pump();
      await tester.pump();

      if (game.playState == LuminaPlayState.stopped) {
        // FilamentWidget could not create a scene in this test binding.
        await tester.pumpWidget(const SizedBox.shrink());
        markTestSkipped('FilamentWidget did not create a scene in the test binding');
        return;
      }

      expect(game.isPaused, isTrue);
      expect(states.first, LuminaPlayState.playing);
      expect(states.last, LuminaPlayState.paused);

      await tester.pumpWidget(build(false));
      await tester.pump();
      expect(game.isPaused, isFalse);
      expect(states.last, LuminaPlayState.playing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(game.playState, LuminaPlayState.stopped);
    });
  });
}
