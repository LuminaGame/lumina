import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/sequencer_movie_render_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/sequencer_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sequencer/render_dialog.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

SequencerData _sequence() => SequencerData(
      fps: 30,
      lengthFrames: 120,
      tracks: [
        SequencerTrack(
          id: 'track-a',
          actorId: 'actor-a',
          actorName: 'Cube',
          kind: SequencerTrackKind.transform,
          channels: [
            SequencerChannel(name: 'Location.X', keys: [
              SequencerKey(frame: 0, value: 0.0, interpolation: KeyInterpolation.linear),
              SequencerKey(frame: 60, value: 12.0, interpolation: KeyInterpolation.linear),
            ]),
          ],
        ),
      ],
    );

class _RecordingFrameSource implements MovieFrameSource {
  int rendered = 0;
  bool disposed = false;
  MovieRenderJob? job;
  final Duration perFrame;

  _RecordingFrameSource({this.perFrame = Duration.zero});

  @override
  bool get rowsAreBottomUp => false;

  @override
  Future<void> prepare(MovieRenderJob j) async => job = j;

  @override
  Future<Uint8List> renderFrame(MovieRenderFrameRequest request) async {
    if (perFrame > Duration.zero) await Future<void>.delayed(perFrame);
    rendered++;
    final px = Uint8List(request.width * request.height * 4);
    for (var i = 3; i < px.length; i += 4) {
      px[i] = 255;
    }
    return px;
  }

  @override
  Future<void> dispose() async => disposed = true;
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required String projectDirPath,
  required void Function(MovieRenderJob) onStart,
}) async {
  await tester.pumpWidget(
    ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: SizedBox(
          width: 700,
          height: 900,
          child: SequencerRenderDialog(
            sequence: _sequence(),
            sequenceName: 'SEQ_Intro',
            projectDirPath: projectDirPath,
            defaultStartFrame: 0,
            defaultEndFrame: 9,
            engineAvailable: true,
            now: DateTime(2026, 9, 20, 14, 5, 3),
            onStartRender: onStart,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late Directory tempRoot;
  late Directory projectDir;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('render_dialog_');
    projectDir = Directory('${tempRoot.path}/RenderProject')..createSync(recursive: true);
  });

  tearDown(() {
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  group('SequencerRenderDialog', () {
    testWidgets('offers only the PNG sequence format and shows the resolved output path', (tester) async {
      await _pumpDialog(tester, projectDirPath: projectDir.path, onStart: (_) {});

      expect(find.text('Render Movie'), findsOneWidget);
      expect(find.text('PNG Sequence'), findsWidgets);
      // No fake capabilities.
      expect(find.textContaining('MP4'), findsNothing);
      expect(find.textContaining('OpenEXR'), findsNothing);
      expect(
        find.textContaining('saved/movie_renders/SEQ_Intro_20260920_140503/'),
        findsOneWidget,
      );
    });

    testWidgets('an odd width blocks Start Render with an inline error', (tester) async {
      await _pumpDialog(tester, projectDirPath: projectDir.path, onStart: (_) {});

      await tester.enterText(find.byKey(const ValueKey('render-width')), '1921');
      await tester.pumpAndSettle();

      expect(find.text('Width must be an even number between 16 and 4096'), findsOneWidget);
      expect(tester.widget<PrimaryButton>(find.byKey(const ValueKey('render-start'))).onPressed, isNull);
    });

    testWidgets('start > end blocks Start Render with an inline error', (tester) async {
      await _pumpDialog(tester, projectDirPath: projectDir.path, onStart: (_) {});

      await tester.enterText(find.byKey(const ValueKey('render-start-frame')), '50');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('render-end-frame')), '10');
      await tester.pumpAndSettle();

      expect(find.text('Start frame must not be after the end frame'), findsOneWidget);
      expect(tester.widget<PrimaryButton>(find.byKey(const ValueKey('render-start'))).onPressed, isNull);
    });

    testWidgets('an empty output name blocks Start Render with an inline error', (tester) async {
      await _pumpDialog(tester, projectDirPath: projectDir.path, onStart: (_) {});

      await tester.enterText(find.byKey(const ValueKey('render-output-name')), '');
      await tester.pumpAndSettle();

      expect(find.text('Output folder name is required'), findsOneWidget);
      expect(tester.widget<PrimaryButton>(find.byKey(const ValueKey('render-start'))).onPressed, isNull);
    });

    testWidgets('valid input builds the exact MovieRenderJob', (tester) async {
      MovieRenderJob? captured;
      await _pumpDialog(tester, projectDirPath: projectDir.path, onStart: (j) => captured = j);

      await tester.enterText(find.byKey(const ValueKey('render-width')), '640');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('render-height')), '360');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('render-start-frame')), '2');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('render-end-frame')), '7');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('render-warmup')), '3');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('render-output-name')), 'MyShot');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('render-start')));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.width, 640);
      expect(captured!.height, 360);
      expect(captured!.fps, 30);
      expect(captured!.startFrame, 2);
      expect(captured!.endFrame, 7);
      expect(captured!.warmupFrames, 3);
      expect(captured!.totalFrames, 6);
      expect(captured!.sequenceName, 'SEQ_Intro');
      expect(captured!.format, MovieRenderFormat.pngSequence);
      expect(captured!.outputDir.path, '${projectDir.path}/saved/movie_renders/MyShot');
    });

    testWidgets('Start Render is disabled with a reason when the engine capability is missing', (tester) async {
      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: SizedBox(
              width: 700,
              height: 900,
              child: SequencerRenderDialog(
                sequence: _sequence(),
                sequenceName: 'SEQ_Intro',
                projectDirPath: projectDir.path,
                defaultStartFrame: 0,
                defaultEndFrame: 9,
                engineAvailable: false,
                onStartRender: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('renderStandaloneView'),
        findsOneWidget,
        reason: 'the missing capability must be named, not silently disabled',
      );
      expect(tester.widget<PrimaryButton>(find.byKey(const ValueKey('render-start'))).onPressed, isNull);
    });
  });

  group('SequencerViewModel.startRender', () {
    Future<SequencerViewModel> buildVm({bool dirty = false}) async {
      final cinematics = Directory('${projectDir.path}/contents/cinematics')..createSync(recursive: true);
      final file = File('${cinematics.path}/SEQ_Intro.lmas');
      file.writeAsBytesSync(LuminaAsset(
        assetId: 'seq',
        name: 'SEQ_Intro',
        type: AssetType.sequencer,
        rawPayload: _sequence().toBytes(),
      ).toProtoBufferBytes());
      final vm = SequencerViewModel(assetPath: file.path, projectDirPath: projectDir.path);
      await vm.load();
      if (dirty) vm.setLengthFrames(240);
      return vm;
    }

    MovieRenderJob jobFor(SequencerViewModel vm, {int end = 4, String name = 'Shot'}) => MovieRenderJob(
          sequence: vm.data,
          sequenceName: 'SEQ_Intro',
          width: 32,
          height: 32,
          fps: 30,
          startFrame: 0,
          endFrame: end,
          outputDir: MovieRenderJob.resolveOutputDir(projectDir.path, name),
        );

    test('derives the project directory from the asset path when not supplied', () async {
      final cinematics = Directory('${projectDir.path}/contents/cinematics')..createSync(recursive: true);
      final file = File('${cinematics.path}/SEQ_Intro.lmas');
      file.writeAsBytesSync(LuminaAsset(
        assetId: 'seq',
        name: 'SEQ_Intro',
        type: AssetType.sequencer,
        rawPayload: _sequence().toBytes(),
      ).toProtoBufferBytes());
      final vm = SequencerViewModel(assetPath: file.path);
      addTearDown(vm.dispose);
      expect(vm.projectDirPath, projectDir.path);
    });

    test('renders a real sequence and exposes live progress', () async {
      final vm = await buildVm();
      addTearDown(vm.dispose);
      final source = _RecordingFrameSource();

      final ok = await vm.startRender(jobFor(vm), frameSource: source);
      expect(ok, isTrue);
      expect(vm.isRendering, isFalse);
      expect(vm.renderProgress?.phase, MovieRenderPhase.completed);
      expect(source.rendered, 5);
      expect(source.disposed, isTrue);
      expect(vm.lastRenderDir?.path, '${projectDir.path}/saved/movie_renders/Shot');
      expect(File('${projectDir.path}/saved/movie_renders/Shot/render_manifest.json').existsSync(), isTrue);
    });

    test('a second startRender while one runs is rejected with a visible message', () async {
      final vm = await buildVm();
      addTearDown(vm.dispose);
      final first = vm.startRender(
        jobFor(vm, end: 9, name: 'ShotA'),
        frameSource: _RecordingFrameSource(perFrame: const Duration(milliseconds: 5)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(vm.isRendering, isTrue);

      final second = await vm.startRender(jobFor(vm, name: 'ShotB'), frameSource: _RecordingFrameSource());
      expect(second, isFalse);
      expect(vm.renderMessage, 'A movie render is already running.');
      expect(Directory('${projectDir.path}/saved/movie_renders/ShotB').existsSync(), isFalse);

      expect(await first, isTrue);
    });

    test('a dirty sequence is rejected until saved, then renders', () async {
      final vm = await buildVm(dirty: true);
      addTearDown(vm.dispose);
      expect(vm.isDirty, isTrue);

      final rejected = await vm.startRender(jobFor(vm), frameSource: _RecordingFrameSource());
      expect(rejected, isFalse);
      expect(vm.renderRequiresSave, isTrue);
      expect(vm.renderMessage, 'Save the sequence before rendering.');

      final ok = await vm.startRender(jobFor(vm), frameSource: _RecordingFrameSource(), saveFirst: true);
      expect(ok, isTrue);
      expect(vm.isDirty, isFalse);
      expect(vm.renderRequiresSave, isFalse);
    });

    test('cancelRender stops between frames and keeps the frames already written', () async {
      final vm = await buildVm();
      addTearDown(vm.dispose);
      final source = _RecordingFrameSource(perFrame: const Duration(milliseconds: 10));
      final future = vm.startRender(jobFor(vm, end: 29, name: 'ShotCancel'), frameSource: source);

      await Future<void>.delayed(const Duration(milliseconds: 60));
      vm.cancelRender();
      final ok = await future;

      expect(ok, isFalse);
      expect(vm.renderProgress?.phase, MovieRenderPhase.cancelled);
      final dir = Directory('${projectDir.path}/saved/movie_renders/ShotCancel');
      final pngs = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.png')).length;
      expect(pngs, greaterThan(0));
      expect(pngs, lessThan(30));
      expect(File('${dir.path}/render_manifest.json').existsSync(), isFalse);
      expect(source.disposed, isTrue);
    });

    test('restores the pre-render actor state exactly like stop()', () async {
      final vm = await buildVm();
      addTearDown(vm.dispose);
      final actor = EditorActorNode(id: 'actor-a', name: 'Cube', type: 'StaticMesh', location: [0, 0, 0]);
      vm.bindLevel(actors: () => [actor]);
      vm.scrubToFrame(30);
      expect(actor.location[0], closeTo(6.0, 1e-6));

      await vm.startRender(jobFor(vm, name: 'ShotRestore'), frameSource: _RecordingFrameSource());
      expect(actor.location[0], 0.0, reason: 'the render must leave the editor pose restored');
      expect(vm.isPreviewingLevel, isFalse);
    });
  });
}
