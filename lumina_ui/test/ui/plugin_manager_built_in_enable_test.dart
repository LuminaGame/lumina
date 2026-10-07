import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/data/repositories/project_repository.dart';
import 'package:lumina/data/services/editor_host_generator_service.dart';
import 'package:lumina/data/services/plugin_registry_service.dart';
import 'package:lumina_ui/ui/core/services/user_plugin_dir.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/plugin_manager/view_models/plugin_manager_view_model.dart';
import 'package:lumina_ui/ui/features/plugin_manager/views/plugin_manager_view.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart';

const _sha = 'c200c809d9c6848280b0af01e48938a016eb1f73';
const _pluginsGit = 'https://github.com/LuminaGame/plugins.git';

/// A built-in plugin (one the engine workspace resolved from the plugins
/// repository) is enabled and disabled per project through the Plugin
/// Manager's switch, like any other plugin: `enabled_plugins`, the restart
/// state and the project's editor host all follow it.
void main() {
  late Directory temp;
  late Directory project;
  late PluginRegistryService registry;
  late PluginManagerViewModel viewModel;

  setUp(() async {
    final sourceRoot = LuminaWorkspace.root;
    temp = Directory.systemTemp.createTempSync('lm_builtin_enable_');
    project = Directory(p.join(temp.path, 'BuiltInGame'))..createSync();
    UserPluginDir.override = Directory(p.join(temp.path, 'user_plugins'))..createSync();

    // A release checkout after `pub get`: the built-ins are git checkouts in
    // the pub cache, pinned by its pubspec.lock.
    final checkout = Directory(p.join(temp.path, 'engine', '0.0.1'))..createSync(recursive: true);
    final cache = Directory(p.join(temp.path, 'pub_cache', 'git', 'plugins-$_sha'));
    final packages = <Map<String, String>>[];
    final lock = StringBuffer('packages:\n');
    for (final (name, friendly) in [('lumina_plugin_pcg', 'Procedural Content Generation'), ('lumina_plugin_miniai', 'MiniAI')]) {
      final dir = Directory(p.join(cache.path, name))..createSync(recursive: true);
      File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('name: $name\nversion: 0.1.0\n');
      File(p.join(dir.path, '$name.lmplugin')).writeAsStringSync(jsonEncode({
        'name': name,
        'friendly_name': friendly,
        'version': '0.1.0',
        'category': 'Built-in test',
        'modules': [
          {'name': name, 'type': 'editor', 'entry_library': 'lib/$name.dart', 'registration_class': 'P'},
        ],
      }));
      packages.add({'name': name, 'rootUri': Uri.directory(dir.path).toString(), 'packageUri': 'lib/'});
      lock.write('''
  $name:
    dependency: "direct dev"
    description:
      path: $name
      ref: $_sha
      resolved-ref: "$_sha"
      url: "$_pluginsGit"
    source: git
    version: "0.1.0"
''');
    }
    File(p.join(checkout.path, '.dart_tool', 'package_config.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({'configVersion': 2, 'packages': packages}));
    File(p.join(checkout.path, 'pubspec.lock')).writeAsStringSync(lock.toString());
    LuminaWorkspace.useCheckout(checkout.path, commit: 'abc', repo: kLuminaGitUrl);

    const lmProject = LuminaProject(
      projectName: 'BuiltInGame',
      activeLevel: 'contents/levels/L_Main.lmas',
      settings: EngineScalabilitySettings(targetFps: 60),
    );
    File(p.join(project.path, 'BuiltInGame.lmproject')).writeAsStringSync(jsonEncode(lmProject.toMap()));

    registry = PluginRegistryService(
      repo: PluginRepository(roots: editorPluginScanRoots(project.path)),
      projectRepo: ProjectRepository(),
      // The host is generated from this source workspace's lumina_ui; the
      // built-ins' git pins come from the release checkout's lock.
      hostGenerator: EditorHostGeneratorService(engineRoot: sourceRoot, workspaceRoot: checkout.path),
    );
    await registry.initialize(project.path);
    viewModel = PluginManagerViewModel(registryService: registry);
  });

  tearDown(() {
    viewModel.dispose();
    UserPluginDir.override = null;
    LuminaWorkspace.clearCheckout();
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows can hold a handle for a moment.
    }
  });

  List<String>? enabledOnDisk() {
    final map = jsonDecode(File(p.join(project.path, 'BuiltInGame.lmproject')).readAsStringSync()) as Map<String, dynamic>;
    return (map['enabled_plugins'] as List?)?.cast<String>();
  }

  Finder switchOf(String friendlyName) => find.descendant(
        of: find.ancestor(of: find.text(friendlyName), matching: find.byType(Card)),
        matching: find.byType(Switch),
      );

  // The switch's handler does real file I/O (the .lmproject, the editor
  // host), so it is tapped on the real event loop.
  Future<void> tapAndWait(WidgetTester tester, Finder target, bool Function() done) async {
    await tester.runAsync(() => tester.tap(target));
    for (var i = 0; i < 200 && !done(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await tester.pump();
  }

  testWidgets('a built-in plugin is enabled and disabled for the project from its switch', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    expect({for (final e in registry.entries) e.descriptor.name: e.descriptor.origin},
        {'lumina_plugin_pcg': PluginOrigin.engine, 'lumina_plugin_miniai': PluginOrigin.engine});

    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: PluginManagerView(viewModel: viewModel))));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(switchOf('Procedural Content Generation')).value, isFalse);

    // Enable the built-in PCG.
    final hostPubspec = File(p.join(EditorHostGeneratorService.hostDirOf(project.path), 'pubspec.yaml'));
    await tapAndWait(tester, switchOf('Procedural Content Generation'), () => find.text('Restart required').evaluate().isNotEmpty);

    expect(find.text('Built-in Plugin'), findsNothing, reason: 'a built-in is not refused');
    expect(tester.widget<Switch>(switchOf('Procedural Content Generation')).value, isTrue);
    expect(enabledOnDisk(), ['lumina_plugin_pcg']);
    expect(find.text('Restart required'), findsOneWidget, reason: 'a code plugin waits for the project editor rebuild');
    expect(find.text('2 plugins · 1 enabled'), findsOneWidget);
    // The project editor depends on the built-in at the revision the engine pinned.
    final host = hostPubspec.readAsStringSync();
    expect(host, contains('  lumina_plugin_pcg:\n    git:\n'));
    expect(host, contains("url: '$_pluginsGit'"));
    expect(host, contains("ref: '$_sha'"));
    expect(host, isNot(contains('lumina_plugin_miniai')));

    // Disable it again.
    await tapAndWait(tester, switchOf('Procedural Content Generation'), () => !tester.widget<Switch>(switchOf('Procedural Content Generation')).value);
    expect(find.text('Built-in Plugin'), findsNothing);
    expect(tester.widget<Switch>(switchOf('Procedural Content Generation')).value, isFalse);
    expect(enabledOnDisk(), isEmpty);
    expect(hostPubspec.readAsStringSync(), isNot(contains('lumina_plugin_pcg')));
  });

  testWidgets('the details pane says a built-in is enabled per project and cannot be removed', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: PluginManagerView(viewModel: viewModel))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MiniAI'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plugin_built_in_note')), findsOneWidget);
  });
}
