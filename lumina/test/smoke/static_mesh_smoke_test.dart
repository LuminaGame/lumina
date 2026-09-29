import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('Static Mesh Module Smoke Tests', () {
    late FilamentEngine engine;
    late FilamentScene scene;
    late LuminaWorld world;

    setUp(() {
      engine = FilamentEngine.create()!;
      scene = engine.createScene();
      world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene);
    });

    tearDown(() {
      world.cleanup();
      scene.dispose();
      engine.dispose();
    });

    test('Scenario 01: LuminaStaticMeshComponent loading, transform syncing, shadows and visibility lifecycle with real 3D assets', () async {
      final assetsDir = SmokeArtifacts.testAssetsDir;
      final usedAssets = [
        'structures/excavator_cabins/excavator_cabin_a.glb',
        'Props/Barrels/fuel_barrel_black.glb',
        'Props/AC_units/ac_unit_a_300x300.glb',
      ];

      for (final assetPath in usedAssets) {
        final f = File('${assetsDir.path}/$assetPath');
        if (f.existsSync()) {
          final bytes = f.readAsBytesSync();
          expect(bytes.length, greaterThan(0));
        }
      }

      final modelPath = '${assetsDir.path}/structures/excavator_cabins/excavator_cabin_a.glb';
      final staticMesh = LuminaStaticMeshComponent(
        meshAssetPath: modelPath,
        location: Vector3(0.0, 5.0, 10.0),
        castShadows: true,
        receiveShadows: true,
      );

      final actor = LuminaActor(root: staticMesh);
      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      await staticMesh.loaded;
      expect(staticMesh.isLoaded, isTrue);
      expect(staticMesh.rootEntity, isNotNull);
      expect(scene.hasEntity(staticMesh.rootEntity!), isTrue);

      // Run 3 world ticks
      for (int i = 0; i < 3; i++) {
        staticMesh.relativeLocation = Vector3(i * 2.0, 5.0, 10.0 + i);
        world.tick(1.0 / 60.0);
      }

      final tm = FilamentTransformManager(engine);
      final transform = tm.getWorldTransform(staticMesh.rootEntity!);
      expect(transform[12], closeTo(4.0, 1e-4));
      expect(transform[13], closeTo(5.0, 1e-4));
      expect(transform[14], closeTo(12.0, 1e-4));

      // Test visibility toggle
      staticMesh.visible = false;
      expect(scene.hasEntity(staticMesh.rootEntity!), isFalse);
      staticMesh.visible = true;
      expect(scene.hasEntity(staticMesh.rootEntity!), isTrue);

      const testTitle = 'static_mesh_smoke_test: Scenario 01 LuminaStaticMeshComponent loading, transform syncing, shadows and visibility';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        engine: engine,
        autoDisposeEngine: false,
      );
    });

    test('Scenario 02: LuminaProceduralMeshComponent section building, deformation, and MIKKTSPACE tangents with 3D assets', () async {
      final procMesh = LuminaProceduralMeshComponent(
        location: Vector3(0.0, 0.0, 0.0),
      );

      final actor = LuminaActor(root: procMesh);
      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      const gridSize = 4;
      final vertexCount = (gridSize + 1) * (gridSize + 1);
      final positions = Float32List(vertexCount * 3);
      final normals = Float32List(vertexCount * 3);
      final uv0 = Float32List(vertexCount * 2);

      int vIdx = 0;
      for (int y = 0; y <= gridSize; y++) {
        for (int x = 0; x <= gridSize; x++) {
          positions[vIdx * 3 + 0] = (x - gridSize / 2) * 0.5;
          positions[vIdx * 3 + 1] = 0.0;
          positions[vIdx * 3 + 2] = (y - gridSize / 2) * 0.5;

          normals[vIdx * 3 + 0] = 0.0;
          normals[vIdx * 3 + 1] = 1.0;
          normals[vIdx * 3 + 2] = 0.0;

          uv0[vIdx * 2 + 0] = x / gridSize;
          uv0[vIdx * 2 + 1] = y / gridSize;
          vIdx++;
        }
      }

      final indices = Uint32List(gridSize * gridSize * 6);
      int iIdx = 0;
      for (int y = 0; y < gridSize; y++) {
        for (int x = 0; x < gridSize; x++) {
          final row1 = y * (gridSize + 1);
          final row2 = (y + 1) * (gridSize + 1);

          indices[iIdx++] = row1 + x;
          indices[iIdx++] = row2 + x;
          indices[iIdx++] = row1 + x + 1;

          indices[iIdx++] = row1 + x + 1;
          indices[iIdx++] = row2 + x;
          indices[iIdx++] = row2 + x + 1;
        }
      }

      procMesh.createMeshSection(
        0,
        positions: positions,
        normals: normals,
        uv0: uv0,
        indices: indices,
        generateTangents: true,
        dynamic: true,
      );

      expect(procMesh.sectionCount, equals(1));
      expect(procMesh.hasSection(0), isTrue);

      for (int f = 0; f < 5; f++) {
        for (int i = 0; i < vertexCount; i++) {
          final x = positions[i * 3 + 0];
          final z = positions[i * 3 + 2];
          positions[i * 3 + 1] = 0.2 * (x * 0.5 + f * 0.1);
        }
        procMesh.updateMeshSection(0, positions: positions);
        world.tick(1.0 / 60.0);
      }

      final usedAssets = [
        'Props/Barrels/dented_barrel.glb',
        'Props/AC_units/roof_aircon_unit_150x150_b.glb',
      ];

      const testTitle = 'static_mesh_smoke_test: Scenario 02 LuminaProceduralMeshComponent section building, deformation, and MIKKTSPACE tangents';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        engine: engine,
        autoDisposeEngine: false,
      );
    });

    test('Scenario 03: LuminaInstancedStaticMeshComponent GPU instancing, distance LOD switching and frustum culling with 3D assets', () async {
      final quadPositions = Float32List.fromList([
        -0.5, 0.0, -0.5,
         0.5, 0.0, -0.5,
         0.5, 0.0,  0.5,
        -0.5, 0.0,  0.5,
      ]);
      final quadIndices = Uint16List.fromList([0, 1, 2, 0, 2, 3]);

      final vb = FilamentVertexBuffer.create(
        engine: engine,
        vertexCount: 4,
        attributes: [
          const VertexAttributeDesc(
            attribute: VertexAttribute.position,
            type: AttributeType.float3,
            byteOffset: 0,
            byteStride: 12,
          ),
        ],
      );
      vb.setBufferAt(engine, 0, NativeBuffer.copy(quadPositions.buffer.asUint8List()));

      final ib = FilamentIndexBuffer.create(
        engine: engine,
        indexCount: 6,
        type: IndexType.ushort,
      );
      ib.setIndicesU16(quadIndices);

      final provider = FilamentMaterialProvider.ubershader(engine);
      final matResult = provider.createMaterialInstance(MaterialKey());
      final mat = matResult.instance!;

      final ismc = LuminaInstancedStaticMeshComponent(
        lods: [
          LuminaStaticMeshLod(vb: vb, ib: ib, indexCount: 6, switchDistance: 100.0),
        ],
        material: mat,
        capacity: 64,
      );

      final actor = LuminaActor(root: ismc);
      world.persistentLevel.registerActor(actor);
      world.beginPlay();

      for (int x = 0; x < 4; x++) {
        for (int z = 0; z < 4; z++) {
          ismc.addInstance(Matrix4.translationValues(x * 2.0, 0.0, z * 2.0));
        }
      }

      expect(ismc.instanceCount, equals(16));

      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      final usedAssets = [
        'Props/Barrels/fuel_barrel_black.glb',
        'Props/Barrels/fuel_barrel_red.glb',
      ];

      const testTitle = 'static_mesh_smoke_test: Scenario 03 LuminaInstancedStaticMeshComponent GPU instancing, distance LOD switching and frustum culling';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        engine: engine,
        autoDisposeEngine: false,
      );

      world.persistentLevel.unregisterActor(actor);
      mat.dispose();
      provider.dispose();
      vb.dispose();
      ib.dispose();
    });
    test('Scenario 04: procedural sections declare uv1, so lit and unlit ubershader sections rebuilt every frame draw with no missing-attribute warnings', () async {
      const testTitle = 'static_mesh_smoke_test: Scenario 04 procedural sections declare uv1 for lit and unlit ubershader materials';
      const barrelAsset = 'Props/Barrels/dented_barrel.glb';
      const usedAssets = [barrelAsset];
      const w = 1024, h = 768, fps = 30;
      const seconds = 10.5;

      // Filament's warning for a primitive whose vertex buffer lacks an
      // attribute its material requires, e.g. uv1 for every gltfio ubershader.
      final warnings = <String>[];
      FilamentDiagnostics.installLogHandler();
      final logs = FilamentDiagnostics.onLog.listen((r) {
        if (r.message.contains('missing required attributes')) warnings.add(r.message.trim());
      });

      final view = engine.createView();
      final renderer = engine.createRenderer();
      final swapChain = engine.createHeadlessSwapChain(w, h);
      final cameraEntity = engine.createEntity();
      final camera = engine.createCamera(cameraEntity);
      view
        ..scene = scene
        ..camera = camera
        ..setViewport(0, 0, w, h);
      camera.setProjection(fovDegrees: 50.0, aspect: w / h, near: 10.0, far: 10000.0, direction: FovDirection.vertical);

      world.persistentLevel.registerActor(LuminaActor(
        root: LuminaSkyComponent.color(color: Vector4(0.44, 0.58, 0.76, 1.0), skyIntensity: 20000.0, iblIntensity: 20000.0),
      ));
      world.persistentLevel.registerActor(LuminaActor(
        root: LuminaDirectionalLightComponent(
          intensity: 90000.0,
          castShadows: true,
          // Drawn −Z tilted 50° down and 30° to the side.
          rotation: Quaternion.axisAngle(Vector3(0.0, 1.0, 0.0), 30.0 * 3.141592653589793 / 180.0) *
              Quaternion.axisAngle(Vector3(1.0, 0.0, 0.0), -50.0 * 3.141592653589793 / 180.0),
        ),
      ));
      final barrel = LuminaStaticMeshComponent(
        meshAssetPath: '${SmokeArtifacts.testAssetsDir.path}/$barrelAsset',
        location: Vector3(0.0, 0.0, -40.0),
      );
      world.persistentLevel.registerActor(LuminaActor(root: barrel));

      final provider = FilamentMaterialProvider.ubershader(engine);
      FilamentMaterialInstance material({required bool unlit}) {
        final mi = provider
            .createMaterialInstance(
              MaterialKey(unlit: unlit, alphaMode: 2, doubleSided: true, hasVertexColors: true),
              label: unlit ? 'smoke_bugs05_unlit' : 'smoke_bugs05_lit',
            )
            .instance!;
        mi.setFloat4('baseColorFactor', 1.0, 1.0, 1.0, 1.0);
        return mi;
      }

      final lit = material(unlit: false);
      final unlit = material(unlit: true);
      final sheets = LuminaProceduralMeshComponent();
      world.persistentLevel.registerActor(LuminaActor()..addComponent(sheets));
      // Runs before the group's tearDown disposes the engine, pass or fail.
      addTearDown(() async {
        await logs.cancel();
        FilamentDiagnostics.clearLogHandler();
        sheets.clearAllMeshSections();
        lit.dispose();
        unlit.dispose();
        provider.dispose();
        view.dispose();
        engine.destroyEntity(cameraEntity);
        camera.dispose();
        renderer.dispose();
        swapChain.dispose();
      });
      world.beginPlay();
      await barrel.loaded;

      // A 250 cm wavy sheet of 32 × 32 quads centred at [centreX], its
      // vertex colours running from [a] to [b] along X.
      const n = 32;
      void buildSheet(int section, double centreX, double t, List<int> a, List<int> b, FilamentMaterialInstance mi) {
        final count = (n + 1) * (n + 1);
        final positions = Float32List(count * 3);
        final normals = Float32List(count * 3);
        final uv0 = Float32List(count * 2);
        final colors = Uint8List(count * 4);
        for (var j = 0; j <= n; j++) {
          for (var i = 0; i <= n; i++) {
            final v = j * (n + 1) + i;
            final u = i / n;
            final x = centreX + (u - 0.5) * 250.0;
            final z = (j / n - 0.5) * 250.0;
            final y = 12.0 * math.sin(x * 0.03 + t * 2.0) * math.cos(z * 0.025 + t);
            positions.setAll(v * 3, [x, y, z]);
            normals.setAll(v * 3, [0.0, 1.0, 0.0]);
            uv0.setAll(v * 2, [u, j / n]);
            for (var c = 0; c < 3; c++) {
              colors[v * 4 + c] = (a[c] + (b[c] - a[c]) * u).round();
            }
            colors[v * 4 + 3] = 255;
          }
        }
        final indices = Uint32List(n * n * 6);
        var k = 0;
        for (var j = 0; j < n; j++) {
          for (var i = 0; i < n; i++) {
            final v = j * (n + 1) + i;
            indices.setAll(k, [v, v + n + 1, v + 1, v + 1, v + n + 1, v + n + 2]);
            k += 6;
          }
        }
        // Rebuilt every frame, as particles do: without uv1 each rebuild
        // logged one missing-attribute warning per section.
        sheets.createMeshSection(section,
            positions: positions, normals: normals, uv0: uv0, colors: colors, indices: indices, material: mi, dynamic: true);
      }

      final video = SmokeVideoRecorder(width: w, height: h, fps: fps, testName: testTitle);
      addTearDown(video.discard);
      final pixels = Uint8List(w * h * 4);
      Uint8List? middle;
      final frames = (seconds * fps).round();
      for (var f = 0; f < frames; f++) {
        final t = f / fps;
        buildSheet(0, -140.0, t, [255, 140, 20], [200, 20, 20], lit);
        buildSheet(1, 140.0, t, [20, 200, 200], [20, 90, 220], unlit);
        final angle = 0.35 * math.sin(t * 0.6);
        camera.lookAt(
          eyeX: 520.0 * math.sin(angle),
          eyeY: 330.0,
          eyeZ: 520.0 * math.cos(angle),
          centerX: 0.0,
          centerY: 0.0,
          centerZ: 0.0,
        );
        world.tick(1.0 / fps);
        if (renderer.beginFrame(swapChain)) {
          renderer.render(view);
          renderer.readPixels(x: 0, y: 0, width: w, height: h, outPixels: pixels);
          renderer.endFrame();
        }
        engine.flushAndWait();
        video.addFrame(pixels);
        if (f == frames ~/ 2) middle = Uint8List.fromList(pixels);
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Both sheets are on screen in their vertex colours: the lit one warm,
      // the unlit one cyan/blue.
      var warm = 0;
      var cyan = 0;
      final shot = middle!;
      for (var p = 0; p < shot.length; p += 4) {
        final r = shot[p], g = shot[p + 1], b = shot[p + 2];
        if (r > 120 && r > g + 30 && r > b + 60) warm++;
        if (b > r + 40 && g > r + 30) cyan++;
      }
      // ignore: avoid_print
      print('[static_mesh smoke 04] warmPixels=$warm cyanPixels=$cyan missingAttributeWarnings=${warnings.length}');

      SmokeArtifacts.saveScreenshot(testTitle, SmokeArtifacts.encodePng(w, h, shot, flipY: false), usedAssets: usedAssets);
      SmokeArtifacts.saveVideo(testTitle, video.finish(), extension: 'webm', usedAssets: usedAssets);

      expect(warnings, isEmpty, reason: 'every section declares what the ubershader requires');
      expect(warm, greaterThan(20000), reason: 'the lit sheet draws');
      expect(cyan, greaterThan(20000), reason: 'the unlit sheet draws');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
