import 'dart:convert';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/sequencer_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sequencer/curve_editor_widget.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// Writes a real SEQUENCER `.lmas` with one transform track keyed on
/// Location.X at frames 0 -> 0.0 and 60 -> 12.0 (cubic by default so the
/// tangent handles are meaningful) and returns its path.
String _writeSequence(Directory dir, {KeyInterpolation interpolation = KeyInterpolation.cubic, List<SequencerTrack>? extraTracks}) {
  final data = SequencerData(
    fps: 30,
    lengthFrames: 120,
    tracks: [
      SequencerTrack(
        id: 'track-cube',
        actorId: 'actor-cube',
        actorName: 'SM_Cube',
        kind: SequencerTrackKind.transform,
        channels: [
          SequencerChannel(name: 'Location.X', keys: [
            SequencerKey(frame: 0, value: 0.0, interpolation: interpolation),
            SequencerKey(frame: 60, value: 12.0, interpolation: interpolation),
          ]),
          SequencerChannel(name: 'Location.Y'),
          SequencerChannel(name: 'Location.Z'),
          SequencerChannel(name: 'Rotation.X'),
          SequencerChannel(name: 'Rotation.Y'),
          SequencerChannel(name: 'Rotation.Z'),
          SequencerChannel(name: 'Scale.X'),
          SequencerChannel(name: 'Scale.Y'),
          SequencerChannel(name: 'Scale.Z'),
        ],
      ),
      ...?extraTracks,
    ],
  );
  final asset = LuminaAsset(
    assetId: 'seq-curves',
    name: 'SEQ_Curves',
    type: AssetType.sequencer,
    rawPayload: data.toBytes(),
  );
  final path = '${dir.path}/contents/cinematics/SEQ_Curves.lmas';
  File(path).parent.createSync(recursive: true);
  File(path).writeAsBytesSync(asset.toProtoBufferBytes());
  return path;
}

/// A real temp project on disk with an EditorViewModel hosting one cube actor
/// at the origin; no timers so nothing auto-saves behind the test's back.
({EditorViewModel evm, EditorActorNode cube}) _levelWithCube(Directory pDir) {
  final project = LuminaProject(
    projectName: 'SeqCurvesProject',
    activeLevel: 'contents/levels/L_Main.lmas',
    settings: EngineScalabilitySettings(targetFps: 60),
  );
  File('${pDir.path}/SeqCurvesProject.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
  Directory('${pDir.path}/contents/levels').createSync(recursive: true);
  final evm = EditorViewModel(
    initialProject: project,
    projectDirPath: pDir.path,
    enableTimers: false,
    autoInitAssets: false,
  );
  final cube = EditorActorNode(
    id: 'actor-cube',
    name: 'SM_Cube',
    type: 'StaticMesh',
    location: [0.0, 0.0, 0.0],
    rotation: [0.0, 0.0, 0.0],
    scale: [1.0, 1.0, 1.0],
  );
  evm.addActorNodeForTest(cube);
  return (evm: evm, cube: cube);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Directory pDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('seq_curves_test_');
    pDir = Directory('${tempDir.path}/SeqCurvesProject')..createSync(recursive: true);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('Scrub-anywhere: playheadFrame = 30 writes Location.X == 6.0 onto the live actor immediately', () async {
    final level = _levelWithCube(pDir);
    addTearDown(level.evm.dispose);
    final seqPath = _writeSequence(pDir, interpolation: KeyInterpolation.linear);

    final vm = SequencerViewModel(assetPath: seqPath);
    await vm.load();
    vm.bindLevel(actors: () => level.evm.actors, onChanged: level.evm.notifyListeners);

    var notifications = 0;
    level.evm.addListener(() => notifications++);

    expect(level.cube.location[0], equals(0.0));
    vm.playheadFrame = 30;
    expect(level.cube.location[0], equals(6.0));
    expect(vm.isPlaying, isFalse, reason: 'no play was required');
    expect(notifications, greaterThan(0), reason: 'viewport sync path must observe the change');

    vm.scrubToFrame(60);
    expect(level.cube.location[0], equals(12.0));
  });

  test('Playback with manual clock: fps 30, step 1.0 s -> frame 30 and actor holds the pose; loop wraps', () async {
    final level = _levelWithCube(pDir);
    addTearDown(level.evm.dispose);
    final seqPath = _writeSequence(pDir, interpolation: KeyInterpolation.linear);

    final vm = SequencerViewModel(assetPath: seqPath);
    await vm.load();
    vm.bindLevel(actors: () => level.evm.actors, onChanged: level.evm.notifyListeners);
    expect(vm.fps, equals(30));

    vm.play();
    expect(vm.isPlaying, isTrue);
    vm.advanceClock(1.0);
    expect(vm.playheadFrame, equals(30));
    expect(level.cube.location[0], closeTo(6.0, 1e-9));

    // Loop on within [0, 60]: from frame 0, 2.5 s = 75 frames wraps to 15.
    vm.stop();
    vm.setPlaybackRange(0, 60);
    vm.setLooping(true);
    vm.play();
    vm.advanceClock(2.5);
    expect(vm.playheadFrame, equals(15));
    expect(vm.isPlaying, isTrue);
    expect(level.cube.location[0], closeTo(3.0, 1e-9));

    // Loop off: playback stops at rangeEnd.
    vm.stop();
    vm.setLooping(false);
    vm.play();
    vm.advanceClock(10.0);
    expect(vm.playheadFrame, equals(60));
    expect(vm.isPlaying, isFalse);
  });

  test('stop restores the original location and the level stays clean after a play/stop cycle', () async {
    final level = _levelWithCube(pDir);
    addTearDown(level.evm.dispose);
    level.cube.location = [1.5, 2.0, 3.0];
    final seqPath = _writeSequence(pDir, interpolation: KeyInterpolation.linear);

    final vm = SequencerViewModel(assetPath: seqPath);
    await vm.load();
    vm.bindLevel(actors: () => level.evm.actors, onChanged: level.evm.notifyListeners);
    expect(level.evm.project.isDirty, isFalse);

    vm.play();
    vm.advanceClock(1.0);
    expect(level.cube.location[0], closeTo(6.0, 1e-9));
    expect(level.cube.location[1], equals(2.0), reason: 'unkeyed channels are untouched');

    vm.stop();
    expect(vm.isPlaying, isFalse);
    expect(vm.playheadFrame, equals(0), reason: 'stop returns to range start');
    expect(level.cube.location, equals([1.5, 2.0, 3.0]));
    expect(level.evm.project.isDirty, isFalse);
    expect(level.evm.transactions.canUndo, isFalse, reason: 'a preview never records undo transactions');
  });

  test('Next/previous keyframe jumps across the merged key set of all tracks', () async {
    final level = _levelWithCube(pDir);
    addTearDown(level.evm.dispose);
    final seqPath = _writeSequence(pDir);

    final vm = SequencerViewModel(assetPath: seqPath);
    await vm.load();
    // Replace the default keys with 10 / 25 / 40 spread over two tracks.
    vm.deleteKey('track-cube', 'Location.X', 1);
    vm.deleteKey('track-cube', 'Location.X', 0);
    vm.addKey('track-cube', 'Location.X', 10, 1.0);
    vm.addKey('track-cube', 'Location.X', 40, 4.0);
    vm.addTrack('actor-cube', 'SM_Cube', SequencerTrackKind.visibility);
    vm.addKey(vm.tracks.last.id, 'visibility', 25, 1.0);

    vm.scrubToFrame(12);
    vm.nextKeyframe();
    expect(vm.playheadFrame, equals(25));
    vm.nextKeyframe();
    expect(vm.playheadFrame, equals(40));
    vm.nextKeyframe();
    expect(vm.playheadFrame, equals(40), reason: 'no key after the last one');

    vm.scrubToFrame(12);
    vm.previousKeyframe();
    expect(vm.playheadFrame, equals(10));
    vm.previousKeyframe();
    expect(vm.playheadFrame, equals(10));

    vm.scrubToFrame(33);
    vm.goToFirstFrame();
    expect(vm.playheadFrame, equals(0));
  });

  test('Visibility track: scrubbing to 31 hides the live actor, back to 0 restores it', () async {
    final level = _levelWithCube(pDir);
    addTearDown(level.evm.dispose);
    final seqPath = _writeSequence(pDir, extraTracks: [
      SequencerTrack(
        id: 'track-vis',
        actorId: 'actor-cube',
        actorName: 'SM_Cube',
        kind: SequencerTrackKind.visibility,
        channels: [
          SequencerChannel(name: 'visibility', keys: [
            SequencerKey(frame: 0, value: 1.0),
            SequencerKey(frame: 30, value: 0.0),
          ]),
        ],
      ),
    ]);

    final vm = SequencerViewModel(assetPath: seqPath);
    await vm.load();
    vm.bindLevel(actors: () => level.evm.actors, onChanged: level.evm.notifyListeners);

    expect(level.cube.isVisible, isTrue);
    vm.scrubToFrame(31);
    expect(level.cube.isVisible, isFalse);
    vm.scrubToFrame(0);
    expect(level.cube.isVisible, isTrue);
  });

  test('Property track writes the bound numeric property (light intensity) onto the actor', () async {
    final level = _levelWithCube(pDir);
    addTearDown(level.evm.dispose);
    final seqPath = _writeSequence(pDir, extraTracks: [
      SequencerTrack(
        id: 'track-int',
        actorId: 'actor-cube',
        actorName: 'SM_Cube',
        kind: SequencerTrackKind.property,
        propertyName: 'lightIntensity',
        channels: [
          SequencerChannel(name: 'lightIntensity', keys: [
            SequencerKey(frame: 0, value: 1000.0),
            SequencerKey(frame: 100, value: 2000.0),
          ]),
        ],
      ),
    ]);

    final vm = SequencerViewModel(assetPath: seqPath);
    await vm.load();
    vm.bindLevel(actors: () => level.evm.actors, onChanged: level.evm.notifyListeners);

    final original = level.cube.lightIntensity;
    vm.scrubToFrame(50);
    expect(level.cube.lightIntensity, closeTo(1500.0, 1e-9));
    vm.stop();
    expect(level.cube.lightIntensity, equals(original));
  });

  testWidgets('Curve canvas: dragging the out-tangent handle mutates outTangent and changes the painted segment', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final seqPath = _writeSequence(pDir);
    final vm = SequencerViewModel(assetPath: seqPath);
    await tester.runAsync(() => vm.load());

    const view = CurveView(minFrame: 0, maxFrame: 120, minValue: -4, maxValue: 16);
    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SequencerCurveEditorWidget(viewModel: vm, initialView: view),
        ),
      ),
    );
    await tester.pump();

    final canvasFinder = find.byKey(SequencerCurveEditorWidget.canvasKey);
    expect(canvasFinder, findsOneWidget);
    final canvasRect = tester.getRect(canvasFinder);
    final canvasSize = canvasRect.size;

    final channel = vm.findChannel('track-cube', 'Location.X')!;
    final before = SequencerCurvePainter.buildChannelPoints(channel, view, canvasSize);
    expect(channel.keys.first.outTangent, equals(0.0));

    // Select key 0 by clicking its square, then drag its out-tangent handle upward.
    final keyPos = SequencerCurvePainter.keyScreenPosition(channel.keys.first, view, canvasSize);
    await tester.tapAt(canvasRect.topLeft + keyPos);
    await tester.pump();
    expect(vm.selectedKey, equals(('track-cube', 'Location.X', 0)));

    final handles = SequencerCurvePainter.tangentHandlePositions(channel, 0, view, canvasSize);
    final outHandle = canvasRect.topLeft + handles.outHandle;
    final gesture = await tester.startGesture(outHandle);
    await tester.pump();
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(channel.keys.first.outTangent, greaterThan(0.0));
    final after = SequencerCurvePainter.buildChannelPoints(channel, view, canvasSize);
    expect(after.length, equals(before.length));
    expect(after, isNot(equals(before)), reason: 'segment repaints from the new tangent');
    expect(vm.isDirty, isTrue);
  });

  testWidgets('Curve canvas context menu: Interpolation -> Linear on a cubic key persists through save/reload', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final seqPath = _writeSequence(pDir);
    final vm = SequencerViewModel(assetPath: seqPath);
    await tester.runAsync(() => vm.load());
    expect(vm.findChannel('track-cube', 'Location.X')!.keys.first.interpolation, equals(KeyInterpolation.cubic));

    const view = CurveView(minFrame: 0, maxFrame: 120, minValue: -4, maxValue: 16);
    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SequencerCurveEditorWidget(viewModel: vm, initialView: view),
        ),
      ),
    );
    await tester.pump();

    final canvasRect = tester.getRect(find.byKey(SequencerCurveEditorWidget.canvasKey));
    final channel = vm.findChannel('track-cube', 'Location.X')!;
    final keyPos = canvasRect.topLeft + SequencerCurvePainter.keyScreenPosition(channel.keys.first, view, canvasRect.size);

    await tester.tapAt(keyPos, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Interpolation'), findsOneWidget);
    await tester.tap(find.text('Interpolation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Linear'));
    await tester.pumpAndSettle();

    expect(channel.keys.first.interpolation, equals(KeyInterpolation.linear));

    final saved = await tester.runAsync(() => vm.save());
    expect(saved, isTrue);

    final reloaded = SequencerViewModel(assetPath: seqPath);
    await tester.runAsync(() => reloaded.load());
    expect(reloaded.findChannel('track-cube', 'Location.X')!.keys.first.interpolation, equals(KeyInterpolation.linear));
  });

  testWidgets('Curve editor channel list toggles visibility and Fit reframes all keys', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final seqPath = _writeSequence(pDir);
    final vm = SequencerViewModel(assetPath: seqPath);
    await tester.runAsync(() => vm.load());

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SequencerCurveEditorWidget(viewModel: vm),
        ),
      ),
    );
    await tester.pump();

    // Every transform channel is listed with its colour chip; keyed ones are visible by default.
    expect(find.text('Location.X'), findsOneWidget);
    expect(find.text('Scale.Z'), findsOneWidget);
    expect(find.text('Fit'), findsOneWidget);

    final state = tester.state<SequencerCurveEditorWidgetState>(find.byType(SequencerCurveEditorWidget));
    expect(state.isChannelVisible('track-cube', 'Location.X'), isTrue);
    state.setChannelVisible('track-cube', 'Location.X', false);
    await tester.pump();
    expect(state.isChannelVisible('track-cube', 'Location.X'), isFalse);
    state.setChannelVisible('track-cube', 'Location.X', true);

    // Zoom in, then Fit must frame keys 0..60 / 0..12 with margin.
    state.zoomBy(0.5, focusFrame: 30);
    await tester.pump();
    expect(state.view.maxFrame - state.view.minFrame, lessThan(120));
    await tester.tap(find.text('Fit'));
    await tester.pump();
    expect(state.view.minFrame, lessThanOrEqualTo(0));
    expect(state.view.maxFrame, greaterThanOrEqualTo(60));
    expect(state.view.minValue, lessThanOrEqualTo(0));
    expect(state.view.maxValue, greaterThanOrEqualTo(12));
  });
}
