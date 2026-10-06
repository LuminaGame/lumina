import 'dart:convert';
import 'dart:io';

import 'package:lumina/data/models/lumina_plugin_descriptor.dart';
import 'package:lumina/data/models/lumina_project.dart';
import 'package:lumina/data/repositories/plugin_repository.dart';
import 'package:test/test.dart';

/// `.lmplugin` `isolation` / `process_class`, read from real manifest files.
void main() {
  late Directory temp;
  late Directory root;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('lm_isolation_');
    root = Directory('${temp.path}/plugins')..createSync();
  });
  tearDown(() {
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  File writeManifest(String name, Map<String, Object?> fields, {Map<String, Object?> module = const {}}) {
    final dir = Directory('${root.path}/$name')..createSync(recursive: true);
    return File('${dir.path}/$name.lmplugin')
      ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
        'name': name,
        'version': '1.0.0',
        'modules': [
          {'name': name, 'type': 'editor', 'entry_library': 'lib/$name.dart', 'registration_class': 'ShellPlugin', ...module},
        ],
        ...fields,
      }));
  }

  Future<PluginScanResult> scan() =>
      PluginRepository(roots: [PluginScanRoot(dir: root, origin: PluginOrigin.project)]).scanAll();

  test('no isolation field: in process, no process class', () async {
    writeManifest('plain_plugin', const {});
    final result = await scan();
    expect(result.errors, isEmpty);
    final d = result.plugins.single;
    expect(d.isolation, PluginIsolation.inProcess);
    expect(d.processClass, isNull);
    expect(d.effectiveIsolation(), PluginIsolation.inProcess);
    expect(d.toJson().containsKey('isolation'), isFalse, reason: 'the default is not written');
  });

  test('"isolation": "process" with a process_class parses, round-trips and stays out of extras', () async {
    final file = writeManifest('iso_plugin', const {'isolation': 'process'}, module: const {'process_class': 'IsoProcess'});
    final result = await scan();
    expect(result.errors, isEmpty);
    final d = result.plugins.single;
    expect(d.isolation, PluginIsolation.process);
    expect(d.processClass, 'IsoProcess');
    expect(d.processModule!.registrationClass, 'ShellPlugin');
    expect(d.extras.containsKey('isolation'), isFalse);
    expect(d.effectiveIsolation(), PluginIsolation.process);

    final json = d.toJson();
    expect(json['isolation'], 'process');
    expect((json['modules'] as List).single['process_class'], 'IsoProcess');
    // Written back and read again: the same descriptor.
    file.writeAsStringSync(jsonEncode(json));
    final again = await PluginRepository(roots: []).loadInternal(file, PluginOrigin.project);
    expect(again.isolation, PluginIsolation.process);
    expect(again.processClass, 'IsoProcess');
    expect(again.toJson(), json);
  });

  test('"isolation": "in_process" is accepted and is the default', () async {
    writeManifest('explicit_plugin', const {'isolation': 'in_process'});
    final result = await scan();
    expect(result.errors, isEmpty);
    expect(result.plugins.single.isolation, PluginIsolation.inProcess);
  });

  test('an unknown isolation value is a schema violation the Plugin Manager lists', () async {
    writeManifest('bad_plugin', const {'isolation': 'sandbox'});
    writeManifest('good_plugin', const {});
    final result = await scan();
    expect(result.plugins.map((d) => d.name), ['good_plugin']);
    final error = result.errors.single;
    expect(error.kind, PluginErrorKind.schemaViolation);
    expect(error.message, contains('"isolation" must be "in_process" or "process", got "sandbox"'));
    expect(error.filePath, endsWith('bad_plugin.lmplugin'));
  });

  test('isolation process without a process_class on an editor module is a schema violation', () async {
    writeManifest('no_class_plugin', const {'isolation': 'process'});
    final result = await scan();
    expect(result.plugins, isEmpty);
    expect(result.errors.single.kind, PluginErrorKind.schemaViolation);
    expect(result.errors.single.message, contains('"process_class"'));
  });

  test('a process_class on a runtime module does not count', () async {
    final dir = Directory('${root.path}/runtime_plugin')..createSync();
    File('${dir.path}/runtime_plugin.lmplugin').writeAsStringSync(jsonEncode({
      'name': 'runtime_plugin',
      'version': '1.0.0',
      'isolation': 'process',
      'modules': [
        {'name': 'r', 'type': 'runtime', 'entry_library': 'lib/r.dart', 'registration_class': 'R', 'process_class': 'RProcess'},
      ],
    }));
    final result = await scan();
    expect(result.plugins, isEmpty);
    expect(result.errors.single.message, contains('"process_class"'));
  });

  test('a process_class that is not a Dart class name is a schema violation', () async {
    writeManifest('evil_plugin', const {'isolation': 'process'}, module: const {'process_class': "X(); import 'dart:io'"});
    final result = await scan();
    expect(result.plugins, isEmpty);
    expect(result.errors.single.message, contains('`modules[0].process_class` must be a Dart class name'));
  });

  test('the project override forces an isolated plugin in process; it cannot isolate a plugin without a process part',
      () async {
    writeManifest('iso_plugin', const {'isolation': 'process'}, module: const {'process_class': 'IsoProcess'});
    writeManifest('plain_plugin', const {});
    final plugins = {for (final d in (await scan()).plugins) d.name: d};
    const forced = LuminaProject(projectName: 'p', pluginIsolation: {
      'iso_plugin': PluginIsolation.inProcess,
      'plain_plugin': PluginIsolation.process,
    });
    expect(plugins['iso_plugin']!.effectiveIsolation(forced), PluginIsolation.inProcess);
    expect(plugins['iso_plugin']!.effectiveIsolation(const LuminaProject(projectName: 'p')), PluginIsolation.process);
    expect(plugins['plain_plugin']!.effectiveIsolation(forced), PluginIsolation.inProcess);
  });

  test('an isolated plugin may leave out registration_class (no UI shell); an in-process one may not', () async {
    writeManifest('shellless', {'isolation': 'process'}, module: {'registration_class': null, 'process_class': 'OnlyProcess'});
    writeManifest('broken', {}, module: {'registration_class': null});
    final result = await scan();
    final ok = result.plugins.singleWhere((p) => p.name == 'shellless');
    expect(ok.processModule!.registrationClass, isNull);
    expect(ok.processClass, 'OnlyProcess');
    expect(ok.modules.single.toJson().containsKey('registration_class'), isFalse);
    expect(result.plugins.where((p) => p.name == 'broken'), isEmpty);
    expect(result.errors.single.message, contains('registration_class'));
  });
}
