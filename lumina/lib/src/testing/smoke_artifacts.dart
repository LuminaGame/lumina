import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/filament.dart';
import 'package:lumina_smoke/lumina_smoke.dart' as smoke;

import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/src/testing/smoke_render.dart';

/// The smoke-test artifact API of lumina's tests: lumina_smoke's
/// `SmokeArtifacts` (every member forwards to it, so both share one state:
/// the artifact directory, the recorded assets) plus
/// [renderRealAssetMedia], which films real test assets with Filament.
abstract final class SmokeArtifacts {
  /// See [SmokeRender.renderRealAssetMedia].
  static Future<void> renderRealAssetMedia({
    required String testTitle,
    required List<String> usedAssets,
    double durationSeconds = 10.0,
    int width = smoke.SmokeVideo.defaultWidth,
    int height = smoke.SmokeVideo.defaultHeight,
    int fps = smoke.SmokeVideo.minimumFps,
    SmokeRenderFrame? onFrame,
    SmokeRenderSetup? onSetup,
    FutureOr<void> Function()? onTeardown,
    FilamentEngine? engine,
    bool autoDisposeEngine = true,
    double sceneUnitsPerMetre = LuminaUnits.unitsPerMetre,
    double? near,
    double? far,
  }) =>
      SmokeRender.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: durationSeconds,
        width: width,
        height: height,
        fps: fps,
        onFrame: onFrame,
        onSetup: onSetup,
        onTeardown: onTeardown,
        engine: engine,
        autoDisposeEngine: autoDisposeEngine,
        sceneUnitsPerMetre: sceneUnitsPerMetre,
        near: near,
        far: far,
      );

  // ---------------------------------------------------------------------------
  // lumina_smoke's SmokeArtifacts, member for member
  // ---------------------------------------------------------------------------

  static String? get outputDirOverride => smoke.SmokeArtifacts.outputDirOverride;
  static set outputDirOverride(String? value) => smoke.SmokeArtifacts.outputDirOverride = value;
  static String? get testAssetsDirOverride => smoke.SmokeArtifacts.testAssetsDirOverride;
  static set testAssetsDirOverride(String? value) => smoke.SmokeArtifacts.testAssetsDirOverride = value;
  static void overrideDirForTesting(Directory? d) => smoke.SmokeArtifacts.overrideDirForTesting(d);
  static Directory get packageRoot => smoke.SmokeArtifacts.packageRoot;
  static Directory get dir => smoke.SmokeArtifacts.dir;
  static Directory get testAssetsDir => smoke.SmokeArtifacts.testAssetsDir;
  static String sanitizeTestName(String testName) => smoke.SmokeArtifacts.sanitizeTestName(testName);

  static void recordAsset(String path) => smoke.SmokeArtifacts.recordAsset(path);
  static List<String> get recordedAssets => smoke.SmokeArtifacts.recordedAssets;
  static void resetRecordedAssets() => smoke.SmokeArtifacts.resetRecordedAssets();

  static const double minimumVideoSeconds = smoke.SmokeArtifacts.minimumVideoSeconds;
  static const double maximumFrameHoldSeconds = smoke.SmokeArtifacts.maximumFrameHoldSeconds;
  static const double minimumVideoFps = smoke.SmokeArtifacts.minimumVideoFps;
  static const int minimumVideoWidth = smoke.SmokeArtifacts.minimumVideoWidth;
  static const int minimumVideoHeight = smoke.SmokeArtifacts.minimumVideoHeight;
  static double framesDurationSeconds(int frameCount, double fps) =>
      smoke.SmokeArtifacts.framesDurationSeconds(frameCount, fps);
  static int framesForSeconds(double fps, {double seconds = minimumVideoSeconds}) =>
      smoke.SmokeArtifacts.framesForSeconds(fps, seconds: seconds);
  static void checkVideoDuration(String testName, int frameCount, double fps) =>
      smoke.SmokeArtifacts.checkVideoDuration(testName, frameCount, fps);
  static void checkVideoFps(String testName, double fps) => smoke.SmokeArtifacts.checkVideoFps(testName, fps);
  static void checkVideoSize(String testName, int width, int height) =>
      smoke.SmokeArtifacts.checkVideoSize(testName, width, height);
  static void checkFramesMove(String testName, List<Uint8List> pngFrames, double fps) =>
      smoke.SmokeArtifacts.checkFramesMove(testName, pngFrames, fps);

  static Uint8List encodePng(int w, int h, Uint8List rgba, {bool flipY = false, bool bgra = false}) =>
      smoke.SmokeArtifacts.encodePng(w, h, rgba, flipY: flipY, bgra: bgra);
  static Uint8List encodeRgbaToPng(Uint8List rawPixels, int width, int height, {bool flipY = false, bool bgra = false}) =>
      smoke.SmokeArtifacts.encodeRgbaToPng(rawPixels, width, height, flipY: flipY, bgra: bgra);
  static (int, int)? pngSize(Uint8List png) => smoke.SmokeArtifacts.pngSize(png);

  static const List<String> vp8QualitySettings = smoke.SmokeArtifacts.vp8QualitySettings;
  static const List<String> ffmpegVp8QualitySettings = smoke.SmokeArtifacts.ffmpegVp8QualitySettings;
  static bool get videoEncoderAvailable => smoke.SmokeArtifacts.videoEncoderAvailable;
  static bool get gstreamerEncoderAvailable => smoke.SmokeArtifacts.gstreamerEncoderAvailable;
  static String? get ffmpegPath => smoke.SmokeArtifacts.ffmpegPath;
  static String? get ffprobePath => smoke.SmokeArtifacts.ffprobePath;
  static Uint8List encodeWebmFromPngFrames(List<Uint8List> pngFrames, {double fps = minimumVideoFps}) =>
      smoke.SmokeArtifacts.encodeWebmFromPngFrames(pngFrames, fps: fps);
  static ProcessResult encodeRawRgbaToWebm({
    required String rawFrames,
    required String out,
    required int width,
    required int height,
    required int rateNumerator,
    required int rateDenominator,
  }) =>
      smoke.SmokeArtifacts.encodeRawRgbaToWebm(
        rawFrames: rawFrames,
        out: out,
        width: width,
        height: height,
        rateNumerator: rateNumerator,
        rateDenominator: rateDenominator,
      );
  static Uint8List encodeWebmFromRawFile(
    File rawFrames, {
    required int width,
    required int height,
    required int frameDurationMs,
    int? framesPerSecond,
  }) =>
      smoke.SmokeArtifacts.encodeWebmFromRawFile(rawFrames,
          width: width, height: height, frameDurationMs: frameDurationMs, framesPerSecond: framesPerSecond);
  static Uint8List encodeWebmFromRgbaFrames({
    required int width,
    required int height,
    required List<Uint8List> frames,
    int fps = smoke.SmokeVideo.minimumFps,
    int? frameDurationMs,
    String? testName,
  }) =>
      smoke.SmokeArtifacts.encodeWebmFromRgbaFrames(
          width: width, height: height, frames: frames, fps: fps, frameDurationMs: frameDurationMs, testName: testName);

  static ({double? seconds, int? width, int? height, double? fps})? probeVideo(String path) =>
      smoke.SmokeArtifacts.probeVideo(path);
  static double? probeVideoSeconds(String path) => smoke.SmokeArtifacts.probeVideoSeconds(path);
  static double? videoDurationSeconds(File video) => smoke.SmokeArtifacts.videoDurationSeconds(video);
  static double? videoFramesPerSecond(File video) => smoke.SmokeArtifacts.videoFramesPerSecond(video);
  static (int, int)? videoFrameSize(File video) => smoke.SmokeArtifacts.videoFrameSize(video);

  static File saveScreenshot(String testName, Uint8List pngBytes, {List<String>? usedAssets, Map<String, Object?>? metrics}) =>
      smoke.SmokeArtifacts.saveScreenshot(testName, pngBytes, usedAssets: usedAssets, metrics: metrics);
  static File saveScreenshotToDir(
    String testName,
    Uint8List pngBytes,
    Directory targetDir, {
    List<String>? usedAssets,
    Map<String, Object?>? metrics,
  }) =>
      smoke.SmokeArtifacts.saveScreenshotToDir(testName, pngBytes, targetDir, usedAssets: usedAssets, metrics: metrics);
  static File saveVideoFromPngFrames(String testName, List<Uint8List> pngFrames,
          {double fps = minimumVideoFps, List<String>? usedAssets}) =>
      smoke.SmokeArtifacts.saveVideoFromPngFrames(testName, pngFrames, fps: fps, usedAssets: usedAssets);
  static File saveVideo(
    String testName,
    Uint8List videoBytes, {
    String extension = 'webm',
    List<String>? usedAssets,
    int? frameCount,
    double? fps,
    double? durationSeconds,
    int? width,
    int? height,
  }) =>
      smoke.SmokeArtifacts.saveVideo(testName, videoBytes,
          extension: extension,
          usedAssets: usedAssets,
          frameCount: frameCount,
          fps: fps,
          durationSeconds: durationSeconds,
          width: width,
          height: height);
  static File saveEncodedVideo(
    String testName,
    Uint8List videoBytes, {
    String extension = 'webm',
    List<String>? usedAssets,
    int? frameCount,
    double? fps,
    double? durationSeconds,
    int? width,
    int? height,
  }) =>
      smoke.SmokeArtifacts.saveEncodedVideo(testName, videoBytes,
          extension: extension,
          usedAssets: usedAssets,
          frameCount: frameCount,
          fps: fps,
          durationSeconds: durationSeconds,
          width: width,
          height: height);
  static File saveVideoToDir(
    String testName,
    Uint8List videoBytes,
    Directory targetDir, {
    String extension = 'webm',
    List<String>? usedAssets,
    int? frameCount,
    double? fps,
    double? durationSeconds,
    int? width,
    int? height,
  }) =>
      smoke.SmokeArtifacts.saveVideoToDir(testName, videoBytes, targetDir,
          extension: extension,
          usedAssets: usedAssets,
          frameCount: frameCount,
          fps: fps,
          durationSeconds: durationSeconds,
          width: width,
          height: height);
  static void annotate(String testName, Map<String, Object?> fields, {Directory? targetDir}) =>
      smoke.SmokeArtifacts.annotate(testName, fields, targetDir: targetDir);
  static void clear() => smoke.SmokeArtifacts.clear();
  static void clearDir(Directory targetDir) => smoke.SmokeArtifacts.clearDir(targetDir);
}
