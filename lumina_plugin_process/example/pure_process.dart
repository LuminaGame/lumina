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
