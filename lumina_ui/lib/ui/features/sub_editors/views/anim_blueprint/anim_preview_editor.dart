import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/anim_blueprint_editor_view_model.dart';

/// The Anim Preview Editor: the stand-in owner's speed, direction and
/// falling state (what Get Velocity / Is Falling return to the update graph),
/// and per-variable overrides that pin a variable (the update graph stops
/// writing it) while the preview runs.
class AnimPreviewEditorPanel extends StatelessWidget {
  final AnimBlueprintEditorViewModel viewModel;

  const AnimPreviewEditorPanel({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final anim = vm.preview.animInstance;
    Widget slider(String key, String label, double value, double min, double max, String unit, ValueChanged<double> onChanged) {
      return Row(
        children: [
          SizedBox(width: 92, child: Text(label, style: const TextStyle(fontSize: 9.5, color: EditorColors.foreground))),
          Expanded(
            child: SliderField(
              key: ValueKey(key),
              value: value.clamp(min, max).toDouble(),
              defaultValue: 0.0,
              min: min,
              max: max,
              unit: unit,
              fractionDigits: 0,
              onChanged: onChanged,
              onCommit: onChanged,
              onReset: () => onChanged(0.0),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text('${value.toStringAsFixed(0)} $unit',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 9.5, fontFamily: EditorTypography.monoFamily, color: EditorColors.mutedForeground)),
          ),
        ],
      );
    }

    return ListView(
      key: const ValueKey('anim_preview_editor'),
      padding: const EdgeInsets.all(8),
      children: [
        Row(
          children: [
            const Icon(LucideIcons.slidersHorizontal, size: 12, color: EditorColors.primary),
            const SizedBox(width: 6),
            const Text('ANIM PREVIEW EDITOR',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.primary)),
            const Spacer(),
            Text(
              vm.previewState == null ? 'not running' : 'state ${vm.previewState} · ${vm.previewClip ?? '-'}',
              key: const ValueKey('anim_preview_status'),
              style: const TextStyle(fontSize: 9, color: Color(0xFFFFB300)), // preview amber: an overridden variable
            ),
          ],
        ),
        if (vm.previewError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(vm.previewError!, style: const TextStyle(fontSize: 9, color: EditorColors.destructive)),
          ),
        const SizedBox(height: 6),
        const Text('OWNER (stand-in pawn)', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
        slider('preview_owner_speed', 'Speed', vm.ownerSpeed, 0, 600, 'cm/s', (v) => vm.setOwner(speed: v)),
        slider('preview_owner_direction', 'Direction', vm.ownerDirection, -180, 180, '°', (v) => vm.setOwner(direction: v)),
        Row(
          children: [
            const SizedBox(width: 92, child: Text('Falling', style: TextStyle(fontSize: 9.5))),
            Switch(key: const ValueKey('preview_owner_falling'), value: vm.ownerFalling, onChanged: (v) => vm.setOwner(falling: v)),
          ],
        ),
        const SizedBox(height: 8),
        const Text('VARIABLES (check to override)',
            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
        for (final v in vm.document.variables) _variableRow(vm, v, anim),
      ],
    );
  }

  Widget _variableRow(AnimBlueprintEditorViewModel vm, LuminaBlueprintVariable v, LuminaAnimBlueprintInstance? anim) {
    final overridden = vm.overrides.containsKey(v.name);
    final live = anim?.variables[v.name];
    final value = overridden ? vm.overrides[v.name] : live;
    Widget editor;
    switch (v.type) {
      case LuminaPinType.boolean:
        editor = Switch(
          key: ValueKey('override_value_${v.name}'),
          value: value == true,
          onChanged: (b) => vm.setOverride(v.name, b),
        );
      case LuminaPinType.float:
      case LuminaPinType.integer:
        final n = value is num ? value.toDouble() : 0.0;
        editor = Row(
          children: [
            Expanded(
              child: SliderField(
                key: ValueKey('override_value_${v.name}'),
                value: n.clamp(-180.0, 600.0).toDouble(),
                defaultValue: v.defaultValue is num ? (v.defaultValue as num).toDouble() : 0.0,
                min: -180,
                max: 600,
                fractionDigits: v.type == LuminaPinType.integer ? 0 : 1,
                onChanged: (s) => vm.setOverride(v.name, v.type == LuminaPinType.integer ? s.round() : s),
                onCommit: (s) => vm.setOverride(v.name, v.type == LuminaPinType.integer ? s.round() : s),
                onReset: () => vm.setOverride(v.name, v.defaultValue),
              ),
            ),
            SizedBox(
              width: 48,
              child: Text(n.toStringAsFixed(1),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 9.5, fontFamily: EditorTypography.monoFamily)),
            ),
          ],
        );
      default:
        editor = Text('${value ?? '-'}', style: const TextStyle(fontSize: 9.5));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Checkbox(
            key: ValueKey('override_toggle_${v.name}'),
            state: overridden ? CheckboxState.checked : CheckboxState.unchecked,
            onChanged: (s) {
              if (s == CheckboxState.checked) {
                vm.setOverride(v.name, live ?? v.defaultValue);
              } else {
                vm.clearOverride(v.name);
              }
            },
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 84,
            child: Text(v.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: overridden ? FontWeight.bold : FontWeight.normal,
                    color: overridden ? const Color(0xFFFFB300) : EditorColors.foreground)), // preview amber
          ),
          Expanded(child: editor),
        ],
      ),
    );
  }
}
