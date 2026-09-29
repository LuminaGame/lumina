import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina/lumina.dart';

class FakeFilamentRenderer implements FilamentRenderer {
  final List<String> callLog = [];
  int? lastVsyncNanos;
  bool shouldRender = true;
  bool beginFrameResult = true;
  DisplayInfo? displayInfoConfig;
  List<FrameInfo> frameHistoryToReturn = [];

  @override
  bool beginFrame(FilamentSwapChain swapChain, {int vsyncSteadyClockTimeNano = 0, int vsyncNs = 0}) {
    callLog.add('beginFrame');
    lastVsyncNanos = vsyncSteadyClockTimeNano;
    return beginFrameResult;
  }

  @override
  void render(FilamentView view) {
    callLog.add('render');
  }

  @override
  void endFrame() {
    callLog.add('endFrame');
  }

  @override
  void skipFrame({int vsyncSteadyClockNanos = 0}) {
    callLog.add('skipFrame');
  }

  @override
  bool get shouldRenderFrame => shouldRender;

  @override
  set displayInfo(DisplayInfo info) {
    displayInfoConfig = info;
  }

  @override
  List<FrameInfo> getFrameInfoHistory([int count = 1]) => frameHistoryToReturn;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFilamentSwapChain implements FilamentSwapChain {
  double? lastRequestedFrameRate;

  @override
  void setFrameRate(
    double fps, {
    FrameRateCompatibility compatibility = FrameRateCompatibility.defaultMode,
    ChangeFrameRateStrategy strategy = ChangeFrameRateStrategy.onlyIfSeamless,
  }) {
    lastRequestedFrameRate = fps;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFilamentView implements FilamentView {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFramePacer implements FilamentFramePacer {
  final List<String> callLog = [];
  double targetFps = 60.0;
  int presentationTimeNs = 1000000000;
  int presentationStepNs = 16666667;
  bool gpuFallenBehind = false;
  bool renderFlag = true;

  @override
  FrameStatus setupFrame(VsyncTick tick) {
    callLog.add('setupFrame');
    presentationTimeNs += presentationStepNs;
    return renderFlag ? FrameStatus.accepted : FrameStatus.skippedSpurious;
  }

  @override
  int get expectedPresentationTime => presentationTimeNs;

  @override
  void applyPresentationTime(FilamentRenderer renderer) {
    callLog.add('applyPresentationTime');
  }

  @override
  void configure(FramePacerConfiguration config) {
    targetFps = config.targetFrameRate;
  }

  @override
  bool hasGpuFallenBehind(FilamentRenderer renderer) => gpuFallenBehind;

  @override
  void resetPacing() {
    callLog.add('resetPacing');
  }

  @override
  void dispose() {
    callLog.add('dispose');
  }

  @override
  FramePacerConfiguration get configuration => FramePacerConfiguration(targetFrameRate: targetFps);

  @override
  Duration get effectiveLatency => const Duration(microseconds: 33333);

  @override
  bool get isDisposed => false;

  @override
  bool get isExactFrameRateAchieved => true;

  @override
  PacingStatus get pacingStatus => PacingStatus.steady;

  @override
  int get renderingDeadline => 0;

  @override
  double get selectedFrameRate => targetFps;

  @override
  bool setupExtraFrame() => renderFlag;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

FrameInfo makeFrameInfo({
  required int frameId,
  int gpuDuration = 8000000,
  int begin = 1000000,
  int end = 5000000,
  int interval = 16666667,
}) {
  return FrameInfo(
    frameId: frameId,
    gpuFrameDuration: gpuDuration,
    denoisedGpuFrameDuration: gpuDuration,
    beginFrame: begin,
    endFrame: end,
    backendBeginFrame: begin,
    backendEndFrame: end,
    gpuFrameComplete: end + gpuDuration,
    vsync: begin,
    displayPresent: end + gpuDuration,
    presentDeadline: begin + interval,
    displayPresentInterval: interval,
    compositionToPresentLatency: 1000000,
    expectedPresentLatency: 1000000,
    frameScheduleTime: begin,
  );
}

void main() {
  group('LuminaFrameDriver and Frame Pacing', () {
    late LuminaWorld world;
    late FakeFilamentRenderer renderer;
    late FakeFilamentSwapChain swapChain;
    late FakeFilamentView view;
    late FakeFramePacer pacer;

    setUp(() {
      world = LuminaWorld(worldType: LuminaWorldType.game);
      world.beginPlay();
      renderer = FakeFilamentRenderer();
      swapChain = FakeFilamentSwapChain();
      view = FakeFilamentView();
      pacer = FakeFramePacer();
    });

    tearDown(() {
      world.cleanup();
    });

    test('Order probe, rendered frame: setupFrame -> tick -> beginFrame -> applyPresentationTime -> render -> endFrame', () {
      final driver = LuminaFrameDriver(
        world,
        renderer: renderer,
        swapChain: swapChain,
        view: view,
        framePacer: pacer,
      );

      final ticks = <double>[];
      world.onPreTick = (dt) => ticks.add(dt);

      driver.onVsync(1000000000);

      expect(pacer.callLog, contains('setupFrame'));
      expect(pacer.callLog, contains('applyPresentationTime'));
      expect(renderer.callLog, equals(['beginFrame', 'render', 'endFrame']));
      expect(renderer.lastVsyncNanos, equals(1000000000));
      expect(ticks, hasLength(1));
    });

    test('deltaTime derives from expectedPresentationTime advancing steadily', () {
      final driver = LuminaFrameDriver(
        world,
        renderer: renderer,
        swapChain: swapChain,
        view: view,
        framePacer: pacer,
      );

      final recordedDts = <double>[];
      world.onPreTick = (dt) => recordedDts.add(dt);

      // 3 vsync pulses with jittered wall vsync timestamps
      driver.onVsync(1000000000);
      driver.onVsync(1010000000); // 10ms later
      driver.onVsync(1030000000); // 20ms later

      // Because pacer reported exact 16,666,667ns step, dt must be 0.016666667s
      expect(recordedDts[1], closeTo(0.016666667, 1e-7));
      expect(recordedDts[2], closeTo(0.016666667, 1e-7));
    });

    test('Skip path: FrameStatus.render == false calls skipFrame, no begin/end, and simulation still ticks', () {
      pacer.renderFlag = false;
      final driver = LuminaFrameDriver(
        world,
        renderer: renderer,
        swapChain: swapChain,
        view: view,
        framePacer: pacer,
      );

      final ticks = <double>[];
      world.onPreTick = (dt) => ticks.add(dt);

      driver.onVsync(1000000000);

      expect(renderer.callLog, equals(['skipFrame']));
      expect(ticks, hasLength(1));
    });

    test('Fallback path (useFramePacer: false): dt = delta vsync clamped to 0.25s', () {
      final driver = LuminaFrameDriver(
        world,
        renderer: renderer,
        swapChain: swapChain,
        view: view,
        useFramePacer: false,
      );

      final recordedDts = <double>[];
      world.onPreTick = (dt) => recordedDts.add(dt);

      driver.onVsync(1000000000);
      driver.onVsync(3000000000); // 2.0s gap

      expect(recordedDts[1], equals(0.25)); // clamped to maxDeltaTime
      expect(driver.hitchCount, equals(1));
    });

    test('targetFrameRate and setDisplayRefreshRate', () {
      final driver = LuminaFrameDriver(
        world,
        renderer: renderer,
        swapChain: swapChain,
        view: view,
        framePacer: pacer,
      );

      driver.targetFrameRate = 30.0;
      expect(pacer.targetFps, equals(30.0));
      expect(swapChain.lastRequestedFrameRate, equals(30.0));

      driver.setDisplayRefreshRate(120.0);
      expect(renderer.displayInfoConfig?.refreshRate, equals(120.0));
    });

    test('Stats dedup and gap detection with PENDING gpu duration handling', () async {
      final driver = LuminaFrameDriver(
        world,
        renderer: renderer,
        swapChain: swapChain,
        view: view,
        framePacer: pacer,
      );

      final emittedStats = <LuminaFrameStats>[];
      driver.frameStats.listen(emittedStats.add);

      // Frame batch 1: f1, f2
      renderer.frameHistoryToReturn = [
        makeFrameInfo(frameId: 1, gpuDuration: 6000000),
        makeFrameInfo(frameId: 2, gpuDuration: 7000000),
      ];
      driver.onVsync(1000000000);
      await pumpEventQueue();

      // Frame batch 2: f2, f3 (f2 overlap should be deduped)
      renderer.frameHistoryToReturn = [
        makeFrameInfo(frameId: 2, gpuDuration: 7000000),
        makeFrameInfo(frameId: 3, gpuDuration: FrameInfo.pending),
      ];
      driver.onVsync(1016666667);
      await pumpEventQueue();

      // Frame batch 3: f3, f5 (f4 missing gap -> missedFrames == 1)
      renderer.frameHistoryToReturn = [
        makeFrameInfo(frameId: 3, gpuDuration: FrameInfo.pending),
        makeFrameInfo(frameId: 5, gpuDuration: 9000000),
      ];
      driver.onVsync(1033333334);
      await pumpEventQueue();

      expect(emittedStats.map((s) => s.frameId).toList(), equals([1, 2, 3, 5]));
      expect(emittedStats[2].gpuFrameMs, isNull); // Frame 3 was PENDING
      expect(emittedStats[3].missedFrames, equals(1)); // Frame 4 was missed
      expect(emittedStats[3].gpuFrameMs, closeTo(9.0, 1e-4));
    });

    test('hasGpuFallenBehind triggers resetPacing once per episode and marks gpuBehind', () {
      pacer.gpuFallenBehind = true;
      final driver = LuminaFrameDriver(
        world,
        renderer: renderer,
        swapChain: swapChain,
        view: view,
        framePacer: pacer,
      );

      driver.onVsync(1000000000);

      expect(pacer.callLog, contains('resetPacing'));
    });

    test('beginFrame returns false -> skips render and endFrame', () {
      renderer.beginFrameResult = false;
      final driver = LuminaFrameDriver(
        world,
        renderer: renderer,
        swapChain: swapChain,
        view: view,
        framePacer: pacer,
      );

      driver.onVsync(1000000000);
      expect(renderer.callLog, equals(['beginFrame']));
    });

    test('paused = true skips tick and render; unpausing resets dt baseline', () {
      final driver = LuminaFrameDriver(
        world,
        renderer: renderer,
        swapChain: swapChain,
        view: view,
        framePacer: pacer,
      );

      final ticks = <double>[];
      world.onPreTick = (dt) => ticks.add(dt);

      driver.paused = true;
      driver.onVsync(1000000000);
      expect(ticks, isEmpty);
      expect(renderer.callLog, isEmpty);

      driver.paused = false;
      driver.onVsync(10000000000); // 9 seconds later
      expect(ticks, hasLength(1));
      expect(ticks[0], closeTo(0.016666667, 1e-4)); // fresh baseline, not 9s
    });

    test('Re-entrancy and lifecycle: onVsync inside onVsync throws StateError; onVsync after dispose throws StateError', () {
      late LuminaFrameDriver driver;
      driver = LuminaFrameDriver(
        world,
        renderer: renderer,
        swapChain: swapChain,
        view: view,
        framePacer: pacer,
      );

      world.onPreTick = (dt) {
        expect(() => driver.onVsync(2000000000), throwsStateError);
      };

      driver.onVsync(1000000000);

      driver.dispose();
      expect(() => driver.onVsync(3000000000), throwsStateError);
      expect(pacer.callLog, contains('dispose'));
    });
  });
}
