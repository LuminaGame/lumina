import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';

/// The idle-break and turn-in-place exports carry a 71-bone
/// skeleton with `breast_l/r` the mannequin lacks, and MM_Land / MM_WallJump
/// arrived as `.gltf` + `.bin` pairs. Everything here reads the real exports
/// in the private test-assets/mannequin/exports (skipped when absent).
void main() {
  final mannequin = Directory('${SmokeArtifacts.testAssetsDir.path}/mannequin/exports');
  Uint8List read(String file) => File('${mannequin.path}/$file').readAsBytesSync();

  List<Map<String, dynamic>> listOf(Map<String, dynamic> json, String key) =>
      ((json[key] as List?) ?? const []).cast<Map<String, dynamic>>();

  /// Bone names animated by animation [index] of [glb].
  Set<String> animatedBones(Uint8List glb, int index) {
    final doc = GlbDocument.parse(glb);
    final nodes = listOf(doc.json, 'nodes');
    final animation = listOf(doc.json, 'animations')[index];
    return {
      for (final c in (animation['channels'] as List).cast<Map<String, dynamic>>())
        nodes[(c['target'] as Map)['node'] as int]['name'] as String,
    };
  }

  group('GlbAnimationMerger.skipMissingBones', () {
    test('Idle_01 keeps 69 bones, drops breast_l/breast_r and reports them; without the flag it throws naming both',
        () {
      if (!mannequin.existsSync()) {
        markTestSkipped('test-assets/mannequin/exports is not present');
        return;
      }
      final base = read('SKM_Quinn_Simple.glb');
      // Verbatim (no rotation-only retarget): this test is about the missing bones only.
      final idle = GlbClipSource(name: 'Idle_01', bytes: read('Idle_01.glb'), rotationOnly: false);
      expect(animatedBones(idle.bytes, 0).length, 70, reason: 'the export animates 70 of its 71 nodes');

      expect(
        () => GlbAnimationMerger.merge(base: base, clips: [idle]),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', allOf(contains('breast_l'), contains('breast_r')))),
      );

      final result = GlbAnimationMerger.mergeWithReport(base: base, clips: [idle], skipMissingBones: true);
      final report = result.report.forClip('Idle_01')!;
      expect(report.droppedBones.toSet(), {'breast_l', 'breast_r'});
      expect(report.droppedChannels, 6, reason: 'translation, rotation and scale per dropped bone');
      expect(report.keptBones.length, 68);
      expect(report.keptChannels, 204);
      expect(report.keeps(['root', 'pelvis', 'spine_01']), isTrue);
      expect(report.toString(), contains('dropped breast_r, breast_l'));

      // The merged clip animates exactly the kept bones — 69 nodes of the
      // base share names with the export, minus the one it does not move.
      final merged = animatedBones(result.bytes, 0);
      expect(merged, report.keptBones.toSet());
      expect(merged, isNot(contains('breast_l')));
      expect(GlbAnimationMerger.animationNames(result.bytes), ['Idle_01']);

      // Dropped channels take no keys along: every sampler is referenced.
      final doc = GlbDocument.parse(result.bytes);
      final animation = listOf(doc.json, 'animations').single;
      final used = {for (final c in (animation['channels'] as List).cast<Map>()) c['sampler'] as int};
      expect(used.length, (animation['samplers'] as List).length);
    });

    test('a clip whose bones all exist reports nothing dropped and merges byte-identically to merge()', () {
      if (!mannequin.existsSync()) {
        markTestSkipped('test-assets/mannequin/exports is not present');
        return;
      }
      final base = read('SKM_Quinn_Simple.glb');
      final jump = GlbClipSource(name: 'MM_Jump', bytes: read('MM_Jump.glb'));
      final plain = GlbAnimationMerger.merge(base: base, clips: [jump]);
      final result = GlbAnimationMerger.mergeWithReport(base: base, clips: [jump], skipMissingBones: true);
      expect(result.report.clips.single.droppedAny, isFalse);
      expect(result.report.clips.single.keptChannels, 267);
      expect(result.bytes, plain);
    });
  });

  group('GlbAnimationMerger.hasCollapsedScales', () {
    test('the Turn_* exports are additive deltas (every scale key 0); their _Data companions hold the poses', () {
      if (!mannequin.existsSync()) {
        markTestSkipped('test-assets/mannequin/exports is not present');
        return;
      }
      for (final turn in LuminaThirdPersonContent.turnClips.keys) {
        expect(GlbAnimationMerger.hasCollapsedScales(read('$turn.glb')), isTrue, reason: turn);
        expect(GlbAnimationMerger.hasCollapsedScales(read('${turn}_Data.glb')), isFalse, reason: '${turn}_Data');
      }
      expect(GlbAnimationMerger.hasCollapsedScales(read('Idle_01.glb')), isFalse);
      expect(GlbAnimationMerger.hasCollapsedScales(read('MM_Jump.glb')), isFalse);
      expect(GlbAnimationMerger.hasCollapsedScales(read('SKM_Quinn_Simple.glb')), isFalse, reason: 'no animation at all');
    });
  });

  group('GlbClipSource.fromGltf', () {
    test("MM_Land.gltf reads MM_Land.bin, is named after the file and merges as 'MM_Land'; textures are not needed", () {
      if (!mannequin.existsSync()) {
        markTestSkipped('test-assets/mannequin/exports is not present');
        return;
      }
      final gltf = File('${mannequin.path}/MM_Land.gltf');
      final json = jsonDecode(gltf.readAsStringSync()) as Map<String, dynamic>;
      expect((json['images'] as List).length, greaterThan(0), reason: 'the export references texture PNGs');
      for (final image in (json['images'] as List).cast<Map>()) {
        expect(File('${mannequin.path}/${image['uri']}').existsSync(), isFalse, reason: 'the PNGs were never shipped');
      }

      final source = GlbClipSource.fromGltf(gltf);
      expect(source.name, 'MM_Land');
      final doc = GlbDocument.parse(source.bytes);
      expect(doc.bin.length, File('${mannequin.path}/MM_Land.bin').lengthSync());
      expect(doc.json['images'], isNull);
      expect(doc.json['buffers'], [
        {'byteLength': doc.bin.length}
      ]);
      expect(GlbAnimationMerger.animationNames(source.bytes), ['MM_Land_0']);

      final merged = GlbAnimationMerger.merge(base: read('SKM_Quinn_Simple.glb'), clips: [source]);
      expect(GlbAnimationMerger.animationNames(merged), ['MM_Land']);
      expect(animatedBones(merged, 0).length, 89);
    });

    test('a missing sibling .bin is a FileSystemException; a data: buffer is decoded inline', () {
      final dir = Directory.systemTemp.createTempSync('lumina_gltf_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final orphan = File('${dir.path}/orphan.gltf')
        ..writeAsStringSync(jsonEncode({
          'asset': {'version': '2.0'},
          'buffers': [
            {'uri': 'orphan.bin', 'byteLength': 4}
          ],
        }));
      expect(() => GlbClipSource.fromGltf(orphan), throwsA(isA<FileSystemException>()));

      final inline = File('${dir.path}/inline.gltf')
        ..writeAsStringSync(jsonEncode({
          'asset': {'version': '2.0'},
          'buffers': [
            {'uri': 'data:application/octet-stream;base64,${base64Encode([1, 2, 3, 4])}', 'byteLength': 4}
          ],
          'animations': [
            {'name': 'inline_0', 'channels': [], 'samplers': []}
          ],
        }));
      final source = GlbClipSource.fromGltf(inline, name: 'Inline');
      expect(source.name, 'Inline');
      expect(GlbDocument.parse(source.bytes).bin, [1, 2, 3, 4]);
    });
  });

  group('the Third Person bundle', () {
    test('MM_Dash is a root-motion export: stripRootMotion drops its root translation (and only that), the report says so', () {
      if (!mannequin.existsSync()) {
        markTestSkipped('test-assets/mannequin/exports is not present');
        return;
      }
      final base = read('SKM_Quinn_Simple.glb');
      final dash = read('MM_Dash.glb');
      List<(String, String)> channelsOf(Uint8List glb, String clip) {
        final doc = GlbDocument.parse(glb);
        final nodes = listOf(doc.json, 'nodes');
        final animation = listOf(doc.json, 'animations').firstWhere((a) => a['name'] == clip);
        return [
          for (final c in (animation['channels'] as List).cast<Map<String, dynamic>>())
            (nodes[(c['target'] as Map)['node'] as int]['name'] as String, (c['target'] as Map)['path'] as String),
        ];
      }
      final srcChannels = channelsOf(dash, listOf(GlbDocument.parse(dash).json, 'animations').first['name'] as String);
      expect(srcChannels, contains(('root', 'translation')));

      final kept = GlbAnimationMerger.mergeWithReport(base: base, clips: [GlbClipSource(name: 'MM_Dash', bytes: dash)]);
      expect(kept.report.clips.single.strippedRootMotionChannels, 0);
      expect(channelsOf(kept.bytes, 'MM_Dash'), srcChannels);

      final stripped = GlbAnimationMerger.mergeWithReport(
          base: base, clips: [GlbClipSource(name: 'MM_Dash', bytes: dash, stripRootMotion: true)]);
      final report = stripped.report.clips.single;
      expect(report.strippedRootMotionChannels, 1);
      expect(report.droppedBones, isEmpty);
      expect(report.keptChannels, srcChannels.length - 1);
      expect(report.keeps(['root', 'pelvis']), isTrue, reason: 'root keeps its rotation / scale');
      expect(report.toString(), contains('root motion stripped (1 channel)'));
      final out = channelsOf(stripped.bytes, 'MM_Dash');
      expect(out, isNot(contains(('root', 'translation'))));
      expect(out, srcChannels.where((c) => c != ('root', 'translation')).toList());
    });

    // The 71-bone exports have other bone lengths; copying their
    // translation channels stretched the mannequin's spine by ~30 cm.
    group('rotation-only retarget', () {
      const spine = ['spine_01', 'spine_02', 'spine_03', 'spine_04', 'spine_05', 'neck_01', 'neck_02', 'head'];

      /// Each bone's translation (its length from the parent) as the merged
      /// clip [clip] of [glb] plays it: the translation channel's first key
      /// when there is one, else the bind translation ([clip] null = bind).
      Map<String, List<double>> boneOffsets(Uint8List glb, String? clip, Iterable<String> bones) {
        final doc = GlbDocument.parse(glb);
        final nodes = listOf(doc.json, 'nodes');
        final accessors = listOf(doc.json, 'accessors');
        final views = listOf(doc.json, 'bufferViews');
        final animation = clip == null ? null : listOf(doc.json, 'animations').firstWhere((a) => a['name'] == clip);
        final out = <String, List<double>>{};
        for (final bone in bones) {
          final index = nodes.indexWhere((n) => n['name'] == bone);
          expect(index, greaterThanOrEqualTo(0), reason: bone);
          out[bone] = ((nodes[index]['translation'] as List?) ?? [0.0, 0.0, 0.0]).cast<num>().map((x) => x.toDouble()).toList();
          if (animation == null) continue;
          for (final c in (animation['channels'] as List).cast<Map<String, dynamic>>()) {
            final target = c['target'] as Map;
            if (target['node'] != index || target['path'] != 'translation') continue;
            final sampler = (animation['samplers'] as List)[c['sampler'] as int] as Map;
            final acc = accessors[sampler['output'] as int];
            final view = views[acc['bufferView'] as int];
            final data = ByteData.sublistView(doc.bin, (view['byteOffset'] as int? ?? 0) + (acc['byteOffset'] as int? ?? 0));
            out[bone] = [for (var k = 0; k < 3; k++) data.getFloat32(k * 4, Endian.little)];
          }
        }
        return out;
      }

      double length(List<double> v) => math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);

      test('verbatim (rotationOnly: false), Idle_02 moves spine_01 to 0.115 m from the base bind 0.025 m: the stretch', () {
        if (!mannequin.existsSync()) {
          markTestSkipped('test-assets/mannequin/exports is not present');
          return;
        }
        final base = read('SKM_Quinn_Simple.glb');
        final merged = GlbAnimationMerger.mergeWithReport(
            base: base,
            clips: [GlbClipSource(name: 'Idle_02', bytes: read('Idle_02.glb'), rotationOnly: false)],
            skipMissingBones: true);
        expect(merged.report.clips.single.rotationOnly, isFalse);
        final bind = boneOffsets(base, null, spine);
        final idle = boneOffsets(merged.bytes, 'Idle_02', spine);
        expect(length(idle['spine_01']!), closeTo(0.1151, 1e-3));
        expect(length(bind['spine_01']!), closeTo(0.0247, 1e-3));
        final stretch = spine.fold(0.0, (sum, b) => sum + length(idle[b]!) - length(bind[b]!));
        expect(stretch, greaterThan(0.25), reason: 'the spine chain grows ~0.29 m');
      });

      test('by default a clip whose skin differs is retargeted: spine lengths equal the base bind, pelvis translation scaled by 1.066, scales dropped', () {
        if (!mannequin.existsSync()) {
          markTestSkipped('test-assets/mannequin/exports is not present');
          return;
        }
        final base = read('SKM_Quinn_Simple.glb');
        for (final (clip, file) in [('Idle_02', 'Idle_02.glb'), ('Turn_Right_90', 'Turn_Right_90_Data.glb')]) {
          final src = read(file);
          expect(GlbAnimationMerger.hasUnitScales(src), isTrue, reason: '$file scales bones');
          final merged = GlbAnimationMerger.mergeWithReport(
              base: base, clips: [GlbClipSource(name: clip, bytes: src)], skipMissingBones: true);
          final report = merged.report.clips.single;
          expect(report.rotationOnly, isTrue, reason: clip);
          expect(report.droppedScaleChannels, 68, reason: clip);
          expect(report.droppedTranslationChannels, 66, reason: clip);
          expect(report.translationScale.keys, unorderedEquals(['root', 'pelvis']));
          expect(report.translationScale['root'], 1.0);
          expect(report.translationScale['pelvis'], closeTo(0.9869 / 0.9265, 1e-3));
          expect(report.toString(), contains('rotation-only retarget'));
          final bind = boneOffsets(base, null, spine);
          final got = boneOffsets(merged.bytes, clip, spine);
          for (final b in spine) {
            expect(length(got[b]!), closeTo(length(bind[b]!), 1e-6), reason: '$clip $b');
          }
          // The pelvis follows the clip, at the base's hip height.
          final pelvis = boneOffsets(merged.bytes, clip, ['pelvis'])['pelvis']!;
          expect(length(pelvis), closeTo(0.9869, 0.02), reason: '$clip pelvis');
          // Only rotations remain for the other bones; root / pelvis keep translation.
          final doc = GlbDocument.parse(merged.bytes);
          final nodes = listOf(doc.json, 'nodes');
          final animation = listOf(doc.json, 'animations').firstWhere((a) => a['name'] == clip);
          for (final c in (animation['channels'] as List).cast<Map<String, dynamic>>()) {
            final target = c['target'] as Map;
            final name = nodes[target['node'] as int]['name'];
            expect(target['path'], isNot('scale'), reason: '$clip $name');
            if (target['path'] == 'translation') expect(name, isIn(['root', 'pelvis']), reason: clip);
          }
        }
        // A same-skeleton clip is left alone.
        final jump = GlbAnimationMerger.mergeWithReport(base: base, clips: [GlbClipSource(name: 'MM_Jump', bytes: read('MM_Jump.glb'))]);
        expect(jump.report.clips.single.rotationOnly, isFalse);
        expect(jump.report.clips.single.droppedTranslationChannels, 0);
      });

      test('the shipped bundle keeps the base spine lengths in every clip', () {
        final bundle = File(LuminaThirdPersonContent.bundledMeshPath).readAsBytesSync();
        // The shipped character's chain (its head bone is `Head`).
        const chain = ['spine_01', 'spine_02', 'spine_03', 'neck_01', 'Head'];
        final bind = boneOffsets(bundle, null, chain);
        for (final clip in LuminaThirdPersonContent.clipNames) {
          final got = boneOffsets(bundle, clip, chain);
          for (final b in chain) {
            expect(length(got[b]!), closeTo(length(bind[b]!), 0.01), reason: '$clip $b');
          }
        }
      });
    });

    test('no clip of the shipped bundle moves the root (in-place clips)', () {
      final doc = GlbDocument.parse(File(LuminaThirdPersonContent.bundledMeshPath).readAsBytesSync());
      final nodes = listOf(doc.json, 'nodes');
      final accessors = listOf(doc.json, 'accessors');
      final views = listOf(doc.json, 'bufferViews');
      for (final animation in listOf(doc.json, 'animations')) {
        for (final c in (animation['channels'] as List).cast<Map<String, dynamic>>()) {
          final target = c['target'] as Map;
          if (nodes[target['node'] as int]['name'] != 'root' || target['path'] != 'translation') continue;
          // Every other clip's root stays put: its keys are all zero.
          final sampler = (animation['samplers'] as List)[c['sampler'] as int] as Map;
          final acc = accessors[sampler['output'] as int];
          final view = views[acc['bufferView'] as int];
          final data = ByteData.sublistView(doc.bin, (view['byteOffset'] as int? ?? 0) + (acc['byteOffset'] as int? ?? 0));
          for (var i = 0; i < (acc['count'] as int) * 3; i++) {
            expect(data.getFloat32(i * 4, Endian.little), 0.0, reason: '${animation['name']} root translation key $i');
          }
        }
      }
    });

    test('ships every clip of LuminaThirdPersonContent.clipNames (25, the eight jogs last), in order', () {
      final bundle = File(LuminaThirdPersonContent.bundledMeshPath);
      expect(bundle.existsSync(), isTrue, reason: 'build it with dart run tool/build_third_person_content.dart');
      expect(LuminaThirdPersonContent.clipNames.length, 25);
      expect(GlbAnimationMerger.animationNames(bundle.readAsBytesSync()), LuminaThirdPersonContent.clipNames);
      expect(LuminaThirdPersonContent.clipNames.sublist(17), LuminaThirdPersonClips.jogs, reason: 'the jogs are appended last');
    });
  });
}
