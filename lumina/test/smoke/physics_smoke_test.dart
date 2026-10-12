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

/// Real props from test-assets as rigid bodies on the Jolt backend: each
/// prop's collision is the convex hull of its own mesh, so barrels roll and
/// air-conditioning units tip like their shapes. A tower of barrels is hit by
/// a thrown barrel, AC units stack and topple, banana bunches and access
/// cards rain onto them and come to rest.
void main() {
  const testTitle = 'Physics Smoke Scenario 03: real props stack, topple and come to rest on the Jolt backend';

  test(testTitle, () async {
    final assets = SmokeArtifacts.testAssetsDir;
    const barrelAsset = 'Props/Barrels/fuel_barrel_red.glb';
    const barrel2Asset = 'Props/Barrels/fuel_barrel_yellow.glb';
    const acAsset = 'Props/AC_units/roof_aircon_unit_150x150_a.glb';
    const bananaAsset = 'Props/Banana Bunch/banana_bunch_medium.glb';
    const cardAsset = 'Props/Access_cards/access_card_red.glb';
    final used = [barrelAsset, barrel2Asset, acAsset, bananaAsset, cardAsset];
    for (final a in used) {
      if (!File('${assets.path}/$a').existsSync()) return markTestSkipped('test-assets missing $a');
    }
    final physicsBackend = LuminaPhysicsSubsystem(backend: LuminaPhysicsBackendKind.jolt);
    if (physicsBackend.backendKind != LuminaPhysicsBackendKind.jolt) {
      return markTestSkipped('the Jolt library is not built (tools/flutter_jolt/tool/build_jolt.*)');
    }

    // Each prop's hull: its mesh vertices (glTF metres → cm), thinned.
    final hulls = <String, List<Vector3>>{};
    for (final a in used) {
      final mesh = (await GlbReader.parse(File('${assets.path}/$a').readAsBytesSync()))!;
      final p = mesh.positions;
      final n = p.length ~/ 3;
      final step = math.max(1, n ~/ 1500);
      hulls[a] = [for (var i = 0; i < n; i += step) Vector3(p[3 * i], p[3 * i + 1], p[3 * i + 2]) * LuminaUnits.unitsPerMetre];
    }
    Aabb3 boundsOf(String a) => Aabb3.minMax(
          hulls[a]!.reduce((x, y) => Vector3.copy(x)..setValues(math.min(x.x, y.x), math.min(x.y, y.y), math.min(x.z, y.z))),
          hulls[a]!.reduce((x, y) => Vector3.copy(x)..setValues(math.max(x.x, y.x), math.max(x.y, y.y), math.max(x.z, y.z))),
        );

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
    final physics = world.registerSubsystem(physicsBackend);
    world.bindView(view);
    for (final a in used) {
      SmokeArtifacts.recordAsset('${assets.path}/$a');
    }

    world.persistentLevel.registerActor(LuminaPrimitiveActor(
        location: Vector3(0, -10, 0), shape: LuminaPrimitiveShape.box, size: Vector3(6000, 20, 6000), color: Vector3(0.5, 0.52, 0.5)));
    world.persistentLevel.registerActor(LuminaActor(
        root: LuminaDirectionalLightComponent(rotation: LuminaAxes.rotation([-50, 0, 35]), intensity: 100000, castShadows: true)));

    final props = <LuminaConvexComponent>[];
    final meshes = <LuminaStaticMeshComponent>[];
    LuminaConvexComponent prop(String asset, Vector3 bottomCenter, {double massKg = 20, Quaternion? rotation}) {
      final b = boundsOf(asset);
      // Place the hull's bottom centre at [bottomCenter].
      final offset = Vector3((b.min.x + b.max.x) / 2, b.min.y, (b.min.z + b.max.z) / 2);
      final body = LuminaConvexComponent(location: bottomCenter - offset, rotation: rotation, points: hulls[asset]!)
        ..simulatePhysics = true
        ..overrideMass = true
        ..massKg = massKg;
      final mesh = LuminaStaticMeshComponent(meshAssetPath: '${assets.path}/$asset', castShadows: true, receiveShadows: true)
        ..attachToComponent(body);
      final actor = LuminaActor(root: body)..addComponent(mesh);
      world.persistentLevel.registerActor(actor);
      props.add(body);
      meshes.add(mesh);
      return body;
    }

    // A tower of four barrels, left; a stack of three AC units, right.
    final barrelBounds = boundsOf(barrelAsset);
    final barrelHeight = barrelBounds.max.y - barrelBounds.min.y;
    for (var i = 0; i < 4; i++) {
      prop(i.isEven ? barrelAsset : barrel2Asset, Vector3(-150, i * (barrelHeight + 0.5) + 0.5, 0), massKg: 40);
    }
    final acBounds = boundsOf(acAsset);
    final acHeight = acBounds.max.y - acBounds.min.y;
    for (var i = 0; i < 3; i++) {
      prop(acAsset, Vector3(180 + i * 6.0, i * (acHeight + 0.5) + 0.5, i * 4.0), massKg: 60);
    }
    // The barrel thrown at the tower (sideways, so it rolls in).
    final thrown = prop(barrelAsset, Vector3(-700, 40, 0),
        massKg: 40, rotation: Quaternion.axisAngle(Vector3(1, 0, 0), math.pi / 2));
    // Light props that rain down later.
    final rain = <LuminaConvexComponent>[
      for (var i = 0; i < 6; i++)
        prop(i.isEven ? bananaAsset : cardAsset, Vector3(150 + (i % 3) * 25.0 - 25, 600 + i * 60.0, (i ~/ 3) * 30.0 - 15),
            massKg: i.isEven ? 1.5 : 0.05, rotation: Quaternion.axisAngle(Vector3(0.3, 1, 0.2).normalized(), i * 0.7)),
    ];
    for (final r in rain) {
      r.enableGravity = false;
    }

    world.beginPlay();
    for (final m in meshes) {
      await m.loaded.timeout(const Duration(seconds: 60));
    }

    final eye = Vector3(40, 380, 1150), center = Vector3(0, 110, 0);
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

    final towerStart = [for (final p in props.take(4)) p.worldLocation];
    var stepUs = 0, steps = 0, maxFrameUs = 0;
    double towerDisplacement() =>
        [for (var i = 0; i < 4; i++) props[i].worldLocation.distanceTo(towerStart[i])].reduce(math.max);
    var standingTower = 0.0;
    const frames = 12 * 60;
    for (var f = 0; f < frames; f++) {
      final t = f / 60;
      if (f == 60) {
        // Throw the barrel at the middle of the tower, tumbling.
        thrown.setPhysicsLinearVelocity(Vector3(1400, 380, 0));
        thrown.setPhysicsAngularVelocity(Vector3(0, 0, -12));
      }
      if (f == 60 * 4) {
        for (final r in rain) {
          r.enableGravity = true;
          r.wakeRigidBody();
        }
      }
      if (f == 55) standingTower = towerDisplacement();
      final watch = Stopwatch()..start();
      world.tick(1 / 60);
      watch.stop();
      stepUs += watch.elapsedMicroseconds;
      steps += physics.lastFrameSteps;
      maxFrameUs = math.max(maxFrameUs, watch.elapsedMicroseconds);
      if (f.isEven) video.addFrame(shot());
      if (f == 50) save('01 stacked at rest', {'towerDriftCm': towerDisplacement()});
      if (f == 60 * 2) save('02 the thrown barrel hits the tower', {'thrownX': thrown.worldLocation.x});
      if (f == 60 * 5) save('03 props rain onto the AC units', {});
      if (t >= 11.9 && f == frames - 1) save('04 everything at rest', {'awake': physics.bodies.where((b) => b.isAwake).length});
    }
    final awake = physics.bodies.where((b) => b.isAwake).length;
    final lowest = props.map((p) => p.getAABB().min.y).reduce(math.min);
    final metrics = <String, Object?>{
      'backend': physics.backend.name,
      'bodies': physics.bodies.length,
      'towerDriftBeforeHitCm': standingTower,
      'towerDisplacementCm': towerDisplacement(),
      'awakeAtEnd': awake,
      'lowestPropCm': lowest,
      'frameMeanMs': stepUs / frames / 1000,
      'frameMaxMs': maxFrameUs / 1000,
      'stepsPerFrame': steps / frames,
    };
    // ignore: avoid_print
    print('physics smoke: $metrics');
    expect(physics.backend.name, 'jolt');
    expect(standingTower, lessThan(5.0), reason: 'the stacks settle and stand before the throw');
    expect(towerDisplacement(), greaterThan(50), reason: 'the thrown barrel knocks the tower over');
    expect(lowest, greaterThan(-3), reason: 'nothing sinks into the floor');
    expect(awake, lessThan(physics.bodies.length), reason: 'props come to rest and sleep');
    SmokeArtifacts.saveVideo(testTitle, video.finish(), usedAssets: used);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
