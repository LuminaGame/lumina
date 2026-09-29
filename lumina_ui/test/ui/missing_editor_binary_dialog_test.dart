import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/data/services/workspace_paths.dart';
import 'package:lumina_ui/ui/core/services/user_plugin_dir.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/launcher/services/project_editor_resolver.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/views/launcher_view.dart';
import 'package:lumina_ui/ui/features/launcher/views/missing_editor_binary_dialog.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/editor_host_fixture.dart';
import '../helpers/temp_project.dart';

/// "Editor binary not found" for a project with code plugins
/// whose editor was never built on this machine.
void main() {
  Future<void> settle(WidgetTester tester, {int frames = 12}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('lists the plugins and the reason and answers with each of its three buttons', (tester) async {
    MissingBinaryChoice? answer;
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Builder(
        builder: (context) => PrimaryButton(
          onPressed: () async => answer = await MissingEditorBinaryDialog.show(context,
              projectName: 'HostGame', pluginNames: const ['a_plugin', 'lumina_plugin_pcg'], reason: 'No editor host on this machine'),
          child: const Text('Open'),
        ),
      ),
    ));
    for (final (label, expected) in [
      ('Build & Open', MissingBinaryChoice.buildAndOpen),
      ('Open without plugins', MissingBinaryChoice.openWithoutPlugins),
      ('Cancel', MissingBinaryChoice.cancel),
    ]) {
      await tester.tap(find.text('Open'));
      await settle(tester);
      expect(find.text('Editor binary not found'), findsOneWidget);
      expect(
          find.text('HostGame uses code plugins (a_plugin, lumina_plugin_pcg). The editor for this project has not been built on '
              'this machine. Build it now?'),
          findsOneWidget);
      expect(find.text('No editor host on this machine'), findsOneWidget);
      expect(find.widgetWithText(PrimaryButton, 'Build & Open'), findsOneWidget);
      expect(find.widgetWithText(OutlineButton, 'Open without plugins'), findsOneWidget);
      expect(find.widgetWithText(GhostButton, 'Cancel'), findsOneWidget);
      await tester.tap(find.text(label));
      await settle(tester);
      expect(answer, expected, reason: label);
      expect(find.text('Editor binary not found'), findsNothing);
    }
  });

  testWidgets('Open without plugins from the launcher opens the project with a toast naming the inactive plugins', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final fx = EditorHostFixture.create();
    final config = Directory(p.join(fx.temp.path, 'config'))..createSync();
    UserPluginDir.override = Directory(p.join(fx.temp.path, 'user_plugins'))..createSync();
    addTearDown(() async {
      UserPluginDir.override = null;
      await deleteTempProject(fx.temp);
    });

    final resolver = ProjectEditorResolver(
      engineRoot: LuminaWorkspace.root,
      cache: EditorBuildCache(root: Directory(p.join(fx.temp.path, 'cache'))),
      flutterInfo: fixedFlutterInfo,
    );
    late LauncherViewModel launcher;
    await tester.runAsync(() async => launcher = LauncherViewModel(configDir: config, editorResolver: resolver));
    EditorViewModel? editor;
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: LauncherView(
        viewModel: launcher,
        initialProjectDir: fx.projectDir.path,
        editorBuilder: (project, location, warning) => MainEditorView(
          viewModel: editor = EditorViewModel(initialProject: project, projectLocation: location, enableTimers: false, autoInitAssets: false),
          startupWarning: warning,
        ),
      ),
    ));
    for (var i = 0; i < 60 && find.byType(MissingEditorBinaryDialog).evaluate().isEmpty; i++) {
      await drainRealIo(tester, rounds: 2);
    }
    expect(find.text('Editor binary not found'), findsOneWidget);
    expect(find.textContaining('HostGame uses code plugins (a_plugin)'), findsOneWidget);

    await tester.tap(find.text('Open without plugins'));
    await settle(tester, frames: 30);
    expect(find.byType(MainEditorView), findsOneWidget);
    expect(editor, isNotNull);
    final toast = tester.widget<Text>(find.byKey(const Key('startup_warning_toast')));
    expect(toast.data, contains('a_plugin'));
    expect(editor!.logger.logs.any((e) => e.level == 'warning' && e.message.contains('a_plugin')), isTrue);
    // The toast times out after 8 s.
    await tester.pump(const Duration(seconds: 9));
    await settle(tester);
    editor!.dispose();
    await drainRealIo(tester);
  });

  test('the dialog and the splash use no Material widgets', () {
    for (final f in ['missing_editor_binary_dialog.dart', 'editor_build_splash.dart']) {
      final src = File(p.join(LuminaWorkspace.package('lumina_ui'), 'lib', 'ui', 'features', 'launcher', 'views', f)).readAsStringSync();
      expect(src, isNot(contains('package:flutter/material.dart')), reason: f);
    }
  });
}
