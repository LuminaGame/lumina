// A material built in the Material Editor's node graph samples its texture
// upright on a Lumina mesh: a Texture Sample of a four-quadrant image wired
// into Base Color, compiled with matc, draws the image's top-left quadrant on
// the top-left corner of a glTF quad (glTF texture coordinates, v = 0 at the
// image top), whether the material started from the editor's new-material
// template or from an empty source (what Content Browser ▸ New wrote before
// it used the template).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina/testing.dart' show TextureOrientationFixture, TextureQuadrant;
import 'package:lumina_ui/ui/features/sub_editors/models/material_graph.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late String quadMesh;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_graph_uv_');
    File('${root.path}/P.lmproject').writeAsStringSync(jsonEncode(const LuminaProject(projectName: 'P').toMap()));
    Directory('${root.path}/contents').createSync();
    final src = Directory('${root.path}/src')..createSync();
    final quad = TextureOrientationFixture.writeGltfQuad('${src.path}/quad_gltf.glb', TextureOrientationFixture.quadrantsPng());
    await AssetRepository().importExternalFile(projectPath: root.path, sourceFilePath: quad);
    quadMesh = 'contents/meshes/static/quad_gltf.entity.glb';
    expect(File('${root.path}/$quadMesh').existsSync(), isTrue);
  });

  tearDownAll(() => root.deleteSync(recursive: true));

  const width = 128;
  const height = 128;

  late FilamentEngine engine;
  late FilamentScene scene;
  late FilamentView view;
  late int cameraEntity;
  late FilamentCamera camera;
  late FilamentRenderer renderer;
  late FilamentSwapChain swapChain;
  late LuminaWorld world;

  setUp(() {
    engine = FilamentEngine.create()!;
    scene = engine.createScene();
    view = engine.createView();
    cameraEntity = engine.createEntity();
    camera = engine.createCamera(cameraEntity);
    renderer = engine.createRenderer();
    swapChain = engine.createHeadlessSwapChain(width, height);
    view.scene = scene;
    view.camera = camera;
    view.setViewport(0, 0, width, height);
    renderer.setClearOptions(r: 0.0, g: 0.0, b: 0.0, a: 1.0);
    world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
    // Travels along -Z: straight onto the quad's front.
    world.persistentLevel.registerActor(LuminaActor(
      root: LuminaDirectionalLightComponent(color: Vector3(1.0, 1.0, 1.0), intensity: 100000.0, castShadows: false),
    ));
    LuminaAssets.projectDir = root.path;
  });

  tearDown(() {
    LuminaAssets.projectDir = null;
    world.cleanup();
    view.dispose();
    scene.dispose();
    engine.destroyEntity(cameraEntity);
    camera.dispose();
    renderer.dispose();
    swapChain.dispose();
    engine.dispose();
  });

  /// Opens [material] in the Material Editor, wires a Texture Sample of the
  /// quadrant texture into Base Color, compiles and saves it, as the user
  /// does.
  Future<String> buildInGraph(String material) async {
    final vm = MaterialEditorViewModel(assetPath: '${root.path}/$material');
    addTearDown(vm.dispose);
    await vm.load();
    final graph = vm.graph..ensureSynced();
    final editor = graph.editor;
    // An empty source reads as one Custom (Fragment) node; the user deletes
    // it to build the material from nodes.
    editor.removeNodes({for (final n in graph.graph.nodes) if (n.registryId == MaterialNodes.customFragment) n.id});
    final sample = editor.addNode(MaterialNodes.textureSample, const Offset(-400, 0))!;
    expect(
        editor.addWire(fromNodeId: sample.id, fromPinId: 'rgba', toNodeId: MaterialNodes.outputNodeId, toPinId: MaterialNodes.baseColor),
        isNotNull);
    // Metallic 0 and roughness 1, so the directional light shows the colours.
    for (final (pin, value) in [(MaterialNodes.metallic, 0.0), (MaterialNodes.roughness, 1.0)]) {
      final k = editor.addNode(MaterialNodes.constant, const Offset(-400, 200), literals: {'value': value})!;
      expect(editor.addWire(fromNodeId: k.id, fromPinId: 'out', toNodeId: MaterialNodes.outputNodeId, toPinId: pin), isNotNull);
    }
    final texture = vm.availableTextures.singleWhere((t) => t.fileName.toLowerCase().contains('quadrants'));
    expect(graph.bindTexture(sample.literals['parameter'] as String, texture), isTrue);
    expect(graph.isAhead, isFalse, reason: '${graph.issues.map((i) => i.message)}');
    expect(await vm.compile(), isTrue, reason: '${vm.issues.map((i) => i.message)}\n${vm.currentCode}');
    expect(await vm.save(), isTrue);
    return vm.currentCode;
  }

  /// Draws the quad with [material] and returns the quadrant colour found at
  /// each corner of the quad on screen.
  Future<Map<TextureQuadrant, TextureQuadrant?>> drawnCorners(String material) async {
    final actor = LuminaStaticMeshActor(meshAssetPath: quadMesh, materialOverrideAsset: material);
    world.persistentLevel.registerActor(actor);
    world.beginPlay();
    await actor.meshComponent.loaded.timeout(const Duration(seconds: 20));
    for (var i = 0; i < 500 && actor.meshComponent.materialOverride() == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(actor.meshComponent.materialOverride(), isNotNull, reason: 'the compiled material is drawn');
    final bounds = actor.meshComponent.localBounds!;
    final centre = bounds.center;
    final size = bounds.max.y - bounds.min.y;
    // Aim below and left of the quad, so it lands in the upper right of the
    // frame: that tells which read-back rows and columns are up and right.
    final target = centre - Vector3(size * 0.3, size * 0.3, 0);
    camera.setProjection(fovDegrees: 60.0, aspect: 1.0, near: size * 0.05, far: size * 20, direction: FovDirection.vertical);
    camera.lookAt(
      eyeX: target.x, eyeY: target.y, eyeZ: centre.z + size * 2.2,
      centerX: target.x, centerY: target.y, centerZ: centre.z,
    );
    world.tick(1 / 60);
    final pixels = Uint8List(width * height * 4);
    for (var i = 0; i < 4; i++) {
      if (renderer.beginFrame(swapChain)) {
        renderer.render(view);
        renderer.readPixels(x: 0, y: 0, width: width, height: height, outPixels: pixels);
        renderer.endFrame();
      }
      engine.flushAndWait();
    }
    final corners = TextureOrientationFixture.quadCorners(pixels, width, height);
    expect(corners, isNotNull, reason: 'the quad is lit and in frame');
    return corners!;
  }

  test('a Texture Sample built on the new-material template draws the texture upright', () async {
    const material = 'contents/materials/M_GraphTemplate.lmas';
    final source = await buildInGraph(material);
    expect(await drawnCorners(material), TextureOrientationFixture.upright, reason: source);
  });

  test('a Texture Sample built on an empty-source material draws the texture upright', () async {
    await AssetRepository().createAsset(
        projectPath: root.path, subFolder: 'materials', fileName: 'M_GraphNew.lmas', type: AssetType.filamat);
    const material = 'contents/materials/M_GraphNew.lmas';
    expect(LuminaAsset.fromBytes(File('${root.path}/$material').readAsBytesSync()).rawMatSource, isEmpty);
    final source = await buildInGraph(material);
    expect(await drawnCorners(material), TextureOrientationFixture.upright, reason: source);
  });
}
