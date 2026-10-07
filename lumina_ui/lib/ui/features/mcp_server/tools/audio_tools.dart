import 'package:lumina_editor_data/lumina_editor.dart' show AssetType, LuminaAttenuationModel;

import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/audio_editor_state.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/audio_editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_editor_sessions.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';

/// The Sound editor as MCP tools: the decoded wave's facts,
/// the sound's settings (volume, pitch, class, looping, spatialisation,
/// attenuation), a gain-at-distance probe evaluated by the runtime's own
/// attenuation, Save. No playback: an agent cannot hear.
void registerAudioTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions) {
  const groups = {McpToolGroups.audio, McpToolGroups.assetEditors};
  const noUndo = 'Not undoable (the Sound editor keeps no undo stack); close the tab without saving to discard.';
  final classes = [for (final c in AudioSoundClass.values) c.label];
  final models = [for (final m in LuminaAttenuationModel.values) m.name];
  final assetArg = McpSchema.string('The sound asset (list_assets type "audio"): project-relative path or unique file name.');

  Future<AudioEditorViewModel> editorFor(McpArgs args) =>
      sessions.audio(sessions.resolveAsset(args.string('asset'), type: AssetType.audio));

  Map<String, Object?> settingsJson(AudioEditorViewModel e) {
    final s = e.settings;
    return {
      'volume': s.volumeMultiplier,
      'pitch': s.pitchMultiplier,
      'pitch_randomization': s.pitchRandomization,
      'sound_class': s.soundClass.label,
      'looping': s.looping,
      'spatialized': s.spatialized,
      'attenuation_model': s.attenuation.model.name,
      'inner_radius_cm': s.attenuation.innerRadius,
      'falloff_distance_cm': s.attenuation.falloffDistance,
    };
  }

  Map<String, Object?> audioJson(AudioEditorViewModel e, String asset) {
    final a = e.audio;
    return {
      'asset': asset,
      'sample_rate': a?.sampleRate,
      'channels': a?.channels,
      'bit_depth': a?.bitDepth,
      'float': a?.isFloat,
      'duration_s': e.duration,
      'frame_count': a?.frameCount,
      'error': e.hasError ? e.errorMessage : null,
      'settings': settingsJson(e),
      'is_dirty': e.isDirty,
    };
  }

  registry.registerAll([
    McpTool(
      name: 'get_audio',
      risk: McpToolRisk.readOnly,
      groups: groups,
      title: 'Get sound',
      description: 'The Sound editor\'s asset (opens its tab): sample rate, channels, bit depth, duration in seconds, '
          'frame count, and the settings (volume, pitch, pitch randomization, sound class, looping, spatialized, '
          'attenuation model, inner radius and falloff distance in cm), unsaved changes.',
      inputSchema: McpSchema.object({'asset': assetArg}, required: ['asset']),
      handler: (args) async => McpToolResult.json(audioJson(await editorFor(args), args.string('asset'))),
    ),
    McpTool(
      name: 'set_audio_settings',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set sound settings',
      description: 'The Details panel: volume (0–2), pitch (0.5–2), pitch_randomization (0–1), sound_class '
          '(${classes.join(', ')}), looping, spatialized, attenuation_model (${models.join(', ')}), inner_radius_cm '
          '(full volume inside) and falloff_distance_cm (to silence beyond the inner radius). The inner radius is '
          'applied first; as its handle does, it keeps the outer edge still. $noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'volume': McpSchema.number('Volume multiplier 0–2.'),
        'pitch': McpSchema.number('Pitch multiplier 0.5–2.'),
        'pitch_randomization': McpSchema.number('Random pitch spread 0–1.'),
        'sound_class': McpSchema.string('Sound class.', enumValues: classes),
        'looping': McpSchema.boolean('Loop playback.'),
        'spatialized': McpSchema.boolean('3D (attenuated, panned) sound.'),
        'attenuation_model': McpSchema.string('Attenuation curve.', enumValues: models),
        'inner_radius_cm': McpSchema.number('Full-volume radius in cm.'),
        'falloff_distance_cm': McpSchema.number('Distance beyond the inner radius over which the sound fades, in cm.'),
      }, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        final volume = args.optionalNumber('volume');
        if (volume != null) e.setVolumeMultiplier(volume);
        final pitch = args.optionalNumber('pitch');
        if (pitch != null) e.setPitchMultiplier(pitch);
        final random = args.optionalNumber('pitch_randomization');
        if (random != null) e.setPitchRandomization(random);
        final cls = args.optionalString('sound_class');
        if (cls != null) e.setSoundClass(AudioSoundClass.fromLabel(cls));
        if (args.has('looping')) e.setLooping(args.boolean('looping'));
        if (args.has('spatialized')) e.setSpatialized(args.boolean('spatialized'));
        final model = args.optionalString('attenuation_model');
        if (model != null) e.setAttenuationModel(LuminaAttenuationModel.values.byName(model));
        final inner = args.optionalNumber('inner_radius_cm');
        final falloff = args.optionalNumber('falloff_distance_cm');
        if ((inner != null && inner < 0) || (falloff != null && falloff < 0)) {
          return McpToolResult.error('inner_radius_cm and falloff_distance_cm must be ≥ 0.');
        }
        if (inner != null) {
          // The inner handle cannot pass the outer edge: move the edge first.
          if (inner > e.outerDistance) e.setFalloffDistance(inner - e.settings.attenuation.innerRadius);
          e.setInnerRadius(inner);
        }
        if (falloff != null) e.setFalloffDistance(falloff);
        return McpToolResult.json(audioJson(e, args.string('asset')));
      },
    ),
    McpTool(
      name: 'probe_audio_attenuation',
      risk: McpToolRisk.readOnly,
      groups: groups,
      title: 'Probe attenuation',
      description: 'The attenuation plot\'s probe: the gain (0–1) the runtime\'s attenuation gives at distance_cm '
          '(default 1200) with the current settings, before the volume multiplier (effective_gain includes it). '
          'Reads only: the plot\'s own probe marker stays where the user left it.',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'distance_cm': McpSchema.number('Distance from the source in cm; default 1200.'),
      }, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        final distance = args.number('distance_cm', fallback: 1200);
        if (distance < 0) return McpToolResult.error('distance_cm must be ≥ 0.');
        return McpToolResult.json({
          'distance_cm': distance,
          'gain': e.gainAt(distance),
          'effective_gain': e.gainAt(distance) * e.settings.volumeMultiplier,
          'inner_radius_cm': e.settings.attenuation.innerRadius,
          'outer_distance_cm': e.outerDistance,
          'attenuation_model': e.settings.attenuation.model.name,
        });
      },
    ),
    McpTool(
      name: 'save_audio',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Save sound',
      description: 'The tab\'s Save: writes the settings into the .lmas metadata (audio_settings); the wave is unchanged.',
      inputSchema: McpSchema.object({'asset': assetArg}, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        if (!await e.save()) return McpToolResult.error('Save failed; see the Output Log.');
        return McpToolResult.json(audioJson(e, args.string('asset')));
      },
    ),
  ]);
}
