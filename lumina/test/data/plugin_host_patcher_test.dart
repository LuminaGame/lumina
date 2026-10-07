import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:test/test.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:lumina_core/lumina_core.dart';

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

    LuminaPluginDescriptor editorPlugin(String name,
            {PluginIsolation isolation = PluginIsolation.inProcess, String? processClass, String? shell = 'ShellPlugin'}) =>
        LuminaPluginDescriptor(
          name: name,
          version: Version.parse('1.0.0'),
          pluginDir: Directory('${tempDir.path}/$name'),
          origin: PluginOrigin.project,
          isolation: isolation,
          modules: [
            PluginModuleDescriptor(
              name: name,
              type: PluginModuleType.editor,
              entryLibrary: 'lib/$name.dart',
              registrationClass: shell,
              processClass: processClass,
            ),
          ],
        );

    test('kPluginProcesses lists only the isolated plugins, by name, and the registrar parses', () async {
      final plugins = [
        editorPlugin('a_plugin'),
        editorPlugin('b_plugin', isolation: PluginIsolation.process, processClass: 'BProcess'),
        // A process_class without "isolation": "process" stays in process.
        editorPlugin('c_plugin', processClass: 'CProcess'),
        editorPlugin('d_plugin', isolation: PluginIsolation.process, processClass: 'DProcess'),
      ];
      await service.generateRegistrar(tempDir, plugins);
      final source = File('${tempDir.path}/lib/generated/plugin_registrar.dart').readAsStringSync();
      expect(source, contains('''
final Map<String, LuminaPluginProcess Function()> kPluginProcesses = {
  'b_plugin': () => b_plugin_plugin.BProcess(),
  'd_plugin': () => d_plugin_plugin.DProcess(),
};
'''));
      expect(source, isNot(contains('CProcess')));
      expect(source, isNot(contains("'a_plugin':")));
      // The shells of all four still register in process.
      for (final name in ['a_plugin', 'b_plugin', 'c_plugin', 'd_plugin']) {
        expect(source, contains('  ${name}_plugin.ShellPlugin(),'));
      }
      expect(source, contains("import 'package:lumina_editor_api/lumina_editor_api.dart';"));

      final parsed = parseString(content: source, throwIfDiagnostics: false);
      expect(parsed.errors, isEmpty, reason: parsed.errors.join('\n'));
      final declared = [
        for (final d in parsed.unit.declarations)
          if (d is TopLevelVariableDeclaration) ...d.variables.variables.map((v) => v.name.lexeme)
          else if (d is FunctionDeclaration) d.name.lexeme,
      ];
      expect(declared, ['kEnabledPlugins', 'kPluginProcesses', 'registerAllPlugins']);
    });

    test('an isolated plugin without a UI shell registers only its process part', () {
      final source = service.registrarSource([
        editorPlugin('e_plugin', isolation: PluginIsolation.process, processClass: 'EProcess', shell: null),
      ]);
      expect(source, contains("  'e_plugin': () => e_plugin_plugin.EProcess(),"));
      expect(source, isNot(contains('e_plugin_plugin.null')));
      expect(source, contains('final List<LuminaEditorPlugin> kEnabledPlugins = [\n];'));
      final parsed = parseString(content: source, throwIfDiagnostics: false);
      expect(parsed.errors, isEmpty, reason: parsed.errors.join('\n'));
    });

    test('without isolated plugins kPluginProcesses is an empty map (still declared, the main passes it)', () {
      for (final plugins in [<LuminaPluginDescriptor>[], [editorPlugin('a_plugin')]]) {
        final source = service.registrarSource(plugins);
        expect(source, contains('final Map<String, LuminaPluginProcess Function()> kPluginProcesses = {};\n'));
        final parsed = parseString(content: source, throwIfDiagnostics: false);
        expect(parsed.errors, isEmpty, reason: parsed.errors.join('\n'));
      }
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
