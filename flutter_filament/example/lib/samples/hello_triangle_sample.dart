import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_filament/flutter_filament.dart';

class HelloTriangleSample extends StatefulWidget {
  const HelloTriangleSample({super.key});

  @override
  State<HelloTriangleSample> createState() => _HelloTriangleSampleState();
}

class _HelloTriangleSampleState extends State<HelloTriangleSample> {
  String _info = 'Initializing Hello Triangle 3D scene...';
  FilamentEngine? _engine;
  FilamentScene? _scene;
  int? _entity;
  FilamentSkybox? _skybox;
  FilamentMaterial? _material;
  FilamentMaterialInstance? _instance;
  FilamentVertexBuffer? _vb;
  FilamentIndexBuffer? _ib;

  void _cleanupResources() {
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

    // 0. Set Skybox matching hellotriangle.cpp (0.1, 0.125, 0.25, 1.0)
    final skybox = FilamentSkybox.createColor(
      engine: engine,
      r: 0.1,
      g: 0.125,
      b: 0.25,
    );
    _skybox = skybox;
    scene.setSkybox(skybox);
    // 1. Initialize Filamat Material Compiler Engine
    FilamentMaterialBuilder.initEngine();

    // 2. Position Camera (Eye: (0,0,3), Target: (0,0,0), Up: (0,1,0))
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

    const double zoom = 1.5;
    const double aspect = 800.0 / 600.0;
    camera.setProjectionOrtho(
      left: -aspect * zoom,
      right: aspect * zoom,
      bottom: -zoom,
      top: zoom,
      near: 0.1,
      far: 100.0,
    );

    // 3. Create 3D Triangle Vertices (Position + Vertex Colors matching Filament hellotriangle.cpp)
    final double v1x = math.cos(math.pi * 2.0 / 3.0);
    final double v1y = math.sin(math.pi * 2.0 / 3.0);
    final double v2x = math.cos(math.pi * 4.0 / 3.0);
    final double v2y = math.sin(math.pi * 4.0 / 3.0);

    final byteData = ByteData(48); // 3 vertices * 16 bytes
    // Vertex 0: Position (1.0, 0.0, 0.0), Color Red (255, 0, 0, 255)
    byteData.setFloat32(0, 1.0, Endian.host);
    byteData.setFloat32(4, 0.0, Endian.host);
    byteData.setFloat32(8, 0.0, Endian.host);
    byteData.setUint8(12, 255);
    byteData.setUint8(13, 0);
    byteData.setUint8(14, 0);
    byteData.setUint8(15, 255);

    // Vertex 1: Position (v1x, v1y, 0.0), Color Green (0, 255, 0, 255)
    byteData.setFloat32(16, v1x, Endian.host);
    byteData.setFloat32(20, v1y, Endian.host);
    byteData.setFloat32(24, 0.0, Endian.host);
    byteData.setUint8(28, 0);
    byteData.setUint8(29, 255);
    byteData.setUint8(30, 0);
    byteData.setUint8(31, 255);

    // Vertex 2: Position (v2x, v2y, 0.0), Color Blue (0, 0, 255, 255)
    byteData.setFloat32(32, v2x, Endian.host);
    byteData.setFloat32(36, v2y, Endian.host);
    byteData.setFloat32(40, 0.0, Endian.host);
    byteData.setUint8(44, 0);
    byteData.setUint8(45, 0);
    byteData.setUint8(46, 255);
    byteData.setUint8(47, 255);

    final vertices = byteData.buffer.asFloat32List();
    final indices = Uint16List.fromList([0, 1, 2]);

    final vb = FilamentVertexBuffer.create(
      engine: engine,
      vertexCount: 3,
      bufferCount: 1,
      withColor: true,
    );
    vb.setData(vertices, bufferIndex: 0);
    _vb = vb;

    final ib = FilamentIndexBuffer.create(
      engine: engine,
      indexCount: 3,
      type: IndexType.ushort,
    );
    ib.setUint16Data(indices);
    _ib = ib;

    // 4. Create 3D Triangle Entity & Unlit Material Shader
    final entity = engine.createEntity();
    _entity = entity;

    final materialBuilder = FilamentMaterialBuilder.create();
    materialBuilder.setShading(FilamatShading.unlit);
    materialBuilder.setName('TriangleUnlitMaterial');
    materialBuilder.requireAttribute(2); // VertexAttribute::COLOR
    materialBuilder.setCode('''
void material(inout MaterialInputs material) {
    prepareMaterial(material);
    material.baseColor = getColor();
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

      final renderableManager = FilamentRenderableManager(engine);
      renderableManager.createRenderable(
        entity: entity,
        vertexBuffer: vb,
        indexBuffer: ib,
        materialInstance: instance,
        count: 3,
        primitiveType: PrimitiveType.triangles,
      );

      scene.addEntity(entity);
    } else {
      debugPrint('[Material Build Failed]: materialBuffer is null!');
    }

    setState(() {
      _info = 'Hello Triangle 3D Scene Running!\n'
          'Engine Pointer: 0x${engine.nativePointer.address.toRadixString(16)}\n'
          'Camera Position: eye(0,0,3), target(0,0,0)\n'
          '3D Vertices: 3 points, Indices: 3 elements\n'
          'Scene Entity Count: ${scene.entityCount}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hello Triangle Sample (hellotriangle.cpp)'),
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
                    const Icon(Icons.info_outline, color: Colors.deepOrange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sample: hellotriangle.cpp\n'
                        'Renders a 3D geometry using FilamentVertexBuffer, FilamentIndexBuffer, and FilamentWidget viewport.',
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
                  height: 600,
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
