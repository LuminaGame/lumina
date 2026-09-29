import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:test/test.dart';

void main() {
  group('VertexBuffer setBufferAt with byteOffset & vertexCount Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) {
        engine.dispose();
      }
    });

    test('Full upload baseline and vertexCount stability', () {
      final vb = FilamentVertexBuffer.positions(
        engine: engine,
        vertexCount: 4,
      );

      expect(vb.vertexCount, equals(4));

      final quadPositions = Float32List.fromList([
        -1.0, -1.0, 0.0,
         1.0, -1.0, 0.0,
        -1.0,  1.0, 0.0,
         1.0,  1.0, 0.0,
      ]);

      vb.setData(quadPositions, bufferIndex: 0);
      expect(vb.vertexCount, equals(4));

      engine.flushAndWait();
      vb.dispose();
    });

    test('Partial update with byteOffset: update vertices 2..3', () {
      final vb = FilamentVertexBuffer.positions(
        engine: engine,
        vertexCount: 4,
      );

      final fullData = Float32List.fromList([
        -1.0, -1.0, 0.0,
         1.0, -1.0, 0.0,
        -1.0,  1.0, 0.0,
         1.0,  1.0, 0.0,
      ]);
      vb.setData(fullData, bufferIndex: 0);

      // Sub-range update: only vertices 2 and 3 (offset = 2 * 12 = 24 bytes)
      final partialData = Float32List.fromList([
        -0.5, 0.5, 0.0,
         0.5, 0.5, 0.0,
      ]);

      vb.setData(partialData, bufferIndex: 0, byteOffset: 2 * 12);
      expect(vb.vertexCount, equals(4));

      engine.flushAndWait();
      vb.dispose();
    });

    test('NativeBuffer zero-copy upload with ownership release future', () async {
      final vb = FilamentVertexBuffer.positions(
        engine: engine,
        vertexCount: 4,
      );

      final rawData = Float32List(4 * 3);
      final nativeBuf = NativeBuffer.copy(Uint8List.view(rawData.buffer));
      expect(nativeBuf.isReleased, isFalse);

      bool freed = false;
      final (user, callback, token) = BufferOwnershipRegistry.instance.register(
        nativeBuf,
        onFree: () {
          freed = true;
          nativeBuf.free();
        },
      );

      final releaseFuture = BufferOwnershipRegistry.instance.whenReleased(token);

      c.filament_vertex_buffer_set_buffer_at(
        engine.nativePointer,
        vb.nativePointer,
        0,
        nativeBuf.pointer.cast(),
        nativeBuf.sizeInBytes,
        0,
        callback,
        user,
      );

      expect(freed, isFalse);

      engine.flushAndWait();
      await releaseFuture;

      expect(freed, isTrue);
      expect(nativeBuf.isReleased, isTrue);

      vb.dispose();
    });

    test('60 sequential partial updates and flushAndWait cycle drains cleanly', () {
      final vb = FilamentVertexBuffer.positions(
        engine: engine,
        vertexCount: 4,
      );

      final vertexPatch = Float32List.fromList([0.0, 1.0, 2.0]);
      for (int i = 0; i < 60; i++) {
        vb.setData(vertexPatch, bufferIndex: 0, byteOffset: (i % 4) * 12);
      }

      engine.flushAndWait();
      expect(vb.vertexCount, equals(4));
      vb.dispose();
    });

    test('Out of bounds bufferIndex and negative byteOffset throw Dart exceptions', () {
      final vb = FilamentVertexBuffer.positions(
        engine: engine,
        vertexCount: 4,
        bufferCount: 1,
      );

      final rawData = Float32List(4 * 3);
      final nativeBuf = NativeBuffer.copy(Uint8List.view(rawData.buffer));

      expect(
        () => vb.setBufferAt(engine, 1, nativeBuf),
        throwsRangeError,
      );

      expect(
        () => vb.setBufferAt(engine, -1, nativeBuf),
        throwsRangeError,
      );

      expect(
        () => vb.setBufferAt(engine, 0, nativeBuf, byteOffset: -10),
        throwsArgumentError,
      );

      nativeBuf.free();
      vb.dispose();
    });
  });
}
