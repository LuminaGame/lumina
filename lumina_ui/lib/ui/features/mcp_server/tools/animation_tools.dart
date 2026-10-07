import 'package:lumina/lumina.dart';

import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/anim_notify_and_curves.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/animation_editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_editor_sessions.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';

/// The Animation editor as MCP tools: clips and timing,
/// notifies, curves and their keys, rate scale, interpolation, additive
/// type, root motion, the preview mesh, the preview transport, Save.
///
/// The Animation editor has no undo stack (a dirty flag only): these edits
/// are reverted by not saving (the tab's Discard), never by `undo`.
void registerAnimationTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions) {
  const groups = {McpToolGroups.animation};
  const noUndo = 'The Animation editor has no undo stack: the edit marks the tab dirty and is reverted only by not '
      'saving (the tab\'s Discard).';
  final assetArg = McpSchema.string('The animation asset: its project-relative .lmas path (list_assets with type '
      '"animation") or its file name when unique.');
  final notifyArg = McpSchema.string('A notify, by id (get_animation) or by unique name.');
  final curveArg = McpSchema.string('A curve name (get_animation).');
  const notifyTypes = ['footstep', 'playSound', 'spawnParticle', 'custom'];
  const interpolations = ['Linear', 'Step'];
  const additiveTypes = ['No Additive', 'Local Space', 'Mesh Space'];

  Future<AnimationEditorViewModel> editorFor(McpArgs args) async {
    final asset = sessions.resolveAsset(args.string('asset'));
    if (asset.type != AssetType.animation) {
      throw JsonRpcException(JsonRpcErrorCode.invalidParams,
          '${asset.relativePath} is a ${asset.type.name}, not an animation. Call list_assets with type "animation".');
    }
    return sessions.animation(asset);
  }

  EditorAnimNotify notifyOf(AnimationEditorViewModel e, String ref) {
    final byId = e.notifies.where((n) => n.id == ref).firstOrNull;
    if (byId != null) return byId;
    final byName = e.notifies.where((n) => n.name == ref).toList();
    if (byName.length == 1) return byName.single;
    throw JsonRpcException(
      JsonRpcErrorCode.invalidParams,
      byName.isEmpty
          ? 'No notify "$ref". Notifies: ${e.notifies.isEmpty ? 'none' : e.notifies.map((n) => '${n.name} (${n.id})').join(', ')}.'
          : '"$ref" names ${byName.length} notifies; pass the id: ${byName.map((n) => n.id).join(', ')}.',
    );
  }

  AnimCurveData curveOf(AnimationEditorViewModel e, String name) =>
      e.curves.where((c) => c.name == name).firstOrNull ??
      (throw JsonRpcException(JsonRpcErrorCode.invalidParams,
          'No curve "$name". Curves: ${e.curves.isEmpty ? 'none (add_animation_curve)' : e.curves.map((c) => c.name).join(', ')}.'));

  Map<String, Object?> notifyJson(EditorAnimNotify n) =>
      {'id': n.id, 'name': n.name, 'time': n.time, 'type': n.type.name, 'is_sync_marker': n.isSyncMarker};

  Map<String, Object?> doc(AnimationEditorViewModel e) => {
        'asset': e.assetPath,
        'clips': [
          for (var i = 0; i < e.clips.length; i++)
            {'index': i, 'name': e.clips[i].name, 'duration_s': e.clips[i].duration, 'frames': (e.clips[i].duration * e.frameRate).ceil()},
        ],
        'selected_clip': e.selectedClip,
        'frame_rate': e.frameRate,
        'rate_scale': e.rateScale,
        'interpolation': e.interpolation,
        'additive_type': e.additiveType,
        'root_motion': e.enableRootMotion,
        'preview_mesh': e.previewMeshPath,
        'notifies': [for (final n in e.notifies) notifyJson(n)],
        'curves': [
          for (final c in e.curves) {'name': c.name, 'keys': [for (final k in c.keys) {'time': k.time, 'value': k.value}]},
        ],
        'position_s': e.positionSeconds,
        'is_playing': e.isPlaying,
        'is_dirty': e.isDirty,
      };

  registry.registerAll([
    McpTool(
      name: 'get_animation',
      risk: McpToolRisk.readOnly,
      groups: groups,
      title: 'Get animation',
      description: 'An animation asset as the Animation editor shows it: clips [{index, name, duration_s, frames}], the '
          'selected clip, frame_rate, rate_scale, interpolation (Linear / Step), additive_type, root_motion, the preview '
          'mesh, notifies [{id, name, time, type, is_sync_marker}], curves [{name, keys [{time, value}]}], the playhead '
          'position_s and is_dirty. Times are seconds on the selected clip. Opens its tab.',
      inputSchema: McpSchema.object({'asset': assetArg}, required: ['asset']),
      handler: (args) async => McpToolResult.json(doc(await editorFor(args))),
    ),
    McpTool(
      name: 'add_animation_notify',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      title: 'Add animation notify',
      description: 'Adds a notify at `time` seconds, clamped to the clip (the result says whether it was, and the time '
          'used). Types: ${notifyTypes.join(', ')} (default custom). $noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'name': McpSchema.string('The notify name, e.g. "Footstep_L".'),
        'time': McpSchema.number('Seconds on the clip.'),
        'type': McpSchema.string('The notify type.', enumValues: notifyTypes),
        'sync_marker': McpSchema.boolean('A sync marker. Default false.'),
      }, required: ['asset', 'name', 'time']),
      handler: (args) async {
        final e = await editorFor(args);
        final before = e.notifies.map((n) => n.id).toSet();
        final time = args.number('time');
        e.addNotify(args.string('name'), time,
            type: AnimNotifyType.values.byName(args.optionalString('type') ?? 'custom'), isSyncMarker: args.boolean('sync_marker'));
        final added = e.notifies.firstWhere((n) => !before.contains(n.id));
        return McpToolResult.json({...notifyJson(added), 'clamped': added.time != time, 'is_dirty': e.isDirty});
      },
    ),
    McpTool(
      name: 'move_animation_notify',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Move animation notify',
      description: 'Moves a notify to `time` seconds, clamped to the clip. $noUndo',
      inputSchema: McpSchema.object({'asset': assetArg, 'notify': notifyArg, 'time': McpSchema.number('Seconds on the clip.')},
          required: ['asset', 'notify', 'time']),
      handler: (args) async {
        final e = await editorFor(args);
        final n = notifyOf(e, args.string('notify'));
        e.moveNotify(n.id, args.number('time'));
        return McpToolResult.json({...notifyJson(n), 'is_dirty': e.isDirty});
      },
    ),
    McpTool(
      name: 'rename_animation_notify',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Rename animation notify',
      description: 'Renames a notify. $noUndo',
      inputSchema: McpSchema.object({'asset': assetArg, 'notify': notifyArg, 'name': McpSchema.string('The new name.')},
          required: ['asset', 'notify', 'name']),
      handler: (args) async {
        final e = await editorFor(args);
        final n = notifyOf(e, args.string('notify'));
        final name = args.string('name').trim();
        if (name.isEmpty) return McpToolResult.error('A notify needs a name.');
        e.renameNotify(n.id, name);
        return McpToolResult.json({...notifyJson(n), 'is_dirty': e.isDirty});
      },
    ),
    McpTool(
      name: 'remove_animation_notify',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      removesContent: true,
      title: 'Remove animation notify',
      description: 'Deletes a notify. $noUndo',
      inputSchema: McpSchema.object({'asset': assetArg, 'notify': notifyArg}, required: ['asset', 'notify']),
      handler: (args) async {
        final e = await editorFor(args);
        final n = notifyOf(e, args.string('notify'));
        e.removeNotify(n.id);
        return McpToolResult.json({'removed': n.id, 'is_dirty': e.isDirty});
      },
    ),
    McpTool(
      name: 'add_animation_curve',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      title: 'Add animation curve',
      description: 'Adds an empty float curve (e.g. a foot-plant weight). A name in use is refused. $noUndo',
      inputSchema: McpSchema.object({'asset': assetArg, 'name': McpSchema.string('The curve name.')}, required: ['asset', 'name']),
      handler: (args) async {
        final e = await editorFor(args);
        final name = args.string('name').trim();
        if (name.isEmpty) return McpToolResult.error('A curve needs a name.');
        if (e.curves.any((c) => c.name == name)) return McpToolResult.error('A curve "$name" already exists.');
        e.addCurve(name);
        return McpToolResult.json({'curve': name, 'curves': e.curves.map((c) => c.name).toList(), 'is_dirty': e.isDirty});
      },
    ),
    McpTool(
      name: 'remove_animation_curve',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      removesContent: true,
      title: 'Remove animation curve',
      description: 'Deletes a curve and its keys. $noUndo',
      inputSchema: McpSchema.object({'asset': assetArg, 'curve': curveArg}, required: ['asset', 'curve']),
      handler: (args) async {
        final e = await editorFor(args);
        final c = curveOf(e, args.string('curve'));
        e.removeCurve(c.name);
        return McpToolResult.json({'removed': c.name, 'is_dirty': e.isDirty});
      },
    ),
    McpTool(
      name: 'add_animation_curve_key',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      title: 'Add animation curve key',
      description: 'Adds a key (time seconds, value) to a curve; keys stay sorted by time. $noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'curve': curveArg,
        'time': McpSchema.number('Seconds on the clip.'),
        'value': McpSchema.number('The curve value.'),
      }, required: ['asset', 'curve', 'time', 'value']),
      handler: (args) async {
        final e = await editorFor(args);
        final c = curveOf(e, args.string('curve'));
        e.addCurveKey(c.name, args.number('time'), args.number('value'));
        return McpToolResult.json({
          'curve': c.name,
          'keys': [for (final k in c.keys) {'time': k.time, 'value': k.value}],
          'is_dirty': e.isDirty,
        });
      },
    ),
    McpTool(
      name: 'remove_animation_curve_key',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      removesContent: true,
      title: 'Remove animation curve key',
      description: 'Deletes the curve\'s key at `time` seconds (within 0.0001 s, as the curve editor matches it). $noUndo',
      inputSchema: McpSchema.object({'asset': assetArg, 'curve': curveArg, 'time': McpSchema.number('The key\'s time in seconds.')},
          required: ['asset', 'curve', 'time']),
      handler: (args) async {
        final e = await editorFor(args);
        final c = curveOf(e, args.string('curve'));
        final count = c.keys.length;
        e.deleteCurveKey(c.name, args.number('time'));
        if (c.keys.length == count) {
          return McpToolResult.error('No key of "${c.name}" at ${args.number('time')} s. Keys at: ${c.keys.map((k) => k.time).join(', ')}.');
        }
        return McpToolResult.json({
          'curve': c.name,
          'keys': [for (final k in c.keys) {'time': k.time, 'value': k.value}],
          'is_dirty': e.isDirty,
        });
      },
    ),
    McpTool(
      name: 'set_animation_settings',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set animation settings',
      description: 'The Animation editor\'s asset settings: the default clip (index), frame_rate (> 0), rate_scale, '
          'interpolation (${interpolations.join(' / ')}), additive_type (${additiveTypes.join(', ')}), root_motion, and '
          'the preview_mesh (a skeletal mesh .lmas). $noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'clip': McpSchema.integer('The clip index to show and save as default.'),
        'frame_rate': McpSchema.number('Frames per second.'),
        'rate_scale': McpSchema.number('Playback rate multiplier.'),
        'interpolation': McpSchema.string('Key interpolation.', enumValues: interpolations),
        'additive_type': McpSchema.string('Additive type.', enumValues: additiveTypes),
        'root_motion': McpSchema.boolean('Enable root motion.'),
        'preview_mesh': McpSchema.string('A skeletal mesh .lmas (project-relative) to preview on.'),
      }, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        if (args.has('clip')) {
          final i = args.integer('clip');
          if (i < 0 || i >= e.clips.length) return McpToolResult.error('No clip $i; the asset has ${e.clips.length}.');
          e.selectClip(i);
        }
        if (args.has('frame_rate')) {
          final fps = args.number('frame_rate');
          if (fps <= 0) return McpToolResult.error('frame_rate must be greater than 0.');
          e.setFrameRate(fps);
        }
        if (args.has('rate_scale')) e.setRateScale(args.number('rate_scale'));
        if (args.has('interpolation')) e.setInterpolation(args.string('interpolation'));
        if (args.has('additive_type')) e.setAdditiveType(args.string('additive_type'));
        if (args.has('root_motion')) e.setRootMotion(args.boolean('root_motion'));
        if (args.has('preview_mesh')) {
          final mesh = sessions.resolveAsset(args.string('preview_mesh'));
          if (!e.availableSkeletalMeshes.any((m) => m.relativePath == mesh.relativePath) && mesh.type != AssetType.filameshSk) {
            return McpToolResult.error('${mesh.relativePath} is not a skeletal mesh. Skeletal meshes: '
                '${e.availableSkeletalMeshes.map((m) => m.relativePath).join(', ')}.');
          }
          await e.setPreviewMesh(mesh);
        }
        return McpToolResult.json(doc(e));
      },
    ),
    McpTool(
      name: 'animation_preview',
      risk: McpToolRisk.editorState,
      groups: groups,
      idempotent: false,
      title: 'Animation preview',
      description: 'The Animation editor\'s transport: "play" / "pause", "seek" to `time` seconds, or "step" `frames` '
          'frames (negative steps back). Returns the position, the current frame and each curve\'s value there. '
          'Changes what the tab shows, never the asset. Created by a tool, the editor has no frame clock until its tab '
          'draws, so step or seek to move the playhead.',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'action': McpSchema.string('What to do.', enumValues: const ['play', 'pause', 'seek', 'step']),
        'time': McpSchema.number('For seek: seconds on the clip.'),
        'frames': McpSchema.integer('For step: frames (default 1).'),
      }, required: ['asset', 'action']),
      handler: (args) async {
        final e = await editorFor(args);
        switch (args.string('action')) {
          case 'play':
            e.play();
          case 'pause':
            e.pause();
          case 'seek':
            e.seek(args.number('time'));
          case 'step':
            e.stepFrame(args.integer('frames', fallback: 1));
        }
        return McpToolResult.json({
          'position_s': e.positionSeconds,
          'current_frame': e.currentFrame,
          'is_playing': e.isPlaying,
          'curves': {for (final c in e.curves) c.name: e.evaluateCurve(c.name)},
        });
      },
    ),
    McpTool(
      name: 'save_animation',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Save animation',
      description: 'Writes the animation .lmas: notifies, curves, settings, root motion, the preview mesh (the tab\'s Save).',
      inputSchema: McpSchema.object({'asset': assetArg}, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        if (!await e.save()) return McpToolResult.error('The animation was not saved; see the Output Log.');
        return McpToolResult.json({'saved': e.assetPath, 'is_dirty': e.isDirty});
      },
    ),
  ]);
}
