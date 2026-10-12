import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';
import 'package:vector_math/vector_math_64.dart';

/// Cloth on the Jolt backend with real props: a flag pinned to a pole flies
/// in gusty wind, a towel and a t-shirt from test-assets hang on a washing
/// line and swing, and a 2.4 m sheet falls over a barrel and an AC unit
/// (convex hulls of their own meshes) and drapes over them.
void main() {
  const testTitle = 'Physics Smoke Scenario 04: a flag in the wind, clothes on a line and a sheet draped over props';

  test(testTitle, () async {
    final assets = SmokeArtifacts.testAssetsDir;
    const lineAsset = 'Props/Clothes Line/washingline3m.glb';
    const towelAsset = 'Props/Clothes Line/towel.glb';
    const shirtAsset = 'Props/Clothes Line/tshirt.glb';
    const barrelAsset = 'Props/Barrels/fuel_barrel_red.glb';
    const acAsset = 'Props/AC_units/roof_aircon_unit_150x150_a.glb';
    final used = [lineAsset, towelAsset, shirtAsset, barrelAsset, acAsset];
    for (final a in used) {
      if (!File('${assets.path}/$a').existsSync()) return markTestSkipped('test-assets missing $a');
    }
    final physics = LuminaPhysicsSubsystem(backend: LuminaPhysicsBackendKind.jolt);
    if (physics.backendKind != LuminaPhysicsBackendKind.jolt) {
      return markTestSkipped('the Jolt library is not built (tools/flutter_jolt/tool/build_jolt.*)');
    }

    // Convex hulls of the props the sheet falls on (glTF metres → cm).
    Future<List<Vector3>> hull(String asset) async {
      final mesh = (await LuminaGlbLoader.parse(File('${assets.path}/$asset').readAsBytesSync()))!;
      final p = mesh.positions;
      final n = p.length ~/ 3;
      final step = math.max(1, n ~/ 1500);
      return [for (var i = 0; i < n; i += step) Vector3(p[3 * i], p[3 * i + 1], p[3 * i + 2]) * LuminaUnits.unitsPerMetre];
    }

    final barrelHull = await hull(barrelAsset);
    final acHull = await hull(acAsset);

    const w = 1024, h = 768;
    final engine = FilamentEngine.create()!;
    final scene = engine.createScene();
    final view = engine.createView();
    final renderer = engine.createRenderer();
    final swapChain = engine.createHeadlessSwapChain(w, h);
    final camera = engine.createCamera(engine.createEntity());
    view
      ..scene = scene
      ..camera = camera
      ..setViewport(0, 0, w, h);
    camera.setProjection(fovDegrees: 45, aspect: w / h, near: 10, far: 100000, direction: FovDirection.vertical);
    scene.setSkybox(FilamentSkybox.build(engine, color: Vector4(0.45, 0.58, 0.8, 1), intensity: 30000));
    scene.setIndirectLight(FilamentIndirectLight.build(engine,
        irradiance: SphericalHarmonics(bands: 1, coefficients: [0.7, 0.7, 0.75]), intensity: 30000));
    final pixels = calloc<ffi.Uint8>(w * h * 4);
    final world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
    addTearDown(() {
      world.cleanup();
      calloc.free(pixels);
      engine.dispose();
    });
    world.registerSubsystem(LuminaCollisionSubsystem());
    world.registerSubsystem(physics);
    world.bindView(view);
    for (final a in used) {
      SmokeArtifacts.recordAsset('${assets.path}/$a');
    }

    void place(LuminaActor actor) => world.persistentLevel.registerActor(actor);
    place(LuminaPrimitiveActor(
        location: Vector3(0, -10, 0), shape: LuminaPrimitiveShape.box, size: Vector3(6000, 20, 6000), color: Vector3(0.5, 0.52, 0.5)));
    place(LuminaActor(root: LuminaDirectionalLightComponent(rotation: LuminaAxes.rotation([-50, 0, 35]), intensity: 100000, castShadows: true)));

    // A 4 m pole with a 180 x 110 cm flag pinned along its left edge.
    place(LuminaPrimitiveActor(
        location: Vector3(-420, 200, -150), shape: LuminaPrimitiveShape.cylinder, size: Vector3(8, 400, 8), color: Vector3(0.7, 0.7, 0.72)));
    // Turned 50° about the pole so the camera sees it fly toward it.
    final flagTurn = Quaternion.axisAngle(Vector3(0, 1, 0), -50 * math.pi / 180);
    final flag = LuminaClothComponent(
      location: Vector3(-420, 390, -150) + (Vector3(90, 0, 0)..applyQuaternion(flagTurn)),
      rotation: flagTurn,
      gridWidth: 180,
      gridHeight: 110,
      gridColumns: 24,
      gridRows: 15,
      pinning: LuminaClothPinning.leftEdge,
      massKg: 0.6,
      bendStiffness: 0.2,
      wind: Vector3(500, 0, 450),
      windDrag: 2.5,
      windTurbulence: 0.6,
      color: Vector3(0.75, 0.05, 0.05),
    );
    place(LuminaActor(root: flag));

    // A washing line between two posts, a towel and a t-shirt hanging on it.
    const lineY = 175.0;
    place(LuminaActor(root: LuminaStaticMeshComponent(meshAssetPath: '${assets.path}/$lineAsset', location: Vector3(330, lineY, -150))));
    for (final x in [180.0, 480.0]) {
      place(LuminaPrimitiveActor(
          location: Vector3(x, lineY / 2, -150), shape: LuminaPrimitiveShape.cylinder, size: Vector3(6, lineY, 6), color: Vector3(0.45, 0.3, 0.2)));
    }
    final towel = LuminaClothComponent(
      meshAsset: '${assets.path}/$towelAsset',
      location: Vector3(260, lineY - 6.3, -150),
      rotation: Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 2),
      massKg: 0.4,
      thickness: 0.6,
      wind: Vector3(0, 0, 350),
      windDrag: 1.5,
      color: Vector3(0.1, 0.35, 0.8),
    );
    final shirt = LuminaClothComponent(
      meshAsset: '${assets.path}/$shirtAsset',
      location: Vector3(400, lineY - 6.2, -150),
      rotation: Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 2),
      massKg: 0.3,
      thickness: 0.6,
      wind: Vector3(0, 0, 350),
      windDrag: 1.5,
      color: Vector3(0.85, 0.8, 0.2),
    );
    place(LuminaActor(root: towel));
    place(LuminaActor(root: shirt));

    // A barrel and an AC unit (static, their hulls) under a falling sheet.
    LuminaActor prop(String asset, List<Vector3> points, Vector3 at) {
      final body = LuminaConvexComponent(location: at, points: points)..objectType = CollisionObjectType.worldStatic;
      final mesh = LuminaStaticMeshComponent(meshAssetPath: '${assets.path}/$asset', castShadows: true, receiveShadows: true)
        ..attachToComponent(body);
      return LuminaActor(root: body)..addComponent(mesh);
    }

    final barrelBottom = barrelHull.map((v) => v.y).reduce(math.min);
    final acBottom = acHull.map((v) => v.y).reduce(math.min);
    place(prop(barrelAsset, barrelHull, Vector3(-150, -barrelBottom, 150)));
    place(prop(acAsset, acHull, Vector3(-20, -acBottom, 150)));
    final sheet = LuminaClothComponent(
      location: Vector3(-85, 260, 30),
      rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -math.pi / 2),
      gridWidth: 240,
      gridHeight: 240,
      gridColumns: 30,
      gridRows: 30,
      pinning: LuminaClothPinning.none,
      massKg: 1.5,
      bendStiffness: 0.15,
      thickness: 1.5,
      color: Vector3(0.85, 0.85, 0.82),
    );
    place(LuminaActor(root: sheet));

    world.beginPlay();
    for (final cloth in [flag, towel, shirt, sheet]) {
      await cloth.ready.timeout(const Duration(seconds: 60));
    }
    final meshes = [
      for (final a in world.actors)
        for (final comp in a.components)
          if (comp is LuminaStaticMeshComponent) comp,
    ];
    for (final m in meshes) {
      await m.loaded.timeout(const Duration(seconds: 60));
    }
    expect([flag, towel, shirt, sheet].every((c) => c.isSimulating), isTrue);

    final eye = Vector3(20, 360, 1050), center = Vector3(20, 150, 0);
    Uint8List shot() {
      camera.lookAt(eyeX: eye.x, eyeY: eye.y, eyeZ: eye.z, centerX: center.x, centerY: center.y, centerZ: center.z);
      for (var i = 0; i < 2; i++) {
        if (renderer.beginFrame(swapChain)) {
          renderer.render(view);
          if (i == 1) {
            c.filament_renderer_read_pixels(renderer.nativePointer, engine.nativePointer, 0, 0, w, h, pixels.cast(), ffi.nullptr, ffi.nullptr);
          }
          renderer.endFrame();
        }
        engine.flushAndWait();
      }
      return Uint8List.fromList(pixels.asTypedList(w * h * 4));
    }

    final video = SmokeVideoRecorder(width: w, height: h, fps: 30, testName: testTitle);
    addTearDown(video.discard);
    void save(String name, Map<String, Object?> metrics) =>
        SmokeArtifacts.saveScreenshot('$testTitle $name', SmokeArtifacts.encodePng(w, h, shot()), usedAssets: used, metrics: metrics);

    double flagSpanZ() {
      final p = flag.currentSimPositions();
      var lo = double.infinity, hi = -double.infinity;
      for (var i = 0; i < p.length ~/ 3; i++) {
        lo = math.min(lo, p[3 * i + 2]);
        hi = math.max(hi, p[3 * i + 2]);
      }
      return hi - lo;
    }

    var frameUs = 0, maxFrameUs = 0;
    const frames = 12 * 60;
    for (var f = 0; f < frames; f++) {
      final watch = Stopwatch()..start();
      world.tick(1 / 60);
      watch.stop();
      frameUs += watch.elapsedMicroseconds;
      maxFrameUs = math.max(maxFrameUs, watch.elapsedMicroseconds);
      if (f.isEven) video.addFrame(shot());
      if (f == 20) save('01 cloth starts', {});
      if (f == 150) save('02 the sheet lands on the props', {});
      if (f == 400) save('03 flag flying, clothes swinging', {'flagSpanZcm': flagSpanZ()});
      if (f == frames - 1) save('04 after 12 s', {});
    }

    // The sheet's world vertices: it rests on the props, edges hanging lower.
    final sp = sheet.currentSimPositions();
    final sheetWorld = [for (var i = 0; i < sp.length ~/ 3; i++) sheet.worldTransform.transform3(Vector3(sp[3 * i], sp[3 * i + 1], sp[3 * i + 2]))];
    final sheetTop = sheetWorld.map((v) => v.y).reduce(math.max);
    final sheetLowest = sheetWorld.map((v) => v.y).reduce(math.min);
    final towelP = towel.currentSimPositions();
    final towelOk = towelP.every((v) => v.isFinite);
    final metrics = <String, Object?>{
      'backend': physics.backend.name,
      'clothVertices': {
        'flag': flag.geometry!.simVertexCount,
        'towel': towel.geometry!.simVertexCount,
        'tshirt': shirt.geometry!.simVertexCount,
        'sheet': sheet.geometry!.simVertexCount,
      },
      'flagSpanZcm': flagSpanZ(),
      'sheetTopCm': sheetTop,
      'sheetLowestCm': sheetLowest,
      'frameMeanMs': frameUs / frames / 1000,
      'frameMaxMs': maxFrameUs / 1000,
    };
    // ignore: avoid_print
    print('cloth smoke: $metrics');
    expect(towelOk, isTrue);
    expect(flagSpanZ(), greaterThan(40), reason: 'the wind lifts the flag off the pole plane');
    expect(sheetTop, greaterThan(60), reason: 'the sheet rests on the props');
    expect(sheetLowest, lessThan(sheetTop - 40), reason: 'its edges hang down');
    SmokeArtifacts.saveVideo(testTitle, video.finish(), usedAssets: used);
  }, timeout: const Timeout(Duration(minutes: 10)));

  const skirtTitle = 'Physics Smoke Scenario 05: a skirt skinned to the walking mannequin swings and stays outside its legs';

  test(skirtTitle, () async {
    final assets = SmokeArtifacts.testAssetsDir;
    const mannyAsset = 'mannequin/SKM_Manny_Simple.glb';
    const walkAsset = 'mannequin/MF_Unarmed_Walk_Fwd.glb';
    final used = [mannyAsset, walkAsset];
    for (final a in used) {
      if (!File('${assets.path}/$a').existsSync()) return markTestSkipped('test-assets missing $a');
    }
    final physics = LuminaPhysicsSubsystem(backend: LuminaPhysicsBackendKind.jolt);
    if (physics.backendKind != LuminaPhysicsBackendKind.jolt) {
      return markTestSkipped('the Jolt library is not built (tools/flutter_jolt/tool/build_jolt.*)');
    }
    final dir = Directory.systemTemp.createTempSync('skirt_smoke_');
    final merged = GlbAnimationMerger.merge(
      base: File('${assets.path}/$mannyAsset').readAsBytesSync(),
      clips: [GlbClipSource(name: 'Walk', bytes: File('${assets.path}/$walkAsset').readAsBytesSync())],
    );
    final meshFile = File('${dir.path}/manny_walk.glb')..writeAsBytesSync(merged);

    const w = 1024, h = 768;
    final engine = FilamentEngine.create()!;
    final scene = engine.createScene();
    final view = engine.createView();
    final renderer = engine.createRenderer();
    final swapChain = engine.createHeadlessSwapChain(w, h);
    final camera = engine.createCamera(engine.createEntity());
    view
      ..scene = scene
      ..camera = camera
      ..setViewport(0, 0, w, h);
    camera.setProjection(fovDegrees: 40, aspect: w / h, near: 10, far: 100000, direction: FovDirection.vertical);
    scene.setSkybox(FilamentSkybox.build(engine, color: Vector4(0.45, 0.58, 0.8, 1), intensity: 30000));
    scene.setIndirectLight(FilamentIndirectLight.build(engine,
        irradiance: SphericalHarmonics(bands: 1, coefficients: [0.7, 0.7, 0.75]), intensity: 30000));
    final pixels = calloc<ffi.Uint8>(w * h * 4);
    final world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
    addTearDown(() {
      world.cleanup();
      calloc.free(pixels);
      engine.dispose();
      dir.deleteSync(recursive: true);
    });
    world.registerSubsystem(LuminaCollisionSubsystem());
    world.registerSubsystem(physics);
    world.bindView(view);
    for (final a in used) {
      SmokeArtifacts.recordAsset('${assets.path}/$a');
    }
    world.persistentLevel.registerActor(LuminaPrimitiveActor(
        location: Vector3(0, -10, 0), shape: LuminaPrimitiveShape.box, size: Vector3(4000, 20, 4000), color: Vector3(0.5, 0.52, 0.5)));
    world.persistentLevel.registerActor(
        LuminaActor(root: LuminaDirectionalLightComponent(rotation: LuminaAxes.rotation([-50, 0, 35]), intensity: 100000, castShadows: true)));

    // The mannequin walks along +X (it faces glTF +Z: turned 90°).
    final root = LuminaSceneComponent(location: Vector3(-150, 0, 0));
    final actor = LuminaActor(root: root);
    final mesh = LuminaAnimatedMeshComponent(meshAssetPath: meshFile.path)
      ..relativeRotation = Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 2);
    mesh.attachToComponent(root);
    actor.addComponent(mesh);
    final skirt = LuminaSkinnedClothComponent(mesh: mesh, color: Vector3(0.55, 0.08, 0.35), wind: Vector3(0, 0, 120), windDrag: 0.5);
    actor.addComponent(skirt);
    world.persistentLevel.registerActor(actor);
    world.beginPlay();
    await mesh.loaded.timeout(const Duration(seconds: 60));
    await skirt.ready.timeout(const Duration(seconds: 60));
    mesh.play('Walk');
    expect(skirt.isSimulating, isTrue);

    Uint8List shot() {
      final focus = root.worldLocation + Vector3(0, 95, 0);
      camera.lookAt(
          eyeX: focus.x + 120, eyeY: focus.y + 60, eyeZ: focus.z + 330, centerX: focus.x, centerY: focus.y - 10, centerZ: focus.z);
      for (var i = 0; i < 2; i++) {
        if (renderer.beginFrame(swapChain)) {
          renderer.render(view);
          if (i == 1) {
            c.filament_renderer_read_pixels(renderer.nativePointer, engine.nativePointer, 0, 0, w, h, pixels.cast(), ffi.nullptr, ffi.nullptr);
          }
          renderer.endFrame();
        }
        engine.flushAndWait();
      }
      return Uint8List.fromList(pixels.asTypedList(w * h * 4));
    }

    final video = SmokeVideoRecorder(width: w, height: h, fps: 30, testName: skirtTitle);
    addTearDown(video.discard);
    void save(String name, Map<String, Object?> metrics) =>
        SmokeArtifacts.saveScreenshot('$skirtTitle $name', SmokeArtifacts.encodePng(w, h, shot()), usedAssets: used, metrics: metrics);

    var maxFrameUs = 0, frameUs = 0, nonFinite = 0;
    const frames = 12 * 60;
    for (var f = 0; f < frames; f++) {
      // Walk 1.5 m/s for 4 s, stop, turn round within one frame, walk back.
      final speed = f < 240 ? 150.0 : (f < 360 ? 0.0 : -150.0);
      root.relativeLocation = root.relativeLocation + Vector3(speed / 60, 0, 0);
      if (f == 360) mesh.relativeRotation = Quaternion.axisAngle(Vector3(0, 1, 0), -math.pi / 2);
      final watch = Stopwatch()..start();
      world.tick(1 / 60);
      watch.stop();
      frameUs += watch.elapsedMicroseconds;
      maxFrameUs = math.max(maxFrameUs, watch.elapsedMicroseconds);
      if (f > 120) {
        nonFinite += skirt.currentSimPositions().where((v) => !v.isFinite).length;
      }
      if (f.isEven) video.addFrame(shot());
      if (f == 60) save('01 standing', {});
      if (f == 200) save('02 walking, the skirt swings', {});
      if (f == 330) save('03 stopped', {});
      if (f == 362) save('04 turned 180 degrees in one frame, the skirt back on the body', {});
      if (f == 600) save('05 walking back', {});
    }
    final metrics = <String, Object?>{
      'skirtVertices': skirt.geometry!.simVertexCount,
      'frameMeanMs': frameUs / frames / 1000,
      'frameMaxMs': maxFrameUs / 1000,
      'nonFinite': nonFinite,
    };
    // ignore: avoid_print
    print('skirt smoke: $metrics');
    expect(nonFinite, 0, reason: 'every vertex stays finite');
    SmokeArtifacts.saveVideo(skirtTitle, video.finish(), usedAssets: used);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
