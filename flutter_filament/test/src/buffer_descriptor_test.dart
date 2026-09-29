import 'dart:ffi' as ffi;
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('BufferDescriptor Ownership Bridge Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) {
        engine.flushAndWait();
        engine.dispose();
      }
    });

    test('Zero-copy: address equality', () {
      final buffer = NativeBuffer.allocate(64);
      final nativeAddress = BufferOwnershipRegistry.peekAddress(buffer.pointer.cast());
      expect(nativeAddress.address, buffer.pointer.address);
      buffer.free();
    });

    test('callback fires on consumption', () async {
      final buffer = NativeBuffer.allocate(64);
      final view = buffer.asTypedList;
      for (var i = 0; i < 64; i++) {
        view[i] = i;
      }
      
      final (user, callback, token) = BufferOwnershipRegistry.instance.register(
        buffer,
        onFree: () => buffer.free(),
      );
      
      BufferOwnershipRegistry.consumeTestBuffer(
        engine: engine,
        data: buffer.pointer.cast(),
        size: 64,
        callback: callback,
        user: user,
      );
      
      engine.flushAndWait();
      
      await BufferOwnershipRegistry.instance.whenReleased(token);
      expect(buffer.isReleased, isTrue);
    });

    test('Consume 100 buffers without leaking', () async {
      final tokens = <int>[];
      final initialCount = BufferOwnershipRegistry.instance.pendingCount;
      
      for (int i = 0; i < 100; i++) {
        final buffer = NativeBuffer.allocate(64);
        final (user, callback, token) = BufferOwnershipRegistry.instance.register(
          buffer,
          onFree: () => buffer.free(),
        );
        tokens.add(token);
        
        BufferOwnershipRegistry.consumeTestBuffer(
          engine: engine,
          data: buffer.pointer.cast(),
          size: 64,
          callback: callback,
          user: user,
        );
      }
      
      engine.flushAndWait();
      
      for (final token in tokens) {
        await BufferOwnershipRegistry.instance.whenReleased(token);
      }
      
      expect(BufferOwnershipRegistry.instance.pendingCount, initialCount);
    });

    test('cb == NULL path does not leak or crash', () {
      final buffer = NativeBuffer.allocate(64);
      
      BufferOwnershipRegistry.consumeTestBuffer(
        engine: engine,
        data: buffer.pointer.cast(),
        size: 64,
        callback: ffi.nullptr.cast(),
        user: ffi.nullptr.cast(),
      );
      
      engine.flushAndWait();
      buffer.free();
      // Test passed if no crash.
    });

    test('PixelBufferDescriptor variant', () async {
      final buffer = NativeBuffer.allocate(16);
      
      final (user, callback, token) = BufferOwnershipRegistry.instance.register(
        buffer,
        onFree: () => buffer.free(),
      );
      
      BufferOwnershipRegistry.consumeTestPixelBuffer(
        engine: engine,
        data: buffer.pointer.cast(),
        size: 16,
        pixelFormat: 0, // RGBA
        pixelType: 0, // UBYTE
        stride: 0,
        alignment: 1,
        callback: callback,
        user: user,
      );
      
      engine.flushAndWait();
      
      await BufferOwnershipRegistry.instance.whenReleased(token);
      expect(buffer.isReleased, isTrue);
    });
  });
}
