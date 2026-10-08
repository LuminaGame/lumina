import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/host/launch_model_files.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// The launcher's note while model files from "Open with" wait for a
/// project: opening or creating one imports them there. "Don't import" drops
/// them. Nothing is shown when no file waits.
class PendingModelImportBanner extends StatelessWidget {
  const PendingModelImportBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: LaunchModelFiles.pending,
      builder: (context, files, _) {
        if (files.isEmpty) return const SizedBox.shrink();
        final names = files.map(p.basename).join(', ');
        return Container(
          key: const ValueKey('pending_model_import_banner'),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: EditorColors.primary.withValues(alpha: 0.12),
            border: const Border(bottom: BorderSide(color: EditorColors.border)),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.fileInput, size: 16, color: EditorColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Open or create a project to import $names into it.',
                  style: const TextStyle(fontSize: 12, color: EditorColors.foreground),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Button.ghost(
                style: const ButtonStyle.ghost(density: ButtonDensity.compact),
                onPressed: () => LaunchModelFiles.pending.value = const [],
                child: const Text("Don't import", style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        );
      },
    );
  }
}
