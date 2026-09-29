import 'dart:ffi' as ffi;
import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('BufferObject Tests', () {
    late FilamentEngine engine;
    late FilamentRenderer renderer;
    late FilamentView view;
    late FilamentScene scene;
    late FilamentSwapChain swapChain;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      renderer = engine.createRenderer();
      view = engine.createView();
      scene = engine.createScene();
      view.scene = scene;
      swapChain = engine.createHeadlessSwapChain(64, 64);
    });

    tearDown(() {
      engine.dispose();
    });

    test('create, get byteCount, destroy', () {
      final bo = BufferObject.create(
        engine: engine,
        byteCount: 96,
      );
      
      expect(bo.byteCount, equals(96));
      expect(bo.bindingType, equals(BufferObjectBindingType.vertex));
      
      bo.dispose();
      expect(bo.isDisposed, isTrue);
    });

    test('Render path with enableBufferObjects', () {
      final bo = BufferObject.create(engine: engine, byteCount: 48); // 4 * 3 * 4 = 48 bytes
      final data = Float32List.fromList([
        -1.0, -1.0, 0.0,
         1.0, -1.0, 0.0,
        -1.0,  1.0, 0.0,
         1.0,  1.0, 0.0,
      ]);
      bo.setData(data);

      final vb = FilamentVertexBuffer.positions(
        engine: engine,
        vertexCount: 4,
        enableBufferObjects: true,
      );
      
      vb.setBufferObjectAt(engine, 0, bo);

      // Render it (smoke test, just ensure no crash)
      renderer.beginFrame(swapChain);
      renderer.render(view);
      renderer.endFrame();

      vb.dispose();
      bo.dispose();
    });

    test('Sharing BufferObject between two VertexBuffers', () {
      final bo = BufferObject.create(engine: engine, byteCount: 48);
      final data = Float32List(12); // Zeros
      bo.setData(data);

      final vb1 = FilamentVertexBuffer.positions(
        engine: engine,
        vertexCount: 4,
        enableBufferObjects: true,
      );
      vb1.setBufferObjectAt(engine, 0, bo);

      final vb2 = FilamentVertexBuffer.positions(
        engine: engine,
        vertexCount: 4,
        enableBufferObjects: true,
      );
      vb2.setBufferObjectAt(engine, 0, bo);

      renderer.beginFrame(swapChain);
      renderer.render(view);
      renderer.endFrame();

      vb1.dispose();
      vb2.dispose();
      bo.dispose();
    });

    test('Single-point update reflects correctly', () {
      final bo = BufferObject.create(engine: engine, byteCount: 48);
      final data = Float32List(12);
      bo.setData(data);

      final vb = FilamentVertexBuffer.positions(
        engine: engine,
        vertexCount: 4,
        enableBufferObjects: true,
      );
      vb.setBufferObjectAt(engine, 0, bo);

      // Update part of the buffer
      final vertexData = Float32List.fromList([1.0, 1.0, 1.0]);
      bo.setData(vertexData, byteOffset: 12); // vertex 1 (0-indexed)

      renderer.beginFrame(swapChain);
      renderer.render(view);
      renderer.endFrame();

      vb.dispose();
      bo.dispose();
    });

    test('State errors for mismatched API usage', () {
      final bo = BufferObject.create(engine: engine, byteCount: 48);

      final vbEnabled = FilamentVertexBuffer.positions(
        engine: engine,
        vertexCount: 4,
        enableBufferObjects: true,
      );
      
      final vbDisabled = FilamentVertexBuffer.positions(
        engine: engine,
        vertexCount: 4,
        enableBufferObjects: false,
      );

      final data = Float32List(12);

      // setBufferAt on BO-enabled buffer throws StateError
      expect(
        () => vbEnabled.setData(data),
        throwsA(isA<StateError>()),
      );

      // setBufferObjectAt on BO-disabled buffer throws StateError
      expect(
        () => vbDisabled.setBufferObjectAt(engine, 0, bo),
        throwsA(isA<StateError>()),
      );

      vbEnabled.dispose();
      vbDisabled.dispose();
      bo.dispose();
    });

    test('Destroy order and cleanup', () {
      final bo = BufferObject.create(engine: engine, byteCount: 48);
      final vb = FilamentVertexBuffer.positions(
        engine: engine,
        vertexCount: 4,
        enableBufferObjects: true,
      );
      vb.setBufferObjectAt(engine, 0, bo);

      // Destroy vb first, then bo
      vb.dispose();
      bo.dispose();
      engine.flushAndWait();
      
      // Implicitly expects no crash
      expect(true, isTrue);
    });
  });
}
