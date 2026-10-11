import 'dart:convert';
import 'dart:io';

import 'package:lumina_core/lumina_core.dart';
import 'package:test/test.dart';

/// Kernel plugins: `process_kernel` / `process_entry` / `process_kernel_sdk`
/// on an isolated plugin's editor module, read from real manifest files.
void main() {
  late Directory temp;
  late Directory root;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('lm_kernel_');
    root = Directory('${temp.path}/plugins')..createSync();
  });
  tearDown(() {
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  void writeManifest(String name, Map<String, Object?> module, {Map<String, Object?> fields = const {}}) {
    final dir = Directory('${root.path}/$name')..createSync(recursive: true);
    File('${dir.path}/$name.lmplugin').writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
      'name': name,
      'version': '1.2.0',
      'isolation': 'process',
      'modules': [
        {'name': name, 'type': 'editor', 'entry_library': 'lib/$name.dart', 'process_class': 'XProcess', ...module},
      ],
      ...fields,
    }));
  }

  Future<PluginScanResult> scan() =>
      PluginRepository(roots: [PluginScanRoot(dir: root, origin: PluginOrigin.user)]).scanAll();

  const kernelModule = {
    'process_kernel': 'bin/x_process.dill',
    'process_entry': 'bin/x_process.dart',
    'process_kernel_sdk': '3.11.0',
  };

  test('a shell-less process plugin with a kernel and an entry is a kernel plugin', () async {
    writeManifest('x_plugin', kernelModule);
    final result = await scan();
    expect(result.errors, isEmpty);
    final d = result.plugins.single;
    expect(d.isKernelPlugin, isTrue);
    final m = d.processModule!;
    expect(m.processKernel, 'bin/x_process.dill');
    expect(m.processEntry, 'bin/x_process.dart');
    expect(m.processKernelSdk, '3.11.0');
    expect(d.processKernelFile!.path.replaceAll(r'\', '/'), endsWith('x_plugin/bin/x_process.dill'));
    expect(d.processEntryFile!.path.replaceAll(r'\', '/'), endsWith('x_plugin/bin/x_process.dart'));
    // Round trip: the fields stay on the module.
    final json = (d.toJson()['modules'] as List).single as Map<String, dynamic>;
    expect(json['process_kernel'], 'bin/x_process.dill');
    expect(json['process_entry'], 'bin/x_process.dart');
    expect(json['process_kernel_sdk'], '3.11.0');
    expect(d.extras.containsKey('process_kernel'), isFalse);
  });

  test('a kernel path escaping the plugin folder is rejected', () async {
    writeManifest('escape_plugin', {...kernelModule, 'process_kernel': '../x.dill'});
    writeManifest('abs_plugin', {...kernelModule, 'process_entry': '/etc/x_process.dart'});
    final result = await scan();
    expect(result.plugins, isEmpty);
    expect(result.errors, hasLength(2));
    final byFile = {for (final e in result.errors) e.filePath.contains('escape_plugin') ? 'escape' : 'abs': e};
    expect(byFile['escape']!.kind, PluginErrorKind.schemaViolation);
    expect(byFile['escape']!.message, contains('process_kernel'));
    expect(byFile['escape']!.message, contains('inside the plugin folder'));
    expect(byFile['abs']!.message, contains('process_entry'));
  });

  test('a kernel without its process_entry is not a kernel plugin; the error names the field', () async {
    writeManifest('no_entry', {'process_kernel': 'bin/x_process.dill', 'process_kernel_sdk': '3.11.0'});
    final result = await scan();
    expect(result.plugins, isEmpty);
    expect(result.errors.single.kind, PluginErrorKind.schemaViolation);
    expect(result.errors.single.message, contains('"process_entry"'));
  });

  test('a module with a registration_class is a compiled isolated plugin, not a kernel plugin', () async {
    writeManifest('shell_plugin', {...kernelModule, 'registration_class': 'ShellPlugin'});
    final d = (await scan()).plugins.single;
    expect(d.isKernelPlugin, isFalse);
    expect(d.isolation, PluginIsolation.process);
  });

  test('a kernel on an in-process plugin does not make it a kernel plugin', () async {
    writeManifest('in_proc', {...kernelModule, 'registration_class': 'P'}, fields: {'isolation': 'in_process'});
    expect((await scan()).plugins.single.isKernelPlugin, isFalse);
  });

  test('the in-process override does not apply to a kernel plugin or a process plugin without a registration_class',
      () async {
    writeManifest('kernel_plugin', kernelModule);
    writeManifest('shellless', const {});
    writeManifest('shelled', {'registration_class': 'ShellPlugin'});
    final plugins = {for (final d in (await scan()).plugins) d.name: d};
    const forced = LuminaProject(projectName: 'p', pluginIsolation: {
      'kernel_plugin': PluginIsolation.inProcess,
      'shellless': PluginIsolation.inProcess,
      'shelled': PluginIsolation.inProcess,
    });
    expect(plugins['kernel_plugin']!.canRunInEditorProcess, isFalse);
    expect(plugins['kernel_plugin']!.inEditorProcessUnavailableReason, contains('kernel'));
    expect(plugins['kernel_plugin']!.effectiveIsolation(forced), PluginIsolation.process);
    expect(plugins['shellless']!.canRunInEditorProcess, isFalse);
    expect(plugins['shellless']!.inEditorProcessUnavailableReason, contains('registration_class'));
    expect(plugins['shellless']!.effectiveIsolation(forced), PluginIsolation.process);
    expect(plugins['shelled']!.canRunInEditorProcess, isTrue);
    expect(plugins['shelled']!.inEditorProcessUnavailableReason, isNull);
    expect(plugins['shelled']!.effectiveIsolation(forced), PluginIsolation.inProcess);
  });
}
