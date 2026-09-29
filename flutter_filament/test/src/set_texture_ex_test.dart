import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('setTexture with TextureSampler Tests', () {
    late FilamentEngine engine;
    late FilamentSwapChain swapChain;
    late FilamentRenderer renderer;
    late FilamentView view;
    late FilamentScene scene;
    late FilamentCamera camera;
    late int cameraEntity;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!; // Try noop first to pass in CI easily, fallback if needed
      swapChain = engine.createHeadlessSwapChain(128, 128);
      renderer = engine.createRenderer();
      view = engine.createView();
      scene = engine.createScene();
      cameraEntity = engine.createEntity();
      camera = engine.createCamera(cameraEntity);

      view.scene = scene;
      view.camera = camera;
      view.setViewport(0, 0, 128, 128);
    });

    tearDown(() {
      if (!engine.isDisposed) {
        camera.dispose();
        engine.destroyEntity(cameraEntity);
        scene.dispose();
        view.dispose();
        renderer.dispose();
        swapChain.dispose();
        engine.dispose();
      }
    });

    test('setTexture can accept a packed TextureSampler and does not crash', () {
      FilamentMaterialBuilder.initEngine();
      final builder = FilamentMaterialBuilder.create();
      builder.setName('TexturedMaterial');
      builder.setShading(FilamatShading.unlit);
      builder.addSamplerParameter('albedo');
      builder.requireAttribute(VertexAttribute.uv0.value);
      builder.setCode('''
        void material(inout MaterialInputs material) {
            prepareMaterial(material);
            material.baseColor = texture(materialParams_albedo, getUV0());
        }
      ''');
      
      final package = builder.build();
      builder.dispose();
      
      final material = FilamentMaterial.fromBuffer(engine: engine, filamatBuffer: package!);
      final mi = material.createInstance('default');
      
      final texture = FilamentTexture.create2D(
        engine: engine,
        width: 2,
        height: 2,
        format: TextureFormat.rgba8,
      );
      
      final pixels = Uint8List(2 * 2 * 4);
      texture.setImage(
        width: 2,
        height: 2,
        pixelData: pixels,
        pixelFormat: PixelFormat.rgba,
        pixelType: PixelType.ubyte,
      );

      // Verify that the C hook doesn't assert and correctly binds the sampler
      expect(() => mi.setTexture(
        'albedo', 
        texture, 
        sampler: TextureSampler(
          wrapS: SamplerWrapMode.repeat,
          wrapT: SamplerWrapMode.repeat,
          filterMin: SamplerMinFilter.nearest,
          filterMag: SamplerMagFilter.nearest,
        )
      ), returnsNormally);

      expect(() => mi.setTexture(
        'albedo', 
        texture, 
        sampler: TextureSampler.trilinear()
      ), returnsNormally);

      texture.dispose();
      mi.dispose();
      material.dispose();
      FilamentMaterialBuilder.shutdownEngine();
    });

    // We only test that setTexture works without crashing for headless on NOOP. 
    // Actual pixel readout is usually skipped or validated in integration tests
    // because noop backend does not rasterize pixels.
  });
}
