import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Shown after a code plugin was enabled or disabled. Restart
/// Editor saves and hands off to the launcher, which rebuilds this project's
/// editor — the same routine as the `editor.restart` command.
class RestartRequiredBanner extends StatelessWidget {
  final VoidCallback onDismiss;
  final VoidCallback onRestart;

  const RestartRequiredBanner({
    super.key,
    required this.onDismiss,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            DestructiveBadge(
              child: const Text('Warning'),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text("Plugin changes require rebuilding this project's editor"),
            ),
            OutlineButton(
              onPressed: onRestart,
              child: const Text('Restart Editor'),
            ),
            const SizedBox(width: 8),
            GhostButton(
              onPressed: onDismiss,
              child: const Text('Later'),
            ),
          ],
        ),
      ),
    );
  }
}
