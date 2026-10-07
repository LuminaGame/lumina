import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// The answer to [MissingEditorBinaryDialog].
enum MissingBinaryChoice { buildAndOpen, openWithoutPlugins, cancel }

/// A project with code plugins whose editor was never built on
/// this machine (an older project, a fresh clone, another OS): the modules
/// are missing or built with a different engine version, so it offers to
/// rebuild them now.
class MissingEditorBinaryDialog extends StatelessWidget {
  final String projectName;
  final List<String> pluginNames;
  final String reason;

  const MissingEditorBinaryDialog({super.key, required this.projectName, required this.pluginNames, required this.reason});

  static Future<MissingBinaryChoice> show(BuildContext context,
      {required String projectName, required List<String> pluginNames, required String reason}) async {
    final choice = await showOverlay<MissingBinaryChoice>(
      context,
      const DialogConfiguration(),
      builder: (_) => MissingEditorBinaryDialog(projectName: projectName, pluginNames: pluginNames, reason: reason),
    ).future;
    return choice ?? MissingBinaryChoice.cancel;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('missing_editor_binary_dialog'),
      title: const Text('Editor binary not found'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$projectName uses code plugins (${pluginNames.join(', ')}). The editor for this project has not been '
              'built on this machine. Build it now?',
              style: const TextStyle(fontSize: 12, color: EditorColors.foreground),
            ),
            const SizedBox(height: 8),
            Text(reason, key: const Key('missing_editor_binary_reason'),
                style: const TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
          ],
        ),
      ),
      actions: [
        GhostButton(
          key: const Key('missing_editor_binary_cancel'),
          onPressed: () => Navigator.of(context).pop(MissingBinaryChoice.cancel),
          child: const Text('Cancel'),
        ),
        OutlineButton(
          key: const Key('missing_editor_binary_open_without'),
          onPressed: () => Navigator.of(context).pop(MissingBinaryChoice.openWithoutPlugins),
          child: const Text('Open without plugins'),
        ),
        PrimaryButton(
          key: const Key('missing_editor_binary_build'),
          onPressed: () => Navigator.of(context).pop(MissingBinaryChoice.buildAndOpen),
          child: const Text('Build & Open'),
        ),
      ],
    );
  }
}
