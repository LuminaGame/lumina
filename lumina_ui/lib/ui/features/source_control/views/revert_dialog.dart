import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/source_control/services/git_service.dart';
import 'package:lumina_ui/ui/features/source_control/view_models/source_control_view_model.dart';

/// Confirm dialog naming the file, then `git restore -- <path>`; untracked
/// files are offered a delete instead. The view model fires its reload hook
/// afterwards so in-memory editor state matches disk.
void showRevertDialog(BuildContext context, SourceControlViewModel viewModel, String path) {
  final state = viewModel.stateFor(path);
  final untracked = state == GitFileState.untracked;
  showOverlay(
    context,
    const DialogConfiguration(),
    builder: (c) => AlertDialog(
      title: Text(untracked ? 'Delete Untracked File' : 'Revert File'),
      content: SizedBox(
        width: 440,
        child: Text(
          untracked
              ? '$path is not tracked by git, so there is nothing to revert to. Delete it from disk instead?'
              : 'Discard all working-tree changes to $path and restore the version from HEAD? This cannot be undone.',
          style: const TextStyle(fontSize: 11, color: EditorColors.foreground),
        ),
      ),
      actions: [
        OutlineButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Cancel')),
        DestructiveButton(
          key: const ValueKey('sc_revert_confirm'),
          onPressed: () async {
            Navigator.of(c).pop();
            await viewModel.revert(path, deleteUntracked: untracked);
          },
          child: Text(untracked ? 'Delete File' : 'Revert'),
        ),
      ],
    ),
  );
}
