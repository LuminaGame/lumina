import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// Every gltfio ubershader variant requires `uv1`, which a
/// procedural section could not declare. Filament warned
/// `missing required attributes` for each section it built (per entity, per
/// rebuild: particles rebuild every frame), and on Vulkan the undeclared
/// attribute is read from the position bytes.
///
/// These tests render real frames on the default backend and read them back.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
  late FilamentMaterialProvider provider;
  final materials = <FilamentMaterialInstance>[];
  final warnings = <String>[];
  StreamSubscription<FilamentLogRecord>? logs;

  setUp(() {
    warnings.clear();
    FilamentDiagnostics.installLogHandler();
    logs = FilamentDiagnostics.onLog.listen((r) {
      if (r.message.contains('missing required attributes')) warnings.add(r.message.trim());
    });

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
    camera.setProjection(fovDegrees: 60.0, aspect: 1.0, near: 0.1, far: 100.0, direction: FovDirection.vertical);
    camera.lookAt(eyeX: 0.0, eyeY: 0.0, eyeZ: 3.0, centerX: 0.0, centerY: 0.0, centerZ: 0.0);
    // A blue background, so a drawn (red) quad and an empty frame differ.
    renderer.setClearOptions(r: 0.0, g: 0.2, b: 0.8, a: 1.0);

    world = LuminaWorld(worldType: LuminaWorldType.game);
    world.initializeNativeContext(engine, scene);
    provider = FilamentMaterialProvider.ubershader(engine);
  });

  tearDown(() async {
    world.cleanup();
    for (final mi in materials) {
      mi.dispose();
    }
    materials.clear();
    provider.dispose();
    view.dispose();
    scene.dispose();
    engine.destroyEntity(cameraEntity);
    camera.dispose();
    renderer.dispose();
    swapChain.dispose();
    engine.dispose();
    await logs?.cancel();
    FilamentDiagnostics.clearLogHandler();
  });

  FilamentMaterialInstance ubershader({required bool unlit}) {
    final mi = provider
        .createMaterialInstance(
          MaterialKey(unlit: unlit, alphaMode: 2, doubleSided: true, hasVertexColors: true),
          label: unlit ? 'bugs05_unlit' : 'bugs05_lit',
        )
        .instance!;
    mi.setFloat4('baseColorFactor', 1.0, 1.0, 1.0, 1.0);
    materials.add(mi);
    return mi;
  }

  /// A 2 × 2 quad at the origin facing the camera (+Z): positions, normals,
  /// uv0, opaque red vertex colours and indices — the bug's repro.
  LuminaProceduralMeshComponent redQuad(FilamentMaterialInstance mi) {
    final mesh = LuminaProceduralMeshComponent();
    world.persistentLevel.registerActor(LuminaActor()..addComponent(mesh));
    mesh.createMeshSection(
      0,
      positions: Float32List.fromList([-1, -1, 0, 1, -1, 0, 1, 1, 0, -1, 1, 0]),
      normals: Float32List.fromList([0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1]),
      uv0: Float32List.fromList([0, 0, 1, 0, 1, 1, 0, 1]),
      colors: Uint8List.fromList([255, 0, 0, 255, 255, 0, 0, 255, 255, 0, 0, 255, 255, 0, 0, 255]),
      indices: Uint32List.fromList([0, 1, 2, 0, 2, 3]),
      material: mi,
    );
    return mesh;
  }

  /// Renders a frame and returns the RGBA of pixel (28, 48): inside the quad
  /// (it covers roughly x, y ∈ [20, 76]) and away from the lit variant's
  /// specular highlight at the centre (the light shines along the view).
  List<int> renderQuadPixel() {
    final pixels = Uint8List(width * height * 4);
    for (var i = 0; i < 3; i++) {
      if (renderer.beginFrame(swapChain)) {
        renderer.render(view);
        renderer.readPixels(x: 0, y: 0, width: width, height: height, outPixels: pixels);
        renderer.endFrame();
      }
      engine.flushAndWait();
    }
    final o = (48 * width + 28) * 4;
    return pixels.sublist(o, o + 4);
  }

  /// The warnings Filament logged so far (delivered through the event loop).
  Future<List<String>> loggedWarnings() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List.of(warnings);
  }

  test('an unlit ubershader section declares every attribute the material requires', () async {
    redQuad(ubershader(unlit: true));
    final pixel = renderQuadPixel();

    expect(await loggedWarnings(), isEmpty, reason: 'the section must declare uv1 as well as position, colour and uv0');
    expect(pixel[0], greaterThan(200), reason: 'the unlit quad draws its red vertex colour, got $pixel');
    expect(pixel[2], lessThan(60), reason: 'and hides the blue background, got $pixel');
  });

  test('a lit ubershader section draws, and declares every attribute the material requires', () async {
    world.persistentLevel.registerActor(LuminaActor(
      root: LuminaDirectionalLightComponent(color: Vector3(1.0, 1.0, 1.0), intensity: 100000.0, castShadows: false),
    ));
    redQuad(ubershader(unlit: false));
    world.beginPlay();
    world.tick(1 / 60);
    final pixel = renderQuadPixel();

    expect(await loggedWarnings(), isEmpty, reason: 'the lit variant requires position, tangents, colour, uv0 and uv1');
    expect(pixel[0], greaterThan(150), reason: 'the lit quad is drawn in its red vertex colour, got $pixel');
    expect(pixel[1], lessThan(60), reason: 'red, not a washed-out or garbage colour, got $pixel');
    expect(pixel[2], lessThan(60), reason: 'and hides the blue background, got $pixel');
  });

  test('an explicit uv1 is stored alongside uv0; without one uv1 reads uv0', () {
    final withAlias = redQuad(ubershader(unlit: true));
    final explicit = LuminaProceduralMeshComponent();
    world.persistentLevel.registerActor(LuminaActor()..addComponent(explicit));
    explicit.createMeshSection(
      0,
      positions: Float32List.fromList([0, 0, 0, 1, 0, 0, 0, 1, 0]),
      uv0: Float32List.fromList([0, 0, 1, 0, 0, 1]),
      uv1: Float32List.fromList([0.5, 0.5, 0.75, 0.5, 0.5, 0.75]),
      indices: Uint32List.fromList([0, 1, 2]),
      generateTangents: false,
    );

    // pos 12 + tangents 8 + uv0 8 + colour 4: the default uv1 adds no bytes.
    expect(withAlias.getSectionStride(0), 32);
    // pos 12 + uv0 8 + uv1 8.
    expect(explicit.getSectionStride(0), 28);
    expect(() => explicit.createMeshSection(
          1,
          positions: Float32List.fromList([0, 0, 0, 1, 0, 0, 0, 1, 0]),
          uv1: Float32List.fromList([0, 0, 1, 0]),
          indices: Uint32List.fromList([0, 1, 2]),
        ), throwsArgumentError);
  });
}
