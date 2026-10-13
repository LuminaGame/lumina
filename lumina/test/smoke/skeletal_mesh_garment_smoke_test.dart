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
import 'package:lumina_core/lumina_core.dart';
import 'package:vector_math/vector_math_64.dart';

/// A character Blueprint with Body and Torso slots: the T-shirt from
/// `test-assets/Props/Clothes Line/` as a Garment asset (landmarked on
/// Manny) is put in Torso through the Fit Garment path, the body under it
/// masked; the Body slot then changes to Quinn playing her idle clip (the
/// shirt is fitted to her on a worker isolate and masks her) and back to
/// Manny (from the cache), while a sway on the spine and arms animates the
/// body and the shirt follows by bone name.
void main() {
  test('Skeletal Mesh Smoke Scenario 06: garment refit when the character body changes', () async {
    const testTitle = 'Skeletal Mesh Smoke Scenario 06: garment refit when the character body changes';
    final assets = SmokeArtifacts.testAssetsDir.path;
    final tshirt = File('$assets/Props/Clothes Line/tshirt.glb');
    final manny = File('$assets/mannequin/SKM_Manny_Simple.glb');
    // Quinn with the idle clip in the same file.
    final quinn = File('$assets/mannequin/MM_Idle.glb');
    for (final f in [tshirt, manny, quinn]) {
      if (!f.existsSync()) return markTestSkipped('test-assets missing ${f.path}');
      SmokeArtifacts.recordAsset(f.path);
    }
    const w = SmokeVideo.defaultWidth;
    const h = SmokeVideo.defaultHeight;
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
    camera.setProjection(fovDegrees: 35, aspect: w / h, near: 10, far: 100000, direction: FovDirection.vertical);
    scene.setSkybox(FilamentSkybox.build(engine, color: Vector4(0.36, 0.42, 0.52, 1), intensity: 30000));
    scene.setIndirectLight(FilamentIndirectLight.build(engine,
        irradiance: SphericalHarmonics(bands: 1, coefficients: [0.7, 0.7, 0.75]), intensity: 32000));
    final pixels = calloc<ffi.Uint8>(w * h * 4);
    final dir = Directory.systemTemp.createTempSync('garment_smoke_');
    final world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
    addTearDown(() {
      world.cleanup();
      calloc.free(pixels);
      engine.dispose();
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });
    world.bindView(view);
    world.persistentLevel.registerActor(LuminaPrimitiveActor(
        location: Vector3(0, -10, 0), shape: LuminaPrimitiveShape.box, size: Vector3(1600, 20, 1600), color: Vector3(0.45, 0.44, 0.42)));
    world.persistentLevel.registerActor(LuminaActor(
        root: LuminaDirectionalLightComponent(rotation: LuminaAxes.rotation([-45, 0, 35]), intensity: 100000, castShadows: true)));

    // The Garment asset, as the Garment editor writes it: the shirt turned
    // to face front at the chest, landmarks at the neck, shoulders and waist.
    final draco = LuminaGlbLoader.decoders.draco;
    final shirt = LuminaSkinnedMeshData.fromGlb(tshirt.readAsBytesSync(), draco: draco);
    final mannyData = LuminaSkinnedMeshData.fromGlb(manny.readAsBytesSync());
    var doc = const LuminaGarmentDocument().copyWith(
      sourceMesh: tshirt.path,
      referenceBody: manny.path,
      location: [0, 150, 9],
      rotation: [0, 90, 0],
      scale: [1.15, 1.15, 1.15],
      thickness: 0.6,
    );
    final placed = Float64List(shirt.positions.length);
    for (var v = 0; v < shirt.vertexCount; v++) {
      placed.setAll(v * 3, doc.place([shirt.positions[v * 3], shirt.positions[v * 3 + 1], shirt.positions[v * 3 + 2]]));
    }
    for (final (name, x, y) in [('Neck', 0.0, 145.0), ('Shoulder L', 17.0, 141.0), ('Shoulder R', -17.0, 141.0), ('Waist', 0.0, 104.0)]) {
      final g = LuminaGarmentMath.raycast(placed, shirt.triangles, x, y, 200, 0, 0, -1)!;
      final b = LuminaGarmentMath.raycast(mannyData.positions, mannyData.triangles, x, y, 200, 0, 0, -1)!;
      final q = LuminaGarmentMath.quaternionFromEuler(doc.rotation);
      final local = LuminaGarmentMath.rotate([-q[0], -q[1], -q[2], q[3]], [g.x - doc.location[0], g.y - doc.location[1], g.z - doc.location[2]]);
      doc = doc.withLandmark(LuminaGarmentLandmark(name, garment: [for (final c in local) c / 1.15], body: [b.x, b.y, b.z]));
    }
    final garment = '${dir.path}/G_Tshirt.lmas';
    File(garment).writeAsBytesSync(doc.toAsset(name: 'G_Tshirt').toProtoBufferBytes());

    final actor = LuminaActor(root: LuminaSceneComponent());
    final built = LuminaBlueprintComponents.construct(actor, [
      LuminaBlueprintComponent(id: 'body', name: 'Body', type: 'LuminaSkeletalMeshComponent', isSceneComponent: true, properties: {'skeletalMeshAsset': manny.path, 'slot': 'Body'}),
      LuminaBlueprintComponent(
        id: 'torso',
        name: 'Torso',
        type: 'LuminaSkeletalMeshComponent',
        parentId: 'body',
        isSceneComponent: true,
        properties: {'skeletalMeshAsset': '', 'slot': 'Torso', 'poseFrom': 'body'},
      ),
    ], resolveAsset: (s) => s);
    world.persistentLevel.registerActor(actor);
    world.beginPlay();
    final body = built['body'] as LuminaAnimatedMeshComponent;
    await body.loaded;
    final slots = LuminaCharacterSlots.of(actor);
    LuminaGarmentCache.instance.clear();
    final onManny = (await slots.fitGarment('Torso', garment))!;
    final torso = slots.component('Torso') as LuminaAnimatedMeshComponent;
    await torso.poseLinkReady;
    expect(onManny.maxPenetration, lessThan(0.1));

    var t = 0.0;
    Uint8List shot() {
      final angle = 0.35 * math.sin(t * 0.5);
      camera.lookAt(eyeX: 330 * math.sin(angle), eyeY: 135, eyeZ: 330 * math.cos(angle), centerX: 0, centerY: 110, centerZ: 0);
      for (var i = 0; i < 3; i++) {
        if (renderer.beginFrame(swapChain)) {
          renderer.render(view);
          if (i == 2) {
            c.filament_renderer_read_pixels(renderer.nativePointer, engine.nativePointer, 0, 0, w, h, pixels.cast(), ffi.nullptr, ffi.nullptr);
          }
          renderer.endFrame();
        }
        engine.flushAndWait();
      }
      return Uint8List.fromList(pixels.asTypedList(w * h * 4));
    }

    void sway() {
      body.setJointOverride('spine_03', rotation: Quaternion.axisAngle(Vector3(0, 1, 0), 0.25 * math.sin(t * 1.7)));
      body.setJointOverride('upperarm_l', rotation: Quaternion.axisAngle(Vector3(0, 0, 1), 0.35 * math.sin(t * 2.1)));
      body.setJointOverride('upperarm_r', rotation: Quaternion.axisAngle(Vector3(0, 0, 1), -0.35 * math.sin(t * 2.1)));
    }

    final usedAssets = [
      'Props/Clothes Line/tshirt.glb',
      'mannequin/SKM_Manny_Simple.glb',
      'mannequin/MM_Idle.glb',
    ];
    final video = SmokeVideoRecorder(width: w, height: h, fps: 30, testName: testTitle);
    addTearDown(video.discard);
    Future<void> play(double seconds) async {
      final ticks = (seconds * 60).round();
      for (var i = 0; i < ticks; i++) {
        t += 1 / 60;
        sway();
        world.tick(1 / 60);
        if (i.isEven) video.addFrame(shot());
      }
    }

    await play(4);
    expect(body.meshAssetPath, startsWith('${manny.path}#masked-'));
    SmokeArtifacts.saveScreenshot('$testTitle 01 shirt on Manny', SmokeArtifacts.encodePng(w, h, shot()),
        usedAssets: usedAssets, metrics: onManny.toJson());

    expect(await slots.setMesh('Body', quinn.path), isTrue);
    await torso.poseLinkReady;
    body.play(body.clipNames.first);
    final onQuinn = slots.slot('Torso')!.lastFit!;
    expect(onQuinn.maxPenetration, lessThan(0.1));
    expect(onQuinn.denseCorrespondence, isFalse, reason: 'Manny and Quinn differ in topology');
    expect(body.meshAssetPath, startsWith('${quinn.path}#masked-'));
    await play(4);
    SmokeArtifacts.saveScreenshot('$testTitle 02 shirt refitted to Quinn', SmokeArtifacts.encodePng(w, h, shot()),
        usedAssets: usedAssets, metrics: onQuinn.toJson());

    final computed = LuminaGarmentCache.instance.computed;
    expect(await slots.setMesh('Body', manny.path), isTrue);
    await torso.poseLinkReady;
    expect(LuminaGarmentCache.instance.computed, computed, reason: 'Manny\'s fit comes from the cache');
    await play(4);
    SmokeArtifacts.saveScreenshot('$testTitle 03 back on Manny', SmokeArtifacts.encodePng(w, h, shot()), usedAssets: usedAssets);
    // ignore: avoid_print
    print('garment refit: Manny ${onManny.toJson()}; Quinn ${onQuinn.toJson()}');
    SmokeArtifacts.saveVideo(testTitle, video.finish(), usedAssets: usedAssets);
  }, timeout: const Timeout(Duration(minutes: 8)));
}
