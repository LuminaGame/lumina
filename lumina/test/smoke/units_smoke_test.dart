import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';
import 'package:vector_math/vector_math_64.dart';

/// Units smoke: the centimetre world on a real GPU.
///
/// 1. A cm-scale scene: the 180 cm mannequin on a floor next to 100 cm crates.
/// 2. Parity: a room lit only by a point light renders as bright in cm
///    (through lumina) as the same room in metres (raw Filament).
/// 3. The Third Person template, authored Z-up in cm, mounted through the
///    same axis conversion the generated game uses, at human scale.
const _w = 640;
const _h = 360;

class _Frame {
  _Frame() {
    engine = FilamentEngine.create()!;
    scene = engine.createScene();
    view = engine.createView();
    renderer = engine.createRenderer();
    swapChain = engine.createHeadlessSwapChain(_w, _h);
    camera = engine.createCamera(engine.createEntity());
    view
      ..scene = scene
      ..camera = camera
      ..setViewport(0, 0, _w, _h);
  }

  late final FilamentEngine engine;
  late final FilamentScene scene;
  late final FilamentView view;
  late final FilamentRenderer renderer;
  late final FilamentSwapChain swapChain;
  late final FilamentCamera camera;
  final ffi.Pointer<ffi.Uint8> _pixels = calloc<ffi.Uint8>(_w * _h * 4);

  void project({required double near, required double far}) =>
      camera.setProjection(fovDegrees: 45, aspect: _w / _h, near: near, far: far, direction: FovDirection.vertical);

  void daylight() {
    scene.setSkybox(FilamentSkybox.build(engine, color: Vector4(0.35, 0.5, 0.75, 1), intensity: 30000));
    final sun = engine.createEntity();
    LightBuilder(LightType.directional)
        .color(1, 0.97, 0.92)
        .intensity(100000)
        .direction(-0.4, -0.8, -0.5)
        .castShadows(true)
        .build(engine, sun);
    scene.addEntity(sun);
    scene.setIndirectLight(FilamentIndirectLight.build(
      engine,
      irradiance: SphericalHarmonics(bands: 1, coefficients: [0.6, 0.65, 0.7]),
      intensity: 30000,
    ));
  }

  Uint8List capture() {
    for (var i = 0; i < 3; i++) {
      if (renderer.beginFrame(swapChain)) {
        renderer.render(view);
        if (i == 2) {
          c.filament_renderer_read_pixels(renderer.nativePointer, engine.nativePointer, 0, 0, _w, _h, _pixels.cast(), ffi.nullptr, ffi.nullptr);
        }
        renderer.endFrame();
      }
      engine.flushAndWait();
    }
    return Uint8List.fromList(_pixels.asTypedList(_w * _h * 4));
  }

  void dispose() {
    calloc.free(_pixels);
    engine.dispose();
  }
}

/// Mean luminance (0–255) of the pixel rectangle [l,t)-[r,b) of an RGBA frame.
double _meanLuma(Uint8List rgba, int l, int t, int r, int b) {
  var sum = 0.0;
  var n = 0;
  for (var y = t; y < b; y++) {
    for (var x = l; x < r; x++) {
      final i = (y * _w + x) * 4;
      sum += 0.2126 * rgba[i] + 0.7152 * rgba[i + 1] + 0.0722 * rgba[i + 2];
      n++;
    }
  }
  return sum / n;
}

Future<Uint8List> _mannequin(String _) => File(LuminaThirdPersonContent.bundledMeshPath).readAsBytes();

double _worldHeight(LuminaStaticMeshComponent mesh) {
  final b = mesh.localBounds!;
  final scale = mesh.worldTransform.getMaxScaleOnAxis();
  return (b.max.y - b.min.y) * scale;
}

void main() {
  test('units: centimetre runtime scene', () async {
    final f = _Frame();
    addTearDown(f.dispose);
    f.daylight();
    f.project(near: 10, far: 100000);
    // The boom camera of the Third Person character: 350 cm behind, at shoulder height.
    f.camera.lookAt(eyeX: 0, eyeY: 160, eyeZ: 450, centerX: 0, centerY: 90, centerZ: 0);

    final world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(f.engine, f.scene);
    addTearDown(world.cleanup);
    final floor = LuminaPrimitiveActor(shape: LuminaPrimitiveShape.plane, size: Vector3(6000, 0, 6000), color: Vector3(0.37, 0.42, 0.36));
    final crates = [
      for (final x in [-120.0, 130.0])
        LuminaPrimitiveActor(shape: LuminaPrimitiveShape.box, size: Vector3.all(100), color: Vector3(0.69, 0.48, 0.27), location: Vector3(x, 50, -60)),
    ];
    final mannequin = LuminaStaticMeshComponent(meshAssetPath: 'mannequin.glb', assetProvider: _mannequin);
    for (final a in [floor, ...crates, LuminaActor(root: mannequin)]) {
      world.persistentLevel.registerActor(a);
    }
    world.beginPlay();
    await Future.wait([mannequin.loaded, floor.meshComponent.loaded, ...crates.map((c) => c.meshComponent.loaded)]);
    world.tick(1 / 60);

    expect(_worldHeight(mannequin), closeTo(180, 4), reason: 'the glTF mannequin (1.8 m) is 180 world units');
    expect(_worldHeight(crates.first.meshComponent), closeTo(100, 1));
    final png = SmokeArtifacts.encodePng(_w, _h, f.capture());
    SmokeArtifacts.saveScreenshot('units: centimetre runtime scene', png, usedAssets: const [LuminaThirdPersonContent.bundledMeshPath]);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('units: a point-lit room renders the same in centimetres', () async {
    Future<Uint8List> render({required bool centimetres}) async {
      final f = _Frame();
      addTearDown(f.dispose);
      final u = centimetres ? LuminaUnits.unitsPerMetre : 1.0;
      f.project(near: 0.1 * u, far: 100 * u);
      f.camera.lookAt(eyeX: 0, eyeY: 3 * u, eyeZ: 6 * u, centerX: 0, centerY: 0, centerZ: 0);
      // Indoor exposure (EV100 ≈ 6): the default is set for sunlight.
      f.camera.setExposureEv100(6.0);
      if (!centimetres) {
        // The reference: raw Filament in metres, the units it was designed for.
        final floorBytes = PrimitiveGlbFactory.build(shape: 'plane', sizeX: 20, sizeY: 0, sizeZ: 20, colorHex: '#B0B0B0');
        final provider = FilamentMaterialProvider.ubershader(f.engine);
        final loader = FilamentAssetLoader.create(engine: f.engine, materialProvider: provider);
        final (asset, _) = loader.createInstancedAsset(floorBytes, 1);
        final resources = FilamentResourceLoader.create(engine: f.engine)..registerDefaultProviders(f.engine);
        await resources.loadAsync(asset!);
        f.scene.addEntities(asset.entities);
        // Released before the engine (tear-downs run last-registered first).
        addTearDown(() {
          f.scene.removeEntities(asset.entities);
          loader.destroyAsset(asset);
          resources.dispose();
          loader.dispose();
          provider.dispose();
        });
        final light = f.engine.createEntity();
        LightBuilder(LightType.point).color(1, 1, 1).intensity(10000).falloff(10).position(0, 2.5, 0).build(f.engine, light);
        f.scene.addEntity(light);
        return f.capture();
      }
      final world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(f.engine, f.scene);
      addTearDown(world.cleanup);
      world.bindView(f.view);
      final floor = LuminaPrimitiveActor(shape: LuminaPrimitiveShape.plane, size: Vector3(2000, 0, 2000), color: luminaHexToRgb('#B0B0B0'));
      world.persistentLevel.registerActor(floor);
      world.persistentLevel.registerActor(LuminaActor(root: LuminaPointLightComponent(intensity: 10000, location: Vector3(0, 250, 0))));
      world.beginPlay();
      await floor.meshComponent.loaded;
      world.tick(1 / 60);
      return f.capture();
    }

    final metres = await render(centimetres: false);
    final cm = await render(centimetres: true);
    SmokeArtifacts.saveScreenshot('units: a point-lit room renders the same in centimetres 01 metres', SmokeArtifacts.encodePng(_w, _h, metres));
    SmokeArtifacts.saveScreenshot('units: a point-lit room renders the same in centimetres', SmokeArtifacts.encodePng(_w, _h, cm));
    final mLuma = _meanLuma(metres, 200, 200, 440, 330);
    final cmLuma = _meanLuma(cm, 200, 200, 440, 330);
    expect(mLuma, greaterThan(20), reason: 'the reference floor is lit');
    expect((cmLuma - mLuma).abs() / mLuma, lessThan(0.05), reason: 'metres $mLuma vs centimetres $cmLuma');
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('units: Third Person template at human scale', () async {
    final f = _Frame();
    addTearDown(f.dispose);
    f.daylight();
    f.project(near: 10, far: 100000);

    final world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(f.engine, f.scene);
    addTearDown(world.cleanup);
    world.registerSubsystem(LuminaCollisionSubsystem());
    // The stored level, exactly as the scaffold writes it: cm, Z up, converted
    // with the rule the level code generator emits.
    final crates = <LuminaPrimitiveActor>[];
    List<double>? start;
    for (final a in GameTemplateCatalog.thirdPerson.levelActors) {
      final loc = (a['location'] as List).cast<num>().map((e) => e.toDouble()).toList();
      if (a['type'] == 'PlayerStart') start = loc;
      if (a['type'] != 'Primitive') continue;
      final props = Map<String, dynamic>.from(((a['components'] as List).first as Map)['properties'] as Map);
      final actor = LuminaPrimitiveActor.fromComponentProperties(props, location: LuminaAxes.location(loc));
      if ((a['name'] as String).startsWith('Crate_')) crates.add(actor);
      world.persistentLevel.registerActor(actor);
    }
    final character = LuminaTemplateCharacter(thirdPerson: true, meshAssetPath: LuminaThirdPersonContent.bundledMeshPath, location: LuminaAxes.location(start!));
    world.persistentLevel.registerActor(character);
    world.beginPlay();
    await character.bodyMesh!.loaded;
    for (var i = 0; i < 30; i++) {
      world.tick(1 / 60);
    }

    final mannequinHeight = _worldHeight(character.bodyMesh!);
    final crateHeight = _worldHeight(crates.first.meshComponent);
    expect(mannequinHeight / crateHeight, closeTo(1.8, 0.2), reason: 'mannequin $mannequinHeight vs crate $crateHeight');
    // On the ground's collider (a plane gets a thin box centred on it), not falling through.
    expect(
      character.actorLocation.y,
      closeTo(LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight + LuminaPrimitiveActor.planeColliderThickness / 2, 2),
    );

    // Look from the character's own boom camera.
    final cam = world.activeCamera!;
    final eye = cam.worldLocation;
    final target = character.actorLocation + Vector3(0, 90, 0);
    f.camera.lookAt(eyeX: eye.x, eyeY: eye.y, eyeZ: eye.z, centerX: target.x, centerY: target.y, centerZ: target.z);
    SmokeArtifacts.saveScreenshot('units: Third Person template at human scale', SmokeArtifacts.encodePng(_w, _h, f.capture()),
        usedAssets: const [LuminaThirdPersonContent.bundledMeshPath]);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
