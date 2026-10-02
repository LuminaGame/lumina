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

  testWidgets('LauncherView with initialProjectDir starts on loading screen, then falls back to project list when project cannot open',
      (WidgetTester tester) async {
    final vm = LauncherViewModel(configDir: tempConfigDir);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: LauncherView(viewModel: vm, initialProjectDir: '/nonexistent/dummy_project'),
    ));

    // First frame must show loading screen, NOT the project list
    expect(find.byKey(const Key('initial_project_loading_status')), findsOneWidget);
    expect(find.text('Recent Projects'), findsNothing, reason: 'project list should not appear while loading');

    // After resolution finishes (project does not exist), falls back to project list
    await tester.pumpAndSettle();
    expect(find.text('Recent Projects'), findsWidgets, reason: 'fallback to project list on failure');
    expect(find.textContaining('Could not find a project'), findsOneWidget);
  });

  testWidgets('LauncherView loading screen can be cancelled to immediately show project list',
      (WidgetTester tester) async {
    final vm = LauncherViewModel(configDir: tempConfigDir);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: LauncherView(viewModel: vm, initialProjectDir: '/nonexistent/dummy_project'),
    ));

    expect(find.byKey(const Key('initial_project_loading_status')), findsOneWidget);
    expect(find.text('Cancel to Projects'), findsOneWidget);

    await tester.tap(find.text('Cancel to Projects'));
    await tester.pump();

    expect(find.text('Recent Projects'), findsWidgets);
  });
}
