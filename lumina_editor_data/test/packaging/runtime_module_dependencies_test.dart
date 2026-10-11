import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_editor_data/src/packaging/runtime_module_dependencies.dart';
import 'package:yaml/yaml.dart';

/// A plugin folder on disk with a runtime module, like the OpenXR plugin.
Future<LuminaPluginDescriptor> _plugin(Directory root, String name, {Map<String, String> localOverrides = const {}}) async {
  final dir = Directory('${root.path}/$name')..createSync(recursive: true);
  File('${dir.path}/pubspec.yaml').writeAsStringSync('name: $name\nversion: 0.1.0\nenvironment:\n  sdk: ^3.12.0\n');
  File('${dir.path}/lib/runtime.dart')
    ..createSync(recursive: true)
    ..writeAsStringSync('class Runtime { static void register(Map<String, Object?> s) {} }\n');
  if (localOverrides.isNotEmpty) {
    File('${dir.path}/pubspec_overrides.yaml').writeAsStringSync(
        'dependency_overrides:\n${[for (final e in localOverrides.entries) '  ${e.key}:\n    path: ${e.value}\n'].join()}');
  }
  final manifest = File('${dir.path}/$name.lmplugin')
    ..writeAsStringSync(jsonEncode({
      'name': name,
      'version': '0.1.0',
      'modules': [
        {'name': '${name}_editor', 'type': 'editor', 'entry_library': 'lib/$name.dart', 'registration_class': 'EditorPart'},
        {'name': '${name}_runtime', 'type': 'runtime', 'entry_library': 'lib/runtime.dart', 'registration_class': 'Runtime'},
      ],
    }));
  return PluginRepository(roots: const []).load(manifest);
}

void main() {
  late Directory temp;
  late Directory project;
  setUp(() {
    temp = Directory.systemTemp.createTempSync('runtime_modules_');
    project = Directory('${temp.path}/game')..createSync();
    File('${project.path}/pubspec.yaml').writeAsStringSync('name: game\n'
        'environment:\n  sdk: ^3.12.0\n\n'
        'dependencies:\n  flutter:\n    sdk: flutter\n  lumina:\n    git:\n      url: https://github.com/LuminaGame/lumina.git\n      path: lumina\n\n'
        'flutter:\n  uses-material-design: true\n');
  });
  tearDown(() => temp.deleteSync(recursive: true));

  test('an enabled plugin\'s runtime module becomes a game dependency; disabling it removes it', () async {
    final helper = Directory('${temp.path}/plugins/helper_pkg')..createSync(recursive: true);
    final openxr = await _plugin(Directory('${temp.path}/plugins'), 'lumina_plugin_openxr', localOverrides: {'helper_pkg': '../helper_pkg'});
    final deps = await RuntimeModuleDependencies.resolve([openxr]);
    expect(deps.single.library, 'package:lumina_plugin_openxr/runtime.dart');
    expect(deps.single.closure.keys, ['helper_pkg']);

    expect(await RuntimeModuleDependencies.apply(project.path, deps, settings: const {'xr': 'quest', 'refresh_rate': 72}), isTrue);
    final pubspec = File('${project.path}/pubspec.yaml').readAsStringSync();
    final begin = pubspec.indexOf(RuntimeModuleDependencies.pubspecBegin);
    final end = pubspec.indexOf(RuntimeModuleDependencies.pubspecEnd);
    expect(begin, greaterThan(0));
    expect(pubspec.substring(begin, end), contains('lumina_plugin_openxr:'));
    final yaml = loadYaml(pubspec) as YamlMap;
    expect((yaml['dependencies'] as YamlMap).containsKey('lumina_plugin_openxr'), isTrue);
    expect((yaml['dependencies'] as YamlMap).containsKey('lumina'), isTrue);

    // The plugin's local closure is pinned in the gitignored overrides.
    final overrides = loadYaml(File('${project.path}/pubspec_overrides.yaml').readAsStringSync()) as YamlMap;
    expect((overrides['dependency_overrides'] as YamlMap)['helper_pkg']['path'], helper.absolute.path.replaceAll(r'\', '/'));

    // main() registers it with the project's settings.
    final registration = File('${project.path}/${RuntimeModuleDependencies.registrationFile}').readAsStringSync();
    expect(registration, contains("import 'package:lumina_plugin_openxr/runtime.dart' as lumina_plugin_openxr;"));
    expect(registration, contains('lumina_plugin_openxr.Runtime.register(kPluginRuntimeSettings);'));
    expect(registration, contains("'refresh_rate': 72"));

    // A package the engine link already pins is not pinned twice.
    final engine = File('${project.path}/pubspec_overrides.yaml');
    engine.writeAsStringSync("dependency_overrides:\n  helper_pkg:\n    path: 'D:/engine/helper_pkg'\n${ProjectEngineLink.pluginOverridesBlock(engine.readAsStringSync())}");
    await RuntimeModuleDependencies.apply(project.path, deps, settings: const {'xr': 'quest', 'refresh_rate': 72});
    expect(loadYaml(engine.readAsStringSync()), isA<YamlMap>(), reason: 'no duplicate key');
    expect(ProjectEngineLink.pluginOverridesBlock(engine.readAsStringSync()), isEmpty);

    // Applying again changes nothing.
    expect(await RuntimeModuleDependencies.apply(project.path, deps, settings: const {'xr': 'quest', 'refresh_rate': 72}), isFalse);

    // Disabled: the dependency, the pins and the registration are gone.
    expect(await RuntimeModuleDependencies.apply(project.path, const []), isTrue);
    final after = File('${project.path}/pubspec.yaml').readAsStringSync();
    expect(after, isNot(contains('lumina_plugin_openxr')));
    expect(after, isNot(contains(RuntimeModuleDependencies.pubspecBegin)));
    expect(File('${project.path}/pubspec_overrides.yaml').readAsStringSync(), isNot(contains(ProjectEngineLink.pluginOverridesBegin)));
    expect(File('${project.path}/${RuntimeModuleDependencies.registrationFile}').existsSync(), isFalse);
  });

  test('the engine link keeps the plugin pins when it rewrites the overrides', () {
    const block = '${ProjectEngineLink.pluginOverridesBegin}\n  lumina_plugin_openxr:\n    path: \'D:/x/openxr\'\n${ProjectEngineLink.pluginOverridesEnd}\n';
    final file = ProjectEngineLink.withPluginOverridesBlock('dependency_overrides:\n  lumina:\n    path: \'D:/e/lumina\'\n', block);
    expect(ProjectEngineLink.pluginOverridesBlock(file), block);
    final yaml = loadYaml(file) as YamlMap;
    expect((yaml['dependency_overrides'] as YamlMap).keys, containsAll(['lumina', 'lumina_plugin_openxr']));
    expect(ProjectEngineLink.withPluginOverridesBlock(file, ''), isNot(contains('lumina_plugin_openxr')));
  });
}
