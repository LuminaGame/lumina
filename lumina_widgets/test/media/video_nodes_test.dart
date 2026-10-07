import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_widgets/lumina_widgets.dart';

/// The Blueprint video nodes open a [LuminaVideoController] once
/// [LuminaWidgets.ensureInitialized] registered it as the engine's player.
void main() {
  setUpAll(LuminaWidgets.ensureInitialized);

  test('without a registered player, Open Video opens nothing', () {
    final factory = LuminaVideoPlayback.factory;
    LuminaVideoPlayback.factory = null;
    addTearDown(() => LuminaVideoPlayback.factory = factory);
    expect(LuminaBlueprintFunctionLibrary.openVideo(LuminaActor(), 'test_video.mp4', false, false, 1.0), isNull);
  });

  test('Blueprint Video nodes: open, play, pause, seek, volume, rate, loop, query', () async {
    final actor = LuminaActor();

    // 1. Direct function library call verification
    final controller = LuminaBlueprintFunctionLibrary.openVideo(
      actor,
      'test_video.mp4',
      false,
      true,
      0.75,
    );
    expect(controller, isA<LuminaVideoController>());
    final v = controller as LuminaVideoController;
    await v.initialize();

    expect(LuminaBlueprintFunctionLibrary.isVideoPlaying(actor, v), isFalse);
    expect(LuminaBlueprintFunctionLibrary.getVideoPosition(actor, v), 0.0);
    expect(LuminaBlueprintFunctionLibrary.getVideoDuration(actor, v), greaterThanOrEqualTo(0.0));

    LuminaBlueprintFunctionLibrary.playVideo(actor, v);
    expect(LuminaBlueprintFunctionLibrary.isVideoPlaying(actor, v), isTrue);

    LuminaBlueprintFunctionLibrary.pauseVideo(actor, v);
    expect(LuminaBlueprintFunctionLibrary.isVideoPlaying(actor, v), isFalse);

    LuminaBlueprintFunctionLibrary.seekVideo(actor, v, 3.5);
    expect(LuminaBlueprintFunctionLibrary.getVideoPosition(actor, v), closeTo(3.5, 0.1));

    LuminaBlueprintFunctionLibrary.setVideoVolume(actor, v, 0.5);
    expect(v.value.volume, 0.5);

    LuminaBlueprintFunctionLibrary.setVideoRate(actor, v, 2.0);
    expect(v.value.playbackSpeed, 2.0);

    LuminaBlueprintFunctionLibrary.setVideoLooping(actor, v, false);
    expect(v.value.isLooping, isFalse);

    LuminaBlueprintFunctionLibrary.stopVideo(actor, v);
    expect(LuminaBlueprintFunctionLibrary.isVideoPlaying(actor, v), isFalse);
    expect(LuminaBlueprintFunctionLibrary.getVideoPosition(actor, v), 0.0);

    v.dispose();
  });

  test('Blueprint VM built-in functions execute video nodes by id', () async {
    final actor = LuminaActor();
    final ctx = LuminaBlueprintCallContext(actor);

    // Call open_video via VM functions map
    final openFn = LuminaBlueprintFunctionLibrary.functions['open_video'];
    expect(openFn, isNotNull);
    final openRes = openFn!(ctx, {
      'source': 'sample.mp4',
      'auto_play': false,
      'loop': false,
      'volume': 0.8,
    });
    final v = openRes['return_value'] as LuminaVideoController;
    await v.initialize();

    // Call play_video
    final playFn = LuminaBlueprintFunctionLibrary.functions['play_video']!;
    playFn(ctx, {'target': v});
    expect(v.value.isPlaying, isTrue);

    // Call is_video_playing
    final isPlayingFn = LuminaBlueprintFunctionLibrary.functions['is_video_playing']!;
    final isPlayingRes = isPlayingFn(ctx, {'target': v});
    expect(isPlayingRes['return_value'], isTrue);

    // Call seek_video
    final seekFn = LuminaBlueprintFunctionLibrary.functions['seek_video']!;
    seekFn(ctx, {'target': v, 'seconds': 2.0});
    expect(v.value.position.inSeconds, 2);

    // Call get_video_position
    final getPosFn = LuminaBlueprintFunctionLibrary.functions['get_video_position']!;
    final posRes = getPosFn(ctx, {'target': v});
    expect(posRes['return_value'], 2.0);

    // Call pause_video
    final pauseFn = LuminaBlueprintFunctionLibrary.functions['pause_video']!;
    pauseFn(ctx, {'target': v});
    expect(v.value.isPlaying, isFalse);

    v.dispose();
  });
}
