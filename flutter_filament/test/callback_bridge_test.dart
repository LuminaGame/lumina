import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('Unified Callback Bridge & Engine pumpMessageQueues', () {
    setUpAll(() {
      CallbackBridge.instance.init();
    });

    tearDownAll(() {
      CallbackBridge.instance.shutdown();
    });

    test('Single request: register and fire synchronously', () async {
      final (requestId, future) = CallbackBridge.instance.register(kind: 1);

      final payloadBytes = Uint8List.fromList([10, 20, 30, 40, 50]);
      final payloadPtr = calloc<Uint8>(payloadBytes.length);
      payloadPtr.asTypedList(payloadBytes.length).setAll(0, payloadBytes);

      try {
        CallbackBridge.testFire(
          requestId: requestId,
          kind: 1,
          status: 0,
          payload: payloadPtr.cast<Void>(),
          size: payloadBytes.length,
        );

        final result = await future;
        expect(result.kind, equals(1));
        expect(result.status, equals(0));
        expect(result.payload, equals(payloadBytes));
        expect(CallbackBridge.instance.pendingCount, equals(0));
      } finally {
        calloc.free(payloadPtr);
      }
    });

    test('Two concurrent requests fired in reverse order route to matching Completers', () async {
      final (idA, futureA) = CallbackBridge.instance.register(kind: 1);
      final (idB, futureB) = CallbackBridge.instance.register(kind: 2);

      expect(CallbackBridge.instance.pendingCount, equals(2));

      final payloadA = Uint8List.fromList([1, 2, 3]);
      final ptrA = calloc<Uint8>(payloadA.length);
      ptrA.asTypedList(payloadA.length).setAll(0, payloadA);

      final payloadB = Uint8List.fromList([4, 5, 6, 7]);
      final ptrB = calloc<Uint8>(payloadB.length);
      ptrB.asTypedList(payloadB.length).setAll(0, payloadB);

      try {
        // Fire B first, then A
        CallbackBridge.testFire(
          requestId: idB,
          kind: 2,
          status: 200,
          payload: ptrB.cast<Void>(),
          size: payloadB.length,
        );

        CallbackBridge.testFire(
          requestId: idA,
          kind: 1,
          status: 100,
          payload: ptrA.cast<Void>(),
          size: payloadA.length,
        );

        final resB = await futureB;
        final resA = await futureA;

        expect(resB.kind, equals(2));
        expect(resB.status, equals(200));
        expect(resB.payload, equals(payloadB));

        expect(resA.kind, equals(1));
        expect(resA.status, equals(100));
        expect(resA.payload, equals(payloadA));

        expect(CallbackBridge.instance.pendingCount, equals(0));
      } finally {
        calloc.free(ptrA);
        calloc.free(ptrB);
      }
    });

    test('Fire async from a separate native thread delivers safely to main isolate', () async {
      final (requestId, future) = CallbackBridge.instance.register(kind: 42);

      final payloadData = Uint8List.fromList([99, 88, 77, 66]);
      final ptr = calloc<Uint8>(payloadData.length);
      ptr.asTypedList(payloadData.length).setAll(0, payloadData);

      try {
        CallbackBridge.testFireAsync(
          requestId: requestId,
          kind: 42,
          status: 0,
          payload: ptr.cast<Void>(),
          size: payloadData.length,
        );

        final result = await future;
        expect(result.kind, equals(42));
        expect(result.status, equals(0));
        expect(result.payload, equals(payloadData));
        expect(CallbackBridge.instance.pendingCount, equals(0));
      } finally {
        calloc.free(ptr);
      }
    });

    test('Loop of 1000 register and fire cycles does not leak', () async {
      final futures = <Future<CallbackResult>>[];
      final ptr = calloc<Uint8>(8);
      ptr.asTypedList(8).setAll(0, [1, 2, 3, 4, 5, 6, 7, 8]);

      try {
        for (int i = 0; i < 1000; i++) {
          final (id, future) = CallbackBridge.instance.register(kind: 10);
          futures.add(future);

          CallbackBridge.testFire(
            requestId: id,
            kind: 10,
            status: i,
            payload: ptr.cast<Void>(),
            size: 8,
          );
        }

        final results = await Future.wait(futures);
        expect(results.length, equals(1000));
        expect(results[500].status, equals(500));
        expect(CallbackBridge.instance.pendingCount, equals(0));
      } finally {
        calloc.free(ptr);
      }
    });

    test('Firing unknown request_id is safely ignored without crash', () {
      final ptr = calloc<Uint8>(4);
      try {
        CallbackBridge.testFire(
          requestId: 99999999,
          kind: 1,
          status: 0,
          payload: ptr.cast<Void>(),
          size: 4,
        );
        expect(CallbackBridge.instance.pendingCount, equals(0));
      } finally {
        calloc.free(ptr);
      }
    });

    test('Engine.pumpMessageQueues executes safely on headless engine', () {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      try {
        engine.pumpMessageQueues();
        engine.flushAndWait();
      } finally {
        engine.dispose();
      }
    });
  });
}
