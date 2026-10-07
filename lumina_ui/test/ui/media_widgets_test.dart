import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/widgets/media/editor_media_widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  group('LuminaVideoPlayerWidget UI tests', () {
    testWidgets('renders video player controls and reacts to interaction', (tester) async {
      final controller = LuminaVideoController.headless(
        duration: const Duration(seconds: 40),
        size: const Size(1920, 1080),
      );
      await controller.initialize();

      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: SizedBox(
              width: 800,
              height: 500,
              child: LuminaVideoPlayerWidget(
                controller: controller,
                autoHideControls: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LuminaVideoPlayerWidget), findsOneWidget);
      expect(find.text('00:00 / 00:40'), findsOneWidget);
      expect(find.byIcon(LucideIcons.play), findsOneWidget);

      // Tap play
      await tester.tap(find.byIcon(LucideIcons.play));
      await tester.pump();
      expect(controller.value.isPlaying, isTrue);
      expect(find.byIcon(LucideIcons.pause), findsOneWidget);

      controller.dispose();
    });
  });

  group('LuminaAudioPlayerWidget UI tests', () {
    testWidgets('renders audio player controls and reacts to interaction', (tester) async {
      final controller = LuminaAudioController.headless(
        duration: const Duration(seconds: 120),
        title: 'Exploration_Theme.mp3',
      );
      await controller.initialize();

      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: SizedBox(
              width: 400,
              height: 200,
              child: LuminaAudioPlayerWidget(
                controller: controller,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LuminaAudioPlayerWidget), findsOneWidget);
      expect(find.text('Exploration_Theme.mp3'), findsOneWidget);
      expect(find.text('00:00 / 02:00'), findsOneWidget);
      expect(find.byIcon(LucideIcons.play), findsOneWidget);

      // Tap play
      await tester.tap(find.byIcon(LucideIcons.play));
      await tester.pump();
      expect(controller.value.isPlaying, isTrue);

      controller.dispose();
    });
  });
}
