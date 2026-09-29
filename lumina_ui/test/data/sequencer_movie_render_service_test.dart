import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/sequencer_evaluator.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/sequencer_movie_render_service.dart';

/// A frame source that never touches the GPU: it paints a flat colour derived
/// from the frame index so every written PNG is a real, decodable image, and
/// records exactly which frames were requested plus the evaluator samples that
/// reached the "scene".
class _FakeFrameSource implements MovieFrameSource {
  final List<MovieRenderFrameRequest> requests = [];
  final List<double> appliedX = [];
  final int? throwAtOutputIndex;
  bool prepared = false;
  bool disposed = false;
  MovieRenderJob? preparedJob;

  _FakeFrameSource({this.throwAtOutputIndex});

  @override
  bool get rowsAreBottomUp => false;

  @override
  Future<void> prepare(MovieRenderJob job) async {
    prepared = true;
    preparedJob = job;
  }

  @override
  Future<Uint8List> renderFrame(MovieRenderFrameRequest request) async {
    requests.add(request);
    for (final sample in request.samples) {
      final x = sample.values['Location.X'];
      if (x != null && !request.isWarmup) appliedX.add(x);
    }
    if (throwAtOutputIndex != null && request.outputIndex == throwAtOutputIndex) {
      throw StateError('frame source exploded at frame ${request.outputIndex}');
    }
    final job = preparedJob!;
    final pixels = Uint8List(job.width * job.height * 4);
    final shade = (20 + (request.outputIndex.clamp(0, 200)) * 10) % 256;
    for (var i = 0; i < pixels.length; i += 4) {
      pixels[i] = shade;
      pixels[i + 1] = 40;
      pixels[i + 2] = 90;
      pixels[i + 3] = 255;
    }
    return pixels;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

SequencerData _locationSequence({
  int fps = 30,
  int lengthFrames = 120,
  int lastKeyFrame = 60,
  double lastValue = 12.0,
}) {
  return SequencerData(
    fps: fps,
    lengthFrames: lengthFrames,
    tracks: [
      SequencerTrack(
        id: 'track-a',
        actorId: 'actor-a',
        actorName: 'Cube',
        kind: SequencerTrackKind.transform,
        channels: [
          SequencerChannel(name: 'Location.X', keys: [
            SequencerKey(frame: 0, value: 0.0, interpolation: KeyInterpolation.linear),
            SequencerKey(frame: lastKeyFrame, value: lastValue, interpolation: KeyInterpolation.linear),
          ]),
        ],
      ),
    ],
  );
}

void main() {
  late Directory tempRoot;
  late Directory projectDir;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('movie_render_svc_');
    projectDir = Directory('${tempRoot.path}/RenderProject')..createSync(recursive: true);
  });

  tearDown(() {
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  Directory outDir(String name) => Directory('${projectDir.path}/saved/movie_renders/$name');

  group('MovieRenderService', () {
    test('writes exactly one 320x180 PNG per frame plus a manifest', () async {
      final job = MovieRenderJob(
        sequence: _locationSequence(),
        sequenceName: 'SEQ_Test',
        width: 320,
        height: 180,
        fps: 30,
        startFrame: 0,
        endFrame: 9,
        outputDir: outDir('shot_a'),
      );
      final source = _FakeFrameSource();
      const service = MovieRenderService();

      final events = await service.render(job, frameSource: source).toList();

      final files = job.outputDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.png'))
          .map((f) => f.uri.pathSegments.last)
          .toList()
        ..sort();
      expect(files, [
        for (var i = 0; i < 10; i++) 'frame_${i.toString().padLeft(5, '0')}.png',
      ]);

      for (final name in files) {
        final decoded = img.decodePng(File('${job.outputDir.path}/$name').readAsBytesSync());
        expect(decoded, isNotNull, reason: '$name must be a decodable PNG');
        expect(decoded!.width, 320);
        expect(decoded.height, 180);
      }

      final manifest = File('${job.outputDir.path}/render_manifest.json');
      expect(manifest.existsSync(), isTrue);
      final json = jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
      expect(json['frames'], 10);
      expect(json['width'], 320);
      expect(json['height'], 180);
      expect(json['fps'], 30);
      expect(json['sequence'], 'SEQ_Test');
      expect(json['format'], 'png_sequence');
      expect(json['wallTimeMs'], isA<int>());

      expect(events.last.phase, MovieRenderPhase.completed);
      expect(source.disposed, isTrue);
    });

    test('progress stream emits one monotonic event per frame with on-disk byte totals', () async {
      final job = MovieRenderJob(
        sequence: _locationSequence(),
        sequenceName: 'SEQ_Test',
        width: 320,
        height: 180,
        fps: 30,
        startFrame: 0,
        endFrame: 9,
        outputDir: outDir('shot_b'),
      );
      const service = MovieRenderService();
      final events = await service.render(job, frameSource: _FakeFrameSource()).toList();

      final frameEvents = events.where((e) => e.phase == MovieRenderPhase.rendering).toList();
      expect(frameEvents.length, 10);
      for (var i = 0; i < frameEvents.length; i++) {
        expect(frameEvents[i].frame, i);
        expect(frameEvents[i].total, 10);
        if (i > 0) {
          expect(frameEvents[i].frame, greaterThan(frameEvents[i - 1].frame));
          expect(frameEvents[i].bytesWritten, greaterThan(frameEvents[i - 1].bytesWritten));
        }
      }

      final onDisk = job.outputDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.png'))
          .fold<int>(0, (sum, f) => sum + f.lengthSync());
      expect(frameEvents.last.bytesWritten, onDisk);
      expect(events.last.bytesWritten, onDisk);
    });

    test('cancelling from the 4th progress event leaves exactly 4 intact frames', () async {
      final job = MovieRenderJob(
        sequence: _locationSequence(),
        sequenceName: 'SEQ_Test',
        width: 64,
        height: 64,
        fps: 30,
        startFrame: 0,
        endFrame: 19,
        outputDir: outDir('shot_cancel'),
      );
      final source = _FakeFrameSource();
      final token = MovieRenderCancellationToken();
      const service = MovieRenderService();

      final seen = <MovieRenderProgress>[];
      await for (final p in service.render(job, frameSource: source, token: token)) {
        seen.add(p);
        if (p.phase == MovieRenderPhase.rendering && p.frame == 3) token.cancel();
      }

      expect(seen.last.phase, MovieRenderPhase.cancelled);
      final pngs = job.outputDir.listSync().whereType<File>().where((f) => f.path.endsWith('.png')).toList();
      expect(pngs.length, 4);
      for (final f in pngs) {
        final decoded = img.decodePng(f.readAsBytesSync());
        expect(decoded, isNotNull, reason: '${f.path} must not be a partial file');
        expect(decoded!.width, 64);
      }
      expect(File('${job.outputDir.path}/frame_00004.png').existsSync(), isFalse);
      expect(File('${job.outputDir.path}/render_manifest.json').existsSync(), isFalse);
      expect(source.disposed, isTrue, reason: 'GPU resources must be torn down on cancel');
    });

    test('warmup frames are rendered but never written', () async {
      final job = MovieRenderJob(
        sequence: _locationSequence(),
        sequenceName: 'SEQ_Test',
        width: 64,
        height: 64,
        fps: 30,
        startFrame: 0,
        endFrame: 5,
        warmupFrames: 2,
        outputDir: outDir('shot_warmup'),
      );
      final source = _FakeFrameSource();
      const service = MovieRenderService();
      await service.render(job, frameSource: source).toList();

      expect(source.requests.length, 8, reason: '2 warmup + 6 written frames');
      expect(source.requests.where((r) => r.isWarmup).length, 2);
      final names = job.outputDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.png'))
          .map((f) => f.uri.pathSegments.last)
          .toList()
        ..sort();
      expect(names, [
        'frame_00000.png',
        'frame_00001.png',
        'frame_00002.png',
        'frame_00003.png',
        'frame_00004.png',
        'frame_00005.png',
      ]);
    });

    test('a frame-source throw errors the stream, skips the manifest and still tears down', () async {
      final job = MovieRenderJob(
        sequence: _locationSequence(),
        sequenceName: 'SEQ_Test',
        width: 64,
        height: 64,
        fps: 30,
        startFrame: 0,
        endFrame: 9,
        outputDir: outDir('shot_error'),
      );
      final source = _FakeFrameSource(throwAtOutputIndex: 2);
      const service = MovieRenderService();

      Object? error;
      try {
        await service.render(job, frameSource: source).toList();
      } catch (e) {
        error = e;
      }
      expect(error, isA<StateError>());
      final pngs = job.outputDir.listSync().whereType<File>().where((f) => f.path.endsWith('.png')).toList();
      expect(pngs.length, 2);
      expect(File('${job.outputDir.path}/render_manifest.json').existsSync(), isFalse);
      expect(source.disposed, isTrue);
    });

    test('each frame is posed by the evaluator with the fps remap applied', () async {
      // Sequence authored at 60 fps, keys 0 -> 0.0 and 60 -> 12.0 (linear).
      // Rendering 4 frames at 3 fps samples sequence frames 0, 20, 40, 60.
      final job = MovieRenderJob(
        sequence: _locationSequence(fps: 60, lastKeyFrame: 60, lastValue: 12.0),
        sequenceName: 'SEQ_Remap',
        width: 32,
        height: 32,
        fps: 3,
        startFrame: 0,
        endFrame: 3,
        outputDir: outDir('shot_remap'),
      );
      final source = _FakeFrameSource();
      const service = MovieRenderService();
      await service.render(job, frameSource: source).toList();

      expect(source.appliedX, [0.0, 4.0, 8.0, 12.0]);
      expect(
        source.requests.where((r) => !r.isWarmup).map((r) => r.sequenceFrame).toList(),
        [0.0, 20.0, 40.0, 60.0],
      );
    });

    test('samples come from SequencerEvaluator, not a re-implementation', () async {
      final data = _locationSequence(fps: 30, lastKeyFrame: 60, lastValue: 12.0);
      final job = MovieRenderJob(
        sequence: data,
        sequenceName: 'SEQ_Eval',
        width: 32,
        height: 32,
        fps: 30,
        startFrame: 0,
        endFrame: 2,
        outputDir: outDir('shot_eval'),
      );
      final source = _FakeFrameSource();
      await const MovieRenderService().render(job, frameSource: source).toList();

      const evaluator = SequencerEvaluator();
      for (final r in source.requests.where((r) => !r.isWarmup)) {
        final expected = evaluator.evaluate(data, r.sequenceFrame);
        expect(r.samples.length, expected.length);
        expect(r.samples.first.values['Location.X'], expected.first.values['Location.X']);
      }
    });

    test('bottom-up readback rows are flipped before encoding', () async {
      final job = MovieRenderJob(
        sequence: _locationSequence(),
        sequenceName: 'SEQ_Flip',
        width: 2,
        height: 2,
        fps: 30,
        startFrame: 0,
        endFrame: 0,
        outputDir: outDir('shot_flip'),
      );
      final source = _BottomUpSource();
      await const MovieRenderService().render(job, frameSource: source).toList();
      final decoded = img.decodePng(File('${job.outputDir.path}/frame_00000.png').readAsBytesSync())!;
      // The source paints its first buffer row white and declares the buffer
      // bottom-up, so after the flip the PNG top row is black, bottom row white.
      expect(decoded.getPixel(0, 0).r, 0);
      expect(decoded.getPixel(0, 1).r, 255);
    });
  });

  group('MovieRenderJob', () {
    test('resolves the output directory under the project saved/movie_renders tree', () {
      final dir = MovieRenderJob.resolveOutputDir(projectDir.path, 'MyShot');
      expect(dir.path, '${projectDir.path}/saved/movie_renders/MyShot');
    });

    test('default output name carries the sequence name and a timestamp', () {
      final name = MovieRenderJob.defaultOutputName('SEQ_Intro', DateTime(2026, 9, 20, 14, 5, 3));
      expect(name, 'SEQ_Intro_20260920_140503');
    });

    test('totalFrames counts the inclusive frame range', () {
      final job = MovieRenderJob(
        sequence: _locationSequence(),
        sequenceName: 'S',
        width: 16,
        height: 16,
        fps: 30,
        startFrame: 5,
        endFrame: 9,
        outputDir: outDir('x'),
      );
      expect(job.totalFrames, 5);
    });
  });
}

/// Emits a 2x2 buffer whose *first* row (index 0) is black and second row is
/// white, declaring itself bottom-up like a real GL readback.
class _BottomUpSource implements MovieFrameSource {
  @override
  bool get rowsAreBottomUp => true;

  @override
  Future<void> prepare(MovieRenderJob job) async {}

  @override
  Future<Uint8List> renderFrame(MovieRenderFrameRequest request) async {
    final px = Uint8List(2 * 2 * 4);
    for (var x = 0; x < 2; x++) {
      final top = x * 4; // row 0
      px[top] = 255;
      px[top + 1] = 255;
      px[top + 2] = 255;
      px[top + 3] = 255;
      final bottom = (2 + x) * 4; // row 1
      px[bottom + 3] = 255;
    }
    return px;
  }

  @override
  Future<void> dispose() async {}
}
