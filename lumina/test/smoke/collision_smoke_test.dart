import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';

/// Test assets root (`$LUMINA_TEST_ASSETS`, see test-assets/FBX/README.md).
Directory get _testAssets => Directory(Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets');

/// A translucent green overlay of [hull]'s faces with bright edges — the
/// engine has no collision debug draw, so the smoke draws the
/// hull itself. Positions are the hull's
/// local frame (cm): the overlay draws with `assetUnitScale: 1`.
Uint8List _hullOverlayGlb(ConvexHullShape hull) {
  final positions = <double>[];
  final normals = <double>[];
  for (var t = 0; t < hull.triangles.length; t += 3) {
    final a = hull.vertices[hull.triangles[t]];
    final b = hull.vertices[hull.triangles[t + 1]];
    final cc = hull.vertices[hull.triangles[t + 2]];
    final n = (b - a).cross(cc - a)..normalize();
    for (final v in [a, b, cc]) {
      positions.addAll([v.x, v.y, v.z]);
      normals.addAll([n.x, n.y, n.z]);
    }
  }
  final edges = <int>[];
  final seen = <int>{};
  for (var t = 0; t < hull.triangles.length; t += 3) {
    for (var k = 0; k < 3; k++) {
      final i = t + k, j = t + (k + 1) % 3;
      final u = hull.triangles[i], v = hull.triangles[j];
      if (seen.add(math.min(u, v) * 100000 + math.max(u, v))) edges.addAll([i, j]);
    }
  }
  final vertexCount = positions.length ~/ 3;
  final pos = Float32List.fromList(positions).buffer.asUint8List();
  final nor = Float32List.fromList(normals).buffer.asUint8List();
  final tri = Uint32List.fromList(List<int>.generate(vertexCount, (i) => i)).buffer.asUint8List();
  final lin = Uint32List.fromList(edges).buffer.asUint8List();
  final bin = BytesBuilder()..add(pos)..add(nor)..add(tri)..add(lin);
  double bound(int axis, bool max) {
    var m = max ? -double.infinity : double.infinity;
    for (var i = axis; i < positions.length; i += 3) {
      m = max ? math.max(m, positions[i]) : math.min(m, positions[i]);
    }
    return m;
  }

  final json = <String, dynamic>{
    'asset': {'version': '2.0', 'generator': 'lumina collision smoke'},
    'extensionsUsed': ['KHR_materials_unlit'],
    'scene': 0,
    'scenes': [
      {'nodes': [0]},
    ],
    'nodes': [
      {'mesh': 0, 'name': 'CollisionHull'},
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
        'name': 'M_CollisionFaces',
        'alphaMode': 'BLEND',
        'doubleSided': true,
        'pbrMetallicRoughness': {'baseColorFactor': [0.15, 1.0, 0.35, 0.28], 'metallicFactor': 0.0, 'roughnessFactor': 1.0},
        'extensions': {'KHR_materials_unlit': <String, dynamic>{}},
      },
      {
        'name': 'M_CollisionEdges',
        'pbrMetallicRoughness': {'baseColorFactor': [0.3, 1.0, 0.4, 1.0], 'metallicFactor': 0.0, 'roughnessFactor': 1.0},
        'extensions': {'KHR_materials_unlit': <String, dynamic>{}},
      },
    ],
    'accessors': [
      {
        'bufferView': 0,
        'componentType': 5126,
        'count': vertexCount,
        'type': 'VEC3',
        'min': [bound(0, false), bound(1, false), bound(2, false)],
        'max': [bound(0, true), bound(1, true), bound(2, true)],
      },
      {'bufferView': 1, 'componentType': 5126, 'count': vertexCount, 'type': 'VEC3'},
      {'bufferView': 2, 'componentType': 5125, 'count': vertexCount, 'type': 'SCALAR'},
      {'bufferView': 3, 'componentType': 5125, 'count': edges.length, 'type': 'SCALAR'},
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

/// Bright unlit line segments (pairs of world-space points, cm) as a GLB:
/// how the smoke draws a shape collider's `buildWireframe`,
/// as the editor's debug draw would.
Uint8List _wireframeGlb(List<Vector3> segments, List<double> rgba) {
  final positions = <double>[];
  for (final v in segments) {
    positions.addAll([v.x, v.y, v.z]);
  }
  final vertexCount = positions.length ~/ 3;
  final pos = Float32List.fromList(positions).buffer.asUint8List();
  final idx = Uint32List.fromList(List<int>.generate(vertexCount, (i) => i)).buffer.asUint8List();
  final bin = BytesBuilder()..add(pos)..add(idx);
  double bound(int axis, bool max) {
    var m = max ? -double.infinity : double.infinity;
    for (var i = axis; i < positions.length; i += 3) {
      m = max ? math.max(m, positions[i]) : math.min(m, positions[i]);
    }
    return m;
  }

  final json = <String, dynamic>{
    'asset': {'version': '2.0', 'generator': 'lumina collision smoke'},
    'extensionsUsed': ['KHR_materials_unlit'],
    'scene': 0,
    'scenes': [
      {'nodes': [0]},
    ],
    'nodes': [
      {'mesh': 0, 'name': 'CollisionWireframe'},
    ],
    'meshes': [
      {
        'primitives': [
          {'attributes': {'POSITION': 0}, 'indices': 1, 'material': 0, 'mode': 1},
        ],
      },
    ],
    'materials': [
      {
        'name': 'M_CollisionWire',
        'pbrMetallicRoughness': {'baseColorFactor': rgba, 'metallicFactor': 0.0, 'roughnessFactor': 1.0},
        'extensions': {'KHR_materials_unlit': <String, dynamic>{}},
      },
    ],
    'accessors': [
      {
        'bufferView': 0,
        'componentType': 5126,
        'count': vertexCount,
        'type': 'VEC3',
        'min': [bound(0, false), bound(1, false), bound(2, false)],
        'max': [bound(0, true), bound(1, true), bound(2, true)],
      },
      {'bufferView': 1, 'componentType': 5125, 'count': vertexCount, 'type': 'SCALAR'},
    ],
    'bufferViews': [
      {'buffer': 0, 'byteOffset': 0, 'byteLength': pos.length, 'target': 34962},
      {'buffer': 0, 'byteOffset': pos.length, 'byteLength': idx.length, 'target': 34963},
    ],
    'buffers': [
      {'byteLength': pos.length + idx.length},
    ],
  };
  return GlbDocument(json, bin.takeBytes()).encode();
}

/// A lit Filament world on GPU 1 with a floor, the sun and imported props
/// built as Play-In-Editor builds them, their simple
/// collision drawn over them.
class _PropYard {
  static const w = SmokeVideo.defaultWidth;
  static const h = SmokeVideo.defaultHeight;

  _PropYard() {
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
    collision = world.registerSubsystem(LuminaCollisionSubsystem());
    world.bindView(view);
    // The level, authored Z-up in cm and converted as PIE and the generated
    // game convert it: a floor and the sun.
    world.persistentLevel.registerActor(LuminaPrimitiveActor(
      location: LuminaAxes.location([0, 0, -10]),
      shape: LuminaPrimitiveShape.box,
      size: Vector3(2400, 20, 2400),
      color: Vector3(0.52, 0.5, 0.47),
    ));
    world.persistentLevel.registerActor(LuminaActor(
      root: LuminaDirectionalLightComponent(rotation: LuminaAxes.rotation([-50, 0, -30]), intensity: 100000, castShadows: true),
    ));
  }

  late final FilamentEngine engine;
  late final FilamentScene scene;
  late final FilamentView view;
  late final FilamentRenderer renderer;
  late final FilamentSwapChain swapChain;
  late final FilamentCamera camera;
  late final LuminaWorld world;
  late final LuminaCollisionSubsystem collision;
  final ffi.Pointer<ffi.Uint8> _pixels = calloc<ffi.Uint8>(w * h * 4);

  /// A prop built from its mesh asset's simple collision, as PIE builds it,
  /// with every box and convex collider drawn where it is.
  LuminaStaticMeshActor prop(String lmas, List<double> location, double yaw) {
    final simple = MeshCollisionService.simpleCollisionForMeshAsset(lmas);
    final actor = LuminaStaticMeshActor(
      meshAssetPath: lmas,
      location: LuminaAxes.location(location),
      rotation: LuminaAxes.rotation([0, 0, yaw]),
      collisionHulls: simple.hulls,
      collisionPrimitives: simple.primitives,
    );
    var n = 0;
    for (final c in actor.collisionComponents) {
      final ConvexHullShape shape;
      switch (c.shapeType) {
        case CollisionShapeType.convex:
          shape = c.convexHull!;
        case CollisionShapeType.box:
          final e = c.boxExtent;
          shape = ConvexHullShape([
            for (var i = 0; i < 8; i++) Vector3(i & 1 == 0 ? -e.x : e.x, i & 2 == 0 ? -e.y : e.y, i & 4 == 0 ? -e.z : e.z),
          ]);
        default:
          continue;
      }
      final overlay = _hullOverlayGlb(shape);
      actor.addComponent(LuminaStaticMeshComponent(
        meshAssetPath: 'smoke-collision:$lmas:${n++}',
        location: c.relativeLocation.clone(),
        rotation: c.relativeRotation,
        scale: c.relativeScale.clone(),
        assetUnitScale: 1.0,
        castShadows: false,
        assetProvider: (_) async => overlay,
      ));
    }
    world.persistentLevel.registerActor(actor);
    return actor;
  }

  /// The Third Person mannequin at the origin, possessed.
  (LuminaTemplateCharacter, LuminaPlayerController) character() {
    final character = LuminaTemplateCharacter(
      thirdPerson: true,
      meshAssetPath: LuminaThirdPersonContent.bundledMeshPath,
      location: Vector3(0, LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight + 1, 0),
    );
    final pc = LuminaPlayerController()..possess(character);
    world.persistentLevel.registerActor(character);
    return (character, pc);
  }

  /// A side view of [character] and what it walks into, orbiting with it as
  /// it turns; one frame read back.
  Uint8List shot(
    LuminaCharacter character,
    LuminaPlayerController pc, {
    double ahead = 120,
    double side = 400,
    double up = 140,
    double lookAhead = 140,
  }) {
    final yaw = pc.controlRotation.y * math.pi / 180;
    final forward = Vector3(math.sin(yaw), 0, -math.cos(yaw));
    final right = Vector3(math.cos(yaw), 0, math.sin(yaw));
    final at = character.actorLocation;
    final eye = at + forward * ahead + right * side + Vector3(0, up, 0);
    final target = at + forward * lookAhead + Vector3(0, 10, 0);
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

/// The tick Scenario 07 is on, for its overlap log.
int ticksRun = 0;

void main() {
  group('Collision Module Smoke Tests', () {
    test('Scenario 01: 5 collision shape primitives, AABB derivation, and capsule segment caching', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final rootActor = LuminaActor();

      final sphere = LuminaCollisionComponent(shapeType: CollisionShapeType.sphere, radius: 1.0);
      final box = LuminaCollisionComponent(shapeType: CollisionShapeType.box)..boxExtent = Vector3(2.0, 1.0, 3.0);
      final capsule = LuminaCapsuleComponent(radius: 0.5, halfHeight: 1.5);
      final cone = LuminaCollisionComponent(shapeType: CollisionShapeType.cone, radius: 1.0)..height = 3.0;
      final cylinder = LuminaCollisionComponent(shapeType: CollisionShapeType.cylinder, radius: 0.8)..height = 2.4;

      rootActor.addComponent(sphere);
      rootActor.addComponent(box);
      rootActor.addComponent(capsule);
      rootActor.addComponent(cone);
      rootActor.addComponent(cylinder);

      world.persistentLevel.registerActor(rootActor);
      world.beginPlay();

      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      // Assert AABB and shape descriptors
      expect(sphere.worldShape, isA<SphereShape>());
      expect(box.worldShape, isA<BoxShape>());
      expect(capsule.worldShape, isA<CapsuleShape>());
      expect(cone.worldShape, isA<ConeShape>());
      expect(cylinder.worldShape, isA<CylinderShape>());

      expect(sphere.getAABB().min, equals(Vector3(-1.0, -1.0, -1.0)));
      expect(sphere.getAABB().max, equals(Vector3(1.0, 1.0, 1.0)));

      expect(capsule.segmentStart.y, closeTo(-1.0, 1e-6));
      expect(capsule.segmentEnd.y, closeTo(1.0, 1e-6));

      final wireframe = capsule.buildCapsuleWireframe(segments: 8);
      expect(wireframe, isNotEmpty);

      final usedAssets = [
        'Props/AC_units/ac_unit_a_300x300.glb',
        'Props/Barrels/dented_barrel.glb',
      ];

      const testTitle = 'Collision Module Smoke Tests Scenario 01: 5 collision shape primitives, AABB derivation, and capsule segment caching';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.length < 2) return;
          final tm = FilamentTransformManager(engine);

          for (int i = 0; i < 2; i++) {
            final xOffset = (i == 0) ? -1.2 : 1.2;
            final rotSpeed = (i == 0) ? 1.0 : -1.2;
            final bob = math.sin(timeSeconds * 2.0 + i * math.pi) * 0.15;

            final aabb = assets[i].getBoundingBox();
            final s = aabb.max - aabb.min;
            final maxDim = math.max(s.x, math.max(s.y, s.z));
            final scale = maxDim > 0 ? 1.1 / maxDim : 1.0;

            final mat = Matrix4.identity()
              ..setTranslationRaw(xOffset, -aabb.min.y * scale + bob, 0.0)
              ..rotateY(timeSeconds * rotSpeed)
              ..scaleByDouble(scale, scale, scale, 1.0);
            tm.setTransform(assets[i].rootEntity, mat.storage.toList());
          }

          cam.lookAt(
            eyeX: math.sin(timeSeconds * 0.5) * 3.2,
            eyeY: 1.5,
            eyeZ: math.cos(timeSeconds * 0.5) * 3.2,
            centerX: 0.0,
            centerY: 0.6,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
    });

    test('Scenario 02: 32-bit layer masks, object types, and response matrix resolution', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final wall = LuminaCollisionComponent(shapeType: CollisionShapeType.box);
      final player = LuminaCapsuleComponent();
      final trigger = LuminaCollisionComponent(shapeType: CollisionShapeType.sphere);

      CollisionProfile.applyBlockAll(wall);
      wall.objectType = CollisionObjectType.worldStatic;

      CollisionProfile.applyPawn(player);

      CollisionProfile.applyOverlapAll(trigger);

      world.persistentLevel.registerActor(LuminaActor()..addComponent(wall));
      world.persistentLevel.registerActor(LuminaActor()..addComponent(player));
      world.persistentLevel.registerActor(LuminaActor()..addComponent(trigger));

      world.beginPlay();

      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      // Player vs Wall -> Block
      expect(effectiveResponse(player, wall), equals(CollisionResponse.block));

      // Player vs Trigger -> Overlap
      expect(effectiveResponse(player, trigger), equals(CollisionResponse.overlap));

      // Layer filtering: isolate trigger on layer 5 with mask targeting only layer 5
      trigger.setLayer(5);
      trigger.collisionLayerMask = CollisionLayers.layer(5);

      // Player is on layer 1 -> layer filter fails -> Ignore
      expect(effectiveResponse(player, trigger), equals(CollisionResponse.ignore));

      final usedAssets = [
        'Props/Barrels/fuel_barrel_black.glb',
        'Props/Barrels/fuel_barrel_red.glb',
      ];

      const testTitle = 'Collision Module Smoke Tests Scenario 02: 32-bit layer masks, object types, and response matrix resolution';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.length < 2) return;
          final tm = FilamentTransformManager(engine);

          // Moving actor (Asset 0) approaches wall (Asset 1) at x=1.0 and bounces back
          final loopT = (timeSeconds % 4.0) / 4.0;
          double moveX = 0.0;
          if (loopT < 0.5) {
            moveX = -1.8 + (loopT / 0.5) * 2.0; // reaches 0.2
          } else {
            moveX = 0.2 - ((loopT - 0.5) / 0.5) * 2.0; // rebounds
          }

          final aabb0 = assets[0].getBoundingBox();
          final s0 = aabb0.max - aabb0.min;
          final max0 = math.max(s0.x, math.max(s0.y, s0.z));
          final scale0 = max0 > 0 ? 1.0 / max0 : 1.0;
          final mat0 = Matrix4.identity()
            ..setTranslationRaw(moveX, -aabb0.min.y * scale0, 0.0)
            ..scaleByDouble(scale0, scale0, scale0, 1.0);
          tm.setTransform(assets[0].rootEntity, mat0.storage.toList());

          // Wall (Asset 1) at (1.0, 0, 0)
          final aabb1 = assets[1].getBoundingBox();
          final s1 = aabb1.max - aabb1.min;
          final max1 = math.max(s1.x, math.max(s1.y, s1.z));
          final scale1 = max1 > 0 ? 1.2 / max1 : 1.0;
          final mat1 = Matrix4.identity()
            ..setTranslationRaw(1.0, -aabb1.min.y * scale1, 0.0)
            ..scaleByDouble(scale1, scale1, scale1, 1.0);
          tm.setTransform(assets[1].rootEntity, mat1.storage.toList());

          cam.lookAt(
            eyeX: 0.0,
            eyeY: 1.8,
            eyeZ: 3.5,
            centerX: 0.0,
            centerY: 0.5,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
    });

    test('Scenario 03: Analytic collision pairs, GJK/EPA solver, and raycast math in active world', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);

      final sphereA = SphereShape(1.0);
      final sphereB = SphereShape(1.0);
      final tA = Matrix4.translation(Vector3(0.0, 0.0, 0.0));
      final tB = Matrix4.translation(Vector3(1.2, 0.0, 0.0));

      final contact = ContactResult();
      final hitSphere = testPair(sphereA, tA, sphereB, tB, contact);
      expect(hitSphere, isTrue);
      expect(contact.penetrationDepth, closeTo(0.8, 1e-4));

      final cone = ConeShape(1.0, 2.0);
      final box = BoxShape(Vector3(1.0, 1.0, 1.0));
      final tCone = Matrix4.translation(Vector3(0.0, 0.0, 0.0));
      final tBox = Matrix4.translation(Vector3(0.5, 0.5, 0.0));

      final hitConvex = testPair(cone, tCone, box, tBox, contact);
      expect(hitConvex, isTrue);
      expect(contact.penetrationDepth, greaterThan(0.0));

      final rayHit = rayVsCapsule(
        Vector3(0.0, 10.0, 0.0),
        Vector3(0.0, -1.0, 0.0),
        Vector3(0.0, -1.0, 0.0),
        Vector3(0.0, 1.0, 0.0),
        0.5,
      );
      expect(rayHit, isNotNull);
      expect(rayHit!, closeTo(8.5, 1e-6)); // 10 - 1.5 = 8.5

      world.beginPlay();
      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      final usedAssets = [
        'Props/Banana Bunch/banana_bunch_short.glb',
        'Props/Access_cards/access_card_red.glb',
      ];

      const testTitle = 'Collision Module Smoke Tests Scenario 03: Analytic collision pairs, GJK/EPA solver, and raycast math in active world';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.length < 2) return;
          final tm = FilamentTransformManager(engine);

          // Dynamic impact collision simulation between Asset 0 and Asset 1
          final impactT = (timeSeconds % 3.0) / 3.0;
          double d0 = 0.0;
          double d1 = 0.0;

          if (impactT < 0.5) {
            // Approach
            final p = impactT / 0.5;
            d0 = -1.5 + p * 1.0;
            d1 = 1.5 - p * 1.0;
          } else {
            // Rebound after collision impact
            final p = (impactT - 0.5) / 0.5;
            d0 = -0.5 - p * 1.0;
            d1 = 0.5 + p * 1.0;
          }

          for (int i = 0; i < 2; i++) {
            final x = (i == 0) ? d0 : d1;
            final aabb = assets[i].getBoundingBox();
            final s = aabb.max - aabb.min;
            final maxDim = math.max(s.x, math.max(s.y, s.z));
            final scale = maxDim > 0 ? 0.9 / maxDim : 1.0;

            final mat = Matrix4.identity()
              ..setTranslationRaw(x, -aabb.min.y * scale, 0.0)
              ..rotateY((i == 0 ? 1 : -1) * timeSeconds * 1.5)
              ..scaleByDouble(scale, scale, scale, 1.0);
            tm.setTransform(assets[i].rootEntity, mat.storage.toList());
          }

          cam.lookAt(
            eyeX: 0.0,
            eyeY: 1.5,
            eyeZ: 2.8,
            centerX: 0.0,
            centerY: 0.4,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
    });

    test('Scenario 04: Collision Subsystem broadphase, overlap/hit events, and raycast/sweep queries', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final collisionSubsystem = LuminaCollisionSubsystem();
      world.subsystems.registerSubsystem<LuminaCollisionSubsystem>(collisionSubsystem, world);

      final pawn = LuminaCapsuleComponent(radius: 0.4, halfHeight: 0.9)
        ..location = Vector3(0.0, 0.0, 0.0);
      CollisionProfile.applyPawn(pawn);

      final trigger = LuminaCollisionComponent(shapeType: CollisionShapeType.sphere, radius: 1.5)
        ..location = Vector3(0.5, 0.0, 0.0);
      CollisionProfile.applyOverlapAll(trigger);

      final wall = LuminaCollisionComponent(shapeType: CollisionShapeType.box)
        ..boxExtent = Vector3(1.0, 2.0, 1.0)
        ..location = Vector3(0.0, 0.0, 2.0);
      CollisionProfile.applyBlockAll(wall);
      wall.objectType = CollisionObjectType.worldStatic;

      collisionSubsystem.register(pawn);
      collisionSubsystem.register(trigger);
      collisionSubsystem.register(wall);

      bool overlapFired = false;
      pawn.onComponentBeginOverlap = (self, other) {
        if (other == trigger) overlapFired = true;
      };

      world.beginPlay();

      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      expect(overlapFired, isTrue);

      final rayHit = HitResult();
      final hitWall = collisionSubsystem.raycast(
        Vector3(0.0, 0.0, -5.0),
        Vector3(0.0, 0.0, 1.0),
        20.0,
        rayHit,
        layerMask: CollisionLayers.layer(1),
      );
      expect(hitWall, isTrue);

      final usedAssets = [
        'Props/Barrels/fuel_barrel_black.glb',
        'Props/AC_units/ac_unit_b_600x600.glb',
      ];

      const testTitle = 'Collision Module Smoke Tests Scenario 04: Collision Subsystem broadphase, overlap/hit events, and raycast/sweep queries';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.length < 2) return;
          final tm = FilamentTransformManager(engine);

          // Moving pawn (Asset 0) circles around stationary wall (Asset 1)
          final pawnAngle = timeSeconds * 1.2;
          final pawnX = math.sin(pawnAngle) * 1.5;
          final pawnZ = math.cos(pawnAngle) * 1.5;

          final aabb0 = assets[0].getBoundingBox();
          final s0 = aabb0.max - aabb0.min;
          final max0 = math.max(s0.x, math.max(s0.y, s0.z));
          final scale0 = max0 > 0 ? 0.9 / max0 : 1.0;
          final mat0 = Matrix4.identity()
            ..setTranslationRaw(pawnX, -aabb0.min.y * scale0, pawnZ)
            ..rotateY(pawnAngle + math.pi / 2.0)
            ..scaleByDouble(scale0, scale0, scale0, 1.0);
          tm.setTransform(assets[0].rootEntity, mat0.storage.toList());

          // Stationary wall (Asset 1) at center (0, 0, 0)
          final aabb1 = assets[1].getBoundingBox();
          final s1 = aabb1.max - aabb1.min;
          final max1 = math.max(s1.x, math.max(s1.y, s1.z));
          final scale1 = max1 > 0 ? 1.2 / max1 : 1.0;
          final mat1 = Matrix4.identity()
            ..setTranslationRaw(0.0, -aabb1.min.y * scale1, 0.0)
            ..scaleByDouble(scale1, scale1, scale1, 1.0);
          tm.setTransform(assets[1].rootEntity, mat1.storage.toList());

          cam.lookAt(
            eyeX: math.sin(timeSeconds * 0.4) * 3.5,
            eyeY: 2.5,
            eyeZ: math.cos(timeSeconds * 0.4) * 3.5,
            centerX: 0.0,
            centerY: 0.5,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
    });
    // Imported FBX props collide by their UCX_ hulls.
    test('Scenario 05: a character walks into imported FBX props and their UCX hulls stop it', () async {
      const testTitle = 'Collision Module Smoke Tests Scenario 05: a character walks into imported FBX props and their UCX hulls stop it';
      final chairFbx = File('${_testAssets.path}/FBX/StaticMeshes/SM_Casino_Chair.FBX');
      final slotFbx = File('${_testAssets.path}/FBX/StaticMeshes/SM_Slot_Machine.FBX');
      final mannequin = File(LuminaThirdPersonContent.bundledMeshPath);
      if (!chairFbx.existsSync() || !slotFbx.existsSync()) return markTestSkipped('test-assets/FBX missing');
      if (!mannequin.existsSync()) return markTestSkipped('build tool/build_third_person_content.dart first');
      const usedAssets = [
        'FBX/StaticMeshes/SM_Casino_Chair.FBX',
        'FBX/StaticMeshes/SM_Slot_Machine.FBX',
        LuminaThirdPersonContent.bundledMeshPath,
      ];

      // The real import pipeline, into a temp project.
      final project = Directory.systemTemp.createTempSync('lumina_collision_smoke_ucx_');
      addTearDown(() => project.deleteSync(recursive: true));
      Directory('${project.path}/contents/meshes/static').createSync(recursive: true);
      for (final fbx in [chairFbx, slotFbx]) {
        final imported = await ImportAssetUseCase()(projectDir: project.path, sourceFilePath: fbx.path);
        expect(imported.isSuccess, isTrue, reason: imported.error);
      }
      final chairLmas = '${project.path}/contents/meshes/static/SM_Casino_Chair.lmas';
      final slotLmas = '${project.path}/contents/meshes/static/SM_Slot_Machine.lmas';

      const w = _PropYard.w;
      const h = _PropYard.h;
      final yard = _PropYard();
      addTearDown(yard.dispose);
      final world = yard.world;
      final collision = yard.collision;

      // The chair 4.5 m ahead of the player start and the slot machine to
      // its right, both built from their hulls as Play-In-Editor builds them.
      final chair = yard.prop(chairLmas, [0, 450, 0], 0);
      final slot = yard.prop(slotLmas, [700, 390, 0], -90);
      expect(chair.collisionComponents, hasLength(4), reason: 'pedestal, foot ring, seat, back');
      expect(slot.collisionComponents, hasLength(5));

      final (character, pc) = yard.character();
      world.beginPlay();
      await Future.wait([
        chair.meshComponent.loaded,
        slot.meshComponent.loaded,
        character.bodyMesh!.loaded,
        for (final a in [chair, slot])
          for (final m in a.components.whereType<LuminaStaticMeshComponent>()) m.loaded,
      ]);

      final radius = character.capsuleComponent.radius;
      Uint8List shot() => yard.shot(character, pc);

      final video = SmokeVideoRecorder(width: w, height: h, fps: 30, testName: testTitle);
      addTearDown(video.discard);
      final hulls = [...chair.collisionComponents, ...slot.collisionComponents];
      final overlaps = <LuminaCollisionComponent>[];
      final walk = LuminaInputActionValue.raw(InputValueType.axis2D, 0.0, 1.0, 0.0);
      final track = <double>[];

      // 11 s at 60 Hz, every 2nd tick a video frame (30 fps, real time):
      // 0.5 s idle, 4 s walking north into the chair, a 1.5 s turn right,
      // 5 s walking east into the slot machine.
      const ticks = 660;
      for (var tick = 0; tick < ticks; tick++) {
        final t = tick / 60;
        if (t >= 4.5 && t < 6.0) pc.controlRotation.y = 90 * ((t - 4.5) / 1.5);
        if (t >= 6.0) pc.controlRotation.y = 90;
        if (t >= 0.5 && (t < 4.5 || t >= 6.0)) character.onMove(walk);
        pc.onTick(1 / 60);
        world.tick(1 / 60);

        collision.overlapTest(character.capsuleComponent.worldShape, character.capsuleComponent.worldTransform, overlaps,
            ignore: character.capsuleComponent);
        expect(overlaps.where(hulls.contains), isEmpty, reason: 't=${t.toStringAsFixed(2)} s: the capsule is inside a hull');
        track.add(t < 5 ? character.actorLocation.z : character.actorLocation.x);

        if (tick.isEven) video.addFrame(shot());
        if (tick == 30) {
          SmokeArtifacts.saveScreenshot('$testTitle 01 start', SmokeArtifacts.encodePng(w, h, shot()), usedAssets: usedAssets);
        }
        if (tick == 269) {
          SmokeArtifacts.saveScreenshot('$testTitle 02 stopped by the chair', SmokeArtifacts.encodePng(w, h, shot()),
              usedAssets: usedAssets);
        }
      }

      // Stopped at the chair: the last 1.5 s of walking north moved it by
      // less than a centimetre, touching (not inside) one of its hulls.
      final chairStop = track[269];
      expect((track[269] - track[180]).abs(), lessThan(1.0), reason: 'still pushing into the chair, not moving');
      expect(chairStop, lessThan(-300), reason: 'it walked up to the chair (z $chairStop)');
      final chairBox = chair.collisionComponents.map((c) => c.getAABB()).reduce((a, b) => Aabb3.copy(a)..hull(b));
      expect(chairStop - radius, greaterThan(chairBox.min.z), reason: 'in front of the chair, not through it');
      // At the slot machine, the same.
      final slotStop = track.last;
      expect((track.last - track[ticks - 90]).abs(), lessThan(1.0), reason: 'still pushing into the slot machine, not moving');
      expect(slotStop, greaterThan(450), reason: 'it walked east up to the slot machine (x $slotStop)');
      final slotBox = slot.collisionComponents.map((c) => c.getAABB()).reduce((a, b) => Aabb3.copy(a)..hull(b));
      expect(slotStop + radius, lessThan(slotBox.max.x), reason: 'in front of the slot machine, not through it');
      bool touching(Vector3 dir) {
        final probe = character.capsuleComponent.worldTransform..setTranslation(character.capsuleComponent.worldLocation + dir * 2.0);
        final contact = ContactResult();
        return slot.collisionComponents.any((c) => testPair(character.capsuleComponent.worldShape, probe, c.worldShape, c.worldTransform, contact));
      }

      expect(touching(Vector3(1, 0, 0)), isTrue, reason: 'within 2 cm of a slot machine hull');
      expect(character.actorLocation.y, closeTo(LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight, 2), reason: 'on the floor');

      SmokeArtifacts.saveScreenshot(testTitle, SmokeArtifacts.encodePng(w, h, shot()), usedAssets: usedAssets);
      SmokeArtifacts.saveVideo(testTitle, video.finish(), usedAssets: usedAssets);
    }, timeout: const Timeout(Duration(minutes: 6)));

    // The Static Mesh editor's authored box is a prop's simple
    // collision — on a prop with no UCX_ hull at all.
    test('Scenario 06: a character is stopped by the box authored for an imported prop with no UCX hull', () async {
      const testTitle = 'Collision Module Smoke Tests Scenario 06: a character is stopped by the box authored for an imported prop with no UCX hull';
      final counterFbx = File('${_testAssets.path}/FBX/StaticMeshes/SM_Counter_1.FBX');
      final mannequin = File(LuminaThirdPersonContent.bundledMeshPath);
      if (!counterFbx.existsSync()) return markTestSkipped('test-assets/FBX missing');
      if (!mannequin.existsSync()) return markTestSkipped('build tool/build_third_person_content.dart first');
      const usedAssets = ['FBX/StaticMeshes/SM_Counter_1.FBX', LuminaThirdPersonContent.bundledMeshPath];

      final project = Directory.systemTemp.createTempSync('lumina_collision_smoke_authored_');
      addTearDown(() => project.deleteSync(recursive: true));
      Directory('${project.path}/contents/meshes/static').createSync(recursive: true);
      final imported = await ImportAssetUseCase()(projectDir: project.path, sourceFilePath: counterFbx.path);
      expect(imported.isSuccess, isTrue, reason: imported.error);
      final lmas = '${project.path}/${imported.asset!.relativePath}';
      expect(MeshCollisionService.simpleCollisionForMeshAsset(lmas).isEmpty, isTrue, reason: 'SM_Counter_1 has no UCX_ hull');

      // The Static Mesh editor's Box Collision, saved as the editor saves it:
      // the mesh's bounds, cm, Z up, marked.
      final mesh = (await AssetRepository.loadMeshFromDisk(lmas))!;
      final a = MeshCollisionService.toAuthoring(mesh.minBounds[0], mesh.minBounds[1], mesh.minBounds[2]);
      final b = MeshCollisionService.toAuthoring(mesh.maxBounds[0], mesh.maxBounds[1], mesh.maxBounds[2]);
      final lo = [for (var i = 0; i < 3; i++) math.min(a[i], b[i])];
      final hi = [for (var i = 0; i < 3; i++) math.max(a[i], b[i])];
      final asset = LuminaAsset.fromBytes(File(lmas).readAsBytesSync());
      File(lmas).writeAsBytesSync(LuminaAsset(
        assetId: asset.assetId,
        name: asset.name,
        type: asset.type,
        hasThumbnail: asset.hasThumbnail,
        thumbnailPng: asset.thumbnailPng,
        rawPayload: asset.rawPayload,
        references: asset.references,
        metadata: {
          ...asset.metadata,
          'collision': jsonEncode({
            'world_units': 'cm',
            'up_axis': 'z',
            'complexity': 'default',
            'shapes': [
              {
                'type': 'box',
                'center': [for (var i = 0; i < 3; i++) (lo[i] + hi[i]) / 2],
                'extents': [for (var i = 0; i < 3; i++) (hi[i] - lo[i]) / 2],
              },
            ],
          }),
        },
      ).toProtoBufferBytes());

      const w = _PropYard.w;
      const h = _PropYard.h;
      final yard = _PropYard();
      addTearDown(yard.dispose);
      final world = yard.world;

      // The counter 3.5 m ahead (authored +Y), its 8.1 m length across the
      // character's path. Its origin is at its west end, so it is placed
      // 4.06 m west to meet the character half way along.
      final counter = yard.prop(lmas, [-406, 350, 0], 0);
      expect(counter.collisionHulls, isEmpty);
      final box = counter.collisionComponents.single;
      expect(box.shapeType, CollisionShapeType.box);
      final (character, pc) = yard.character();
      world.beginPlay();
      await Future.wait([
        counter.meshComponent.loaded,
        character.bodyMesh!.loaded,
        for (final m in counter.components.whereType<LuminaStaticMeshComponent>()) m.loaded,
      ]);
      // Its near face (runtime +z side) is the drawn counter's front.
      final face = box.getAABB().max.z;
      var drawnFront = -double.infinity;
      for (var i = 0; i < 8; i++) {
        final corner = counter.meshComponent.renderTransform.transform3(Vector3(
          i & 1 == 0 ? mesh.minBounds[0] : mesh.maxBounds[0],
          i & 2 == 0 ? mesh.minBounds[1] : mesh.maxBounds[1],
          i & 4 == 0 ? mesh.minBounds[2] : mesh.maxBounds[2],
        ));
        drawnFront = math.max(drawnFront, corner.z);
      }
      expect(face, closeTo(drawnFront, 0.5));
      final radius = character.capsuleComponent.radius;
      final skin = character.characterMovement.skinWidth;
      // Behind the character and to its left, above the counter's top.
      Uint8List shot() => yard.shot(character, pc, ahead: -330, side: -260, up: 230, lookAhead: 170);

      final video = SmokeVideoRecorder(width: w, height: h, fps: 30, testName: testTitle);
      addTearDown(video.discard);
      final overlaps = <LuminaCollisionComponent>[];
      final walk = LuminaInputActionValue.raw(InputValueType.axis2D, 0.0, 1.0, 0.0);
      final zs = <double>[];
      final xs = <double>[];

      // 11 s at 60 Hz, every 2nd tick a video frame (30 fps, real time):
      // 0.5 s idle, 3.5 s walking north into the counter, 1 s turning 25°
      // left while pushing, 3 s sliding west along the box, 3 s standing.
      const ticks = 660;
      for (var tick = 0; tick < ticks; tick++) {
        final t = tick / 60;
        if (t >= 4.0 && t < 5.0) pc.controlRotation.y = -25 * (t - 4.0);
        if (t >= 0.5 && t < 8.0) character.onMove(walk);
        pc.onTick(1 / 60);
        world.tick(1 / 60);
        yard.collision.overlapTest(character.capsuleComponent.worldShape, character.capsuleComponent.worldTransform, overlaps,
            ignore: character.capsuleComponent);
        expect(overlaps, isNot(contains(box)), reason: 't=${t.toStringAsFixed(2)} s: the capsule is inside the authored box');
        zs.add(character.actorLocation.z);
        xs.add(character.actorLocation.x);
        if (tick.isEven) video.addFrame(shot());
        if (tick == 30) {
          SmokeArtifacts.saveScreenshot('$testTitle 01 start', SmokeArtifacts.encodePng(w, h, shot()),
              usedAssets: usedAssets);
        }
        if (tick == 230) {
          SmokeArtifacts.saveScreenshot('$testTitle 02 stopped by the authored box',
              SmokeArtifacts.encodePng(w, h, shot()), usedAssets: usedAssets);
        }
      }

      // Stopped at the near face while pushing north…
      expect(zs[235], closeTo(face + radius + skin, 1.0), reason: 'against the box, z ${zs[235]}');
      expect((zs[235] - zs[160]).abs(), lessThan(1.0), reason: 'still pushing into it, not moving');
      // …then slid west along it, never through it.
      expect(xs[479] - xs[300], lessThan(-150), reason: 'slid ${xs[479] - xs[300]} cm along the counter');
      for (var i = 300; i < 480; i++) {
        expect(zs[i], greaterThan(face + radius - 1.0), reason: 'tick $i: stays in front of the box');
      }
      expect(character.actorLocation.y, closeTo(LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight, 2), reason: 'on the floor');

      SmokeArtifacts.saveScreenshot(testTitle, SmokeArtifacts.encodePng(w, h, shot()), usedAssets: usedAssets);
      SmokeArtifacts.saveVideo(testTitle, video.finish(), usedAssets: usedAssets);
    }, timeout: const Timeout(Duration(minutes: 6)));

    // Shape colliders with presets — a Trigger sphere the pawn
    // walks through (overlap events) and a Block All box wall that stops it.
    test('Scenario 07: shape colliders and presets: a trigger sphere logs the pawn and a box wall stops it', () async {
      const testTitle = 'Collision Module Smoke Tests Scenario 07: shape colliders and presets: a trigger sphere logs the pawn and a box wall stops it';
      final mannequin = File(LuminaThirdPersonContent.bundledMeshPath);
      if (!mannequin.existsSync()) return markTestSkipped('build tool/build_third_person_content.dart first');
      const usedAssets = [LuminaThirdPersonContent.bundledMeshPath];

      const w = _PropYard.w;
      const h = _PropYard.h;
      final yard = _PropYard();
      addTearDown(yard.dispose);
      final world = yard.world;

      // A trigger sphere 3 m ahead, a pickup-style overlap cylinder to its
      // right, and a block-all box wall 7 m ahead — built as the Blueprint
      // component mapping builds them from their collision JSON.
      final props = LuminaActor(location: Vector3.zero());
      final built = LuminaBlueprintComponents.construct(props, [
        LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
        LuminaBlueprintComponent(
            id: 'trigger', name: 'TriggerSphere', type: 'LuminaSphereComponent', parentId: 'root',
            properties: {'radius': 120.0, 'preset': 'Trigger', 'location': [0.0, 300.0, 90.0]}),
        LuminaBlueprintComponent(
            id: 'pickup', name: 'PickupCylinder', type: 'LuminaCylinderComponent', parentId: 'root',
            properties: {'radius': 40.0, 'halfHeight': 60.0, 'preset': 'OverlapAll', 'location': [160.0, 300.0, 60.0]}),
        LuminaBlueprintComponent(
            id: 'wall', name: 'Wall', type: 'LuminaBoxComponent', parentId: 'root',
            properties: {'boxExtent': [300.0, 20.0, 100.0], 'preset': 'BlockAll', 'location': [0.0, 700.0, 100.0]}),
        LuminaBlueprintComponent(
            id: 'cone', name: 'Cone', type: 'LuminaConeComponent', parentId: 'root',
            properties: {'radius': 50.0, 'halfHeight': 70.0, 'preset': 'BlockAllDynamic', 'location': [-180.0, 500.0, 70.0]}),
      ]);
      world.persistentLevel.registerActor(props);
      final trigger = built['trigger'] as LuminaSphereComponent;
      final wall = built['wall'] as LuminaBoxComponent;
      expect(trigger.preset, LuminaCollisionPreset.trigger);
      expect(wall.preset, LuminaCollisionPreset.blockAll);
      expect(trigger.worldLocation, Vector3(0, 90, -300));

      // Their wireframes, drawn through the world's debug shapes and as
      // unlit lines so the frame shows them.
      final wireColors = <String, List<double>>{
        'trigger': [0.2, 1.0, 0.4, 1.0],
        'pickup': [0.3, 0.8, 1.0, 1.0],
        'wall': [1.0, 0.35, 0.25, 1.0],
        'cone': [1.0, 0.9, 0.2, 1.0],
      };
      for (final entry in wireColors.entries) {
        final c = built[entry.key] as LuminaCollisionComponent;
        final glb = _wireframeGlb(c.buildWireframe(segments: 24), entry.value);
        world.persistentLevel.registerActor(LuminaActor(
          root: LuminaStaticMeshComponent(
            meshAssetPath: 'smoke-collision:wire:${entry.key}',
            assetUnitScale: 1.0,
            castShadows: false,
            assetProvider: (_) async => glb,
          ),
        ));
        world.addDebugShape(LuminaDebugShape(
          kind: c is LuminaBoxComponent ? LuminaDebugShapeKind.box : LuminaDebugShapeKind.sphere,
          points: [c.worldLocation],
          radius: c.radius,
          extent: c is LuminaBoxComponent ? c.boxExtent : null,
          rotation: c.worldRotation,
          color: entry.value,
          duration: 60,
          expiresAt: double.infinity,
        ));
      }
      expect(world.debugShapes, hasLength(4));

      final (character, pc) = yard.character();
      final log = <String>[];
      trigger.onComponentBeginOverlap = (_, other) => log.add('begin ${other.owner?.runtimeType} at t=${(ticksRun / 60).toStringAsFixed(2)}');
      trigger.onComponentEndOverlap = (_, other) => log.add('end ${other.owner?.runtimeType} at t=${(ticksRun / 60).toStringAsFixed(2)}');
      world.beginPlay();
      await Future.wait([character.bodyMesh!.loaded, for (final m in world.persistentLevel.actors.expand((a) => a.components).whereType<LuminaStaticMeshComponent>()) m.loaded]);
      expect(character.capsuleComponent.objectType, CollisionObjectType.pawn);

      Uint8List shot() => yard.shot(character, pc, side: 520, up: 220, ahead: 200, lookAhead: 260);
      final video = SmokeVideoRecorder(width: w, height: h, fps: 30, testName: testTitle);
      addTearDown(video.discard);
      final walk = LuminaInputActionValue.raw(InputValueType.axis2D, 0.0, 1.0, 0.0);
      final track = <double>[];

      // 11 s at 60 Hz: 0.5 s idle, then walking north through the trigger
      // sphere and into the wall.
      const ticks = 660;
      for (var tick = 0; tick < ticks; tick++) {
        ticksRun = tick;
        final t = tick / 60;
        if (t >= 0.5) character.onMove(walk);
        pc.onTick(1 / 60);
        world.tick(1 / 60);
        track.add(character.actorLocation.z);
        if (tick.isEven) video.addFrame(shot());
        if (tick == 30) {
          SmokeArtifacts.saveScreenshot('$testTitle 01 start', SmokeArtifacts.encodePng(w, h, shot()), usedAssets: usedAssets);
        }
        if (tick == 110) {
          SmokeArtifacts.saveScreenshot('$testTitle 02 inside the trigger sphere', SmokeArtifacts.encodePng(w, h, shot()),
              usedAssets: usedAssets);
        }
      }

      // Through the trigger: one begin and one end overlap, in that order.
      expect(log.where((l) => l.startsWith('begin LuminaTemplateCharacter')), hasLength(1), reason: '$log');
      expect(log.where((l) => l.startsWith('end LuminaTemplateCharacter')), hasLength(1), reason: '$log');
      expect(log.first, startsWith('begin'));
      expect(track.any((z) => z < -300), isTrue, reason: 'it walked past the trigger centre');
      // Stopped by the wall: the last 1.5 s moved it by less than a centimetre,
      // touching (not inside) the box.
      final stop = track.last;
      expect((track.last - track[ticks - 90]).abs(), lessThan(1.0), reason: 'still pushing into the wall, not moving');
      expect(stop, lessThan(-550), reason: 'it walked up to the wall (z $stop)');
      expect(stop - character.capsuleComponent.radius, greaterThan(wall.getAABB().min.z - 1), reason: 'in front of the wall, not through it');
      final overlaps = <LuminaCollisionComponent>[];
      yard.collision.overlapTest(character.capsuleComponent.worldShape, character.capsuleComponent.worldTransform, overlaps,
          ignore: character.capsuleComponent);
      expect(overlaps, isNot(contains(wall)));
      expect(character.actorLocation.y, closeTo(LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight, 2), reason: 'on the floor');

      SmokeArtifacts.saveScreenshot(testTitle, SmokeArtifacts.encodePng(w, h, shot()), usedAssets: usedAssets);
      SmokeArtifacts.saveVideo(testTitle, video.finish(), usedAssets: usedAssets);
    }, timeout: const Timeout(Duration(minutes: 6)));
  });
}
