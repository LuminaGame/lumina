import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';

void main() {
  group('FramePipelineEstimator Unit Tests (Pure Dart)', () {
    test('getZScore matches Filament constants exactly', () {
      expect(FramePipelineEstimator.getZScore(TargetPercentile.p50), equals(0.0));
      expect(FramePipelineEstimator.getZScore(TargetPercentile.p90), equals(1.282));
      expect(FramePipelineEstimator.getZScore(TargetPercentile.p95), equals(1.645));
    });

    test('Empty history returns fallback defaults', () {
      final workload = FramePipelineEstimator.estimateWorkload(const []);
      expect(workload.idealFrameRate, equals(60.0));
      expect(workload.idealFrameDuration.inMicroseconds, equals(16666));

      final sizing = FramePipelineEstimator.estimatePacing(
        const [],
        const Duration(microseconds: 16666),
      );
      expect(sizing.latencyFrames, equals(2));
      expect(sizing.safeDelayDuration, equals(Duration.zero));
    });

    test('Synthetic history with constant frame duration (8ms)', () {
      // 10 frames with exactly 8ms GPU duration, 2ms app, 2ms backend
      final history = List.generate(
        10,
        (i) => FrameInfo(
          frameId: i,
          gpuFrameDuration: 8000000, // 8ms
          denoisedGpuFrameDuration: 8000000,
          beginFrame: 1000000, // 1ms
          endFrame: 3000000, // 3ms -> CPU = 3ms
          backendBeginFrame: 3000000,
          backendEndFrame: 5000000, // 5ms -> BE = 2ms
          gpuFrameComplete: 13000000,
          vsync: 0,
          displayPresent: 0,
          presentDeadline: 0,
          displayPresentInterval: 0,
          compositionToPresentLatency: 0,
          expectedPresentLatency: 0,
          frameScheduleTime: 0,
        ),
      );

      // Sigma is 0, bottleneck is GPU (8ms)
      final workload = FramePipelineEstimator.estimateWorkload(
        history,
        targetPercentile: TargetPercentile.p90,
      );
      expect(workload.idealFrameDuration.inMicroseconds, closeTo(8000, 10));
      expect(workload.idealFrameRate, closeTo(125.0, 0.5));
    });

    test('Synthetic history with known variance', () {
      // 5 frames with GPU durations: 6ms, 8ms, 10ms, 8ms, 8ms
      // mean = 8.0ms = 8,000,000ns
      // differences from mean: -2, 0, +2, 0, 0 ms
      // sum of squares = 4 + 0 + 4 + 0 + 0 = 8 ms^2 = 8,000,000,000,000 ns^2
      // sample variance = 8 / (5 - 1) = 2 ms^2
      // stdDev = sqrt(2) ms ≈ 1.41421356 ms = 1,414,213 ns
      // With Z=1.282 (P90): effectiveGpu = 8.0 + 1.282 * sqrt(2) ≈ 8.0 + 1.81302 = 9.81302 ms ≈ 9813 µs
      final gpuDurations = [6000000, 8000000, 10000000, 8000000, 8000000];
      final history = List.generate(
        5,
        (i) => FrameInfo(
          frameId: i,
          gpuFrameDuration: gpuDurations[i],
          denoisedGpuFrameDuration: gpuDurations[i],
          beginFrame: 1000000,
          endFrame: 2000000, // 2ms CPU
          backendBeginFrame: 2000000,
          backendEndFrame: 3000000, // 1ms BE
          gpuFrameComplete: 10000000,
          vsync: 0,
          displayPresent: 0,
          presentDeadline: 0,
          displayPresentInterval: 0,
          compositionToPresentLatency: 0,
          expectedPresentLatency: 0,
          frameScheduleTime: 0,
        ),
      );

      final workload = FramePipelineEstimator.estimateWorkload(
        history,
        targetPercentile: TargetPercentile.p90,
      );
      expect(workload.idealFrameDuration.inMicroseconds, closeTo(9813, 20));
    });

    test('Records with pending GPU durations are skipped from GPU stats', () {
      final validFrames = List.generate(
        5,
        (i) => FrameInfo(
          frameId: i,
          gpuFrameDuration: 5000000, // 5ms
          denoisedGpuFrameDuration: 5000000,
          beginFrame: 1000000,
          endFrame: 2000000,
          backendBeginFrame: 2000000,
          backendEndFrame: 3000000,
          gpuFrameComplete: 8000000,
          vsync: 0,
          displayPresent: 0,
          presentDeadline: 0,
          displayPresentInterval: 0,
          compositionToPresentLatency: 0,
          expectedPresentLatency: 0,
          frameScheduleTime: 0,
        ),
      );

      final pendingFrame = FrameInfo(
        frameId: 99,
        gpuFrameDuration: FrameInfo.pending,
        denoisedGpuFrameDuration: FrameInfo.pending,
        beginFrame: 1000000,
        endFrame: 2000000,
        backendBeginFrame: 2000000,
        backendEndFrame: 3000000,
        gpuFrameComplete: FrameInfo.pending,
        vsync: 0,
        displayPresent: 0,
        presentDeadline: 0,
        displayPresentInterval: 0,
        compositionToPresentLatency: 0,
        expectedPresentLatency: 0,
        frameScheduleTime: 0,
      );

      final mixedHistory = [...validFrames, pendingFrame];

      final workloadWithout = FramePipelineEstimator.estimateWorkload(
        validFrames,
        targetPercentile: TargetPercentile.p50,
      );
      final workloadWith = FramePipelineEstimator.estimateWorkload(
        mixedHistory,
        targetPercentile: TargetPercentile.p50,
      );

      expect(workloadWith.idealFrameDuration.inMicroseconds,
          closeTo(workloadWithout.idealFrameDuration.inMicroseconds, 5));
    });

    test('estimatePacing sizes latency frames and safe delay correctly', () {
      // 10 frames with 4ms CPU, 2ms BE, 8ms GPU -> Total transit = 14ms
      final history = List.generate(
        10,
        (i) => FrameInfo(
          frameId: i,
          gpuFrameDuration: 8000000,
          denoisedGpuFrameDuration: 8000000,
          beginFrame: 1000000,
          endFrame: 4000000,
          backendBeginFrame: 4000000,
          backendEndFrame: 6000000,
          gpuFrameComplete: 14000000,
          vsync: 0,
          displayPresent: 0,
          presentDeadline: 0,
          displayPresentInterval: 0,
          compositionToPresentLatency: 0,
          expectedPresentLatency: 0,
          frameScheduleTime: 0,
        ),
      );

      // 60Hz pacing period = 16.666ms
      // Total transit = 14ms <= 16.666ms -> idealLatency = ceil(14 / 16.666) = 1 frame
      // Budget = 1 * 16.666ms = 16.666ms -> Safe delay = 16.666 - 14.0 = 2.666ms
      final sizing = FramePipelineEstimator.estimatePacing(
        history,
        const Duration(microseconds: 16666),
        targetPercentile: TargetPercentile.p50,
      );

      expect(sizing.latencyFrames, equals(1));
      expect(sizing.safeDelayDuration.inMicroseconds, closeTo(2666, 100));
    });

    test('Linear scaling property holds', () {
      List<FrameInfo> makeHistory(int multiplier) {
        return List.generate(
          10,
          (i) => FrameInfo(
            frameId: i,
            gpuFrameDuration: 4000000 * multiplier,
            denoisedGpuFrameDuration: 4000000 * multiplier,
            beginFrame: 0,
            endFrame: 2000000 * multiplier,
            backendBeginFrame: 2000000 * multiplier,
            backendEndFrame: 3000000 * multiplier,
            gpuFrameComplete: 7000000 * multiplier,
            vsync: 0,
            displayPresent: 0,
            presentDeadline: 0,
            displayPresentInterval: 0,
            compositionToPresentLatency: 0,
            expectedPresentLatency: 0,
            frameScheduleTime: 0,
          ),
        );
      }

      final w1 = FramePipelineEstimator.estimateWorkload(
        makeHistory(1),
        targetPercentile: TargetPercentile.p50,
      );
      final w2 = FramePipelineEstimator.estimateWorkload(
        makeHistory(2),
        targetPercentile: TargetPercentile.p50,
      );

      expect(
        w2.idealFrameDuration.inMicroseconds,
        closeTo(w1.idealFrameDuration.inMicroseconds * 2, 10),
      );
    });
  });
}
