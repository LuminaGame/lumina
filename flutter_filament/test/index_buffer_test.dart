import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:test/test.dart';

void main() {
  group('IndexBuffer bufferType, offset, and queries Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) {
        engine.dispose();
      }
    });

    test('Enum fidelity: IndexType values match ElementType::USHORT(12) and UINT(17)', () {
      expect(IndexType.ushort.value, equals(c.filament_enum_index_type(0)));
      expect(IndexType.uint.value, equals(c.filament_enum_index_type(1)));

      expect(IndexType.ushort.value, equals(12));
      expect(IndexType.uint.value, equals(17));
    });

    test('USHORT IndexBuffer creation, indexCount, and data upload', () {
      final ib = FilamentIndexBuffer.create(
        engine: engine,
        indexCount: 6,
        type: IndexType.ushort,
      );

      expect(ib.indexCount, equals(6));
      expect(ib.type, equals(IndexType.ushort));
      expect(ib.byteCapacity, equals(12));

      final quadIndices = Uint16List.fromList([0, 1, 2, 2, 3, 0]);
      ib.setIndicesU16(quadIndices);

      engine.flushAndWait();
      ib.dispose();
      expect(ib.isDisposed, isTrue);
    });

    test('UINT IndexBuffer creation (>65535 capacity) and data upload', () {
      final ib = FilamentIndexBuffer.create(
        engine: engine,
        indexCount: 70000,
        type: IndexType.uint,
      );

      expect(ib.indexCount, equals(70000));
      expect(ib.type, equals(IndexType.uint));
      expect(ib.byteCapacity, equals(70000 * 4));

      final sampleIndices = Uint32List.fromList([0, 65536, 69999]);
      ib.setIndicesU32(sampleIndices);

      engine.flushAndWait();
      ib.dispose();
    });

    test('Partial index update at byteOffset (multiple of 4)', () {
      final ib = FilamentIndexBuffer.create(
        engine: engine,
        indexCount: 12, // 2 quads = 12 ushort indices = 24 bytes
        type: IndexType.ushort,
      );

      final fullIndices = Uint16List.fromList([
        0, 1, 2, 2, 3, 0,
        4, 5, 6, 6, 7, 4,
      ]);
      ib.setIndicesU16(fullIndices);

      // Re-upload second quad at byteOffset 12 (6 * 2 bytes = 12, multiple of 4)
      final secondQuad = Uint16List.fromList([4, 6, 5, 5, 7, 4]);
      ib.setIndicesU16(secondQuad, byteOffset: 12);

      expect(ib.indexCount, equals(12));
      engine.flushAndWait();
      ib.dispose();
    });

    test('byteOffset not a multiple of 4 throws ArgumentError', () {
      final ib = FilamentIndexBuffer.create(
        engine: engine,
        indexCount: 6,
        type: IndexType.ushort,
      );

      final indices = Uint16List.fromList([0, 1, 2]);
      expect(
        () => ib.setIndicesU16(indices, byteOffset: 6), // 6 is not a multiple of 4
        throwsArgumentError,
      );

      ib.dispose();
    });

    test('Type mismatch: calling setIndicesU32 on USHORT buffer throws ArgumentError', () {
      final ib = FilamentIndexBuffer.create(
        engine: engine,
        indexCount: 6,
        type: IndexType.ushort,
      );

      final indices32 = Uint32List.fromList([0, 1, 2, 2, 3, 0]);
      expect(
        () => ib.setIndicesU32(indices32),
        throwsArgumentError,
      );

      ib.dispose();
    });

    test('Type mismatch: calling setIndicesU16 on UINT buffer throws ArgumentError', () {
      final ib = FilamentIndexBuffer.create(
        engine: engine,
        indexCount: 6,
        type: IndexType.uint,
      );

      final indices16 = Uint16List.fromList([0, 1, 2, 2, 3, 0]);
      expect(
        () => ib.setIndicesU16(indices16),
        throwsArgumentError,
      );

      ib.dispose();
    });

    test('NativeBuffer zero-copy ownership release future on IndexBuffer setBuffer', () async {
      final ib = FilamentIndexBuffer.create(
        engine: engine,
        indexCount: 6,
        type: IndexType.ushort,
      );

      final rawData = Uint16List.fromList([0, 1, 2, 2, 3, 0]);
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

      c.filament_index_buffer_set_buffer(
        engine.nativePointer,
        ib.nativePointer,
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

      ib.dispose();
    });
  });
}
