import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/viewport_pills.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/sub_editor_transform_gizmo.dart';

/// A sub-editor viewport's transform controls in the Aurora chrome: the
/// World/Local pill and the three snap pills (each its toggle and an inline
/// step field), laid out as pills of the viewport's pill row. The tools
/// themselves are the [TransformGizmoToolColumn] under the row.
class TransformGizmoToolbar extends StatelessWidget {
  final SubEditorTransformGizmo gizmo;

  const TransformGizmoToolbar({
    super.key,
    required this.gizmo,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: gizmo,
      builder: (context, _) {
        final snap = gizmo.snap;
        final world = gizmo.space == GizmoSpace.world;
        return Wrap(
          spacing: ViewportPillStyle.gap,
          runSpacing: ViewportPillStyle.gap,
          children: [
            ViewportPill(
              key: const ValueKey('sub_gizmo_space'),
              icon: world ? LucideIcons.globe : LucideIcons.box,
              label: world ? 'World' : 'Local',
              highlighted: !world,
              tooltip: world ? 'World space (click for Local)' : 'Local space (click for World)',
              onPressed: gizmo.toggleSpace,
            ),
            _SnapFieldPill(
              toggleKey: const ValueKey('sub_gizmo_snap_translate'),
              fieldKey: const ValueKey('sub_gizmo_snap_translate_step'),
              icon: LucideIcons.magnet,
              tooltip: 'Grid snap',
              enabled: snap.translateEnabled,
              value: snap.translateStep,
              suffix: 'cm',
              onToggle: () => gizmo.setSnap(snap.copyWith(translateEnabled: !snap.translateEnabled)),
              onChanged: (v) => gizmo.setSnap(gizmo.snap.copyWith(translateStep: v)),
            ),
            _SnapFieldPill(
              toggleKey: const ValueKey('sub_gizmo_snap_rotate'),
              fieldKey: const ValueKey('sub_gizmo_snap_rotate_step'),
              icon: LucideIcons.rotateCw,
              tooltip: 'Rotation snap',
              enabled: snap.rotateEnabled,
              value: snap.rotateStep,
              suffix: '°',
              onToggle: () => gizmo.setSnap(snap.copyWith(rotateEnabled: !snap.rotateEnabled)),
              onChanged: (v) => gizmo.setSnap(gizmo.snap.copyWith(rotateStep: v)),
            ),
            _SnapFieldPill(
              toggleKey: const ValueKey('sub_gizmo_snap_scale'),
              fieldKey: const ValueKey('sub_gizmo_snap_scale_step'),
              icon: LucideIcons.scaling,
              tooltip: 'Scale snap',
              enabled: snap.scaleEnabled,
              value: snap.scaleStep,
              suffix: '×',
              onToggle: () => gizmo.setSnap(snap.copyWith(scaleEnabled: !snap.scaleEnabled)),
              onChanged: (v) => gizmo.setSnap(gizmo.snap.copyWith(scaleStep: v)),
            ),
          ],
        );
      },
    );
  }
}

/// The vertical tool column of a sub-editor viewport: Select, Move, Rotate,
/// Scale (Select picks with the move gizmo, as Q does), then [onFocus].
class TransformGizmoToolColumn extends StatelessWidget {
  const TransformGizmoToolColumn({super.key, required this.gizmo, this.onFocus});

  final SubEditorTransformGizmo gizmo;
  final VoidCallback? onFocus;

  static const List<ViewportTool> tools = [
    ViewportTool(id: 'select', icon: LucideIcons.mousePointer, tooltip: 'Select (Q)', key: ValueKey('sub_gizmo_tool_select')),
    ViewportTool(id: 'translate', icon: LucideIcons.move, tooltip: 'Move (W)', key: ValueKey('sub_gizmo_tool_translate')),
    ViewportTool(id: 'rotate', icon: LucideIcons.rotateCcw, tooltip: 'Rotate (E)', key: ValueKey('sub_gizmo_tool_rotate')),
    ViewportTool(id: 'scale', icon: LucideIcons.maximize2, tooltip: 'Scale (R)', key: ValueKey('sub_gizmo_tool_scale')),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: gizmo,
      builder: (context, _) => ViewportToolColumn(
        key: const ValueKey('sub_gizmo_tool_column'),
        tools: tools,
        active: switch (gizmo.mode) {
          GizmoMode.rotate => 'rotate',
          GizmoMode.scale => 'scale',
          _ => 'translate',
        },
        onSelect: (id) => gizmo.setMode(switch (id) {
          'rotate' => GizmoMode.rotate,
          'scale' => GizmoMode.scale,
          _ => GizmoMode.translate,
        }),
        actions: [
          if (onFocus != null)
            const ViewportTool(id: 'focus', icon: LucideIcons.scan, tooltip: 'Frame the view (F)', key: ValueKey('sub_gizmo_focus')),
        ],
        onAction: (_) => onFocus?.call(),
      ),
    );
  }
}

/// A snap pill with an inline step field: the toggle (amber while on) and
/// the free step value with its unit.
class _SnapFieldPill extends StatelessWidget {
  const _SnapFieldPill({
    required this.toggleKey,
    required this.fieldKey,
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.value,
    required this.suffix,
    required this.onToggle,
    required this.onChanged,
  });

  final Key toggleKey;
  final Key fieldKey;
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final double value;
  final String suffix;
  final VoidCallback onToggle;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: ViewportPillStyle.height,
      padding: const EdgeInsets.only(right: 4),
      decoration: ViewportPillStyle.decoration(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            tooltip: (_) => TooltipContainer(child: Text(tooltip)),
            child: GestureDetector(
              key: toggleKey,
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(icon, size: 13, color: enabled ? EditorColors.primary : EditorColors.mutedForeground),
              ),
            ),
          ),
          SizedBox(
            width: 52,
            height: 22,
            child: TextField(
              key: fieldKey,
              initialValue: value == value.roundToDouble() ? value.toInt().toString() : value.toString(),
              style: EditorTypography.mono(fontSize: EditorTypography.labelSize, color: EditorColors.foreground),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              borderRadius: BorderRadius.circular(6),
              placeholder: Text(suffix, style: EditorTypography.mono(fontSize: EditorTypography.labelSize)),
              onChanged: (text) {
                final v = double.tryParse(text);
                if (v != null && v > 0) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}
