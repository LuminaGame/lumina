import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('Index Buffer Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) {
        engine.dispose();
      }
    });

    test('USHORT path - rendering quad with 6 uint16 indices', () {
      final ib = FilamentIndexBuffer.create(
        engine: engine,
        indexCount: 6,
        type: IndexType.ushort,
      );

      expect(ib.isDisposed, isFalse);
      expect(ib.indexCount, 6);

      final indices = Uint16List.fromList([0, 1, 2, 2, 3, 0]);
      ib.setIndicesU16(indices);

      ib.dispose();
    });

    test('UINT path - large capacity >65535', () {
      final ib = FilamentIndexBuffer.create(
        engine: engine,
        indexCount: 70000,
        type: IndexType.uint,
      );

      expect(ib.isDisposed, isFalse);
      expect(ib.indexCount, 70000);

      final indices = Uint32List(6);
      ib.setIndicesU32(indices);

      ib.dispose();
    });

    test('byteOffset partial update (multiple of 4) moves quad', () {
      final ib = FilamentIndexBuffer.create(
        engine: engine,
        indexCount: 12,
        type: IndexType.ushort,
      );

      final initialIndices = Uint16List.fromList([0, 1, 2, 2, 3, 0, 4, 5, 6, 6, 7, 4]);
      ib.setIndicesU16(initialIndices);

      // Re-upload second quad's 6 indices at byteOffset=12 (6 * uint16 = 12 bytes)
      final newIndices = Uint16List.fromList([8, 9, 10, 10, 11, 8]);
      ib.setIndicesU16(newIndices, byteOffset: 12);

      ib.dispose();
    });

    test('byteOffset not a multiple of 4 throws ArgumentError', () {
      final ib = FilamentIndexBuffer.create(
        engine: engine,
        indexCount: 6,
        type: IndexType.ushort,
      );

      final indices = Uint16List(2);
      
      expect(
        () => ib.setIndicesU16(indices, byteOffset: 6),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('multiple of 4'))),
      );

      ib.dispose();
    });

    test('Type mismatched convenience calls throw ArgumentError', () {
      final ib = FilamentIndexBuffer.create(
        engine: engine,
        indexCount: 6,
        type: IndexType.ushort,
      );

      final indicesU32 = Uint32List(6);
      expect(
        () => ib.setIndicesU32(indicesU32),
        throwsArgumentError,
      );

      ib.dispose();
    });
  });
}
