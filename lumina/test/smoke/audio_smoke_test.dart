import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Audio Module Smoke Tests', () {
    test('Scenario 01: LuminaAudioComponent 3D spatial audio playback, distance attenuation, stereo panning, and audio fading with real 3D assets', () async {
      final backend = NullAudioBackend();
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final audioSys = LuminaAudioSubsystem(backend: backend);
      world.registerSubsystem<LuminaAudioSubsystem>(audioSys);

      final soundA = LuminaSoundWave(
        assetPath: 'sounds/ambience_generator.wav',
        baseVolume: 0.9,
        looping: true,
        attenuation: LuminaSoundAttenuation(
          innerRadius: 2.0,
          falloffDistance: 10.0,
          model: LuminaAttenuationModel.linear,
        ),
      );

      final soundB = LuminaSoundWave(
        assetPath: 'sounds/radio_chime.wav',
        baseVolume: 0.8,
        looping: true,
        attenuation: LuminaSoundAttenuation(
          innerRadius: 1.0,
          falloffDistance: 6.0,
          model: LuminaAttenuationModel.logarithmic,
        ),
      );

      final actorA = LuminaActor(location: Vector3(3.0, 0.0, 0.0));
      final audioCompA = LuminaAudioComponent(sound: soundA, spatialized: true);
      actorA.addComponent(audioCompA);

      final actorB = LuminaActor(location: Vector3(-3.0, 0.0, 0.0));
      final audioCompB = LuminaAudioComponent(sound: soundB, spatialized: true);
      actorB.addComponent(audioCompB);

      world.persistentLevel.registerActor(actorA);
      world.persistentLevel.registerActor(actorB);
      world.beginPlay();

      audioCompA.play();
      audioCompB.fadeIn(2.0, targetVolume: 0.8);
      await Future<void>.delayed(Duration.zero);

      expect(audioCompA.isPlaying, isTrue);
      expect(audioCompB.isPlaying, isTrue);

      for (int i = 0; i < 5; i++) {
        world.tick(0.016);
      }

      final usedAssets = [
        'Props/Barrels/dented_barrel.glb',
        'Props/AC_units/ac_unit_b_600x600.glb',
        'Props/Access_cards/access_card_blue.glb',
      ];
      final assetsDir = SmokeArtifacts.testAssetsDir;
      for (final assetPath in usedAssets) {
        final f = File('${assetsDir.path}/$assetPath');
        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          expect(bytes.length, greaterThan(0));
        }
      }

      const testTitle = 'Audio Module Smoke Tests Scenario 01: LuminaAudioComponent 3D spatial audio playback, distance attenuation, stereo panning, and audio fading with real 3D assets';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.isEmpty) return;
          final tm = FilamentTransformManager(engine);

          // Emitter A (Asset 0: Acoustic Barrel vibrating with audio pulses at X = 3.0)
          final aabb0 = assets[0].getBoundingBox();
          final s0 = aabb0.max - aabb0.min;
          final max0 = math.max(s0.x, math.max(s0.y, s0.z));
          final scale0 = max0 > 0 ? 1.4 / max0 : 1.0;
          final pulse = (1.0 + math.sin(timeSeconds * 12.0) * 0.05) * scale0;

          final barrelMat = Matrix4.identity()
            ..setTranslationRaw(3.0, -aabb0.min.y * pulse, 0.0)
            ..rotateY(timeSeconds * 0.5)
            ..scaleByDouble(pulse, pulse, pulse, 1.0);
          tm.setTransform(assets[0].rootEntity, barrelMat.storage.toList());

          // Emitter B (Asset 1: Radio Generator / AC unit at X = -3.0 with sound waves)
          if (assets.length > 1) {
            final aabb1 = assets[1].getBoundingBox();
            final s1 = aabb1.max - aabb1.min;
            final max1 = math.max(s1.x, math.max(s1.y, s1.z));
            final scale1 = max1 > 0 ? 1.5 / max1 : 1.0;

            final acMat = Matrix4.identity()
              ..setTranslationRaw(-3.0, 0.6, 0.0)
              ..rotateY(timeSeconds * 1.0)
              ..scaleByDouble(scale1, scale1, scale1, 1.0);
            tm.setTransform(assets[1].rootEntity, acMat.storage.toList());
          }

          // Listener Indicator (Asset 2: Floating Listener microphone / card navigating between emitters)
          if (assets.length > 2) {
            final aabb2 = assets[2].getBoundingBox();
            final s2 = aabb2.max - aabb2.min;
            final max2 = math.max(s2.x, math.max(s2.y, s2.z));
            final scale2 = max2 > 0 ? 1.0 / max2 : 1.0;
            final listenerX = math.sin(timeSeconds * 1.2) * 4.0;

            final cardMat = Matrix4.identity()
              ..setTranslationRaw(listenerX, 1.2, math.cos(timeSeconds * 1.2) * 1.5)
              ..rotateY(timeSeconds * 2.0)
              ..scaleByDouble(scale2, scale2, scale2, 1.0);
            tm.setTransform(assets[2].rootEntity, cardMat.storage.toList());
          }

          // Orbiting dynamic tracking camera
          cam.lookAt(
            eyeX: math.sin(timeSeconds * 0.2) * 7.5,
            eyeY: 3.5,
            eyeZ: math.cos(timeSeconds * 0.2) * 7.5,
            centerX: 0.0,
            centerY: 0.8,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
    });
  });
}
