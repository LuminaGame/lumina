import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';

/// The MCP tool types live in the plugin API, and a
/// detached EditorMcp runs a plugin's tools.
void main() {
  McpTool tool({String name = 'count', McpToolHandler? handler}) => McpTool(
        name: name,
        title: 'Count',
        description: 'Counts things.',
        inputSchema: McpSchema.object({'n': McpSchema.integer('How many')}),
        handler: handler ?? (args) => McpToolResult.json({'n': args.integer('n', fallback: 0)}),
        risk: McpToolRisk.readOnly,
        groups: {McpToolGroups.level},
      );

  test('the moved types serialise as they did in lumina_ui', () {
    expect(tool().toJson(), {
      'name': 'count',
      'title': 'Count',
      'description': 'Counts things.',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'n': {'type': 'integer', 'description': 'How many'},
        },
        'additionalProperties': false,
      },
      'annotations': {'title': 'Count', 'readOnlyHint': true, 'destructiveHint': false, 'idempotentHint': true, 'openWorldHint': false},
      '_meta': {
        'lumina/risk': 'readOnly',
        'lumina/groups': ['level'],
      },
    });
    expect(McpToolResult.json({'a': 1}).toJson(), {
      'content': [
        {'type': 'text', 'text': '{\n  "a": 1\n}'},
      ],
      'structuredContent': {'a': 1},
      'isError': false,
    });
    expect(McpToolGroups.known, contains(McpToolGroups.plugin));
    // Content Browser / Marketplace / DDC and Source Control.
    expect(McpToolGroups.known, containsAll(['content', 'scm']));
    // The UMG designer and the material node graph.
    expect(McpToolGroups.known, containsAll(['umg', 'material_graph']));
    // Animation editors, Sequencer, particles.
    expect(McpToolGroups.known, containsAll(['animation', 'sequencer', 'particle']));
    // Landscape, static mesh, texture, physics asset,
    // audio, Enumeration / Interface editors and their umbrella.
    expect(McpToolGroups.known,
        containsAll(['landscape', 'static_mesh', 'texture', 'physics_asset', 'audio', 'blueprint_types', 'asset_editors']));
  });

  test('McpArgs names the argument it rejects', () {
    expect(
      () => const McpArgs({'n': 'x'}).integer('n'),
      throwsA(isA<JsonRpcException>()
          .having((e) => e.code, 'code', JsonRpcErrorCode.invalidParams)
          .having((e) => e.message, 'message', contains('"n"'))),
    );
  });

  test('a detached EditorMcp registers, lists and calls a plugin tool, reporting the call', () async {
    final mcp = EditorMcp.detached(pluginName: 'probe');
    var changed = 0;
    mcp.toolsChanged.addListener(() => changed++);
    mcp.registerTool(tool());
    expect(changed, 1);
    expect(mcp.listTools().single.name, 'probe.count');
    expect(mcp.listTools().single.groups, {McpToolGroups.level, McpToolGroups.plugin});
    final events = <McpToolCallEvent>[];
    final sub = mcp.calls.listen(events.add);
    final result = await mcp.callTool('probe.count', {'n': 3}, caller: 'test');
    expect(result.structuredContent, {'n': 3});
    await Future<void>.delayed(Duration.zero);
    expect(events.single.tool, 'probe.count');
    expect(events.single.caller, 'test');
    expect(events.single.transport, McpTransport.inProcess);
    await sub.cancel();
  });

  test('the MCP files import no Flutter (the stdio bridge and CLI tools use them)', () {
    for (final f in Directory('lib/src/mcp').listSync().whereType<File>()) {
      expect(f.readAsStringSync(), isNot(contains('package:flutter')), reason: f.path);
    }
  });
}
