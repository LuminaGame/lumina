import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show EditorSourceVendorService;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_preferences.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/project_editor_builds_preferences_page.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Editor Preferences › General › Project Editor Builds ›
/// "Open every project in its own project editor" (default on).
void main() {
  late Directory config;
  setUp(() => config = Directory.systemTemp.createTempSync('lumina_prefs_page_'));
  tearDown(() => config.deleteSync(recursive: true));

  testWidgets('the switch shows the preference and toggles it (saved at once)', (tester) async {
    final prefs = EditorPreferences.load(configDir: config);
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: ProjectEditorBuildsPreferencesPage(preferences: prefs)),
    ));
    await tester.pumpAndSettle();

    final toggle = find.byKey(const ValueKey('editor_prefs_per_project_editors'));
    expect(toggle, findsOneWidget);
    expect(find.text('Open every project in its own project editor'), findsOneWidget);
    expect(tester.widget<Switch>(toggle).value, isTrue);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(prefs.perProjectEditors, isFalse);
    expect(tester.widget<Switch>(toggle).value, isFalse);
    expect(EditorPreferences.load(configDir: config).perProjectEditors, isFalse);
  });

  // The project's copy of the engine source, and Sync.
  group('editor source', () {
    late Directory temp;
    late String engine;
    late String projectDir;
    late String host;

    void write(String rel, String content) {
      final f = File('$engine/$rel');
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(content);
    }

    setUp(() {
      temp = Directory.systemTemp.createTempSync('lumina_prefs_source_');
      engine = '${temp.path}/engine';
      write('lumina_ui/pubspec.yaml', 'name: lumina_ui\ndependencies:\n  lumina:\n    path: ../lumina\n');
      write('lumina_ui/lib/ui.dart', '// ui\n');
      write('lumina/pubspec.yaml', 'name: lumina\n');
      write('lumina/lib/lumina.dart', '// engine\n');
      write('filament/include/x.h', '// filament\n');
      projectDir = '${temp.path}/Game';
      host = '$projectDir/.lumina/editor';
      Directory(host).createSync(recursive: true);
    });
    tearDown(() => temp.deleteSync(recursive: true));

    Future<void> pumpPage(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: ProjectEditorBuildsPreferencesPage(
            preferences: EditorPreferences.load(configDir: config),
            projectDir: projectDir,
            engineRoot: engine,
          ),
        ),
      ));
      await settle(tester);
    }

    String text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(ValueKey(key))).data!;

    testWidgets('shows where the copy is, whether the engine changed since, and syncs after a confirmation', (tester) async {
      await tester.runAsync(() => EditorSourceVendorService(engineRoot: engine).vendor(host));
      await pumpPage(tester);
      expect(text(tester, 'editor_prefs_editor_source_path'), contains('.lumina'));
      expect(text(tester, 'editor_prefs_editor_source_status'), contains('2 packages'));
      expect(text(tester, 'editor_prefs_editor_source_engine'), 'Up to date with the engine');

      File('$host/lumina_ui/lib/ui.dart').writeAsStringSync('// edited in the project\n');
      write('lumina/lib/lumina.dart', '// engine v2\n');
      await tester.tap(find.byKey(const ValueKey('editor_prefs_refresh_editor_source')));
      await settle(tester);
      expect(text(tester, 'editor_prefs_editor_source_engine'), 'Engine changed since the copy: lumina');

      // Cancel changes nothing.
      await tester.tap(find.byKey(const ValueKey('editor_prefs_sync_editor_source')));
      await tester.pumpAndSettle();
      expect(find.textContaining('replaces every file under'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('editor_prefs_sync_cancel')));
      await tester.pumpAndSettle();
      expect(File('$host/lumina_ui/lib/ui.dart').readAsStringSync(), '// edited in the project\n');

      // Sync replaces the copy with the engine's source.
      await tester.tap(find.byKey(const ValueKey('editor_prefs_sync_editor_source')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('editor_prefs_sync_confirm')));
      await settle(tester);
      expect(File('$host/lumina_ui/lib/ui.dart').readAsStringSync(), '// ui\n');
      expect(File('$host/lumina/lib/lumina.dart').readAsStringSync(), '// engine v2\n');
      expect(text(tester, 'editor_prefs_editor_source_engine'), 'Up to date with the engine');
      expect(find.textContaining('The next open rebuilds'), findsOneWidget);
    });

    testWidgets('a project without a copy says the next open makes it', (tester) async {
      await pumpPage(tester);
      expect(text(tester, 'editor_prefs_editor_source_status'), contains('Not copied yet'));
    });

    testWidgets('outside a project (the launcher) there is no editor source section', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: ProjectEditorBuildsPreferencesPage(preferences: EditorPreferences.load(configDir: config))),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('editor_prefs_editor_source_status')), findsNothing);
    });
  });
}

/// Lets the page's real disk IO (copy, hashing) finish, then pumps.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump();
  }
}
