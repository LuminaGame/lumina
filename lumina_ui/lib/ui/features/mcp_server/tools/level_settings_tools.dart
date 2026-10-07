import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/navigation_editor_state.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/environment_lighting_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/navigation_editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_editor_sessions.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/blueprint_tool_support.dart' show mcpRefuseWhilePlaying;
import 'package:lumina_ui/ui/features/mcp_server/tools/core_tools.dart' show mcpUndoState;

/// The data-layer states the runtime's `DataLayerState` has.
const List<String> kDataLayerStates = ['unloaded', 'loaded', 'activated'];

/// The level's own settings as MCP tools: World Partition and
/// its data layers (the Details panel with nothing selected), the
/// environment (Tools → Environment Lighting's view model) and navigation
/// (Tools → Navigation's view model, Build → Build Navigation). Every edit is
/// one level undo step.
void registerLevelSettingsTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions) {
  const level = {McpToolGroups.level};

  Map<String, Object?> worldPartition() => {
        'enabled': vm.worldPartitionEnabled,
        'authored': vm.levelWorldPartition.isNotEmpty,
        'cell_size': vm.worldPartitionCellSize,
        'loading_range': vm.worldPartitionLoadingRange,
        'max_cell_transitions_per_tick': vm.worldPartitionMaxCellTransitionsPerTick,
        'data_layers': [
          for (final (i, l) in vm.worldPartitionDataLayers.indexed)
            {'index': i, 'name': l['name'], 'initial_state': l['initialState'] ?? 'unloaded', 'is_runtime': l['isRuntime'] ?? true},
        ],
      };

  Map<String, Object?> environmentOf(EnvironmentState s, {required bool authored}) => {
        'authored': authored,
        'time_of_day': s.timeOfDay,
        'sun_elevation': s.sunElevationDeg,
        'sun_azimuth': s.sunAzimuthDeg,
        'sun_intensity_lux': s.sunIntensityLux,
        'sun_kelvin': s.sunKelvin,
        'sun_color_override': s.sunColorOverride,
        'sun_color': s.sunColorHex,
        'cast_shadows': s.castShadows,
        'sun_disc_visible': s.sunDiscVisible,
        'sky_mode': s.skyMode.name,
        'sky_color': s.skyColorHex,
        'sky_environment_asset': s.skyEnvironmentAssetPath,
        'sky_intensity': s.skyIntensity,
        'ibl_intensity': s.iblIntensity,
        'sky_rotation': s.skyRotationDeg,
        'follow_time_of_day': s.followTimeOfDay,
        'fog_enabled': s.fogEnabled,
        'fog_density': s.fogDensity,
        'fog_height_falloff': s.fogHeightFalloff,
        'fog_color': s.fogColorHex,
        'exposure': s.exposure,
        'bloom_intensity': s.bloomIntensity,
        'bloom_threshold': s.bloomThreshold,
        'vignette': s.vignette,
        'saturation': s.saturation,
        'contrast': s.contrast,
        'gamma': s.gamma,
      };

  Map<String, Object?> environment() {
    final bound = sessions.boundEnvironment;
    if (bound != null) return environmentOf(bound.state, authored: true);
    final section = vm.levelEnvironment;
    return environmentOf(
      section.isEmpty ? EnvironmentState.defaults() : EnvironmentState.fromSection(Map<String, dynamic>.from(section)),
      authored: section.isNotEmpty,
    );
  }

  Map<String, Object?> navConfig(NavigationEditorConfig c) => {
        'cell_size': c.cellSize,
        'agent_radius': c.agentRadius,
        'agent_height': c.agentHeight,
        'max_step_height': c.maxStepHeight,
        'walkable_layer_mask': c.walkableLayerMask,
        'auto_rebuild': c.autoRebuild,
      };

  Map<String, Object?>? buildOf(NavBuildResult? b) => b == null
      ? null
      : {
          'walkable_cells': b.walkableCells,
          'cols': b.cols,
          'rows': b.rows,
          'cell_size': b.cellSize,
          'obstacle_count': b.obstacleCount,
          'volume_count': b.volumeCount,
          'duration_ms': b.durationMs,
        };

  Map<String, Object?> navigation() {
    final bound = sessions.boundNavigation;
    final section = vm.levelNavigation;
    final config = bound?.config ??
        (section.isEmpty ? NavigationEditorConfig.defaults() : NavigationEditorConfig.fromSection(Map<String, dynamic>.from(section)));
    return {
      'config': navConfig(config),
      'volumes': [
        for (final v in vm.actors.where(NavMeshBoundsVolume.isVolume))
          {'id': v.id, 'name': v.name, 'location': v.location, 'extent_m': v.scale},
      ],
      'last_build': buildOf(bound?.lastBuild),
      'stale': bound?.isStale ?? false,
    };
  }

  /// The Details panel shows the level's own settings when nothing is
  /// selected: a level-settings edit clears the selection.
  void showLevelSettings() {
    vm.clearSelection();
    vm.selectTab(0);
  }

  int? layerIndexOf(Object? layer) {
    final layers = vm.worldPartitionDataLayers;
    if (layer is num && layer == layer.roundToDouble()) {
      final i = layer.toInt();
      return i >= 0 && i < layers.length ? i : null;
    }
    if (layer is String) {
      final i = layers.indexWhere((l) => l['name'] == layer);
      return i < 0 ? null : i;
    }
    return null;
  }

  McpToolResult noLayer(Object? layer) => McpToolResult.error('No data layer $layer. Layers: '
      '${vm.worldPartitionDataLayers.indexed.map((e) => '${e.$1} "${e.$2['name']}"').join(', ')}'
      '${vm.worldPartitionDataLayers.isEmpty ? '(none; add_data_layer adds one)' : ''}.');

  final colour = RegExp(r'^#[0-9A-Fa-f]{6}$');

  /// set_level_environment's fields: the argument, its JSON type and the
  /// Environment Lighting setter, in the order they apply (the mode and the
  /// override before the values they gate).
  final envFields = <(String, String, String, void Function(EnvironmentLightingViewModel, Object))>[
    ('sky_mode', 'string', '"color" or "environment"', (e, v) => e.setSkyMode(EnvironmentSkyMode.values.byName(v as String))),
    ('sky_environment_asset', 'string', 'a .ktx environment map in the project', (e, v) => e.setSkyEnvironmentAsset(v as String)),
    ('sun_color_override', 'boolean', 'use sun_color instead of the Kelvin ramp', (e, v) => e.setSunColorOverride(v as bool)),
    ('time_of_day', 'number', 'hours, 0–24 (drives the sun\'s elevation and azimuth)', (e, v) => e.setTimeOfDay((v as num).toDouble())),
    ('sun_intensity_lux', 'number', 'lux, 0–200000', (e, v) => e.setSunIntensity((v as num).toDouble())),
    ('sun_kelvin', 'number', 'colour temperature, 1500–15000 K', (e, v) => e.setSunKelvin((v as num).toDouble())),
    ('sun_color', 'color', '"#RRGGBB"', (e, v) => e.setSunColorHex(v as String)),
    ('cast_shadows', 'boolean', 'the sun casts shadows', (e, v) => e.setCastShadows(v as bool)),
    ('sun_disc_visible', 'boolean', 'the sun disc shows in the sky', (e, v) => e.setSunDiscVisible(v as bool)),
    ('sky_color', 'color', '"#RRGGBB"', (e, v) => e.setSkyColorHex(v as String)),
    ('sky_intensity', 'number', '0–200000', (e, v) => e.setSkyIntensity((v as num).toDouble())),
    ('ibl_intensity', 'number', '0–200000', (e, v) => e.setIblIntensity((v as num).toDouble())),
    ('sky_rotation', 'number', 'degrees', (e, v) => e.setSkyRotation((v as num).toDouble())),
    ('follow_time_of_day', 'boolean', 'the sky follows the time of day', (e, v) => e.setFollowTimeOfDay(v as bool)),
    ('fog_enabled', 'boolean', 'height fog on', (e, v) => e.setFogEnabled(v as bool)),
    ('fog_density', 'number', '0–0.05', (e, v) => e.setFogDensity((v as num).toDouble())),
    ('fog_height_falloff', 'number', '0–10', (e, v) => e.setFogHeightFalloff((v as num).toDouble())),
    ('fog_color', 'color', '"#RRGGBB"', (e, v) => e.setFogColorHex(v as String)),
    ('exposure', 'number', 'EV, −6–6', (e, v) => e.setExposure((v as num).toDouble())),
    ('bloom_intensity', 'number', 'bloom strength', (e, v) => e.setBloomIntensity((v as num).toDouble())),
    ('bloom_threshold', 'number', '1–100000', (e, v) => e.setBloomThreshold((v as num).toDouble())),
    ('vignette', 'number', '0–1', (e, v) => e.setVignette((v as num).toDouble())),
    ('saturation', 'number', '0–2', (e, v) => e.setSaturation((v as num).toDouble())),
    ('contrast', 'number', '0.5–2', (e, v) => e.setContrast((v as num).toDouble())),
    ('gamma', 'number', '0.2–3', (e, v) => e.setGamma((v as num).toDouble())),
  ];

  final navFields = <(String, String, void Function(NavigationEditorViewModel, Object))>[
    ('cell_size', 'cm, ${NavigationEditorConfig.minCellSize.toInt()}–${NavigationEditorConfig.maxCellSize.toInt()}',
        (n, v) => n.setCellSize((v as num).toDouble())),
    ('agent_radius', 'cm, 0–${NavigationEditorConfig.maxAgentRadius.toInt()}', (n, v) => n.setAgentRadius((v as num).toDouble())),
    ('agent_height', 'cm, ${NavigationEditorConfig.minAgentHeight.toInt()}–${NavigationEditorConfig.maxAgentHeight.toInt()}',
        (n, v) => n.setAgentHeight((v as num).toDouble())),
    ('max_step_height', 'cm, 0–${NavigationEditorConfig.maxStepHeightLimit.toInt()}', (n, v) => n.setMaxStepHeight((v as num).toDouble())),
  ];

  registry.registerAll([
    McpTool(
      name: 'get_level_settings',
      risk: McpToolRisk.readOnly,
      groups: level,
      title: 'Get level settings',
      description: 'The open level\'s own settings: world_partition (enabled, cell_size and loading_range in cm, '
          'max_cell_transitions_per_tick, data_layers [{index, name, initial_state}]), actor_cells (the grid cell each '
          'actor falls in, as the Outliner shows it; null without a partition), environment (the Environment '
          'Lighting fields set_level_environment takes) and navigation (config, NavMeshBoundsVolume actors, the last '
          'build). Actors are not assigned to data layers: no editor view does that.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) => McpToolResult.json({
        'level': vm.project.activeLevel,
        'world_partition': worldPartition(),
        'actor_cells': [
          for (final a in vm.actors)
            if (a.type != 'Folder') {'id': a.id, 'name': a.name, 'cell': vm.worldPartitionCellLabel(a)},
        ],
        'environment': environment(),
        'navigation': navigation(),
      }),
    ),
    McpTool(
      name: 'set_world_partition',
      risk: McpToolRisk.mutating,
      groups: level,
      idempotent: true,
      title: 'Set World Partition',
      description: 'The level\'s World Partition section (Details panel with nothing selected): enabled, cell_size '
          '(cm, > 0), loading_range (cm, ≥ 0) and max_cell_transitions_per_tick (≥ 1), clamped as the panel clamps. '
          'Enabling a level without a section seeds the runtime\'s defaults. One undo step; the values reach the '
          'generated LuminaWorldPartitionSubsystem on save_level.',
      inputSchema: McpSchema.object({
        'enabled': McpSchema.boolean('Turn the partition on or off (off keeps the authored values).'),
        'cell_size': McpSchema.number('Grid cell edge in cm (default 12800).'),
        'loading_range': McpSchema.number('Streaming radius in cm (default 25000).'),
        'max_cell_transitions_per_tick': McpSchema.integer('Cell state transitions per tick (default 10).'),
      }),
      handler: (args) {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        if (!['enabled', 'cell_size', 'loading_range', 'max_cell_transitions_per_tick'].any(args.has)) {
          return McpToolResult.error('Give at least one of enabled, cell_size, loading_range, max_cell_transitions_per_tick.');
        }
        showLevelSettings();
        if (args.has('enabled')) vm.setWorldPartitionEnabled(args.boolean('enabled'));
        if (args.has('cell_size')) vm.setWorldPartitionCellSize(args.number('cell_size'));
        if (args.has('loading_range')) vm.setWorldPartitionLoadingRange(args.number('loading_range'));
        if (args.has('max_cell_transitions_per_tick')) {
          vm.setWorldPartitionMaxCellTransitionsPerTick(args.integer('max_cell_transitions_per_tick'));
        }
        return McpToolResult.json({'world_partition': worldPartition(), 'undo': mcpUndoState(vm.transactions)});
      },
    ),
    McpTool(
      name: 'add_data_layer',
      risk: McpToolRisk.mutating,
      groups: level,
      idempotent: false,
      title: 'Add data layer',
      description: 'World Partition → Data Layers → Add: a runtime data layer (initial state "unloaded") the '
          'generated code registers with LuminaDataLayerManager. The name is made unique ("DataLayer" → '
          '"DataLayer1"); returns it. One undo step. Enables World Partition with its defaults when the level has no '
          'section yet. There is no per-actor data layer assignment in the editor.',
      inputSchema: McpSchema.object({'name': McpSchema.string('The layer name. Default "DataLayer".')}),
      handler: (args) {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        showLevelSettings();
        final requested = args.optionalString('name')?.trim();
        final name = vm.addWorldPartitionDataLayer((requested == null || requested.isEmpty) ? 'DataLayer' : requested);
        return McpToolResult.json({
          'name': name,
          'index': vm.worldPartitionDataLayers.indexWhere((l) => l['name'] == name),
          'world_partition': worldPartition(),
          'undo': mcpUndoState(vm.transactions),
        });
      },
    ),
    McpTool(
      name: 'set_data_layer',
      risk: McpToolRisk.mutating,
      groups: level,
      idempotent: true,
      title: 'Set data layer',
      description: 'Renames a data layer and/or sets its initial state (${kDataLayerStates.join(' / ')}), as its '
          'Details row does. layer is its index or name. One undo step.',
      inputSchema: McpSchema.object({
        'layer': McpSchema.any('The layer\'s index (0-based) or name.'),
        'name': McpSchema.string('A new name.'),
        'initial_state': McpSchema.string('The initial state: ${kDataLayerStates.join(', ')}.'),
      }, required: ['layer']),
      handler: (args) {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final index = layerIndexOf(args['layer']);
        if (index == null) return noLayer(args['layer']);
        final state = args.optionalString('initial_state');
        if (state != null && !kDataLayerStates.contains(state)) {
          return McpToolResult.error('"$state" is not a data layer state. States: ${kDataLayerStates.join(', ')}.');
        }
        final name = args.optionalString('name')?.trim();
        if (name == null && state == null) return McpToolResult.error('Give name and/or initial_state.');
        if (name != null) {
          if (name.isEmpty) return McpToolResult.error('A data layer name cannot be empty.');
          final clash = vm.worldPartitionDataLayers.indexed.any((e) => e.$1 != index && e.$2['name'] == name);
          if (clash) return McpToolResult.error('Another data layer is already named "$name".');
        }
        showLevelSettings();
        if (name != null) vm.setWorldPartitionDataLayerName(index, name);
        if (state != null) vm.setWorldPartitionDataLayerState(index, state);
        return McpToolResult.json({'world_partition': worldPartition(), 'undo': mcpUndoState(vm.transactions)});
      },
    ),
    McpTool(
      name: 'remove_data_layer',
      risk: McpToolRisk.mutating,
      groups: level,
      idempotent: false,
      removesContent: true,
      title: 'Remove data layer',
      description: 'Removes a data layer (its Details row × ), by index or name. One undo step.',
      inputSchema: McpSchema.object({'layer': McpSchema.any('The layer\'s index (0-based) or name.')}, required: ['layer']),
      handler: (args) {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final index = layerIndexOf(args['layer']);
        if (index == null) return noLayer(args['layer']);
        showLevelSettings();
        vm.removeWorldPartitionDataLayer(index);
        return McpToolResult.json({'world_partition': worldPartition(), 'undo': mcpUndoState(vm.transactions)});
      },
    ),
    McpTool(
      name: 'set_level_environment',
      risk: McpToolRisk.mutating,
      groups: level,
      idempotent: true,
      title: 'Set level environment',
      description: 'Tools → Environment Lighting: sets any of the sun, sky, fog and post-process fields through the '
          'Environment Lighting view model (opening its tab; the Sun and SkyAmbience actors are created if missing). '
          'Values are clamped to the mixer\'s ranges. The whole call is one undo step; the values are saved in the '
          'level\'s environment section and on its Sun / SkyAmbience actors. Fields: '
          '${envFields.map((f) => '${f.$1} (${f.$3})').join('; ')}.',
      inputSchema: McpSchema.object({
        for (final f in envFields)
          f.$1: switch (f.$2) {
            'number' => McpSchema.number(f.$3),
            'boolean' => McpSchema.boolean(f.$3),
            _ => McpSchema.string(f.$3),
          },
      }),
      handler: (args) async {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final given = [for (final f in envFields) if (args.has(f.$1)) f];
        if (given.isEmpty) return McpToolResult.error('Give at least one field: ${envFields.map((f) => f.$1).join(', ')}.');
        // Validate everything before touching anything.
        for (final f in given) {
          final v = args[f.$1];
          if (f.$2 == 'color' && !(v is String && colour.hasMatch(v))) {
            return McpToolResult.error('${f.$1} takes a "#RRGGBB" colour; got $v.');
          }
        }
        final mode = args.optionalString('sky_mode');
        if (mode != null && !EnvironmentSkyMode.values.any((m) => m.name == mode)) {
          return McpToolResult.error('"$mode" is not a sky mode. Modes: ${EnvironmentSkyMode.values.map((m) => m.name).join(', ')}.');
        }
        final env = await sessions.environment();
        final asset = args.optionalString('sky_environment_asset');
        if (asset != null && !env.hdriAssets.contains(asset)) {
          return McpToolResult.error('"$asset" is not an environment map of the project. Maps: '
              '${env.hdriAssets.isEmpty ? '(none: import a .ktx)' : env.hdriAssets.join(', ')}.');
        }
        for (final f in given) {
          f.$4(env, args[f.$1]!);
        }
        return McpToolResult.json({
          'environment': environmentOf(env.state, authored: true),
          'open_tab': vm.currentTab.category,
          'undo': mcpUndoState(vm.transactions),
        });
      },
    ),
    McpTool(
      name: 'reset_level_environment',
      risk: McpToolRisk.mutating,
      groups: level,
      idempotent: true,
      title: 'Reset level environment',
      description: 'Environment Lighting → Reset: every sun, sky, fog and post-process field back to the defaults, as '
          'one undo step (opening the Environment Lighting tab).',
      inputSchema: McpSchema.object(const {}),
      handler: (args) async {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final env = await sessions.environment();
        env.resetToDefaults();
        return McpToolResult.json({'environment': environmentOf(env.state, authored: true), 'undo': mcpUndoState(vm.transactions)});
      },
    ),
    McpTool(
      name: 'set_navigation_settings',
      risk: McpToolRisk.mutating,
      groups: level,
      idempotent: true,
      title: 'Set navigation settings',
      description: 'Tools → Navigation: the navigation grid\'s settings through the Navigation view model (opening its '
          'tab), clamped to its ranges: ${navFields.map((f) => '${f.$1} (${f.$2})').join(', ')}, walkable_layer_mask '
          '(an integer bit mask) and auto_rebuild. One undo step. Bounds are NavMeshBoundsVolume actors: place them '
          'with spawn_actor, then build_navigation.',
      inputSchema: McpSchema.object({
        for (final f in navFields) f.$1: McpSchema.number(f.$2),
        'walkable_layer_mask': McpSchema.integer('The collision layers the agent walks on, as a bit mask.'),
        'auto_rebuild': McpSchema.boolean('Rebuild after every scene or settings change.'),
      }),
      handler: (args) async {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final keys = [...navFields.map((f) => f.$1), 'walkable_layer_mask', 'auto_rebuild'];
        if (!keys.any(args.has)) return McpToolResult.error('Give at least one of ${keys.join(', ')}.');
        final nav = await sessions.navigation();
        for (final f in navFields) {
          if (args.has(f.$1)) f.$3(nav, args[f.$1]!);
        }
        if (args.has('walkable_layer_mask')) nav.setWalkableLayerMask(args.integer('walkable_layer_mask'));
        if (args.has('auto_rebuild')) nav.setAutoRebuild(args.boolean('auto_rebuild'));
        return McpToolResult.json({
          'config': navConfig(nav.config),
          'open_tab': vm.currentTab.category,
          'undo': mcpUndoState(vm.transactions),
        });
      },
    ),
    McpTool(
      name: 'build_navigation',
      risk: McpToolRisk.mutating,
      groups: level,
      idempotent: true,
      title: 'Build navigation',
      description: 'Build → Build Navigation: runs the real grid bake inside the level\'s NavMeshBoundsVolume actors '
          '(opening the Navigation tab) and returns {walkable_cells, cols, rows, cell_size, obstacle_count, '
          'volume_count, duration_ms}. A tool error without a volume. The baked grid is derived data, not saved.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) async {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final nav = await sessions.navigation();
        if (!nav.canBuild) return McpToolResult.error('Cannot build navigation: ${nav.buildDisabledReason}');
        final before = nav.buildCount;
        vm.requestNavigationBuild();
        // The open Navigation view model bakes on the request; build here when
        // it did not (it was busy, or not listening yet).
        if (nav.buildCount == before) nav.build();
        final result = buildOf(nav.lastBuild);
        if (result == null || nav.buildCount == before) {
          return McpToolResult.error('The navigation build failed: ${nav.buildError ?? 'see the Output Log'}.');
        }
        return McpToolResult.json(result);
      },
    ),
  ]);
}
