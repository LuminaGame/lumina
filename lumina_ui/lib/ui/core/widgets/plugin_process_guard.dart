import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../theme/editor_theme.dart';

/// Wraps a panel, tab or asset editor of a plugin that runs in its own
/// process. While the process runs it shows [child] untouched; while it
/// starts, a small spinner sits over the top-right corner; while it is hung,
/// crashed or stopped, [child] is dimmed under a card saying
/// "`<plugin>` stopped: `<reason>`" with Restart and Details (the process's
/// log tail, from [logTail]).
class PluginProcessGuard extends StatefulWidget {
  const PluginProcessGuard({super.key, required this.channel, required this.child, this.logTail, this.logRevision});

  final PluginProcessChannel channel;
  final Widget child;

  /// The process's recent output, shown by Details.
  final List<String> Function()? logTail;

  /// Changes when [logTail] grows (Details follows it).
  final Listenable? logRevision;

  @override
  State<PluginProcessGuard> createState() => _PluginProcessGuardState();
}

class _PluginProcessGuardState extends State<PluginProcessGuard> {
  bool _details = false;
  bool _restarting = false;

  Future<void> _restart() async {
    setState(() => _restarting = true);
    try {
      await widget.channel.restart();
    } finally {
      if (mounted) setState(() => _restarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.channel.pluginName;
    return ValueListenableBuilder<PluginProcessState>(
      valueListenable: widget.channel.state,
      builder: (context, state, _) {
        // The child keeps its place (and its state) in every case.
        final content = KeyedSubtree(key: const ValueKey('plugin_process_guard_child'), child: widget.child);
        if (state.isAvailable || state.status == PluginProcessStatus.disabled) return content;
        if (state.status == PluginProcessStatus.starting) {
          return Stack(
            children: [
              content,
              Positioned(
                top: 6,
                right: 6,
                child: Tooltip(
                  tooltip: (_) => TooltipContainer(child: Text('$name is starting')),
                  child: SizedBox(
                    key: ValueKey('plugin_process_starting_$name'),
                    width: 14,
                    height: 14,
                    child: const CircularProgressIndicator(size: 14, strokeWidth: 1.6),
                  ),
                ),
              ),
            ],
          );
        }
        return LayoutBuilder(builder: (context, constraints) {
          final card = _stoppedCard(context, name, state);
          if (!constraints.hasBoundedHeight || !constraints.hasBoundedWidth) {
            // A panel in a scroll view: the card, the panel kept alive but
            // hidden under it.
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(padding: const EdgeInsets.all(12), child: card),
                Visibility(visible: false, maintainState: true, child: content),
              ],
            );
          }
          // The whole area: the panel dimmed behind the card.
          return SizedBox.expand(
            child: Stack(
              children: [
                Positioned.fill(child: IgnorePointer(child: Opacity(opacity: 0.25, child: content))),
                Positioned.fill(
                  child: Container(
                    color: EditorColors.background.withValues(alpha: 0.55),
                    alignment: Alignment.topCenter,
                    padding: const EdgeInsets.all(12),
                    child: SingleChildScrollView(child: card),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _stoppedCard(BuildContext context, String name, PluginProcessState state) {
    final reason = state.reason ?? state.status.name;
    final waiting = state.status != PluginProcessStatus.stopped;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Card(
        key: ValueKey('plugin_process_stopped_$name'),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.plugZap, size: 16, color: EditorColors.destructive),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$name stopped: $reason',
                    key: ValueKey('plugin_process_reason_$name'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EditorColors.foreground),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              waiting
                  ? 'It runs in its own process; the editor is unaffected. It restarts on its own shortly, or now with Restart.'
                  : 'It runs in its own process; the editor is unaffected. Restart starts it again.',
              style: const TextStyle(fontSize: 11, color: EditorColors.mutedForeground),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                PrimaryButton(
                  key: ValueKey('plugin_process_restart_$name'),
                  size: ButtonSize.small,
                  enabled: !_restarting,
                  leading: const Icon(LucideIcons.rotateCw, size: 13),
                  onPressed: _restart,
                  child: const Text('Restart'),
                ),
                const SizedBox(width: 8),
                if (widget.logTail != null)
                  OutlineButton(
                    key: ValueKey('plugin_process_details_$name'),
                    size: ButtonSize.small,
                    leading: Icon(_details ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 13),
                    onPressed: () => setState(() => _details = !_details),
                    child: const Text('Details'),
                  ),
              ],
            ),
            if (_details && widget.logTail != null) ...[
              const SizedBox(height: 10),
              _LogTail(lines: widget.logTail!, revision: widget.logRevision, keyName: name),
            ],
          ],
        ),
      ),
    );
  }
}

/// The last lines of a plugin process's log, newest at the bottom.
class _LogTail extends StatelessWidget {
  const _LogTail({required this.lines, required this.revision, required this.keyName});

  final List<String> Function() lines;
  final Listenable? revision;
  final String keyName;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: revision ?? const AlwaysStoppedAnimation(0),
        builder: (context, _) {
          final all = lines();
          final tail = all.length > 40 ? all.sublist(all.length - 40) : all;
          return Container(
            key: ValueKey('plugin_process_log_$keyName'),
            constraints: const BoxConstraints(maxHeight: 220),
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: EditorColors.background,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: EditorColors.border),
            ),
            child: SingleChildScrollView(
              reverse: true,
              child: SelectableText(
                tail.isEmpty ? '(no output)' : tail.join('\n'),
                style: const TextStyle(fontSize: 10, fontFamily: EditorTypography.monoFamily, color: EditorColors.foreground),
              ),
            ),
          );
        },
      );
}
