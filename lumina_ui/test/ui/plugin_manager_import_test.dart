import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/plugin_manager/services/plugin_importer.dart';
import 'package:lumina_ui/ui/features/plugin_manager/view_models/plugin_manager_view_model.dart';
import 'package:lumina_ui/ui/features/plugin_manager/views/plugin_manager_view.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart';

Map<String, String> _plugin(String name, String version) => {
      '$name.lmplugin': jsonEncode({
        'name': name,
        'friendly_name': 'Imported Widgets',
        'version': version,
        'description': 'Imported through the Plugin Manager',
        'category': 'Testing',
        'license': 'MIT',
        'modules': [
          {'name': name, 'type': 'editor', 'entry_library': 'lib/$name.dart', 'registration_class': 'P'},
        ],
      }),
      'pubspec.yaml': 'name: $name\nversion: $version\n',
      'lib/$name.dart': '// $version\nclass P {}\n',
      'CHANGELOG.md': '## $version\n\n- Release.\n',
    };

/// The Plugin Manager's Import from Folder / Import from Zip, end to end
/// through its buttons, with the pickers pointed at real files.
void main() {
  late Directory temp;
  late Directory userDir;
  late Directory projectDir;
  late PluginRegistryService registry;
  late PluginManagerViewModel vm;
  late int rescans;
  String? pickedFolder;
  String? pickedZip;

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('lm_pm_import_');
    userDir = Directory(p.join(temp.path, 'user'))..createSync();
    projectDir = Directory(p.join(temp.path, 'project'))..createSync();
    Directory(p.join(projectDir.path, 'plugins')).createSync();
    File(p.join(projectDir.path, 'project.lmproject')).writeAsStringSync(jsonEncode({'project_name': 'project', 'engine_version': '0.0.1'}));
    registry = PluginRegistryService(
      repo: PluginRepository(roots: [
        PluginScanRoot(dir: Directory(p.join(projectDir.path, 'plugins')), origin: PluginOrigin.project),
        PluginScanRoot(dir: userDir, origin: PluginOrigin.user),
      ]),
      projectRepo: ProjectRepository(),
    );
    await registry.initialize(projectDir.path);
    rescans = 0;
    vm = PluginManagerViewModel(
      registryService: registry,
      onPluginsChanged: () async {
        rescans++;
        await registry.refresh();
      },
      folderPicker: () async => pickedFolder,
      zipPicker: () async => pickedZip,
      importerFactory: (existing) => PluginImporter(
        userPluginDir: userDir,
        stagingRoot: Directory(p.join(temp.path, 'staging'))..createSync(recursive: true),
        existing: existing,
      ),
    );
  });

  tearDown(() {
    vm.dispose();
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows can hold a handle for a moment; the temp dir is left behind.
    }
  });

  Future<void> pumpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: PluginManagerView(viewModel: vm))));
    await tester.pumpAndSettle();
  }

  Future<void> tapAndWait(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  String installedVersion() => File(p.join(userDir.path, 'imported_widgets', 'lib', 'imported_widgets.dart')).readAsStringSync();

  testWidgets('New Plugin, Import from Folder and Import from Zip sit together in the list header', (tester) async {
    await pumpView(tester);
    // One group of actions: New Plugin and both imports share their row.
    final row = find.ancestor(of: find.byKey(const ValueKey('plugin_new')), matching: find.byType(Wrap));
    expect(row, findsOneWidget);
    for (final key in ['plugin_import_folder', 'plugin_import_zip']) {
      expect(find.descendant(of: row, matching: find.byKey(ValueKey(key))), findsOneWidget);
    }
    expect(find.text('Import from Folder'), findsOneWidget);
    expect(find.text('Import from Zip'), findsOneWidget);
  });

  testWidgets('a zip imports, then a folder of the same plugin asks Replace / Cancel', (tester) async {
    final zipFile = File(p.join(temp.path, 'imported_widgets-1.0.0.zip'));
    final archive = Archive();
    for (final MapEntry(key: rel, value: text) in _plugin('imported_widgets', '1.0.0').entries) {
      archive.addFile(ArchiveFile.bytes('imported_widgets/$rel', utf8.encode(text)));
    }
    zipFile.writeAsBytesSync(ZipEncoder().encode(archive));
    final folder = Directory(p.join(temp.path, 'src', 'imported_widgets'))..createSync(recursive: true);
    for (final MapEntry(key: rel, value: text) in _plugin('imported_widgets', '2.0.0').entries) {
      File(p.join(folder.path, rel))
        ..createSync(recursive: true)
        ..writeAsStringSync(text);
    }
    pickedZip = zipFile.path;
    pickedFolder = folder.path;
    await pumpView(tester);
    expect(find.text('Imported Widgets'), findsNothing);

    // Zip: installed, listed as a user plugin and selected.
    await tapAndWait(tester, find.byKey(const ValueKey('plugin_import_zip')));
    expect(find.byKey(const ValueKey('plugin_import_done_dialog')), findsOneWidget);
    await tapAndWait(tester, find.byKey(const ValueKey('plugin_import_ok')));
    expect(rescans, 1);
    expect(installedVersion(), contains('1.0.0'));
    expect(find.text('Imported Widgets'), findsWidgets);
    expect(find.text('USER'), findsWidgets);
    expect(vm.selectedEntry?.descriptor.name, 'imported_widgets');

    // Folder of the same plugin: Cancel keeps the installed copy.
    await tapAndWait(tester, find.byKey(const ValueKey('plugin_import_folder')));
    expect(find.byKey(const ValueKey('plugin_import_replace_dialog')), findsOneWidget);
    await tapAndWait(tester, find.byKey(const ValueKey('plugin_import_cancel')));
    expect(find.byKey(const ValueKey('plugin_import_replace_dialog')), findsNothing);
    expect(installedVersion(), contains('1.0.0'));
    expect(rescans, 1);

    // Again, Replace: the folder's version is installed.
    await tapAndWait(tester, find.byKey(const ValueKey('plugin_import_folder')));
    await tapAndWait(tester, find.byKey(const ValueKey('plugin_import_replace')));
    expect(find.byKey(const ValueKey('plugin_import_done_dialog')), findsOneWidget);
    await tapAndWait(tester, find.byKey(const ValueKey('plugin_import_ok')));
    expect(installedVersion(), contains('2.0.0'));
    expect(rescans, 2);
    expect(find.text('2.0.0'), findsWidgets);
  });

  testWidgets('an invalid zip shows the problems and installs nothing', (tester) async {
    final zipFile = File(p.join(temp.path, 'evil.zip'));
    final archive = Archive()
      ..addFile(ArchiveFile.bytes('../evil.txt', utf8.encode('evil')))
      ..addFile(ArchiveFile.bytes('imported_widgets.lmplugin', utf8.encode(_plugin('imported_widgets', '1.0.0')['imported_widgets.lmplugin']!)));
    zipFile.writeAsBytesSync(ZipEncoder().encode(archive));
    pickedZip = zipFile.path;
    await pumpView(tester);

    await tapAndWait(tester, find.byKey(const ValueKey('plugin_import_zip')));

    expect(find.byKey(const ValueKey('plugin_import_error')), findsOneWidget);
    expect(find.textContaining('../evil.txt'), findsOneWidget);
    expect(userDir.listSync(), isEmpty);
    expect(rescans, 0);
    await tapAndWait(tester, find.byKey(const ValueKey('plugin_import_error_ok')));
    expect(find.byKey(const ValueKey('plugin_import_error')), findsNothing);
  });

  testWidgets('a cancelled picker imports nothing', (tester) async {
    pickedFolder = null;
    await pumpView(tester);
    await tapAndWait(tester, find.byKey(const ValueKey('plugin_import_folder')));
    expect(find.byKey(const ValueKey('plugin_import_error')), findsNothing);
    expect(find.byKey(const ValueKey('plugin_import_done_dialog')), findsNothing);
    expect(userDir.listSync(), isEmpty);
  });
}
