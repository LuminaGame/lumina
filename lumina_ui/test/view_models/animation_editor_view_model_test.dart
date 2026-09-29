import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/animation_playback_controller.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/animation_editor_view_model.dart';

Uint8List buildTestGlbWithTwoClips() {
  final BytesBuilder bin = BytesBuilder();

  // Positions [0,0,0, 1,0,0, 0,1,0]
  final posData = Float32List.fromList([
    0.0, 0.0, 0.0,
    1.0, 0.0, 0.0,
    0.0, 1.0, 0.0,
  ]);
  bin.add(posData.buffer.asUint8List()); // 36 bytes

  // Indices [0, 1, 2]
  final indData = Uint16List.fromList([0, 1, 2]);
  bin.add(indData.buffer.asUint8List()); // 6 bytes
  bin.add(Uint8List(2)); // pad to 44

  // Clip 1 "Idle" Time [0.0, 1.0, 2.0]
  final idleTimes = Float32List.fromList([0.0, 1.0, 2.0]);
  bin.add(idleTimes.buffer.asUint8List()); // 12 bytes (44..56)

  // Clip 1 Quat
  final idleQuats = Float32List.fromList([
    0.0, 0.0, 0.0, 1.0,
    0.0, 0.707, 0.0, 0.707,
    0.0, 0.0, 0.0, 1.0,
  ]);
  bin.add(idleQuats.buffer.asUint8List()); // 48 bytes (56..104)

  // Clip 2 "Walk" Time [0.0, 0.75, 1.5]
  final walkTimes = Float32List.fromList([0.0, 0.75, 1.5]);
  bin.add(walkTimes.buffer.asUint8List()); // 12 bytes (104..116)

  // Clip 2 Trans
  final walkTrans = Float32List.fromList([
    0.0, 0.0, 0.0,
    0.0, 0.0, 1.0,
    0.0, 0.0, 2.0,
  ]);
  bin.add(walkTrans.buffer.asUint8List()); // 36 bytes (116..152)

  final binBytes = bin.toBytes();

  final jsonMap = {
    'asset': {'version': '2.0'},
    'nodes': [
      {'name': 'Armature', 'children': [1]},
      {'name': 'pelvis', 'children': [2]},
      {'name': 'spine_01'},
      {'name': 'MeshNode', 'mesh': 0},
    ],
    'scenes': [
      {
        'nodes': [0, 3]
      }
    ],
    'scene': 0,
    'meshes': [
      {
        'name': 'SimpleMesh',
        'primitives': [
          {
            'attributes': {'POSITION': 0},
            'indices': 1,
          }
        ]
      }
    ],
    'accessors': [
      {
        'bufferView': 0,
        'byteOffset': 0,
        'componentType': 5126,
        'count': 3,
        'type': 'VEC3',
        'min': [0.0, 0.0, 0.0],
        'max': [1.0, 1.0, 0.0],
      },
      {
        'bufferView': 1,
        'byteOffset': 0,
        'componentType': 5123,
        'count': 3,
        'type': 'SCALAR',
      },
      {
        'bufferView': 2,
        'byteOffset': 0,
        'componentType': 5126,
        'count': 3,
        'type': 'SCALAR',
        'min': [0.0],
        'max': [2.0],
      },
      {
        'bufferView': 3,
        'byteOffset': 0,
        'componentType': 5126,
        'count': 3,
        'type': 'VEC4',
      },
      {
        'bufferView': 4,
        'byteOffset': 0,
        'componentType': 5126,
        'count': 3,
        'type': 'SCALAR',
        'min': [0.0],
        'max': [1.5],
      },
      {
        'bufferView': 5,
        'byteOffset': 0,
        'componentType': 5126,
        'count': 3,
        'type': 'VEC3',
      },
    ],
    'bufferViews': [
      {'buffer': 0, 'byteOffset': 0, 'byteLength': 36},
      {'buffer': 0, 'byteOffset': 36, 'byteLength': 6},
      {'buffer': 0, 'byteOffset': 44, 'byteLength': 12},
      {'buffer': 0, 'byteOffset': 56, 'byteLength': 48},
      {'buffer': 0, 'byteOffset': 104, 'byteLength': 12},
      {'buffer': 0, 'byteOffset': 116, 'byteLength': 36},
    ],
    'buffers': [
      {'byteLength': binBytes.length}
    ],
    'animations': [
      {
        'name': 'Idle',
        'samplers': [
          {'input': 2, 'output': 3, 'interpolation': 'LINEAR'}
        ],
        'channels': [
          {
            'sampler': 0,
            'target': {'node': 1, 'path': 'rotation'}
          }
        ]
      },
      {
        'name': 'Walk',
        'samplers': [
          {'input': 4, 'output': 5, 'interpolation': 'LINEAR'}
        ],
        'channels': [
          {
            'sampler': 0,
            'target': {'node': 1, 'path': 'translation'}
          },
          {
            'sampler': 0,
            'target': {'node': 2, 'path': 'rotation'}
          }
        ]
      }
    ],
  };

  final jsonStr = jsonEncode(jsonMap);
  final jsonBytes = utf8.encode(jsonStr);
  final jsonPad = (4 - (jsonBytes.length % 4)) % 4;
  final finalJsonBytes = Uint8List(jsonBytes.length + jsonPad)
    ..setAll(0, jsonBytes)
    ..fillRange(jsonBytes.length, jsonBytes.length + jsonPad, 0x20);

  final totalLength = 12 + 8 + finalJsonBytes.length + 8 + binBytes.length;
  final glb = BytesBuilder();
  final h = ByteData(12)
    ..setUint32(0, 0x46546C67, Endian.little)
    ..setUint32(4, 2, Endian.little)
    ..setUint32(8, totalLength, Endian.little);
  glb.add(h.buffer.asUint8List());

  final jh = ByteData(8)
    ..setUint32(0, finalJsonBytes.length, Endian.little)
    ..setUint32(4, 0x4E4F534A, Endian.little);
  glb.add(jh.buffer.asUint8List());
  glb.add(finalJsonBytes);

  final bh = ByteData(8)
    ..setUint32(0, binBytes.length, Endian.little)
    ..setUint32(4, 0x004E4942, Endian.little);
  glb.add(bh.buffer.asUint8List());
  glb.add(binBytes);

  return glb.toBytes();
}

void main() {
  late Directory tempDir;
  late String lmasPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('anim_vm_test_');
    lmasPath = '${tempDir.path}/A_Hero_Anim.lmas';

    final glbBytes = buildTestGlbWithTwoClips();
    final asset = LuminaAsset(
      assetId: 'hero-anim-uuid',
      name: 'A_Hero_Anim',
      type: AssetType.animation,
      rawPayload: glbBytes,
      metadata: {},
    );

    final lmasBytes = asset.toProtoBufferBytes();
    File(lmasPath).writeAsBytesSync(lmasBytes);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('AnimationEditorViewModel loads 2 clips with real durations from .lmas', () async {
    final vm = AnimationEditorViewModel(assetPath: lmasPath);
    await vm.load();

    expect(vm.clips.length, equals(2));
    expect(vm.clips[0].name, equals('Idle'));
    expect(vm.clips[0].duration, closeTo(2.0, 1e-4));
    expect(vm.clips[1].name, equals('Walk'));
    expect(vm.clips[1].duration, closeTo(1.5, 1e-4));

    expect(vm.selectedClip, equals(0));
    expect(vm.duration, closeTo(2.0, 1e-4));
    expect(vm.totalFrames, equals(60)); // 2.0s * 30 FPS = 60
    expect(vm.currentFrame, equals(0));
    expect(vm.isPlaying, isFalse);
    expect(vm.isLooping, isTrue);

    // Bone tracks
    expect(vm.activeAnimatedNodeIndices, contains(1));
    expect(vm.allBones.length, equals(3));
  });

  test('AnimationEditorViewModel playback ticker advances time and handles speed / rateScale', () async {
    final vm = AnimationEditorViewModel(assetPath: lmasPath);
    await vm.load();

    vm.play();
    expect(vm.isPlaying, isTrue);

    // Advance 0.5s at speed 1.0, rateScale 1.0
    vm.tickDelta(0.5);
    expect(vm.positionSeconds, closeTo(0.5, 1e-5));
    expect(vm.currentFrame, equals(15)); // 0.5 * 30 = 15

    // Set speed 2.0 and advance 0.25s -> delta = 0.25 * 2.0 = 0.5s -> total 1.0s
    vm.setSpeed(2.0);
    vm.tickDelta(0.25);
    expect(vm.positionSeconds, closeTo(1.0, 1e-5));
    expect(vm.currentFrame, equals(30));

    // Set rateScale 0.5 and advance 0.5s at speed 2.0 -> delta = 0.5 * 2.0 * 0.5 = 0.5s -> total 1.5s
    vm.setRateScale(0.5);
    vm.tickDelta(0.5);
    expect(vm.positionSeconds, closeTo(1.5, 1e-5));
  });

  test('AnimationEditorViewModel looping wraps at duration, non-looping pauses at duration', () async {
    final vm = AnimationEditorViewModel(assetPath: lmasPath);
    await vm.load();

    vm.play();
    // Looping is ON by default. duration is 2.0s
    vm.tickDelta(2.3);
    // 2.3 mod 2.0 = 0.3
    expect(vm.positionSeconds, closeTo(0.3, 1e-5));
    expect(vm.isPlaying, isTrue);

    // Disable looping
    vm.setLooping(false);
    vm.seek(1.8);
    vm.play();
    vm.tickDelta(0.5);
    // Should clamp to duration (2.0) and flip isPlaying to false
    expect(vm.positionSeconds, closeTo(2.0, 1e-5));
    expect(vm.isPlaying, isFalse);
  });

  test('AnimationEditorViewModel stepFrame and Step interpolation snapping', () async {
    final vm = AnimationEditorViewModel(assetPath: lmasPath);
    await vm.load();

    // Paused at 0.0
    vm.stepFrame(1);
    expect(vm.positionSeconds, closeTo(1.0 / 30.0, 1e-5));
    expect(vm.currentFrame, equals(1));

    vm.stepFrame(9);
    expect(vm.currentFrame, equals(10));
    expect(vm.positionSeconds, closeTo(10.0 / 30.0, 1e-5));

    // Step -1
    vm.stepFrame(-1);
    expect(vm.currentFrame, equals(9));
    expect(vm.positionSeconds, closeTo(9.0 / 30.0, 1e-5));

    // Step -20 clamps to 0
    vm.stepFrame(-20);
    expect(vm.currentFrame, equals(0));
    expect(vm.positionSeconds, closeTo(0.0, 1e-5));

    // Step interpolation mode snaps seek to nearest whole frame
    vm.setInterpolation('Step');
    vm.seek(0.34); // ~10.2 frames -> snaps to 10/30 = 0.333333
    expect(vm.currentFrame, equals(10));
    expect(vm.positionSeconds, closeTo(10.0 / 30.0, 1e-5));
  });

  test('AnimationEditorViewModel clip selection resets position and recomputes totalFrames', () async {
    final vm = AnimationEditorViewModel(assetPath: lmasPath);
    await vm.load();

    vm.seek(1.2);
    expect(vm.selectedClip, equals(0));
    expect(vm.duration, closeTo(2.0, 1e-4));
    expect(vm.totalFrames, equals(60));

    // Switch to Walk (duration 1.5s -> 45 frames)
    vm.selectClip(1);
    expect(vm.selectedClip, equals(1));
    expect(vm.positionSeconds, equals(0.0));
    expect(vm.duration, closeTo(1.5, 1e-4));
    expect(vm.totalFrames, equals(45));
    expect(vm.activeAnimatedNodeIndices, containsAll([1, 2]));
  });

  test('AnimationEditorViewModel metadata round-trip persistence', () async {
    final vm = AnimationEditorViewModel(assetPath: lmasPath);
    await vm.load();

    vm.setRateScale(1.5);
    vm.setInterpolation('Step');
    vm.setAdditiveType('Local Space');
    vm.setFrameRate(60.0);
    vm.selectClip(1);

    expect(vm.isDirty, isTrue);
    await vm.save();
    expect(vm.isDirty, isFalse);

    // Reopen and verify
    final vm2 = AnimationEditorViewModel(assetPath: lmasPath);
    await vm2.load();

    expect(vm2.rateScale, equals(1.5));
    expect(vm2.interpolation, equals('Step'));
    expect(vm2.additiveType, equals('Local Space'));
    expect(vm2.frameRate, equals(60.0));
    expect(vm2.selectedClip, equals(1));
    expect(vm2.totalFrames, equals(90)); // 1.5s * 60 FPS = 90
  });

  test('AnimationPlaybackController updates on seek/tick and records calls', () async {
    final vm = AnimationEditorViewModel(assetPath: lmasPath);
    await vm.load();

    expect(vm.playbackController.clipIndex, equals(0));
    expect(vm.playbackController.timeSeconds, equals(0.0));

    vm.seek(0.75);
    expect(vm.playbackController.timeSeconds, closeTo(0.75, 1e-5));

    vm.selectClip(1);
    expect(vm.playbackController.clipIndex, equals(1));
    expect(vm.playbackController.timeSeconds, equals(0.0));
  });
}
