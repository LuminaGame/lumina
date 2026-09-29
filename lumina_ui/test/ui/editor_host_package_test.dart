@Tags(['slow'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/data/services/workspace_paths.dart';
import 'package:path/path.dart' as p;

import '../helpers/editor_host_fixture.dart';

/// lumina_ui works as a dependency, not only as the app. A
/// generated project editor host runs a widget test of its own that renders
/// the launcher: lumina_ui's `assets/…` resolve as `packages/lumina_ui/…`
/// through the editor's asset bundle, and its fonts register unqualified.
void main() {
  test('the launcher renders from a generated host package with lumina_ui assets and fonts', () async {
    final flutter = Platform.isWindows ? 'flutter.bat' : 'flutter';
    try {
      Process.runSync(flutter, ['--version'], runInShell: Platform.isWindows);
    } on ProcessException {
      markTestSkipped('flutter is not on PATH');
      return;
    }
    final fx = EditorHostFixture.create();
    addTearDown(fx.dispose);
    final plugin = await PluginRepository(roots: []).loadInternal(File(p.join(fx.pluginDir.path, 'a_plugin.lmplugin')), PluginOrigin.project);
    await EditorHostGeneratorService(engineRoot: LuminaWorkspace.root).generate(fx.projectDir.path, [plugin]);
    // The host builds from the project's source copy (links here).
    await fx.vendorHost();

    // The host's own test: flutter_test as a dev dependency of the host.
    File(p.join(fx.hostDir, 'pubspec.yaml')).writeAsStringSync('''
${File(p.join(fx.hostDir, 'pubspec.yaml')).readAsStringSync()}
dev_dependencies:
  flutter_test:
    sdk: flutter
''');
    Directory(p.join(fx.hostDir, 'test')).createSync();
    File(p.join(fx.hostDir, 'test', 'launcher_from_host_test.dart')).writeAsStringSync(r'''
// ignore_for_file: depend_on_referenced_packages
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/editor_entry.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/views/launcher_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('launcher from the host', (tester) async {
    await tester.runAsync(EditorAssets.configure);
    expect(EditorAssets.packaged, isTrue, reason: 'lumina_ui assets are bundled as packages/lumina_ui/…');
    final logo = await tester.runAsync(() => EditorAssets.bundle.load('assets/logo_color.png'));
    expect(logo!.lengthInBytes, greaterThan(1000));
    final mono = await tester.runAsync(() => EditorAssets.bundle.load('assets/fonts/JetBrainsMono-Regular.ttf'));
    expect(mono!.lengthInBytes, greaterThan(1000));

    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    final config = Directory.systemTemp.createTempSync('host_launcher_cfg_');
    late LauncherViewModel vm;
    await tester.runAsync(() async => vm = LauncherViewModel(configDir: config));
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: DefaultAssetBundle(bundle: EditorAssets.bundle, child: LauncherView(viewModel: vm)),
    ));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(find.byType(LauncherView), findsOneWidget);
    // The header logo loaded: its error fallback (a box icon) is not shown.
    expect(find.byWidgetPredicate((w) => w is Icon && w.icon == LucideIcons.box), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
''');
    var get = await Process.run(flutter, ['pub', 'get', '--offline'], workingDirectory: fx.hostDir, runInShell: Platform.isWindows);
    if (get.exitCode != 0) get = await Process.run(flutter, ['pub', 'get'], workingDirectory: fx.hostDir, runInShell: Platform.isWindows);
    expect(get.exitCode, 0, reason: '${get.stdout}\n${get.stderr}');
    final run = await Process.run(flutter, ['test', 'test/launcher_from_host_test.dart'], workingDirectory: fx.hostDir, runInShell: Platform.isWindows);
    expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
    expect('${run.stdout}', contains('All tests passed'));
  }, timeout: const Timeout(Duration(minutes: 20)));
}
