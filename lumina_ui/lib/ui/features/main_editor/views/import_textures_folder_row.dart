import 'package:file_picker/file_picker.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../core/theme/editor_theme.dart';

/// The Import Asset Options dialog's **Textures Folder** row: a folder the FBX importer searches first for the FBX's
/// textures. Without one it looks next to the FBX and in its `Textures/`,
/// `textures/`, `<name>/` and `<name>.fbm/` folders. Textures the FBX names
/// are found by file name; images named after a material and a channel
/// (`T_Wood_BaseColor`, `…_MI_Neon_Green_…_Emissive`, `_Normal`, `_ORM`) are
/// applied to that material even when the FBX names none (an Unreal FBX
/// export carries only its materials' constants).
class ImportTexturesFolderRow extends StatelessWidget {
  /// Only an FBX goes through the texture search.
  static bool appliesTo(List<String> filePaths) => filePaths.any((p) => p.toLowerCase().endsWith('.fbx'));

  /// The chosen folder, or null for "next to the FBX".
  final String? value;
  final ValueChanged<String?> onChanged;

  /// The directory picker; null opens the OS dialog.
  final Future<String?> Function()? picker;

  const ImportTexturesFolderRow({super.key, required this.value, required this.onChanged, this.picker});

  Future<void> _browse() async {
    final pick = picker ?? () => FilePicker.platform.getDirectoryPath(dialogTitle: 'Textures Folder');
    final folder = await pick();
    if (folder != null && folder.isNotEmpty) onChanged(folder);
  }

  @override
  Widget build(BuildContext context) {
    final chosen = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Textures Folder (FBX)',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                chosen ?? 'Next to the FBX (and its Textures/ folders)',
                key: const ValueKey('import_textures_folder_value'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9, color: chosen == null ? EditorColors.mutedForeground : EditorColors.foreground),
              ),
            ),
            const SizedBox(width: 6),
            OutlineButton(
              key: const ValueKey('import_textures_folder_browse'),
              size: ButtonSize.small,
              onPressed: _browse,
              child: const Text('Browse…', style: TextStyle(fontSize: 9)),
            ),
            if (chosen != null) ...[
              const SizedBox(width: 4),
              GhostButton(
                key: const ValueKey('import_textures_folder_clear'),
                size: ButtonSize.small,
                onPressed: () => onChanged(null),
                child: const Icon(LucideIcons.x, size: 12),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        const Text(
          'Searched first for the textures the FBX names; images named after a material '
          '(T_<Material>_BaseColor / _Normal / _Emissive / _ORM) are applied to it.',
          style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
        ),
      ],
    );
  }
}
