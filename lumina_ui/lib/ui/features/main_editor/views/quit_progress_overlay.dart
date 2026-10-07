import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// The notice the editor shows while it quits: a dimmed editor that takes no
/// more input, and a card naming the step in progress ("Saving L_Main…",
/// "Closing plugins…", "Closing editor…"). Nothing while [status] is null.
class QuitProgressOverlay extends StatelessWidget {
  const QuitProgressOverlay({super.key, required this.status});

  final ValueListenable<String?> status;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: status,
      builder: (context, step, _) {
        if (step == null) return const SizedBox.shrink();
        return AbsorbPointer(
          key: const ValueKey('quit_progress_overlay'),
          child: ColoredBox(
            color: const Color(0x99000000),
            child: Center(
              child: SizedBox(
                width: 320,
                child: Card(
                  padding: const EdgeInsets.all(16),
                  borderRadius: BorderRadius.circular(6),
                  borderColor: EditorColors.borderSolid,
                  fillColor: EditorColors.popover,
                  filled: true,
                  child: Row(
                    children: [
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(size: 18)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Quitting Lumina Studio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              step,
                              key: const ValueKey('quit_progress_status'),
                              style: const TextStyle(fontSize: 11, color: EditorColors.mutedForeground),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
