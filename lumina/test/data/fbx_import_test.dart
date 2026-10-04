// FBX import — conversion fix-ups,
// retargeting onto the Third Person mannequin, and the import pipeline end to
// end on real Unreal FBX exports from test-assets/FBX/.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

Directory get _assets {
  final root = Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets';
  return Directory(root);
}

File _fbx(String relative) => File('${_assets.path}/FBX/$relative');

/// The Third Person template's merged mannequin (built by
/// tool/build_third_person_content.dart).
final File _quinn = File(LuminaThirdPersonContent.bundledMeshPath);

/// A UE5-skeleton skeletal mesh export kept in the private test-assets.
File get _ue5Mannequin => File('${_assets.path}/mannequin/exports/SKM_Quinn_Simple.glb');

// ---- small glTF helpers -----------------------------------------------------

typedef _Q = List<double>; // x, y, z, w

_Q _mul(_Q a, _Q b) => [
      a[3] * b[0] + a[0] * b[3] + a[1] * b[2] - a[2] * b[1],
      a[3] * b[1] - a[0] * b[2] + a[1] * b[3] + a[2] * b[0],
      a[3] * b[2] + a[0] * b[1] - a[1] * b[0] + a[2] * b[3],
      a[3] * b[3] - a[0] * b[0] - a[1] * b[1] - a[2] * b[2],
    ];

double _angleDeg(_Q a, _Q b) {
  final d = (a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3]).abs().clamp(0.0, 1.0);
  return 2 * math.acos(d) * 180 / math.pi;
}

Float32List _floats(GlbDocument doc, int accessor) {
  final acc = (doc.json['accessors'] as List)[accessor] as Map;
  final bv = (doc.json['bufferViews'] as List)[acc['bufferView'] as int] as Map;
  final n = const {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}[acc['type']]!;
  final start = ((bv['byteOffset'] as int?) ?? 0) + ((acc['byteOffset'] as int?) ?? 0);
  final data = ByteData.sublistView(doc.bin);
  return Float32List.fromList([
    for (var i = 0; i < (acc['count'] as int) * n; i++) data.getFloat32(start + i * 4, Endian.little),
  ]);
}

/// Model-space rotation of every named node at key [frame] of animation
/// [anim] (rest rotation where a node has no channel).
Map<String, _Q> _worldRotations(GlbDocument doc, int anim, int frame) {
  final nodes = (doc.json['nodes'] as List).cast<Map>();
  final a = (doc.json['animations'] as List)[anim] as Map;
  final local = <int, _Q>{};
  for (var i = 0; i < nodes.length; i++) {
    final r = (nodes[i]['rotation'] as List?) ?? const [0, 0, 0, 1];
    local[i] = [for (final v in r) (v as num).toDouble()];
  }
  for (final c in (a['channels'] as List).cast<Map>()) {
    final target = c['target'] as Map;
    if (target['path'] != 'rotation') continue;
    final sampler = (a['samplers'] as List)[c['sampler'] as int] as Map;
    final out = _floats(doc, sampler['output'] as int);
    final k = math.min(frame, out.length ~/ 4 - 1);
    local[target['node'] as int] = [out[k * 4], out[k * 4 + 1], out[k * 4 + 2], out[k * 4 + 3]];
  }
  final parent = List<int>.filled(nodes.length, -1);
  for (var i = 0; i < nodes.length; i++) {
    for (final c in (nodes[i]['children'] as List?) ?? const []) {
      parent[c as int] = i;
    }
  }
  final world = <int, _Q>{};
  _Q w(int i) => world[i] ??= parent[i] < 0 ? local[i]! : _mul(w(parent[i]), local[i]!);
  return {
    for (var i = 0; i < nodes.length; i++)
      if (nodes[i]['name'] is String) nodes[i]['name'] as String: w(i),
  };
}

/// A real project folder holding the Third Person mannequin the way a Third
/// Person project does (`.lmas` without payload + `.entity.glb` companion).
Directory _projectWithMannequin() {
  final project = Directory.systemTemp.createTempSync('lumina_fbx_import_');
  Directory('${project.path}/contents/meshes/skeletal').createSync(recursive: true);
  File('${project.path}/${LuminaThirdPersonContent.projectMeshGlbPath}').writeAsBytesSync(_quinn.readAsBytesSync());
  File('${project.path}/${LuminaThirdPersonContent.projectMeshAssetPath}').writeAsBytesSync(LuminaAsset(
    assetId: 'quinn-mesh',
    name: LuminaThirdPersonContent.meshAssetName,
    type: AssetType.filameshSk,
    metadata: {
      'payload_format': 'glb',
      'animation_clips': LuminaThirdPersonContent.clipNames.join(','),
    },
  ).toProtoBufferBytes());
  return project;
}

void main() {
  group('FbxImportService.postProcess (exporter fix-ups)', () {
    Uint8List exporterLikeGlb() {
      // Two takes (2 + 1 channels), written the way Assimp's exporter does:
      // one unnamed animation per channel, interpolation under "path", node
      // transforms as matrices.
      final bin = Float32List.fromList([0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1]);
      final json = <String, dynamic>{
        'asset': {'version': '2.0'},
        'scene': 0,
        'scenes': [
          {'nodes': [0]},
        ],
        'nodes': [
          {
            'name': 'root',
            'children': [1],
            'matrix': [1, 0, 0, 0, 0, 0, 1, 0, 0, -1, 0, 0, 0, 0.5, 0, 1], // 90° about X, (0, .5, 0)
          },
          {'name': 'pelvis', 'matrix': [2, 0, 0, 0, 0, 2, 0, 0, 0, 0, 2, 0, 1, 2, 3, 1]},
        ],
        'buffers': [
          {'byteLength': bin.lengthInBytes},
        ],
        'bufferViews': [
          {'buffer': 0, 'byteOffset': 0, 'byteLength': 8},
          {'buffer': 0, 'byteOffset': 8, 'byteLength': 32},
        ],
        'accessors': [
          {'bufferView': 0, 'componentType': 5126, 'count': 2, 'type': 'SCALAR', 'min': [0], 'max': [1]},
          {'bufferView': 1, 'componentType': 5126, 'count': 2, 'type': 'VEC4'},
        ],
        'animations': [
          for (var i = 0; i < 3; i++)
            {
              'channels': [
                {
                  'sampler': 0,
                  'target': {'node': i % 2, 'path': 'rotation'},
                },
              ],
              'samplers': [
                {'input': 0, 'output': 1, 'path': 'LINEAR'},
              ],
            },
        ],
      };
      return GlbDocument(json, bin.buffer.asUint8List()).encode();
    }

    test('merges the per-channel animations into one named clip per take', () {
      final out = FbxImportService.postProcess(
        exporterLikeGlb(),
        takes: [(name: 'AS_Test_Walk', channels: 2), (name: 'AS_Test_Run', channels: 1)],
      );
      final json = GlbDocument.parse(out).json;
      final animations = (json['animations'] as List).cast<Map>();
      expect(animations.map((a) => a['name']), ['AS_Test_Walk', 'AS_Test_Run']);
      expect((animations[0]['channels'] as List), hasLength(2));
      expect((animations[0]['samplers'] as List), hasLength(2));
      expect(((animations[0]['channels'] as List)[1] as Map)['sampler'], 1, reason: 'sampler indices are rebased');
      final sampler = (animations[1]['samplers'] as List).single as Map;
      expect(sampler['interpolation'], 'LINEAR');
      expect(sampler.containsKey('path'), isFalse);
    });

    test('falls back to one clip when the take channel counts do not add up', () {
      final out = FbxImportService.postProcess(exporterLikeGlb(), takes: [(name: 'Only', channels: 7)]);
      final animations = (GlbDocument.parse(out).json['animations'] as List).cast<Map>();
      expect(animations, hasLength(1));
      expect(animations.single['name'], 'Only');
      expect((animations.single['channels'] as List), hasLength(3));
    });

    test('rewrites node matrices as TRS', () {
      final out = FbxImportService.postProcess(exporterLikeGlb(), takes: const []);
      final nodes = (GlbDocument.parse(out).json['nodes'] as List).cast<Map>();
      expect(nodes.every((n) => n['matrix'] == null), isTrue);
      final root = nodes[0];
      expect(root['translation'], [0.0, 0.5, 0.0]);
      final r = (root['rotation'] as List).cast<double>();
      expect(r[0], closeTo(math.sqrt1_2, 1e-9));
      expect(r[3], closeTo(math.sqrt1_2, 1e-9));
      expect(root.containsKey('scale'), isFalse);
      expect(nodes[1]['translation'], [1.0, 2.0, 3.0]);
      expect(nodes[1]['scale'], [2.0, 2.0, 2.0]);
      expect(nodes[1].containsKey('rotation'), isFalse);
    });

    test('names a single take after the file and several as <file>_<take>', () {
      expect(FbxImportService.clipNamesFor('AS_Poker_Dealer_Idle_01', ['Unreal Take']), ['AS_Poker_Dealer_Idle_01']);
      expect(FbxImportService.clipNamesFor('Hero', ['Walk Cycle', 'Walk Cycle', '']),
          ['Hero_Walk_Cycle', 'Hero_Walk_Cycle_2', 'Hero_Take3']);
    });
  });

  group('real Unreal FBX exports', () {
    final haveAssets = _fbx('StaticMeshes/SM_Casino_Chair.FBX').existsSync();

    test('AS_Poker_Dealer_Idle_01 converts to one clip named after the file, nodes as TRS', () {
      final fbx = _fbx('Animations/AS_Poker_Dealer_Idle_01.FBX');
      if (!haveAssets || !fbx.existsSync()) return markTestSkipped('test-assets/FBX missing');
      final result = FbxImportService.convertSync(fbx.path);
      expect(result.clipNames, ['AS_Poker_Dealer_Idle_01']);
      final json = GlbDocument.parse(result.glb).json;
      final anim = (json['animations'] as List).single as Map;
      expect(anim['name'], 'AS_Poker_Dealer_Idle_01');
      expect((anim['channels'] as List).length, 61 * 3, reason: 'T, R and S for each of the 61 bone channels');
      expect((json['nodes'] as List).every((n) => (n as Map)['matrix'] == null), isTrue);
      expect(result.toAssetMetadata()['source_format'], 'FBX');
      expect(result.toAssetMetadata()['fbx_up_axis'], '+Z');
    });

    test('retargets AS_Poker_Dealer_Idle_01 (UE4 skeleton) onto Quinn (UE5): model-space rotations match', () {
      final fbx = _fbx('Animations/AS_Poker_Dealer_Idle_01.FBX');
      if (!haveAssets || !fbx.existsSync()) return markTestSkipped('test-assets/FBX missing');
      if (!_ue5Mannequin.existsSync()) return markTestSkipped('test-assets/mannequin/exports missing');

      final clip = FbxImportService.convertSync(fbx.path).glb;
      final quinn = _ue5Mannequin.readAsBytesSync();
      final match = GlbAnimationRetargeter.match(target: quinn, clip: clip);
      // Every bone the clip animates exists on Quinn (its unanimated
      // breast_l/r helpers do not count).
      expect(match.score, 1.0);
      expect(match.missing, isEmpty);

      final result = GlbAnimationRetargeter.retargetInto(target: quinn, clip: clip, clipName: 'AS_Poker_Dealer_Idle_01');
      final before = GlbAnimationMerger.animationNames(quinn);
      final after = GlbAnimationMerger.animationNames(result.glb);
      expect(after, [...before, 'AS_Poker_Dealer_Idle_01']);
      expect(result.clipIndex, before.length);
      expect(result.duration, closeTo(12.97, 0.05));
      expect(result.mappedBones, containsAll(['root', 'pelvis', 'spine_03', 'clavicle_l', 'hand_r', 'head']));
      expect(result.restBones, containsAll(['spine_04', 'spine_05', 'neck_02']));
      expect(result.ignoredSourceBones, isEmpty);
      // Quinn's legs (0.87 m) over the clip's authoring legs (0.86 m).
      expect(result.pelvisTranslationScale, inInclusiveRange(1.0, 1.05));

      // Every mapped bone points where the clip's bone points, in model
      // space, across the clip (frames 0, middle, last).
      final src = GlbDocument.parse(clip);
      final tgt = GlbDocument.parse(result.glb);
      for (final frame in [0, 190, 389]) {
        final s = _worldRotations(src, 0, frame);
        final t = _worldRotations(tgt, result.clipIndex, frame);
        for (final bone in ['pelvis', 'spine_03', 'clavicle_l', 'upperarm_l', 'lowerarm_r', 'hand_r', 'thigh_l', 'foot_r', 'head']) {
          expect(_angleDeg(s[bone]!, t[bone]!), lessThan(0.5), reason: '$bone at frame $frame');
        }
      }

      // Re-running with the same name replaces the clip instead of adding one.
      final again = GlbAnimationRetargeter.retargetInto(target: result.glb, clip: clip, clipName: 'AS_Poker_Dealer_Idle_01');
      expect(GlbAnimationMerger.animationNames(again.glb), after);
      expect(again.clipIndex, result.clipIndex);
    });

    test('retargets onto skeleton with differing bone axis conventions without flipping limbs', () {
      final fbx = _fbx('Animations/AS_Poker_Dealer_Idle_01.FBX');
      if (!haveAssets || !fbx.existsSync()) return markTestSkipped('test-assets/FBX missing');
      if (!_quinn.existsSync()) return markTestSkipped('bundled mesh missing');

      final clip = FbxImportService.convertSync(fbx.path).glb;
      final target = _quinn.readAsBytesSync();
      final result = GlbAnimationRetargeter.retargetInto(target: target, clip: clip, clipName: 'Dealer_Retargeted');
      expect(result.mappedBones, containsAll(['pelvis', 'thigh_l', 'thigh_r', 'spine_01']));

      // Thigh rotation maintaining downward orientation (X component near 0.9-1.0 in Blender bind space)
      final doc = GlbDocument.parse(result.glb);
      final r0 = _worldRotations(doc, result.clipIndex, 0);
      final thighRot = r0['thigh_l']!;
      expect(thighRot[0].abs(), greaterThan(0.7), reason: 'thigh must maintain downward bind orientation');
      final thighRotR = r0['thigh_r']!;
      expect(thighRotR[0].abs(), greaterThan(0.7), reason: 'right thigh must maintain downward bind orientation');
    });

    test('external textures: found by file name are embedded, missing ones are dropped with their slots', () {
      final chair = _fbx('StaticMeshes/SM_Casino_Chair.FBX');
      final laptop = _fbx('StaticMeshes/SM_Laptop.FBX');
      final manny = File('${_assets.path}/mannequin/SKM_Manny_Simple.glb');
      if (!haveAssets || !manny.existsSync()) return markTestSkipped('test-assets missing');

      // The chair names W:/Cafe/Furniture/Sofa/textures/T_Leather_Normal.png:
      // nowhere on this machine.
      final missing = FbxImportService.convertSync(chair.path);
      expect(missing.report[FbxImportService.missingTexturesKey], ['W:/Cafe/Furniture/Sofa/textures/T_Leather_Normal.png']);
      final json = GlbDocument.parse(missing.glb).json;
      expect(json['images'], isNull);
      expect(json['textures'], isNull);
      expect(jsonEncode(json['materials']), isNot(contains('Texture')), reason: 'no material samples a dropped texture');
      expect(missing.toAssetMetadata()['fbx_missing_textures'], contains('T_Leather_Normal.png'));

      // The laptop names .../Computers/textures/T_Laptop_BC.png; put a real
      // PNG of that name in a Textures folder next to the FBX's folder.
      final dir = Directory.systemTemp.createTempSync('fbx_textures_');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory('${dir.path}/Meshes').createSync();
      Directory('${dir.path}/Textures').createSync();
      final fbx = laptop.copySync('${dir.path}/Meshes/SM_Laptop.FBX');
      // A real PNG: the first one embedded in the Manny GLB export.
      final mannyDoc = GlbDocument.parse(manny.readAsBytesSync());
      final image = (mannyDoc.json['images'] as List).cast<Map>().firstWhere((i) => i['mimeType'] == 'image/png');
      final view = (mannyDoc.json['bufferViews'] as List)[image['bufferView'] as int] as Map;
      final png = mannyDoc.bin.sublist(view['byteOffset'] as int? ?? 0, (view['byteOffset'] as int? ?? 0) + (view['byteLength'] as int));
      expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47], reason: 'the fixture image is a PNG');
      File('${dir.path}/Textures/t_laptop_bc.PNG').writeAsBytesSync(png);

      final found = FbxImportService.convertSync(fbx.path);
      expect(found.report[FbxImportService.embeddedTexturesKey], ['t_laptop_bc.PNG']);
      expect(found.report[FbxImportService.missingTexturesKey], isEmpty);
      final foundJson = GlbDocument.parse(found.glb).json;
      final embedded = (foundJson['images'] as List).single as Map;
      expect(embedded['uri'], isNull);
      expect(embedded['mimeType'], 'image/png');
      expect(jsonEncode(foundJson['materials']), contains('Texture'), reason: 'the laptop material still samples it');
    });

    test('a GLB without a skin is refused as a retarget target', () {
      final fbx = _fbx('Animations/AS_Poker_Dealer_Idle_01.FBX');
      final chair = _fbx('StaticMeshes/SM_Casino_Chair.FBX');
      if (!haveAssets || !fbx.existsSync()) return markTestSkipped('test-assets/FBX missing');
      final clip = FbxImportService.convertSync(fbx.path).glb;
      final prop = FbxImportService.convertSync(chair.path).glb;
      expect(() => GlbAnimationRetargeter.retargetInto(target: prop, clip: clip, clipName: 'x'), throwsFormatException);
    });
  });

  group('import pipeline (AssetRepository / ImportAssetUseCase)', () {
    final haveAssets = _fbx('StaticMeshes/SM_Casino_Chair.FBX').existsSync();
    late Directory project;

    setUp(() => project = _projectWithMannequin());
    tearDown(() {
      if (project.existsSync()) project.deleteSync(recursive: true);
    });

    test('SM_Casino_Chair.FBX imports as an upright ~0.97 m static mesh with its UCX hull kept as data', () async {
      if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
      final result = await ImportAssetUseCase()(
        projectDir: project.path,
        sourceFilePath: _fbx('StaticMeshes/SM_Casino_Chair.FBX').path,
      );
      expect(result.isSuccess, isTrue, reason: result.error);
      expect(result.asset!.relativePath, 'contents/meshes/static/SM_Casino_Chair.lmas');
      expect(result.asset!.type, AssetType.filamesh);

      final lmas = LuminaAsset.fromBytes(File('${project.path}/contents/meshes/static/SM_Casino_Chair.lmas').readAsBytesSync());
      expect(lmas.metadata['source_format'], 'FBX');
      expect(lmas.metadata['fbx_up_axis'], '+Z');
      final hulls = (jsonDecode(lmas.metadata['collision_hulls']!) as List).cast<Map>();
      expect(hulls.single['name'], 'UCX_SM_Casino_Chair');
      expect((hulls.single['points'] as List), hasLength((hulls.single['vertex_count'] as int) * 3));

      final mesh = await AssetRepository.loadMeshFromDisk(
        '${project.path}/contents/meshes/static/SM_Casino_Chair.lmas',
      );
      expect(mesh, isNotNull);
      final size = [for (var i = 0; i < 3; i++) mesh!.maxBounds[i] - mesh.minBounds[i]];
      expect(size[1], closeTo(0.968, 0.01), reason: 'upright: the height is along +Y, in metres');
      expect(size[0], lessThan(0.6));
      expect(size[2], lessThan(0.7));
      expect(Directory('${project.path}/temp').listSync(), isEmpty, reason: 'staging leaves nothing behind');
      expect(lmas.metadata['fbx_missing_textures'], contains('T_Leather_Normal.png'));
      expect(Directory('${project.path}/contents/textures/SM_Casino_Chair').existsSync(), isFalse,
          reason: 'no texture asset without an image');
    });

    test('AS_Poker_Dealer_Idle_01.FBX binds to the Third Person mannequin automatically', () async {
      if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
      if (!_quinn.existsSync()) return markTestSkipped('build tool/build_third_person_content.dart first');
      final result = await ImportAssetUseCase()(
        projectDir: project.path,
        sourceFilePath: _fbx('Animations/AS_Poker_Dealer_Idle_01.FBX').path,
      );
      expect(result.isSuccess, isTrue, reason: result.error);
      expect(result.asset!.type, AssetType.animation);
      expect(result.asset!.relativePath, 'contents/animations/AS_Poker_Dealer_Idle_01/AS_Poker_Dealer_Idle_01.lmas');

      final clip = LuminaAsset.fromBytes(File('${project.path}/${result.asset!.relativePath}').readAsBytesSync());
      expect(clip.rawPayload == null || clip.rawPayload!.isEmpty, isTrue, reason: 'the clip lives in the mesh GLB');
      expect(clip.metadata['source_mesh'], LuminaThirdPersonContent.projectMeshAssetPath);
      expect(clip.metadata['clip_name'], 'AS_Poker_Dealer_Idle_01');
      expect(clip.metadata['clip_index'], '${LuminaThirdPersonContent.clipNames.length}');
      expect(clip.metadata['retarget_status'], startsWith('bound: matched by bone names'));
      expect(clip.references.single.slotName, 'skeletal_mesh');
      expect(clip.references.single.assetId, 'quinn-mesh');

      final meshGlb = File('${project.path}/${LuminaThirdPersonContent.projectMeshGlbPath}').readAsBytesSync();
      expect(GlbAnimationMerger.animationNames(meshGlb), [...LuminaThirdPersonContent.clipNames, 'AS_Poker_Dealer_Idle_01']);
      final mesh = LuminaAsset.fromBytes(File('${project.path}/${LuminaThirdPersonContent.projectMeshAssetPath}').readAsBytesSync());
      expect(mesh.metadata['animation_clips'], endsWith(',AS_Poker_Dealer_Idle_01'));
      expect(mesh.rawPayload == null || mesh.rawPayload!.isEmpty, isTrue, reason: 'template meshes stay payload-free');

      // The mesh loader sees the new clip (what the Animation editor plays).
      final parsed = await AssetRepository.loadMeshFromDisk('${project.path}/${LuminaThirdPersonContent.projectMeshAssetPath}');
      expect(parsed!.animations.map((a) => a.name), contains('AS_Poker_Dealer_Idle_01'));
    });

    test('an animation imported with no skeletal mesh chosen stays unbound with its GLB', () async {
      if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
      final result = await ImportAssetUseCase()(
        projectDir: project.path,
        sourceFilePath: _fbx('Animations/AS_CCG_Player_DrawFromDeck.FBX').path,
        targetSkeletonPath: '',
      );
      expect(result.isSuccess, isTrue, reason: result.error);
      final clip = LuminaAsset.fromBytes(File('${project.path}/${result.asset!.relativePath}').readAsBytesSync());
      expect(clip.metadata['retarget_status'], startsWith('not bound'));
      expect(GlbAnimationMerger.animationNames(clip.rawPayload!), ['AS_CCG_Player_DrawFromDeck']);
      final meshGlb = File('${project.path}/${LuminaThirdPersonContent.projectMeshGlbPath}').readAsBytesSync();
      expect(GlbAnimationMerger.animationNames(meshGlb), isNot(contains('AS_CCG_Player_DrawFromDeck')));
    });

    test('the importer ranks the imported skinned SKM_Manny_Simple.FBX as a skeleton too', () async {
      if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
      final manny = await ImportAssetUseCase()(
        projectDir: project.path,
        sourceFilePath: _fbx('SkeletalMeshes/SKM_Manny_Simple.FBX').path,
      );
      expect(manny.isSuccess, isTrue, reason: manny.error);
      expect(manny.asset!.type, AssetType.filameshSk);
      expect(manny.asset!.relativePath, 'contents/meshes/skeletal/SKM_Manny_Simple.lmas');
      final mesh = await AssetRepository.loadMeshFromDisk('${project.path}/contents/meshes/skeletal/SKM_Manny_Simple.lmas');
      final height = mesh!.maxBounds[1] - mesh.minBounds[1];
      expect(height, inInclusiveRange(1.5, 2.1), reason: 'the mannequin stands ~1.8 m tall along +Y');

      final clip = FbxImportService.convertSync(_fbx('Animations/AS_Blackjack_Dealer_DealCard.FBX').path).glb;
      final ranked = AnimationImportBinder.rankTargets(
        projectPath: project.path,
        skeletalMeshLmasPaths: [LuminaThirdPersonContent.projectMeshAssetPath, 'contents/meshes/skeletal/SKM_Manny_Simple.lmas'],
        clipGlb: clip,
      );
      expect(ranked, hasLength(2));
      expect(ranked.firstWhere((c) => c.lmasPath.endsWith('SKM_Manny_Simple.lmas')).match.score, greaterThan(0.9));
      expect(ranked.every((c) => c.match.score > 0.8), isTrue, reason: 'the template character shares the bone names');

      // Chosen explicitly, the clip goes onto Manny instead of the template character.
      final bound = await ImportAssetUseCase()(
        projectDir: project.path,
        sourceFilePath: _fbx('Animations/AS_Blackjack_Dealer_DealCard.FBX').path,
        targetSkeletonPath: 'contents/meshes/skeletal/SKM_Manny_Simple.lmas',
      );
      expect(bound.isSuccess, isTrue, reason: bound.error);
      final asset = LuminaAsset.fromBytes(File('${project.path}/${bound.asset!.relativePath}').readAsBytesSync());
      expect(asset.metadata['source_mesh'], 'contents/meshes/skeletal/SKM_Manny_Simple.lmas');
      final mannyLmas = LuminaAsset.fromBytes(File('${project.path}/contents/meshes/skeletal/SKM_Manny_Simple.lmas').readAsBytesSync());
      expect(GlbAnimationMerger.animationNames(mannyLmas.rawPayload!), contains('AS_Blackjack_Dealer_DealCard'),
          reason: 'an imported mesh keeps its payload in step with its companion');
    });

    test('a corrupt .fbx fails with a conversion message and writes no asset', () async {
      final bogus = File('${project.path}/model.fbx')..writeAsBytesSync([0, 1, 2]);
      final result = await ImportAssetUseCase()(projectDir: project.path, sourceFilePath: bogus.path);
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('FBX conversion of "model.fbx" failed'));
      expect(Directory('${project.path}/contents/meshes/static').existsSync(), isFalse);
    });
  });
}
