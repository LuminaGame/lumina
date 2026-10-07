import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_widgets/lumina_widgets.dart';

void main() {
  group('LuminaAudioController headless tests', () {
    late LuminaAudioController controller;

    setUp(() async {
      controller = LuminaAudioController.headless(
        duration: const Duration(seconds: 45),
        title: 'ThemeSong.ogg',
        volume: 0.9,
      );
      await controller.initialize();
    });

    tearDown(() {
      controller.dispose();
    });

    test('initializes with default headless state', () {
      expect(controller.value.isInitialized, isTrue);
      expect(controller.value.isPlaying, isFalse);
      expect(controller.value.duration, const Duration(seconds: 45));
      expect(controller.value.title, 'ThemeSong.ogg');
      expect(controller.value.volume, 0.9);
      expect(controller.isHeadless, isTrue);
    });

    test('playback, seeking and stop', () async {
      await controller.play();
      expect(controller.value.isPlaying, isTrue);

      await controller.seekToSeconds(15.0);
      expect(controller.value.position, const Duration(seconds: 15));

      await controller.pause();
      expect(controller.value.isPlaying, isFalse);

      await controller.stop();
      expect(controller.value.isPlaying, isFalse);
      expect(controller.value.position, Duration.zero);
    });
  });

  group('LuminaAudioPlayer widget tests', () {
    testWidgets('renders audio player bar with title and controls', (tester) async {
      final controller = LuminaAudioController.headless(
        duration: const Duration(seconds: 60),
        title: 'Soundtrack_Boss.wav',
      );
      await controller.initialize();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LuminaAudioPlayer(controller: controller),
        ),
      );

      expect(find.text('Soundtrack_Boss.wav'), findsOneWidget);
      expect(find.text('00:00 / 01:00'), findsOneWidget);
      expect(find.text('Play'), findsOneWidget);

      await tester.tap(find.text('Play'));
      await tester.pump();
      expect(controller.value.isPlaying, isTrue);
      expect(find.text('Pause'), findsOneWidget);

      controller.dispose();
    });
  });
}
