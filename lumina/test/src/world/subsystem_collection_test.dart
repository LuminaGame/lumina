import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

class FakeAudioSubsystem extends LuminaWorldSubsystem {
  final List<String>? eventLog;
  FakeAudioSubsystem([this.eventLog]);

  @override
  void onWorldInitialize(LuminaWorld world) {
    super.onWorldInitialize(world);
    eventLog?.add('audio:initialize');
  }

  @override
  void onWorldBeginPlay() {
    super.onWorldBeginPlay();
    eventLog?.add('audio:beginPlay');
  }

  @override
  void onWorldTick(double deltaTime) {
    super.onWorldTick(deltaTime);
    eventLog?.add('audio:tick');
  }

  @override
  void onWorldShutdown() {
    eventLog?.add('audio:shutdown');
    super.onWorldShutdown();
  }
}

class FakeRenderSubsystem extends LuminaWorldSubsystem {
  final List<String>? eventLog;
  FakeRenderSubsystem([this.eventLog]);

  @override
  void onWorldInitialize(LuminaWorld world) {
    super.onWorldInitialize(world);
    eventLog?.add('render:initialize');
  }

  @override
  void onWorldBeginPlay() {
    super.onWorldBeginPlay();
    eventLog?.add('render:beginPlay');
  }

  @override
  void onWorldTick(double deltaTime) {
    super.onWorldTick(deltaTime);
    eventLog?.add('render:tick');
  }

  @override
  void onWorldShutdown() {
    eventLog?.add('render:shutdown');
    super.onWorldShutdown();
  }
}

class FakeOtherSubsystem extends LuminaWorldSubsystem {}

void main() {
  group('World Subsystem Collection Tests (Task 02)', () {
    test('registerSubsystem initializes and getSubsystem returns identical instance', () {
      final collection = LuminaSubsystemCollection();
      final world = LuminaWorld();

      final physics = LuminaPhysicsWorldSubsystem();
      collection.registerSubsystem(physics, world);

      final retrieved = collection.getSubsystem<LuminaPhysicsWorldSubsystem>();
      expect(retrieved, isNotNull);
      expect(identical(retrieved, physics), isTrue);
      expect(physics.isInitialized, isTrue);
      expect(physics.world, equals(world));
      expect(collection.contains<LuminaPhysicsWorldSubsystem>(), isTrue);
      expect(collection.length, equals(1));
    });

    test('Base-typed registration correctly keys runtimeType and allows concrete getSubsystem lookup', () {
      final collection = LuminaSubsystemCollection();
      final world = LuminaWorld();

      LuminaWorldSubsystem s = FakeAudioSubsystem();
      collection.registerSubsystem(s, world);

      expect(collection.getSubsystem<FakeAudioSubsystem>(), isNotNull);
      expect(collection.getSubsystem<FakeAudioSubsystem>(), isA<FakeAudioSubsystem>());
    });

    test('getSubsystem on unregistered type returns null without throwing', () {
      final collection = LuminaSubsystemCollection();
      expect(collection.getSubsystem<FakeOtherSubsystem>(), isNull);
      expect(collection.contains<FakeOtherSubsystem>(), isFalse);
    });

    test('Duplicate registration throws StateError with type name and leaves original untouched', () {
      final collection = LuminaSubsystemCollection();
      final world = LuminaWorld();

      final audio1 = FakeAudioSubsystem();
      collection.registerSubsystem(audio1, world);

      final audio2 = FakeAudioSubsystem();
      expect(
        () => collection.registerSubsystem(audio2, world),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('FakeAudioSubsystem'))),
      );

      expect(identical(collection.getSubsystem<FakeAudioSubsystem>(), audio1), isTrue);
    });

    test('Subsystem lifecycle order: [initialize, beginPlay, tick, tick, shutdown]', () {
      final eventLog = <String>[];
      final collection = LuminaSubsystemCollection();
      final world = LuminaWorld();

      final audio = FakeAudioSubsystem(eventLog);
      collection.registerSubsystem(audio, world);
      collection.notifyBeginPlay();
      collection.notifyTick(1.0 / 60.0);
      collection.notifyTick(1.0 / 60.0);
      collection.shutdown();

      expect(eventLog, equals([
        'audio:initialize',
        'audio:beginPlay',
        'audio:tick',
        'audio:tick',
        'audio:shutdown',
      ]));
    });

    test('Registration-order tick and reverse-order shutdown for [A, B]', () {
      final eventLog = <String>[];
      final collection = LuminaSubsystemCollection();
      final world = LuminaWorld();

      final audio = FakeAudioSubsystem(eventLog);
      final render = FakeRenderSubsystem(eventLog);

      collection.registerSubsystem(audio, world);
      collection.registerSubsystem(render, world);

      eventLog.clear();
      collection.notifyTick(1.0 / 60.0);
      expect(eventLog, equals(['audio:tick', 'render:tick']));

      eventLog.clear();
      collection.shutdown();
      expect(eventLog, equals(['render:shutdown', 'audio:shutdown']));
    });

    test('After shutdown: length is 0, getters return null, world is null, and second shutdown is no-op', () {
      final eventLog = <String>[];
      final collection = LuminaSubsystemCollection();
      final world = LuminaWorld();

      final audio = FakeAudioSubsystem(eventLog);
      collection.registerSubsystem(audio, world);
      expect(collection.length, equals(1));

      collection.shutdown();
      expect(collection.length, equals(0));
      expect(collection.getSubsystem<FakeAudioSubsystem>(), isNull);
      expect(audio.world, isNull);
      expect(audio.isInitialized, isFalse);

      final count = eventLog.length;
      collection.shutdown();
      expect(eventLog.length, equals(count));
    });

    test('Integration with LuminaWorld tick and beginPlay pipeline', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final physics = LuminaPhysicsWorldSubsystem();
      world.registerSubsystem(physics);

      world.beginPlay();
      expect(physics.isInitialized, isTrue);

      world.tick(0.016);
      world.tick(0.016);
      world.tick(0.016);

      expect(physics.stepCount, equals(3));
      expect(physics.totalSimulatedTime, closeTo(0.048, 0.0001));
    });
  });
}
