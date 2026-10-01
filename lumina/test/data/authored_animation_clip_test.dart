import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

Directory get _assets => Directory(Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets');

File get _manny => File('${_assets.path}/mannequin/SKM_Manny_Simple.glb');

List<double> _axisAngle(Vector3 axis, double degrees) {
  final q = Quaternion.axisAngle(axis.normalized(), degrees * math.pi / 180.0);
  return [q.x, q.y, q.z, q.w];
}

double _angleDegrees(List<double> q) => 2 * math.acos(q[3].abs().clamp(0.0, 1.0)) * 180.0 / math.pi;

/// Authored clips: keys in frames, a sampler that evaluates them as gltfio
/// does, and the glTF animation they are stored as in the skeletal mesh's GLB.
void main() {
  group('AuthoredAnimationClip model', () {
    test('keys are set, replaced, removed and moved; a move onto a key replaces it', () {
      final clip = AuthoredAnimationClip(name: 'Wave', lengthFrames: 60);
      clip.setKey('upperarm_r', AuthoredChannel.rotation, 0, const [0, 0, 0, 1]);
      clip.setKey('upperarm_r', AuthoredChannel.rotation, 30, _axisAngle(Vector3(1, 0, 0), 90));
      clip.setKey('upperarm_r', AuthoredChannel.rotation, 30, _axisAngle(Vector3(1, 0, 0), 45));
      expect(clip.keyFrames('upperarm_r'), [0, 30]);
      expect(_angleDegrees(clip.channel('upperarm_r', AuthoredChannel.rotation)!.keys[30]!), closeTo(45, 1e-9));

      clip.setKey('upperarm_r', AuthoredChannel.rotation, 20, _axisAngle(Vector3(1, 0, 0), 10));
      expect(clip.moveKey('upperarm_r', 30, 20), isTrue);
      expect(clip.keyFrames('upperarm_r'), [0, 20]);
      expect(_angleDegrees(clip.channel('upperarm_r', AuthoredChannel.rotation)!.keys[20]!), closeTo(45, 1e-9));

      expect(clip.removeKey('upperarm_r', 20), isTrue);
      expect(clip.keyFrames('upperarm_r'), [0]);
      expect(clip.removeKey('upperarm_r', 0), isTrue);
      expect(clip.tracks, isEmpty, reason: 'an empty track is dropped');
      expect(() => clip.setKey('head', AuthoredChannel.rotation, 61, const [0, 0, 0, 1]), throwsRangeError);
    });

    test('JSON round-trips key for key, value for value, interpolation for interpolation', () {
      final clip = AuthoredAnimationClip(name: 'Turn', frameRate: 24, lengthFrames: 48);
      clip.setKey('head', AuthoredChannel.rotation, 12, _axisAngle(Vector3(0, 1, 0), 30));
      clip.setKey('root', AuthoredChannel.translation, 0, const [0.0, 0.0, 0.0]);
      clip.setKey('root', AuthoredChannel.translation, 48, const [0.25, 0.0, -1.5]);
      clip.setKey('pelvis', AuthoredChannel.scale, 5, const [1.0, 1.2, 1.0]);
      clip.channel('head', AuthoredChannel.rotation)!.interpolation = AuthoredInterpolation.cubic;
      clip.channel('pelvis', AuthoredChannel.scale)!.interpolation = AuthoredInterpolation.step;

      final back = AuthoredAnimationClip.decode(clip.encode());
      expect(back, clip);
      expect(back.frameRate, 24);
      expect(back.lengthFrames, 48);
      expect(back.channel('head', AuthoredChannel.rotation)!.interpolation, AuthoredInterpolation.cubic);
      expect(back.channel('root', AuthoredChannel.translation)!.keys[48], const [0.25, 0.0, -1.5]);
    });
  });

  group('sampler (gltfio semantics)', () {
    AuthoredAnimationClip armClip(AuthoredInterpolation interpolation) {
      final clip = AuthoredAnimationClip(name: 'Arm', lengthFrames: 40);
      clip.setKey('upperarm_r', AuthoredChannel.rotation, 0, const [0, 0, 0, 1], interpolation: interpolation);
      clip.setKey('upperarm_r', AuthoredChannel.rotation, 30, _axisAngle(Vector3(1, 0, 0), 90));
      clip.setKey('root', AuthoredChannel.translation, 0, const [0, 0, 0], interpolation: interpolation);
      clip.setKey('root', AuthoredChannel.translation, 30, const [3, 0, 0]);
      return clip;
    }

    double angleAt(AuthoredAnimationClip clip, double frame) =>
        _angleDegrees(clip.sample('upperarm_r', AuthoredChannel.rotation, frame / clip.frameRate)!);

    test('linear: slerp half way, translation lerps, ends hold', () {
      final clip = armClip(AuthoredInterpolation.linear);
      expect(angleAt(clip, 15), closeTo(45, 1e-6));
      expect(angleAt(clip, 7.5), closeTo(22.5, 1e-6));
      expect(clip.sample('root', AuthoredChannel.translation, 10 / 30)![0], closeTo(1.0, 1e-9));
      expect(angleAt(clip, 35), closeTo(90, 1e-6), reason: 'after the last key the last value holds');
      expect(clip.sample('head', AuthoredChannel.rotation, 0.5), isNull);
    });

    test('step holds the earlier key until the next', () {
      final clip = armClip(AuthoredInterpolation.step);
      expect(angleAt(clip, 15), closeTo(0, 1e-6));
      expect(angleAt(clip, 29.9), closeTo(0, 1e-6));
      expect(angleAt(clip, 30), closeTo(90, 1e-6));
    });

    test('cubic (flat tangents) eases: half way is half, a quarter is less than linear', () {
      final clip = armClip(AuthoredInterpolation.cubic);
      expect(angleAt(clip, 15), closeTo(45, 1e-6));
      expect(angleAt(clip, 7.5), lessThan(22.5 - 1.0));
      expect(clip.sample('root', AuthoredChannel.translation, 7.5 / 30)![0], closeTo(3 * 0.15625, 1e-9));
    });
  });

  group('GlbAuthoredClipWriter on SKM_Manny_Simple', () {
    late Uint8List manny;
    setUpAll(() {
      if (!_manny.existsSync()) return;
      manny = _manny.readAsBytesSync();
    });

    AuthoredAnimationClip waveClip() {
      final clip = AuthoredAnimationClip(name: 'Authored_Wave', lengthFrames: 30);
      clip.setKey('upperarm_r', AuthoredChannel.rotation, 0, GlbSkeleton.fromGlb(manny).rest(GlbSkeleton.fromGlb(manny).indexOf('upperarm_r')).channel('rotation'));
      final rest = GlbSkeleton.fromGlb(manny).rest(GlbSkeleton.fromGlb(manny).indexOf('upperarm_r')).r;
      final raised = Quaternion.axisAngle(Vector3(0, 0, 1), 70 * math.pi / 180) * rest;
      clip.setKey('upperarm_r', AuthoredChannel.rotation, 30, [raised.x, raised.y, raised.z, raised.w]);
      clip.setKey('head', AuthoredChannel.rotation, 15, _axisAngle(Vector3(1, 0, 0), 30));
      return clip;
    }

    test('writes one animation under the clip name with a channel per joint and the clip length', () async {
      if (!_manny.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
      final clip = waveClip();
      final out = GlbAuthoredClipWriter.write(meshGlb: manny, clip: clip);
      expect(GlbAnimationMerger.animationNames(out.glb), ['Authored_Wave']);
      expect(out.clipIndex, 0);

      final doc = GlbDocument.parse(out.glb);
      final skeleton = GlbSkeleton.fromJson(doc.json);
      final anim = (doc.json['animations'] as List).first as Map;
      final channels = (anim['channels'] as List).cast<Map>();
      for (final j in skeleton.joints) {
        final paths = {for (final c in channels) if ((c['target'] as Map)['node'] == j) (c['target'] as Map)['path']};
        expect(paths, containsAll(['rotation', 'translation']), reason: '${skeleton.names[j]} must be defined by the clip');
      }
      // The head's single key is held to the end: gltfio skips one-key samplers.
      final head = skeleton.indexOf('head');
      final headRot = channels.firstWhere((c) => (c['target'] as Map)['node'] == head && (c['target'] as Map)['path'] == 'rotation');
      final sampler = (anim['samplers'] as List)[headRot['sampler'] as int] as Map;
      final input = (doc.json['accessors'] as List)[sampler['input'] as int] as Map;
      expect(input['count'], 2);
      expect((input['max'] as List).first, closeTo(1.0, 1e-6));

      final parsed = (await GlbParserService.parseGlb(out.glb))!;
      expect(parsed.animations.single.duration, closeTo(1.0, 1e-6));
    });

    test('the parsed GLB channels sample to the authored values at keys and in between', () async {
      if (!_manny.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
      final clip = waveClip();
      final out = GlbAuthoredClipWriter.write(meshGlb: manny, clip: clip);
      final parsed = (await GlbParserService.parseGlb(out.glb))!.animations.single;
      final arm = parsed.channels.firstWhere((c) => c.nodeName == 'upperarm_r' && c.path == 'rotation');
      final fromGlb = AuthoredChannel('rotation', keys: {
        for (var i = 0; i < arm.keyframeTimes.length; i++)
          (arm.keyframeTimes[i] * 30).round(): arm.values.sublist(i * 4, i * 4 + 4),
      });
      for (final frame in [0.0, 7.0, 15.0, 22.0, 30.0]) {
        final a = clip.sample('upperarm_r', 'rotation', frame / 30)!;
        final b = fromGlb.sample(frame);
        final dot = (a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3]).abs();
        expect(dot, closeTo(1.0, 1e-6), reason: 'frame $frame');
      }
    });

    test('re-writing the same name keeps the index and does not grow the file; the mesh data is untouched', () async {
      if (!_manny.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
      final clip = waveClip();
      final first = GlbAuthoredClipWriter.write(meshGlb: manny, clip: clip);
      final other = AuthoredAnimationClip(name: 'Other', lengthFrames: 10)
        ..setKey('head', AuthoredChannel.rotation, 0, const [0, 0, 0, 1]);
      final two = GlbAuthoredClipWriter.write(meshGlb: first.glb, clip: other);
      expect(GlbAnimationMerger.animationNames(two.glb), ['Authored_Wave', 'Other']);

      final again = GlbAuthoredClipWriter.write(meshGlb: two.glb, clip: clip);
      expect(again.clipIndex, 0);
      expect(GlbAnimationMerger.animationNames(again.glb), ['Authored_Wave', 'Other']);
      expect(GlbDocument.parse(again.glb).bin.length, GlbDocument.parse(two.glb).bin.length,
          reason: 'the replaced clip\'s old binary data is dropped');
      expect((again.glb.length - two.glb.length).abs(), lessThan(256), reason: 'only accessor indices in the JSON differ');

      final before = (await GlbParserService.parseGlb(manny))!;
      final after = (await GlbParserService.parseGlb(again.glb))!;
      expect(after.vertexCount, before.vertexCount);
      expect(after.positions, before.positions);
      expect(GlbAnimationRetargeter.jointNames(again.glb), GlbAnimationRetargeter.jointNames(manny));
      expect(after.animations.map((a) => a.name), ['Authored_Wave', 'Other']);
      final otherHead = after.animations[1].channels.firstWhere((c) => c.nodeName == 'head' && c.path == 'rotation');
      expect(otherHead.values.sublist(0, 4), [0, 0, 0, 1], reason: 'the other clip still reads its own keys');
    });

    test('an unknown bone is refused, naming it', () {
      if (!_manny.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
      final clip = AuthoredAnimationClip(name: 'Bad', lengthFrames: 10)
        ..setKey('tail_01', AuthoredChannel.rotation, 0, const [0, 0, 0, 1]);
      expect(() => GlbAuthoredClipWriter.write(meshGlb: manny, clip: clip),
          throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('tail_01'))));
    });
  });

  group('AuthoredAnimationStore', () {
    late Directory project;
    const meshRel = 'contents/meshes/skeletal/SKM_Manny_Simple.lmas';

    setUp(() {
      project = Directory.systemTemp.createTempSync('lumina_authored_clip_');
      Directory('${project.path}/contents/meshes/skeletal').createSync(recursive: true);
      if (!_manny.existsSync()) return;
      var glb = _manny.readAsBytesSync();
      // A mesh that already has a clip named Idle.
      glb = GlbAuthoredClipWriter.write(
        meshGlb: glb,
        clip: AuthoredAnimationClip(name: 'Idle', lengthFrames: 10)..setKey('head', 'rotation', 0, const [0, 0, 0, 1]),
      ).glb;
      File('${project.path}/$meshRel').writeAsBytesSync(LuminaAsset(
        assetId: 'mesh-id',
        name: 'SKM_Manny_Simple',
        type: AssetType.filameshSk,
        rawPayload: glb,
        metadata: const {'payload_format': 'glb', 'animation_clips': 'Idle'},
      ).toProtoBufferBytes());
    });

    tearDown(() {
      try {
        project.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('create writes the clip into the mesh GLB and an animation asset pointing at it', () {
      if (!_manny.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
      final rel = AuthoredAnimationStore.create(
          projectDir: project.path, meshRelPath: meshRel, name: 'Wave Hello', lengthFrames: 45, frameRate: 30);
      expect(rel, 'contents/animations/SKM_Manny_Simple/Wave_Hello.lmas');

      final asset = LuminaAsset.fromBytes(File('${project.path}/$rel').readAsBytesSync());
      expect(asset.type, AssetType.animation);
      expect(asset.rawPayload == null || asset.rawPayload!.isEmpty, isTrue);
      expect(asset.metadata['source_mesh'], meshRel);
      expect(asset.metadata['clip_name'], 'Wave_Hello');
      expect(asset.metadata['clip_index'], '1');
      expect(asset.metadata['duration_seconds'], '1.500');
      expect(asset.references.single.slotName, 'skeletal_mesh');
      expect(asset.references.single.assetPath, meshRel);
      final clip = AuthoredAnimationStore.clipOf(asset)!;
      expect(clip.lengthFrames, 45);
      expect(clip.frameRate, 30);
      expect(clip.bones, ['root'], reason: 'the skeleton root\'s rest pose is keyed at frame 0');
      expect(clip.keyFrames('root'), [0]);

      final mesh = LuminaAsset.fromBytes(File('${project.path}/$meshRel').readAsBytesSync());
      expect(mesh.metadata['animation_clips'], 'Idle,Wave_Hello');
      final companion = File('${project.path}/contents/meshes/skeletal/SKM_Manny_Simple.entity.glb');
      expect(GlbAnimationMerger.animationNames(companion.readAsBytesSync()), ['Idle', 'Wave_Hello']);
      expect(GlbAnimationMerger.animationNames(mesh.rawPayload!), ['Idle', 'Wave_Hello']);
    });

    test('a name already used by a clip of the mesh gets a unique one', () {
      if (!_manny.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
      final rel = AuthoredAnimationStore.create(projectDir: project.path, meshRelPath: meshRel, name: 'Idle', lengthFrames: 30);
      expect(rel, 'contents/animations/SKM_Manny_Simple/Idle_2.lmas');
      final again = AuthoredAnimationStore.create(projectDir: project.path, meshRelPath: meshRel, name: 'Idle', lengthFrames: 30);
      expect(again, 'contents/animations/SKM_Manny_Simple/Idle_3.lmas');
    });

    test('save then load round-trips the keys exactly and keeps the clip index', () async {
      if (!_manny.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
      final rel = AuthoredAnimationStore.create(projectDir: project.path, meshRelPath: meshRel, name: 'Pose', lengthFrames: 30);
      final clip = AuthoredAnimationStore.load(project.path, rel)!;
      clip.setKey('head', AuthoredChannel.rotation, 15, _axisAngle(Vector3(0, 1, 0), 40));
      clip.setKey('upperarm_r', AuthoredChannel.rotation, 30, _axisAngle(Vector3(0, 0, 1), 60));
      clip.channel('head', AuthoredChannel.rotation)!.interpolation = AuthoredInterpolation.cubic;
      final saved = AuthoredAnimationStore.save(
        projectDir: project.path,
        animationRelPath: rel,
        clip: clip,
        metadata: {...LuminaAsset.fromBytes(File('${project.path}/$rel').readAsBytesSync()).metadata, 'notifies': '[]'},
      );
      expect(saved.metadata['notifies'], '[]');
      expect(saved.metadata['clip_index'], '1');
      expect(AuthoredAnimationStore.load(project.path, rel), clip);

      final companion = File('${project.path}/contents/meshes/skeletal/SKM_Manny_Simple.entity.glb').readAsBytesSync();
      final parsed = (await GlbParserService.parseGlb(companion))!.animations[1];
      expect(parsed.name, 'Pose');
      final head = parsed.channels.firstWhere((c) => c.nodeName == 'head' && c.path == 'rotation');
      expect(head.interpolation, 'CUBICSPLINE');
    });
  });
}
