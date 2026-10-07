import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_widgets/lumina_widgets.dart';

void main() {
  group('LuminaVideoController headless tests', () {
    late LuminaVideoController controller;

    setUp(() async {
      controller = LuminaVideoController.headless(
        duration: const Duration(seconds: 10),
        size: const Size(1920, 1080),
        volume: 0.8,
      );
      await controller.initialize();
    });

    tearDown(() {
      controller.dispose();
    });

    test('initializes with default headless state', () {
      expect(controller.value.isInitialized, isTrue);
      expect(controller.value.isPlaying, isFalse);
      expect(controller.value.duration, const Duration(seconds: 10));
      expect(controller.value.position, Duration.zero);
      expect(controller.value.volume, 0.8);
      expect(controller.value.aspectRatio, closeTo(16.0 / 9.0, 1e-4));
      expect(controller.isHeadless, isTrue);
    });

    test('play, pause, stop lifecycle', () async {
      await controller.play();
      expect(controller.value.isPlaying, isTrue);

      await controller.pause();
      expect(controller.value.isPlaying, isFalse);

      await controller.seekToSeconds(5.0);
      expect(controller.value.position, const Duration(seconds: 5));

      await controller.stop();
      expect(controller.value.isPlaying, isFalse);
      expect(controller.value.position, Duration.zero);
    });

    test('volume, speed, and looping setters', () async {
      await controller.setVolume(0.4);
      expect(controller.value.volume, 0.4);

      await controller.setPlaybackSpeed(1.5);
      expect(controller.value.playbackSpeed, 1.5);

      await controller.setLooping(true);
      expect(controller.value.isLooping, isTrue);
    });
  });

  group('LuminaVideoPlayer widget tests', () {
    testWidgets('renders fallback preview and controls', (tester) async {
      final controller = LuminaVideoController.headless(
        duration: const Duration(seconds: 20),
        size: const Size(1280, 720),
      );
      await controller.initialize();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LuminaVideoPlayer(
            controller: controller,
            showControls: true,
          ),
        ),
      );

      expect(find.byKey(const Key('lumina_video_fallback_surface')), findsOneWidget);
      expect(find.text('▶'), findsOneWidget);
      expect(find.text('00:00 / 00:20'), findsOneWidget);

      // Tap play
      await tester.tap(find.text('▶'));
      await tester.pump();
      expect(controller.value.isPlaying, isTrue);
      expect(find.text('❚❚'), findsOneWidget);

      controller.dispose();
    });
  });
}
