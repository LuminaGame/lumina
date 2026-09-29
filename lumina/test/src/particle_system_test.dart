import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('LuminaParticleSystem Pure Simulation Tests', () {
    test('spawnRate 10 ticks 1.0s in 0.1s steps spawns exactly 10 particles with fractional carry', () {
      final config = LuminaParticleEmitterConfig(
        spawnRate: 10.0,
        lifetimeMin: 5.0,
        lifetimeMax: 5.0,
        maxParticles: 50,
      );

      final emitter = LuminaParticleSystemComponent(config: config, randomSeed: 42);
      emitter.activate();

      for (int i = 0; i < 10; i++) {
        emitter.onTick(0.1);
      }
      expect(emitter.liveParticleCount, equals(10));

      emitter.resetSimulation();
      // Tick 0.05s steps for 1.0s (20 steps) -> still 10 particles
      for (int i = 0; i < 20; i++) {
        emitter.onTick(0.05);
      }
      expect(emitter.liveParticleCount, equals(10));
    });

    test('LuminaParticleBurst fires at specified time within loop duration', () {
      final config = LuminaParticleEmitterConfig(
        spawnRate: 0.0,
        bursts: [const LuminaParticleBurst(0.5, 5)],
        looping: true,
        duration: 1.0,
        lifetimeMin: 5.0,
        lifetimeMax: 5.0,
      );

      final emitter = LuminaParticleSystemComponent(config: config);
      emitter.activate();

      // Before t=0.5
      emitter.onTick(0.4);
      expect(emitter.liveParticleCount, equals(0));

      // At t=0.5
      emitter.onTick(0.15);
      expect(emitter.liveParticleCount, equals(5));

      // Next loop at t=1.5
      emitter.onTick(0.8); // t = 1.35
      expect(emitter.liveParticleCount, equals(5));

      emitter.onTick(0.2); // t = 1.55 (crosses 1.5)
      expect(emitter.liveParticleCount, equals(10));
    });

    test('Particles die on crossing lifetime and free indices are recycled', () {
      final config = LuminaParticleEmitterConfig(
        spawnRate: 0.0,
        bursts: [const LuminaParticleBurst(0.0, 3)],
        looping: false,
        lifetimeMin: 0.3,
        lifetimeMax: 0.3,
      );

      final emitter = LuminaParticleSystemComponent(config: config);
      emitter.activate();

      emitter.onTick(0.1); // t = 0.1, born at t=0, age=0
      expect(emitter.liveParticleCount, equals(3));

      emitter.onTick(0.1); // t = 0.2, age 0.1 < 0.3
      expect(emitter.liveParticleCount, equals(3));

      emitter.onTick(0.1); // t = 0.3, age 0.2 < 0.3
      expect(emitter.liveParticleCount, equals(3));

      emitter.onTick(0.15); // t = 0.45, age 0.35 >= 0.3 -> died
      expect(emitter.liveParticleCount, equals(0));
    });

    test('maxParticles caps live particles and drops excess spawn requests', () {
      final config = LuminaParticleEmitterConfig(
        spawnRate: 100.0,
        lifetimeMin: 5.0,
        lifetimeMax: 5.0,
        maxParticles: 4,
      );

      final emitter = LuminaParticleSystemComponent(config: config);
      emitter.activate();

      emitter.onTick(0.5); // wants to spawn 50 particles
      expect(emitter.liveParticleCount, equals(4));
    });

    test('Gravity and drag explicit Euler integration', () {
      final config = LuminaParticleEmitterConfig(
        spawnRate: 0.0,
        bursts: [const LuminaParticleBurst(0.0, 1)],
        looping: false,
        speedMin: 0.0,
        speedMax: 0.0,
        gravity: Vector3(0.0, -10.0, 0.0),
        drag: 0.0,
        lifetimeMin: 5.0,
        lifetimeMax: 5.0,
      );

      final emitter = LuminaParticleSystemComponent(config: config);
      emitter.activate();

      // Spawn at t=0
      emitter.onTick(0.0001);

      // 10 ticks of 0.1s
      // Explicit Euler order: v += g*dt; p += v*dt
      // tick 1: v = -1, p = -0.1
      // tick 2: v = -2, p = -0.3
      // ...
      // tick 10: v = -10, p = -5.5
      for (int i = 0; i < 10; i++) {
        emitter.onTick(0.1);
      }

      expect(emitter.getParticleVelocity(0).y, closeTo(-10.0, 1e-4));
      expect(emitter.getParticlePosition(0).y, closeTo(-5.5, 1e-4));
    });

    test('Cone angle direction distribution', () {
      // 0 degree cone -> all particles shoot along forward vector (0, 0, -1)
      final config0 = LuminaParticleEmitterConfig(
        spawnRate: 0.0,
        bursts: [const LuminaParticleBurst(0.0, 10)],
        looping: false,
        speedMin: 5.0,
        speedMax: 5.0,
        coneAngleDegrees: 0.0,
      );

      final emitter0 = LuminaParticleSystemComponent(config: config0, randomSeed: 123);
      emitter0.activate();
      emitter0.onTick(0.016);

      for (int i = 0; i < 10; i++) {
        final vel = emitter0.getParticleVelocity(i);
        expect(vel.x, closeTo(0.0, 1e-5));
        expect(vel.y, closeTo(0.0, 1e-5));
        expect(vel.z, closeTo(-5.0, 1e-5));
      }
    });

    test('Curve and gradient sampling', () {
      final config = LuminaParticleEmitterConfig(
        colorOverLife: [
          LuminaGradientStop(0.0, Vector4(1.0, 1.0, 1.0, 1.0)),
          LuminaGradientStop(1.0, Vector4(1.0, 0.0, 0.0, 0.0)),
        ],
        sizeOverLife: [
          LuminaCurvePoint(0.0, 0.0),
          LuminaCurvePoint(0.2, 1.0),
          LuminaCurvePoint(1.0, 0.0),
        ],
      );

      final cMid = config.sampleColorAt(0.5);
      expect(cMid.x, closeTo(1.0, 1e-4));
      expect(cMid.y, closeTo(0.5, 1e-4));
      expect(cMid.z, closeTo(0.5, 1e-4));
      expect(cMid.w, closeTo(0.5, 1e-4));

      expect(config.sampleSizeAt(0.1), closeTo(0.5, 1e-4));
      expect(config.sampleSizeAt(0.6), closeTo(0.5, 1e-4));
      expect(config.sampleSizeAt(1.5), closeTo(0.0, 1e-4)); // Clamped
    });

    test('onSystemFinished fires on non-looping emitter completion', () {
      final config = LuminaParticleEmitterConfig(
        spawnRate: 0.0,
        bursts: [const LuminaParticleBurst(0.0, 2)],
        looping: false,
        lifetimeMin: 0.2,
        lifetimeMax: 0.2,
      );

      final emitter = LuminaParticleSystemComponent(config: config);
      bool finished = false;
      emitter.onSystemFinished = () => finished = true;
      emitter.activate();

      emitter.onTick(0.01); // spawn
      expect(finished, isFalse);

      emitter.onTick(0.1); // age 0.1
      expect(finished, isFalse);

      emitter.onTick(0.15); // age 0.25 >= 0.2s lifetime -> died
      expect(finished, isTrue);
    });
  });
}
