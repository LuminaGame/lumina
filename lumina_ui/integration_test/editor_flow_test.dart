import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/views/launcher_view.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'helpers/shared_editor_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Lumina Studio Integration Test Flow', (WidgetTester tester) async {
    final tempConfigDir = Directory.systemTemp.createTempSync('lumina_flow_config_');
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_flow_projects_');

    try {
      useSharedEditor(tempConfigDir);
      final vm = LauncherViewModel(configDir: tempConfigDir);
      await vm.setDefaultProjectsDirectory(tempProjectsDir.path);

      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: LauncherView(viewModel: vm),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      // Verify Launcher initial state
      expect(find.text('Lumina Studio'), findsOneWidget);
      expect(find.text('Recent Projects'), findsWidgets);

      // Tap New Project button
      await tester.tap(find.text('New Project...'));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Create Project inside dialog
      await tester.tap(find.text('Create Project'));
      await tester.pump(const Duration(seconds: 1));

      // Verify transition to MainEditorView
      expect(find.text('WORLD OUTLINER'), findsOneWidget);
    } finally {
      if (tempConfigDir.existsSync()) {
        tempConfigDir.deleteSync(recursive: true);
      }
      if (tempProjectsDir.existsSync()) {
        tempProjectsDir.deleteSync(recursive: true);
      }
    }
  });
}
