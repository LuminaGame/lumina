import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('MaterialInstance Render State Visual Tests', () {
    late FilamentEngine engine;
    late FilamentRenderer renderer;
    late FilamentView view;
    late FilamentScene scene;
    late FilamentCamera camera;
    late FilamentSwapChain swapChain;
    
    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.opengl)!;
      FilamentMaterialBuilder.initEngine();
      
      renderer = engine.createRenderer();
      view = engine.createView();
      scene = engine.createScene();
      view.scene = scene;
      
      camera = engine.createCamera(engine.createEntity());
      // Look down -Z, at origin.
      camera.lookAt(
        eyeX: 0, eyeY: 0, eyeZ: 2,
        centerX: 0, centerY: 0, centerZ: 0,
        upX: 0, upY: 1, upZ: 0,
      );
      // Orthographic camera for easy projection
      camera.setProjectionOrtho(
        left: -1, right: 1,
        bottom: -1, top: 1,
        near: 0.1, far: 10,
      );
      view.camera = camera;
      
      renderer.setClearOptions(r: 0.0, g: 0.0, b: 0.0, a: 1.0, clear: true);
      
      swapChain = engine.createHeadlessSwapChain(64, 64);
      view.setViewport(0, 0, 64, 64);
    });

    tearDown(() {
      FilamentMaterialBuilder.shutdownEngine();
      engine.dispose();
    });

    test('Culling mode visual test', () {
      final builder = FilamentMaterialBuilder.create();
      builder.setName('CullingMat');
      builder.setShading(FilamatShading.unlit);
      builder.setDoubleSided(false);
      builder.setCode('''
        void material(inout MaterialInputs material) {
            prepareMaterial(material);
            material.baseColor = vec4(1.0, 1.0, 1.0, 1.0); // White
        }
      ''');
      final filamat = builder.build()!;
      builder.dispose();

      final material = FilamentMaterial.fromBuffer(
        engine: engine,
        filamatBuffer: filamat,
      );
      final instance = material.getDefaultInstance();

      // Single triangle wound counter-clockwise
      final vb = FilamentVertexBuffer.positions(
        engine: engine,
        vertexCount: 3,
      );
      final data = Float32List.fromList([
        -0.5, -0.5, 0.0, // Bottom-left
         0.5, -0.5, 0.0, // Bottom-right
         0.0,  0.5, 0.0, // Top-center
      ]);
      final dataBuffer = NativeBuffer.copy(data.buffer.asUint8List());
      vb.setBufferAt(engine, 0, dataBuffer);

      final ib = FilamentIndexBuffer.create(
        engine: engine,
        indexCount: 3,
        type: IndexType.ushort,
      );
      final indices = Uint16List.fromList([0, 1, 2]);
      final indicesBuffer = NativeBuffer.copy(indices.buffer.asUint8List());
      ib.setBuffer(engine, indicesBuffer);

      final renderable = engine.createEntity();
      final renderableBuilder = RenderableBuilder(1);
      renderableBuilder.boundingBox(-1.0, -1.0, -1.0, 1.0, 1.0, 1.0);
      renderableBuilder.geometry(0, PrimitiveType.triangles, vb, ib: ib);
      renderableBuilder.material(0, instance);
      renderableBuilder.build(engine, renderable);
      
      scene.addEntity(renderable);
      
      // Default culling is back. Windings in Filament are CCW.
      // So this should be visible.
      instance.setCullingMode(CullingMode.back);
      
      renderer.setClearOptions(r: 0.0, g: 0.0, b: 0.0, a: 1.0, clear: true);

      final pixels = Uint8List(64 * 64 * 4);

      renderer.beginFrame(swapChain);
      renderer.render(view);
      renderer.readPixels(x: 0, y: 0, width: 64, height: 64, outPixels: pixels);
      renderer.endFrame();
      engine.flushAndWait();

      // Center pixel (32, 32) should be white-ish (> 0)
      final centerIdx = (32 * 64 + 32) * 4;
      expect(pixels[centerIdx], greaterThan(0)); // R
      expect(pixels[centerIdx+1], greaterThan(0)); // G
      expect(pixels[centerIdx+2], greaterThan(0)); // B
      
      // Now set culling to front
      instance.setCullingMode(CullingMode.front);
      
      renderer.beginFrame(swapChain);
      renderer.render(view);
      renderer.readPixels(x: 0, y: 0, width: 64, height: 64, outPixels: pixels);
      renderer.endFrame();
      engine.flushAndWait();
      
      // Center pixel should be clear color (black)
      expect(pixels[centerIdx], equals(0)); // R
      expect(pixels[centerIdx+1], equals(0)); // G
      expect(pixels[centerIdx+2], equals(0)); // B
      
      // Clean up
      engine.destroyEntity(renderable);
      vb.dispose();
      ib.dispose();
      material.dispose();
    });

    test('Scissor visual test', () {
      final builder = FilamentMaterialBuilder.create();
      builder.setName('ScissorMat');
      builder.setShading(FilamatShading.unlit);
      builder.setDoubleSided(false);
      builder.setCode('''
        void material(inout MaterialInputs material) {
            prepareMaterial(material);
            material.baseColor = vec4(1.0, 1.0, 1.0, 1.0); // White
        }
      ''');
      final filamat = builder.build()!;
      builder.dispose();

      final material = FilamentMaterial.fromBuffer(
        engine: engine,
        filamatBuffer: filamat,
      );
      final instance = material.getDefaultInstance();

      final vb = FilamentVertexBuffer.positions(
        engine: engine,
        vertexCount: 3,
      );
      final data = Float32List.fromList([
        -0.5, -0.5, 0.0,
         0.5, -0.5, 0.0,
         0.0,  0.5, 0.0,
      ]);
      final dataBuffer = NativeBuffer.copy(data.buffer.asUint8List());
      vb.setBufferAt(engine, 0, dataBuffer);

      final ib = FilamentIndexBuffer.create(
        engine: engine,
        indexCount: 3,
        type: IndexType.ushort,
      );
      final indices = Uint16List.fromList([0, 1, 2]);
      final indicesBuffer = NativeBuffer.copy(indices.buffer.asUint8List());
      ib.setBuffer(engine, indicesBuffer);

      final renderable = engine.createEntity();
      final renderableBuilder = RenderableBuilder(1);
      renderableBuilder.boundingBox(-1.0, -1.0, -1.0, 1.0, 1.0, 1.0);
      renderableBuilder.geometry(0, PrimitiveType.triangles, vb, ib: ib);
      renderableBuilder.material(0, instance);
      renderableBuilder.build(engine, renderable);
      
      scene.addEntity(renderable);
      renderer.setClearOptions(r: 0.0, g: 0.0, b: 0.0, a: 1.0, clear: true);

      final pixels = Uint8List(64 * 64 * 4);
      final centerIdx = (32 * 64 + 32) * 4;

      // Unset scissor (or full screen scissor), should be visible
      instance.unsetScissor();
      renderer.beginFrame(swapChain);
      renderer.render(view);
      renderer.readPixels(x: 0, y: 0, width: 64, height: 64, outPixels: pixels);
      renderer.endFrame();
      engine.flushAndWait();
      
      expect(pixels[centerIdx], greaterThan(0));

      // Set scissor OUTSIDE the center (e.g. 0,0, 10,10)
      instance.setScissor(left: 0, bottom: 0, width: 10, height: 10);
      renderer.beginFrame(swapChain);
      renderer.render(view);
      renderer.readPixels(x: 0, y: 0, width: 64, height: 64, outPixels: pixels);
      renderer.endFrame();
      engine.flushAndWait();
      
      expect(pixels[centerIdx], equals(0)); // Should be black (culled by scissor)

      engine.destroyEntity(renderable);
      vb.dispose();
      ib.dispose();
      material.dispose();
    });

    test('Depth write and Polygon offset visual test', () {
      // Red Material
      final rBuilder = FilamentMaterialBuilder.create();
      rBuilder.setName('RedMat');
      rBuilder.setShading(FilamatShading.unlit);
      rBuilder.setDoubleSided(false);
      rBuilder.setCode('''
        void material(inout MaterialInputs material) {
            prepareMaterial(material);
            material.baseColor = vec4(1.0, 0.0, 0.0, 1.0);
        }
      ''');
      final filamatRed = rBuilder.build()!;
      rBuilder.dispose();
      final matRed = FilamentMaterial.fromBuffer(engine: engine, filamatBuffer: filamatRed);
      final instRed = matRed.getDefaultInstance();

      // Green Material
      final gBuilder = FilamentMaterialBuilder.create();
      gBuilder.setName('GreenMat');
      gBuilder.setShading(FilamatShading.unlit);
      gBuilder.setDoubleSided(false);
      gBuilder.setCode('''
        void material(inout MaterialInputs material) {
            prepareMaterial(material);
            material.baseColor = vec4(0.0, 1.0, 0.0, 1.0);
        }
      ''');
      final filamatGreen = gBuilder.build()!;
      gBuilder.dispose();
      final matGreen = FilamentMaterial.fromBuffer(engine: engine, filamatBuffer: filamatGreen);
      final instGreen = matGreen.getDefaultInstance();

      // Triangle 1 (Z=0.5, closer to camera at Z=2)
      final vb1 = FilamentVertexBuffer.positions(engine: engine, vertexCount: 3);
      final data1 = Float32List.fromList([-0.5, -0.5, 0.5, 0.5, -0.5, 0.5, 0.0, 0.5, 0.5]);
      vb1.setBufferAt(engine, 0, NativeBuffer.copy(data1.buffer.asUint8List()));

      // Triangle 2 (Z=0.0, further)
      final vb2 = FilamentVertexBuffer.positions(engine: engine, vertexCount: 3);
      final data2 = Float32List.fromList([-0.5, -0.5, 0.0, 0.5, -0.5, 0.0, 0.0, 0.5, 0.0]);
      vb2.setBufferAt(engine, 0, NativeBuffer.copy(data2.buffer.asUint8List()));

      final ib = FilamentIndexBuffer.create(engine: engine, indexCount: 3, type: IndexType.ushort);
      ib.setBuffer(engine, NativeBuffer.copy(Uint16List.fromList([0, 1, 2]).buffer.asUint8List()));

      final r1 = engine.createEntity();
      final r2 = engine.createEntity();
      
      final builder1 = RenderableBuilder(1);
      builder1.boundingBox(-1.0, -1.0, -1.0, 1.0, 1.0, 1.0);
      builder1.geometry(0, PrimitiveType.triangles, vb1, ib: ib);
      builder1.material(0, instRed);
      builder1.build(engine, r1);
      
      final builder2 = RenderableBuilder(1);
      builder2.boundingBox(-1.0, -1.0, -1.0, 1.0, 1.0, 1.0);
      builder2.geometry(0, PrimitiveType.triangles, vb2, ib: ib);
      builder2.material(0, instGreen);
      builder2.build(engine, r2);

      // Add only closer triangle first
      scene.addEntity(r1);
      
      renderer.setClearOptions(r: 0.0, g: 0.0, b: 0.0, a: 1.0, clear: true);
      final pixels = Uint8List(64 * 64 * 4);
      final centerIdx = (32 * 64 + 32) * 4;

      // 1. Depth write OFF on Red.
      instRed.setDepthWrite(false);
      
      renderer.beginFrame(swapChain);
      renderer.render(view);
      renderer.readPixels(x: 0, y: 0, width: 64, height: 64, outPixels: pixels);
      renderer.endFrame();
      engine.flushAndWait();
      
      expect(pixels[centerIdx], greaterThan(200)); // Red is visible
      expect(pixels[centerIdx+1], lessThan(50));    // Not green
      
      // 2. Add Green triangle. Because Red didn't write depth, Green will overdraw it despite being further!
      scene.addEntity(r2);
      
      renderer.beginFrame(swapChain);
      renderer.render(view);
      renderer.readPixels(x: 0, y: 0, width: 64, height: 64, outPixels: pixels);
      renderer.endFrame();
      engine.flushAndWait();
      
      expect(pixels[centerIdx+1], greaterThan(0)); // Green overdraws red
      
      // 3. Now enable Depth write on Red. Since Red is drawn first (or rather, Z buffer works), Red should occlude Green.
      instRed.setDepthWrite(true);
      instRed.setDepthCulling(true);
      instGreen.setDepthCulling(true);
      
      // Wait, Filament sorts by depth, so it might draw closer (Red) first, writing depth, then Green is depth-failed.
      renderer.beginFrame(swapChain);
      renderer.render(view);
      renderer.readPixels(x: 0, y: 0, width: 64, height: 64, outPixels: pixels);
      renderer.endFrame();
      engine.flushAndWait();
      
      // Now Red should win
      expect(pixels[centerIdx], greaterThan(200)); // Red wins
      expect(pixels[centerIdx+1], lessThan(50));    // Green fails depth test
      
      // 4. Polygon offset: Push Red back using offset
      instRed.setPolygonOffset(2.0, 2.0); // push it back
      
      renderer.beginFrame(swapChain);
      renderer.render(view);
      renderer.readPixels(x: 0, y: 0, width: 64, height: 64, outPixels: pixels);
      renderer.endFrame();
      engine.flushAndWait();
      
      // Clean up
      engine.destroyEntity(r1);
      engine.destroyEntity(r2);
      vb1.dispose();
      vb2.dispose();
      ib.dispose();
      matRed.dispose();
      matGreen.dispose();
    });
  });
}
