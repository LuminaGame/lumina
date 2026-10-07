import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/sub_editor_transform_gizmo.dart';

/// Reusable transform gizmo toolbar component for 3D viewports and sub-editors.
///
/// Provides interactive tool mode buttons (Select/Translate/Rotate/Scale),
/// coordinate space toggle (World/Local), and numeric snapping controls (Grid/Rotation/Scale).
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

        Widget tool(IconData icon, GizmoMode mode, String tip, String key) {
          final sel = gizmo.mode == mode;
          return Tooltip(
            tooltip: (context) => TooltipContainer(child: Text('$tip ($key)')),
            child: GestureDetector(
              key: ValueKey('sub_gizmo_tool_${tip.toLowerCase()}'),
              onTap: () => gizmo.setMode(mode),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  color: sel ? EditorColors.primary.withValues(alpha: 0.3) : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Icon(icon, size: 11, color: sel ? EditorColors.primary : EditorColors.foreground),
              ),
            ),
          );
        }

        Widget snapToggle({
          required Key key,
          required IconData icon,
          required bool active,
          required String tip,
          required VoidCallback onToggle,
        }) {
          return Tooltip(
            tooltip: (context) => TooltipContainer(child: Text(tip)),
            child: GestureDetector(
              key: key,
              onTap: onToggle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                  color: active ? EditorColors.primary.withValues(alpha: 0.3) : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Icon(icon, size: 11, color: active ? EditorColors.primary : EditorColors.foreground),
              ),
            ),
          );
        }

        Widget stepField({
          required Key key,
          required double value,
          required String suffix,
          required ValueChanged<double> onChanged,
        }) {
          return SizedBox(
            width: 54,
            height: 20,
            child: TextField(
              key: key,
              initialValue: value == value.roundToDouble() ? value.toInt().toString() : value.toString(),
              style: const TextStyle(fontSize: 9),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              placeholder: Text(suffix, style: const TextStyle(fontSize: 9)),
              onChanged: (text) {
                final v = double.tryParse(text);
                if (v != null && v > 0) onChanged(v);
              },
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: EditorColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              tool(LucideIcons.mousePointer, GizmoMode.translate, 'Select', 'Q'),
              tool(LucideIcons.move, GizmoMode.translate, 'Translate', 'W'),
              tool(LucideIcons.rotateCcw, GizmoMode.rotate, 'Rotate', 'E'),
              tool(LucideIcons.maximize2, GizmoMode.scale, 'Scale', 'R'),
              const SizedBox(width: 4),
              Tooltip(
                tooltip: (context) => TooltipContainer(
                  child: Text(gizmo.space == GizmoSpace.world ? 'World space (click for Local)' : 'Local space (click for World)'),
                ),
                child: GestureDetector(
                  key: const ValueKey('sub_gizmo_space'),
                  onTap: gizmo.toggleSpace,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: gizmo.space == GizmoSpace.local ? EditorColors.primary.withValues(alpha: 0.3) : Colors.transparent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(gizmo.space == GizmoSpace.world ? LucideIcons.globe : LucideIcons.box,
                            size: 11, color: gizmo.space == GizmoSpace.local ? EditorColors.primary : EditorColors.foreground),
                        const SizedBox(width: 3),
                        Text(gizmo.space == GizmoSpace.world ? 'WORLD' : 'LOCAL',
                            style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: gizmo.space == GizmoSpace.local ? EditorColors.primary : EditorColors.foreground)),
                      ],
                    ),
                  ),
                ),
              ),
              snapToggle(
                key: const ValueKey('sub_gizmo_snap_translate'),
                icon: LucideIcons.magnet,
                active: snap.translateEnabled,
                tip: 'Grid snap',
                onToggle: () => gizmo.setSnap(snap.copyWith(translateEnabled: !snap.translateEnabled)),
              ),
              stepField(
                key: const ValueKey('sub_gizmo_snap_translate_step'),
                value: snap.translateStep,
                suffix: 'cm',
                onChanged: (v) => gizmo.setSnap(gizmo.snap.copyWith(translateStep: v)),
              ),
              snapToggle(
                key: const ValueKey('sub_gizmo_snap_rotate'),
                icon: LucideIcons.rotateCw,
                active: snap.rotateEnabled,
                tip: 'Rotation snap',
                onToggle: () => gizmo.setSnap(snap.copyWith(rotateEnabled: !snap.rotateEnabled)),
              ),
              stepField(
                key: const ValueKey('sub_gizmo_snap_rotate_step'),
                value: snap.rotateStep,
                suffix: '°',
                onChanged: (v) => gizmo.setSnap(gizmo.snap.copyWith(rotateStep: v)),
              ),
              snapToggle(
                key: const ValueKey('sub_gizmo_snap_scale'),
                icon: LucideIcons.scaling,
                active: snap.scaleEnabled,
                tip: 'Scale snap',
                onToggle: () => gizmo.setSnap(snap.copyWith(scaleEnabled: !snap.scaleEnabled)),
              ),
              stepField(
                key: const ValueKey('sub_gizmo_snap_scale_step'),
                value: snap.scaleStep,
                suffix: '×',
                onChanged: (v) => gizmo.setSnap(gizmo.snap.copyWith(scaleStep: v)),
              ),
            ],
          ),
        );
      },
    );
  }
}
