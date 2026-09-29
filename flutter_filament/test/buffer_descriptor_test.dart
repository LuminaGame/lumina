import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('BufferDescriptor Ownership & Zero-Copy Bridge', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      engine.flushAndWait();
      engine.dispose();
    });

    test('Zero-copy: NativeBuffer pointer address is identical to C address', () {
      final buffer = NativeBuffer.allocate(128);
      try {
        final peekedAddress = BufferOwnershipRegistry.peekAddress(buffer.pointer.cast<Void>());
        expect(peekedAddress.address, equals(buffer.pointer.address));
      } finally {
        buffer.free();
      }
    });

    test('Consume buffer descriptor releases memory and completes whenReleased Future on flushAndWait', () async {
      final buffer = NativeBuffer.allocate(64);
      final list = buffer.asTypedList;
      for (int i = 0; i < 64; i++) {
        list[i] = i;
      }

      final (user, cb, token) = BufferOwnershipRegistry.instance.register(
        buffer,
        onFree: () => buffer.free(),
      );

      final releaseFuture = BufferOwnershipRegistry.instance.whenReleased(token);

      BufferOwnershipRegistry.consumeTestBuffer(
        engine: engine,
        data: buffer.pointer.cast<Void>(),
        size: buffer.sizeInBytes,
        callback: cb,
        user: user,
      );

      expect(releaseFuture, completion(isA<void>()));
      engine.flushAndWait();

      await releaseFuture;
      expect(buffer.isReleased, isTrue);
      expect(BufferOwnershipRegistry.instance.pendingCount, equals(0));
    });

    test('Consume 100 buffers back to back with zero leaks', () async {
      final futures = <Future<void>>[];
      for (int i = 0; i < 100; i++) {
        final buffer = NativeBuffer.allocate(32);
        final (user, cb, token) = BufferOwnershipRegistry.instance.register(
          buffer,
          onFree: () => buffer.free(),
        );
        futures.add(BufferOwnershipRegistry.instance.whenReleased(token));

        BufferOwnershipRegistry.consumeTestBuffer(
          engine: engine,
          data: buffer.pointer.cast<Void>(),
          size: buffer.sizeInBytes,
          callback: cb,
          user: user,
        );
      }

      expect(BufferOwnershipRegistry.instance.pendingCount, equals(100));

      engine.flushAndWait();
      await Future.wait(futures);

      expect(BufferOwnershipRegistry.instance.pendingCount, equals(0));
    });

    test('NULL callback path neither crashes nor creates registry entries', () {
      final initialPending = BufferOwnershipRegistry.instance.pendingCount;
      final ptr = calloc<Uint8>(64);
      try {
        BufferOwnershipRegistry.consumeTestBuffer(
          engine: engine,
          data: ptr.cast<Void>(),
          size: 64,
          callback: nullptr,
          user: nullptr,
        );
        engine.flushAndWait();
        expect(BufferOwnershipRegistry.instance.pendingCount, equals(initialPending));
      } finally {
        calloc.free(ptr);
      }
    });

    test('PixelBufferDescriptor variant release callback flows through same registry', () async {
      final buffer = NativeBuffer.allocate(4 * 4 * 4); // 4x4 RGBA
      final (user, cb, token) = BufferOwnershipRegistry.instance.register(
        buffer,
        onFree: () => buffer.free(),
      );

      final releaseFuture = BufferOwnershipRegistry.instance.whenReleased(token);

      BufferOwnershipRegistry.consumeTestPixelBuffer(
        engine: engine,
        data: buffer.pointer.cast<Void>(),
        size: buffer.sizeInBytes,
        pixelFormat: 6, // RGBA
        pixelType: 0,   // UBYTE
        stride: 4,
        alignment: 1,
        callback: cb,
        user: user,
      );

      engine.flushAndWait();
      await releaseFuture;

      expect(buffer.isReleased, isTrue);
      expect(BufferOwnershipRegistry.instance.pendingCount, equals(0));
    });

    test('NativeBuffer throws StateError when accessed after free', () {
      final buffer = NativeBuffer.allocate(16);
      expect(buffer.isReleased, isFalse);
      expect(buffer.asTypedList.length, equals(16));

      buffer.free();
      expect(buffer.isReleased, isTrue);
      expect(() => buffer.asTypedList, throwsStateError);
      // Multiple frees are safe
      buffer.free();
    });
  });
}
