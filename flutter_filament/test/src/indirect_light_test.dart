import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter_filament/flutter_filament.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FilamentEngine engine;
  late FilamentSwapChain swapChain;
  late FilamentRenderer renderer;
  late FilamentView view;
  late FilamentScene scene;

  setUp(() {
    engine = FilamentEngine.create()!;
    swapChain = engine.createHeadlessSwapChain(64, 64);
    renderer = engine.createRenderer();
    view = engine.createView();
    scene = engine.createScene();
    view.scene = scene;
  });

  tearDown(() {
    view.dispose();
    scene.dispose();
    renderer.dispose();
    swapChain.dispose();
    engine.dispose();
  });

  group('FilamentIndirectLight Tests', () {
    test('SphericalHarmonics validation', () {
      // 1 band requires 3 floats
      final sh1 = SphericalHarmonics(bands: 1, coefficients: [0.5, 0.5, 0.5]);
      expect(sh1.bands, equals(1));
      expect(sh1.coefficients.length, equals(3));
      expect(SphericalHarmonics.shIndex(0, 0), equals(0));

      // 2 bands require 4*3 = 12 floats
      expect(
        () => SphericalHarmonics(bands: 2, coefficients: List.filled(27, 0.1)),
        throwsArgumentError,
      );

      // bands out of range
      expect(
        () => SphericalHarmonics(bands: 0, coefficients: []),
        throwsArgumentError,
      );
      expect(
        () => SphericalHarmonics(bands: 4, coefficients: List.filled(48, 0.1)),
        throwsArgumentError,
      );
    });

    test('1-band ambient IBL builds and renders a frame', () {
      final ibl = FilamentIndirectLight.build(
        engine,
        irradiance: SphericalHarmonics(bands: 1, coefficients: [0.5, 0.5, 0.5]),
        intensity: 30000,
      );

      scene.indirectLight = ibl;
      expect(ibl.intensity, closeTo(30000, 1.0));
      expect(ibl.irradianceTexture, isNull);

      final begun = renderer.beginFrame(swapChain);
      expect(begun, isTrue);
      renderer.render(view);
      renderer.endFrame();
      engine.flushAndWait();

      ibl.dispose();
    });

    test('3-band SH IBL rotation roundtrip and default identity', () {
      // Standard 3-band SH (9 float3 = 27 floats)
      final shCoeffs = List.generate(27, (i) => (i + 1) * 0.05);
      final sh3 = SphericalHarmonics(bands: 3, coefficients: shCoeffs);

      final ibl = FilamentIndirectLight.build(
        engine,
        irradiance: sh3,
        intensity: 25000,
      );

      // Default rotation should be identity
      final defaultRot = ibl.rotation;
      expect(defaultRot.isIdentity(), isTrue);

      // Set rotation (90 deg around Y)
      final rotY = Matrix3.rotationY(math.pi / 2);
      ibl.rotation = rotY;

      final readRot = ibl.rotation;
      for (var i = 0; i < 9; i++) {
        expect(readRot.storage[i], closeTo(rotY.storage[i], 1e-4));
      }

      ibl.dispose();
    });

    test('Rotation visual smoke with 180 degree flip', () {
      final shCoeffs = List.filled(27, 0.2);
      // Boost Z-direction
      shCoeffs[6] = 1.0;
      shCoeffs[7] = 1.0;
      shCoeffs[8] = 1.0;

      final ibl = FilamentIndirectLight.build(
        engine,
        irradiance: SphericalHarmonics(bands: 3, coefficients: shCoeffs),
        intensity: 35000,
      );
      scene.indirectLight = ibl;

      // Frame 1
      renderer.beginFrame(swapChain);
      renderer.render(view);
      renderer.endFrame();

      // Rotate 180 deg
      ibl.rotation = Matrix3.rotationY(math.pi);

      // Frame 2
      renderer.beginFrame(swapChain);
      renderer.render(view);
      renderer.endFrame();
      engine.flushAndWait();

      ibl.dispose();
    });

    test('Static and member direction / color estimation from 3-band SH', () {
      // Hand-built 3-band SH
      final shCoeffs = List.filled(27, 0.0);
      shCoeffs[0] = 0.5; // L00
      shCoeffs[1] = 0.5;
      shCoeffs[2] = 0.5;
      shCoeffs[6] = 1.0; // dominant component
      shCoeffs[7] = 1.0;
      shCoeffs[8] = 1.0;

      final sh3 = SphericalHarmonics(bands: 3, coefficients: shCoeffs);

      // Static estimation
      final staticDir = FilamentIndirectLight.directionEstimateFromSh(sh3);
      expect(staticDir.length, closeTo(1.0, 1e-3));

      final (staticColor, staticIntensity) =
          FilamentIndirectLight.colorEstimateFromSh(sh3, staticDir);
      expect(staticIntensity, greaterThanOrEqualTo(0.0));
      expect(staticColor.x, greaterThanOrEqualTo(0.0));

      // Member estimation consistency
      final ibl = FilamentIndirectLight.build(
        engine,
        irradiance: sh3,
        intensity: 40000,
      );

      final memberDir = ibl.getDirectionEstimate();
      expect(memberDir.x, closeTo(staticDir.x, 1e-3));
      expect(memberDir.y, closeTo(staticDir.y, 1e-3));
      expect(memberDir.z, closeTo(staticDir.z, 1e-3));

      final (memberColor, memberIntensity) = ibl.getColorEstimate(memberDir);
      expect(memberIntensity, closeTo(staticIntensity, 1e-3));
      expect(memberColor.x, closeTo(staticColor.x, 1e-3));

      ibl.dispose();
    });

    test('directionEstimateFromSh validates 3 bands requirement', () {
      final sh1 = SphericalHarmonics(bands: 1, coefficients: [1, 1, 1]);
      expect(
        () => FilamentIndirectLight.directionEstimateFromSh(sh1),
        throwsArgumentError,
      );
    });
  });
}
