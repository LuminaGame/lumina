import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../core/services/plugin_process/plugin_process_supervisor.dart';
import '../../../core/theme/editor_theme.dart';
import '../view_models/plugin_manager_view_model.dart';

/// The Plugin Manager's word for a process state.
String pluginProcessStatusLabel(PluginProcessStatus status) => switch (status) {
      PluginProcessStatus.inProcess => 'In process',
      PluginProcessStatus.starting => 'Starting',
      PluginProcessStatus.running => 'Running',
      PluginProcessStatus.hung => 'Hung',
      PluginProcessStatus.crashed => 'Crashed',
      PluginProcessStatus.stopped => 'Stopped',
      PluginProcessStatus.disabled => 'Disabled',
    };

Color _toneOf(PluginProcessStatus status) => switch (status) {
      PluginProcessStatus.running => EditorColors.logSuccess,
      PluginProcessStatus.inProcess => EditorColors.primary,
      PluginProcessStatus.starting => EditorColors.logWarning,
      PluginProcessStatus.hung || PluginProcessStatus.crashed || PluginProcessStatus.stopped => EditorColors.destructive,
      PluginProcessStatus.disabled => EditorColors.mutedForeground,
    };

/// The Status badge of an isolated plugin's card: follows its process.
class PluginProcessStatusBadge extends StatelessWidget {
  const PluginProcessStatusBadge({super.key, required this.process});

  final PluginProcessSupervisor process;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<PluginProcessState>(
        valueListenable: process.state,
        builder: (context, state, _) {
          final color = _toneOf(state.status);
          final badge = Container(
            key: ValueKey('plugin_process_status_${process.pluginName}'),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text(pluginProcessStatusLabel(state.status),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
              ],
            ),
          );
          final reason = state.reason;
          if (reason == null || state.isAvailable) return badge;
          return Tooltip(tooltip: (_) => TooltipContainer(child: Text(reason)), child: badge);
        },
      );
}

/// The details pane's Process section of an isolated plugin: its status
/// and reason, last exit code, Restart, the per-project "Run in editor
/// process (debugging)" switch and the tail of its log.
class PluginProcessSection extends StatelessWidget {
  const PluginProcessSection({super.key, required this.viewModel, required this.process});

  final PluginManagerViewModel viewModel;
  final PluginProcessSupervisor process;

  @override
  Widget build(BuildContext context) {
    final name = process.pluginName;
    final muted = Theme.of(context).colorScheme.mutedForeground;
    return ListenableBuilder(
      listenable: Listenable.merge([process.state, process.logRevision]),
      builder: (context, _) {
        final state = process.state.value;
        final exit = process.lastExitCode;
        final tail = process.logTail;
        final shown = tail.length > 60 ? tail.sublist(tail.length - 60) : tail;
        return Column(
          key: ValueKey('plugin_process_section_$name'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Process', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Row(
              children: [
                PluginProcessStatusBadge(process: process),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    [
                      if (state.reason != null && !state.isAvailable) state.reason!,
                      if (state.pid != null) 'pid ${state.pid}',
                      if (exit != null) 'last exit code $exit',
                      if (state.restarts > 0) '${state.restarts} automatic restart(s)',
                    ].join(' · '),
                    key: ValueKey('plugin_process_detail_$name'),
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ),
                const SizedBox(width: 8),
                OutlineButton(
                  key: ValueKey('plugin_process_manager_restart_$name'),
                  size: ButtonSize.small,
                  leading: const Icon(LucideIcons.rotateCw, size: 13),
                  enabled: !viewModel.switchingIsolation,
                  onPressed: () => viewModel.restartProcess(name),
                  child: const Text('Restart'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Switch(
                  key: ValueKey('plugin_process_in_editor_$name'),
                  value: viewModel.runsInEditor(name),
                  onChanged: viewModel.switchingIsolation ? null : (v) => viewModel.setRunInEditorProcess(name, v),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Run in editor process (debugging): this project runs the plugin inside the editor, '
                    'where a crash or hang in it affects the editor.',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              key: ValueKey('plugin_process_manager_log_$name'),
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 180),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: EditorColors.background,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: EditorColors.border),
              ),
              child: SingleChildScrollView(
                reverse: true,
                child: SelectableText(
                  shown.isEmpty ? '(no output yet)' : shown.join('\n'),
                  style: const TextStyle(fontSize: 10, fontFamily: EditorTypography.monoFamily, color: EditorColors.foreground),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}
