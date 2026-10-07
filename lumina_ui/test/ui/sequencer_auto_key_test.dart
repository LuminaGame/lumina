import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_preferences.dart';
import 'package:lumina_ui/ui/features/main_editor/services/transform_gizmo.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/sequencer_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sequencer/level_viewport.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sequencer/sequencer_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sequencer/timeline_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

const _nine = [
  'Location.X', 'Location.Y', 'Location.Z',
  'Rotation.X', 'Rotation.Y', 'Rotation.Z',
  'Scale.X', 'Scale.Y', 'Scale.Z',
];

/// A real SEQUENCER `.lmas` with one transform track bound to `actor-cube`;
/// [keys] maps channel → (frame, value) keys.
String _writeSequence(Directory dir, {Map<String, List<(int, double)>> keys = const {}, KeyInterpolation interp = KeyInterpolation.linear}) {
  final data = SequencerData(fps: 30, lengthFrames: 120, tracks: [
    SequencerTrack(
      id: 'track-cube',
      actorId: 'actor-cube',
      actorName: 'SM_Cube',
      kind: SequencerTrackKind.transform,
      channels: [
        for (final name in _nine)
          SequencerChannel(name: name, keys: [
            for (final (f, v) in keys[name] ?? const <(int, double)>[]) SequencerKey(frame: f, value: v, interpolation: interp),
          ]),
      ],
    ),
  ]);
  final path = '${dir.path}/contents/cinematics/SEQ_AutoKey.lmas';
  File(path).parent.createSync(recursive: true);
  File(path).writeAsBytesSync(
      LuminaAsset(assetId: 'seq-auto-key', name: 'SEQ_AutoKey', type: AssetType.sequencer, rawPayload: data.toBytes()).toProtoBufferBytes());
  return path;
}

/// A real temp project with an editor hosting `SM_Cube` (bound) and
/// `SM_Barrel` (not in the sequence), both at the origin.
({EditorViewModel evm, EditorActorNode cube, EditorActorNode barrel}) _level(Directory pDir) {
  final project = LuminaProject(
    projectName: 'SeqAutoKeyProject',
    activeLevel: 'contents/levels/L_Main.lmas',
    settings: EngineScalabilitySettings(targetFps: 60),
  );
  File('${pDir.path}/SeqAutoKeyProject.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
  Directory('${pDir.path}/contents/levels').createSync(recursive: true);
  final evm = EditorViewModel(initialProject: project, projectDirPath: pDir.path, enableTimers: false, autoInitAssets: false);
  final cube = EditorActorNode(id: 'actor-cube', name: 'SM_Cube', type: 'StaticMesh', location: [0, 0, 0], rotation: [0, 0, 0], scale: [1, 1, 1]);
  final barrel = EditorActorNode(id: 'actor-barrel', name: 'SM_Barrel', type: 'StaticMesh', location: [0, 0, 0], rotation: [0, 0, 0], scale: [1, 1, 1]);
  evm.addActorNodeForTest(cube);
  evm.addActorNodeForTest(barrel);
  return (evm: evm, cube: cube, barrel: barrel);
}

List<(int, double)> _keysOf(SequencerViewModel vm, String channel, {String trackId = 'track-cube'}) =>
    [for (final k in vm.findChannel(trackId, channel)?.keys ?? const <SequencerKey>[]) (k.frame, k.value)];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Directory pDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('seq_auto_key_test_');
    pDir = Directory('${tempDir.path}/SeqAutoKeyProject')..createSync(recursive: true);
    // Registered first, so it runs after the editor of the test is disposed.
    final dir = tempDir;
    addTearDown(() {
      try {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } on FileSystemException catch (_) {}
    });
  });

  Future<SequencerViewModel> open(String path, EditorViewModel evm) async {
    final vm = SequencerViewModel(assetPath: path);
    await vm.load();
    vm.bindLevel(actors: () => evm.actors, onChanged: evm.notifyListeners);
    evm.actorTransformEditHandler = vm.handleLevelTransformEdits;
    return vm;
  }

  group('Auto Key from the viewport gizmo', () {
    test('keys only the changed channel at the playhead, as one undo step; undo/redo', () async {
      final level = _level(pDir);
      addTearDown(level.evm.dispose);
      final vm = await open(_writeSequence(pDir), level.evm);
      vm.scrubToFrame(30);
      final steps = vm.transactions.history(limit: 200).length;

      vm.beginActorTransform('actor-cube');
      vm.previewActorTransform('actor-cube', location: [50, 0, 0]);
      vm.previewActorTransform('actor-cube', location: [150, 0, 0]);
      expect(_keysOf(vm, 'Location.X'), isEmpty, reason: 'no key while dragging');
      expect(vm.endActorTransform('actor-cube'), isTrue);

      expect(_keysOf(vm, 'Location.X'), [(30, 150.0)]);
      for (final name in _nine.where((n) => n != 'Location.X')) {
        expect(_keysOf(vm, name), isEmpty, reason: '$name did not change');
      }
      expect(vm.transactions.history(limit: 200).length, steps + 1, reason: 'one undo step per gesture');
      expect(vm.isDirty, isTrue);
      expect(level.evm.transactions.canUndo, isFalse, reason: 'the level records nothing');

      vm.undo();
      expect(_keysOf(vm, 'Location.X'), isEmpty);
      expect(level.cube.location[0], 0.0, reason: 'undo puts the actor back');
      vm.redo();
      expect(_keysOf(vm, 'Location.X'), [(30, 150.0)]);
      expect(level.cube.location[0], 150.0);
    });

    test('replaces a key already at the playhead frame and keeps its interpolation', () async {
      final level = _level(pDir);
      addTearDown(level.evm.dispose);
      final vm = await open(
          _writeSequence(pDir, keys: {'Location.X': [(30, 40.0)]}, interp: KeyInterpolation.cubic), level.evm);
      vm.scrubToFrame(30);
      expect(level.cube.location[0], 40.0);

      vm.beginActorTransform('actor-cube');
      vm.previewActorTransform('actor-cube', location: [90, 0, 0]);
      vm.endActorTransform('actor-cube');

      final keys = vm.findChannel('track-cube', 'Location.X')!.keys;
      expect(keys, hasLength(1));
      expect(keys.single.frame, 30);
      expect(keys.single.value, 90.0);
      expect(keys.single.interpolation, KeyInterpolation.cubic);
    });

    test('an actor the sequence does not animate gets a transform track on its first auto-key', () async {
      final level = _level(pDir);
      addTearDown(level.evm.dispose);
      final vm = await open(_writeSequence(pDir), level.evm);
      vm.scrubToFrame(12);
      expect(vm.transformTrackFor('actor-barrel'), isNull);

      vm.beginActorTransform('actor-barrel');
      vm.previewActorTransform('actor-barrel', scale: [1, 1, 2]);
      vm.endActorTransform('actor-barrel');

      final track = vm.transformTrackFor('actor-barrel')!;
      expect(track.actorName, 'SM_Barrel');
      expect(track.channels.map((c) => c.name), _nine);
      expect(_keysOf(vm, 'Scale.Z', trackId: track.id), [(12, 2.0)]);
      expect(track.channels.where((c) => c.keys.isNotEmpty), hasLength(1));

      vm.undo();
      expect(vm.transformTrackFor('actor-barrel'), isNull, reason: 'undo removes the track it created');
      expect(level.barrel.scale, [1.0, 1.0, 1.0]);
    });

    test('Auto Key off: a change is a preview the next scrub reverts; Key keys it', () async {
      final level = _level(pDir);
      addTearDown(level.evm.dispose);
      final vm = await open(_writeSequence(pDir), level.evm);
      vm.setAutoKey(false);
      vm.scrubToFrame(10);
      final steps = vm.transactions.history(limit: 200).length;

      vm.beginActorTransform('actor-cube');
      vm.previewActorTransform('actor-cube', location: [100, 0, 0]);
      vm.endActorTransform('actor-cube');
      expect(_keysOf(vm, 'Location.X'), isEmpty);
      expect(vm.transactions.history(limit: 200).length, steps);
      expect(vm.hasPendingPreview, isTrue);
      expect(level.cube.location[0], 100.0);

      vm.scrubToFrame(20);
      expect(level.cube.location[0], 0.0, reason: 'the scrub reverts the unkeyed preview');
      expect(vm.hasPendingPreview, isFalse);

      vm.beginActorTransform('actor-cube');
      vm.previewActorTransform('actor-cube', location: [70, 0, 0], rotation: [0, 0, 45]);
      vm.endActorTransform('actor-cube');
      vm.keyPendingOrSelected();
      expect(_keysOf(vm, 'Location.X'), [(20, 70.0)]);
      expect(_keysOf(vm, 'Rotation.Z'), [(20, 45.0)]);
      expect(_keysOf(vm, 'Location.Y'), isEmpty);
      expect(vm.hasPendingPreview, isFalse);

      // With nothing pending, Key keys the selected actor's whole transform.
      vm.scrubToFrame(40);
      vm.keyPendingOrSelected(selectedActorId: 'actor-cube');
      for (final name in _nine) {
        expect(vm.hasKeyAt('track-cube', name, 40), isTrue, reason: name);
      }
    });

    test('closing the Sequencer returns the actor to its level pose and the level stays clean', () async {
      final level = _level(pDir);
      addTearDown(level.evm.dispose);
      level.cube.location = [5, 6, 7];
      final vm = await open(_writeSequence(pDir), level.evm);
      vm.scrubToFrame(30);
      vm.beginActorTransform('actor-cube');
      vm.previewActorTransform('actor-cube', location: [150, 6, 7], scale: [2, 2, 2]);
      vm.endActorTransform('actor-cube');
      expect(level.cube.location, [150.0, 6.0, 7.0]);

      vm.restoreLevel();
      expect(level.cube.location, [5.0, 6.0, 7.0]);
      expect(level.cube.scale, [1.0, 1.0, 1.0]);
      expect(level.evm.project.isDirty, isFalse);
    });
  });

  group('Level transform edits while the Sequencer is open', () {
    test('Details and a level gizmo drag key a bound actor; an unbound actor is edited in the level', () async {
      final level = _level(pDir);
      addTearDown(level.evm.dispose);
      final evm = level.evm;
      final vm = await open(_writeSequence(pDir), evm);
      vm.scrubToFrame(20);

      evm.selectActor(level.cube);
      evm.updateActorLocation([0, 0, 55]); // a Details commit
      expect(_keysOf(vm, 'Location.Z'), [(20, 55.0)]);
      expect(_keysOf(vm, 'Location.X'), isEmpty);
      expect(evm.transactions.canUndo, isFalse, reason: 'no level undo step');
      expect(evm.project.isDirty, isFalse);

      evm.beginTransformDrag();
      evm.updateActorLocation([10, 0, 55], isCommit: false);
      evm.updateActorLocation([25, 0, 55], isCommit: false);
      evm.endTransformDrag();
      expect(_keysOf(vm, 'Location.X'), [(20, 25.0)]);
      expect(evm.transactions.canUndo, isFalse);
      expect(evm.project.isDirty, isFalse);

      evm.selectActor(level.barrel);
      evm.updateActorLocation([0, 300, 0]);
      expect(vm.transformTrackFor('actor-barrel'), isNull);
      expect(evm.transactions.canUndo, isTrue, reason: 'an ordinary level edit');
      expect(evm.project.isDirty, isTrue);
      expect(level.barrel.location, [0.0, 300.0, 0.0]);
    });
  });

  group('Key panel edits', () {
    test('value, frame, interpolation and delete are one undo step each; save/reload keeps the keys', () async {
      final level = _level(pDir);
      addTearDown(level.evm.dispose);
      final path = _writeSequence(pDir, keys: {
        'Location.X': [(0, 0.0), (60, 100.0)],
      });
      final vm = await open(path, level.evm);
      vm.scrubToFrame(60);
      vm.selectKey('track-cube', 'Location.X', 1);
      int steps() => vm.transactions.history(limit: 200).length;

      var before = steps();
      vm.setChannelValueAtFrame('track-cube', 'Location.Z', 60, 75);
      expect(_keysOf(vm, 'Location.Z'), [(60, 75.0)]);
      expect(level.cube.location[2], 75.0, reason: 'the evaluated actor moves at once');
      expect(steps(), before + 1);

      before = steps();
      vm.moveSelectedKeysToFrame(90);
      expect(_keysOf(vm, 'Location.X'), [(0, 0.0), (90, 100.0)]);
      expect(vm.selectedKey, ('track-cube', 'Location.X', 1), reason: 'the selection follows the key');
      expect(steps(), before + 1);
      vm.undo();
      expect(_keysOf(vm, 'Location.X'), [(0, 0.0), (60, 100.0)]);
      vm.redo();

      // Moving onto a frame with a key replaces that key.
      vm.selectKey('track-cube', 'Location.X', 1);
      vm.moveSelectedKeysToFrame(0);
      expect(_keysOf(vm, 'Location.X'), [(0, 100.0)]);
      vm.undo();
      expect(_keysOf(vm, 'Location.X'), [(0, 0.0), (90, 100.0)]);

      vm.selectKey('track-cube', 'Location.X', 0);
      vm.scrubToFrame(45);
      expect(level.cube.location[0], closeTo(50.0, 1e-9));
      before = steps();
      vm.setSelectedKeysInterpolation(SequencerKeyInterpolationChoice.constant);
      expect(level.cube.location[0], 0.0, reason: 'constant holds the left key');
      expect(steps(), before + 1);

      vm.nudgeSelectedKeys(5);
      expect(_keysOf(vm, 'Location.X'), [(5, 0.0), (90, 100.0)]);

      before = steps();
      vm.selectKey('track-cube', 'Location.X', 1);
      vm.toggleKeySelection('track-cube', 'Location.Z', 0);
      expect(vm.selectedKeys, hasLength(2));
      vm.deleteSelectedKeys();
      expect(_keysOf(vm, 'Location.X'), [(5, 0.0)]);
      expect(_keysOf(vm, 'Location.Z'), isEmpty);
      expect(steps(), before + 1, reason: 'deleting the selection is one step');
      vm.undo();
      expect(_keysOf(vm, 'Location.X'), [(5, 0.0), (90, 100.0)]);
      expect(_keysOf(vm, 'Location.Z'), [(60, 75.0)]);

      expect(await vm.save(), isTrue);
      final reopened = SequencerViewModel(assetPath: path);
      await reopened.load();
      expect(_keysOf(reopened, 'Location.X'), [(5, 0.0), (90, 100.0)]);
      expect(_keysOf(reopened, 'Location.Z'), [(60, 75.0)]);
      expect(reopened.findChannel('track-cube', 'Location.X')!.keys.first.interpolation, KeyInterpolation.constant);
    });
  });

  test('EditorPreferences.sequencerAutoKey defaults to on and survives a reload', () {
    final config = Directory('${tempDir.path}/config')..createSync();
    final prefs = EditorPreferences.load(configDir: config);
    expect(prefs.sequencerAutoKey, isTrue);
    prefs.setSequencerAutoKey(false);
    expect(EditorPreferences.load(configDir: config).sequencerAutoKey, isFalse);
  });

  group('Sequencer editor widgets', () {
    Future<({SequencerViewModel vm, EditorViewModel evm, EditorActorNode cube})> pumpEditor(
        WidgetTester tester, Map<String, List<(int, double)>> keys) async {
      tester.view.physicalSize = const Size(1700, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final level = _level(pDir);
      addTearDown(level.evm.dispose);
      final path = _writeSequence(pDir, keys: keys);
      final vm = SequencerViewModel(assetPath: path);
      await tester.runAsync(vm.load);
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SequencerSubEditor(assetName: 'SEQ_AutoKey', assetPath: path, viewModel: vm, editorViewModel: level.evm),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      return (vm: vm, evm: level.evm, cube: level.cube);
    }

    testWidgets('a drag on the viewport gizmo\'s X arrow keys Location.X; track click selects; W/E/R pick the tool',
        (tester) async {
      final env = await pumpEditor(tester, const {});
      final vm = env.vm, evm = env.evm;
      expect(vm.autoKey, isTrue, reason: 'Auto Key is on by default');
      expect(find.byKey(const ValueKey('seq_auto_key')), findsOneWidget);
      vm.scrubToFrame(24);

      // Clicking the track selects its actor in the level.
      await tester.tap(find.text('SM_Cube').first);
      await tester.pump(const Duration(milliseconds: 50));
      expect(evm.selectedActor?.id, 'actor-cube');
      evm.setActiveTool('translate');

      final view = tester.state<SequencerLevelViewportState>(find.byType(SequencerLevelViewport));
      view.editorCamera
        ..yaw = 0
        ..pitch = 20
        ..distance = 600
        ..target = [0, 0, 0];
      await tester.pump(const Duration(milliseconds: 50));
      final model = view.gizmoModel()!;
      final handles = model.handleScreenPositions()!;
      final centre = handles[TransformGizmoModel.center]!;
      final xEnd = handles[TransformGizmoModel.axisX]!;
      final grab = centre + (xEnd - centre) * 0.8;
      expect(model.hitTest(grab), TransformGizmoModel.axisX);
      expect(find.byKey(const ValueKey('seq_viewport_gizmo')), findsOneWidget);

      final origin = tester.getTopLeft(find.byType(SequencerLevelViewport));
      final gesture = await tester.startGesture(origin + grab, kind: PointerDeviceKind.mouse, buttons: kPrimaryMouseButton);
      final step = (xEnd - centre) / 10;
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(step);
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(view.isDraggingGizmo, isTrue);
      expect(env.cube.location[0], greaterThan(10), reason: 'the actor follows the arrow');
      expect(_keysOf(vm, 'Location.X'), isEmpty);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 50));

      final keys = _keysOf(vm, 'Location.X');
      expect(keys, hasLength(1));
      expect(keys.single.$1, 24);
      expect(keys.single.$2, closeTo(env.cube.location[0], 1e-9));
      expect(_keysOf(vm, 'Location.Y'), isEmpty);
      expect(_keysOf(vm, 'Location.Z'), isEmpty);

      // W/E/R while the viewport has focus.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      expect(evm.activeTool, 'rotate');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      expect(evm.activeTool, 'scale');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      expect(evm.activeTool, 'translate');
    });

    testWidgets('clicking a key opens the Key panel with its values; Shift-click adds a key; edits go through it',
        (tester) async {
      final env = await pumpEditor(tester, const {
        'Location.X': [(0, 0.0), (60, 100.0)],
        'Location.Z': [(60, 20.0)],
      });
      final vm = env.vm;
      expect(find.byKey(const ValueKey('seq_key_panel_empty')), findsOneWidget);

      final canvas = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is SequencerTimelinePainter);
      final rect = tester.getRect(canvas);
      final keyRects = SequencerTimelinePainter.computeKeyRects(tracks: vm.tracks, lengthFrames: vm.lengthFrames, size: rect.size);
      // Order: Location.X @0, Location.X @60, Location.Z @60.
      await tester.tapAt(rect.topLeft + keyRects[1].center);
      await tester.pump(const Duration(milliseconds: 500)); // past the double-tap window
      expect(vm.selectedKey, ('track-cube', 'Location.X', 1));

      String field(String key) => tester
          .widget<EditableText>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(EditableText)))
          .controller
          .text;
      expect(field('seq_key_frame'), '60');
      expect(tester.widget<Text>(find.byKey(const ValueKey('seq_key_time'))).data, startsWith('2.000 s'));
      expect(tester.widget<Text>(find.byKey(const ValueKey('seq_key_channels'))).data, 'Location.X');
      expect(field('seq_key_value_Location.X'), '100.00');
      expect(field('seq_key_value_Location.Z'), '20.00');
      expect(field('seq_key_value_Location.Y'), '0.00');
      expect(field('seq_key_value_Scale.X'), '1.00');

      // Shift-click the Location.Z key.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tapAt(rect.topLeft + keyRects[2].center);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump(const Duration(milliseconds: 50));
      expect(vm.selectedKeys, hasLength(2));
      expect(tester.widget<Text>(find.byKey(const ValueKey('seq_key_panel_title'))).data, 'KEY (2 SELECTED)');

      // Edit Location.Z at frame 60 through the panel.
      vm.scrubToFrame(60);
      await tester.pump();
      await tester.enterText(find.descendant(of: find.byKey(const ValueKey('seq_key_value_Location.Z')), matching: find.byType(EditableText)), '75');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 50));
      expect(_keysOf(vm, 'Location.Z'), [(60, 75.0)]);
      expect(env.cube.location[2], 75.0);

      // Delete from the panel removes both selected keys in one step.
      final steps = vm.transactions.history(limit: 200).length;
      await tester.tap(find.byKey(const ValueKey('seq_key_delete')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(_keysOf(vm, 'Location.X'), [(0, 0.0)]);
      expect(_keysOf(vm, 'Location.Z'), isEmpty);
      expect(vm.transactions.history(limit: 200).length, steps + 1);
      expect(find.byKey(const ValueKey('seq_key_panel_empty')), findsOneWidget);
    });

    testWidgets('the Auto Key toggle writes the preference', (tester) async {
      final env = await pumpEditor(tester, const {});
      addTearDown(() => env.evm.editorPreferences.setSequencerAutoKey(true));
      await tester.tap(find.byKey(const ValueKey('seq_auto_key')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(env.vm.autoKey, isFalse);
      expect(env.evm.editorPreferences.sequencerAutoKey, isFalse);
    });
  });
}
