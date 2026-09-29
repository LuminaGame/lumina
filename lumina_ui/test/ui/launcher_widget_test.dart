import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/views/launcher_view.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  late Directory tempConfigDir;

  setUp(() {
    tempConfigDir = Directory.systemTemp.createTempSync('lumina_launcher_widget_');
  });

  tearDown(() {
    if (tempConfigDir.existsSync()) tempConfigDir.deleteSync(recursive: true);
  });

  testWidgets('LauncherView renders the logo header, recent projects and the new-project action',
      (WidgetTester tester) async {
    final vm = LauncherViewModel(configDir: tempConfigDir);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: LauncherView(viewModel: vm)));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsWidgets, reason: 'logo header');
    expect(find.text(vm.engineDisplayVersion), findsWidgets);
    expect(find.text('Recent Projects'), findsWidgets);
    expect(find.text('New Project...'), findsOneWidget);
  });
}
