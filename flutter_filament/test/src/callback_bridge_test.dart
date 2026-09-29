import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';
import 'package:flutter_filament/src/callback_bridge.dart';
import 'package:flutter_filament/src/engine.dart';
import 'package:test/test.dart';

void main() {
  group('Callback Bridge Tests', () {
    late FilamentEngine engine;

    setUpAll(() {
      CallbackBridge.instance.init();
    });

    tearDownAll(() {
      CallbackBridge.instance.shutdown();
    });

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) {
        engine.flushAndWait();
        engine.dispose();
      }
    });

    test('register + fire completes correctly', () async {
      final (reqId, future) = CallbackBridge.instance.register(kind: 1);
      
      final payload = calloc<ffi.Uint8>(4);
      payload.asTypedList(4).setAll(0, [10, 20, 30, 40]);
      
      CallbackBridge.testFire(
        requestId: reqId,
        kind: 1,
        status: 0,
        payload: payload.cast(),
        size: 4,
      );
      
      final result = await future;
      
      expect(result.kind, 1);
      expect(result.status, 0);
      expect(result.payload, [10, 20, 30, 40]);
      
      calloc.free(payload);
    });

    test('concurrent requests map correctly', () async {
      final (id1, f1) = CallbackBridge.instance.register(kind: 1);
      final (id2, f2) = CallbackBridge.instance.register(kind: 2);
      
      final p1 = calloc<ffi.Uint8>(1);
      p1.asTypedList(1)[0] = 42;
      
      final p2 = calloc<ffi.Uint8>(1);
      p2.asTypedList(1)[0] = 84;
      
      // Fire in reverse order
      CallbackBridge.testFire(
        requestId: id2,
        kind: 2,
        status: 0,
        payload: p2.cast(),
        size: 1,
      );
      
      CallbackBridge.testFire(
        requestId: id1,
        kind: 1,
        status: 0,
        payload: p1.cast(),
        size: 1,
      );
      
      final res2 = await f2;
      final res1 = await f1;
      
      expect(res1.kind, 1);
      expect(res1.payload[0], 42);
      
      expect(res2.kind, 2);
      expect(res2.payload[0], 84);
      
      calloc.free(p1);
      calloc.free(p2);
    });

    test('async fire lands correctly', () async {
      final (reqId, future) = CallbackBridge.instance.register(kind: 3);
      
      final payload = calloc<ffi.Uint8>(2);
      payload.asTypedList(2).setAll(0, [99, 100]);
      
      CallbackBridge.testFireAsync(
        requestId: reqId,
        kind: 3,
        status: 0,
        payload: payload.cast(),
        size: 2,
      );
      
      final result = await future;
      expect(result.kind, 3);
      expect(result.payload, [99, 100]);
      
      calloc.free(payload);
    });

    test('1000 register+fire cycles do not leak', () async {
      final initialCount = CallbackBridge.instance.pendingCount;
      
      final futures = <Future<CallbackResult>>[];
      for (int i = 0; i < 1000; i++) {
        final (id, f) = CallbackBridge.instance.register(kind: 4);
        futures.add(f);
        CallbackBridge.testFire(
          requestId: id,
          kind: 4,
          status: 0,
          payload: ffi.nullptr.cast(),
          size: 0,
        );
      }
      
      await Future.wait(futures);
      
      expect(CallbackBridge.instance.pendingCount, initialCount);
    });

    test('unknown request id does not crash', () async {
      final initialCount = CallbackBridge.instance.pendingCount;
      
      // Fire with unknown ID
      CallbackBridge.testFire(
        requestId: 9999999,
        kind: 5,
        status: 0,
        payload: ffi.nullptr.cast(),
        size: 0,
      );
      
      // Wait a tick to allow the listener to process
      await Future.delayed(Duration(milliseconds: 10));
      
      expect(CallbackBridge.instance.pendingCount, initialCount);
    });

    test('pumpMessageQueues works headlessly', () {
      // Just make sure it doesn't crash
      engine.pumpMessageQueues();
      expect(true, isTrue);
    });
  });
}
