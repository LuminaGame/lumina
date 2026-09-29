import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina/lumina.dart';

class RecordingSubsystem extends LuminaWorldSubsystem {
  int tickCount = 0;
  int beginPlayCount = 0;

  @override
  void onWorldBeginPlay() {
    super.onWorldBeginPlay();
    beginPlayCount++;
  }

  @override
  void onWorldTick(double deltaTime) {
    super.onWorldTick(deltaTime);
    tickCount++;
  }
}

class RecordingActor extends LuminaActor {
  int tickCount = 0;
  int beginPlayCount = 0;

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    beginPlayCount++;
  }

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    tickCount++;
  }
}

void main() {
  group('World Type and Native Handles Tests (Task 03)', () {
    test('LuminaWorld() defaults to game worldType with runsGameplay == true', () {
      final world = LuminaWorld();
      expect(world.worldType, equals(LuminaWorldType.game));
      expect(world.worldType.runsGameplay, isTrue);
    });

    test('LuminaWorldType extension truth table is asserted exhaustively for all 4 values', () {
      // runsGameplay: game: T, editor: F, pie: T, preview: F
      expect(LuminaWorldType.game.runsGameplay, isTrue);
      expect(LuminaWorldType.editor.runsGameplay, isFalse);
      expect(LuminaWorldType.pie.runsGameplay, isTrue);
      expect(LuminaWorldType.preview.runsGameplay, isFalse);

      // ticksSubsystems: game: T, editor: T, pie: T, preview: F
      expect(LuminaWorldType.game.ticksSubsystems, isTrue);
      expect(LuminaWorldType.editor.ticksSubsystems, isTrue);
      expect(LuminaWorldType.pie.ticksSubsystems, isTrue);
      expect(LuminaWorldType.preview.ticksSubsystems, isFalse);

      // runsRenderPrep: all True
      expect(LuminaWorldType.game.runsRenderPrep, isTrue);
      expect(LuminaWorldType.editor.runsRenderPrep, isTrue);
      expect(LuminaWorldType.pie.runsRenderPrep, isTrue);
      expect(LuminaWorldType.preview.runsRenderPrep, isTrue);

      // isEditorWorld: game: F, editor: T, pie: T, preview: F
      expect(LuminaWorldType.game.isEditorWorld, isFalse);
      expect(LuminaWorldType.editor.isEditorWorld, isTrue);
      expect(LuminaWorldType.pie.isEditorWorld, isTrue);
      expect(LuminaWorldType.preview.isEditorWorld, isFalse);
    });

    test('Editor world: ticks subsystems but does not run gameplay actor beginPlay or ticks', () {
      final world = LuminaWorld(worldType: LuminaWorldType.editor);

      final subsystem = RecordingSubsystem();
      world.registerSubsystem(subsystem);

      final actor = RecordingActor();
      world.persistentLevel.registerActor(actor);
      actor.onRegister(world);
      actor.onInitialize();

      world.beginPlay(); // No-op on editor world
      expect(actor.beginPlayCount, equals(0));

      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      expect(actor.beginPlayCount, equals(0));
      expect(actor.tickCount, equals(0));
      expect(subsystem.tickCount, equals(3));
    });

    test('PIE world: behaves identically to game world (1 onBeginPlay, 3 onTick)', () {
      final world = LuminaWorld(worldType: LuminaWorldType.pie);

      final subsystem = RecordingSubsystem();
      world.registerSubsystem(subsystem);

      final actor = RecordingActor();
      world.persistentLevel.registerActor(actor);
      actor.onRegister(world);

      world.beginPlay();
      expect(actor.beginPlayCount, equals(1));
      expect(subsystem.beginPlayCount, equals(1));

      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      expect(actor.tickCount, equals(3));
      expect(subsystem.tickCount, equals(3));
    });

    test('Preview world: 0 actor ticks, 0 subsystem ticks, render-prep hook fires 3 times', () {
      final world = LuminaWorld(worldType: LuminaWorldType.preview);

      final subsystem = RecordingSubsystem();
      world.registerSubsystem(subsystem);

      final actor = RecordingActor();
      world.persistentLevel.registerActor(actor);
      actor.onRegister(world);

      int renderPrepCount = 0;
      world.onRenderPrepCallback = (_) => renderPrepCount++;

      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      expect(actor.tickCount, equals(0));
      expect(subsystem.tickCount, equals(0));
      expect(renderPrepCount, equals(3));
    });

    test('Native context: throwing getters when unbound, non-null when bound', () {
      final world = LuminaWorld();

      expect(world.hasNativeContext, isFalse);
      expect(world.filamentEngineOrNull, isNull);
      expect(world.filamentSceneOrNull, isNull);

      expect(
        () => world.filamentEngine,
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('initializeNativeContext'))),
      );
      expect(
        () => world.filamentScene,
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('initializeNativeContext'))),
      );

      final engine = FilamentEngine.create(backend: FilamentBackend.noop);
      if (engine != null) {
        final scene = engine.createScene();
        world.initializeNativeContext(engine, scene);

        expect(world.hasNativeContext, isTrue);
        expect(identical(world.filamentEngine, engine), isTrue);
        expect(identical(world.filamentScene, scene), isTrue);
        expect(identical(world.filamentEngineOrNull, engine), isTrue);
        expect(identical(world.filamentSceneOrNull, scene), isTrue);

        world.cleanup();
        engine.destroyScene(scene);
        engine.dispose();
      }
    });

    test('initializeNativeContext re-bind throws StateError; bind after cleanup throws StateError', () {
      final world = LuminaWorld();

      final engine = FilamentEngine.create(backend: FilamentBackend.noop);
      if (engine != null) {
        final scene = engine.createScene();
        world.initializeNativeContext(engine, scene);

        // Re-binding without cleanup throws StateError
        expect(
          () => world.initializeNativeContext(engine, scene),
          throwsA(isA<StateError>()),
        );

        world.cleanup();

        // Binding after cleanup throws StateError
        expect(
          () => world.initializeNativeContext(engine, scene),
          throwsA(isA<StateError>()),
        );
        expect(world.filamentEngineOrNull, isNull);
        expect(world.hasNativeContext, isFalse);

        engine.destroyScene(scene);
        engine.dispose();
      }
    });

    test('tick after cleanup throws StateError', () {
      final world = LuminaWorld();
      world.cleanup();

      expect(
        () => world.tick(1.0 / 60.0),
        throwsA(isA<StateError>()),
      );
    });
  });
}
