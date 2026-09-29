import 'package:flutter_test/flutter_test.dart';
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

  group('FramePacer Enums and Data Types', () {
    test('FrameStatus values and helpers match FramePacer.h exactly', () {
      expect(FrameStatus.skippedSpurious.value, equals(-2));
      expect(FrameStatus.skippedStale.value, equals(-1));
      expect(FrameStatus.accepted.value, equals(0));

      expect(FrameStatus.accepted.shouldRender, isTrue);
      expect(FrameStatus.skippedSpurious.shouldRender, isFalse);
      expect(FrameStatus.skippedStale.shouldRender, isFalse);

      expect(FrameStatus.fromValue(-2), equals(FrameStatus.skippedSpurious));
      expect(FrameStatus.fromValue(-1), equals(FrameStatus.skippedStale));
      expect(FrameStatus.fromValue(0), equals(FrameStatus.accepted));
      expect(FrameStatus.fromValue(99), equals(FrameStatus.skippedStale));
    });

    test('PacingStatus values match FramePacer.h exactly', () {
      expect(PacingStatus.displayStarving.value, equals(-1));
      expect(PacingStatus.steady.value, equals(0));
      expect(PacingStatus.displayStuffed.value, equals(1));

      expect(PacingStatus.fromValue(-1), equals(PacingStatus.displayStarving));
      expect(PacingStatus.fromValue(0), equals(PacingStatus.steady));
      expect(PacingStatus.fromValue(1), equals(PacingStatus.displayStuffed));
      expect(PacingStatus.fromValue(99), equals(PacingStatus.steady));
    });

    test('FramePacerConfiguration copyWith, equality and toString', () {
      const config = FramePacerConfiguration(
        targetFrameRate: 60.0,
        latency: Duration(milliseconds: 33),
      );
      final updated = config.copyWith(targetFrameRate: 30.0);
      expect(updated.targetFrameRate, equals(30.0));
      expect(updated.latency, equals(const Duration(milliseconds: 33)));

      final identicalCopy = config.copyWith();
      expect(identicalCopy, equals(config));
      expect(identicalCopy.hashCode, equals(config.hashCode));
      expect(config.toString(), contains('60'));
    });
  });

  group('FramePacer Creation, Configuration, and Lifecycle', () {
    test('create and getConfiguration roundtrip', () {
      final pacer = engine.createFramePacer(
        targetFrameRate: 60.0,
        latency: const Duration(milliseconds: 33),
      );
      expect(pacer.isDisposed, isFalse);

      final config = pacer.configuration;
      expect(config.targetFrameRate, closeTo(60.0, 0.01));
      expect(config.latency.inMicroseconds, closeTo(33000, 1000));

      pacer.dispose();
      expect(pacer.isDisposed, isTrue);
      expect(() => pacer.configuration, throwsStateError);
      expect(() => pacer.nativePointer, throwsStateError);
    });

    test('reconfiguration updates configuration', () {
      final pacer = engine.createFramePacer(targetFrameRate: 60.0);
      pacer.configure(
        const FramePacerConfiguration(
          targetFrameRate: 30.0,
          latency: Duration(milliseconds: 66),
        ),
      );

      final config = pacer.configuration;
      expect(config.targetFrameRate, closeTo(30.0, 0.01));
      expect(config.latency.inMicroseconds, closeTo(66000, 1000));

      engine.destroyFramePacer(pacer);
      expect(pacer.isDisposed, isTrue);
      // Double destroy should be no-op
      expect(() => pacer.dispose(), returnsNormally);
    });

    test('setupFrame returns valid FrameStatus and advances telemetry', () {
      final pacer = engine.createFramePacer(targetFrameRate: 60.0);

      final baseTime = DateTime.now().microsecondsSinceEpoch * 1000;
      final status = pacer.setupFrame(
        VsyncTick(
          baseTimeNs: baseTime,
          vsyncPeriodNs: 16666666,
        ),
      );

      expect(
        status,
        isIn([
          FrameStatus.accepted,
          FrameStatus.skippedSpurious,
          FrameStatus.skippedStale,
        ]),
      );

      expect(pacer.pacingStatus, isIn(PacingStatus.values));
      expect(pacer.selectedFrameRate, greaterThan(0));
      expect(pacer.isExactFrameRateAchieved, isA<bool>());

      pacer.dispose();
    });

    test('Drive simulated vsyncs 16.6ms apart produces monotonic presentation times', () {
      final pacer = engine.createFramePacer(targetFrameRate: 60.0);

      var simTime = 1000000000; // 1s in ns
      final period = 16666666; // ~60Hz
      var previousPresentationTime = 0;

      for (int i = 0; i < 3; i++) {
        final tick = VsyncTick(
          baseTimeNs: simTime,
          vsyncPeriodNs: period,
          frameScheduleTimeNs: simTime + 1000000,
        );
        pacer.setupFrame(tick);

        final expTime = pacer.expectedPresentationTime;
        expect(expTime, greaterThan(0));
        if (previousPresentationTime > 0) {
          expect(expTime, greaterThanOrEqualTo(previousPresentationTime));
        }
        previousPresentationTime = expTime;
        simTime += period;
      }

      pacer.dispose();
    });

    test('resetPacing, setupExtraFrame, and applyPresentationTime smoke', () {
      final pacer = engine.createFramePacer(targetFrameRate: 60.0);

      pacer.resetPacing();
      final extraResult = pacer.setupExtraFrame();
      expect(extraResult, isA<bool>());

      final fallenBehind = pacer.hasGpuFallenBehind(renderer);
      expect(fallenBehind, isFalse);

      pacer.applyPresentationTime(renderer);

      final begun = renderer.beginFrame(swapChain);
      expect(begun, isTrue);
      renderer.render(view);
      renderer.endFrame();

      engine.flushAndWait();
      pacer.dispose();
    });
  });
}
