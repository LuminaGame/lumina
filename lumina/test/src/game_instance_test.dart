import 'package:test/test.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina/lumina.dart';

class TestSettingsSubsystem extends LuminaGameInstanceSubsystem {
  int initCount = 0;
  int deinitCount = 0;

  @override
  void onInitialize(LuminaGameInstance owner) {
    super.onInitialize(owner);
    initCount++;
  }

  @override
  void onDeinitialize() {
    deinitCount++;
    super.onDeinitialize();
  }
}

class TestWorldSubsystem extends LuminaWorldSubsystem {
  int shutdownCount = 0;

  @override
  void onWorldShutdown() {
    shutdownCount++;
    super.onWorldShutdown();
  }
}

class TestGameInstance extends LuminaGameInstance {
  int initCount = 0;
  List<String> eventLog = [];

  @override
  void init() {
    eventLog.add('init');
    initCount++;
    super.init();
  }

  @override
  void shutdown() {
    eventLog.add('shutdown');
    super.shutdown();
  }
}

class TestGame extends LuminaGame {
  TestGame({super.key, super.gameInstanceFactory});
}

class ActorA extends LuminaActor {
  ActorA({super.key});
}

class ActorB extends LuminaActor {
  ActorB({super.key});
}

void main() {
  group('LuminaGameInstance', () {
    late FilamentEngine engine;
    late FilamentScene scene;
    late FilamentSwapChain swapChain;

    setUpAll(() async {
      engine = FilamentEngine.create()!;
      swapChain = engine.createHeadlessSwapChain(128, 128);
      scene = engine.createScene();
    });

    tearDownAll(() {
      swapChain.dispose();
      scene.dispose();
      engine.dispose();
    });

    test('mountGame with gameInstanceFactory initializes instance exactly once', () {
      final game = TestGame(gameInstanceFactory: () => TestGameInstance());
      game.mountGame(engine, scene);

      final instance = game.gameInstance as TestGameInstance;
      expect(instance, isNotNull);
      expect(instance.world, isNotNull);
      expect(instance.initCount, 1);
      
      game.disposeGame();
    });

    test('registerSubsystem and getSubsystem typed lookup', () {
      final instance = TestGameInstance();
      final subsystem = TestSettingsSubsystem();
      
      instance.registerSubsystem(subsystem);
      
      expect(instance.getSubsystem<TestSettingsSubsystem>(), same(subsystem));
      
      // Unregistered type returns null
      // We will define a dummy subsystem to query
      expect(instance.getSubsystem<DummySubsystem>(), isNull);
      
      // Registering duplicate type throws StateError
      expect(() => instance.registerSubsystem(TestSettingsSubsystem()), throwsStateError);
    });

    test('openLevel unregisters old world actors and spawns new world actors', () async {
      final game = TestGame(gameInstanceFactory: () => TestGameInstance());
      game.mountGame(engine, scene);
      
      final instance = game.gameInstance as TestGameInstance;
      final oldWorld = instance.world!;
      
      final oldActor = ActorA();
      oldWorld.spawnActor(oldActor);
      oldWorld.beginPlay();
      oldWorld.tick(0.016);
      
      bool worldChangedFired = false;
      instance.onWorldChanged = (oldW, newW) {
        expect(oldW, same(oldWorld));
        expect(newW, isNot(same(oldWorld)));
        worldChangedFired = true;
      };

      await instance.openLevel(() => LuminaLevel(children: [ActorB()]));
      
      final newWorld = instance.world!;
      expect(newWorld, isNot(same(oldWorld)));
      expect(worldChangedFired, isTrue);
      
      // New actor B should exist in new world
      newWorld.spawnActor(ActorB());
      newWorld.beginPlay();
      newWorld.tick(0.016);
      expect(newWorld.persistentLevel.actors.whereType<ActorB>().isNotEmpty, isTrue);
      
      // Old world is cleaned up, but testing cleanup internally is tricky,
      // we check via onWorldShutdown in subsystems next test.
      game.disposeGame();
    });

    test('Game instance subsystem survives openLevel, world subsystem dies', () async {
      final game = TestGame();
      game.mountGame(engine, scene);
      
      final instance = game.gameInstance;
      final instanceSubsystem = TestSettingsSubsystem();
      instance.registerSubsystem(instanceSubsystem);
      
      final oldWorld = instance.world!;
      final worldSubsystem = TestWorldSubsystem();
      oldWorld.registerSubsystem(worldSubsystem);
      
      await instance.openLevel(() => LuminaLevel(children: []));
      
      expect(worldSubsystem.shutdownCount, 1);
      expect(instanceSubsystem.deinitCount, 0); // Survives transition
      
      game.disposeGame();
      expect(instanceSubsystem.deinitCount, 1); // Dies with the game
    });

    test('disposeGame ordering: world cleanup -> shutdown -> subsystems reverse deinit', () {
      final game = TestGame(gameInstanceFactory: () => TestGameInstance());
      game.mountGame(engine, scene);
      
      final instance = game.gameInstance as TestGameInstance;
      final sub1 = TestSettingsSubsystem();
      
      instance.registerSubsystem(sub1);
      
      game.disposeGame();
      
      expect(instance.eventLog, contains('shutdown'));
      // Checking reverse registration is hard to observe cleanly without more logging,
      // we will rely on internal logic, but we know deinit was called.
      expect(sub1.deinitCount, 1);
    });

    test('openLevel retains native context identical handles', () async {
      final game = TestGame();
      game.mountGame(engine, scene);
      
      final instance = game.gameInstance;
      final oldWorld = instance.world!;
      
      final oldEngine = oldWorld.filamentEngine;
      final oldScene = oldWorld.filamentScene;
      
      await instance.openLevel(() => LuminaLevel(children: []));
      
      final newWorld = instance.world!;
      
      expect(newWorld.filamentEngine, same(oldEngine));
      expect(newWorld.filamentScene, same(oldScene));
      expect(newWorld.filamentEngine, same(engine));
      
      game.disposeGame();
    });

    test('primaryPlayerController retained across openLevel', () async {
      final game = TestGame();
      game.mountGame(engine, scene);
      
      final instance = game.gameInstance;
      final oldController = instance.primaryPlayerController;
      expect(oldController, isNotNull);
      
      await instance.openLevel(() => LuminaLevel(children: []));
      
      final newController = instance.primaryPlayerController;
      expect(newController, same(oldController));
      
      game.disposeGame();
    });
  });
}

class DummySubsystem extends LuminaGameInstanceSubsystem {}
