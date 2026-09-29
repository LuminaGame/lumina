import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/features/main_editor/views/restart_required_banner.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  testWidgets('RestartRequiredBanner displays text and buttons', (tester) async {
    bool dismissed = false;
    var restarts = 0;
    
    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        title: 'Test',
        home: Scaffold(
          child: RestartRequiredBanner(
            onDismiss: () => dismissed = true,
            onRestart: () => restarts++,
          ),
        ),
      ),
    );

    expect(find.text("Plugin changes require rebuilding this project's editor"), findsOneWidget);
    expect(find.text('Restart Editor'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);

    await tester.tap(find.text('Later'));
    expect(dismissed, isTrue);
    await tester.tap(find.text('Restart Editor'));
    expect(restarts, 1);
  });
}
