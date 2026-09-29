import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('FilamentTools Native FFI API Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) engine.dispose();
    });

    test('inspectMaterialJson & inspectMaterialText with invalid buffer returns null', () {
      expect(FilamentTools.inspectMaterialJson(Uint8List(0)), isNull);
      expect(FilamentTools.inspectMaterialText(Uint8List(0)), isNull);

      final invalidBytes = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7]);
      expect(FilamentTools.inspectMaterialJson(invalidBytes), isNull);
      expect(FilamentTools.inspectMaterialText(invalidBytes), isNull);
    });

    test('encodeResourceHeader (resgen) generates C++ code string', () {
      final bytes = Uint8List.fromList([0x12, 0x34, 0x56, 0x78]);
      final code = FilamentTools.encodeResourceHeader(
        bytes: bytes,
        symbolName: 'MY_IMAGE',
      );

      expect(code, isNotNull);
      expect(code, contains('MY_IMAGE'));
      expect(code, contains('0x12'));
      expect(code, contains('0x34'));
      expect(code, contains('0x56'));
      expect(code, contains('0x78'));
      expect(code, contains('MY_IMAGE_SIZE = 4'));
    });

    test('generateMipmap (mipgen) downsamples RGBA8 4x4 image to 2x2 level 1', () {
      final srcPixels = Uint8List(4 * 4 * 4);
      srcPixels.fillRange(0, srcPixels.length, 200);

      final mipResult = FilamentTools.generateMipmap(
        srcPixels: srcPixels,
        width: 4,
        height: 4,
        targetLevel: 1,
      );

      expect(mipResult, isNotNull);
      expect(mipResult!.width, equals(2));
      expect(mipResult.height, equals(2));
      expect(mipResult.pixels.length, equals(2 * 2 * 4));
      expect(mipResult.pixels[0], equals(200));
    });

    test('minifyGlsl (glslminifier) strips comments and empty lines', () {
      const inputGlsl = '''
        // This is a test comment
        /* Block comment */
        void material(inout MaterialInputs material) {
            // Set base color
            material.baseColor = vec4(1.0);
        }
      ''';

      final minified = FilamentTools.minifyGlsl(inputGlsl);
      expect(minified, isNotNull);
      expect(minified, isNot(contains('This is a test comment')));
      expect(minified, isNot(contains('Block comment')));
      expect(minified, contains('void material'));
    });

    test('blendNormalMaps (normal-blending) blends base and detail normal maps', () {
      final base = Uint8List.fromList([128, 128, 255, 255]);
      final detail = Uint8List.fromList([128, 128, 255, 255]);

      final blended = FilamentTools.blendNormalMaps(
        basePixels: base,
        detailPixels: detail,
        width: 1,
        height: 1,
      );

      expect(blended, isNotNull);
      expect(blended!.length, equals(4));
      expect(blended[0], closeTo(128, 2));
      expect(blended[1], closeTo(128, 2));
      expect(blended[2], closeTo(255, 2));
    });

    test('computeDielectricF0 & computeConductorF0 (specular-color) calculations', () {
      final f0Glass = FilamentTools.computeDielectricF0(1.5);
      expect(f0Glass, closeTo(0.04, 0.001));

      final f0Gold = FilamentTools.computeConductorF0(
        nR: 0.18, nG: 0.42, nB: 1.37,
        kR: 3.43, kG: 2.35, kB: 1.77,
      );
      expect(f0Gold.r, greaterThan(0.8));
      expect(f0Gold.g, greaterThan(0.6));
      expect(f0Gold.b, greaterThan(0.3));
    });

    test('computeSphericalHarmonics (cmgen) computes 27 RGB coefficients from equirectangular image', () {
      final equirect = Uint8List(8 * 4 * 4); // 8x4 RGBA
      equirect.fillRange(0, equirect.length, 128);

      final sh = FilamentTools.computeSphericalHarmonics(
        equirectPixels: equirect,
        width: 8,
        height: 4,
      );

      expect(sh, isNotNull);
      expect(sh!.length, equals(27));
      expect(sh[0], greaterThan(0.0)); // Y00 Red coefficient
    });

    test('compareImages (diffimg) computes mean and max error and diff map', () {
      final imgA = Uint8List.fromList([100, 100, 100, 255]);
      final imgB = Uint8List.fromList([150, 100, 100, 255]);

      final diff = FilamentTools.compareImages(
        pixelsA: imgA,
        pixelsB: imgB,
        width: 1,
        height: 1,
      );

      expect(diff, isNotNull);
      expect(diff!.maxError, closeTo(50 / 255.0, 0.01));
      expect(diff.diffPixels[0], equals(50));
    });

    test('computeSpecularAo (cso-lut) computes SAO LUT value', () {
      final sao = FilamentTools.computeSpecularAo(
        roughness: 0.5,
        ndotv: 0.8,
        ao: 0.6,
      );
      expect(sao, greaterThan(0.0));
      expect(sao, lessThanOrEqualTo(1.0));
    });

    test('zstdCompress and zstdDecompress (uberz) roundtrip test', () {
      final sampleData = Uint8List.fromList(List.generate(100, (i) => i % 10));

      final compressed = FilamentTools.zstdCompress(sampleData);
      expect(compressed, isNotNull);

      final decompressed = FilamentTools.zstdDecompress(compressed!);
      expect(decompressed, isNotNull);
      expect(decompressed, equals(sampleData));
    });

    test('dumpFramePipelineJson (frame_pipeline_visualizer) dumps pipeline state', () {
      final view = engine.createView();
      final scene = engine.createScene();
      final entity = engine.createEntity();
      final camera = engine.createCamera(entity);

      final json = FilamentTools.dumpFramePipelineJson(
        view: view,
        scene: scene,
        camera: camera,
      );

      expect(json, isNotNull);
      expect(json, contains('view'));
      expect(json, contains('scene'));
      expect(json, contains('camera'));

      view.dispose();
      scene.dispose();
      camera.dispose();
      engine.destroyEntity(entity);
    });
  });
}
