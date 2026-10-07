import 'package:lumina/lumina.dart';

import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blend_space_editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_editor_sessions.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/core_tools.dart' show mcpUndoState;

/// The Blend Space editor as MCP tools: axes (name, range,
/// 1D ⇄ 2D), grid divisions, samples (dropped clips snapped to the grid),
/// the preview point and the clip it picks, Save. Every edit goes through
/// the tab's `BlendSpaceEditorViewModel`; document edits are one `MCP: …`
/// step on its stack (the divisions and the preview point are view state).
void registerBlendSpaceTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions) {
  const groups = {McpToolGroups.animation};
  final assetArg = McpSchema.string('The Blend Space: its project-relative .lmas path (list_assets with type '
      '"blendSpace") or its file name when unique.');
  final indexArg = McpSchema.integer('The sample index (get_blend_space).');

  Future<BlendSpaceEditorViewModel> editorFor(McpArgs args) async {
    final asset = sessions.resolveAsset(args.string('asset'));
    if (asset.type != AssetType.blendSpace) {
      throw JsonRpcException(JsonRpcErrorCode.invalidParams,
          '${asset.relativePath} is a ${asset.type.name}, not a Blend Space. Call list_assets with type "blendSpace".');
    }
    return sessions.blendSpace(asset);
  }

  String clipOf(BlendSpaceEditorViewModel e, String clip) {
    if (!e.clips.contains(clip)) {
      throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'No clip "$clip" on ${e.targetMesh}. Clips: ${e.clips.join(', ')}.');
    }
    return clip;
  }

  int sampleOf(BlendSpaceEditorViewModel e, McpArgs args) {
    final i = args.integer('index');
    if (i < 0 || i >= e.document.samples.length) {
      throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'No sample $i; the Blend Space has ${e.document.samples.length}.');
    }
    return i;
  }

  Map<String, Object?> sampleJson(int i, LuminaBlendSpaceSample s) => {'index': i, 'clip': s.clip, 'x': s.x, 'y': s.y};

  Map<String, Object?> state(BlendSpaceEditorViewModel e) {
    final doc = e.document;
    final nearest = e.nearestSample;
    return {
      'asset': e.relativePath,
      'target_mesh': e.targetMesh,
      'axes': [for (final a in doc.axes) {'name': a.name, 'min': a.min, 'max': a.max}],
      'divisions': {'x': e.divisionsX, 'y': e.divisionsY},
      'samples': [for (var i = 0; i < doc.samples.length; i++) sampleJson(i, doc.samples[i])],
      'clips': e.clips,
      'preview_point': [e.previewPoint.$1, e.previewPoint.$2],
      'nearest_sample': nearest == null ? null : sampleJson(doc.samples.indexOf(nearest), nearest),
      'is_dirty': e.isDirty,
      'undo': mcpUndoState(e.transactions),
    };
  }

  registry.registerAll([
    McpTool(
      name: 'get_blend_space',
      risk: McpToolRisk.readOnly,
      groups: groups,
      title: 'Get Blend Space',
      description: 'A Blend Space as its editor shows it: axes [{name, min, max}] (one for 1D, two for 2D), grid '
          'divisions, samples [{index, clip, x, y}], the target mesh\'s clips, the preview point and the nearest sample '
          '(the one the preview plays: lumina picks the nearest sample and cross-fades, it never blends weights). Opens its tab.',
      inputSchema: McpSchema.object({'asset': assetArg}, required: ['asset']),
      handler: (args) async => McpToolResult.json(state(await editorFor(args))),
    ),
    McpTool(
      name: 'set_blend_space_axis',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set Blend Space axis',
      description: 'Renames an axis and / or sets its range (one undo step). max must exceed min.',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'index': McpSchema.integer('0 (X, e.g. Direction) or 1 (Y, e.g. Speed).'),
        'name': McpSchema.string('The axis name.'),
        'min': McpSchema.number('The range minimum.'),
        'max': McpSchema.number('The range maximum.'),
      }, required: ['asset', 'index']),
      handler: (args) async {
        final e = await editorFor(args);
        final i = args.integer('index');
        final axes = e.document.axes;
        if (i < 0 || i >= axes.length) return McpToolResult.error('No axis $i; the Blend Space has ${axes.length}.');
        final min = args.optionalNumber('min') ?? axes[i].min, max = args.optionalNumber('max') ?? axes[i].max;
        if (max <= min) return McpToolResult.error('The axis max ($max) must exceed its min ($min). Nothing changed.');
        e.setAxis(i, name: args.optionalString('name'), min: min, max: max);
        return McpToolResult.json(state(e));
      },
    ),
    McpTool(
      name: 'set_blend_space_dimensions',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set Blend Space dimensions',
      description: 'Makes the Blend Space 1D (the Y axis and every sample\'s Y are dropped) or 2D (a Speed axis 0…500 '
          'is added), one undo step.',
      inputSchema: McpSchema.object({'asset': assetArg, 'count': McpSchema.integer('1 or 2.')}, required: ['asset', 'count']),
      handler: (args) async {
        final e = await editorFor(args);
        final count = args.integer('count');
        if (count != 1 && count != 2) return McpToolResult.error('count must be 1 or 2.');
        e.setDimensions(count);
        return McpToolResult.json(state(e));
      },
    ),
    McpTool(
      name: 'set_blend_space_divisions',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set Blend Space divisions',
      description: 'Sets the grid divisions per axis (1…32) that new samples snap to. Editor state kept with the tab, '
          'not the saved document.',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'x': McpSchema.integer('X axis divisions.'),
        'y': McpSchema.integer('Y axis divisions.'),
      }, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        e.setDivisions(x: args.has('x') ? args.integer('x') : null, y: args.has('y') ? args.integer('y') : null);
        return McpToolResult.json(state(e));
      },
    ),
    McpTool(
      name: 'add_blend_space_sample',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      title: 'Add Blend Space sample',
      description: 'Drops a clip of the target mesh at (x, y), snapped to the grid divisions as a drop on the grid '
          'is (one undo step). Returns the sample with its snapped coordinates.',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'clip': McpSchema.string('A clip of the target mesh (get_blend_space clips).'),
        'x': McpSchema.number('X axis value.'),
        'y': McpSchema.number('Y axis value (ignored for a 1D space).'),
      }, required: ['asset', 'clip', 'x']),
      handler: (args) async {
        final e = await editorFor(args);
        final i = e.addSample(clipOf(e, args.string('clip')), args.number('x'), args.number('y', fallback: 0));
        if (i == null) return McpToolResult.error('The Blend Space has no axis to place a sample on.');
        return McpToolResult.json({...sampleJson(i, e.document.samples[i]), 'is_dirty': e.isDirty, 'undo': mcpUndoState(e.transactions)});
      },
    ),
    McpTool(
      name: 'set_blend_space_sample',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set Blend Space sample',
      description: 'Moves a sample (unsnapped, as typed in its fields) and / or retargets it to another clip (one undo step).',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'index': indexArg,
        'clip': McpSchema.string('Another clip of the target mesh.'),
        'x': McpSchema.number('X axis value.'),
        'y': McpSchema.number('Y axis value.'),
      }, required: ['asset', 'index']),
      handler: (args) async {
        final e = await editorFor(args);
        final i = sampleOf(e, args);
        final clip = args.has('clip') ? clipOf(e, args.string('clip')) : null;
        e.setSample(i, clip: clip, x: args.optionalNumber('x'), y: args.optionalNumber('y'));
        return McpToolResult.json({...sampleJson(i, e.document.samples[i]), 'is_dirty': e.isDirty, 'undo': mcpUndoState(e.transactions)});
      },
    ),
    McpTool(
      name: 'remove_blend_space_sample',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      removesContent: true,
      title: 'Remove Blend Space sample',
      description: 'Deletes a sample (one undo step); later samples move down one index.',
      inputSchema: McpSchema.object({'asset': assetArg, 'index': indexArg}, required: ['asset', 'index']),
      handler: (args) async {
        final e = await editorFor(args);
        e.removeSample(sampleOf(e, args));
        return McpToolResult.json(state(e));
      },
    ),
    McpTool(
      name: 'set_blend_space_preview',
      risk: McpToolRisk.editorState,
      groups: groups,
      idempotent: true,
      title: 'Set Blend Space preview',
      description: 'Moves the preview point (unsnapped); the preview mesh cross-fades to the nearest sample\'s clip, '
          'which is returned as picked_clip. Changes what the tab shows, never the document.',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'x': McpSchema.number('X axis value.'),
        'y': McpSchema.number('Y axis value.'),
      }, required: ['asset', 'x']),
      handler: (args) async {
        final e = await editorFor(args);
        if (!e.preview.isAttached) e.startHeadlessPreview(ticker: false);
        e.setPreviewPoint(args.number('x'), args.number('y', fallback: 0));
        final nearest = e.nearestSample;
        return McpToolResult.json({
          'preview_point': [e.previewPoint.$1, e.previewPoint.$2],
          'picked_clip': nearest?.clip,
          'nearest_sample': nearest == null ? null : sampleJson(e.document.samples.indexOf(nearest), nearest),
        });
      },
    ),
    McpTool(
      name: 'save_blend_space',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Save Blend Space',
      description: 'Writes the Blend Space .lmas (the tab\'s Save).',
      inputSchema: McpSchema.object({'asset': assetArg}, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        if (!await e.save()) return McpToolResult.error('The Blend Space was not saved; see the Output Log.');
        return McpToolResult.json({'saved': e.relativePath, 'is_dirty': e.isDirty});
      },
    ),
  ]);
}
