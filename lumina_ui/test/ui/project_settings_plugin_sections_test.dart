import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/ui/core/plugin_extension_registry.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/project_settings_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/project_settings_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A plugin with one Project Settings page: a "Level" select and an
/// "Enabled" switch stored in `plugin_settings.settings_plugin`.
class _SettingsPlugin extends LuminaEditorPlugin {
  _SettingsPlugin({this.withSection = true});

  final bool withSection;
  ValueListenable<Map<String, Object?>>? applied;

  @override
  String get pluginName => 'settings_plugin';

  @override
  void register(LuminaEditorContext context) {
    applied = context.pluginSettings;
    if (!withSection) return;
    context.registerProjectSettingsSection(ProjectSettingsSection(
      id: 'main',
      title: 'Settings Plugin',
      keywords: const ['approval', 'budget'],
      builder: (context, settings) => ListenableBuilder(
        listenable: settings.changes,
        builder: (context, _) => Row(children: [
          const Text('Enabled'),
          Switch(
            key: const ValueKey('settings_plugin_enabled'),
            value: settings.get<bool>('enabled') ?? false,
            onChanged: (v) => settings.set('enabled', v),
          ),
        ]),
      ),
    ));
  }
}

/// Plugin pages in Project Settings, on a real temp project.
void main() {
  late Directory tempDir;
  late Directory projDir;
  late File manifest;

  Map<String, dynamic> readManifest() => jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_plugin_settings_');
    projDir = Directory('${tempDir.path}/plugin_game')..createSync(recursive: true);
    manifest = File('${projDir.path}/plugin_game.lmproject')
      ..writeAsStringSync(jsonEncode({
        ...const LuminaProject(projectName: 'plugin_game', activeLevel: 'contents/levels/L_Main.lmas').toMap(),
        'future_feature': {'a': 1},
      }));
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('the registry lists sections, drops them on re-registration, and publishes per plugin', () {
    final registry = PluginExtensionRegistry(logger: EngineLoggerService());
    final plugin = _SettingsPlugin();
    registry.registerPlugin(plugin);
    expect(registry.projectSettingsSections.map((e) => (e.$1, e.$2.id)), [('settings_plugin', 'main')]);

    final other = PluginExtensionRegistry(logger: EngineLoggerService());
    final plain = _SettingsPlugin(withSection: false);
    other.registerPlugin(_SettingsPlugin());
    other.registerPlugin(plain);
    expect(other.projectSettingsSections, isEmpty, reason: 're-registration replaces the sections');

    var fired = 0;
    plugin.applied!.addListener(() => fired++);
    registry.publishPluginSettings({
      'settings_plugin': {'enabled': true},
      'someone_else': {'x': 1},
    });
    expect(plugin.applied!.value, {'enabled': true});
    registry.publishPluginSettings({
      'settings_plugin': {'enabled': true},
      'someone_else': {'x': 2},
    });
    expect(fired, 1, reason: 'another plugin\'s change does not notify');
  });

  testWidgets('PLUGINS ▸ page: edit marks dirty, Apply writes plugin_settings, Revert restores, search finds it', (tester) async {
    final registry = PluginExtensionRegistry(logger: EngineLoggerService());
    registry.registerPlugin(_SettingsPlugin());
    final vm = ProjectSettingsViewModel(projectDirPath: projDir.path)..pluginSections = registry.projectSettingsSections;
    await tester.runAsync(() => vm.load());
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: SizedBox(width: 1200, height: 800, child: ProjectSettingsSubEditor(assetName: 'Project Settings', viewModel: vm)),
      ),
    ));
    await tester.pump();

    final category = ProjectSettingsViewModel.pluginCategoryId('settings_plugin', 'main');
    expect(find.byKey(const ValueKey('project_settings_nav_plugins_header')), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('project_settings_nav_$category')));
    await tester.pump();
    expect(find.text('SETTINGS PLUGIN'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings_plugin_enabled')));
    await tester.pump();
    expect(vm.isDirty, isTrue);
    expect(readManifest().containsKey('plugin_settings'), isFalse, reason: 'nothing written before Apply');

    expect(await tester.runAsync(() => vm.apply()), isTrue);
    final saved = readManifest();
    expect(saved['plugin_settings'], {
      'settings_plugin': {'enabled': true},
    });
    expect(saved['future_feature'], {'a': 1}, reason: 'unknown keys survive the save');

    await tester.tap(find.byKey(const ValueKey('settings_plugin_enabled')));
    await tester.pump();
    expect(vm.pluginSettingsOf('settings_plugin'), {'enabled': false});
    await tester.runAsync(() => vm.revert());
    await tester.pump();
    expect(vm.pluginSettingsOf('settings_plugin'), {'enabled': true});

    vm.setFilterQuery('approval');
    await tester.pump();
    expect(vm.visibleCategories, [category]);
    expect(() => vm.setPluginSetting('settings_plugin', 'apiKey', 'sk-1'), throwsArgumentError);
  });
}
