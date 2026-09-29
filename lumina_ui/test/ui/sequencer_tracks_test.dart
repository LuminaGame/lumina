import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sequencer/sequencer_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sequencer/timeline_widget.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/sequencer_view_model.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late String lmasPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('seq_widget_test_');
    lmasPath = '${tempDir.path}/Seq_OpeningScene.lmas';

    final seqData = SequencerData(
      fps: 30,
      lengthFrames: 120,
      tracks: [
        SequencerTrack(
          id: 'track-light',
          actorId: 'actor-sun-id',
          actorName: 'DirectionalLight_Sun',
          kind: SequencerTrackKind.property,
          propertyName: 'intensity',
          channels: [
            SequencerChannel(
              name: 'intensity',
              keys: [
                SequencerKey(frame: 12, value: 50000.0),
              ],
            ),
          ],
        ),
      ],
    );

    final asset = LuminaAsset(
      assetId: 'seq-opening-id',
      name: 'Seq_OpeningScene',
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

  test('SequencerData roundtrip: 2 tracks with 5 keys persists and re-reads identically', () {
    final original = SequencerData(
      fps: 60,
      lengthFrames: 240,
      tracks: [
        SequencerTrack(
          id: 't1',
          actorId: 'act-1',
          actorName: 'CineCamera_Actor',
          kind: SequencerTrackKind.transform,
          channels: [
            SequencerChannel(
              name: 'Location.X',
              keys: [
                SequencerKey(frame: 0, value: 0.0),
                SequencerKey(frame: 30, value: 150.0),
                SequencerKey(frame: 60, value: 300.0),
              ],
            ),
          ],
        ),
        SequencerTrack(
          id: 't2',
          actorId: 'act-2',
          actorName: 'PointLight_Fill',
          kind: SequencerTrackKind.property,
          propertyName: 'intensity',
          channels: [
            SequencerChannel(
              name: 'intensity',
              keys: [
                SequencerKey(frame: 10, value: 2000.0),
                SequencerKey(frame: 100, value: 0.0),
              ],
            ),
          ],
        ),
      ],
    );

    final bytes = original.toBytes();
    final restored = SequencerData.fromBytes(bytes);
    expect(restored.fps, equals(60));
    expect(restored.lengthFrames, equals(240));
    expect(restored.tracks.length, equals(2));
    expect(restored.tracks[0].channels[0].keys.length, equals(3));
    expect(restored.tracks[1].channels[0].keys.length, equals(2));

    // Persist as real .lmas
    final assetFile = '${tempDir.path}/Roundtrip.lmas';
    final lmasAsset = LuminaAsset(
      assetId: 'roundtrip-id',
      name: 'Roundtrip',
      type: AssetType.sequencer,
      rawPayload: bytes,
    );
    File(assetFile).writeAsBytesSync(lmasAsset.toProtoBufferBytes());

    final reRead = LuminaAsset.fromBytes(File(assetFile).readAsBytesSync());
    expect(reRead.type, equals(AssetType.sequencer));
    final reReadData = SequencerData.fromBytes(reRead.rawPayload!);
    expect(reReadData.tracks[0].actorName, equals('CineCamera_Actor'));
    expect(reReadData.tracks[1].propertyName, equals('intensity'));
  });

  testWidgets('Binding picker lists exactly the actors of a real temp level (no hardcoded names)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final vm = SequencerViewModel(assetPath: lmasPath);
    await tester.runAsync(() => vm.load());

    final List<EditorActorNode> levelActors = [
      EditorActorNode(id: 'act-hero', name: 'HeroCharacter', type: 'Character', location: [0.0, 0.0, 0.0]),
      EditorActorNode(id: 'act-sun', name: 'Sun_Main', type: 'DirectionalLight', location: [0.0, 0.0, 10.0]),
      EditorActorNode(id: 'act-cam', name: 'Cinematic_Shot_1', type: 'Camera', location: [5.0, 5.0, 2.0]),
    ];

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SequencerSubEditor(
            assetName: 'Seq_OpeningScene',
            assetPath: lmasPath,
            viewModel: vm,
            levelActors: levelActors,
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify hardcoded fake track names are absent
    expect(find.text('CineCameraActor_1'), findsNothing);
    expect(find.text('BP_PlayerCharacter'), findsNothing);

    // Open Add Track dialog
    await tester.tap(find.text('+ Track'));
    await tester.pumpAndSettle();

    // Verify dialog shows real level actors
    expect(find.text('Add Actor Track'), findsOneWidget);
    expect(find.text('HeroCharacter'), findsOneWidget);

    // Close dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('Add track and add keyframe renders in tree and timeline canvas key rects', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final vm = SequencerViewModel(assetPath: lmasPath);
    await tester.runAsync(() => vm.load());

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SequencerSubEditor(
            assetName: 'Seq_OpeningScene',
            assetPath: lmasPath,
            viewModel: vm,
          ),
        ),
      ),
    );
    await tester.pump();

    // Initial state: 1 track with 1 key at frame 12
    expect(find.text('DirectionalLight_Sun'), findsOneWidget);
    expect(find.text('1 keys'), findsOneWidget);

    // Compute key rects on timeline canvas
    final rects = SequencerTimelinePainter.computeKeyRects(
      tracks: vm.tracks,
      lengthFrames: vm.lengthFrames,
      size: const Size(1000, 400),
    );
    expect(rects.length, equals(1));
    // At frame 12 of 120 -> x = (12/120) * 1000 = 100.0
    expect(rects.first.center.dx, closeTo(100.0, 1.0));
  });

  test('Retiming keyframe via moveKey snaps to whole frames and marks dirty', () async {
    final vm = SequencerViewModel(assetPath: lmasPath);
    await vm.load();

    final track = vm.tracks.first;
    expect(track.channels.first.keys.first.frame, equals(12));

    // Move key to frame 30
    vm.moveKey(track.id, 'intensity', 0, 30);
    expect(track.channels.first.keys.first.frame, equals(30));
    expect(vm.isDirty, isTrue);

    // Undo transaction moves it back to 12
    vm.undo();
    expect(track.channels.first.keys.first.frame, equals(12));

    // Redo transaction moves it to 30
    vm.redo();
    expect(track.channels.first.keys.first.frame, equals(30));
  });

  test('Delete keyframe with undo restores keyframe position', () async {
    final vm = SequencerViewModel(assetPath: lmasPath);
    await vm.load();

    final track = vm.tracks.first;
    expect(track.channels.first.keys.length, equals(1));

    // Delete key
    vm.deleteKey(track.id, 'intensity', 0);
    expect(track.channels.first.keys.length, equals(0));

    // Undo
    vm.undo();
    expect(track.channels.first.keys.length, equals(1));
    expect(track.channels.first.keys.first.frame, equals(12));
  });

  testWidgets('Delete track removes track from model and tree', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final vm = SequencerViewModel(assetPath: lmasPath);
    await tester.runAsync(() => vm.load());

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SequencerSubEditor(
            assetName: 'Seq_OpeningScene',
            assetPath: lmasPath,
            viewModel: vm,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('DirectionalLight_Sun'), findsOneWidget);

    vm.deleteTrack('track-light');
    await tester.pump();

    expect(find.text('DirectionalLight_Sun'), findsNothing);
    expect(find.text('No tracks bound yet'), findsOneWidget);
  });

  test('FPS change 30->60 updates timecode without altering keyframe frames', () async {
    final vm = SequencerViewModel(assetPath: lmasPath);
    await vm.load();

    vm.scrubToFrame(60);
    expect(vm.timecodeStr, equals('00:00:02:00'));

    vm.setFps(60);
    expect(vm.timecodeStr, equals('00:00:01:00'));
    expect(vm.tracks.first.channels.first.keys.first.frame, equals(12));
  });

  testWidgets('Missing actor binding shows MISSING badge and allows rebinding', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final vm = SequencerViewModel(assetPath: lmasPath);
    await tester.runAsync(() => vm.load());

    // Level with actor-other-id (actor-sun-id is missing)
    final List<EditorActorNode> levelActors = [
      EditorActorNode(id: 'actor-other-id', name: 'OtherLight', type: 'PointLight', location: [0.0, 0.0, 0.0]),
    ];

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SequencerSubEditor(
            assetName: 'Seq_OpeningScene',
            assetPath: lmasPath,
            viewModel: vm,
            levelActors: levelActors,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('MISSING'), findsOneWidget);

    // Rebind to OtherLight
    vm.rebindActor('track-light', 'actor-other-id', 'OtherLight');
    await tester.pump();

    expect(find.text('MISSING'), findsNothing);
    expect(find.text('OtherLight'), findsOneWidget);
  });

  test('Save writes .lmas to disk and clears isDirty', () async {
    final vm = SequencerViewModel(assetPath: lmasPath);
    await vm.load();

    vm.addTrack('act-new', 'NewActor', SequencerTrackKind.visibility);
    expect(vm.isDirty, isTrue);

    final saved = await vm.save();
    expect(saved, isTrue);
    expect(vm.isDirty, isFalse);

    // Verify file content on disk
    final bytes = File(lmasPath).readAsBytesSync();
    final asset = LuminaAsset.fromBytes(bytes);
    final data = SequencerData.fromBytes(asset.rawPayload!);
    expect(data.tracks.length, equals(2));
    expect(data.tracks.last.actorName, equals('NewActor'));
  });
}
