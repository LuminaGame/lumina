import 'dart:math' as math;

import 'package:flutter_filament/src/renderer.dart';

/// Target statistical percentile for workload estimation.
enum TargetPercentile {
  /// 50th percentile (mean workload, Z = 0.0).
  p50,

  /// 90th percentile (confidence interval, Z = 1.282).
  p90,

  /// 95th percentile (high confidence interval, Z = 1.645).
  p95,
}

/// Computed ideal throughput recommendation from [FramePipelineEstimator.estimateWorkload].
class Workload {
  /// Ideal bottleneck frame duration (throughput).
  final Duration idealFrameDuration;

  /// Ideal frame rate in Hz (1.0 / idealFrameDuration).
  final double idealFrameRate;

  const Workload({
    this.idealFrameDuration = const Duration(microseconds: 16666),
    this.idealFrameRate = 60.0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Workload &&
          runtimeType == other.runtimeType &&
          idealFrameDuration == other.idealFrameDuration &&
          idealFrameRate == other.idealFrameRate;

  @override
  int get hashCode => Object.hash(idealFrameDuration, idealFrameRate);

  @override
  String toString() =>
      'Workload(duration: ${idealFrameDuration.inMicroseconds}µs, fps: $idealFrameRate)';
}

/// Structural latency and CPU safe delay sizing from [FramePipelineEstimator.estimatePacing].
class PacingSizing {
  /// Recommended structural latency (pipeline depth in frames).
  final int latencyFrames;

  /// Maximum safe delay before starting CPU work in the frame cycle.
  final Duration safeDelayDuration;

  const PacingSizing({
    this.latencyFrames = 2,
    this.safeDelayDuration = Duration.zero,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PacingSizing &&
          runtimeType == other.runtimeType &&
          latencyFrames == other.latencyFrames &&
          safeDelayDuration == other.safeDelayDuration;

  @override
  int get hashCode => Object.hash(latencyFrames, safeDelayDuration);

  @override
  String toString() =>
      'PacingSizing(latencyFrames: $latencyFrames, safeDelay: ${safeDelayDuration.inMicroseconds}µs)';
}

class _TelemetryStats {
  final int count;
  final int countGpu;
  final int countMargin;

  final double meanMain;
  final double meanBackend;
  final double meanGpu;
  final double meanMargin;

  final double stdDevMain;
  final double stdDevBackend;
  final double stdDevGpu;
  final double stdDevMargin;

  final double effectiveMain;
  final double effectiveBackend;
  final double effectiveGpu;
  final double totalTransitTimeNs;
  final double effectiveCompositionMarginNs;

  const _TelemetryStats({
    this.count = 0,
    this.countGpu = 0,
    this.countMargin = 0,
    this.meanMain = 0.0,
    this.meanBackend = 0.0,
    this.meanGpu = 0.0,
    this.meanMargin = 0.0,
    this.stdDevMain = 0.0,
    this.stdDevBackend = 0.0,
    this.stdDevGpu = 0.0,
    this.stdDevMargin = 0.0,
    this.effectiveMain = 0.0,
    this.effectiveBackend = 0.0,
    this.effectiveGpu = 0.0,
    this.totalTransitTimeNs = 0.0,
    this.effectiveCompositionMarginNs = 0.0,
  });
}

/// Pure Dart implementation of Filament's `FramePipelineEstimator`.
///
/// Calculates ideal refresh rate (throughput) and ideal structural latency (pipeline depth)
/// based on historical [FrameInfo] telemetry using probabilistic Gaussian modeling.
///
/// C++ analog: `filament/include/filament/FramePipelineEstimator.h`
abstract final class FramePipelineEstimator {
  /// Converts a [TargetPercentile] to its standard normal distribution Z-score.
  ///
  /// Reference: `FramePipelineEstimator::getZScore`
  static double getZScore(TargetPercentile targetPercentile) {
    switch (targetPercentile) {
      case TargetPercentile.p50:
        return 0.0;
      case TargetPercentile.p90:
        return 1.282;
      case TargetPercentile.p95:
        return 1.645;
    }
  }

  static int _getCpuStart(FrameInfo f) {
    return (f.frameScheduleTime != FrameInfo.invalid && f.frameScheduleTime != 0)
        ? f.frameScheduleTime
        : f.vsync;
  }

  static _TelemetryStats _computeStats(List<FrameInfo> history, double zScore) {
    if (history.isEmpty) {
      return const _TelemetryStats();
    }

    final count = history.length;
    var countGpu = 0;
    var countMargin = 0;

    var sumApp = 0.0;
    var sumRender = 0.0;
    var sumBackend = 0.0;
    var sumGpu = 0.0;
    var sumMargin = 0.0;

    for (final frameInfo in history) {
      final cpuStart = _getCpuStart(frameInfo);
      sumApp += (frameInfo.beginFrame - cpuStart).toDouble();
      sumRender += (frameInfo.endFrame - frameInfo.beginFrame).toDouble();
      sumBackend += (frameInfo.backendEndFrame - frameInfo.backendBeginFrame).toDouble();

      if (frameInfo.gpuFrameDuration > 0) {
        sumGpu += frameInfo.gpuFrameDuration.toDouble();
        countGpu++;
      }

      if (frameInfo.displayPresent > 0 &&
          frameInfo.presentDeadline > 0 &&
          frameInfo.displayPresent != FrameInfo.invalid &&
          frameInfo.presentDeadline != FrameInfo.invalid &&
          frameInfo.displayPresent > frameInfo.presentDeadline) {
        sumMargin += (frameInfo.displayPresent - frameInfo.presentDeadline).toDouble();
        countMargin++;
      }
    }

    final meanMain = (sumApp + sumRender) / count;
    final meanBackend = sumBackend / count;
    final meanGpu = countGpu > 0 ? sumGpu / countGpu : 0.0;
    final meanMargin = countMargin > 0 ? sumMargin / countMargin : 0.0;

    var varianceMain = 0.0;
    var varianceBackend = 0.0;
    var varianceGpu = 0.0;
    var varianceMargin = 0.0;

    if (count > 1) {
      var squareSumMain = 0.0;
      var squareSumBackend = 0.0;
      for (final frameInfo in history) {
        final durationMain = (frameInfo.endFrame - _getCpuStart(frameInfo)).toDouble();
        squareSumMain += (durationMain - meanMain) * (durationMain - meanMain);

        final durationBackend =
            (frameInfo.backendEndFrame - frameInfo.backendBeginFrame).toDouble();
        squareSumBackend += (durationBackend - meanBackend) * (durationBackend - meanBackend);
      }
      varianceMain = squareSumMain / (count - 1);
      varianceBackend = squareSumBackend / (count - 1);
    }

    if (countGpu > 1) {
      var squareSumGpu = 0.0;
      for (final frameInfo in history) {
        if (frameInfo.gpuFrameDuration > 0) {
          final durationGpu = frameInfo.gpuFrameDuration.toDouble();
          squareSumGpu += (durationGpu - meanGpu) * (durationGpu - meanGpu);
        }
      }
      varianceGpu = squareSumGpu / (countGpu - 1);
    }

    if (countMargin > 1) {
      var squareSumMargin = 0.0;
      for (final frameInfo in history) {
        if (frameInfo.displayPresent > 0 &&
            frameInfo.presentDeadline > 0 &&
            frameInfo.displayPresent != FrameInfo.invalid &&
            frameInfo.presentDeadline != FrameInfo.invalid &&
            frameInfo.displayPresent > frameInfo.presentDeadline) {
          final margin = (frameInfo.displayPresent - frameInfo.presentDeadline).toDouble();
          squareSumMargin += (margin - meanMargin) * (margin - meanMargin);
        }
      }
      varianceMargin = squareSumMargin / (countMargin - 1);
    }

    final stdDevMain = math.sqrt(varianceMain);
    final stdDevBackend = math.sqrt(varianceBackend);
    final stdDevGpu = math.sqrt(varianceGpu);
    final stdDevMargin = math.sqrt(varianceMargin);

    final effectiveMain = math.max(0.0, meanMain + (zScore * stdDevMain));
    final effectiveBackend = math.max(0.0, meanBackend + (zScore * stdDevBackend));
    final effectiveGpu = math.max(0.0, meanGpu + (zScore * stdDevGpu));
    final totalTransitTimeNs = effectiveMain + effectiveBackend + effectiveGpu;
    final effectiveCompositionMargin = math.max(0.0, meanMargin + (zScore * stdDevMargin));

    return _TelemetryStats(
      count: count,
      countGpu: countGpu,
      countMargin: countMargin,
      meanMain: meanMain,
      meanBackend: meanBackend,
      meanGpu: meanGpu,
      meanMargin: meanMargin,
      stdDevMain: stdDevMain,
      stdDevBackend: stdDevBackend,
      stdDevGpu: stdDevGpu,
      stdDevMargin: stdDevMargin,
      effectiveMain: effectiveMain,
      effectiveBackend: effectiveBackend,
      effectiveGpu: effectiveGpu,
      totalTransitTimeNs: totalTransitTimeNs,
      effectiveCompositionMarginNs: effectiveCompositionMargin,
    );
  }

  /// Evaluates historical frame telemetry to estimate raw unthrottled throughput limit.
  ///
  /// Reference: `FramePipelineEstimator::estimateWorkload`
  static Workload estimateWorkload(
    List<FrameInfo> history, {
    TargetPercentile targetPercentile = TargetPercentile.p90,
    double? zScore,
  }) {
    if (history.isEmpty) {
      return const Workload();
    }

    final z = zScore ?? getZScore(targetPercentile);
    final stats = _computeStats(history, z);

    var idealFrameTimeNs =
        math.max(stats.effectiveMain, math.max(stats.effectiveBackend, stats.effectiveGpu));
    if (idealFrameTimeNs <= 0.0) {
      idealFrameTimeNs = 16666666.0;
    }

    return Workload(
      idealFrameDuration: Duration(microseconds: (idealFrameTimeNs / 1000).round()),
      idealFrameRate: 1e9 / idealFrameTimeNs,
    );
  }

  /// Evaluates historical frame telemetry to size latency and safe delay for a given pacing period.
  ///
  /// Reference: `FramePipelineEstimator::estimatePacing`
  static PacingSizing estimatePacing(
    List<FrameInfo> history,
    Duration pacingPeriod, {
    TargetPercentile targetPercentile = TargetPercentile.p90,
    double? zScore,
  }) {
    final pacingIntervalNs = (pacingPeriod.inMicroseconds * 1000).toDouble();
    if (history.isEmpty || pacingIntervalNs <= 0.0) {
      return const PacingSizing();
    }

    final z = zScore ?? getZScore(targetPercentile);
    final stats = _computeStats(history, z);

    var idealLatency =
        ((stats.totalTransitTimeNs + stats.effectiveCompositionMarginNs) / pacingIntervalNs)
            .ceil();
    if (idealLatency < 1) {
      idealLatency = 1;
    }

    final budgetNs = idealLatency * pacingIntervalNs - stats.effectiveCompositionMarginNs;
    final safeDelayNs = budgetNs - stats.totalTransitTimeNs;

    return PacingSizing(
      latencyFrames: idealLatency,
      safeDelayDuration: Duration(
        microseconds: math.max(0, (safeDelayNs / 1000).round()),
      ),
    );
  }
}
