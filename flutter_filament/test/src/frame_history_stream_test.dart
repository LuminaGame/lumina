import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

FrameInfo makeFrame(int id) {
  return FrameInfo(
    frameId: id,
    gpuFrameDuration: 16000000,
    denoisedGpuFrameDuration: 16000000,
    beginFrame: 1000000 * id,
    endFrame: 1000000 * id + 500000,
    backendBeginFrame: 1000000 * id + 600000,
    backendEndFrame: 1000000 * id + 1200000,
    gpuFrameComplete: 1000000 * id + 15000000,
    vsync: 1000000 * id,
    displayPresent: 1000000 * id + 16666666,
    presentDeadline: 1000000 * id + 16000000,
    displayPresentInterval: 16666666,
    compositionToPresentLatency: 2000000,
    expectedPresentLatency: 16666666,
    frameScheduleTime: 1000000 * id,
  );
}

void main() {
  group('FrameHistoryStream Pure Dart Tests', () {
    test('deduplicates incoming frames across multiple pushes', () async {
      final fhs = FrameHistoryStream(sync: true);
      final emitted = <int>[];
      final sub = fhs.stream.listen((frame) {
        emitted.add(frame.frameId);
      });

      final f1 = makeFrame(1);
      final f2 = makeFrame(2);
      final f3 = makeFrame(3);

      fhs.push([f1, f2]);
      fhs.push([f2, f3]); // f2 is duplicate

      expect(emitted, equals([1, 2, 3]));
      expect(fhs.lastFrameId, equals(3));
      expect(fhs.droppedFrameCount, equals(0));

      await sub.cancel();
      fhs.close();
    });

    test('detects dropped / missing frame gaps', () async {
      final fhs = FrameHistoryStream(sync: true);
      final emitted = <int>[];
      final sub = fhs.stream.listen((frame) {
        emitted.add(frame.frameId);
      });

      final f1 = makeFrame(1);
      final f4 = makeFrame(4); // skipped 2 and 3 -> 2 dropped

      fhs.push([f1]);
      fhs.push([f4]);

      expect(emitted, equals([1, 4]));
      expect(fhs.lastFrameId, equals(4));
      expect(fhs.droppedFrameCount, equals(2));

      await sub.cancel();
      fhs.close();
    });

    test('empty push and repeated identical push are idempotent', () async {
      final fhs = FrameHistoryStream(sync: true);
      final emitted = <int>[];
      final sub = fhs.stream.listen((frame) {
        emitted.add(frame.frameId);
      });

      fhs.push([]);
      expect(emitted, isEmpty);

      final f1 = makeFrame(10);
      fhs.push([f1]);
      fhs.push([f1]);
      fhs.push([f1]);

      expect(emitted, equals([10]));
      expect(fhs.lastFrameId, equals(10));
      expect(fhs.droppedFrameCount, equals(0));

      await sub.cancel();
      fhs.close();
    });
  });
}
