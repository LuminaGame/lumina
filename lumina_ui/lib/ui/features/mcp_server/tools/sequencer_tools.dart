import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/sequencer_movie_render_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/sequencer_offscreen_frame_source.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/sequencer_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_editor_sessions.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_jobs.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/core_tools.dart' show mcpUndoState;
import 'package:lumina_ui/ui/features/mcp_server/tools/rotation_convention.dart';

/// The job key one movie render holds.
const String kMcpMovieRender = 'movie_render';

/// The Sequencer as MCP tools: tracks bound to level actors
/// (transform, property, visibility), keys with interpolation and tangents,
/// frame rate, length, playback range and looping, scrubbing (the level
/// preview moves live; `stop_sequence` restores it) and the Movie Render
/// Queue as a long-running job. Every edit goes through the
/// tab's `SequencerViewModel`, one `MCP: …` step on its stack.
void registerSequencerTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions, McpJobRegistry jobs) {
  const groups = {McpToolGroups.sequencer};
  const units = 'Transform channels carry the level\'s authoring units: Location in cm (Z up), Rotation .X/.Y/.Z '
      'as the level\'s $kMcpRotationConvention, Scale factors, as the Details panel shows them. Frames are sequence '
      'frames at its fps.';
  const scrubNote = 'Scrubbing writes the evaluated keys onto the bound level actors as a preview: it records no level '
      'undo step and does not dirty the level; stop_sequence (or closing the tab) puts the actors back. Never take a '
      'scrubbed position for an authored one, and never save_level mid-scrub.';
  final assetArg = McpSchema.string('The Level Sequence: its project-relative .lmas path (list_assets with type '
      '"sequencer") or its file name when unique.');
  final trackArg = McpSchema.string('A track id (get_sequence).');
  final channelArg = McpSchema.string('A channel of the track, e.g. "Location.Z" (get_sequence).');
  final keyArg = McpSchema.integer('The key index on the channel (get_sequence).');
  final interpolations = [for (final i in KeyInterpolation.values) i.name];

  Future<SequencerViewModel> editorFor(McpArgs args) async {
    final asset = sessions.resolveAsset(args.string('asset'));
    if (asset.type != AssetType.sequencer) {
      throw JsonRpcException(JsonRpcErrorCode.invalidParams,
          '${asset.relativePath} is a ${asset.type.name}, not a Level Sequence. Call list_assets with type "sequencer".');
    }
    return sessions.sequencer(asset);
  }

  /// For the transport: the sequence's bound view model without bringing its
  /// tab forward, so the level viewport the user watches stays in front.
  Future<SequencerViewModel> transportFor(McpArgs args) async {
    final asset = sessions.resolveAsset(args.string('asset'));
    final bound = vm.editorSessionFor(McpEditorSessions.tabIdOf(asset));
    return bound is SequencerViewModel ? bound : editorFor(args);
  }

  EditorActorNode actorOf(String ref) {
    final byId = vm.actors.where((a) => a.id == ref).firstOrNull;
    if (byId != null) return byId;
    final byName = vm.actors.where((a) => a.name == ref).toList();
    if (byName.length == 1) return byName.single;
    throw JsonRpcException(JsonRpcErrorCode.invalidParams,
        'No level actor "$ref"${byName.length > 1 ? ' (the name is ambiguous)' : ''}. Call list_actors and pass an actor id.');
  }

  SequencerTrack trackOf(SequencerViewModel e, String id) =>
      e.findTrack(id) ??
      (throw JsonRpcException(JsonRpcErrorCode.invalidParams,
          'No track "$id". Tracks: ${e.tracks.isEmpty ? 'none' : e.tracks.map((t) => '${t.id} (${t.actorName})').join(', ')}.'));

  SequencerChannel channelOf(SequencerViewModel e, SequencerTrack t, String name) =>
      e.findChannel(t.id, name) ??
      (throw JsonRpcException(JsonRpcErrorCode.invalidParams,
          'Track ${t.id} has no channel "$name". Channels: ${t.channels.map((c) => c.name).join(', ')}.'));

  int keyOf(SequencerChannel c, McpArgs args) {
    final i = args.integer('key');
    if (i < 0 || i >= c.keys.length) {
      throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'No key $i on ${c.name}; it has ${c.keys.length}.');
    }
    return i;
  }

  KeyInterpolation interpOf(String name) => KeyInterpolation.values.byName(name);

  Map<String, Object?> keyJson(SequencerViewModel e, SequencerTrack t, SequencerChannel c, int i) {
    final k = c.keys[i];
    return {
      'index': i,
      'frame': k.frame,
      'value': k.value,
      'interpolation': k.interpolation.name,
      'in_tangent': k.inTangent,
      'out_tangent': k.outTangent,
      'tangent_broken': e.isTangentBroken(t.id, c.name, i),
    };
  }

  Map<String, Object?> trackJson(SequencerViewModel e, SequencerTrack t) {
    final ids = vm.actors.map((a) => a.id).toSet();
    return {
      'id': t.id,
      'actor_id': t.actorId,
      'actor_name': t.actorName,
      'kind': t.kind.name,
      'property': t.propertyName,
      'missing_actor': e.isActorMissing(t.actorId, ids),
      'channels': [
        for (final c in t.channels)
          {
            'name': c.name,
            'keys': [for (var i = 0; i < c.keys.length; i++) keyJson(e, t, c, i)],
          },
      ],
    };
  }

  Map<String, Object?> edited(SequencerViewModel e, [Map<String, Object?> extra = const {}]) => {
        ...extra,
        'is_dirty': e.isDirty,
        'undo': mcpUndoState(e.transactions),
      };

  registry.registerAll([
    McpTool(
      name: 'get_sequence',
      risk: McpToolRisk.readOnly,
      groups: groups,
      title: 'Get sequence',
      description: 'A Level Sequence as the Sequencer shows it: fps, length_frames, playback_range [start, end], looping, '
          'the playhead (current_frame), tracks [{id, actor_id, actor_name, kind, property, missing_actor, channels '
          '[{name, keys [{index, frame, value, interpolation, in_tangent, out_tangent, tangent_broken}]}]}], whether the '
          'level shows a scrubbed preview, is_rendering and is_dirty. $units Opens its tab.',
      inputSchema: McpSchema.object({'asset': assetArg}, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        return McpToolResult.json({
          'asset': sessions.resolveAsset(args.string('asset')).relativePath,
          'fps': e.fps,
          'length_frames': e.lengthFrames,
          'playback_range': [e.rangeStart, e.rangeEnd],
          'looping': e.isLooping,
          'current_frame': e.playheadFrame,
          'is_playing': e.isPlaying,
          'previewing_level': e.isPreviewingLevel,
          'is_rendering': e.isRendering,
          'tracks': [for (final t in e.tracks) trackJson(e, t)],
          'is_dirty': e.isDirty,
          'undo': mcpUndoState(e.transactions),
        });
      },
    ),
    McpTool(
      name: 'add_sequencer_track',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      title: 'Add Sequencer track',
      description: 'Binds a level actor (list_actors id) to a new track (one undo step): "transform" (Location / '
          'Rotation / Scale .X/.Y/.Z channels), "property" (one channel named `property`, e.g. "intensity") or '
          '"visibility". $units',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'actor': McpSchema.string('The level actor\'s id (list_actors), or its unique name.'),
        'kind': McpSchema.string('The track kind.', enumValues: [for (final k in SequencerTrackKind.values) k.name]),
        'property': McpSchema.string('For "property": the property channel, default "intensity".'),
      }, required: ['asset', 'actor', 'kind']),
      handler: (args) async {
        final e = await editorFor(args);
        final actor = actorOf(args.string('actor'));
        final kind = SequencerTrackKind.values.byName(args.string('kind'));
        final before = e.tracks.map((t) => t.id).toSet();
        e.addTrack(actor.id, actor.name, kind, propertyName: kind == SequencerTrackKind.property ? (args.optionalString('property') ?? 'intensity') : null);
        final track = e.tracks.firstWhere((t) => !before.contains(t.id));
        return McpToolResult.json(edited(e, {'track': trackJson(e, track)}));
      },
    ),
    McpTool(
      name: 'delete_sequencer_track',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      removesContent: true,
      title: 'Delete Sequencer track',
      description: 'Deletes a track and its keys (one undo step).',
      inputSchema: McpSchema.object({'asset': assetArg, 'track': trackArg}, required: ['asset', 'track']),
      handler: (args) async {
        final e = await editorFor(args);
        final t = trackOf(e, args.string('track'));
        e.deleteTrack(t.id);
        return McpToolResult.json(edited(e, {'deleted': t.id}));
      },
    ),
    McpTool(
      name: 'rename_sequencer_track',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Rename Sequencer track',
      description: 'Renames a track\'s label (its actor binding is unchanged), one undo step.',
      inputSchema: McpSchema.object({'asset': assetArg, 'track': trackArg, 'name': McpSchema.string('The new label.')},
          required: ['asset', 'track', 'name']),
      handler: (args) async {
        final e = await editorFor(args);
        final t = trackOf(e, args.string('track'));
        final name = args.string('name').trim();
        if (name.isEmpty) return McpToolResult.error('A track needs a name.');
        e.renameTrack(t.id, name);
        return McpToolResult.json(edited(e, {'track': trackJson(e, t)}));
      },
    ),
    McpTool(
      name: 'rebind_sequencer_track',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Rebind Sequencer track',
      description: 'Binds a track to another level actor (a missing actor\'s track is fixed this way), one undo step.',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'track': trackArg,
        'actor': McpSchema.string('The level actor\'s id (list_actors), or its unique name.'),
      }, required: ['asset', 'track', 'actor']),
      handler: (args) async {
        final e = await editorFor(args);
        final t = trackOf(e, args.string('track'));
        final actor = actorOf(args.string('actor'));
        e.rebindActor(t.id, actor.id, actor.name);
        return McpToolResult.json(edited(e, {'track': trackJson(e, t)}));
      },
    ),
    McpTool(
      name: 'add_sequencer_key',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      title: 'Add Sequencer key',
      description: 'Keys a channel at a frame (clamped to the sequence length); a key already on that frame is '
          'updated. One undo step. Interpolation: ${interpolations.join(', ')} (default linear). $units',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'track': trackArg,
        'channel': channelArg,
        'frame': McpSchema.integer('The frame.'),
        'value': McpSchema.number('The value.'),
        'interpolation': McpSchema.string('The key\'s interpolation.', enumValues: interpolations),
      }, required: ['asset', 'track', 'channel', 'frame', 'value']),
      handler: (args) async {
        final e = await editorFor(args);
        final t = trackOf(e, args.string('track'));
        final c = channelOf(e, t, args.string('channel'));
        e.addKey(t.id, c.name, args.integer('frame'), args.number('value'),
            interpolation: interpOf(args.optionalString('interpolation') ?? 'linear'));
        final frame = args.integer('frame').clamp(0, e.lengthFrames);
        final i = c.keys.indexWhere((k) => k.frame == frame);
        return McpToolResult.json(edited(e, {'channel': c.name, 'key': keyJson(e, t, c, i)}));
      },
    ),
    McpTool(
      name: 'move_sequencer_key',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Move Sequencer key',
      description: 'Moves a key to another frame (clamped to the length; keys re-sort, so its index may change — the '
          'result gives the new one). One undo step.',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'track': trackArg,
        'channel': channelArg,
        'key': keyArg,
        'frame': McpSchema.integer('The new frame.'),
      }, required: ['asset', 'track', 'channel', 'key', 'frame']),
      handler: (args) async {
        final e = await editorFor(args);
        final t = trackOf(e, args.string('track'));
        final c = channelOf(e, t, args.string('channel'));
        final i = keyOf(c, args);
        final key = c.keys[i];
        e.moveKey(t.id, c.name, i, args.integer('frame'));
        return McpToolResult.json(edited(e, {'channel': c.name, 'key': keyJson(e, t, c, c.keys.indexOf(key))}));
      },
    ),
    McpTool(
      name: 'delete_sequencer_key',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      removesContent: true,
      title: 'Delete Sequencer key',
      description: 'Deletes a key (one undo step); later keys move down one index.',
      inputSchema: McpSchema.object({'asset': assetArg, 'track': trackArg, 'channel': channelArg, 'key': keyArg},
          required: ['asset', 'track', 'channel', 'key']),
      handler: (args) async {
        final e = await editorFor(args);
        final t = trackOf(e, args.string('track'));
        final c = channelOf(e, t, args.string('channel'));
        final i = keyOf(c, args);
        final frame = c.keys[i].frame;
        e.deleteKey(t.id, c.name, i);
        return McpToolResult.json(edited(e, {'deleted_frame': frame, 'channel': c.name}));
      },
    ),
    McpTool(
      name: 'set_sequencer_key',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set Sequencer key',
      description: 'Edits a key as the curve editor does: its value, interpolation, in / out tangents (value units per '
          'frame) and whether the tangents are broken (edited independently). One undo step.',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'track': trackArg,
        'channel': channelArg,
        'key': keyArg,
        'value': McpSchema.number('The value.'),
        'interpolation': McpSchema.string('The interpolation.', enumValues: interpolations),
        'in_tangent': McpSchema.number('The arriving tangent.'),
        'out_tangent': McpSchema.number('The leaving tangent.'),
        'tangent_broken': McpSchema.boolean('Edit the tangents independently.'),
      }, required: ['asset', 'track', 'channel', 'key']),
      handler: (args) async {
        final e = await editorFor(args);
        final t = trackOf(e, args.string('track'));
        final c = channelOf(e, t, args.string('channel'));
        final i = keyOf(c, args);
        if (args.has('value')) e.updateKey(t.id, c.name, i, value: args.number('value'));
        if (args.has('interpolation')) e.setKeyInterpolation(t.id, c.name, i, interpOf(args.string('interpolation')));
        if (args.has('tangent_broken')) e.setTangentBroken(t.id, c.name, i, args.boolean('tangent_broken'));
        if (args.has('in_tangent') || args.has('out_tangent')) {
          e.setKeyTangents(t.id, c.name, i, inTangent: args.optionalNumber('in_tangent'), outTangent: args.optionalNumber('out_tangent'));
        }
        return McpToolResult.json(edited(e, {'channel': c.name, 'key': keyJson(e, t, c, i)}));
      },
    ),
    McpTool(
      name: 'set_sequence_playback',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set sequence playback',
      description: 'The sequence\'s frame rate (fps > 0; a step on the undo stack), length (frames, at least 10; a '
          'step), and the transport\'s playback range [start, end] and looping (view state of the tab, not saved).',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'fps': McpSchema.integer('Frames per second.'),
        'length_frames': McpSchema.integer('The sequence length in frames (at least 10).'),
        'range': {'type': 'array', 'description': '[start, end] frames of the playback range.', 'items': {'type': 'integer'}},
        'looping': McpSchema.boolean('Loop playback over the range.'),
      }, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        if (args.has('fps')) {
          final fps = args.integer('fps');
          if (fps <= 0) return McpToolResult.error('fps must be greater than 0.');
          e.setFps(fps);
        }
        if (args.has('length_frames')) e.setLengthFrames(args.integer('length_frames'));
        if (args.has('range')) {
          final r = args['range'];
          if (r is! List || r.length != 2 || r.any((v) => v is! num)) {
            throw const JsonRpcException(JsonRpcErrorCode.invalidParams, '"range" must be [start, end] frames');
          }
          e.setPlaybackRange((r[0] as num).toInt(), (r[1] as num).toInt());
        }
        if (args.has('looping')) e.setLooping(args.boolean('looping'));
        return McpToolResult.json(edited(e, {
          'fps': e.fps,
          'length_frames': e.lengthFrames,
          'playback_range': [e.rangeStart, e.rangeEnd],
          'looping': e.isLooping,
        }));
      },
    ),
    McpTool(
      name: 'scrub_sequence',
      risk: McpToolRisk.editorState,
      groups: groups,
      idempotent: true,
      title: 'Scrub sequence',
      description: 'Moves the playhead to a frame; the bound level actors take the evaluated pose at once (the '
          'viewport, Outliner and Details show it). An open Sequencer tab is not brought forward, so the level can stay in '
          'front. $scrubNote',
      inputSchema: McpSchema.object({'asset': assetArg, 'frame': McpSchema.integer('The frame.')}, required: ['asset', 'frame']),
      handler: (args) async {
        final e = await transportFor(args);
        e.scrubToFrame(args.integer('frame'));
        return McpToolResult.json({
          'current_frame': e.playheadFrame,
          'previewing_level': e.isPreviewingLevel,
          'actors': [
            for (final t in e.tracks)
              if (vm.actors.any((a) => a.id == t.actorId))
                () {
                  final a = vm.actors.firstWhere((a) => a.id == t.actorId);
                  return {'id': a.id, 'name': a.name, 'location': a.location, 'rotation': a.rotation, 'scale': a.scale};
                }(),
          ],
        });
      },
    ),
    McpTool(
      name: 'stop_sequence',
      risk: McpToolRisk.editorState,
      groups: groups,
      idempotent: true,
      title: 'Stop sequence',
      description: 'The transport\'s Stop: stops playback, returns the playhead to the range start and restores every '
          'actor the preview moved to its authored transform.',
      inputSchema: McpSchema.object({'asset': assetArg}, required: ['asset']),
      handler: (args) async {
        final e = await transportFor(args);
        e.stop();
        return McpToolResult.json({'current_frame': e.playheadFrame, 'previewing_level': e.isPreviewingLevel});
      },
    ),
    McpTool(
      name: 'render_sequence',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      title: 'Render sequence',
      description: 'The Movie Render Queue: renders frames start_frame…end_frame (inclusive; default the playback range) '
          'offscreen through Filament at width × height (even, 16…4096) and fps (default the sequence\'s) as a PNG '
          'sequence plus render_manifest.json under saved/movie_renders/<output_name>/. Starts a job and returns '
          '{job_id} at once: poll get_job (progress, frame), wait_job, or cancel_job (stops between frames). The result '
          'has output_dir, frames and manifest. A sequence with unsaved edits is refused unless save_first is true. One '
          'movie render at a time.',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'width': McpSchema.integer('Width in pixels (even, 16…4096).'),
        'height': McpSchema.integer('Height in pixels (even, 16…4096).'),
        'fps': McpSchema.integer('Output frames per second; default the sequence fps.'),
        'start_frame': McpSchema.integer('First frame; default the playback range start.'),
        'end_frame': McpSchema.integer('Last frame (inclusive); default the playback range end.'),
        'warmup_frames': McpSchema.integer('Frames drawn but not written first (0…120). Default 0.'),
        'output_name': McpSchema.string('The output folder under saved/movie_renders/; default <sequence>_<timestamp>.'),
        'save_first': McpSchema.boolean('Save the sequence first when it has unsaved edits. Default false.'),
      }, required: ['asset', 'width', 'height']),
      handler: (args) async {
        final running = jobs.runningOn(kMcpMovieRender);
        if (running != null) {
          return McpToolResult.error('A movie render is already running: ${running.id} (${running.title}); wait_job or cancel_job it first.');
        }
        final e = await editorFor(args);
        if (e.isRendering) return McpToolResult.error('A movie render is already running (started from the Render dialog).');
        final width = args.integer('width'), height = args.integer('height');
        for (final (name, v) in [('width', width), ('height', height)]) {
          if (v < 16 || v > 4096 || v.isOdd) return McpToolResult.error('$name must be an even number between 16 and 4096.');
        }
        final start = args.integer('start_frame', fallback: e.rangeStart), end = args.integer('end_frame', fallback: e.rangeEnd);
        if (start < 0 || end < start) return McpToolResult.error('The frame range $start…$end is not valid (start ≤ end, both ≥ 0).');
        final warmup = args.integer('warmup_frames', fallback: 0);
        if (warmup < 0 || warmup > 120) return McpToolResult.error('warmup_frames must be between 0 and 120.');
        final name = (args.optionalString('output_name') ?? e.defaultRenderOutputName()).trim();
        if (name.isEmpty || RegExp(r'[\\/:*?"<>|]').hasMatch(name) || name == '.' || name == '..') {
          return McpToolResult.error('output_name "$name" is not a folder name.');
        }
        final saveFirst = args.boolean('save_first');
        if (e.isDirty && !saveFirst) {
          // The Render dialog's refusal, word for word (startRender's renderMessage).
          return McpToolResult.error('Save the sequence before rendering. Pass save_first: true (or call save_sequence) to render it.');
        }
        if (!SequencerOffscreenFrameSource.isSupported) {
          return McpToolResult.error('The offscreen Filament render is not available in this build (native assets missing).');
        }
        e.projectDirPath = vm.projectDirPath;
        final job = MovieRenderJob(
          sequence: e.data,
          sequenceName: e.fileBasename,
          width: width,
          height: height,
          fps: args.integer('fps', fallback: e.fps > 0 ? e.fps : 30),
          startFrame: start,
          endFrame: end,
          warmupFrames: warmup,
          outputDir: MovieRenderJob.resolveOutputDir(vm.projectDirPath, name),
        );
        final source = SequencerOffscreenFrameSource(actors: sequencerRenderActors(vm.actors));
        final McpJob started = jobs.start(
          'movie_render',
          title: 'Render ${e.fileBasename} → saved/movie_renders/$name ($width×$height, ${job.totalFrames} frames)',
          exclusive: kMcpMovieRender,
          cancel: e.cancelRender,
          run: (mcpJob) async {
            void follow() {
              final p = e.renderProgress;
              if (p == null) return;
              mcpJob.update(
                progress: p.total > 0 ? (p.framesDone.clamp(0, p.total) / p.total) : null,
                stage: '${p.phase.name} frame ${p.framesDone}/${p.total}',
              );
            }

            e.addListener(follow);
            try {
              final ok = await e.startRender(job, frameSource: source, saveFirst: saveFirst);
              follow();
              if (!ok) {
                throw McpJobFailure(e.renderError ?? e.renderMessage ?? 'The render stopped before the last frame.');
              }
              return {
                'output_dir': 'saved/movie_renders/$name',
                'frames': job.totalFrames,
                'manifest': 'saved/movie_renders/$name/render_manifest.json',
              };
            } finally {
              e.removeListener(follow);
            }
          },
        );
        return McpToolResult.json({
          'job_id': started.id,
          'state': started.state.name,
          'output_dir': 'saved/movie_renders/$name',
          'total_frames': job.totalFrames,
        });
      },
    ),
    McpTool(
      name: 'save_sequence',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Save sequence',
      description: 'Writes the Level Sequence .lmas (the tab\'s Save).',
      inputSchema: McpSchema.object({'asset': assetArg}, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        if (!await e.save()) return McpToolResult.error('The sequence was not saved; see the Output Log.');
        return McpToolResult.json({'saved': sessions.resolveAsset(args.string('asset')).relativePath, 'is_dirty': e.isDirty});
      },
    ),
  ]);
}
