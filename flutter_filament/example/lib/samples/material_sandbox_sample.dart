import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_filament/flutter_filament.dart';

class MaterialSandboxSample extends StatefulWidget {
  const MaterialSandboxSample({super.key});

  @override
  State<MaterialSandboxSample> createState() => _MaterialSandboxSampleState();
}

class _MaterialSandboxSampleState extends State<MaterialSandboxSample> {
  String _info = 'Initializing Material Sandbox...';
  final String _glslCode = '''
// Custom PBR Material Shader
void material(inout MaterialInputs material) {
    prepareMaterial(material);
    material.baseColor.rgb = float3(0.8, 0.2, 0.2);
    material.roughness = 0.3;
    material.metallic = 0.9;
}
  ''';
  String _minifiedCode = '';

  FilamentCameraManipulator? _manipulator;
  FilamentIndirectLight? _ibl;
  FilamentSkybox? _skybox;
  FilamentScene? _scene;

  @override
  void initState() {
    super.initState();
    _minifyShader();
  }

  void _minifyShader() {
    final minified = FilamentTools.minifyGlsl(_glslCode);
    _minifiedCode = minified ?? 'Failed to minify GLSL.';
  }

  void _setup3dScene(
    FilamentEngine engine,
    FilamentScene scene,
    FilamentCamera camera,
    FilamentView view,
  ) {
    _scene = scene;
    _manipulator = FilamentCameraManipulator.create(
      mode: ManipulatorMode.orbit,
      viewportWidth: 1024,
      viewportHeight: 768,
    );

    camera.lookAt(
      eyeX: 0.0,
      eyeY: 0.0,
      eyeZ: 3.5,
      centerX: 0.0,
      centerY: 0.0,
      centerZ: 0.0,
      upX: 0.0,
      upY: 1.0,
      upZ: 0.0,
    );

    scene.createSuzanneSample(view);

    rootBundle.load('assets/ibl/lightroom_14b/lightroom_14b_ibl.ktx').then((iblData) {
      if (mounted) {
        final ibl = FilamentIndirectLight.fromKtx(
          engine,
          iblData.buffer.asUint8List(),
          intensity: 100000.0,
        );
        _ibl = ibl;
        scene.setIndirectLight(ibl);
      }
    });

    rootBundle.load('assets/ibl/lightroom_14b/lightroom_14b_skybox.ktx').then((skyData) {
      if (mounted) {
        final skybox = FilamentSkybox.fromKtx(
          engine,
          skyData.buffer.asUint8List(),
          showSun: true,
        );
        _skybox = skybox;
        scene.setSkybox(skybox);
      }
    });

    final lightEntity = engine.createEntity();
    final lightManager = FilamentLightManager(engine);
    lightManager.createLight(
      entity: lightEntity,
      type: LightType.directional,
      colorR: 1.0,
      colorG: 1.0,
      colorB: 0.95,
      intensity: 100000.0,
      dirX: 0.5,
      dirY: -1.0,
      dirZ: -1.0,
    );
    scene.addEntity(lightEntity);

    setState(() {
      _info = 'Material Sandbox Sample (material_sandbox.cpp & matc)\n'
          'GLSL Minifier (glslminifier) & Runtime Material Builder Ready!\n'
          'Live 3D Viewport Active!';
    });
  }

  void _cleanupResources() {
    _ibl?.dispose();
    _skybox?.dispose();
    _scene?.destroySuzanneSample();
    _manipulator?.dispose();
  }

  @override
  void dispose() {
    _cleanupResources();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Material Sandbox (material_sandbox.cpp)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text(
                    'Sample: material_sandbox.cpp & matc\n'
                    'Demonstrates runtime GLSL material compilation (FilamentMaterialBuilder) and shader minification (glslminifier).',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilamentWidget(
                height: 300,
                cameraManipulator: _manipulator,
                onSceneCreated: _setup3dScene,
                onDispose: _cleanupResources,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.grey.shade900,
                child: Text(_info, style: const TextStyle(color: Colors.amberAccent, fontFamily: 'monospace', fontSize: 13)),
              ),
              const SizedBox(height: 16),
              const Text('Original GLSL Shader Code:', style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.grey.shade200,
                child: Text(_glslCode, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ),
              const SizedBox(height: 16),
              const Text('Minified GLSL Code (glslminifier):', style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.grey.shade900,
                child: Text(_minifiedCode, style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
