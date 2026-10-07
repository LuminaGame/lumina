import 'package:lumina/lumina.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// The Import Asset Options dialog's **Target Skeleton** row:
/// which project skeletal mesh an imported FBX
/// animation is retargeted onto.
///
/// [value] follows `EditorViewModel.processImportPipeline(targetSkeletonPath:)`:
/// null matches a skeleton by bone names, `''` keeps the animation unbound,
/// anything else is a skeletal mesh `.lmas` path relative to the project.
class ImportTargetSkeletonSelect extends StatelessWidget {
  /// The Select's value for "match by bone names" (null in [value]).
  static const String autoValue = '__auto__';

  /// Whether the dialog shows the row for [filePaths]: only an FBX can hold
  /// an animation the importer retargets.
  static bool appliesTo(List<String> filePaths) => filePaths.any((p) => p.toLowerCase().endsWith('.fbx'));

  /// The project's skeletal meshes (the retarget targets on offer).
  final List<RealAssetInfo> skeletalMeshes;
  final String? value;
  final ValueChanged<String?> onChanged;

  const ImportTargetSkeletonSelect({
    super.key,
    required this.skeletalMeshes,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = [autoValue, for (final m in skeletalMeshes) m.relativePath, ''];
    final selected = value ?? autoValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Target Skeleton (FBX animations)',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground),
        ),
        const SizedBox(height: 4),
        // The shared searchable picker with thumbnails; Auto
        // and None are its fixed options.
        AssetPickerSelect(
          key: const ValueKey('import_target_skeleton'),
          keyPrefix: 'import_target_skeleton',
          assets: skeletalMeshes,
          selectedPath: selected == autoValue || selected.isEmpty ? null : selected,
          allowClear: false,
          options: const [
            AssetPickerOption(id: autoValue, label: 'Auto (match bone names)', icon: LucideIcons.wandSparkles),
            AssetPickerOption(id: '', label: 'None (keep unbound)', icon: LucideIcons.circleSlash),
          ],
          // A path no longer in the project reads as Auto, as before.
          selectedOption: selected == autoValue || selected.isEmpty ? selected : (options.contains(selected) ? null : autoValue),
          onOption: (id) => onChanged(id == autoValue ? null : id),
          onSelected: (mesh) => onChanged(mesh.relativePath),
        ),
        const SizedBox(height: 2),
        Text(
          skeletalMeshes.isEmpty
              ? 'The project has no skeletal mesh yet: animations import unbound.'
              : 'Clips are retargeted (rotations, root and pelvis motion) into the chosen mesh.',
          style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
        ),
      ],
    );
  }
}
