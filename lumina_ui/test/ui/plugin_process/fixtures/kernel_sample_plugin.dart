import 'dart:convert';
import 'dart:io';

import 'package:lumina_editor_api/lumina_editor_api.dart' show PluginKernelCompiler;
import 'package:lumina_editor_data/lumina_editor.dart' show LuminaWorkspace;
import 'package:path/path.dart' as p;

/// The reference kernel plugin `kernel_sample`: a shell-less isolated
/// plugin whose process ships as a Dart kernel. It registers a menu item
/// that asks a confirm dialog and then copies the level's first mesh actor
/// three times through the level proxy, a declarative panel with the same
/// button, and an MCP tool that counts the level's actors.
const String kKernelSampleName = 'kernel_sample';

const String _processSource = r'''
import 'dart:async';
import 'dart:io';

import 'package:lumina_plugin_process/lumina_plugin_process.dart';

/// The process of the kernel sample plugin.
class KernelSampleProcess extends LuminaPluginProcess {
  int placed = 0;

  @override
  String get pluginName => 'kernel_sample';

  @override
  void register(PluginProcessContext context) {
    Future<int> place() async {
      final ok = await context.confirm('Place barrels?', 'Copies the first mesh actor of the level three times.',
          confirmLabel: 'Place');
      if (!ok) return 0;
      final source = context.level.actors.where((a) => a.meshAssetPath != null).firstOrNull;
      final ids = await context.level.runTransaction('Place barrels', () {
        return context.level.addActors([
          for (var i = 0; i < 3; i++)
            EditorActorSpec(
              name: 'KernelBarrel${placed + i}',
              type: 'StaticMesh',
              location: [
                (source?.location[0] ?? 0) + 120.0 * (i + 1),
                source?.location[1] ?? 0,
                source?.location[2] ?? 0,
              ],
              meshAssetPath: source?.meshAssetPath,
            ),
        ]);
      });
      placed += ids.length;
      context.view('kernel_sample.view')?.patch(PluginViewPatch([
        PluginViewPatchOp.set('status', {'value': 'Placed $placed actors'}),
      ]));
      return ids.length;
    }

    context.handle('pid', (_) => pid);
    context.handle('place', (_) => place());
    context.registerMenuItem(
      'Tools/Kernel Sample/Place Barrels',
      PluginProcessCommand(id: 'kernel_sample.place', label: 'Place Barrels', run: () => place()),
    );
    context.registerViewPanel(PluginProcessViewPanel(
      id: 'kernel_sample.panel',
      title: 'Kernel Sample',
      dock: 'right',
      initial: PluginViewSpec(id: 'kernel_sample.view', children: [
        PluginControl.text('title', 'Kernel Sample (runs on the Dart VM)', style: 'heading'),
        PluginControl.text('status', 'Ready'),
        PluginControl.button('place', 'Place Barrels', tone: 'primary'),
      ]),
      onEvent: (event, view) async {
        if (event.controlId == 'place' && event.kind == 'pressed') await place();
      },
    ));
    context.registerMcpTool(McpTool(
      name: 'kernel_sample_count',
      description: 'Counts the actors of the open level.',
      inputSchema: McpSchema.object({}),
      handler: (_) async {
        return McpToolResult.json({'actors': context.level.actors.length});
      },
      risk: McpToolRisk.readOnly,
      groups: {McpToolGroups.plugin},
    ));
  }
}
''';

const String _entrySource = r'''
import 'package:lumina_plugin_process/lumina_plugin_process.dart';
import 'package:kernel_sample/kernel_sample.dart';

Future<void> main(List<String> args) => runPluginProcessEntry(args, KernelSampleProcess.new);
''';

/// The `dart` of the Flutter SDK running the tests.
String sdkDart() {
  final exe = Platform.isWindows ? 'dart.exe' : 'dart';
  final roots = <String>[
    if (Platform.environment['FLUTTER_ROOT'] case final root?) p.join(root, 'bin', 'cache', 'dart-sdk', 'bin', exe),
  ];
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 6; i++) {
    roots.add(p.join(dir.path, 'dart-sdk', 'bin', exe));
    dir = dir.parent;
  }
  return roots.firstWhere((c) => File(c).existsSync());
}

/// Writes `kernel_sample` into `<parent>/kernel_sample`: its manifest,
/// pubspec (depending on this workspace's `lumina_plugin_process` by path),
/// process library and entry. With [compile] it compiles the kernel with
/// this SDK (`.dill` + `.sha256`) and stamps it with [sdkStamp] (default:
/// the SDK that compiled it). [entrySource] replaces the entry (a compile
/// error, say); [content] adds a `content/` folder.
Future<Directory> writeKernelSamplePlugin(
  Directory parent, {
  bool compile = true,
  String? sdkStamp,
  String version = '1.0.0',
  String? entrySource,
  bool content = false,
}) async {
  final dir = Directory(p.join(parent.path, kKernelSampleName))..createSync(recursive: true);
  final lpp = LuminaWorkspace.package('lumina_plugin_process').replaceAll(r'\', '/');
  File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: kernel_sample
version: $version
publish_to: none
environment:
  sdk: ^3.12.0
dependencies:
  lumina_plugin_process:
    path: '$lpp'
''');
  File(p.join(dir.path, 'lib', 'kernel_sample.dart'))
    ..createSync(recursive: true)
    ..writeAsStringSync(_processSource);
  File(p.join(dir.path, 'bin', 'kernel_sample_process.dart'))
    ..createSync(recursive: true)
    ..writeAsStringSync(entrySource ?? _entrySource);
  if (content) {
    File(p.join(dir.path, 'content', 'README.txt'))
      ..createSync(recursive: true)
      ..writeAsStringSync('kernel sample content\n');
  }
  String? stamp = sdkStamp;
  if (compile) {
    final r = await PluginKernelCompiler(sdkDart()).compile(
      pluginDir: dir,
      entry: 'bin/kernel_sample_process.dart',
      output: File(p.join(dir.path, 'bin', 'kernel_sample_process.dill')),
    );
    stamp ??= r.sdkVersion;
  }
  File(p.join(dir.path, '$kKernelSampleName.lmplugin')).writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
    'name': kKernelSampleName,
    'friendly_name': 'Kernel Sample',
    'version': version,
    'description': 'A shell-less plugin whose process runs on the Dart VM.',
    'category': 'Samples',
    'isolation': 'process',
    'can_contain_content': content,
    'modules': [
      {
        'name': kKernelSampleName,
        'type': 'editor',
        'entry_library': 'lib/kernel_sample.dart',
        'process_class': 'KernelSampleProcess',
        'process_kernel': 'bin/kernel_sample_process.dill',
        'process_entry': 'bin/kernel_sample_process.dart',
        'process_kernel_sdk': ?stamp,
      },
    ],
  }));
  return dir;
}
