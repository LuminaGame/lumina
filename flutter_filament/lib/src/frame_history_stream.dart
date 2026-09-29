/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

import 'dart:async';

import 'package:flutter_filament/src/renderer.dart';

/// Pure-Dart implementation of Filament's FrameHistoryStream.
///
/// Receives batches of [FrameInfo] records, deduplicates them by [FrameInfo.frameId],
/// detects dropped or missing frame gaps, and emits unique completed frames in sequence.
class FrameHistoryStream {
  final StreamController<FrameInfo> _controller;
  int _lastFrameId = 0;
  int _droppedFrameCount = 0;

  FrameHistoryStream({bool sync = false})
      : _controller = StreamController<FrameInfo>.broadcast(sync: sync);

  /// Stream of individual, deduplicated [FrameInfo] instances in increasing order of frameId.
  Stream<FrameInfo> get stream => _controller.stream;

  /// The highest frameId processed and emitted so far (0 if none).
  int get lastFrameId => _lastFrameId;

  /// Cumulative count of dropped/skipped frames detected via frameId discontinuities.
  int get droppedFrameCount => _droppedFrameCount;

  /// Pushes a batch of [FrameInfo] records from [FilamentRenderer.getFrameInfoHistory].
  void push(List<FrameInfo> history) {
    if (history.isEmpty) return;

    // Ensure processing in ascending chronological order of frameId
    final sorted = List<FrameInfo>.from(history)
      ..sort((a, b) => a.frameId.compareTo(b.frameId));

    for (final info in sorted) {
      if (_lastFrameId != 0 && info.frameId <= _lastFrameId) {
        // Already processed / duplicate; ignore
        continue;
      }

      if (_lastFrameId != 0 && info.frameId > _lastFrameId + 1) {
        // Gap detected: one or more frames were dropped or skipped
        _droppedFrameCount += (info.frameId - _lastFrameId - 1);
      }

      _lastFrameId = info.frameId;
      _controller.add(info);
    }
  }

  /// Closes the underlying stream controller.
  void close() {
    _controller.close();
  }
}
