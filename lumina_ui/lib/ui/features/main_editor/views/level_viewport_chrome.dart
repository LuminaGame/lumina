import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/viewport_pills.dart';
import 'package:lumina_ui/ui/features/main_editor/services/snap_service.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// The level viewport's Aurora chrome, top-left over the render: the pill
/// row (camera, view mode, translate / rotate / scale snap, grid, World or
/// Local, Show) and under it the vertical tool column (Select, Move, Rotate,
/// Scale, then Focus). Q/W/E/R/F still switch the tools through the shell's
/// shortcuts; the column follows [EditorViewModel.activeTool].
class LevelViewportPills extends StatelessWidget {
  const LevelViewportPills({super.key, required this.viewModel, required this.onFocus});

  final EditorViewModel viewModel;

  /// Focus: frame the selection (or reset the camera without one).
  final VoidCallback onFocus;

  /// The camera projections the camera pill offers.
  static const List<String> cameraModes = ['Perspective', 'Top', 'Bottom', 'Left', 'Right', 'Front', 'Back'];

  /// The overlays the Show pill toggles.
  static const List<String> showFlags = [
    'Grid',
    'Transform Gizmo',
    'Selection Bounds',
    'Collision',
    'Actor Icons & Labels',
    'Ground Drop Shadows',
  ];

  static const List<ViewportTool> tools = [
    ViewportTool(id: 'select', icon: LucideIcons.mousePointer, tooltip: 'Select (Q)', key: ValueKey('viewport_tool_select')),
    ViewportTool(id: 'translate', icon: LucideIcons.move, tooltip: 'Move (W)', key: ValueKey('viewport_tool_translate')),
    ViewportTool(id: 'rotate', icon: LucideIcons.rotateCcw, tooltip: 'Rotate (E)', key: ValueKey('viewport_tool_rotate')),
    ViewportTool(id: 'scale', icon: LucideIcons.maximize2, tooltip: 'Scale (R)', key: ValueKey('viewport_tool_scale')),
  ];

  static const List<ViewportTool> actions = [
    ViewportTool(id: 'focus', icon: LucideIcons.scan, tooltip: 'Focus selection (F)', key: ValueKey('viewport_tool_focus')),
  ];

  List<MenuItem> _viewModeMenu() {
    final vm = viewModel;
    return [
      for (final mode in const ['Lit', 'Unlit', 'Wireframe'])
        viewportMenuItem(mode, checked: vm.viewMode == mode, onPressed: () => vm.setViewMode(mode)),
      const MenuDivider(),
      MenuButton(
        subMenu: [
          for (final buffer in const ['Base Color', 'Opacity', 'Roughness', 'Metallic', 'Emissive', 'Normal'])
            viewportMenuItem(buffer, onPressed: () {
              vm.setBufferVisualization(buffer);
              vm.setViewMode('Buffer');
            }),
        ],
        child: Text('Buffer Visualization', style: EditorTypography.ui(fontSize: EditorTypography.bodySize)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final vm = viewModel;
        final shown = showFlags.where((f) => vm.showFlags[f] == true).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: ViewportPillStyle.gap,
              runSpacing: ViewportPillStyle.gap,
              children: [
                ViewportPill(
                  key: const ValueKey('viewport_pill_camera'),
                  icon: LucideIcons.video,
                  label: vm.cameraMode,
                  tooltip: 'Camera projection',
                  menu: () => [
                    for (final mode in cameraModes)
                      viewportMenuItem(mode, checked: vm.cameraMode == mode, onPressed: () => vm.setCameraMode(mode)),
                  ],
                ),
                ViewportPill(
                  key: const ValueKey('viewport_pill_view_mode'),
                  icon: LucideIcons.sun,
                  label: vm.viewMode,
                  tooltip: 'View mode',
                  menu: _viewModeMenu,
                ),
                KeyedSubtree(
                  key: const Key('toggle_translate_snap'),
                  child: ViewportSnapPill(
                    icon: LucideIcons.magnet,
                    tooltip: 'Location snap',
                    enabled: vm.translateSnapEnabled,
                    onToggle: () => vm.updateTranslateSnapEnabled(!vm.translateSnapEnabled),
                    value: vm.translateSnapStep,
                    options: SnapService.translateSteps,
                    format: SnapService.formatLength,
                    onChanged: vm.updateTranslateSnapStep,
                  ),
                ),
                KeyedSubtree(
                  key: const Key('toggle_rotate_snap'),
                  child: ViewportSnapPill(
                    icon: LucideIcons.rotateCcw,
                    tooltip: 'Rotation snap',
                    enabled: vm.rotateSnapEnabled,
                    onToggle: () => vm.updateRotateSnapEnabled(!vm.rotateSnapEnabled),
                    value: vm.rotateSnapStep,
                    options: SnapService.rotateSteps,
                    format: (v) => '${v == v.roundToDouble() ? v.round() : v}°',
                    onChanged: vm.updateRotateSnapStep,
                  ),
                ),
                KeyedSubtree(
                  key: const Key('toggle_scale_snap'),
                  child: ViewportSnapPill(
                    icon: LucideIcons.maximize2,
                    tooltip: 'Scale snap',
                    enabled: vm.scaleSnapEnabled,
                    onToggle: () => vm.updateScaleSnapEnabled(!vm.scaleSnapEnabled),
                    value: vm.scaleSnapStep,
                    options: SnapService.scaleSteps,
                    onChanged: vm.updateScaleSnapStep,
                  ),
                ),
                KeyedSubtree(
                  key: const Key('toggle_grid_snap'),
                  child: ViewportSnapPill(
                    icon: LucideIcons.layoutGrid,
                    tooltip: 'Grid',
                    enabled: vm.gridVisible,
                    onToggle: () => vm.updateGridVisible(!vm.gridVisible),
                    value: vm.editorGridStep,
                    options: SnapService.gridSteps,
                    format: SnapService.formatLength,
                    onChanged: vm.updateGridStep,
                  ),
                ),
                ViewportPill(
                  key: const ValueKey('viewport_pill_space'),
                  icon: vm.gizmoSpace == 'world' ? LucideIcons.globe : LucideIcons.box,
                  label: vm.gizmoSpace == 'world' ? 'World' : 'Local',
                  tooltip: 'Transform space: world or the actor\'s own axes',
                  onPressed: vm.toggleGizmoSpace,
                ),
                ViewportPill(
                  key: const ValueKey('viewport_pill_show'),
                  icon: LucideIcons.eye,
                  label: 'Show · $shown',
                  tooltip: 'Overlays drawn in the viewport',
                  menu: () => [
                    for (final flag in showFlags)
                      viewportMenuItem(flag, checked: vm.showFlags[flag] == true, onPressed: () => vm.toggleShowFlag(flag)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ViewportToolColumn(
              key: const ValueKey('viewport_tool_column'),
              tools: tools,
              active: vm.activeTool,
              onSelect: vm.setActiveTool,
              actions: actions,
              onAction: (_) => onFocus(),
            ),
          ],
        );
      },
    );
  }
}

/// The level viewport's stats pill, top-right: the triangles drawn and the
/// frame rate, set in mono. It repaints on its own every frame.
class LevelViewportStatsPill extends StatelessWidget {
  const LevelViewportStatsPill({super.key, required this.viewModel});

  final EditorViewModel viewModel;

  static String format(int triangles, double fps) {
    final tris = triangles >= 1000000
        ? '${(triangles / 1000000).toStringAsFixed(1)}M'
        : triangles >= 1000
            ? '${(triangles / 1000).toStringAsFixed(triangles >= 100000 ? 0 : 1)}k'
            : '$triangles';
    return '$tris tris · ${fps.round()} fps';
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ListenableBuilder(
        listenable: viewModel.frameStats,
        builder: (context, _) => Container(
          key: const ValueKey('viewport_stats_pill'),
          height: ViewportPillStyle.height,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: ViewportPillStyle.decoration(),
          child: Text(format(viewModel.totalTriangles, viewModel.fps), style: ViewportPillStyle.label(mono: true)),
        ),
      ),
    );
  }
}
