import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('AudioComponent & AudioSubsystem Tests', () {
    test('play() with baseVolume and volumeMultiplier issues single backend play with effective volume', () async {
      final backend = NullAudioBackend();
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final audioSys = LuminaAudioSubsystem(backend: backend);
      world.registerSubsystem<LuminaAudioSubsystem>(audioSys);

      final sound = LuminaSoundWave(assetPath: 'sounds/laser.wav', baseVolume: 0.8);
      final audioComp = LuminaAudioComponent(
        sound: sound,
        volumeMultiplier: 0.5,
        spatialized: false,
      );
      final actor = LuminaActor();
      actor.addComponent(audioComp);

      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      audioComp.play();
      await Future<void>.delayed(Duration.zero);

      expect(backend.playCalls.length, equals(1));
      expect(backend.playCalls.first.volume, closeTo(0.4, 1e-6));
      expect(backend.playCalls.first.looping, isFalse);
      expect(audioComp.isPlaying, isTrue);
    });

    test('stop() stops backend handle, subsequent play() creates new handle', () async {
      final backend = NullAudioBackend();
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final audioSys = LuminaAudioSubsystem(backend: backend);
      world.registerSubsystem<LuminaAudioSubsystem>(audioSys);

      final sound = LuminaSoundWave(assetPath: 'sounds/click.wav');
      final audioComp = LuminaAudioComponent(sound: sound, spatialized: false);
      final actor = LuminaActor();
      actor.addComponent(audioComp);

      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      audioComp.play();
      await Future<void>.delayed(Duration.zero);
      final handle1 = audioComp.handle;
      expect(handle1, isNotNull);

      audioComp.stop();
      expect(backend.stopCalls, contains(handle1));
      expect(audioComp.isPlaying, isFalse);

      audioComp.play();
      await Future<void>.delayed(Duration.zero);
      final handle2 = audioComp.handle;
      expect(handle2, isNotNull);
      expect(handle2, isNot(equals(handle1)));
    });

    test('fadeIn(2.0) ramps volume linearly across 0.1s step ticks', () async {
      final backend = NullAudioBackend();
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final audioSys = LuminaAudioSubsystem(backend: backend);
      world.registerSubsystem<LuminaAudioSubsystem>(audioSys);

      final sound = LuminaSoundWave(assetPath: 'sounds/music.wav', baseVolume: 1.0);
      final audioComp = LuminaAudioComponent(sound: sound, spatialized: false);
      final actor = LuminaActor();
      actor.addComponent(audioComp);

      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      audioComp.fadeIn(2.0, targetVolume: 1.0);
      await Future<void>.delayed(Duration.zero);

      // Tick 1.0s in 0.1s steps
      for (int i = 0; i < 10; i++) {
        world.tick(0.1);
      }

      expect(audioComp.fadeFactor, closeTo(0.5, 1e-5));

      // Tick another 1.0s to finish fade
      for (int i = 0; i < 10; i++) {
        world.tick(0.1);
      }

      expect(audioComp.fadeFactor, closeTo(1.0, 1e-5));

      // Subsystem syncs the final volume update
      world.tick(0.1);
      final callCount = backend.volumeCalls.length;

      // Further ticks do not generate extra volume calls (fade complete)
      world.tick(0.1);
      expect(backend.volumeCalls.length, equals(callCount));
    });

    test('fadeOut(1.0, stopWhenDone: true) hits 0.0 at t=1.0 and stops handle', () async {
      final backend = NullAudioBackend();
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final audioSys = LuminaAudioSubsystem(backend: backend);
      world.registerSubsystem<LuminaAudioSubsystem>(audioSys);

      final sound = LuminaSoundWave(assetPath: 'sounds/music.wav');
      final audioComp = LuminaAudioComponent(sound: sound, spatialized: false);
      final actor = LuminaActor();
      actor.addComponent(audioComp);

      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      audioComp.play();
      await Future<void>.delayed(Duration.zero);
      final handle = audioComp.handle!;

      audioComp.fadeOut(1.0, stopWhenDone: true);

      for (int i = 0; i < 10; i++) {
        world.tick(0.1);
      }

      expect(audioComp.isPlaying, isFalse);
      expect(backend.stopCalls, contains(handle));
    });

    test('Linear attenuation: innerRadius 2, falloffDistance 8', () {
      final attenuation = LuminaSoundAttenuation(
        innerRadius: 2.0,
        falloffDistance: 8.0,
        model: LuminaAttenuationModel.linear,
      );

      expect(attenuation.calculateGain(0.0), equals(1.0));
      expect(attenuation.calculateGain(2.0), equals(1.0));
      expect(attenuation.calculateGain(6.0), closeTo(0.5, 1e-6));
      expect(attenuation.calculateGain(10.0), equals(0.0));
      expect(attenuation.calculateGain(15.0), equals(0.0));
    });

    test('Moving listener updates attenuated volume with dirty checking', () async {
      final backend = NullAudioBackend();
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final audioSys = LuminaAudioSubsystem(backend: backend);
      world.registerSubsystem<LuminaAudioSubsystem>(audioSys);

      final sound = LuminaSoundWave(
        assetPath: 'sounds/fire.wav',
        attenuation: LuminaSoundAttenuation(innerRadius: 2.0, falloffDistance: 8.0),
      );
      final audioComp = LuminaAudioComponent(
        sound: sound,
        spatialized: true,
        location: Vector3(2.0, 0.0, 0.0),
      );
      final actor = LuminaActor();
      actor.addComponent(audioComp);

      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      audioComp.play();
      await Future<void>.delayed(Duration.zero);

      final initialCount = backend.volumeCalls.length;
      world.tick(0.016);
      expect(backend.volumeCalls.length, equals(initialCount)); // Stationary: no redundant push

      // Move listener away to (6, 0, 0) -> distance becomes 4 (attenuation ~ 0.75)
      audioSys.listenerLocation = Vector3(6.0, 0.0, 0.0);
      world.tick(0.016);
      expect(backend.volumeCalls.length, greaterThan(initialCount));
    });

    test('Panning calculation maps right (+1), ahead (0), and left (-1)', () {
      final audioSys = LuminaAudioSubsystem();
      audioSys.listenerLocation = Vector3(0.0, 0.0, 0.0);
      audioSys.listenerRotation = Quaternion.identity(); // looking along -Z, right is +X

      final panRight = audioSys.calculatePan(Vector3(5.0, 0.0, 0.0));
      final panAhead = audioSys.calculatePan(Vector3(0.0, 0.0, -5.0));
      final panLeft = audioSys.calculatePan(Vector3(-5.0, 0.0, 0.0));

      expect(panRight, closeTo(1.0, 0.01));
      expect(panAhead, closeTo(0.0, 0.01));
      expect(panLeft, closeTo(-1.0, 0.01));
    });

    test('Non-looping sound with duration fires onAudioFinished and sets isPlaying to false', () async {
      final backend = NullAudioBackend();
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final audioSys = LuminaAudioSubsystem(backend: backend);
      world.registerSubsystem<LuminaAudioSubsystem>(audioSys);

      final sound = LuminaSoundWave(
        assetPath: 'sounds/explosion.wav',
        duration: 0.5,
        looping: false,
      );
      final audioComp = LuminaAudioComponent(sound: sound, spatialized: false);
      bool finishedFired = false;
      audioComp.onAudioFinished = () => finishedFired = true;

      final actor = LuminaActor();
      actor.addComponent(audioComp);

      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      audioComp.play();
      await Future<void>.delayed(Duration.zero);

      world.tick(0.3);
      expect(finishedFired, isFalse);
      expect(audioComp.isPlaying, isTrue);

      world.tick(0.3);
      expect(finishedFired, isTrue);
      expect(audioComp.isPlaying, isFalse);
    });

    test('World shutdown stops active audio and shuts down backend', () async {
      final backend = NullAudioBackend();
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final audioSys = LuminaAudioSubsystem(backend: backend);
      world.registerSubsystem<LuminaAudioSubsystem>(audioSys);

      final sound = LuminaSoundWave(assetPath: 'sounds/loop.wav', looping: true);
      final comp1 = LuminaAudioComponent(sound: sound, spatialized: false);
      final comp2 = LuminaAudioComponent(sound: sound, spatialized: false);
      final comp3 = LuminaAudioComponent(sound: sound, spatialized: false);

      final actor = LuminaActor();
      actor.addComponent(comp1);
      actor.addComponent(comp2);
      actor.addComponent(comp3);

      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      comp1.play();
      comp2.play();
      comp3.play();
      await Future<void>.delayed(Duration.zero);

      expect(comp1.isPlaying, isTrue);
      expect(comp2.isPlaying, isTrue);
      expect(comp3.isPlaying, isTrue);

      world.cleanup();

      expect(comp1.isPlaying, isFalse);
      expect(comp2.isPlaying, isFalse);
      expect(comp3.isPlaying, isFalse);
      expect(backend.isShutdown, isTrue);
    });
  });
}
