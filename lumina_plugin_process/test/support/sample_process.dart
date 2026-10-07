import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:lumina_plugin_process/lumina_plugin_process.dart';

const PluginIconSpec kSampleIcon = PluginIconSpec(0xe145, fontFamily: 'MaterialIcons');

/// A plugin process that registers one of everything, for the tests.
class SampleProcess extends LuminaPluginProcess {
  final ObservableValue<PluginButtonStateSpec> slotState =
      ObservableValue(const PluginButtonStateSpec(icon: kSampleIcon, tooltip: 'Idle'));
  final ObservableValue<bool> checked = ObservableValue(false);
  final List<String> lifecycle = [];
  int runs = 0;
  bool allowRun = true;
  late PluginProcessContext context;

  @override
  String get pluginName => 'sample';

  @override
  Future<void> register(PluginProcessContext context) async {
    this.context = context;
    lifecycle.add('register');
    final level = context.level;

    context.handle('echo', (args) => {'echo': args});
    context.handle('boom', (_) => throw StateError('the handler broke'));
    context.handle('asyncBoom', (_) {
      Future<void>(() => throw StateError('broke later'));
      return 'started';
    });
    context.handle('settings', (_) => context.pluginSettings.value);
    context.handle('project', (_) => {'name': context.project?.name, 'store': context.storage.projectDir?.path});
    context.handle('pluginDir', (_) => context.pluginDir);
    context.handle('store', (args) async {
      await context.storage.writeJson('state', args, project: true);
      return await context.storage.readJson('state', project: true);
    });
    context.handle('reportCrash', (args) {
      LuminaPluginCrashReporter.reportCrash(StateError('native call failed'), StackTrace.current,
          plugin: pluginName, context: 'loading the model');
      return null;
    });
    context.handle('setCount', (args) {
      final view = context.view('sample.view');
      view?.patch(PluginViewPatch([PluginViewPatchOp.set('count', {'value': '${args['n']}'})]));
      return {'found': view != null, 'unknown': context.view('nope') == null};
    });
    context.handle('notify', (args) {
      context.emit('hello', {'n': args['n']});
      context.progress('job', step: 'half', done: 1, total: 2);
      context.log('working', level: 'warning');
      return null;
    });
    context.handle('editorCalls', (_) async {
      await context.saveAsset(relativePath: 'contents/gen/a.bin', bytes: Uint8List.fromList([1, 2, 3]));
      await context.showPanel('sample.view');
      await context.hidePanel('sample.view');
      await context.openTab('sample.tab', title: 'Sample');
      final r = await context.callMcpTool('list_actors', {'limit': 2});
      return r.toJson();
    });
    context.handle('scatter', (args) {
      final n = args['n'] as int;
      return level.runTransaction('Scatter', () async {
        final ids = await level.addActors([
          for (var i = 0; i < n; i++)
            EditorActorSpec(
              name: 'Rock$i',
              type: 'StaticMesh',
              location: [i * 100.0, 0, 0],
              components: const [EditorComponentSpec(type: 'Light', name: 'L')],
            ),
        ]);
        // A nested call joins the outer step.
        await level.runTransaction('Inner', () async {
          level.setComponentProperty(ids.first, 'Light', 'intensity', 5);
        });
        await level.addActors([const EditorActorSpec(name: 'Last', type: 'Empty', location: [0, 0, 0])]);
        return ids;
      });
    });
    context.handle('levelState', (_) => {
          'project': level.projectDirPath,
          'active': level.activeLevelPath,
          'names': [for (final a in level.actors) a.name],
          'selected': level.selectedActorIds,
          'undoTop': level.undoTopLabel,
          'light': level.actors.isEmpty ? null : level.actors.first.componentOfType('Light')?.properties['intensity'],
        });
    context.handle('levelEdits', (args) async {
      final ids = [for (final a in level.actors) a.id];
      level.selectActors([ids.first]);
      level.removeActors([ids.last], label: 'Remove');
      final undone = level.undoIfTop('Remove');
      await level.saveLevel();
      final opened = await level.openLevel('contents/levels/Missing.lmas');
      final reopened = await level.openLevel('contents/levels/L_Main.lmas');
      return {
        'afterRemove': [for (final a in level.actors) a.name],
        'undone': undone,
        'opened': opened,
        'reopened': reopened,
      };
    });

    context.registerMenu(const PluginMenuSpec(id: 'sample', title: 'Sample'));
    context.registerMenuItem(
      'Sample/Run',
      PluginProcessCommand(
        id: 'sample.run',
        label: 'Run',
        icon: kSampleIcon,
        run: () {
          runs++;
          context.emit('ran', runs);
        },
        canExecute: () => allowRun,
      ),
      order: 2,
      checked: checked,
    );
    context.registerSlotButton(PluginProcessSlotButton(
      id: 'status',
      slot: 'statusBarRight',
      state: slotState,
      command: PluginProcessCommand(id: 'sample.status', label: 'Status', run: () => context.emit('status')),
    ));
    context.registerMcpTool(McpTool(
      name: 'double',
      description: 'Doubles n.',
      inputSchema: McpSchema.object({'n': {'type': 'integer'}}, required: ['n']),
      handler: (args) {
        final n = args.integer('n');
        if (n < 0) throw StateError('negative');
        return McpToolResult.json({'n': n * 2});
      },
      risk: McpToolRisk.readOnly,
      groups: {McpToolGroups.plugin},
    ));
    context.registerImporter(PluginProcessImporter(
      id: 'txt',
      extensions: const ['txt'],
      description: 'Text notes',
      import: (source, targetDirectory) async {
        final text = await source.readAsString();
        if (text.isEmpty) throw const PluginImportError('the note is empty');
        final out = File('$targetDirectory/${source.uri.pathSegments.last}.lmas');
        await out.writeAsString(jsonEncode({'note': text}));
        return out.path;
      },
    ));
    context.registerConsoleCommand('sample.say', 'Says the words.', (args) => context.emit('said', args));
    context.registerViewPanel(PluginProcessViewPanel(
      id: 'sample.view',
      title: 'Sample',
      initial: PluginViewSpec(id: 'sample.view', children: [
        PluginControl.text('count', '0'),
        PluginControl.button('inc', 'Add'),
      ]),
      onEvent: (event, view) {
        if (event.controlId != 'inc') return;
        final now = int.parse(view.current.find('count')!.props['value'] as String) + 1;
        view.patch(PluginViewPatch([PluginViewPatchOp.set('count', {'value': '$now'})]));
      },
    ));
  }

  @override
  void onProjectOpened(EditorProjectInfo project) {
    lifecycle.add('opened:${project.name}');
    context.emit('opened', project.name);
  }

  @override
  Future<void> onProjectClosing() async {
    lifecycle.add('closing');
  }

  @override
  Future<void> onShutdown() async {
    lifecycle.add('shutdown');
  }
}
