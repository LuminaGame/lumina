import '../../main_editor/services/snap_service.dart';
import '../../main_editor/view_models/editor_view_model.dart';
import '../services/mcp_protocol.dart';
import '../services/mcp_tool.dart';

/// The six show flags the viewport toolbar's Show menu toggles.
const List<String> kMcpShowFlags = [
  'Grid',
  'Transform Gizmo',
  'Selection Bounds',
  'Collision',
  'Actor Icons & Labels',
  'Ground Drop Shadows',
];

/// The buffers the toolbar's Buffer Visualization menu offers.
const List<String> kMcpBufferVisualizations = ['Base Color', 'Opacity', 'Roughness', 'Metallic', 'Emissive', 'Normal'];

/// The quality presets of the viewport's quality popover.
const List<String> kMcpQualityPresets = ['low', 'medium', 'high', 'epic', 'cinematic'];

/// The viewport toolbar as MCP tools: snapping and the grid,
/// show flags, buffer visualisation and render quality. These are editor
/// settings, not level content: no undo step, persisted with the project's
/// editor viewport / quality settings exactly as the toolbar persists them.
void registerViewportSettingsTools(McpToolRegistry registry, EditorViewModel vm) {
  const view = {McpToolGroups.view};

  Map<String, Object?> settings() => {
        'snapping': {
          'translate_enabled': vm.translateSnapEnabled,
          'translate_step': vm.translateSnapStep,
          'rotate_enabled': vm.rotateSnapEnabled,
          'rotate_step': vm.rotateSnapStep,
          'scale_enabled': vm.scaleSnapEnabled,
          'scale_step': vm.scaleSnapStep,
        },
        'grid_visible': vm.gridVisible,
        'grid_step': vm.editorGridStep,
        'show_flags': {for (final f in kMcpShowFlags) f: vm.showFlags[f] ?? true},
        'view_mode': vm.viewMode,
        'buffer_visualization': vm.bufferVisualization,
        'camera_speed': vm.cameraSpeedScalar,
        'quality': {
          'preset': vm.qualityPreset,
          'resolution_scale': vm.resolutionScale,
          'ssao': vm.ssaoEnabled,
          'bloom': vm.bloomEnabled,
          'ssr': vm.screenSpaceReflectionsEnabled,
          'vsync': vm.vsyncEnabled,
        },
      };

  String steps(List<double> values) => values.map((v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString()).join(', ');

  registry.registerAll([
    McpTool(
      name: 'get_viewport_settings',
      risk: McpToolRisk.readOnly,
      groups: view,
      title: 'Get viewport settings',
      description: 'The viewport toolbar\'s settings: snapping (translate / rotate / scale enabled and step), '
          'grid_visible and grid_step (cm), the six show flags, view_mode, buffer_visualization, the camera speed '
          'level (1–8) and quality (preset, resolution_scale %, ssao, bloom, ssr, vsync).',
      inputSchema: McpSchema.object(const {}),
      handler: (args) => McpToolResult.json(settings()),
    ),
    McpTool(
      name: 'set_viewport_snapping',
      risk: McpToolRisk.editorState,
      groups: view,
      idempotent: true,
      title: 'Set viewport snapping',
      description: 'The toolbar\'s snap toggles, step menus and grid button. Steps must be values the menus offer: '
          'translate cm ${steps(SnapService.translateSteps)}; rotate degrees ${steps(SnapService.rotateSteps)}; scale '
          '${steps(SnapService.scaleSteps)}; grid cm ${steps(SnapService.gridSteps)}. Not an undo step; saved with the '
          'project. Surface snap and the grid extent are not offered: no toolbar control sets them.',
      inputSchema: McpSchema.object({
        'translate_enabled': McpSchema.boolean('Snap moves to translate_step.'),
        'translate_step': McpSchema.number('cm, one of the menu\'s steps.'),
        'rotate_enabled': McpSchema.boolean('Snap rotations to rotate_step.'),
        'rotate_step': McpSchema.number('Degrees, one of the menu\'s steps.'),
        'scale_enabled': McpSchema.boolean('Snap scaling to scale_step.'),
        'scale_step': McpSchema.number('One of the menu\'s steps.'),
        'grid_visible': McpSchema.boolean('Draw the editor grid.'),
        'grid_step': McpSchema.number('Grid spacing in cm, one of the menu\'s steps.'),
      }),
      handler: (args) {
        for (final (key, allowed) in [
          ('translate_step', SnapService.translateSteps),
          ('rotate_step', SnapService.rotateSteps),
          ('scale_step', SnapService.scaleSteps),
          ('grid_step', SnapService.gridSteps),
        ]) {
          if (args.has(key) && !allowed.contains(args.number(key))) {
            return McpToolResult.error('$key ${args[key]} is not a step the toolbar offers. Steps: ${steps(allowed)}.');
          }
        }
        if (args.has('translate_enabled')) vm.updateTranslateSnapEnabled(args.boolean('translate_enabled'));
        if (args.has('translate_step')) vm.updateTranslateSnapStep(args.number('translate_step'));
        if (args.has('rotate_enabled')) vm.updateRotateSnapEnabled(args.boolean('rotate_enabled'));
        if (args.has('rotate_step')) vm.updateRotateSnapStep(args.number('rotate_step'));
        if (args.has('scale_enabled')) vm.updateScaleSnapEnabled(args.boolean('scale_enabled'));
        if (args.has('scale_step')) vm.updateScaleSnapStep(args.number('scale_step'));
        if (args.has('grid_visible')) vm.updateGridVisible(args.boolean('grid_visible'));
        if (args.has('grid_step')) vm.updateGridStep(args.number('grid_step'));
        return McpToolResult.json(settings());
      },
    ),
    McpTool(
      name: 'set_show_flags',
      risk: McpToolRisk.editorState,
      groups: view,
      idempotent: true,
      title: 'Set show flags',
      description: 'The toolbar\'s Show menu: turns show flags on or off (${kMcpShowFlags.join(', ')}). Only flags '
          'whose value differs are toggled. Not an undo step; saved with the project.',
      inputSchema: McpSchema.object({
        'flags': {
          'type': 'object',
          'description': 'Flag name → on/off, e.g. {"Collision": true, "Grid": false}.',
          'additionalProperties': {'type': 'boolean'},
        },
      }, required: ['flags']),
      handler: (args) {
        final flags = args.optionalObject('flags')!;
        for (final e in flags.entries) {
          if (!kMcpShowFlags.contains(e.key)) {
            return McpToolResult.error('Unknown show flag "${e.key}". Flags: ${kMcpShowFlags.join(', ')}.');
          }
          if (e.value is! bool) return McpToolResult.error('Show flag "${e.key}" takes true or false.');
        }
        for (final e in flags.entries) {
          if ((vm.showFlags[e.key] ?? true) != e.value) vm.toggleShowFlag(e.key);
        }
        return McpToolResult.json({'show_flags': settings()['show_flags']});
      },
    ),
    McpTool(
      name: 'set_buffer_visualization',
      risk: McpToolRisk.editorState,
      groups: view,
      idempotent: true,
      title: 'Set buffer visualization',
      description: 'View mode → Buffer Visualization: shows one G-buffer channel (${kMcpBufferVisualizations.join(', ')}) '
          'and switches the view mode to Buffer, as the menu does. set_camera view_mode "Lit" returns to the lit view.',
      inputSchema: McpSchema.object({
        'buffer': McpSchema.string('The buffer.', enumValues: kMcpBufferVisualizations),
      }, required: ['buffer']),
      handler: (args) {
        vm.setBufferVisualization(args.string('buffer'));
        vm.setViewMode('Buffer');
        return McpToolResult.json({'view_mode': vm.viewMode, 'buffer_visualization': vm.bufferVisualization});
      },
    ),
    McpTool(
      name: 'set_viewport_quality',
      risk: McpToolRisk.editorState,
      groups: view,
      idempotent: true,
      title: 'Set viewport quality',
      description: 'The viewport\'s quality popover: preset (${kMcpQualityPresets.join(' / ')}), resolution_scale '
          '(50–200 %, the slider\'s range), ssao, bloom, ssr (screen-space reflections) and vsync; only values that '
          'differ are changed. The preset is also the quality the game ships with (Project Settings; see '
          'the settings tools), and vsync is a project setting. Not an undo step.',
      inputSchema: McpSchema.object({
        'preset': McpSchema.string('The preset.', enumValues: kMcpQualityPresets),
        'resolution_scale': McpSchema.number('Render resolution in %, 50–200.'),
        'ssao': McpSchema.boolean('Screen-space ambient occlusion.'),
        'bloom': McpSchema.boolean('Bloom.'),
        'ssr': McpSchema.boolean('Screen-space reflections.'),
        'vsync': McpSchema.boolean('Vertical sync.'),
      }),
      handler: (args) {
        final scale = args.optionalNumber('resolution_scale');
        if (scale != null && (scale < 50 || scale > 200)) {
          return McpToolResult.error('resolution_scale must be within 50–200 (%); got $scale.');
        }
        final preset = args.optionalString('preset');
        if (preset != null && preset != vm.qualityPreset.toLowerCase()) vm.updateQualityPreset(preset);
        if (scale != null && scale != vm.resolutionScale) vm.updateResolutionScale(scale);
        if (args.has('ssao') && args.boolean('ssao') != vm.ssaoEnabled) vm.toggleSsao();
        if (args.has('bloom') && args.boolean('bloom') != vm.bloomEnabled) vm.toggleBloom();
        if (args.has('ssr') && args.boolean('ssr') != vm.screenSpaceReflectionsEnabled) vm.toggleScreenSpaceReflections();
        if (args.has('vsync') && args.boolean('vsync') != vm.vsyncEnabled) vm.toggleVSync();
        return McpToolResult.json({'quality': settings()['quality']});
      },
    ),
  ]);
}
