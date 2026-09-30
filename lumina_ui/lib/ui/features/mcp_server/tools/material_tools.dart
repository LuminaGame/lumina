import 'package:lumina/lumina.dart';

import '../../main_editor/view_models/editor_view_model.dart';
import '../../sub_editors/view_models/material_editor_view_model.dart';
import '../services/mcp_editor_sessions.dart';
import '../services/mcp_protocol.dart';
import '../services/mcp_tool.dart';

/// The Material editor as MCP tools: read and set the `.mat`
/// source, compile it with Filament's own material compiler (the `.mat`
/// parser `matc` uses), read the issues.
/// Edits go through the material's editor tab (opened when needed), so the
/// code view updates live and the tab's Save writes the `.lmas`.
void registerMaterialTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions) {
  Future<MaterialEditorViewModel> editorFor(McpArgs args) async =>
      sessions.material(sessions.resolveAsset(args.string('asset'), type: AssetType.filamat));

  List<Map<String, Object?>> issuesOf(MaterialEditorViewModel editor) => [
        for (final i in editor.issues) {'line': i.line, 'severity': i.severity.name, 'message': i.message},
      ];

  Map<String, Object?> parametersOf(MaterialEditorViewModel editor) => {
        for (final p in editor.parameters)
          p.name: {
            'type': p.type.name,
            'value': p.value,
            'is_sampler': p.isSampler,
            'texture': p.textureRef?.assetPath,
          },
      };

  const assetArg = 'The material\'s project-relative .lmas path (list_assets with type "filamat"), or its file name when unique.';

  registry.registerAll([
    McpTool(
      name: 'get_material_source',
      risk: McpToolRisk.readOnly,
      groups: const {McpToolGroups.material},
      title: 'Get material source',
      description: 'The material\'s .mat source (a Filament material definition, exactly what Filament\'s matc '
          'compiles: a `material { … }` header with any matc key — shadingModel, blending, parameters, requires, '
          'variables, transparency, culling, … — a `fragment { void material(inout MaterialInputs material) { … } }` '
          'block and optionally a `vertex { void materialVertex(inout MaterialVertexInputs material) { … } }` block), '
          'plus the header\'s shading model, blending, double-sidedness, declared parameters and the last compile\'s '
          'issues. Opens the Material editor tab.',
      inputSchema: McpSchema.object({'asset': McpSchema.string(assetArg)}, required: ['asset']),
      handler: (args) async {
        final editor = await editorFor(args);
        return McpToolResult.json({
          'asset': editor.assetPath,
          'source': editor.currentCode,
          'shading_model': editor.shading.name,
          'blending': editor.blending.name,
          'double_sided': editor.doubleSided,
          'parameters': parametersOf(editor),
          'is_dirty': editor.isDirty,
          'compiled_bytes': editor.compiledBytes?.length ?? 0,
          'issues': issuesOf(editor),
        });
      },
    ),
    McpTool(
      name: 'set_material_source',
      risk: McpToolRisk.mutating,
      groups: const {McpToolGroups.material},
      idempotent: true,
      title: 'Set material source',
      description: 'Replaces the material\'s .mat source in its editor tab (the code view updates), like typing it. '
          'Any Filament material definition matc accepts is supported: every header key, `vertex` and `fragment` '
          'blocks in any order, `#include "file"` from the material\'s folder. Does not compile or save: call '
          'compile_material (with save: true to write the .lmas). One undo step on the material tab\'s own stack: '
          'undo with asset: <this material>.',
      inputSchema: McpSchema.object({
        'asset': McpSchema.string(assetArg),
        'source': McpSchema.string('The whole .mat source: the material header, the fragment block and any vertex block.'),
      }, required: ['asset', 'source']),
      handler: (args) async {
        final editor = await editorFor(args);
        editor.replaceSourceWithTransaction(args.string('source'));
        return McpToolResult.json({
          'asset': editor.assetPath,
          'syntax_status': editor.syntaxStatus,
          'issues': issuesOf(editor),
          'is_dirty': editor.isDirty,
        });
      },
    ),
    McpTool(
      name: 'compile_material',
      risk: McpToolRisk.mutating,
      groups: const {McpToolGroups.material},
      idempotent: true,
      title: 'Compile material',
      description: 'Compiles the material\'s whole current source with Filament\'s own material compiler, the .mat '
          'parser matc uses (the editor\'s Compile button): ok, compile time, compiled size and issues '
          '[{line, severity, message}] where message is matc\'s text verbatim (parser errors, glslang errors, '
          'unknown-key warnings) and line its .mat line (0 when it names none). The preview takes the new material. '
          'With save: true the .lmas is written afterwards (source, parameters, payload).',
      inputSchema: McpSchema.object({
        'asset': McpSchema.string(assetArg),
        'save': McpSchema.boolean('Write the .lmas after compiling. Default false.'),
      }, required: ['asset']),
      handler: (args) async {
        final editor = await editorFor(args);
        final ok = await editor.compile();
        var saved = false;
        if (args.boolean('save')) saved = await editor.save();
        return McpToolResult(
          [
            ..._jsonContent({
              'ok': ok,
              'elapsed_ms': editor.elapsedMs,
              'compiled_bytes': ok ? (editor.compiledBytes?.length ?? 0) : 0,
              'status': editor.syntaxStatus,
              'issues': issuesOf(editor),
              'saved': saved,
              'is_dirty': editor.isDirty,
            })
          ],
          structuredContent: {
            'ok': ok,
            'elapsed_ms': editor.elapsedMs,
            'compiled_bytes': ok ? (editor.compiledBytes?.length ?? 0) : 0,
            'status': editor.syntaxStatus,
            'issues': issuesOf(editor),
            'saved': saved,
            'is_dirty': editor.isDirty,
          },
          isError: !ok,
        );
      },
    ),
    McpTool(
      name: 'get_material_issues',
      risk: McpToolRisk.readOnly,
      groups: const {McpToolGroups.material},
      title: 'Get material issues',
      description: 'The material editor\'s current issues: the last compile\'s matc messages (verbatim, with their '
          '.mat line; 0 when none) or, while typing, the editor\'s quick block/brace checks: [{line, severity, message}].',
      inputSchema: McpSchema.object({'asset': McpSchema.string(assetArg)}, required: ['asset']),
      handler: (args) async {
        final editor = await editorFor(args);
        return McpToolResult.json({'status': editor.syntaxStatus, 'issues': issuesOf(editor)});
      },
    ),
  ]);
}

List<Map<String, Object?>> _jsonContent(Map<String, Object?> data) => McpToolResult.json(data).content;
