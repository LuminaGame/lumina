import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../core/theme/editor_theme.dart';
import '../view_models/source_control_view_model.dart';
import 'identity_form.dart';

/// Dismissible banner shown under the menu bar when the opened project has
/// no `.git`: `Initialize Git Repository` runs `git init` + `.gitignore` +
/// the initial commit; `Not now` persists the dismissal next to the project.
class InitRepoPrompt extends StatelessWidget {
  final SourceControlViewModel viewModel;

  const InitRepoPrompt({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final vm = viewModel;
        return Container(
          key: const ValueKey('sc_init_prompt'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: const BoxDecoration(
            color: EditorColors.cardHeader,
            border: Border(bottom: BorderSide(color: EditorColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.gitBranch, size: 14, color: EditorColors.primary),
                  const SizedBox(width: 8),
                  const PrimaryBadge(child: Text('Source Control')),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'This project is not under version control. Initialize a git repository to get status badges, commits and per-asset history.',
                      style: TextStyle(fontSize: 11, color: EditorColors.foreground),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  PrimaryButton(
                    key: const ValueKey('sc_init_button'),
                    onPressed: vm.isBusy ? null : () => vm.initRepository(),
                    child: const Text('Initialize Git Repository'),
                  ),
                  const SizedBox(width: 6),
                  GhostButton(
                    key: const ValueKey('sc_init_dismiss'),
                    onPressed: () => vm.dismissInitPrompt(),
                    child: const Text('Not now'),
                  ),
                ],
              ),
              if (vm.identityRequired) ...[
                const SizedBox(height: 6),
                GitIdentityForm(viewModel: vm),
              ] else if (vm.lastError != null) ...[
                const SizedBox(height: 4),
                Text(
                  vm.lastError!,
                  key: const ValueKey('sc_init_error'),
                  style: const TextStyle(fontSize: 10, color: EditorColors.logError),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
