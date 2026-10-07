import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:lumina/lumina.dart';

import 'package:lumina_ui/ui/features/sub_editors/services/sequencer_evaluator.dart';

/// The one output format this stack can honestly produce.
///
/// The design doc promises `4K MP4` and `16-bit OpenEXR`; neither has a
/// pure-Dart encoder here and shelling out to ffmpeg would be an undeclared
/// dependency, so the queue writes a numbered PNG sequence. A future encoder
/// consumes the very same per-frame RGBA stream.
enum MovieRenderFormat {
  pngSequence('png_sequence', 'PNG Sequence');

  final String id;
  final String label;
  const MovieRenderFormat(this.id, this.label);
}

/// Lifecycle phase carried by every [MovieRenderProgress] event.
enum MovieRenderPhase { warmup, rendering, completed, cancelled }

/// Cooperative cancellation: the render loop checks it *between* frames so a
/// readback is never torn down half-way and no partial PNG reaches disk.
class MovieRenderCancellationToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// Everything one offscreen render run needs.
class MovieRenderJob {
  final SequencerData sequence;
  final String sequenceName;
  final int width;
  final int height;

  /// Sampling rate of the render. Sequence keys stay authored in sequence
  /// frames; see [sequenceFrameFor].
  final int fps;

  /// Inclusive render-frame range.
  final int startFrame;
  final int endFrame;

  /// Frames evaluated and drawn but never written — the doc's "ısınma karesi",
  /// used to let streaming/temporal effects settle before frame 0.
  final int warmupFrames;
  final Directory outputDir;
  final MovieRenderFormat format;

  MovieRenderJob({
    required this.sequence,
    required this.sequenceName,
    required this.width,
    required this.height,
    required this.fps,
    required this.startFrame,
    required this.endFrame,
    this.warmupFrames = 0,
    required this.outputDir,
    this.format = MovieRenderFormat.pngSequence,
  });

  int get totalFrames => endFrame - startFrame + 1;

  /// Maps a render frame onto the (fractional) sequence frame to evaluate.
  /// Rounding happens nowhere: `renderFrame * (seqFps / renderFps)`.
  double sequenceFrameFor(int renderFrame) {
    final seqFps = sequence.fps > 0 ? sequence.fps : 30;
    final outFps = fps > 0 ? fps : seqFps;
    return renderFrame * (seqFps / outFps);
  }

  /// `<project>/saved/movie_renders/<name>/` — project data, not an asset, so
  /// no `.lmas` wrapper and safe to git-ignore.
  static Directory resolveOutputDir(String projectDirPath, String outputName) =>
      Directory('$projectDirPath/saved/movie_renders/$outputName');

  static String defaultOutputName(String sequenceName, [DateTime? now]) {
    final t = now ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${sequenceName}_${t.year}${two(t.month)}${two(t.day)}_'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }

  Map<String, dynamic> toManifestJson() => {
        'sequence': sequenceName,
        'format': format.id,
        'width': width,
        'height': height,
        'fps': fps,
        'sequenceFps': sequence.fps,
        'startFrame': startFrame,
        'endFrame': endFrame,
        'warmupFrames': warmupFrames,
      };
}

/// One request handed to a [MovieFrameSource].
class MovieRenderFrameRequest {
  /// Zero-based index of the file this frame becomes; `-1` for warmup frames.
  final int outputIndex;

  /// The render-space frame (`startFrame + i`).
  final int renderFrame;

  /// The fractional sequence frame the samples were evaluated at.
  final double sequenceFrame;
  final List<TrackSample> samples;
  final bool isWarmup;
  final int width;
  final int height;

  const MovieRenderFrameRequest({
    required this.outputIndex,
    required this.renderFrame,
    required this.sequenceFrame,
    required this.samples,
    required this.isWarmup,
    required this.width,
    required this.height,
  });
}

/// Produces one RGBA8 frame buffer per request.
///
/// The GPU implementation ([SequencerOffscreenFrameSource]) owns the offscreen
/// view + RenderTarget; tests inject a CPU fake so the loop, the numbering and
/// the IO are provable without a GPU.
abstract class MovieFrameSource {
  /// True when row 0 of the returned buffer is the *bottom* of the image, as
  /// a GL-backend `readPixels` hands it back. The service flips before
  /// encoding so exports are never upside down.
  bool get rowsAreBottomUp;

  Future<void> prepare(MovieRenderJob job);

  Future<Uint8List> renderFrame(MovieRenderFrameRequest request);

  Future<void> dispose();
}

/// A progress tick. Carries files and counters, never pixel buffers — a 4K
/// readback is ~33 MB and must not travel through the stream.
class MovieRenderProgress {
  final MovieRenderPhase phase;

  /// Zero-based index of the frame just written (`-1` for warmup/terminal).
  final int frame;
  final int total;
  final int bytesWritten;
  final File? file;
  final Duration elapsed;

  const MovieRenderProgress({
    required this.phase,
    required this.frame,
    required this.total,
    required this.bytesWritten,
    required this.elapsed,
    this.file,
  });

  int get framesDone => frame + 1;

  double get fraction => total <= 0 ? 0.0 : (framesDone / total).clamp(0.0, 1.0);

  /// Linear estimate from the frames already written; null until one is done.
  Duration? get eta {
    if (framesDone <= 0 || framesDone >= total) return null;
    final perFrame = elapsed.inMicroseconds / framesDone;
    return Duration(microseconds: (perFrame * (total - framesDone)).round());
  }

  String? get fileName => file?.uri.pathSegments.last;

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

/// Walks a [SequencerData] frame by frame and writes a numbered PNG sequence.
///
/// One frame per event-loop turn (`Future.delayed(Duration.zero)` between
/// frames) so the editor keeps painting and the progress UI stays live; the
/// offscreen draw therefore never lands inside the viewport's
/// beginFrame/endFrame.
class MovieRenderService {
  final SequencerEvaluator evaluator;

  const MovieRenderService({this.evaluator = const SequencerEvaluator()});

  Stream<MovieRenderProgress> render(
    MovieRenderJob job, {
    required MovieFrameSource frameSource,
    MovieRenderCancellationToken? token,
  }) async* {
    final stopwatch = Stopwatch()..start();
    final total = job.totalFrames;
    var bytesWritten = 0;
    var written = 0;
    var cancelled = false;

    await job.outputDir.create(recursive: true);
    try {
      await frameSource.prepare(job);

      // Warmup: evaluated + drawn at the first frame's pose, never written.
      for (var w = 0; w < job.warmupFrames; w++) {
        if (token?.isCancelled ?? false) {
          cancelled = true;
          break;
        }
        final seqFrame = job.sequenceFrameFor(job.startFrame);
        await frameSource.renderFrame(MovieRenderFrameRequest(
          outputIndex: -1,
          renderFrame: job.startFrame,
          sequenceFrame: seqFrame,
          samples: evaluator.evaluate(job.sequence, seqFrame),
          isWarmup: true,
          width: job.width,
          height: job.height,
        ));
        await Future<void>.delayed(Duration.zero);
      }

      if (!cancelled) {
        for (var i = 0; i < total; i++) {
          if (token?.isCancelled ?? false) {
            cancelled = true;
            break;
          }
          final renderFrame = job.startFrame + i;
          final seqFrame = job.sequenceFrameFor(renderFrame);
          final rgba = await frameSource.renderFrame(MovieRenderFrameRequest(
            outputIndex: i,
            renderFrame: renderFrame,
            sequenceFrame: seqFrame,
            samples: evaluator.evaluate(job.sequence, seqFrame),
            isWarmup: false,
            width: job.width,
            height: job.height,
          ));

          final oriented = frameSource.rowsAreBottomUp
              ? flipRows(rgba, job.width, job.height)
              : rgba;
          final png = TgaDecoderService.encodePng(oriented, job.width, job.height);
          final file = File('${job.outputDir.path}/frame_${i.toString().padLeft(5, '0')}.png');
          await file.writeAsBytes(png, flush: true);
          bytesWritten += png.length;
          written++;

          yield MovieRenderProgress(
            phase: MovieRenderPhase.rendering,
            frame: i,
            total: total,
            bytesWritten: bytesWritten,
            file: file,
            elapsed: stopwatch.elapsed,
          );
          // Give the editor a turn before the next offscreen draw.
          await Future<void>.delayed(Duration.zero);
        }
      }

      if (cancelled || (token?.isCancelled ?? false)) {
        yield MovieRenderProgress(
          phase: MovieRenderPhase.cancelled,
          frame: written - 1,
          total: total,
          bytesWritten: bytesWritten,
          elapsed: stopwatch.elapsed,
        );
        return;
      }

      final manifest = File('${job.outputDir.path}/render_manifest.json');
      await manifest.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          ...job.toManifestJson(),
          'frames': written,
          'bytesWritten': bytesWritten,
          'wallTimeMs': stopwatch.elapsedMilliseconds,
          'renderedAt': DateTime.now().toIso8601String(),
        }),
        flush: true,
      );

      yield MovieRenderProgress(
        phase: MovieRenderPhase.completed,
        frame: written - 1,
        total: total,
        bytesWritten: bytesWritten,
        elapsed: stopwatch.elapsed,
      );
    } finally {
      stopwatch.stop();
      await frameSource.dispose();
    }
  }

  /// Bottom-up RGBA8 -> top-down RGBA8.
  static Uint8List flipRows(Uint8List rgba, int width, int height) {
    final stride = width * 4;
    final out = Uint8List(stride * height);
    for (var row = 0; row < height; row++) {
      final src = (height - 1 - row) * stride;
      out.setRange(row * stride, row * stride + stride, rgba, src);
    }
    return out;
  }
}
