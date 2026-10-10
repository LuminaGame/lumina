part of '../node_library.dart';

/// The game user settings setters that only stage their value in
/// `LuminaUserSettingsSubsystem`: nothing changes until Apply Scalability
/// Settings runs. Each gets [LuminaBlueprintNodeSpec.requiresApply] and its
/// description followed by [LuminaBlueprintNodeSpec.stagedNote].
const Map<String, String> _stagedSettingDescriptions = {
  'set_shadow_quality': 'Chooses the shadow quality tier (Low, Medium, High, Epic, Cinematic).',
  'set_anti_aliasing_quality': 'Chooses the anti-aliasing mode (None, FXAA, MSAA, TAA).',
  'set_post_processing_quality': 'Chooses the post-processing quality tier (Low, Medium, High, Epic, Cinematic).',
  'set_texture_quality': 'Chooses the texture quality tier (Low, Medium, High, Epic, Cinematic).',
  'set_shading_quality': 'Chooses the shading quality tier (Low, Medium, High, Epic, Cinematic).',
  'set_resolution_scale': 'Chooses the internal render resolution in percent (25 to 200, 100 is native).',
  'set_target_fps': 'Chooses the target frame rate (0 is unlimited).',
  'set_vsync_enabled': 'Turns vertical synchronization on or off.',
  'set_ray_tracing_enabled': 'Turns ray tracing on or off (falls back when the GPU cannot).',
  'set_ray_traced_shadows_enabled': "Turns the sun's ray-traced shadows on or off.",
  'set_restir_enabled': 'Turns ReSTIR ray-traced direct lighting on or off.',
  'set_restir_candidates': 'Chooses how many lights ReSTIR samples per pixel (1 to 64).',
  'set_restir_spatial_samples': 'Chooses how many neighbouring reservoirs ReSTIR merges per pixel (0 to 8).',
  'set_upscaler': 'Chooses the upscaler: None, FSR3, DLSS or DLSS RR.',
  'set_upscaler_quality': 'Chooses the upscaler quality: Native AA, Quality, Balanced, Performance or Ultra Performance.',
  'set_upscaler_sharpness': 'Chooses the sharpening after the upscale (0 to 1; DLSS ignores it).',
  'set_frame_generation_enabled': 'Turns frame generation on or off.',
  'set_frame_generator': 'Chooses who generates the frames: FSR3 or DLSS.',
  'set_dlss_generated_frames': 'Chooses how many frames DLSS generates per rendered frame (1 to 5; 1 is 2x).',
  'set_screen_resolution': 'Chooses the screen resolution in physical pixels (0 x 0 is native); '
      'Set Screen Resolution And Apply applies it at once.',
  'set_fullscreen_monitor': 'Chooses the monitor the game runs on (see Get Monitor Count).',
};

/// Settings nodes that act at once (no [LuminaBlueprintNodeSpec.requiresApply]).
const Map<String, String> _immediateSettingDescriptions = {
  'set_overall_scalability_level':
      'Picks a scalability preset (Low, Medium, High, Epic, Cinematic) and applies every quality tier at once.',
  'set_view_distance_quality': 'Picks a view distance tier and updates the cameras at once.',
  'set_view_distance': 'Sets the view distance in centimetres and updates the cameras at once.',
  'apply_scalability_settings': 'Applies every staged game user setting: qualities, resolution scale, ray tracing, '
      'upscaler, frame generation, screen resolution and monitor (the resolution and monitor are also saved).',
  'set_screen_resolution_and_apply': 'Chooses the screen resolution in physical pixels (0 x 0 is native), applies it '
      'at once and saves it; other staged settings still wait for Apply Scalability Settings.',
  'set_fullscreen_mode': 'Switches the window to Windowed or Borderless Fullscreen at once and saves the choice.',
  'toggle_fullscreen': 'Switches between Windowed and Borderless Fullscreen at once and saves the choice.',
};

/// [nodes] with the settings descriptions and staged flags.
List<LuminaBlueprintNodeSpec> _markStagedSettings(List<LuminaBlueprintNodeSpec> nodes) => [
      for (final s in nodes)
        if (_stagedSettingDescriptions[s.id] case final d?)
          _describedSpec(s, '$d ${LuminaBlueprintNodeSpec.stagedNote}', requiresApply: true)
        else if (_immediateSettingDescriptions[s.id] case final d?)
          _describedSpec(s, d, requiresApply: false)
        else
          s,
    ];

LuminaBlueprintNodeSpec _describedSpec(LuminaBlueprintNodeSpec s, String description, {required bool requiresApply}) =>
    LuminaBlueprintNodeSpec(
      id: s.id,
      title: s.title,
      category: s.category,
      kind: s.kind,
      inputs: s.inputs,
      outputs: s.outputs,
      keywords: s.keywords,
      headerColor: s.headerColor,
      deprecation: s.deprecation,
      unsupported: s.unsupported,
      tooltip: s.tooltip ?? description,
      requiresApply: requiresApply,
    );
