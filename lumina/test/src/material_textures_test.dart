// A material asset drawn at runtime (a level actor's material, a component's
// Material Override / Set Material, a mesh slot) draws with the textures its
// samplers name: the glTF import and the Material Editor record them in the
// asset's references (`slot_name` = sampler), and the material cache loads
// and binds them on every instance it creates.
//
// These tests import real textured GLBs from test-assets, compile the
// imported materials with matc as the Material Editor does, and render real
// frames on the default backend to read the texture back.
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
  // Base colour, metallic-roughness and normal maps.
  final pbrGlb = File('${_assets.path}/fixtures/YVO3D_44368.glb');
  final haveAssets = barrelGlb.existsSync() && pbrGlb.existsSync();
  late Directory project;

  /// Project-relative path of each imported material, by asset name.
  final materials = <String, String>{};

  /// Project-relative path of each imported texture, by asset name.
  final textures = <String, String>{};

  String relativeOf(File f) => f.path.replaceAll(r'\', '/').substring(project.path.replaceAll(r'\', '/').length + 1);

  LuminaAsset read(String relative) => LuminaAsset.fromBytes(File('${project.path}/$relative').readAsBytesSync());

  /// Writes a compiled material asset at [relative].
  void writeMaterial(String relative, String name, String source, List<AssetReference> references) {
    final result = FilamentMatc.compile(source, fileName: '$name.mat', defaultName: name);
    expect(result.ok, isTrue, reason: result.log);
    File('${project.path}/$relative')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(LuminaAsset(
        assetId: name,
        name: name,
        type: AssetType.filamat,
        rawPayload: result.package,
        rawMatSource: source,
        references: references,
      ).toProtoBufferBytes());
  }

  setUpAll(() async {
    if (!haveAssets) return;
    project = Directory.systemTemp.createTempSync('lumina_material_textures_');
    File('${project.path}/P.lmproject').writeAsStringSync(jsonEncode(const LuminaProject(projectName: 'P').toMap()));
    await AssetRepository().importExternalFile(projectPath: project.path, sourceFilePath: barrelGlb.path);
    await AssetRepository().importExternalFile(projectPath: project.path, sourceFilePath: pbrGlb.path);
    // Compile each imported material with matc and store the package, as the
    // Material Editor's Compile + Save does.
    for (final f in Directory('${project.path}/contents').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.lmas')) continue;
      final asset = LuminaAsset.fromBytes(f.readAsBytesSync());
      if (asset.type == AssetType.texture) textures[asset.name] = relativeOf(f);
      if (asset.type != AssetType.filamat) continue;
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
      materials[asset.name] = relativeOf(f);
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
    camera.setProjection(fovDegrees: 60.0, aspect: 1.0, near: 0.1, far: 100.0, direction: FovDirection.vertical);
    camera.lookAt(eyeX: 0.0, eyeY: 0.0, eyeZ: 2.0, centerX: 0.0, centerY: 0.0, centerZ: 0.0);
    renderer.setClearOptions(r: 0.0, g: 0.0, b: 0.0, a: 1.0);
    world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
    world.persistentLevel.registerActor(LuminaActor(
      root: LuminaDirectionalLightComponent(color: Vector3(1.0, 1.0, 1.0), intensity: 100000.0, castShadows: false),
    ));
    // The editor and PIE read `contents/…` against the open project.
    LuminaAssets.projectDir = project.path;
  });

  tearDown(() {
    if (!haveAssets) return;
    LuminaAssets.projectDir = null;
    LuminaAssets.defaultProvider = null;
    world.cleanup();
    view.dispose();
    scene.dispose();
    engine.destroyEntity(cameraEntity);
    camera.dispose();
    renderer.dispose();
    swapChain.dispose();
    engine.dispose();
  });

  /// A quad filling most of the frame, facing the camera, UVs 0..1.
  void quad(FilamentMaterialInstance mi) {
    final mesh = LuminaProceduralMeshComponent();
    world.persistentLevel.registerActor(LuminaActor()..addComponent(mesh));
    mesh.createMeshSection(
      0,
      positions: Float32List.fromList([-1, -1, 0, 1, -1, 0, 1, 1, 0, -1, 1, 0]),
      normals: Float32List.fromList([0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1]),
      uv0: Float32List.fromList([0, 1, 1, 1, 1, 0, 0, 0]),
      indices: Uint32List.fromList([0, 1, 2, 0, 2, 3]),
      material: mi,
    );
  }

  /// Renders a few frames and returns an 8 × 8 grid of RGB samples inside
  /// the quad.
  List<List<int>> renderGrid() {
    world.beginPlay();
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
      for (var gy = 0; gy < 8; gy++)
        for (var gx = 0; gx < 8; gx++)
          () {
            final x = 30 + gx * 5;
            final y = 30 + gy * 5;
            final o = (y * width + x) * 4;
            return [pixels[o], pixels[o + 1], pixels[o + 2]];
          }(),
    ];
  }

  /// Standard deviation of the luminance of [samples].
  double spread(List<List<int>> samples) {
    final l = [for (final s in samples) 0.2126 * s[0] + 0.7152 * s[1] + 0.0722 * s[2]];
    final mean = l.reduce((a, b) => a + b) / l.length;
    return math.sqrt(l.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / l.length);
  }

  /// The imported material whose references name [slot].
  String materialWith(String slot) =>
      materials.values.firstWhere((m) => read(m).references.any((r) => r.slotName == slot));

  test('an imported material draws its base colour texture on every instance the cache creates', () async {
    if (!haveAssets) return markTestSkipped('test-assets missing');
    final path = materialWith('baseColorMap');
    final material = await LuminaMaterial.load(world, path);
    final base = material.textures.bound['baseColorMap'];
    expect(base, isNotNull, reason: 'the sampler the import recorded is bound');
    expect(base!.srgb, isTrue);
    expect(base.texture.format, TextureFormat.srgb8A8);
    expect(base.texture.levels, greaterThan(1), reason: 'mipmapped');
    expect(base.sampler.wrapS, SamplerWrapMode.repeat);
    expect(base.sampler.filterMin, SamplerMinFilter.linearMipmapNearest);
    expect(material.textures.missing, isEmpty);

    final instance = material.createInstance();
    quad(instance.nativeInstance);
    final grid = renderGrid();
    expect(grid.every((s) => s[0] + s[1] + s[2] > 30), isTrue, reason: 'the quad is lit, not a black unbound sampler: $grid');
    expect(spread(grid), greaterThan(6), reason: 'the texture shows, not one flat factor colour: $grid');
  });

  test('a dynamic instance of a textured material draws the texture too', () async {
    if (!haveAssets) return markTestSkipped('test-assets missing');
    final material = await LuminaMaterial.load(world, materialWith('baseColorMap'));
    // What a Blueprint's Create Dynamic Material Instance makes.
    final dynamicInstance = LuminaDynamicMaterialInstance.from(material.createInstance());
    quad(dynamicInstance.nativeInstance);
    final grid = renderGrid();
    expect(grid.every((s) => s[0] + s[1] + s[2] > 30), isTrue, reason: '$grid');
    expect(spread(grid), greaterThan(6), reason: '$grid');
  });

  test('colour maps are sRGB and data maps linear, each mipmapped', () async {
    if (!haveAssets) return markTestSkipped('test-assets missing');
    final material = await LuminaMaterial.load(world, materialWith('normalMap'));
    final bound = material.textures.bound;
    expect(bound.keys, containsAll(['baseColorMap', 'normalMap', 'metallicRoughnessMap']));
    expect(bound['baseColorMap']!.texture.format, TextureFormat.srgb8A8);
    expect(bound['normalMap']!.texture.format, TextureFormat.rgba8);
    expect(bound['normalMap']!.srgb, isFalse);
    expect(bound['metallicRoughnessMap']!.texture.format, TextureFormat.rgba8);
    expect(bound['normalMap']!.texture.width(), 2048);
    for (final t in bound.values) {
      expect(t.texture.levels, greaterThan(1));
    }
    quad(material.createInstance().nativeInstance);
    final grid = renderGrid();
    expect(spread(grid), greaterThan(6), reason: '$grid');
  });

  test('a sampler a user material declares draws the texture the Material Editor assigned', () async {
    if (!haveAssets) return markTestSkipped('test-assets missing');
    const source = '''
material {
  name : M_UserTextured,
  shadingModel : unlit,
  requires : [ uv0 ],
  parameters : [ { type : sampler2d, name : albedo } ]
}
fragment {
  void material(inout MaterialInputs material) {
    prepareMaterial(material);
    material.baseColor = texture(materialParams_albedo, getUV0());
  }
}
''';
    final texture = textures.values.first;
    // The Material Editor's texture slot: `slot_name` is the sampler.
    writeMaterial('contents/materials/M_UserTextured.lmas', 'M_UserTextured', source, [
      AssetReference(slotName: 'albedo', assetId: 'tex', assetPath: texture),
    ]);
    final material = await LuminaMaterial.load(world, 'contents/materials/M_UserTextured.lmas');
    expect(material.textures.bound['albedo']?.path, texture);
    expect(material.textures.bound['albedo']!.srgb, isTrue, reason: 'albedo is colour');
    quad(material.createInstance().nativeInstance);
    final grid = renderGrid();
    expect(grid.every((s) => s[0] + s[1] + s[2] > 30), isTrue, reason: '$grid');
    expect(spread(grid), greaterThan(6), reason: '$grid');
  });

  test('a built game reads the textures from its bundle, absolute project paths included', () async {
    if (!haveAssets) return markTestSkipped('test-assets missing');
    final imported = read(materialWith('baseColorMap'));
    // The Static Mesh editor and older assets store absolute paths.
    final absolute = [
      for (final r in imported.references)
        AssetReference(
          slotName: r.slotName,
          assetId: r.assetId,
          assetPath: '${project.path}\\${r.assetPath.replaceAll('/', r'\')}',
        ),
    ];
    writeMaterial('contents/materials/M_Absolute.lmas', 'M_Absolute', imported.rawMatSource, absolute);
    LuminaAssets.projectDir = null;
    LuminaAssets.defaultProvider = (path) async {
      if (!path.startsWith('contents/')) throw StateError('not in the bundle: $path');
      return File('${project.path}/$path').readAsBytes();
    };
    final material = await LuminaMaterial.load(world, 'contents/materials/M_Absolute.lmas');
    expect(material.textures.missing, isEmpty);
    expect(material.textures.bound['baseColorMap']?.path, startsWith('contents/'));
    quad(material.createInstance().nativeInstance);
    expect(spread(renderGrid()), greaterThan(6));
  });

  test('a missing texture binds nothing and the material still draws', () async {
    if (!haveAssets) return markTestSkipped('test-assets missing');
    final imported = read(materialWith('baseColorMap'));
    writeMaterial('contents/materials/M_Gone.lmas', 'M_Gone', imported.rawMatSource, const [
      AssetReference(slotName: 'baseColorMap', assetId: 'gone', assetPath: 'contents/textures/T_Gone.lmas'),
    ]);
    final material = await LuminaMaterial.load(world, 'contents/materials/M_Gone.lmas');
    expect(material.textures.bound, isEmpty);
    expect(material.textures.missing.keys, ['baseColorMap']);
    expect(material.textures.missing['baseColorMap'], contains('T_Gone'));
    quad(material.createInstance().nativeInstance);
    renderGrid();
  });

  test('materials naming the same texture share one upload, destroyed with the last of them', () async {
    if (!haveAssets) return markTestSkipped('test-assets missing');
    final imported = read(materialWith('baseColorMap'));
    writeMaterial('contents/materials/M_Copy.lmas', 'M_Copy', imported.rawMatSource, imported.references);
    final a = await LuminaMaterial.load(world, materialWith('baseColorMap'));
    final b = await LuminaMaterial.load(world, 'contents/materials/M_Copy.lmas');
    final texture = a.textures.bound['baseColorMap']!.texture;
    expect(identical(b.textures.bound['baseColorMap']!.texture, texture), isTrue);
    a.release();
    expect(texture.isDisposed, isFalse, reason: 'M_Copy still binds it');
    b.release();
    await Future<void>.delayed(Duration.zero);
    expect(texture.isDisposed, isTrue);
  });

  test("the level viewport's material override binds the textures on its instance", () async {
    if (!haveAssets) return markTestSkipped('test-assets missing');
    final path = materialWith('baseColorMap');
    final override = LuminaInstanceMaterialOverride.fromBytes(
      engine,
      path,
      File('${project.path}/$path').readAsBytesSync(),
      assetProvider: (p) => File('${project.path}/$p').readAsBytes(),
    );
    await override.texturesLoaded;
    final texture = override.textures.bound['baseColorMap']?.texture;
    expect(texture, isNotNull);
    quad(override.materialInstance);
    final grid = renderGrid();
    expect(grid.every((s) => s[0] + s[1] + s[2] > 30), isTrue, reason: '$grid');
    expect(spread(grid), greaterThan(6), reason: '$grid');
    world.cleanup();
    override.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(texture!.isDisposed, isTrue);
  });
}
