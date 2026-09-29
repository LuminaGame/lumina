import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter_filament/flutter_filament.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ToneMapper Tests', () {
    test('Enum values fidelity', () {
      expect(ToneMapperType.linear.value, equals(0));
      expect(ToneMapperType.aces.value, equals(1));
      expect(ToneMapperType.acesLegacy.value, equals(2));
      expect(ToneMapperType.filmic.value, equals(3));
      expect(ToneMapperType.pbrNeutral.value, equals(4));
      expect(ToneMapperType.gt7.value, equals(5));
      expect(ToneMapperType.agx.value, equals(6));
      expect(ToneMapperType.generic.value, equals(7));
      expect(ToneMapperType.displayRange.value, equals(8));

      expect(AgxLook.none.value, equals(0));
      expect(AgxLook.punchy.value, equals(1));
      expect(AgxLook.golden.value, equals(2));
    });

    test('Parameterless tone mappers creation and destruction', () {
      final types = [
        ToneMapperType.linear,
        ToneMapperType.aces,
        ToneMapperType.acesLegacy,
        ToneMapperType.filmic,
        ToneMapperType.pbrNeutral,
        ToneMapperType.gt7,
        ToneMapperType.displayRange,
      ];

      for (final type in types) {
        final tm = ToneMapper(type);
        expect(tm.nativePointer.address, isNonZero);
        expect(tm.isDisposed, isFalse);
        tm.destroy();
        expect(tm.isDisposed, isTrue);
      }
    });

    test('AgX tone mapper variants', () {
      final tmNone = ToneMapper.agx(look: AgxLook.none);
      expect(tmNone.nativePointer.address, isNonZero);
      tmNone.destroy();

      final tmPunchy = ToneMapper.agx(look: AgxLook.punchy);
      expect(tmPunchy.nativePointer.address, isNonZero);
      tmPunchy.destroy();

      final tmGolden = ToneMapper.agx(look: AgxLook.golden);
      expect(tmGolden.nativePointer.address, isNonZero);
      tmGolden.destroy();
    });

    test('Generic tone mapper with custom parameters', () {
      final tm = ToneMapper.generic(
        contrast: 1.2,
        midGrayIn: 0.18,
        midGrayOut: 0.2,
        hdrMax: 8.0,
      );
      expect(tm.nativePointer.address, isNonZero);
      tm.destroy();
    });

    test('Double-destroy safety is a no-op', () {
      final tm = ToneMapper(ToneMapperType.filmic);
      tm.destroy();
      expect(() => tm.destroy(), returnsNormally);
    });
  });

  group('ColorGrading Builder Tests', () {
    late FilamentEngine engine;

    setUpAll(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDownAll(() {
      engine.dispose();
    });

    test('Enum fidelity: ColorGradingQuality and LutFormat', () {
      expect(ColorGradingQuality.low.value, equals(0));
      expect(ColorGradingQuality.medium.value, equals(1));
      expect(ColorGradingQuality.high.value, equals(2));
      expect(ColorGradingQuality.ultra.value, equals(3));

      expect(LutFormat.integer.value, equals(0));
      expect(LutFormat.float.value, equals(1));

      // Assert ColorGradingQuality is distinct from QualityLevel
      expect(ColorGradingQuality.low.runtimeType != QualityLevel.low.runtimeType, isTrue);
    });

    test('Minimal ColorGrading build with ToneMapper', () {
      final tm = ToneMapper(ToneMapperType.filmic);
      final cg = ColorGradingBuilder()
          .toneMapper(tm)
          .build(engine);

      expect(cg.nativePointer.address, isNonZero);
      expect(cg.isDisposed, isFalse);

      // Tone mapper can be safely destroyed after build
      tm.destroy();

      cg.destroy();
      expect(cg.isDisposed, isTrue);
    });

    test('Full ColorGrading build with all parameters', () {
      final tm = ToneMapper.agx(look: AgxLook.punchy);
      final cg = ColorGradingBuilder()
          .quality(ColorGradingQuality.high)
          .format(LutFormat.float)
          .dimensions(32)
          .toneMapper(tm)
          .exposure(0.5)
          .nightAdaptation(0.1)
          .whiteBalance(0.2, -0.1)
          .channelMixer(
            outRed: Vector3(1.0, 0.0, 0.0),
            outGreen: Vector3(0.0, 1.0, 0.0),
            outBlue: Vector3(0.0, 0.0, 1.0),
          )
          .shadowsMidtonesHighlights(
            shadows: Vector4(1.0, 1.0, 1.0, 0.0),
            midtones: Vector4(1.0, 1.0, 1.0, 0.0),
            highlights: Vector4(1.0, 1.0, 1.0, 0.0),
            ranges: Vector4(0.0, 0.333, 0.550, 1.0),
          )
          .slopeOffsetPower(
            slope: Vector3(1.0, 1.0, 1.0),
            offset: Vector3(0.0, 0.0, 0.0),
            power: Vector3(1.0, 1.0, 1.0),
          )
          .contrast(1.2)
          .vibrance(1.1)
          .saturation(0.9)
          .curves(
            shadowGamma: Vector3(1.0, 1.0, 1.0),
            midPoint: Vector3(1.0, 1.0, 1.0),
            highlightScale: Vector3(1.0, 1.0, 1.0),
          )
          .luminanceScaling(true)
          .gamutMapping(true)
          .build(engine);

      expect(cg.nativePointer.address, isNonZero);
      tm.destroy();
      cg.destroy();
    });

    test('dimensions range validation (16..64)', () {
      final builder = ColorGradingBuilder();
      expect(() => builder.dimensions(15), throwsRangeError);
      expect(() => builder.dimensions(65), throwsRangeError);
      expect(() => builder.dimensions(16), returnsNormally);
      expect(() => builder.dimensions(64), returnsNormally);
    });

    test('ToneMapper already destroyed throws StateError on builder use', () {
      final tm = ToneMapper(ToneMapperType.aces);
      tm.destroy();

      expect(() => ColorGradingBuilder().toneMapper(tm), throwsStateError);
    });

    test('View.colorGrading integration and cleanup order', () {
      final view = engine.createView();
      final renderer = engine.createRenderer();
      final swapChain = engine.createHeadlessSwapChain(100, 100);
      final camera = engine.createCamera(engine.createEntity());
      final scene = engine.createScene();

      view.camera = camera;
      view.scene = scene;
      view.setViewport(0, 0, 100, 100);

      final cg = ColorGradingBuilder()
          .toneMapper(ToneMapper(ToneMapperType.gt7))
          .build(engine);

      view.setColorGradingModel(cg);

      // Render one headless frame
      if (renderer.beginFrame(swapChain)) {
        renderer.render(view);
        renderer.endFrame();
      }

      // Reset to default
      view.setColorGradingModel(null);

      // Render again with default
      if (renderer.beginFrame(swapChain)) {
        renderer.render(view);
        renderer.endFrame();
      }

      // Safe destroy after setting null
      cg.destroy();
      engine.destroyView(view);
    });
  });
}
