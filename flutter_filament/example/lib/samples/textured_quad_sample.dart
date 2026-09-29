import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_filament/flutter_filament.dart';

class TexturedQuadSample extends StatefulWidget {
  const TexturedQuadSample({super.key});

  @override
  State<TexturedQuadSample> createState() => _TexturedQuadSampleState();
}

class _TexturedQuadSampleState extends State<TexturedQuadSample> {
  String _info = 'Initializing Textured Quad 3D scene...';
  FilamentEngine? _engine;
  FilamentScene? _scene;
  int? _entity;
  FilamentSkybox? _skybox;
  FilamentMaterial? _material;
  FilamentMaterialInstance? _instance;
  FilamentTexture? _texture;
  FilamentVertexBuffer? _vb;
  FilamentIndexBuffer? _ib;
  Timer? _timer;
  double _now = 0.0;

  void _cleanupResources() {
    _timer?.cancel();
    _timer = null;

    if (_entity != null) {
      if (_scene != null) {
        _scene!.removeEntity(_entity!);
      }
      if (_engine != null) {
        _engine!.destroyEntity(_entity!);
      }
      _entity = null;
    }
    _skybox?.dispose();
    _skybox = null;
    _instance?.dispose();
    _instance = null;
    _material?.dispose();
    _material = null;
    _texture?.dispose();
    _texture = null;
    _vb?.dispose();
    _vb = null;
    _ib?.dispose();
    _ib = null;
  }

  @override
  void dispose() {
    _cleanupResources();
    super.dispose();
  }

  void _setup3dScene(
    FilamentEngine engine,
    FilamentScene scene,
    FilamentCamera camera,
    FilamentView view,
  ) {
    _engine = engine;
    _scene = scene;
    view.postProcessingEnabled = false;

    // 1. Set Skybox matching texturedquad.cpp (0.1, 0.125, 0.25, 1.0)
    final skybox = FilamentSkybox.createColor(
      engine: engine,
      r: 0.1,
      g: 0.125,
      b: 0.25,
    );
    _skybox = skybox;
    scene.setSkybox(skybox);

    // 2. Position Camera
    camera.lookAt(
      eyeX: 0.0,
      eyeY: 0.0,
      eyeZ: 3.0,
      centerX: 0.0,
      centerY: 0.0,
      centerZ: 0.0,
      upX: 0.0,
      upY: 1.0,
      upZ: 0.0,
    );

    // 3. Create 2D Checkerboard Texture (128x128 RGBA8)
    const int texSize = 128;
    final pixels = Uint8List(texSize * texSize * 4);
    for (int y = 0; y < texSize; y++) {
      for (int x = 0; x < texSize; x++) {
        final int index = (y * texSize + x) * 4;
        final bool isCheck = ((x ~/ 16) + (y ~/ 16)) % 2 == 0;
        pixels[index] = isCheck ? 230 : 50;     // R
        pixels[index + 1] = isCheck ? 150 : 120; // G
        pixels[index + 2] = isCheck ? 50 : 220;  // B
        pixels[index + 3] = 255;                // A
      }
    }

    final texture = FilamentTexture.create2D(
      engine: engine,
      width: texSize,
      height: texSize,
      format: TextureFormat.rgba8,
    );
    texture.setImage(width: texSize, height: texSize, pixelData: pixels);
    _texture = texture;

    // 4. Create Quad Geometry (Position 2D + UV0)
    final byteData = ByteData(64); // 4 vertices * 16 bytes
    final quadData = [
      -1.0, -1.0, 0.0, 0.0,
       1.0, -1.0, 1.0, 0.0,
      -1.0,  1.0, 0.0, 1.0,
       1.0,  1.0, 1.0, 1.0,
    ];
    for (int i = 0; i < quadData.length; i++) {
      byteData.setFloat32(i * 4, quadData[i], Endian.host);
    }

    final vertices = byteData.buffer.asFloat32List();
    final indices = Uint16List.fromList([0, 1, 2, 3, 2, 1]);

    final vb = FilamentVertexBuffer.create(
      engine: engine,
      vertexCount: 4,
      bufferCount: 1,
      withUv: true,
    );
    vb.setData(vertices, bufferIndex: 0);
    _vb = vb;

    final ib = FilamentIndexBuffer.create(
      engine: engine,
      indexCount: 6,
      type: IndexType.ushort,
    );
    ib.setUint16Data(indices);
    _ib = ib;

    // 5. Compile Textured Material
    FilamentMaterialBuilder.initEngine();
    final materialBuilder = FilamentMaterialBuilder.create();
    materialBuilder.setShading(FilamatShading.unlit);
    materialBuilder.setName('TexturedQuadMaterial');
    materialBuilder.requireAttribute(0); // POSITION
    materialBuilder.requireAttribute(4); // UV0
    materialBuilder.addSamplerParameter('albedo', samplerType: 0);
    materialBuilder.setCode('''
void material(inout MaterialInputs material) {
    prepareMaterial(material);
    material.baseColor = texture(materialParams_albedo, getUV0());
}
''');
    final materialBuffer = materialBuilder.build();
    materialBuilder.dispose();

    if (materialBuffer != null) {
      final material = FilamentMaterial.fromBuffer(
        engine: engine,
        filamatBuffer: materialBuffer,
      );
      _material = material;

      final instance = material.createInstance();
      _instance = instance;
      instance.setTexture('albedo', texture.nativePointer);

      final entity = engine.createEntity();
      _entity = entity;

      final renderableManager = FilamentRenderableManager(engine);
      renderableManager.createRenderable(
        entity: entity,
        vertexBuffer: vb,
        indexBuffer: ib,
        materialInstance: instance,
        count: 6,
        primitiveType: PrimitiveType.triangles,
      );

      scene.addEntity(entity);
    }

    // 6. Camera Zoom Animation matching texturedquad.cpp
    _timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) return;
      _now += 0.016;

      const double aspect = 800.0 / 600.0;
      final double zoom = 2.0 + 2.0 * sin(_now);

      camera.setProjectionOrtho(
        left: -aspect * zoom,
        right: aspect * zoom,
        bottom: -zoom,
        top: zoom,
        near: -1.0,
        far: 1.0,
      );

      if (mounted) {
        setState(() {
          _info = 'Textured Quad 3D Scene Running (texturedquad.cpp)\n'
              'Texture: 128x128 RGBA8 Checkerboard\n'
              'Zoom Factor: ${zoom.toStringAsFixed(2)}\n'
              'Time: ${_now.toStringAsFixed(2)}s';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Textured Quad Sample (texturedquad.cpp)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const Icon(Icons.texture, color: Colors.teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sample: texturedquad.cpp\n'
                        'Renders a 2D Textured Quad with 2D texture pixel upload, sampler2D material shader, and looping zoom projection animation.',
                        style: TextStyle(color: Colors.grey.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FilamentWidget(
                  height: 500,
                  onSceneCreated: _setup3dScene,
                  onDispose: _cleanupResources,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _info,
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
