import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/models/lumina_asset.dart';
import 'package:lumina/data/models/sequencer_data.dart';

void main() {
  test('SequencerData serialization, deserialization, and round-trip', () {
    final data = SequencerData(
      fps: 60,
      lengthFrames: 240,
      tracks: [
        SequencerTrack(
          id: 'track-1',
          actorId: 'actor-cam',
          actorName: 'CineCamera_Main',
          kind: SequencerTrackKind.transform,
          channels: [
            SequencerChannel(
              name: 'Location.X',
              keys: [
                SequencerKey(frame: 0, value: 0.0, interpolation: KeyInterpolation.linear),
                SequencerKey(frame: 60, value: 500.0, interpolation: KeyInterpolation.cubic, inTangent: 1.0, outTangent: 1.0),
              ],
            ),
            SequencerChannel(
              name: 'Location.Y',
              keys: [
                SequencerKey(frame: 0, value: 100.0),
              ],
            ),
          ],
        ),
        SequencerTrack(
          id: 'track-2',
          actorId: 'actor-sun',
          actorName: 'DirectionalLight_Sun',
          kind: SequencerTrackKind.property,
          propertyName: 'intensity',
          channels: [
            SequencerChannel(
              name: 'intensity',
              keys: [
                SequencerKey(frame: 12, value: 50000.0, interpolation: KeyInterpolation.constant),
                SequencerKey(frame: 120, value: 0.0, interpolation: KeyInterpolation.linear),
              ],
            ),
          ],
        ),
        SequencerTrack(
          id: 'track-3',
          actorId: 'actor-prop',
          actorName: 'Barrel_01',
          kind: SequencerTrackKind.visibility,
          channels: [
            SequencerChannel(
              name: 'visible',
              keys: [
                SequencerKey(frame: 0, value: 1.0),
                SequencerKey(frame: 50, value: 0.0),
              ],
            ),
          ],
        ),
      ],
    );

    final bytes = data.toBytes();
    expect(bytes, isNotEmpty);

    final restored = SequencerData.fromBytes(bytes);
    expect(restored.version, equals(1));
    expect(restored.fps, equals(60));
    expect(restored.lengthFrames, equals(240));
    expect(restored.tracks.length, equals(3));

    // Track 1
    expect(restored.tracks[0].id, equals('track-1'));
    expect(restored.tracks[0].actorId, equals('actor-cam'));
    expect(restored.tracks[0].kind, equals(SequencerTrackKind.transform));
    expect(restored.tracks[0].channels.length, equals(2));
    expect(restored.tracks[0].channels[0].name, equals('Location.X'));
    expect(restored.tracks[0].channels[0].keys.length, equals(2));
    expect(restored.tracks[0].channels[0].keys[1].frame, equals(60));
    expect(restored.tracks[0].channels[0].keys[1].value, equals(500.0));
    expect(restored.tracks[0].channels[0].keys[1].interpolation, equals(KeyInterpolation.cubic));

    // Track 2
    expect(restored.tracks[1].propertyName, equals('intensity'));
    expect(restored.tracks[1].channels[0].keys[0].interpolation, equals(KeyInterpolation.constant));

    // Track 3
    expect(restored.tracks[2].kind, equals(SequencerTrackKind.visibility));
  });

  test('SequencerData wraps inside LuminaAsset .lmas and persists to disk', () {
    final tempDir = Directory.systemTemp.createTempSync('seq_test_');
    final filePath = '${tempDir.path}/Seq_OpeningCinematic.lmas';

    try {
      final seqData = SequencerData(
        fps: 30,
        lengthFrames: 120,
        tracks: [
          SequencerTrack(
            id: 'tr-1',
            actorId: 'light-1',
            actorName: 'LightActor',
            kind: SequencerTrackKind.property,
            propertyName: 'intensity',
          ),
        ],
      );

      final asset = LuminaAsset(
        assetId: 'seq-asset-id',
        name: 'Seq_OpeningCinematic',
        type: AssetType.sequencer,
        rawPayload: seqData.toBytes(),
        metadata: {'author': 'cinematic_team'},
      );

      File(filePath).writeAsBytesSync(asset.toProtoBufferBytes());

      // Re-read
      final readBytes = File(filePath).readAsBytesSync();
      final loadedAsset = LuminaAsset.fromBytes(readBytes);

      expect(loadedAsset.type, equals(AssetType.sequencer));
      expect(loadedAsset.name, equals('Seq_OpeningCinematic'));
      expect(loadedAsset.rawPayload, isNotNull);

      final loadedSeq = SequencerData.fromBytes(loadedAsset.rawPayload!);
      expect(loadedSeq.fps, equals(30));
      expect(loadedSeq.tracks.length, equals(1));
      expect(loadedSeq.tracks[0].actorName, equals('LightActor'));
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });
}
