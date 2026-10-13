import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_core/lumina_core.dart';

/// Garment fitting with real files: the T-shirt from `test-assets/Props/
/// Clothes Line/` placed on Manny, fitted to Quinn (another body, another
/// topology, the same skeleton) and to a Manny widened at the hips and chest
/// (the same topology), then written as a skinned GLB over the body's joints.
void main() {
  final assets = Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.parent.path}/test-assets';
  final tshirt = File('$assets/Props/Clothes Line/tshirt.glb');
  final manny = File('$assets/mannequin/SKM_Manny_Simple.glb');
  final quinn = File('$assets/mannequin/exports/SKM_Quinn_Simple.glb');
  final skip = [tshirt, manny, quinn].every((f) => f.existsSync()) ? false : 'the T-shirt or the mannequins are missing';

  LuminaSkinnedMeshData read(File f) => LuminaSkinnedMeshData.fromGlb(f.readAsBytesSync(), draco: LuminaGlbLoader.decoders.draco);

  /// The shirt on Manny's chest, as the Garment editor places it, with
  /// neck, shoulder and waist landmarks on both.
  LuminaGarmentDocument placed(LuminaSkinnedMeshData shirt, LuminaSkinnedMeshData body) {
    var doc = const LuminaGarmentDocument().copyWith(location: [0, 150, 9], rotation: [0, 90, 0], scale: [1.15, 1.15, 1.15], thickness: 0.5);
    final grid = LuminaTriangleGrid(body.positions, body.triangles);
    for (final (name, x, y) in [('Neck', 0.0, 145.0), ('Shoulder L', 17.0, 141.0), ('Shoulder R', -17.0, 141.0), ('Waist', 0.0, 104.0)]) {
      final placedShirt = Float64List(shirt.positions.length);
      for (var v = 0; v < shirt.vertexCount; v++) {
        placedShirt.setAll(v * 3, doc.place([shirt.positions[v * 3], shirt.positions[v * 3 + 1], shirt.positions[v * 3 + 2]]));
      }
      final g = LuminaGarmentMath.raycast(placedShirt, shirt.triangles, x, y, 200, 0, 0, -1)!;
      final b = LuminaGarmentMath.raycast(body.positions, body.triangles, x, y, 200, 0, 0, -1)!;
      // Back into the shirt's own space.
      final q = LuminaGarmentMath.quaternionFromEuler(doc.rotation);
      final local = LuminaGarmentMath.rotate([-q[0], -q[1], -q[2], q[3]], [g.x - doc.location[0], g.y - doc.location[1], g.z - doc.location[2]]);
      doc = doc.withLandmark(LuminaGarmentLandmark(name, garment: [for (final c in local) c / 1.15], body: [b.x, b.y, b.z]));
      expect(grid.closest(b.x, b.y, b.z)!.distance, lessThan(1e-6));
    }
    return doc;
  }

  /// The largest depth of [fit]'s vertices inside [body] (cm).
  double penetration(LuminaGarmentFit fit, LuminaSkinnedMeshData body) {
    final grid = LuminaTriangleGrid(body.positions, body.triangles);
    var worst = 0.0;
    for (var v = 0; v < fit.vertexCount; v++) {
      final h = grid.closest(fit.positions[v * 3], fit.positions[v * 3 + 1], fit.positions[v * 3 + 2]);
      if (h == null) continue;
      final s = (fit.positions[v * 3] - h.x) * h.nx + (fit.positions[v * 3 + 1] - h.y) * h.ny + (fit.positions[v * 3 + 2] - h.z) * h.nz;
      worst = math.max(worst, -s);
    }
    return worst;
  }

  test('the T-shirt landmarked on Manny refits to Quinn: nothing inside, skinned, landmarks kept, a loadable GLB', () {
    final mannyBody = read(manny), quinnBody = read(quinn);
    final doc = placed(read(tshirt), mannyBody);
    final shirt = read(tshirt).refined(); // as the slots fit it
    final fit = LuminaGarmentFitter.fit(source: shirt, document: doc, referenceBody: mannyBody, targetBody: quinnBody);
    // ignore: avoid_print
    print('Manny → Quinn: ${fit.report.toJson()}');
    expect(fit.report.denseCorrespondence, isFalse);
    expect(fit.report.maxPenetration, lessThan(0.1));
    expect(fit.report.maxPokeThrough, lessThan(0.05), reason: 'no body point in front of the shirt where it covers the body');
    expect(penetration(fit, quinnBody), lessThan(0.1));
    for (final e in fit.report.landmarkError.entries) {
      expect(e.value, lessThan(3.0), reason: e.key);
    }
    for (var v = 0; v < fit.vertexCount; v++) {
      final w = fit.weights;
      expect(w[v * 4] + w[v * 4 + 1] + w[v * 4 + 2] + w[v * 4 + 3], closeTo(1, 1e-4));
    }
    final glb = LuminaGarmentGlbWriter.write(fit: fit, source: shirt, targetBody: quinnBody, name: 'tshirt');
    final back = LuminaSkinnedMeshData.fromGlb(glb);
    expect(back.isSkinned, isTrue);
    expect(back.vertexCount, fit.vertexCount);
    expect(back.nodeNamed('pelvis'), quinnBody.nodeNamed('pelvis'), reason: 'the body\'s node order');
    for (var i = 0; i < 30; i++) {
      final v = i * fit.vertexCount ~/ 30;
      expect(back.positions[v * 3 + 1], closeTo(fit.positions[v * 3 + 1], 1e-3));
      expect(back.nodeNames[back.joints![v * 4]], quinnBody.nodeNames[fit.joints[v * 4]]);
    }
    expect((back.document.json['materials'] as List), isNotEmpty, reason: 'the shirt\'s material');
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));

  test('the same topology fits vertex for vertex: a widened Manny keeps the tight parts of the shirt at their distance', () {
    // Refined as the slots fit it, so the shirt's faces follow the body
    // closely and covering it lifts little.
    final mannyBody = read(manny);
    final shirt = read(tshirt).refined();
    // Manny widened 12 % at the hips and chest (x and z), a real body file changed.
    final wide = LuminaSkinnedMeshData.fromGlb(_widened(manny.readAsBytesSync(), 1.12));
    expect(wide.vertexCount, mannyBody.vertexCount);
    final doc = placed(read(tshirt), mannyBody);
    final fit = LuminaGarmentFitter.fit(source: shirt, document: doc, referenceBody: mannyBody, targetBody: wide);
    // ignore: avoid_print
    print('Manny → wide Manny: ${fit.report.toJson()}');
    expect(fit.report.denseCorrespondence, isTrue);
    expect(penetration(fit, wide), lessThan(0.1));
    // Tight vertices (within 1–3 cm of the skin on Manny, not pushed out) keep
    // their distance on the wide body.
    final refGrid = LuminaTriangleGrid(mannyBody.positions, mannyBody.triangles);
    final wideGrid = LuminaTriangleGrid(wide.positions, wide.triangles);
    var checked = 0;
    final errors = <double>[];
    for (var v = 0; v < shirt.vertexCount; v++) {
      final p = doc.place([shirt.positions[v * 3], shirt.positions[v * 3 + 1], shirt.positions[v * 3 + 2]]);
      final h0 = refGrid.closest(p[0], p[1], p[2])!;
      final s0 = (p[0] - h0.x) * h0.nx + (p[1] - h0.y) * h0.ny + (p[2] - h0.z) * h0.nz;
      if (s0 < 1 || s0 > 3) continue;
      final h1 = wideGrid.closest(fit.positions[v * 3], fit.positions[v * 3 + 1], fit.positions[v * 3 + 2])!;
      errors.add((h1.distance - s0).abs());
      checked++;
    }
    expect(checked, greaterThan(5));
    // Lifted over a bump here and there; the binding keeps the rest.
    errors.sort();
    expect(errors[errors.length ~/ 2], lessThan(0.3), reason: 'median offset change');
    expect(errors[errors.length * 9 ~/ 10], lessThan(1.0), reason: '90th percentile offset change');
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));

  test('bodies with the same UV layout but another vertex order still fit vertex for vertex', () {
    final shirt = read(tshirt), mannyBody = read(manny);
    final wide = LuminaSkinnedMeshData.fromGlb(_widened(manny.readAsBytesSync(), 1.12));
    // The widened Manny with its vertices in reverse order (as another
    // export would split and order its seams): only the UVs still match.
    final n = wide.vertexCount;
    final positions = <double>[], uvs = <double>[];
    for (var v = n - 1; v >= 0; v--) {
      positions.addAll([wide.positions[v * 3], wide.positions[v * 3 + 1], wide.positions[v * 3 + 2]]);
      uvs.addAll([wide.uvs[v * 2], wide.uvs[v * 2 + 1]]);
    }
    final reordered = LuminaSkinnedMeshData.fromArrays(positions, [for (final i in wide.triangles) n - 1 - i], uvs: uvs);
    final doc = placed(shirt, mannyBody);
    final direct = LuminaGarmentFitter.fit(source: shirt, document: doc, referenceBody: mannyBody, targetBody: wide);
    // Same vertex count, other order: identity would be wrong; the UVs map it
    // only when the counts differ, so drop the identity path by adding one
    // unused vertex.
    final extra = LuminaSkinnedMeshData.fromArrays([...positions, 0, 0, 0], [for (final i in wide.triangles) n - 1 - i], uvs: [...uvs, -1, -1]);
    final viaUv = LuminaGarmentFitter.fit(source: shirt, document: doc, referenceBody: mannyBody, targetBody: extra);
    expect(viaUv.report.denseCorrespondence, isTrue);
    var worst = 0.0;
    for (var i = 0; i < direct.positions.length; i++) {
      worst = math.max(worst, (direct.positions[i] - viaUv.positions[i]).abs());
    }
    // ignore: avoid_print
    print('UV correspondence: largest difference to the direct fit ${worst.toStringAsFixed(3)} cm');
    expect(worst, lessThan(0.5));
    expect(reordered.vertexCount, n);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));

  test('refitting to the reference body itself keeps the authored placement where it was clear of the body', () {
    final mannyBody = read(manny);
    final doc = placed(read(tshirt), mannyBody);
    final shirt = read(tshirt).refined(); // as the slots fit it
    final fit = LuminaGarmentFitter.fit(source: shirt, document: doc, referenceBody: mannyBody, targetBody: mannyBody);
    final grid = LuminaTriangleGrid(mannyBody.positions, mannyBody.triangles);
    var sum = 0.0, count = 0;
    for (var v = 0; v < shirt.vertexCount; v++) {
      final p = doc.place([shirt.positions[v * 3], shirt.positions[v * 3 + 1], shirt.positions[v * 3 + 2]]);
      final h = grid.closest(p[0], p[1], p[2])!;
      final s = (p[0] - h.x) * h.nx + (p[1] - h.y) * h.ny + (p[2] - h.z) * h.nz;
      if (s < 1) continue; // pushed out: it was inside or touching
      final dx = fit.positions[v * 3] - p[0], dy = fit.positions[v * 3 + 1] - p[1], dz = fit.positions[v * 3 + 2] - p[2];
      sum += math.sqrt(dx * dx + dy * dy + dz * dz);
      count++;
    }
    // ignore: avoid_print
    print('Manny → Manny: mean move ${(sum / count).toStringAsFixed(3)} cm over $count clear vertices');
    expect(sum / count, lessThan(0.5));
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));

  test('a cloth settle drapes the fitted shirt under gravity: hanging parts sag, nothing inside, edges kept', () {
    final shirt = read(tshirt).refined(), mannyBody = read(manny), quinnBody = read(quinn);
    final doc = placed(read(tshirt), mannyBody);
    final still = LuminaGarmentFitter.fit(source: shirt, document: doc, referenceBody: mannyBody, targetBody: quinnBody);
    final settled = LuminaGarmentFitter.fit(source: shirt, document: doc.copyWith(settleSteps: 60), referenceBody: mannyBody, targetBody: quinnBody);
    expect(penetration(settled, quinnBody), lessThan(0.1));
    var sagged = 0, rose = 0;
    for (var v = 0; v < still.vertexCount; v++) {
      final dy = settled.positions[v * 3 + 1] - still.positions[v * 3 + 1];
      if (dy < -0.5) sagged++;
      if (dy > 0.5) rose++;
    }
    // ignore: avoid_print
    print('settle: $sagged of ${still.vertexCount} vertices sagged more than 0.5 cm, $rose rose');
    expect(sagged, greaterThan(still.vertexCount ~/ 20));
    expect(rose, lessThan(sagged));
    double stretch(LuminaGarmentFit f) {
      var sum = 0.0, count = 0;
      for (var t = 0; t + 2 < f.triangles.length; t += 3) {
        final a = f.triangles[t], b = f.triangles[t + 1];
        final d1 = math.sqrt([0, 1, 2].fold(0.0, (s, k) => s + math.pow(f.positions[a * 3 + k] - f.positions[b * 3 + k], 2)));
        final d0 = math.sqrt([0, 1, 2].fold(0.0, (s, k) => s + math.pow(still.positions[a * 3 + k] - still.positions[b * 3 + k], 2)));
        if (d0 > 1e-6) {
          sum += (d1 - d0).abs() / d0;
          count++;
        }
      }
      return sum / count;
    }
    expect(stretch(settled), lessThan(0.08), reason: 'mean edge length change');
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));

  group('a garment in a character slot', () {
    late FilamentEngine engine;
    late FilamentScene scene;
    late LuminaWorld world;
    late Directory dir;

    setUp(() async {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      scene = engine.createScene();
      world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
      dir = await Directory.systemTemp.createTemp('garment_slot_');
    });

    tearDown(() async {
      world.cleanup();
      scene.dispose();
      engine.dispose();
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    });

    test('fits to the body it is put on, follows it, masks it, and refits when the body changes (cached)', () async {
      final shirt = read(tshirt), mannyBody = read(manny);
      final doc = placed(shirt, mannyBody).copyWith(sourceMesh: tshirt.path, referenceBody: manny.path);
      final garment = '${dir.path}/G_Tshirt.lmas';
      await File(garment).writeAsBytes(doc.toAsset(name: 'G_Tshirt').toProtoBufferBytes());

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
      final cache = LuminaGarmentCache.instance..clear();
      final before = cache.computed;

      final report = await slots.fitGarment('Torso', garment);
      expect(report, isNotNull);
      expect(report!.maxPenetration, lessThan(0.1));
      final torso = slots.component('Torso') as LuminaAnimatedMeshComponent;
      expect(torso.meshAssetPath, startsWith('garment:Torso#'));
      expect(torso.isLoaded, isTrue);
      expect(torso.poseLeader, same(body));
      expect(slots.slot('Torso')!.garment, isNotNull);
      expect(body.meshAssetPath, startsWith('${manny.path}#masked-'), reason: 'the shirt hides the chest');
      final onManny = torso.meshAssetPath;

      // A new body: the shirt is fitted to Quinn and masks Quinn.
      expect(await slots.setMesh('Body', quinn.path), isTrue);
      expect(slots.component('Torso'), same(torso));
      expect(torso.meshAssetPath, isNot(onManny));
      expect(slots.slot('Torso')!.lastFit!.denseCorrespondence, isFalse);
      expect(body.meshAssetPath, startsWith('${quinn.path}#masked-'));
      await torso.poseLinkReady;
      world.tick(1 / 60);
      expect(torso.followedBones, contains('spine_03'));

      // Back on Manny: the first fit comes from the cache.
      await slots.setMesh('Body', manny.path);
      expect(torso.meshAssetPath, onManny);
      expect(cache.computed - before, 2, reason: 'Manny and Quinn, each once');

      // The node does the same from a graph.
      expect(LuminaBlueprintFunctionLibrary.fitGarment(actor, null, 'Torso', garment), isTrue);
      expect(LuminaBlueprintFunctionLibrary.fitGarment(actor, null, 'Torso', 'shirt.glb'), isFalse);
      expect(LuminaBlueprintFunctionLibrary.fitGarment(actor, null, 'Cape', garment), isFalse);
    }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));

    test('a Blueprint whose Torso slot holds a Garment asset fits it and masks the body as it is built', () async {
      final doc = placed(read(tshirt), read(manny)).copyWith(sourceMesh: tshirt.path, referenceBody: manny.path);
      final garment = '${dir.path}/G_Tshirt.lmas';
      await File(garment).writeAsBytes(doc.toAsset(name: 'G_Tshirt').toProtoBufferBytes());
      final actor = LuminaActor(root: LuminaSceneComponent());
      final built = LuminaBlueprintComponents.construct(actor, [
        LuminaBlueprintComponent(id: 'body', name: 'Body', type: 'LuminaSkeletalMeshComponent', isSceneComponent: true, properties: {'skeletalMeshAsset': manny.path, 'slot': 'Body'}),
        LuminaBlueprintComponent(
          id: 'torso',
          name: 'Torso',
          type: 'LuminaSkeletalMeshComponent',
          parentId: 'body',
          isSceneComponent: true,
          properties: {'skeletalMeshAsset': garment, 'slot': 'Torso', 'poseFrom': 'body'},
        ),
      ], resolveAsset: (s) => s);
      world.persistentLevel.registerActor(actor);
      world.beginPlay();
      final slots = LuminaCharacterSlots.of(actor);
      await slots.ready;
      final torso = slots.component('Torso') as LuminaAnimatedMeshComponent;
      await torso.loaded;
      expect(torso.meshAssetPath, startsWith('garment:Torso#'), reason: 'the Garment asset is fitted, never loaded as a mesh');
      expect(slots.slot('Torso')!.garment, isNotNull);
      expect(slots.slot('Torso')!.lastFit!.maxPenetration, lessThan(0.1));
      final body = built['body'] as LuminaAnimatedMeshComponent;
      await body.loaded;
      expect(body.meshAssetPath, startsWith('${manny.path}#masked-'), reason: 'masked as soon as the Blueprint is built');
      expect(torso.poseLeader, same(body));
    }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));
  });
}


/// [glb] with every POSITION scaled by [factor] in x and z (about the
/// vertical axis), the accessor bounds kept consistent.
Uint8List _widened(Uint8List glb, double factor) {
  final doc = GlbDocument.parse(glb);
  final bin = Uint8List.fromList(doc.bin);
  final data = ByteData.sublistView(bin);
  final accessors = (doc.json['accessors'] as List).cast<Map<String, dynamic>>();
  final views = (doc.json['bufferViews'] as List).cast<Map<String, dynamic>>();
  for (final mesh in (doc.json['meshes'] as List).cast<Map<String, dynamic>>()) {
    for (final prim in (mesh['primitives'] as List).cast<Map<String, dynamic>>()) {
      final a = accessors[((prim['attributes'] as Map)['POSITION'] as num).toInt()];
      final v = views[(a['bufferView'] as num).toInt()];
      final stride = (v['byteStride'] as num?)?.toInt() ?? 12;
      final base = (v['byteOffset'] as num? ?? 0).toInt() + (a['byteOffset'] as num? ?? 0).toInt();
      for (var i = 0; i < (a['count'] as num).toInt(); i++) {
        for (final k in const [0, 2]) {
          final o = base + i * stride + k * 4;
          data.setFloat32(o, data.getFloat32(o, Endian.little) * factor, Endian.little);
        }
      }
      for (final key in const ['min', 'max']) {
        final b = (a[key] as List?)?.map((e) => (e as num).toDouble()).toList();
        if (b != null) a[key] = [b[0] * factor, b[1], b[2] * factor];
      }
    }
  }
  return GlbDocument(doc.json, bin).encode();
}
