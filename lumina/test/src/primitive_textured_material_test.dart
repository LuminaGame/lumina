// A textured material assigned to a basic shape (a `Primitive` actor's
// Material) draws its texture across the shape, not one texel's colour: the
// shape's generated glTF carries texture coordinates and tangents.
//
// The test imports a real textured GLB from test-assets, compiles its
// material with matc as the Material Editor does, assigns it to a box, a
// sphere and a cylinder, and renders real frames on the default backend to
// read the texture back.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

Directory get _assets => Directory(Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final barrelGlb = File('${_assets.path}/Props/Barrels/fuel_barrel_red.glb');
  final haveAssets = barrelGlb.existsSync();
  late Directory project;
  late String material;

  setUpAll(() async {
    if (!haveAssets) return;
    project = Directory.systemTemp.createTempSync('lumina_primitive_texture_');
    File('${project.path}/P.lmproject').writeAsStringSync(jsonEncode(const LuminaProject(projectName: 'P').toMap()));
    await AssetRepository().importExternalFile(projectPath: project.path, sourceFilePath: barrelGlb.path);
    // Compile the imported material with matc and store the package, as the
    // Material Editor's Compile + Save does.
    for (final f in Directory('${project.path}/contents').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.lmas')) continue;
      final asset = LuminaAsset.fromBytes(f.readAsBytesSync());
      if (asset.type != AssetType.filamat || !asset.references.any((r) => r.slotName == 'baseColorMap')) continue;
      final result = FilamentMatc.compile(asset.rawMatSource, fileName: '${asset.name}.mat', defaultName: asset.name);
      expect(result.ok, isTrue, reason: result.log);
      f.writeAsBytesSync(LuminaAsset(
        assetId: asset.assetId,
        name: asset.name,
        type: asset.type,
        rawPayload: result.package,
        rawMatSource: asset.rawMatSource,
        references: asset.references,
        metadata: asset.metadata,
      ).toProtoBufferBytes());
      material = f.path.replaceAll(r'\', '/').substring(project.path.replaceAll(r'\', '/').length + 1);
    }
  });

  tearDownAll(() {
    if (haveAssets && project.existsSync()) project.deleteSync(recursive: true);
  });

  const width = 96;
  const height = 96;

  late FilamentEngine engine;
  late FilamentScene scene;
  late FilamentView view;
  late int cameraEntity;
  late FilamentCamera camera;
  late FilamentRenderer renderer;
  late FilamentSwapChain swapChain;
  late LuminaWorld world;

  setUp(() {
    if (!haveAssets) return;
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
    // 2 m in front of the shape's +Z side, which faces the camera.
    camera.setProjection(fovDegrees: 60.0, aspect: 1.0, near: 1.0, far: 1000.0, direction: FovDirection.vertical);
    camera.lookAt(eyeX: 0.0, eyeY: 0.0, eyeZ: 200.0, centerX: 0.0, centerY: 0.0, centerZ: 0.0);
    renderer.setClearOptions(r: 0.0, g: 0.0, b: 0.0, a: 1.0);
    world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
    world.persistentLevel.registerActor(LuminaActor(
      root: LuminaDirectionalLightComponent(color: Vector3(1.0, 1.0, 1.0), intensity: 100000.0, castShadows: false),
    ));
    LuminaAssets.projectDir = project.path;
  });

  tearDown(() {
    if (!haveAssets) return;
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

  /// Renders a few frames and returns a 7 × 7 grid of RGB samples over the
  /// middle of the frame, where the shape's front is.
  List<List<int>> renderGrid() {
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
    return [
      for (var gy = 0; gy < 7; gy++)
        for (var gx = 0; gx < 7; gx++)
          () {
            final o = ((36 + gy * 4) * width + 36 + gx * 4) * 4;
            return [pixels[o], pixels[o + 1], pixels[o + 2]];
          }(),
    ];
  }

  double spread(List<List<int>> samples) {
    final l = [for (final s in samples) 0.2126 * s[0] + 0.7152 * s[1] + 0.0722 * s[2]];
    final mean = l.reduce((a, b) => a + b) / l.length;
    return math.sqrt(l.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / l.length);
  }

  for (final shape in [LuminaPrimitiveShape.box, LuminaPrimitiveShape.sphere, LuminaPrimitiveShape.cylinder]) {
    test('a textured material on a ${shape.name} draws its texture, not one texel colour', () async {
      if (!haveAssets) return markTestSkipped('test-assets missing');
      final actor = LuminaPrimitiveActor(
        shape: shape,
        size: Vector3.all(100.0),
        color: Vector3.all(0.6),
        materialOverrideAsset: material,
      );
      world.persistentLevel.registerActor(actor);
      world.beginPlay();
      await actor.meshComponent.loaded;
      for (var i = 0; i < 200 && actor.meshComponent.materialOverride() == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(actor.meshComponent.materialOverride(), isNotNull, reason: 'the assigned material is drawn');
      final grid = renderGrid();
      expect(grid.every((s) => s[0] + s[1] + s[2] > 30), isTrue, reason: 'the ${shape.name} is lit and in frame: $grid');
      expect(spread(grid), greaterThan(6), reason: 'the texture shows across the ${shape.name}, not one flat colour: $grid');
    });
  }
}
