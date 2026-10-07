import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// Shown under the menu bar for a project created before Lumina switched to
/// centimetres and Z-up authoring. Such a project is not migrated
/// (the user's decision): its levels were authored in metres, Y up, and would
/// play at the wrong scale.
class LegacyUnitsBanner extends StatelessWidget {
  const LegacyUnitsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('legacy_units_banner'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: EditorColors.cardHeader,
        border: Border(bottom: BorderSide(color: EditorColors.border)),
      ),
      child: const Row(
        children: [
          Icon(LucideIcons.ruler, size: 14, color: EditorColors.logWarning),
          SizedBox(width: 8),
          DestructiveBadge(child: Text('Metre project')),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'This project was created with metre units, before Lumina switched to centimetres and Z-up. '
              'Its levels will not play at the right scale; recreate it from a template.',
              style: TextStyle(fontSize: 11, color: EditorColors.foreground),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
