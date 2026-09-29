import 'dart:math' as math;

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// Post-process volume blending, pure math:
/// blend-radius falloff, priority order, blend weight, booleans switching at
/// one half, untouched fields, fog density scale, the controller's baseline.
void main() {
  group('LuminaPostProcessVolume.weightFor', () {
    LuminaPostProcessVolume box({double blend = 100.0, Matrix4? transform}) => LuminaPostProcessVolume(
          halfExtent: Vector3.all(100.0),
          blendRadius: blend,
          worldTransform: transform,
        );

    test('1 inside, linear falloff over the blend radius outside, 0 beyond', () {
      final v = box();
      expect(v.weightFor(Vector3.zero()), 1.0);
      expect(v.weightFor(Vector3(150.0, 0, 0)), closeTo(0.5, 1e-9), reason: '50 cm outside a face, blend 100');
      expect(v.weightFor(Vector3(200.0, 0, 0)), closeTo(0.0, 1e-9));
      expect(v.weightFor(Vector3(900.0, 0, 0)), 0.0);
      expect(v.containsPoint(Vector3(99.0, 99.0, -99.0)), isTrue);
      expect(v.containsPoint(Vector3(101.0, 0, 0)), isFalse);
    });

    test('unbound is 1 anywhere and without a camera; a bound volume needs a camera', () {
      final v = box()..unbound = true;
      expect(v.weightFor(Vector3(1e6, 1e6, 1e6)), 1.0);
      expect(v.weightFor(null), 1.0);
      expect(box().weightFor(null), 0.0);
    });

    test('a rotated box contains the point its rotated face covers; scale grows the box', () {
      final yaw90 = Matrix4.compose(Vector3.zero(), Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 2), Vector3(1, 1, 1));
      final v = LuminaPostProcessVolume(halfExtent: Vector3(300.0, 50.0, 50.0), worldTransform: yaw90, blendRadius: 0);
      expect(v.containsPoint(Vector3(0, 0, 250.0)), isTrue, reason: 'the long axis now lies along Z');
      expect(v.containsPoint(Vector3(250.0, 0, 0)), isFalse);
      final scaled = LuminaPostProcessVolume(
        halfExtent: Vector3.all(100.0),
        worldTransform: Matrix4.compose(Vector3(1000.0, 0, 0), Quaternion.identity(), Vector3.all(2.0)),
        blendRadius: 0,
      );
      expect(scaled.containsPoint(Vector3(1190.0, 0, 0)), isTrue, reason: 'half extent 100 × scale 2');
      expect(scaled.containsPoint(Vector3(1210.0, 0, 0)), isFalse);
    });

    test('sphere: radius 300, camera at 350 with blend 100 → 0.5', () {
      final s = LuminaPostProcessVolume(sphereRadius: 300.0, blendRadius: 100.0);
      expect(s.weightFor(Vector3(0, 350.0, 0)), closeTo(0.5, 1e-9));
      expect(s.weightFor(Vector3(0, 299.0, 0)), 1.0);
    });
  });

  group('LuminaPostProcessBlender.resolve', () {
    final baseline = LuminaPostProcessSettings.standard().copyWith(
      bloom: const BloomOptions(enabled: true, strength: 0.1, highlight: 1000.0),
    );

    test('no volumes and no fog returns the baseline itself', () {
      final b = LuminaPostProcessBlender()..baseline = baseline;
      final r = b.resolve(Vector3.zero());
      expect(identical(r.settings, baseline), isTrue);
      expect(r.focusDistance, isNull);
    });

    test('one unbound bloom volume at weight 1 and at weight 0.5', () {
      final b = LuminaPostProcessBlender()..baseline = baseline;
      final v = LuminaPostProcessVolume(unbound: true, overrides: const LuminaPostProcessOverrides(bloomIntensity: 4.0));
      b.addVolume(v);
      var r = b.resolve(null);
      expect(r.settings.bloom.strength, closeTo(0.5, 1e-9), reason: '4 / 8');
      expect(r.settings.bloom.enabled, isTrue);
      v.blendWeight = 0.5;
      r = b.resolve(null);
      expect(r.settings.bloom.strength, closeTo(0.3, 1e-9), reason: 'lerp(0.1, 0.5, 0.5)');
      // Exposure from 0 to 2 at a quarter.
      b.clearVolumes();
      b.addVolume(LuminaPostProcessVolume(unbound: true, blendWeight: 0.25, overrides: const LuminaPostProcessOverrides(exposure: 2.0)));
      expect(b.resolve(null).settings.colorGrade.exposure, closeTo(0.5, 1e-9));
    });

    test('priority: the higher priority is applied last and wins; equal priority keeps registration order', () {
      final b = LuminaPostProcessBlender()..baseline = baseline;
      final low = LuminaPostProcessVolume(unbound: true, priority: 0, overrides: const LuminaPostProcessOverrides(saturation: 0.0));
      final high = LuminaPostProcessVolume(unbound: true, priority: 10, overrides: const LuminaPostProcessOverrides(saturation: 2.0));
      b
        ..addVolume(high)
        ..addVolume(low);
      expect(b.resolve(null).settings.colorGrade.saturation, closeTo(2.0, 1e-9));
      low.priority = 20;
      expect(b.resolve(null).settings.colorGrade.saturation, closeTo(0.0, 1e-9));
      low.priority = 10;
      expect(b.resolve(null).settings.colorGrade.saturation, closeTo(0.0, 1e-9), reason: 'low registered after high');
    });

    test('booleans switch at one half; DoF focus distance comes back for the camera', () {
      final b = LuminaPostProcessBlender()..baseline = baseline.copyWith(taa: const TemporalAntiAliasingOptions(enabled: true));
      final v = LuminaPostProcessVolume(unbound: true, blendWeight: 0.4, overrides: const LuminaPostProcessOverrides(taaEnabled: false));
      b.addVolume(v);
      expect(b.resolve(null).settings.taa.enabled, isTrue);
      v.blendWeight = 0.6;
      expect(b.resolve(null).settings.taa.enabled, isFalse);
      b.clearVolumes();
      b.addVolume(LuminaPostProcessVolume(
        unbound: true,
        overrides: const LuminaPostProcessOverrides(depthOfFieldEnabled: true, dofFocusDistance: 500.0, dofAperture: 1.5),
      ));
      final r = b.resolve(null);
      expect(r.focusDistance, closeTo(500.0, 1e-9));
      expect(r.settings.depthOfField.enabled, isTrue);
      expect(r.settings.depthOfField.cocScale, closeTo(1.5, 1e-9));
    });

    test('fields not overridden stay the baseline\'s', () {
      final b = LuminaPostProcessBlender()..baseline = baseline;
      b.addVolume(LuminaPostProcessVolume(unbound: true, overrides: const LuminaPostProcessOverrides(vignette: 0.5)));
      final r = b.resolve(null).settings;
      expect(r.vignette.enabled, isTrue);
      expect(r.vignette.midPoint, closeTo(0.55, 1e-9));
      expect(r.bloom, baseline.bloom);
      expect(r.colorGrade, baseline.colorGrade);
      expect(r.fog, baseline.fog);
    });

    test('a disabled volume or a camera outside every volume returns the baseline', () {
      final b = LuminaPostProcessBlender()..baseline = baseline;
      final v = LuminaPostProcessVolume(halfExtent: Vector3.all(100.0), overrides: const LuminaPostProcessOverrides(bloomIntensity: 8.0));
      b.addVolume(v);
      expect(b.resolve(Vector3(0, 0, 5000.0)).settings, baseline);
      expect(b.resolve(Vector3.zero()).settings.bloom.strength, closeTo(1.0, 1e-9));
      v.enabled = false;
      expect(b.resolve(Vector3.zero()).settings, baseline);
    });

    test('fog density scale multiplies the baseline fog, and the height fog is the base it multiplies', () {
      final b = LuminaPostProcessBlender()..baseline = baseline;
      b.addVolume(LuminaPostProcessVolume(unbound: true, overrides: const LuminaPostProcessOverrides(fogDensityScale: 3.0)));
      expect(b.resolve(null).settings.fog.density, closeTo(0.003, 1e-12));
      b.setHeightFog(const LuminaHeightFogSettings(fogDensity: 0.05, height: 120.0), owner: 'test');
      final r = b.resolve(null).settings.fog;
      expect(r.density, closeTo(0.05 / LuminaUnits.unitsPerMetre * 3.0, 1e-12));
      expect(r.height, 120.0);
      expect(r.enabled, isTrue);
    });
  });

  group('LuminaPostProcessOverrides properties', () {
    test('values count only with their override flag; toProperties writes the flags', () {
      final o = LuminaPostProcessOverrides.fromProperties(const {
        'bloomIntensity': 5.0,
        'overrideBloomIntensity': true,
        'saturation': 0.2,
        'overrideSaturation': false,
        'taaEnabled': false,
        'overrideTaaEnabled': true,
      });
      expect(o.bloomIntensity, 5.0);
      expect(o.saturation, isNull);
      expect(o.taaEnabled, isFalse);
      final p = o.toProperties();
      expect(p['overrideBloomIntensity'], isTrue);
      expect(p['overrideSaturation'], isFalse);
      expect(p.containsKey('saturation'), isFalse);
      expect(LuminaPostProcessOverrides.overrideKey('dofFocusDistance'), 'overrideDofFocusDistance');
    });
  });

  group('LuminaPostProcessController baseline', () {
    test('a direct apply is the baseline, a blended apply is not; scalability copies from the baseline', () {
      final engine = FilamentEngine.create();
      if (engine == null) return; // noop backend unavailable: nothing to bind
      final scene = engine.createScene();
      final view = engine.createView()..scene = scene;
      final world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene, view: view);
      addTearDown(() {
        world.cleanup();
        view.dispose();
        scene.dispose();
        engine.dispose();
      });
      final a = LuminaPostProcessSettings.standard().copyWith(bloom: const BloomOptions(enabled: true, strength: 0.2));
      final b = a.copyWith(bloom: const BloomOptions(enabled: true, strength: 0.9));
      world.postProcess.apply(a);
      world.postProcess.apply(b, asBaseline: false);
      expect(world.postProcess.applied, b);
      expect(world.postProcess.baseline, a);
      world.applyScalability(LuminaScalabilityProfile.medium);
      expect(world.postProcess.baseline.bloom.strength, closeTo(0.2, 1e-9), reason: 'not the blended 0.9');
    });
  });
}
