import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/sequencer_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late String lmasPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('seq_vm_test_');
    lmasPath = '${tempDir.path}/Seq_Cinematic.lmas';

    final seqData = SequencerData(
      fps: 30,
      lengthFrames: 120,
      tracks: [
        SequencerTrack(
          id: 'track-1',
          actorId: 'actor-light-uuid',
          actorName: 'DirectionalLight_Sun',
          kind: SequencerTrackKind.property,
          propertyName: 'intensity',
          channels: [
            SequencerChannel(
              name: 'intensity',
              keys: [
                SequencerKey(frame: 12, value: 50000.0, interpolation: KeyInterpolation.linear),
              ],
            ),
          ],
        ),
      ],
    );

    final asset = LuminaAsset(
      assetId: 'seq-cinematic-id',
      name: 'Seq_Cinematic',
      type: AssetType.sequencer,
      rawPayload: seqData.toBytes(),
    );

    File(lmasPath).writeAsBytesSync(asset.toProtoBufferBytes());
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('SequencerViewModel loads tracks and parses existing keyframes', () async {
    final vm = SequencerViewModel(assetPath: lmasPath);
    await vm.load();

    expect(vm.fps, equals(30));
    expect(vm.lengthFrames, equals(120));
    expect(vm.tracks.length, equals(1));

    final track = vm.tracks.first;
    expect(track.actorName, equals('DirectionalLight_Sun'));
    expect(track.kind, equals(SequencerTrackKind.property));
    expect(track.channels.first.keys.length, equals(1));
    expect(track.channels.first.keys.first.frame, equals(12));
    expect(track.channels.first.keys.first.value, equals(50000.0));
  });

  test('addTrack creates proper channels for transform, property, and visibility kinds', () async {
    final vm = SequencerViewModel(assetPath: lmasPath);
    await vm.load();

    // 1. Transform track
    vm.addTrack('actor-cube', 'CubeActor', SequencerTrackKind.transform);
    expect(vm.tracks.length, equals(2));
    final t1 = vm.tracks.last;
    expect(t1.channels.length, equals(9));
    expect(t1.channels.map((c) => c.name).toList(), containsAll([
      'Location.X', 'Location.Y', 'Location.Z',
      'Rotation.X', 'Rotation.Y', 'Rotation.Z',
      'Scale.X', 'Scale.Y', 'Scale.Z',
    ]));

    // 2. Visibility track
    vm.addTrack('actor-sphere', 'SphereActor', SequencerTrackKind.visibility);
    expect(vm.tracks.length, equals(3));
    final t2 = vm.tracks.last;
    expect(t2.channels.length, equals(1));
    expect(t2.channels.first.name, equals('visibility'));

    expect(vm.isDirty, isTrue);
  });

  test('addKey, moveKey, and deleteKey mutations update frame positions and snap properly', () async {
    final vm = SequencerViewModel(assetPath: lmasPath);
    await vm.load();

    final track = vm.tracks.first;
    // Add key at frame 60
    vm.addKey(track.id, 'intensity', 60, 10000.0);
    expect(track.channels.first.keys.length, equals(2));
    expect(track.channels.first.keys[1].frame, equals(60));

    // Move key from frame 12 to frame 30
    vm.moveKey(track.id, 'intensity', 0, 30);
    expect(track.channels.first.keys[0].frame, equals(30));

    // Delete key
    vm.deleteKey(track.id, 'intensity', 1);
    expect(track.channels.first.keys.length, equals(1));
    expect(track.channels.first.keys[0].frame, equals(30));
  });

  test('FPS change retains keyframe frames but updates timecode string accurately', () async {
    final vm = SequencerViewModel(assetPath: lmasPath);
    await vm.load();

    vm.scrubToFrame(60);
    // At 30 FPS: frame 60 is 2 seconds -> 00:00:02:00
    expect(vm.timecodeStr, equals('00:00:02:00'));

    vm.setFps(60);
    // At 60 FPS: frame 60 is 1 second -> 00:00:01:00
    expect(vm.timecodeStr, equals('00:00:01:00'));

    // Keyframes intact
    expect(vm.tracks.first.channels.first.keys.first.frame, equals(12));
  });

  test('Missing actor binding detection and rebinding', () async {
    final vm = SequencerViewModel(assetPath: lmasPath);
    await vm.load();

    // Available level actors list
    final levelActorIds = {'actor-cube-123', 'actor-camera-456'};

    // DirectionalLight_Sun (actor-light-uuid) is not in levelActorIds
    expect(vm.isActorMissing(vm.tracks.first.actorId, levelActorIds), isTrue);

    // Rebind to actor-camera-456
    vm.rebindActor(vm.tracks.first.id, 'actor-camera-456', 'MainCamera');
    expect(vm.tracks.first.actorId, equals('actor-camera-456'));
    expect(vm.tracks.first.actorName, equals('MainCamera'));
    expect(vm.isActorMissing(vm.tracks.first.actorId, levelActorIds), isFalse);
  });

  test('Save writes updated SequencerData to .lmas and clears isDirty', () async {
    final vm = SequencerViewModel(assetPath: lmasPath);
    await vm.load();

    vm.addTrack('actor-hero', 'HeroPawn', SequencerTrackKind.transform);
    expect(vm.isDirty, isTrue);

    final saved = await vm.save();
    expect(saved, isTrue);
    expect(vm.isDirty, isFalse);

    // Re-read file directly
    final readBytes = File(lmasPath).readAsBytesSync();
    final asset = LuminaAsset.fromBytes(readBytes);
    final restoredData = SequencerData.fromBytes(asset.rawPayload!);

    expect(restoredData.tracks.length, equals(2));
    expect(restoredData.tracks[1].actorName, equals('HeroPawn'));
  });
}
