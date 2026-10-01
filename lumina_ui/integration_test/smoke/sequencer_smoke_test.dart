import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/sequencer_movie_render_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/sequencer_offscreen_frame_source.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/sequencer_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sequencer/curve_editor_widget.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sequencer/level_viewport.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sequencer/sequencer_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sequencer/timeline_widget.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Sequencer Smoke Scenario: Open Sequencer, add bound track, keyframes, and save', (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('sequencer_smoke_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeProjectSequencer');
    pDir.createSync(recursive: true);

    // Seed directories and assets
    final cinematicsDir = Directory('${pDir.path}/contents/cinematics')..createSync(recursive: true);
    Directory('${pDir.path}/contents/levels').createSync(recursive: true);

    final seqData = SequencerData(
      fps: 30,
      lengthFrames: 120,
      tracks: [
        SequencerTrack(
          id: 'track-light',
          actorId: 'actor-sun',
          actorName: 'DirectionalLight_Sun',
          kind: SequencerTrackKind.property,
          propertyName: 'intensity',
          channels: [
            SequencerChannel(
              name: 'intensity',
              keys: [
                SequencerKey(frame: 10, value: 50000.0),
                SequencerKey(frame: 60, value: 10000.0),
              ],
            ),
          ],
        ),
      ],
    );

    final seqAsset = LuminaAsset(
      assetId: 'seq-intro',
      name: 'SEQ_Intro_Cutscene',
      type: AssetType.sequencer,
      rawPayload: seqData.toBytes(),
    );

    final lmasFile = File('${cinematicsDir.path}/SEQ_Intro_Cutscene.lmas');
    lmasFile.writeAsBytesSync(seqAsset.toProtoBufferBytes());

    try {
      final p = LuminaProject(
        projectName: 'SmokeProjectSequencer',
        activeLevel: 'contents/levels/L_Main.lmas',
        settings: EngineScalabilitySettings(targetFps: 60),
      );

      final vm = EditorViewModel(
        initialProject: p,
        projectDirPath: pDir.path,
        enableTimers: false,
      );
      addTearDown(vm.dispose);

      final repaintBoundaryKey = GlobalKey();

      final seqVm = SequencerViewModel(assetPath: lmasFile.path);
      await seqVm.load();

      final levelActors = [
        EditorActorNode(id: 'actor-sun', name: 'DirectionalLight_Sun', type: 'DirectionalLight', location: [0.0, 0.0, 10.0]),
        EditorActorNode(id: 'actor-cam', name: 'CineCamera_01', type: 'Camera', location: [5.0, 5.0, 2.0]),
      ];

      await tester.pumpWidget(
        RepaintBoundary(
          key: repaintBoundaryKey,
          child: ShadcnApp(
            theme: luminaEditorTheme(),
            home: Scaffold(
              child: SequencerSubEditor(
                assetName: 'SEQ_Intro_Cutscene',
                assetPath: lmasFile.path,
                viewModel: seqVm,
                levelActors: levelActors,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rec = SmokeRecorder(tester, boundary: find.byKey(repaintBoundaryKey));
      await rec.hold(const Duration(milliseconds: 1500));

      // 1. Verify Outliner & Toolbar
      expect(find.text('SEQUENCER'), findsOneWidget);
      expect(find.text('SEQ_Intro_Cutscene'), findsOneWidget);
      expect(find.text('DirectionalLight_Sun'), findsOneWidget);
      expect(find.text('2 keys'), findsOneWidget);

      // 2. Add Track for CineCamera_01
      seqVm.addTrack('actor-cam', 'CineCamera_01', SequencerTrackKind.transform);
      await tester.pumpAndSettle();
      expect(find.text('CineCamera_01'), findsOneWidget);
      await rec.hold(const Duration(seconds: 1));

      // Select the camera track in the outliner and open its curves.
      await tester.tap(find.text('CineCamera_01'));
      await tester.pump(const Duration(milliseconds: 50));
      await rec.hold(const Duration(milliseconds: 600));
      await tester.tap(find.text('Curves & Tangents'));
      await tester.pump(const Duration(milliseconds: 50));
      await rec.hold(const Duration(milliseconds: 800));

      // Key the camera's Location.X out and back, one key at a time: the curve
      // grows with each key.
      final camTrack = seqVm.tracks.firstWhere((t) => t.actorId == 'actor-cam');
      for (final (frame, value) in const [(0, 0.0), (60, 300.0), (120, 0.0)]) {
        seqVm.addKey(camTrack.id, 'Location.X', frame, value);
        await tester.pump(const Duration(milliseconds: 50));
        await rec.hold(const Duration(milliseconds: 800));
      }
      expect(seqVm.tracks.firstWhere((t) => t.actorId == 'actor-cam').channels.first.keys.length, 3);

      // Scrub the playhead across the whole sequence.
      for (var frame = 0; frame <= 120; frame += 3) {
        seqVm.scrubToFrame(frame);
        await tester.pump(const Duration(milliseconds: 16));
        await rec.capture();
      }

      // Real ticker-driven playback from the transport's Play and Stop.
      await tester.tap(find.byKey(const ValueKey('seq_transport_first')));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tap(find.byKey(const ValueKey('seq_transport_play')));
      await rec.hold(const Duration(milliseconds: 1500));
      expect(seqVm.playheadFrame, greaterThan(0), reason: 'playback advanced the playhead');
      await tester.tap(find.byKey(const ValueKey('seq_transport_stop')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(seqVm.isPlaying, isFalse);
      await rec.hold(const Duration(milliseconds: 600));

      // 3. Save from the toolbar.
      expect(seqVm.isDirty, isTrue);
      await tester.tap(find.text('Save'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(seqVm.isDirty, isFalse, reason: 'Save wrote the sequence');
      await rec.hold(const Duration(seconds: 1));

      // 4. Capture screenshot
      final pngBytes = await SmokeArtifacts.captureIntegrationPng(
        binding,
        tester,
        boundary: find.byKey(repaintBoundaryKey),
      );

      SmokeArtifacts.saveScreenshot(
        'Sequencer Smoke Scenario: Track outliner and multi-track timeline verified',
        pngBytes,
      );
      rec.save('Sequencer Smoke Scenario: Open Sequencer, add bound track, keyframes, and save');

      expect(pngBytes.length, greaterThan(0));
    } finally {
      if (tempProjectsDir.existsSync()) {
        tempProjectsDir.deleteSync(recursive: true);
      }
    }
  });

  testWidgets('Sequencer Smoke Scenario: Curve editor scrub + playback drives the live Filament level', (tester) async {
    final acUnitGlb = '${Directory.current.parent.path}/test-assets/Props/AC_units/ac_unit_a_300x300.glb';
    final tempProjectsDir = Directory.systemTemp.createTempSync('sequencer_curves_smoke_');
    const projectName = 'SmokeProjectSequencerCurves';
    final pDir = Directory('${tempProjectsDir.path}/$projectName')..createSync(recursive: true);

    // Real mesh asset in the project so the level viewport renders a model.
    final repo = AssetRepository();
    await repo.createAsset(projectPath: pDir.path, subFolder: 'meshes', fileName: 'AC_Unit.lmas', type: AssetType.filamesh);
    File(acUnitGlb).copySync('${pDir.path}/contents/meshes/AC_Unit.glb');

    try {
      final p = LuminaProject(
        projectName: projectName,
        activeLevel: 'contents/levels/L_Main.lmas',
        settings: EngineScalabilitySettings(targetFps: 60),
      );
      File('${pDir.path}/$projectName.lmproject').writeAsStringSync('{}');

      final vm = EditorViewModel(initialProject: p, projectLocation: tempProjectsDir.path, enableTimers: false);
      addTearDown(vm.dispose);
      await vm.ensureDefaultLevelAssets();
      await vm.spawnActorFromAsset(vm.realAssets.firstWhere((a) => a.fileName == 'AC_Unit.lmas'), location: [0, 0, 0]);
      final actor = vm.actors.last;
      final originalLocation = List<double>.from(actor.location);

      // Sequencer asset bound to the spawned actor: Location.X keyed 0 -> 0 and 60 -> 200 (cubic, flat tangents).
      final seqData = SequencerData(
        fps: 30,
        lengthFrames: 120,
        tracks: [
          SequencerTrack(
            id: 'track-ac-unit',
            actorId: actor.id,
            actorName: actor.name,
            kind: SequencerTrackKind.transform,
            channels: [
              SequencerChannel(name: 'Location.X', keys: [
                SequencerKey(frame: 0, value: 0.0, interpolation: KeyInterpolation.cubic),
                SequencerKey(frame: 60, value: 200.0, interpolation: KeyInterpolation.cubic),
              ]),
              SequencerChannel(name: 'Location.Y'),
              SequencerChannel(name: 'Location.Z'),
              SequencerChannel(name: 'Rotation.X'),
              SequencerChannel(name: 'Rotation.Y'),
              SequencerChannel(name: 'Rotation.Z', keys: [
                SequencerKey(frame: 0, value: 0.0),
                SequencerKey(frame: 120, value: 90.0),
              ]),
              SequencerChannel(name: 'Scale.X'),
              SequencerChannel(name: 'Scale.Y'),
              SequencerChannel(name: 'Scale.Z'),
            ],
          ),
        ],
      );
      final cinematicsDir = Directory('${pDir.path}/contents/cinematics')..createSync(recursive: true);
      final seqFile = File('${cinematicsDir.path}/SEQ_Flyby.lmas');
      seqFile.writeAsBytesSync(LuminaAsset(
        assetId: 'seq-flyby',
        name: 'SEQ_Flyby',
        type: AssetType.sequencer,
        rawPayload: seqData.toBytes(),
      ).toProtoBufferBytes());
      vm.refreshAssets();
      final seqAsset = vm.realAssets.firstWhere((a) => a.fileName == 'SEQ_Flyby.lmas');

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: ShadcnApp(
            theme: luminaEditorTheme(),
            home: MainEditorView(viewModel: vm),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1)); // let Filament bring the level up
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));

      // Open the sequencer through the real shell tab path (editorViewModel is passed by the workspace).
      vm.openSubEditorTab('SEQUENCER', asset: seqAsset);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SequencerSubEditor), findsOneWidget);
      expect(find.text('SEQUENCER'), findsWidgets);
      await rec.hold(const Duration(milliseconds: 1500));

      await tester.tap(find.text('Curves & Tangents'));
      await tester.pump(const Duration(milliseconds: 200));
      await rec.hold(const Duration(seconds: 1));
      expect(find.byType(SequencerCurveEditorWidget), findsOneWidget);
      expect(find.text('CURVE EDITOR'), findsOneWidget);

      final seqVm = tester.widget<SequencerCurveEditorWidget>(find.byType(SequencerCurveEditorWidget)).viewModel;
      expect(seqVm.hasLevelBinding, isTrue, reason: 'the shell must bind the sequencer to the live level');
      // Spawning the actor was a real level edit (dirty); previewing must not change that flag either way.
      final dirtyBefore = vm.project.isDirty;

      // 1. Scrub to the midframe: the live actor moves immediately (cubic midpoint of 0..200 == 100).
      seqVm.scrubToFrame(30);
      await tester.pump(const Duration(milliseconds: 200));
      expect(actor.location[0], closeTo(100.0, 1e-6));
      expect(actor.rotation[2], closeTo(22.5, 1e-6));
      expect(seqVm.isPreviewingLevel, isTrue);
      expect(find.text('PREVIEWING LEVEL'), findsOneWidget);

      final pngCurves = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot(
        'Sequencer Smoke Scenario: Curve editor at midframe with interpolated pose applied to the level',
        pngCurves,
        usedAssets: ['contents/meshes/AC_Unit.glb', 'contents/cinematics/SEQ_Flyby.lmas'],
      );
      final decodedCurves = img.decodePng(pngCurves)!;
      expect(decodedCurves.width, greaterThan(0));
      // The canvas paints the X channel in the red axis colour: assert reddish pixels exist somewhere in the frame.
      int reddish = 0;
      for (int y = 0; y < decodedCurves.height; y += 4) {
        for (int x = 0; x < decodedCurves.width; x += 4) {
          final px = decodedCurves.getPixel(x, y);
          if (px.r > 180 && px.g < 140 && px.b < 140) reddish++;
        }
      }
      expect(reddish, greaterThan(0), reason: 'curve editor must draw the red Location.X curve/keys');
      await rec.hold(const Duration(milliseconds: 1500));

      // 2. Real ticker-driven playback with loop on; capture frames for video evidence.
      seqVm.setLooping(true);
      seqVm.play();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
        await rec.capture();
      }
      expect(seqVm.isPlaying, isTrue);
      expect(seqVm.playheadFrame, greaterThan(30), reason: 'the frame ticker must advance the playhead');
      // The looping playback keeps running on video.
      await rec.hold(const Duration(seconds: 3));

      // 3. Stop restores the pre-play pose and the level stays clean.
      seqVm.stop();
      await tester.pump(const Duration(milliseconds: 100));
      expect(seqVm.isPlaying, isFalse);
      expect(actor.location, equals(originalLocation));
      expect(actor.rotation[2], equals(0.0));
      expect(vm.project.isDirty, equals(dirtyBefore), reason: 'a cinematic preview never dirties or cleans the level');
      await rec.hold(const Duration(seconds: 1));

      // 4. Back on the level tab the real Filament viewport shows the scrubbed pose (IndexedStack keeps the sequencer alive).
      vm.selectTab(0);
      seqVm.scrubToFrame(45);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
      expect(actor.location[0], greaterThan(100.0));
      final pngViewport = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot(
        'Sequencer Smoke Scenario: Filament level viewport reflecting the frame-45 interpolated pose',
        pngViewport,
        usedAssets: ['contents/meshes/AC_Unit.glb', 'contents/cinematics/SEQ_Flyby.lmas'],
      );
      expect(pngViewport.length, greaterThan(0));
      await rec.hold(const Duration(milliseconds: 1500));

      seqVm.stop();
      expect(actor.location, equals(originalLocation));
      await tester.pump(const Duration(milliseconds: 100));
      await rec.hold(const Duration(seconds: 1));
      rec.save('Sequencer Smoke Scenario: Curve editor scrub + playback drives the live Filament level', usedAssets: ['contents/meshes/AC_Unit.glb', 'contents/cinematics/SEQ_Flyby.lmas']);
    } finally {
      if (tempProjectsDir.existsSync()) {
        tempProjectsDir.deleteSync(recursive: true);
      }
    }
  });

  testWidgets('Sequencer Smoke Scenario: Movie Render Queue writes a real offscreen PNG frame sequence', (tester) async {
    if (!SequencerOffscreenFrameSource.isSupported) {
      markTestSkipped('flutter_filament native asset (renderStandaloneView/readPixels) not available');
      return;
    }

    final barrelGlb = '${Directory.current.parent.path}/test-assets/Props/Barrels/fuel_barrel_red.glb';
    if (!File(barrelGlb).existsSync()) {
      markTestSkipped('test asset missing: $barrelGlb');
      return;
    }

    tester.view.physicalSize = const Size(1680, 1120);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Future<void> settle(WidgetTester t, {int frames = 20}) async {
      for (var i = 0; i < frames; i++) {
        await t.pump(const Duration(milliseconds: 16));
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
    }

    final tempProjectsDir = Directory.systemTemp.createTempSync('sequencer_render_smoke_');
    const projectName = 'SmokeProjectSequencerRender';
    final pDir = Directory('${tempProjectsDir.path}/$projectName')..createSync(recursive: true);

    final repo = AssetRepository();
    await repo.createAsset(projectPath: pDir.path, subFolder: 'meshes', fileName: 'Barrel.lmas', type: AssetType.filamesh);
    File(barrelGlb).copySync('${pDir.path}/contents/meshes/Barrel.glb');

    try {
      final p = LuminaProject(
        projectName: projectName,
        activeLevel: 'contents/levels/L_Main.lmas',
        settings: EngineScalabilitySettings(targetFps: 60),
      );
      File('${pDir.path}/$projectName.lmproject').writeAsStringSync('{}');

      final vm = EditorViewModel(initialProject: p, projectLocation: tempProjectsDir.path, enableTimers: false);
      addTearDown(vm.dispose);
      await vm.ensureDefaultLevelAssets();
      await vm.spawnActorFromAsset(vm.realAssets.firstWhere((a) => a.fileName == 'Barrel.lmas'), location: [0, 0, 0]);
      final actor = vm.actors.last;

      // A keyed cube-style move: the barrel travels 0 -> 400 over 60 sequence frames.
      final seqData = SequencerData(
        fps: 30,
        lengthFrames: 60,
        tracks: [
          SequencerTrack(
            id: 'track-barrel',
            actorId: actor.id,
            actorName: actor.name,
            kind: SequencerTrackKind.transform,
            channels: [
              SequencerChannel(name: 'Location.X', keys: [
                SequencerKey(frame: 0, value: 0.0, interpolation: KeyInterpolation.linear),
                SequencerKey(frame: 60, value: 400.0, interpolation: KeyInterpolation.linear),
              ]),
              SequencerChannel(name: 'Rotation.Y', keys: [
                SequencerKey(frame: 0, value: 0.0, interpolation: KeyInterpolation.linear),
                SequencerKey(frame: 60, value: 180.0, interpolation: KeyInterpolation.linear),
              ]),
            ],
          ),
        ],
      );
      final cinematicsDir = Directory('${pDir.path}/contents/cinematics')..createSync(recursive: true);
      final seqFile = File('${cinematicsDir.path}/SEQ_Render.lmas');
      seqFile.writeAsBytesSync(LuminaAsset(
        assetId: 'seq-render',
        name: 'SEQ_Render',
        type: AssetType.sequencer,
        rawPayload: seqData.toBytes(),
      ).toProtoBufferBytes());
      vm.refreshAssets();
      final seqAsset = vm.realAssets.firstWhere((a) => a.fileName == 'SEQ_Render.lmas');

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: ShadcnApp(
            theme: luminaEditorTheme(),
            home: MainEditorView(viewModel: vm),
          ),
        ),
      );
      await settle(tester, frames: 40);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));

      vm.openSubEditorTab('SEQUENCER', asset: seqAsset);
      await settle(tester, frames: 20);
      expect(find.byType(SequencerSubEditor), findsOneWidget);
      await rec.hold(const Duration(milliseconds: 1500));

      // Open the real Render Movie dialog from the sequencer toolbar.
      expect(find.text('Render Movie'), findsOneWidget);
      await tester.tap(find.text('Render Movie'));
      await settle(tester, frames: 20);
      await rec.hold(const Duration(milliseconds: 1500));
      expect(find.byKey(const ValueKey('render-start')), findsOneWidget);
      expect(find.text('PNG Sequence'), findsWidgets);

      final seqVm = tester.widget<SequencerTimelineWidget>(find.byType(SequencerTimelineWidget)).viewModel;

      // Fill the settings the way a user types them.
      for (final (key, value) in const [
        ('render-width', '256'),
        ('render-height', '144'),
        ('render-start-frame', '0'),
        ('render-end-frame', '2'),
        ('render-output-name', 'SmokeShot'),
      ]) {
        final field = find.byKey(ValueKey(key));
        await tester.tap(field);
        await settle(tester, frames: 2);
        await rec.typeText(field, value, perCharacter: const Duration(milliseconds: 150));
        await rec.hold(const Duration(milliseconds: 300));
      }
      await rec.hold(const Duration(milliseconds: 500));

      await tester.tap(find.byKey(const ValueKey('render-start')));

      // The render runs one frame per event-loop turn; settle on the real clock
      // and record it as it runs.
      for (var i = 0; i < 400; i++) {
        await settle(tester, frames: 2);
        await rec.captureIfChanged();
        if (seqVm.renderProgress?.phase == MovieRenderPhase.completed) break;
        if (seqVm.renderError != null) break;
      }
      expect(seqVm.renderError, isNull, reason: 'the offscreen render must not throw');
      expect(seqVm.renderProgress?.phase, MovieRenderPhase.completed);

      final outDir = Directory('${pDir.path}/saved/movie_renders/SmokeShot');
      final framePaths = [
        for (var i = 0; i < 3; i++) '${outDir.path}/frame_${i.toString().padLeft(5, '0')}.png',
      ];
      for (final path in framePaths) {
        expect(File(path).existsSync(), isTrue, reason: '$path must exist');
      }
      expect(File('${outDir.path}/render_manifest.json').existsSync(), isTrue);
      final manifest = jsonDecode(File('${outDir.path}/render_manifest.json').readAsStringSync()) as Map<String, dynamic>;
      expect(manifest['frames'], 3);

      final decoded = [for (final path in framePaths) img.decodePng(File(path).readAsBytesSync())!];
      for (final d in decoded) {
        expect(d.width, 256);
        expect(d.height, 144);
      }

      int diff(img.Image a, img.Image b) {
        var changed = 0;
        for (var y = 0; y < a.height; y += 2) {
          for (var x = 0; x < a.width; x += 2) {
            final pa = a.getPixel(x, y);
            final pb = b.getPixel(x, y);
            if ((pa.r - pb.r).abs() + (pa.g - pb.g).abs() + (pa.b - pb.b).abs() > 12) changed++;
          }
        }
        return changed;
      }

      final d01 = diff(decoded[0], decoded[1]);
      final d12 = diff(decoded[1], decoded[2]);
      // ignore: avoid_print
      print('movie render queue: frame deltas 0->1 = $d01 px, 1->2 = $d12 px, '
          'bytes=${seqVm.renderProgress?.bytesWritten}');
      expect(d01, greaterThan(0), reason: 'the barrel must move between rendered frames');
      expect(d12, greaterThan(0), reason: 'the barrel must keep moving between rendered frames');

      // Publish the real Filament frame 1 plus a WebM of the whole sequence.
      SmokeArtifacts.saveScreenshot(
        'Sequencer Smoke Scenario: Movie Render Queue offscreen frame 1 (real Filament readPixels)',
        File(framePaths[1]).readAsBytesSync(),
        usedAssets: ['Props/Barrels/fuel_barrel_red.glb', 'contents/cinematics/SEQ_Render.lmas'],
      );
      // The completion state offers the real output folder.
      await settle(tester, frames: 10);
      await rec.hold(const Duration(milliseconds: 1200));
      expect(find.byKey(const ValueKey('render-open-folder')), findsOneWidget);
      expect(find.textContaining('saved/movie_renders/SmokeShot'), findsWidgets);

      // And a UI screenshot of the finished dialog over the editor.
      final shellPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot(
        'Sequencer Smoke Scenario: Movie Render Queue completion state in Lumina Studio',
        shellPng,
        usedAssets: ['Props/Barrels/fuel_barrel_red.glb'],
      );
      expect(shellPng.length, greaterThan(0));

      // Done closes the dialog; the rendered range plays back in the editor.
      await tester.tap(find.text('Done'));
      await settle(tester, frames: 10);
      expect(find.byKey(const ValueKey('render-open-folder')), findsNothing);
      await rec.hold(const Duration(milliseconds: 600));
      for (var frame = 0; frame <= seqVm.lengthFrames; frame += 2) {
        seqVm.scrubToFrame(frame);
        await settle(tester, frames: 1);
        await rec.capture();
      }
      await rec.hold(const Duration(milliseconds: 800));
      rec.save('Sequencer Smoke Scenario: Movie Render Queue writes a real offscreen PNG frame sequence', usedAssets: ['Props/Barrels/fuel_barrel_red.glb', 'contents/cinematics/SEQ_Render.lmas']);
    } finally {
      if (tempProjectsDir.existsSync()) {
        tempProjectsDir.deleteSync(recursive: true);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 8)));

  testWidgets('Sequencer Smoke Scenario: The Sequencer viewport draws the level, follows the playhead and locks to the bound camera', (tester) async {
    final barrelGlb = '${Directory.current.parent.path}/test-assets/Props/Barrels/fuel_barrel_red.glb';
    final acUnitGlb = '${Directory.current.parent.path}/test-assets/Props/AC_units/ac_unit_a_300x300.glb';
    if (!File(barrelGlb).existsSync() || !File(acUnitGlb).existsSync()) {
      markTestSkipped('test assets missing: $barrelGlb, $acUnitGlb');
      return;
    }
    tester.view.physicalSize = const Size(1680, 1120);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Future<void> settle({int frames = 20}) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
    }

    const scenario = 'Sequencer Smoke Scenario: The Sequencer viewport draws the level, follows the playhead and locks to the bound camera';
    const usedAssets = ['Props/Barrels/fuel_barrel_red.glb', 'Props/AC_units/ac_unit_a_300x300.glb', 'contents/cinematics/SEQ_Shot.lmas'];
    final tempProjectsDir = Directory.systemTemp.createTempSync('seq_vp_smoke_');
    const projectName = 'SmokeSeqViewport';
    final pDir = Directory('${tempProjectsDir.path}/$projectName')..createSync(recursive: true);
    final repo = AssetRepository();
    await repo.createAsset(projectPath: pDir.path, subFolder: 'meshes', fileName: 'Barrel.lmas', type: AssetType.filamesh);
    File(barrelGlb).copySync('${pDir.path}/contents/meshes/Barrel.glb');
    await repo.createAsset(projectPath: pDir.path, subFolder: 'meshes', fileName: 'AC_Unit.lmas', type: AssetType.filamesh);
    File(acUnitGlb).copySync('${pDir.path}/contents/meshes/AC_Unit.glb');

    try {
      File('${pDir.path}/$projectName.lmproject').writeAsStringSync('{}');
      final vm = EditorViewModel(
        initialProject: LuminaProject(projectName: projectName, activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60)),
        projectLocation: tempProjectsDir.path,
        enableTimers: false,
      );
      addTearDown(vm.dispose);
      await vm.ensureDefaultLevelAssets();
      // The barrel the sequence moves, a static AC unit beside its path, and a camera.
      await vm.spawnActorFromAsset(vm.realAssets.firstWhere((a) => a.fileName == 'Barrel.lmas'), location: [-200, 0, 0]);
      final barrel = vm.actors.last;
      await vm.spawnActorFromAsset(vm.realAssets.firstWhere((a) => a.fileName == 'AC_Unit.lmas'), location: [0, 250, 0]);
      vm.spawnNewActor('Camera');
      final camera = vm.actors.last;
      camera.name = 'Camera_1';
      camera.location = [-200, -650, 180];
      camera.rotation = [-8, 0, 0];
      // Sky light and a sun, so the meshes are lit.
      vm.spawnNewActor('Environment');
      vm.spawnNewActor('DirectionalLight');
      vm.actors.last.location = [900, 900, 600]; // its arrow out of the shot
      vm.clearSelection();

      final seqData = SequencerData(fps: 30, lengthFrames: 120, tracks: [
        SequencerTrack(id: 'track-barrel', actorId: barrel.id, actorName: barrel.name, kind: SequencerTrackKind.transform, channels: [
          SequencerChannel(name: 'Location.X', keys: [SequencerKey(frame: 0, value: -200), SequencerKey(frame: 90, value: 250)]),
          SequencerChannel(name: 'Rotation.Z', keys: [SequencerKey(frame: 0, value: 0), SequencerKey(frame: 90, value: 180)]),
        ]),
        // The camera trucks with the barrel and pushes in.
        SequencerTrack(id: 'track-camera', actorId: camera.id, actorName: camera.name, kind: SequencerTrackKind.transform, channels: [
          SequencerChannel(name: 'Location.X', keys: [SequencerKey(frame: 0, value: -200), SequencerKey(frame: 90, value: 250)]),
          SequencerChannel(name: 'Location.Y', keys: [SequencerKey(frame: 0, value: -650), SequencerKey(frame: 90, value: -420)]),
        ]),
      ]);
      Directory('${pDir.path}/contents/cinematics').createSync(recursive: true);
      File('${pDir.path}/contents/cinematics/SEQ_Shot.lmas').writeAsBytesSync(
          LuminaAsset(assetId: 'seq-shot', name: 'SEQ_Shot', type: AssetType.sequencer, rawPayload: seqData.toBytes()).toProtoBufferBytes());
      vm.refreshAssets();

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(frames: 60);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(milliseconds: 1200));

      vm.openSubEditorTab('SEQUENCER', asset: vm.realAssets.firstWhere((a) => a.fileName == 'SEQ_Shot.lmas'));
      for (var i = 0; i < 100 && find.byType(SequencerLevelViewport).evaluate().isEmpty; i++) {
        await settle(frames: 1);
      }
      final seqView = tester.state<SequencerLevelViewportState>(find.byType(SequencerLevelViewport));
      for (var i = 0; i < 200 && !seqView.drawsLevelScene; i++) {
        await settle(frames: 1);
      }
      expect(seqView.drawsLevelScene, isTrue, reason: 'the Sequencer view renders the level viewport\'s scene');
      expect(find.text('SPHERE'), findsNothing, reason: 'no material preview shapes');
      final seqVm = seqView.sequencer;

      // A capture of the window, and the Sequencer viewport's rectangle in it
      // (inside its frame, below its camera bar).
      Future<({img.Image image, Rect rect})> shot(String name) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot(name, png, usedAssets: usedAssets);
        final image = img.decodePng(png)!;
        final scale = image.width / tester.getSize(find.byKey(boundaryKey)).width;
        final r = tester.getRect(find.byType(SequencerLevelViewport));
        return (image: image, rect: Rect.fromLTRB(r.left * scale + 8, r.top * scale + 60, r.right * scale - 8, r.bottom * scale - 8));
      }

      // Where [a] shows something [b] does not: the mean x of the pixels that
      // changed between the two captures and are not the blue sky or floor in [a].
      double movedMeanX(({img.Image image, Rect rect}) a, ({img.Image image, Rect rect}) b) {
        var count = 0;
        var sum = 0.0;
        for (var y = a.rect.top.round(); y < a.rect.bottom.round(); y += 2) {
          for (var x = a.rect.left.round(); x < a.rect.right.round(); x += 2) {
            final p = a.image.getPixel(x, y), q = b.image.getPixel(x, y);
            final diff = (p.r - q.r).abs() + (p.g - q.g).abs() + (p.b - q.b).abs();
            if (diff > 60 && p.b - p.r < 25) {
              count++;
              sum += x;
            }
          }
        }
        expect(count, greaterThan(40), reason: 'the barrel is drawn where it moved');
        return sum / count;
      }

      // 1. Editor camera on the animated barrel; the playhead at 0 and at 90.
      seqView.editorCamera
        ..yaw = 0
        ..pitch = 18
        ..distance = 1100
        ..target = [25, 0, 60];
      seqVm.scrubToFrame(0);
      await settle(frames: 30);
      await rec.hold(const Duration(milliseconds: 1500));
      final at0 = await shot('Sequencer Smoke Scenario: Sequencer viewport at frame 0 (editor camera)');
      seqVm.scrubToFrame(90);
      await settle(frames: 30);
      await rec.hold(const Duration(milliseconds: 1500));
      final at90 = await shot('Sequencer Smoke Scenario: Sequencer viewport at frame 90 (editor camera)');
      expect(barrel.location[0], closeTo(250.0, 1e-6));
      // The barrel moves +X: to the right for a camera looking along +Y.
      expect(movedMeanX(at90, at0) - movedMeanX(at0, at90), greaterThan(80), reason: 'the barrel moved right on screen with the playhead');

      // 2. Playback in the editor camera.
      seqVm.setLooping(true);
      seqVm.goToFirstFrame();
      seqVm.play();
      await rec.hold(const Duration(seconds: 4));
      seqVm.pause();

      // 3. Camera lock: through Camera_1 inside the 16:9 gate.
      expect(seqView.cameraCandidates.map((c) => c.id), [camera.id]);
      seqView.lockToCamera(camera.id);
      seqVm.scrubToFrame(45);
      await settle(frames: 30);
      expect(find.text('PILOTING Camera_1'), findsOneWidget);
      await rec.hold(const Duration(milliseconds: 1500));
      final locked = await shot('Sequencer Smoke Scenario: Sequencer viewport locked to Camera_1 at frame 45');
      final eye = LuminaAxes.location(camera.location);
      final cam = seqView.cameraForTest!;
      expect(cam.position.x, closeTo(eye.x, 1e-2));
      expect(cam.position.z, closeTo(eye.z, 1e-2));
      // The wide viewport pillarboxes the 16:9 gate: black at the sides, the level inside.
      final side = locked.image.getPixel(locked.rect.left.round() + 4, locked.rect.center.dy.round());
      final middle = locked.image.getPixel(locked.rect.center.dx.round(), locked.rect.center.dy.round());
      expect(side.r + side.g + side.b, lessThan(15), reason: 'outside the film gate is masked');
      expect(middle.r + middle.g + middle.b, greaterThan(60), reason: 'the level is drawn inside the gate');

      seqVm.goToFirstFrame();
      seqVm.play();
      await rec.hold(const Duration(seconds: 4));
      seqVm.stop();
      await settle(frames: 5);
      await rec.hold(const Duration(milliseconds: 800));
      rec.save(scenario, usedAssets: usedAssets);
    } finally {
      if (tempProjectsDir.existsSync()) {
        try {
          tempProjectsDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
