// A plugin process in pure Dart: no Flutter, run with `dart run`.
//
// The editor (or a test's `LoopbackHost`) starts it with the launch flags
// (`--lumina-plugin-process <name> --lumina-plugin-port <port> ...`):
//
//   dart run example/pure_process.dart --lumina-plugin-process pure_sample \
//     --lumina-plugin-port 51234 --lumina-plugin-token <token>
import 'dart:io';

import 'package:lumina_plugin_process/lumina_plugin_process.dart';

/// Registers a menu command, a slot button with live state, an MCP tool and
/// a few handlers, and places actors in the open level through the editor.
class PureSampleProcess extends LuminaPluginProcess {
  final ObservableValue<PluginButtonStateSpec> status =
      ObservableValue(const PluginButtonStateSpec(icon: PluginIconSpec(0xe88e), tooltip: 'Idle'));
  int greetings = 0;

  @override
  String get pluginName => 'pure_sample';

  @override
  void register(PluginProcessContext context) {
    context.handle('greet', (args) {
      greetings++;
      status.value = PluginButtonStateSpec(icon: const PluginIconSpec(0xe88e), tooltip: 'Greeted $greetings');
      context.emit('greeted', {'count': greetings});
      return {'greeting': 'Hello, ${args['name'] ?? 'editor'}', 'pid': pid};
    });
    context.handle('settings', (_) => context.pluginSettings.value);
    // What an editor panel Widget Blueprint of this plugin drives: a status
    // read, an event, element-state patches and a burst of them.
    context.handle('status', (_) => {'state': 'idle', 'greetings': greetings});
    context.handle('emitProgress', (args) {
      context.emit('progress', {'value': args['value'] ?? 0.5});
      return null;
    });
    context.handle('patchStatus', (args) {
      context.patchPanel('${args['panel']}', [PluginPanelStateOp('StatusText', {'text': args['text'] ?? 'Ready'})]);
      return null;
    });
    context.handle('patchBurst', (args) async {
      final count = args['count'] as int? ?? 200;
      final periodUs = (args['periodMs'] as int? ?? 1000) * 1000;
      // Evenly over the period on any timer resolution: send whatever is due.
      final clock = Stopwatch()..start();
      for (var i = 1; i <= count; i++) {
        final due = periodUs * (i - 1) ~/ count - clock.elapsedMicroseconds;
        if (due > 0) await Future<void>.delayed(Duration(microseconds: due));
        context.patchPanel('${args['panel']}', [PluginPanelStateOp('StatusText', {'text': 'Step $i'})]);
      }
      return {'sent': count, 'ms': clock.elapsedMilliseconds};
    });
    context.handle('placeCrates', (args) async {
      final count = args['count'] as int? ?? 1;
      final ids = await context.level.runTransaction('Place crates', () {
        return context.level.addActors([
          for (var i = 0; i < count; i++)
            EditorActorSpec(name: 'Crate$i', type: 'StaticMesh', location: [i * 100.0, 0, 0]),
        ]);
      });
      return {'ids': ids, 'names': [for (final a in context.level.actors) a.name]};
    });

    // A modal dialog over the editor: answers the pressed action and the
    // body's values (`{action: null}` when dismissed or closed).
    context.handle('askName', (args) async {
      final r = await context.showDialog(PluginDialogSpec(
        id: args['id'] as String? ?? 'ask_name',
        title: args['title'] as String? ?? 'Name the actor',
        body: [PluginControl.textField('name', label: 'Name', value: args['initial'] as String? ?? '')],
        actions: const [
          PluginDialogAction(id: 'cancel', label: 'Cancel'),
          PluginDialogAction(id: 'accept', label: 'Accept', tone: PluginDialogTone.primary),
        ],
      ));
      return r.toJson();
    });
    context.handle('closeDialog', (args) => context.closeDialog(args['id'] as String));
    context.handle('confirmDelete', (_) => context.confirm('Delete the crates?', 'Removes every crate.',
        confirmLabel: 'Delete', destructive: true));

    context.registerMenuItem(
      'Tools/Pure Sample/Greet',
      PluginProcessCommand(id: 'pure_sample.greet', label: 'Greet', run: () => context.log('greet from the menu')),
    );
    context.registerSlotButton(PluginProcessSlotButton(
      id: 'pure_sample.status',
      slot: 'statusBarRight',
      state: status,
      command: PluginProcessCommand(id: 'pure_sample.status', label: 'Status', run: () {}),
    ));
    context.registerMcpTool(McpTool(
      name: 'square',
      description: 'Squares n.',
      inputSchema: McpSchema.object({'n': {'type': 'integer'}}, required: ['n']),
      handler: (args) => McpToolResult.json({'n': args.integer('n') * args.integer('n')}),
      risk: McpToolRisk.readOnly,
      groups: {McpToolGroups.plugin},
    ));
  }
}

Future<void> main(List<String> args) async {
  final launch = PluginProcessLaunch.parse(args);
  if (launch == null) {
    stderr.writeln('usage: dart run example/pure_process.dart ${PluginProcessLaunch.flag} <name> ...');
    exit(64);
  }
  exit(await runPluginProcessMain(launch, PureSampleProcess()));
}
