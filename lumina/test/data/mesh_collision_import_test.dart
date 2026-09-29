// Imported UCX_ hulls as a static mesh's simple
// collision — real FBX exports from test-assets/FBX/ through the real import
// pipeline (ImportAssetUseCase) into a temp project, then the frame, the
// decomposition and the generated level.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import '../helpers/analyze_generated_project.dart';

Directory get _assets => Directory(Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets');

File _fbx(String name) => File('${_assets.path}/FBX/StaticMeshes/$name.FBX');

const _props = ['SM_Casino_Chair', 'SM_Laptop', 'SM_Slot_Machine', 'SM_Table', 'SM_Counter_1'];

/// World bounds of the drawn mesh: the GLB's model-space bounds (metres)
/// through the component's render transform (world × 100).
Aabb3 _drawnBounds(GlbMeshData mesh, LuminaStaticMeshComponent component) {
  final t = component.renderTransform;
  final lo = Vector3.all(double.infinity);
  final hi = Vector3.all(-double.infinity);
  for (var i = 0; i < 8; i++) {
    final c = Vector3(
      i & 1 == 0 ? mesh.minBounds[0] : mesh.maxBounds[0],
      i & 2 == 0 ? mesh.minBounds[1] : mesh.maxBounds[1],
      i & 4 == 0 ? mesh.minBounds[2] : mesh.maxBounds[2],
    );
    final w = t.transform3(c);
    Vector3.min(lo, w, lo);
    Vector3.max(hi, w, hi);
  }
  return Aabb3.minMax(lo, hi);
}

Aabb3 _union(Iterable<Aabb3> boxes) {
  final lo = Vector3.all(double.infinity);
  final hi = Vector3.all(-double.infinity);
  for (final b in boxes) {
    Vector3.min(lo, b.min, lo);
    Vector3.max(hi, b.max, hi);
  }
  return Aabb3.minMax(lo, hi);
}

void main() {
  final haveAssets = _props.every((p) => _fbx(p).existsSync());
  late Directory project;
  String lmas(String name) => '${project.path}/contents/meshes/static/$name.lmas';

  setUpAll(() async {
    if (!haveAssets) return;
    project = Directory.systemTemp.createTempSync('lumina_ucx_collision_');
    Directory('${project.path}/contents/meshes/static').createSync(recursive: true);
    for (final prop in _props) {
      final result = await ImportAssetUseCase()(projectDir: project.path, sourceFilePath: _fbx(prop).path);
      expect(result.isSuccess, isTrue, reason: '$prop: ${result.error}');
      expect(result.asset!.relativePath, 'contents/meshes/static/$prop.lmas');
    }
  });

  tearDownAll(() {
    if (haveAssets && project.existsSync()) project.deleteSync(recursive: true);
  });

  group('imported hulls, authored Z-up in centimetres', () {
    test('SM_Casino_Chair: its UCX_ mesh is 4 convex pieces whose authored points are the FBX file\'s own coordinates (cm, Z up)', () {
      if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
      final hulls = MeshCollisionService.hullsForMeshAsset(lmas('SM_Casino_Chair'));
      // Pedestal, foot ring, seat and back: one UCX_ mesh, four disconnected
      // convex pieces.
      expect(hulls.map((h) => h.name), ['UCX_SM_Casino_Chair_1', 'UCX_SM_Casino_Chair_2', 'UCX_SM_Casino_Chair_3', 'UCX_SM_Casino_Chair_4']);
      expect(hulls.every((h) => h.shape == 'convex'), isTrue);

      // The same FBX through the bridge with no normalization: the hull as
      // the file stores it (Unreal export: cm, Z up, front −Y).
      final raw = FlutterAssimp.convertFileForImport(_fbx('SM_Casino_Chair').path, options: AssimpConvertOptions.stripCollision);
      expect(raw.report['normalized'], isFalse);
      final rawHull = (raw.report['collision'] as List).cast<Map>().single;
      final source = [for (final v in rawHull['points'] as List) (v as num).toDouble()];
      final sourcePoints = [for (var i = 0; i < source.length; i += 3) Vector3(source[i], source[i + 1], source[i + 2])];
      final authored = [
        for (final h in hulls)
          for (var i = 0; i < h.pointCount; i++) Vector3(h.points[i * 3], h.points[i * 3 + 1], h.points[i * 3 + 2]),
      ];
      expect(authored, hasLength(sourcePoints.length), reason: 'every vertex is on a hull triangle');
      for (final p in authored) {
        final nearest = sourcePoints.map((s) => s.distanceTo(p)).reduce((a, b) => a < b ? a : b);
        expect(nearest, lessThan(0.02), reason: 'authored point $p is not an FBX hull vertex');
      }
      final zs = [for (final p in authored) p.z];
      expect(zs.reduce((a, b) => a < b ? a : b), closeTo(0, 0.01), reason: 'stands on z = 0');
      expect(zs.reduce((a, b) => a > b ? a : b), closeTo(100.74, 0.02), reason: '100.7 cm tall along +Z');
    });

    test('the runtime points are the reported glTF points × 100, the frame LuminaStaticMeshComponent draws', () {
      if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
      final metadata = LuminaAsset.fromBytes(File(lmas('SM_Casino_Chair')).readAsBytesSync()).metadata;
      final gltf = [
        for (final v in ((jsonDecode(metadata['collision_hulls']!) as List).single as Map)['points'] as List) (v as num).toDouble(),
      ];
      final gltfCm = [
        for (var i = 0; i < gltf.length; i += 3) Vector3(gltf[i], gltf[i + 1], gltf[i + 2])..scale(LuminaUnits.unitsPerMetre),
      ];
      final runtime = [for (final h in MeshCollisionService.hullsFromMetadata(metadata)) ...h.runtimePoints];
      expect(runtime, hasLength(gltfCm.length));
      for (final p in runtime) {
        final nearest = gltfCm.map((g) => g.distanceTo(p)).reduce((a, b) => a < b ? a : b);
        expect(nearest, lessThan(1e-6), reason: 'runtime point $p is not a reported glTF point × 100');
      }
    });

    for (final prop in const ['SM_Casino_Chair', 'SM_Slot_Machine']) {
      test('$prop: placed and turned, its hull wraps the drawn mesh on every side (same floor)', () async {
        if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
        final hulls = MeshCollisionService.hullsForMeshAsset(lmas(prop));
        final mesh = (await AssetRepository.loadMeshFromDisk(lmas(prop)))!;
        final actor = LuminaStaticMeshActor(
          meshAssetPath: lmas(prop),
          location: LuminaAxes.location([250, -40, 0]),
          rotation: LuminaAxes.rotation([0, 0, 90]),
          collisionHulls: hulls,
        );
        final drawn = _drawnBounds(mesh, actor.meshComponent);
        final collision = _union(actor.collisionComponents.map((c) => c.getAABB()));
        expect(collision.min.y, closeTo(drawn.min.y, 0.5), reason: 'the same floor');
        for (var axis = 0; axis < 3; axis++) {
          expect((collision.min[axis] - drawn.min[axis]).abs(), lessThan(4.0),
              reason: '$prop axis $axis min: hull ${collision.min} vs mesh ${drawn.min}');
          expect((collision.max[axis] - drawn.max[axis]).abs(), lessThan(4.0),
              reason: '$prop axis $axis max: hull ${collision.max} vs mesh ${drawn.max}');
        }
      });
    }
  });

  group('decomposition of a UCX_ mesh into convex pieces', () {
    test('one UCX_ mesh splits into its disconnected pieces; SM_Counter_1 has none', () {
      if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
      final laptop = MeshCollisionService.hullsForMeshAsset(lmas('SM_Laptop'));
      expect(laptop.map((h) => h.name), ['UCX_SM_Laptop_1', 'UCX_SM_Laptop_2']);
      expect(laptop.map((h) => h.pointCount).fold<int>(0, (a, b) => a + b), 48);
      expect(MeshCollisionService.hullsForMeshAsset(lmas('SM_Slot_Machine')), hasLength(5), reason: 'cabinet, base, desk, screen, topper');
      expect(MeshCollisionService.hullsForMeshAsset(lmas('SM_Casino_Chair')), hasLength(4));
      expect(MeshCollisionService.hullsForMeshAsset(lmas('SM_Table')).map((h) => h.name), ['UCX_SM_Table_LOD0']);
      expect(MeshCollisionService.hullsForMeshAsset(lmas('SM_Counter_1')), isEmpty);
    });

    test('a hull stored before triangles were reported stays one element', () {
      if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
      final metadata = Map<String, String>.from(LuminaAsset.fromBytes(File(lmas('SM_Laptop')).readAsBytesSync()).metadata);
      final hulls = [for (final h in jsonDecode(metadata['collision_hulls']!) as List) Map<String, dynamic>.from(h as Map)..remove('triangles')];
      metadata['collision_hulls'] = jsonEncode(hulls);
      final legacy = MeshCollisionService.hullsFromMetadata(metadata);
      expect(legacy.single.name, 'UCX_SM_Laptop');
      expect(legacy.single.pointCount, 48);
    });

    test('non-.lmas, missing and relative paths without a project resolve to nothing', () {
      if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
      expect(MeshCollisionService.hullsForMeshAsset('${project.path}/contents/meshes/static/rock.glb'), isEmpty);
      expect(MeshCollisionService.hullsForMeshAsset('${project.path}/contents/meshes/static/missing.lmas'), isEmpty);
      expect(MeshCollisionService.hullsForMeshAsset('contents/meshes/static/SM_Laptop.lmas'), isEmpty);
      expect(MeshCollisionService.hullsForMeshAsset('contents/meshes/static/SM_Laptop.lmas', projectDir: project.path), hasLength(2));
    });
  });

  group('generated level', () {
    Map<String, dynamic> meshActor(String id, String path) => {
          'id': id,
          'name': id,
          'type': 'Mesh',
          'location': [250.0, -40.0, 0.0],
          'rotation': [0.0, 0.0, 90.0],
          'scale': [1.0, 1.0, 1.0],
          'meshAssetPath': path,
        };

    String generate() => DartCodeGeneratorService().generateLevelDart(
          levelName: 'L_Props',
          actors: const [],
          actorMaps: [
            meshActor('chair', lmas('SM_Casino_Chair')),
            meshActor('counter', lmas('SM_Counter_1')),
            meshActor('laptop', 'contents/meshes/static/SM_Laptop.lmas'),
          ],
          projectDir: project.path,
        );

    test('bakes the hulls as constants; a mesh without hulls is emitted as before', () {
      if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
      final code = generate();
      expect(code, contains("LuminaStaticMeshActor(key: const ValueKey('chair'), meshAssetPath: 'contents/meshes/static/SM_Casino_Chair.lmas', "));
      expect(code, contains("LuminaCollisionHull('UCX_SM_Casino_Chair_1', ["));
      expect(code, contains("LuminaCollisionHull('UCX_SM_Casino_Chair_4', ["));
      expect(code, contains("LuminaActor(key: const ValueKey('counter'), root: LuminaStaticMeshComponent(meshAssetPath: 'contents/meshes/static/SM_Counter_1.lmas', "));
      expect(code, contains("LuminaCollisionHull('UCX_SM_Laptop_1', ["), reason: 'contents/… resolves under projectDir');
      expect(code, contains("LuminaCollisionHull('UCX_SM_Laptop_2', ["));
      expect(code, isNot(contains(project.path)), reason: 'a shipped game never names the developer\'s disk');
      expect(code, isNot(contains('collision_hulls')), reason: 'the game never reads .lmas metadata');

      // The numbers the level carries are the ones PIE builds from.
      const marker = "LuminaCollisionHull('UCX_SM_Casino_Chair_1', [";
      final start = code.indexOf(marker) + marker.length;
      final body = code.substring(start, code.indexOf(']', start));
      final emitted = [for (final v in body.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty)) double.parse(v)];
      final expected = MeshCollisionService.hullsForMeshAsset(lmas('SM_Casino_Chair')).first.points;
      expect(emitted, hasLength(expected.length));
      for (var i = 0; i < expected.length; i++) {
        expect(emitted[i], closeTo(expected[i], 1e-4));
      }

      final noProject = DartCodeGeneratorService().generateLevelDart(
        levelName: 'L_Props',
        actors: const [],
        actorMaps: [meshActor('laptop', 'contents/meshes/static/SM_Laptop.lmas')],
      );
      expect(noProject, isNot(contains('LuminaCollisionHull')), reason: 'nothing to resolve a project path against');
    });

    test('the generated level analyzes clean against the real package', () async {
      if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
      final code = generate();
      final probe = Directory.systemTemp.createTempSync('lumina_ucx_levelgen_');
      addTearDown(() => probe.deleteSync(recursive: true));
      File('${probe.path}/pubspec.yaml').writeAsStringSync('''
name: ucx_levelgen_probe
environment:
  sdk: ^3.12.0
dependencies:
  flutter:
    sdk: flutter
  lumina:
    path: ${Directory.current.path}
  vector_math: ^2.1.4
''');
      Directory('${probe.path}/lib/levels').createSync(recursive: true);
      File('${probe.path}/lib/levels/l_props.dart').writeAsStringSync(code);
      File('${probe.path}/lib/main.dart')
          .writeAsStringSync(DartCodeGeneratorService().generateMainDart(projectName: 'ucx_levelgen_probe', levelName: 'L_Props'));
      final pubGet = await Process.run('flutter', ['pub', 'get', '--offline'], workingDirectory: probe.path, runInShell: Platform.isWindows);
      expect(pubGet.exitCode, 0, reason: 'pub get: ${pubGet.stdout}${pubGet.stderr}');
      final analyze = await analyzeGeneratedProject(probe.path);
      expect(analyze.exitCode, 0, reason: 'generated level must analyze clean:\n${analyze.stdout}\n${analyze.stderr}');
    }, timeout: const Timeout(Duration(minutes: 4)));
  });
}
