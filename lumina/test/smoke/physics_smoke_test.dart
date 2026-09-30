import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';
import 'package:vector_math/vector_math_64.dart';

/// Test assets root (`$LUMINA_TEST_ASSETS`).
Directory get _testAssets => Directory(Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets');

/// A translucent green box with bright edges, half extents [e] in its own
/// frame (cm): the collider drawn over the chair, as the editor's
/// "Show > Collision" would, riding with the simulated body.
Uint8List _boxOverlayGlb(Vector3 e) {
  final corners = [
    for (var i = 0; i < 8; i++) Vector3(i & 1 == 0 ? -e.x : e.x, i & 2 == 0 ? -e.y : e.y, i & 4 == 0 ? -e.z : e.z),
  ];
  const faces = [
    [0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5], //
  ];
  final positions = <double>[];
  final normals = <double>[];
  final tris = <int>[];
  for (final f in faces) {
    final n = (corners[f[1]] - corners[f[0]]).cross(corners[f[2]] - corners[f[0]])..normalize();
    final base = positions.length ~/ 3;
    for (final i in f) {
      positions.addAll([corners[i].x, corners[i].y, corners[i].z]);
      normals.addAll([n.x, n.y, n.z]);
    }
    tris.addAll([base, base + 1, base + 2, base, base + 2, base + 3]);
  }
  final lines = <int>[];
  for (var f = 0; f < 6; f++) {
    for (var k = 0; k < 4; k++) {
      lines.addAll([f * 4 + k, f * 4 + (k + 1) % 4]);
    }
  }
  final pos = Float32List.fromList(positions).buffer.asUint8List();
  final nor = Float32List.fromList(normals).buffer.asUint8List();
  final tri = Uint32List.fromList(tris).buffer.asUint8List();
  final lin = Uint32List.fromList(lines).buffer.asUint8List();
  final bin = BytesBuilder()..add(pos)..add(nor)..add(tri)..add(lin);
  final count = positions.length ~/ 3;
  final json = <String, dynamic>{
    'asset': {'version': '2.0', 'generator': 'lumina physics smoke'},
    'extensionsUsed': ['KHR_materials_unlit'],
    'scene': 0,
    'scenes': [
      {'nodes': [0]},
    ],
    'nodes': [
      {'mesh': 0, 'name': 'Collider'},
    ],
    'meshes': [
      {
        'primitives': [
          {'attributes': {'POSITION': 0, 'NORMAL': 1}, 'indices': 2, 'material': 0, 'mode': 4},
          {'attributes': {'POSITION': 0, 'NORMAL': 1}, 'indices': 3, 'material': 1, 'mode': 1},
        ],
      },
    ],
    'materials': [
      {
        'name': 'M_ColliderFaces',
        'alphaMode': 'BLEND',
        'doubleSided': true,
        'pbrMetallicRoughness': {'baseColorFactor': [0.15, 1.0, 0.35, 0.18], 'metallicFactor': 0.0, 'roughnessFactor': 1.0},
        'extensions': {'KHR_materials_unlit': <String, dynamic>{}},
      },
      {
        'name': 'M_ColliderEdges',
        'pbrMetallicRoughness': {'baseColorFactor': [0.3, 1.0, 0.4, 1.0], 'metallicFactor': 0.0, 'roughnessFactor': 1.0},
        'extensions': {'KHR_materials_unlit': <String, dynamic>{}},
      },
    ],
    'accessors': [
      {'bufferView': 0, 'componentType': 5126, 'count': count, 'type': 'VEC3', 'min': [-e.x, -e.y, -e.z], 'max': [e.x, e.y, e.z]},
      {'bufferView': 1, 'componentType': 5126, 'count': count, 'type': 'VEC3'},
      {'bufferView': 2, 'componentType': 5125, 'count': tris.length, 'type': 'SCALAR'},
      {'bufferView': 3, 'componentType': 5125, 'count': lines.length, 'type': 'SCALAR'},
    ],
    'bufferViews': [
      {'buffer': 0, 'byteOffset': 0, 'byteLength': pos.length, 'target': 34962},
      {'buffer': 0, 'byteOffset': pos.length, 'byteLength': nor.length, 'target': 34962},
      {'buffer': 0, 'byteOffset': pos.length + nor.length, 'byteLength': tri.length, 'target': 34963},
      {'buffer': 0, 'byteOffset': pos.length + nor.length + tri.length, 'byteLength': lin.length, 'target': 34963},
    ],
    'buffers': [
      {'byteLength': pos.length + nor.length + tri.length + lin.length},
    ],
  };
  return GlbDocument(json, bin.takeBytes()).encode();
}

/// A lit Filament world on GPU 1: a floor (the yard), the sun, collision.
class _Yard {
  static const w = SmokeVideo.defaultWidth;
  static const h = SmokeVideo.defaultHeight;

  _Yard() {
    engine = FilamentEngine.create()!;
    scene = engine.createScene();
    view = engine.createView();
    renderer = engine.createRenderer();
    swapChain = engine.createHeadlessSwapChain(w, h);
    camera = engine.createCamera(engine.createEntity());
    view
      ..scene = scene
      ..camera = camera
      ..setViewport(0, 0, w, h);
    camera.setProjection(fovDegrees: 55, aspect: w / h, near: 10, far: 100000, direction: FovDirection.vertical);
    scene.setSkybox(FilamentSkybox.build(engine, color: Vector4(0.42, 0.55, 0.78, 1), intensity: 30000));
    scene.setIndirectLight(FilamentIndirectLight.build(
      engine,
      irradiance: SphericalHarmonics(bands: 1, coefficients: [0.65, 0.65, 0.7]),
      intensity: 30000,
    ));
    world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
    world.registerSubsystem(LuminaCollisionSubsystem());
    world.bindView(view);
    world.persistentLevel.registerActor(LuminaPrimitiveActor(
      location: LuminaAxes.location([0, 0, -10]),
      shape: LuminaPrimitiveShape.box,
      size: Vector3(2400, 20, 2400),
      color: Vector3(0.52, 0.5, 0.47),
    ));
    world.persistentLevel.registerActor(LuminaActor(
      root: LuminaDirectionalLightComponent(rotation: LuminaAxes.rotation([-50, 0, 30]), intensity: 100000, castShadows: true),
    ));
  }

  late final FilamentEngine engine;
  late final FilamentScene scene;
  late final FilamentView view;
  late final FilamentRenderer renderer;
  late final FilamentSwapChain swapChain;
  late final FilamentCamera camera;
  late final LuminaWorld world;
  final ffi.Pointer<ffi.Uint8> _pixels = calloc<ffi.Uint8>(w * h * 4);

  Uint8List shot(Vector3 eye, Vector3 target) {
    camera.lookAt(eyeX: eye.x, eyeY: eye.y, eyeZ: eye.z, centerX: target.x, centerY: target.y, centerZ: target.z);
    for (var i = 0; i < 3; i++) {
      if (renderer.beginFrame(swapChain)) {
        renderer.render(view);
        if (i == 2) {
          c.filament_renderer_read_pixels(renderer.nativePointer, engine.nativePointer, 0, 0, w, h, _pixels.cast(), ffi.nullptr, ffi.nullptr);
        }
        renderer.endFrame();
      }
      engine.flushAndWait();
    }
    return Uint8List.fromList(_pixels.asTypedList(w * h * 4));
  }

  void dispose() {
    world.cleanup();
    calloc.free(_pixels);
    engine.dispose();
  }
}

/// Imports [glb] into [project] as a static mesh and stores [massKg] as the
/// Static Mesh editor's Mass; returns the `.lmas` path.
Future<String> _importWithMass(String project, File glb, double massKg) async {
  final imported = await ImportAssetUseCase()(projectDir: project, sourceFilePath: glb.path);
  expect(imported.isSuccess, isTrue, reason: imported.error);
  final base = glb.uri.pathSegments.last.replaceAll(RegExp(r'\.glb$'), '');
  final lmas = Directory('$project/contents')
      .listSync(recursive: true)
      .whereType<File>()
      .firstWhere((f) => f.path.endsWith('/$base.lmas'));
  final asset = LuminaAsset.fromBytes(lmas.readAsBytesSync());
  final updated = LuminaAsset(
    assetId: asset.assetId,
    name: asset.name,
    type: asset.type,
    hasThumbnail: asset.hasThumbnail,
    thumbnailPng: asset.thumbnailPng,
    rawPayload: asset.rawPayload,
    rawMatSource: asset.rawMatSource,
    references: asset.references,
    metadata: {
      ...asset.metadata,
      'physics': jsonEncode({'massKg': massKg, 'centerOfMassOffset': [0.0, 0.0, 0.0]}),
    },
  );
  lmas.writeAsBytesSync(updated.toProtoBufferBytes());
  return lmas.path;
}

/// A prop Blueprint as the editor authors it: the mesh, and a simulating
/// collider sized to the mesh's bounds ([sphere] or a box) inheriting the
/// mesh's mass.
LuminaBlueprintDocument _propBlueprint(String lmas, GlbMeshData mesh,
    {required bool sphere, double restitution = 0.1, double linearDamping = 0.01, double angularDamping = 0.0}) {
  // glTF metres, Y up → authoring cm, Z up.
  final lo = mesh.minBounds, hi = mesh.maxBounds;
  final half = [for (var i = 0; i < 3; i++) (hi[i] - lo[i]) * 50.0];
  final center = [for (var i = 0; i < 3; i++) (hi[i] + lo[i]) * 50.0];
  return LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
    LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
    LuminaBlueprintComponent(id: 'mesh', name: 'Mesh', type: 'LuminaStaticMeshComponent', parentId: 'root', properties: {
      'staticMeshAsset': lmas,
    }),
    LuminaBlueprintComponent(
      id: 'collider',
      name: sphere ? 'Sphere' : 'Box',
      type: sphere ? 'LuminaSphereComponent' : 'LuminaBoxComponent',
      parentId: 'root',
      properties: {
        if (sphere) 'radius': half.reduce(math.max) else 'boxExtent': [half[0], half[2], half[1]],
        'location': [center[0], -center[2], center[1]],
        'preset': 'BlockAllDynamic',
        'physics': {'simulate': true, 'restitution': restitution, 'linearDamping': linearDamping, 'angularDamping': angularDamping},
      },
    ),
  ]);
}

void main() {
  group('Physics Module Smoke Tests', () {
    test('rigid bodies fall, tip and roll', () async {
      const testTitle = 'Physics Module Smoke Tests rigid bodies fall, tip and roll';
      final chairGlb = File('${_testAssets.path}/Props/Chair/chair_mountable.glb');
      final ballGlb = File('${_testAssets.path}/Vehicles/Ball/ball.entity.glb');
      final mannequin = File(LuminaThirdPersonContent.bundledMeshPath);
      if (!chairGlb.existsSync() || !ballGlb.existsSync()) return markTestSkipped('test-assets missing');
      if (!mannequin.existsSync()) return markTestSkipped('build tool/build_third_person_content.dart first');
      const usedAssets = ['Props/Chair/chair_mountable.glb', 'Vehicles/Ball/ball.entity.glb', LuminaThirdPersonContent.bundledMeshPath];

      // The real import, the Static Mesh editor's Mass, and PIE's resolver.
      final project = Directory.systemTemp.createTempSync('lumina_physics_smoke_');
      addTearDown(() => project.deleteSync(recursive: true));
      Directory('${project.path}/contents/meshes/static').createSync(recursive: true);
      final chairLmas = await _importWithMass(project.path, chairGlb, 23.0);
      final ballLmas = await _importWithMass(project.path, ballGlb, 15.0); // a 2.5 m inflatable
      LuminaBlueprintComponents.meshPhysicsResolver = (stored) => MeshPhysicsService.forMeshAsset(stored);
      addTearDown(() => LuminaBlueprintComponents.meshPhysicsResolver = null);
      final chairMesh = (await GlbParserService.parseGlb(chairGlb.readAsBytesSync()))!;
      final ballMesh = (await GlbParserService.parseGlb(ballGlb.readAsBytesSync()))!;
      // The sphere collider's radius (the largest half extent, cm); the mesh sits on it.
      final ballRadius = [for (var i = 0; i < 3; i++) (ballMesh.maxBounds[i] - ballMesh.minBounds[i]) * 50.0].reduce(math.max);

      const w = _Yard.w;
      const h = _Yard.h;
      final yard = _Yard();
      addTearDown(yard.dispose);
      final world = yard.world;

      // BP_Chair dropped from 150 cm, 3 m ahead of the player (authoring +Y).
      final chair = LuminaBlueprintClass.fromDocument(_propBlueprint(chairLmas, chairMesh, sphere: false), name: 'BP_Chair')
          .instantiate(location: LuminaAxes.location([0, 300, 150]));
      final chairBox = (chair as LuminaBlueprintRuntime).blueprintComponents['collider'] as LuminaBoxComponent;
      final overlay = LuminaStaticMeshComponent(
        meshAssetPath: 'smoke-physics:chair-collider',
        assetUnitScale: 1.0,
        castShadows: false,
        assetProvider: (_) async => _boxOverlayGlb(chairBox.boxExtent),
      );
      overlay.attachToComponent(chairBox);
      (chair as LuminaActor).addComponent(overlay);
      world.persistentLevel.registerActor(chair);

      final character = LuminaTemplateCharacter(
        thirdPerson: true,
        meshAssetPath: LuminaThirdPersonContent.bundledMeshPath,
        location: Vector3(0, LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight + 1, 0),
      );
      final pc = LuminaPlayerController()..possess(character);
      world.persistentLevel.registerActor(character);
      // BP_Ball: a giant inflatable resting on the yard, set in front of the
      // character once it is done with the chair (its sphere's bottom 1 cm up).
      final ball = LuminaBlueprintClass.fromDocument(
              _propBlueprint(ballLmas, ballMesh, sphere: true, restitution: 0.4, linearDamping: 1.0, angularDamping: 2.0),
              name: 'BP_Ball')
          .instantiate(location: Vector3(260 + ballRadius, 0, -240));
      final ballSphere = (ball as LuminaBlueprintRuntime).blueprintComponents['collider'] as LuminaSphereComponent;
      ball.actorLocation = ball.actorLocation + Vector3(0, ballRadius + 1 - ballSphere.worldLocation.y, 0);
      world.persistentLevel.registerActor(ball);
      world.beginPlay();
      final chairMeshComponent = chair.blueprintComponents['mesh'] as LuminaStaticMeshComponent;
      final ballMeshComponent = ball.blueprintComponents['mesh'] as LuminaStaticMeshComponent;
      await Future.wait([chairMeshComponent.loaded, ballMeshComponent.loaded, character.bodyMesh!.loaded, overlay.loaded]);
      final physics = world.getSubsystem<LuminaPhysicsSubsystem>()!;
      expect(chairBox.physicsBody, isNotNull);
      expect(chairBox.resolvedMassKg, closeTo(23.0, 1e-9), reason: 'inherited from SM chair_mountable.lmas');

      var lookingAtBall = false;
      // Frames the character and what it walks into (the chair, then the ball).
      Uint8List frame() {
        final other = lookingAtBall ? ballSphere.worldLocation : chairBox.worldLocation;
        final target = (character.actorLocation + other) * 0.5
          ..y = 60;
        final span = math.max(300.0, character.actorLocation.distanceTo(other)) + (lookingAtBall ? 2 * ballRadius : 0);
        return yard.shot(target + Vector3(0.55, 0.45, 0.75) * (span * 1.3), target);
      }

      final video = SmokeVideoRecorder(width: w, height: h, fps: 30, testName: testTitle);
      addTearDown(video.discard);
      final walk = LuminaInputActionValue.raw(InputValueType.axis2D, 0.0, 1.0, 0.0);
      double? landedAt;
      var restingTilt = 0.0;
      var peakTilt = 0.0;
      final ballStart = ballSphere.worldLocation;
      var maxBallTravel = 0.0;

      // 11 s at 60 Hz, a video frame every 2nd tick (30 fps, real time):
      // the chair falls and rests (0–1.5 s), the character walks into it and
      // tips it (1.5–4.5 s), then turns to the giant ball resting east of it,
      // which turns east (4.5–6 s), walks into it (6–7.8 s) and watches it
      // roll away on the grass (damped) until 11 s.
      const ticks = 660;
      for (var tick = 0; tick < ticks; tick++) {
        final t = tick / 60;
        if (t >= 1.5 && t < 4.5) character.onMove(walk);
        if (t >= 4.5 && !lookingAtBall) {
          // Rolled out in front of the character, east of where it stopped
          // (a teleport the ball's body follows).
          final at = character.actorLocation;
          ball.actorLocation = ball.actorLocation + Vector3(at.x + 120 + ballRadius - ballSphere.worldLocation.x, 0, at.z - ballSphere.worldLocation.z);
          ballStart.setFrom(Vector3(at.x + 120 + ballRadius, ballSphere.worldLocation.y, at.z));
          lookingAtBall = true;
        }
        if (t >= 4.5 && t < 6.0) pc.controlRotation.y = 90 * ((t - 4.5) / 1.5);
        if (t >= 6.0) {
          pc.controlRotation.y = 90;
          if (t < 7.8) character.onMove(walk);
        }
        pc.onTick(1 / 60);
        world.tick(1 / 60);

        final tilt = _tilt(chairBox.worldRotation);
        if (landedAt == null && (physics.bodies.isNotEmpty && !chairBox.physicsBody!.isAwake || t > 1.4)) landedAt = t;
        if (t < 1.5) restingTilt = tilt;
        peakTilt = math.max(peakTilt, tilt);
        maxBallTravel = math.max(maxBallTravel, ballSphere.worldLocation.distanceTo(ballStart));

        if (tick.isEven) video.addFrame(frame());
        if (tick == 85) {
          SmokeArtifacts.saveScreenshot('$testTitle 01 chair dropped and resting', SmokeArtifacts.encodePng(w, h, frame()),
              usedAssets: usedAssets);
        }
        if (tick == 269) {
          SmokeArtifacts.saveScreenshot('$testTitle 02 chair tipped by the character', SmokeArtifacts.encodePng(w, h, frame()),
              usedAssets: usedAssets);
        }
      }

      // ignore: avoid_print
      print('[physics smoke] ball at ${ballSphere.worldLocation} (travel ${maxBallTravel.toStringAsFixed(0)} cm), '
          'mesh loaded ${ballMeshComponent.isLoaded} at ${ballMeshComponent.worldLocation}, character ${character.actorLocation}');
      expect(ballMeshComponent.isLoaded, isTrue, reason: 'the ball is drawn');
      expect(landedAt, isNotNull);
      expect(restingTilt, lessThan(5), reason: 'the dropped chair lands upright and rests');
      expect(peakTilt, greaterThan(30), reason: 'walking into it tipped it (peak tilt $peakTilt°)');
      expect(maxBallTravel, greaterThan(100), reason: 'the ball rolled away ($maxBallTravel cm)');
      expect(chairBox.worldLocation.y, greaterThan(0), reason: 'the chair stays above the yard');
      expect(character.actorLocation.y, greaterThan(0), reason: 'the character is still on the yard');
      expect(ballSphere.worldLocation.y, greaterThan(0), reason: 'the ball is still on the yard');
      SmokeArtifacts.saveScreenshot('$testTitle 03 ball rolled away', SmokeArtifacts.encodePng(w, h, frame()), usedAssets: usedAssets);
      SmokeArtifacts.saveScreenshot(testTitle, SmokeArtifacts.encodePng(w, h, frame()), usedAssets: usedAssets);
      SmokeArtifacts.saveVideo(testTitle, video.finish(), usedAssets: usedAssets);
    }, timeout: const Timeout(Duration(minutes: 8)));
  });
}

double _tilt(Quaternion q) {
  final up = Vector3(0, 1, 0)..applyQuaternion(q);
  return math.acos(up.y.clamp(-1.0, 1.0)) * 180 / math.pi;
}
