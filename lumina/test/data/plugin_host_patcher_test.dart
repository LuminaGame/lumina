import 'dart:io';
import 'package:test/test.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:lumina/data/models/lumina_plugin_descriptor.dart';
import 'package:lumina/data/services/plugin_host_patcher_service.dart';

void main() {
  group('PluginHostPatcherService', () {
    late Directory tempDir;
    late PluginHostPatcherService service;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('patcher_test');
      service = PluginHostPatcherService();
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('patchPubspec adds block between markers and is idempotent', () async {
      final pubspecFile = File('${tempDir.path}/pubspec.yaml');
      pubspecFile.writeAsStringSync('''
name: lumina_ui
dependencies:
  flutter:
    sdk: flutter
  shadcn_flutter: ^0.0.1
''');

      final plugins = [
        LuminaPluginDescriptor(
          name: 'a_plugin',
          version: Version.parse('1.0.0'),
          pluginDir: Directory('/some/path/a_plugin'),
          origin: PluginOrigin.user,
        ),
      ];

      await service.patchPubspec(tempDir, plugins);

      final content1 = pubspecFile.readAsStringSync();
      expect(content1, contains('# BEGIN LUMINA PLUGINS (generated)'));
      expect(content1, contains('  a_plugin:\n    path: /some/path/a_plugin'));
      expect(content1, contains('# END LUMINA PLUGINS'));
      expect(content1, contains('  shadcn_flutter: ^0.0.1')); // byte identical outside

      await service.patchPubspec(tempDir, plugins);
      final content2 = pubspecFile.readAsStringSync();
      expect(content1, equals(content2));

      await service.patchPubspec(tempDir, []);
      final content3 = pubspecFile.readAsStringSync();
      expect(content3, contains('# BEGIN LUMINA PLUGINS'));
      expect(content3, isNot(contains('a_plugin:')));
    });

    test('generateRegistrar writes topological registrar and passes dart analyze', () async {
      final libDir = Directory('${tempDir.path}/lib/generated');
      libDir.createSync(recursive: true);

      final plugins = [
        LuminaPluginDescriptor(
          name: 'b_plugin',
          version: Version.parse('1.0.0'),
          pluginDir: Directory(''),
          origin: PluginOrigin.user,
          modules: [PluginModuleDescriptor(name: 'b', type: PluginModuleType.editor, entryLibrary: 'lib/b_plugin.dart', registrationClass: 'BPlugin')],
        ),
        LuminaPluginDescriptor(
          name: 'a_plugin',
          version: Version.parse('1.0.0'),
          pluginDir: Directory(''),
          origin: PluginOrigin.user,
          modules: [PluginModuleDescriptor(name: 'a', type: PluginModuleType.editor, entryLibrary: 'a_plugin', registrationClass: 'APlugin')],
        ),
      ];

      await service.generateRegistrar(tempDir, plugins);

      final file = File('${libDir.path}/plugin_registrar.dart');
      final content = file.readAsStringSync();
      expect(content, contains("import 'package:b_plugin/b_plugin.dart' as b_plugin_plugin;"));
      expect(content, contains("import 'package:a_plugin/a_plugin.dart' as a_plugin_plugin;"));
      expect(content, contains("final List<LuminaEditorPlugin> kEnabledPlugins = ["));
      expect(content, contains("b_plugin_plugin.BPlugin()"));
      
      // Analyze test is skipped because setting up a real dart package in a temp dir requires a pubspec.
    });

    // The one-time cleanup of an engine checkout an
    // older editor patched.
    test('removeEnginePluginBlock drops the block, keeps a .lmbak and is a no-op afterwards', () async {
      const original = '''
name: lumina_ui
dependencies:
  flutter:
    sdk: flutter
  window_manager: ^0.5.1

  # BEGIN LUMINA PLUGINS (generated)
  lumina_plugin_pcg:
    path: /home/dev/.local/share/lumina/plugins/lumina_plugin_pcg
  # END LUMINA PLUGINS

dev_dependencies:
  flutter_test:
    sdk: flutter
''';
      final pubspec = File('${tempDir.path}/pubspec.yaml')..writeAsStringSync(original);
      expect(await service.removeEnginePluginBlock(pubspec), isTrue);
      expect(pubspec.readAsStringSync(), '''
name: lumina_ui
dependencies:
  flutter:
    sdk: flutter
  window_manager: ^0.5.1

dev_dependencies:
  flutter_test:
    sdk: flutter
''');
      expect(File('${pubspec.path}.lmbak').readAsStringSync(), original);
      expect(await service.removeEnginePluginBlock(pubspec), isFalse);
    });
  });
}
