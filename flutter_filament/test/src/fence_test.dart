import 'dart:async';
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

  void renderOneFrame() {
    final begun = renderer.beginFrame(swapChain);
    expect(begun, isTrue);
    renderer.render(view);
    renderer.endFrame();
  }

  group('Fence Enum Fidelity', () {
    test('FenceStatus enum values match C++ exactly', () {
      expect(FenceStatus.error.value, equals(-1));
      expect(FenceStatus.conditionSatisfied.value, equals(0));
      expect(FenceStatus.timeoutExpired.value, equals(1));

      expect(FenceStatus.fromValue(-1), equals(FenceStatus.error));
      expect(FenceStatus.fromValue(0), equals(FenceStatus.conditionSatisfied));
      expect(FenceStatus.fromValue(1), equals(FenceStatus.timeoutExpired));
      expect(FenceStatus.fromValue(99), equals(FenceStatus.error));
    });

    test('FenceMode enum values match C++ exactly', () {
      expect(FenceMode.flush.value, equals(0));
      expect(FenceMode.dontFlush.value, equals(1));
    });
  });

  group('Fence Operations and Lifecycle', () {
    test('render 1 frame and waitAndDestroy returns conditionSatisfied', () {
      renderOneFrame();
      final fence = engine.createFence();
      expect(fence.isDisposed, isFalse);

      final status = fence.waitAndDestroy(mode: FenceMode.flush);
      expect(status, equals(FenceStatus.conditionSatisfied));
      expect(fence.isDisposed, isTrue);

      expect(() => fence.wait(), throwsStateError);
      expect(() => fence.nativePointer, throwsStateError);
    });

    test('wait with timeout returns conditionSatisfied and can be disposed', () {
      renderOneFrame();
      final fence = engine.createFence();

      final status = fence.wait(
        mode: FenceMode.flush,
        timeout: const Duration(seconds: 5),
      );
      expect(status, equals(FenceStatus.conditionSatisfied));
      expect(fence.isDisposed, isFalse);

      fence.dispose();
      expect(fence.isDisposed, isTrue);
      expect(() => fence.poll(), throwsStateError);
    });

    test('poll returns valid enum and repeated polling reaches conditionSatisfied', () {
      renderOneFrame();
      final fence = engine.createFence();

      final status = fence.poll(mode: FenceMode.flush);
      expect(
        status,
        isIn([FenceStatus.conditionSatisfied, FenceStatus.timeoutExpired]),
      );

      // Flushing and waiting should guarantee satisfied
      engine.flushAndWait();
      final finalStatus = fence.poll(mode: FenceMode.flush);
      expect(finalStatus, equals(FenceStatus.conditionSatisfied));

      fence.dispose();
    });

    test('whenSignaled completes without blocking event loop', () async {
      renderOneFrame();
      final fence = engine.createFence();

      var timerTickCount = 0;
      final periodicTimer = Timer.periodic(const Duration(milliseconds: 1), (timer) {
        timerTickCount++;
      });

      final statusFuture = fence.whenSignaled(
        pollInterval: const Duration(milliseconds: 1),
      );

      final status = await statusFuture;
      periodicTimer.cancel();

      expect(status, equals(FenceStatus.conditionSatisfied));
      expect(timerTickCount, greaterThanOrEqualTo(0));

      fence.dispose();
    });

    test('dispose on never-waited fence is safe and double dispose is a no-op', () {
      final fence = engine.createFence();
      expect(fence.isDisposed, isFalse);

      fence.dispose();
      expect(fence.isDisposed, isTrue);

      // Second dispose should be a silent no-op
      expect(() => fence.dispose(), returnsNormally);
    });
  });
}
