import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/glb_animation_merger.dart';
import 'package:lumina/testing.dart';

/// Gltfio only plays animations that live in the same asset as
/// the bones they move, so the mannequin's one-clip-per-file sequences are
/// merged into the skinned mesh. Everything here reads the real exports.
void main() {
  // The user's drop folder (Quinn + the nine clips it was exported with) and
  // the older test-assets set, whose clips list the finger bones in a
  // different order than SKM_Manny_Simple.
  final userMannequin = Directory('${SmokeArtifacts.testAssetsDir.path}/mannequin/exports');
  final testMannequin = Directory('${SmokeArtifacts.testAssetsDir.path}/mannequin');

  Uint8List read(Directory dir, String file) => File('${dir.path}/$file').readAsBytesSync();

  List<Map<String, dynamic>> listOf(Map<String, dynamic> json, String key) =>
      ((json[key] as List?) ?? const []).cast<Map<String, dynamic>>();

  String? nodeName(Map<String, dynamic> json, int node) =>
      (listOf(json, 'nodes')[node])['name'] as String?;

  /// The raw bytes an accessor covers, element by element, stride removed.
  Uint8List accessorBytes(GlbDocument doc, int accessor) {
    final acc = listOf(doc.json, 'accessors')[accessor];
    final bv = listOf(doc.json, 'bufferViews')[acc['bufferView'] as int];
    final count = acc['count'] as int;
    final size = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}[acc['type']]! * 4;
    final stride = (bv['byteStride'] as int?) ?? size;
    final start = ((bv['byteOffset'] as int?) ?? 0) + ((acc['byteOffset'] as int?) ?? 0);
    final out = Uint8List(count * size);
    for (var i = 0; i < count; i++) {
      out.setRange(i * size, (i + 1) * size, doc.bin, start + i * stride);
    }
    return out;
  }

  /// The output bytes of the channel animating [bone]'s [path] in animation [anim].
  Uint8List channelOutput(GlbDocument doc, int anim, String bone, String path) {
    final animation = listOf(doc.json, 'animations')[anim];
    for (final c in (animation['channels'] as List).cast<Map<String, dynamic>>()) {
      final target = c['target'] as Map<String, dynamic>;
      if (target['path'] != path) continue;
      if (nodeName(doc.json, target['node'] as int) != bone) continue;
      final sampler = (animation['samplers'] as List)[c['sampler'] as int] as Map<String, dynamic>;
      return accessorBytes(doc, sampler['output'] as int);
    }
    fail('no $path channel for $bone');
  }

  group('GlbAnimationMerger', () {
    test('merges named clips into the base mesh, retargeting every channel to the same-named bone', () {
      if (!userMannequin.existsSync()) {
        markTestSkipped('test-assets/mannequin/exports is not present');
        return;
      }
      final base = read(userMannequin, 'SKM_Quinn_Simple.glb');
      final merged = GlbAnimationMerger.merge(base: base, clips: [
        GlbClipSource(name: 'MM_Idle', bytes: read(userMannequin, 'MM_Idle.glb')),
        GlbClipSource(name: 'MF_Unarmed_Walk_Fwd', bytes: read(userMannequin, 'MF_Unarmed_Walk_Fwd.glb')),
      ]);

      expect(GlbAnimationMerger.animationNames(merged), ['MM_Idle', 'MF_Unarmed_Walk_Fwd']);

      final out = GlbDocument.parse(merged);
      final original = GlbDocument.parse(base);
      for (final key in ['meshes', 'skins', 'images', 'materials', 'nodes']) {
        expect(listOf(out.json, key).length, listOf(original.json, key).length, reason: key);
      }

      final source = GlbDocument.parse(read(userMannequin, 'MF_Unarmed_Walk_Fwd.glb'));
      final srcChannels = (listOf(source.json, 'animations').first['channels'] as List).cast<Map<String, dynamic>>();
      final outChannels = (listOf(out.json, 'animations')[1]['channels'] as List).cast<Map<String, dynamic>>();
      expect(outChannels.length, srcChannels.length);
      for (var i = 0; i < srcChannels.length; i++) {
        final srcTarget = srcChannels[i]['target'] as Map<String, dynamic>;
        final outTarget = outChannels[i]['target'] as Map<String, dynamic>;
        expect(nodeName(out.json, outTarget['node'] as int), nodeName(source.json, srcTarget['node'] as int));
        expect(outTarget['path'], srcTarget['path']);
      }
    });

    test('retargets by bone name, not by node index', () {
      if (!testMannequin.existsSync()) {
        markTestSkipped('test-assets/mannequin is not present');
        return;
      }
      final base = read(testMannequin, 'SKM_Manny_Simple.glb');
      final clipBytes = read(testMannequin, 'MF_Unarmed_Walk_Fwd.glb');
      final baseDoc = GlbDocument.parse(base);
      final clipDoc = GlbDocument.parse(clipBytes);

      // The premise: the two exports disagree on where this bone sits.
      final baseIndex = listOf(baseDoc.json, 'nodes').indexWhere((n) => n['name'] == 'index_metacarpal_l');
      final clipIndex = listOf(clipDoc.json, 'nodes').indexWhere((n) => n['name'] == 'index_metacarpal_l');
      expect(baseIndex, isNot(clipIndex), reason: 'the fixture must permute the bone to prove anything');

      final merged = GlbDocument.parse(GlbAnimationMerger.merge(
        base: base,
        clips: [GlbClipSource(name: 'Walk', bytes: clipBytes)],
      ));

      expect(channelOutput(merged, 0, 'index_metacarpal_l', 'rotation'),
          channelOutput(clipDoc, 0, 'index_metacarpal_l', 'rotation'));
      // ...and not the keys of whatever bone the clip keeps at the base's index.
      final impostor = nodeName(clipDoc.json, baseIndex)!;
      expect(impostor, isNot('index_metacarpal_l'));
      expect(channelOutput(merged, 0, 'index_metacarpal_l', 'rotation'),
          isNot(channelOutput(clipDoc, 0, impostor, 'rotation')));
    });

    test('copies key data byte-exactly into 4-byte aligned buffer views', () {
      if (!userMannequin.existsSync()) {
        markTestSkipped('test-assets/mannequin/exports is not present');
        return;
      }
      final base = read(userMannequin, 'SKM_Quinn_Simple.glb');
      final clipBytes = read(userMannequin, 'MF_Unarmed_Walk_Left.glb');
      final baseViewCount = listOf(GlbDocument.parse(base).json, 'bufferViews').length;
      final merged = GlbDocument.parse(GlbAnimationMerger.merge(
        base: base,
        clips: [GlbClipSource(name: 'Left', bytes: clipBytes)],
      ));
      final clipDoc = GlbDocument.parse(clipBytes);

      for (final bone in ['pelvis', 'thigh_r', 'hand_l']) {
        for (final path in ['translation', 'rotation', 'scale']) {
          expect(channelOutput(merged, 0, bone, path), channelOutput(clipDoc, 0, bone, path), reason: '$bone.$path');
        }
      }

      final views = listOf(merged.json, 'bufferViews');
      expect(views.length, greaterThan(baseViewCount));
      for (final bv in views.skip(baseViewCount)) {
        expect((bv['byteOffset'] as int) % 4, 0);
      }
      expect((merged.json['buffers'] as List).single['byteLength'], merged.bin.length);

      // One key-time accessor is shared by every sampler of the clip, and is
      // copied once rather than once per channel.
      final animation = listOf(merged.json, 'animations').single;
      final inputs = (animation['samplers'] as List).map((s) => (s as Map)['input']).toSet();
      final srcInputs = (listOf(clipDoc.json, 'animations').first['samplers'] as List)
          .map((s) => (s as Map)['input'])
          .toSet();
      expect(inputs.length, srcInputs.length);
    });

    test('rejects inputs it cannot merge, naming the problem', () {
      if (!userMannequin.existsSync()) {
        markTestSkipped('test-assets/mannequin/exports is not present');
        return;
      }
      final base = read(userMannequin, 'SKM_Quinn_Simple.glb');
      final clip = read(userMannequin, 'MM_Idle.glb');

      expect(
        () => GlbAnimationMerger.merge(base: Uint8List.fromList(List.filled(64, 7)), clips: const []),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('not a GLB'))),
      );
      expect(
        () => GlbAnimationMerger.merge(base: base, clips: [GlbClipSource(name: 'X', bytes: clip, animationIndex: 3)]),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('animation 3'))),
      );

      // A base that lost a bone: rename pelvis and merge a clip that animates it.
      final doc = GlbDocument.parse(base);
      listOf(doc.json, 'nodes').firstWhere((n) => n['name'] == 'pelvis')['name'] = 'hips';
      expect(
        () => GlbAnimationMerger.merge(base: doc.encode(), clips: [GlbClipSource(name: 'Idle', bytes: clip)]),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('pelvis'))),
      );
    });
  });
}
