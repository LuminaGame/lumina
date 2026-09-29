import 'dart:ffi' as ffi;
import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('VertexBuffer Partial Updates', () {
    late FilamentEngine engine;
    late FilamentRenderer renderer;
    late FilamentView view;
    late FilamentScene scene;
    late FilamentCamera camera;
    late FilamentSwapChain swapChain;
    late FilamentRenderTarget renderTarget;

    const int width = 64;
    const int height = 64;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      engine.dispose();
    });

    test('vertexCount returns correct value', () {
      final vb = FilamentVertexBuffer.positions(
        engine: engine,
        vertexCount: 4,
      );
      expect(vb.vertexCount, 4);
      vb.dispose();
    });

    test('Offset+size exceeding capacity throws RangeError', () {
      final vb = FilamentVertexBuffer.positions(
        engine: engine,
        vertexCount: 4, // 4 * 12 = 48 bytes total
      );

      final data = Float32List(3); // 12 bytes
      
      // Valid upload
      expect(() => vb.setData(data, byteOffset: 36), returnsNormally);

      // Invalid upload (exceeds 48)
      expect(() => vb.setData(data, byteOffset: 40), throwsA(isA<RangeError>()));

      vb.dispose();
    });

    test('Repeated per-frame updates without crash', () {
      final vb = FilamentVertexBuffer.positions(
        engine: engine,
        vertexCount: 4,
      );

      // 60 frames of partial updates
      for (int i = 0; i < 60; i++) {
        final data = Float32List.fromList([1.0, 2.0, 3.0]); // 1 vertex (12 bytes)
        vb.setData(data, byteOffset: 12); // update vertex 1
      }
      
      expect(vb.vertexCount, 4);
      vb.dispose();
    });
  });
}
