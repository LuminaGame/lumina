import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/services/plugin_process/kernel_plugin_preparer.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_supervisor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/plugin_manager/view_models/plugin_manager_view_model.dart';

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

/// The "Kernel" badge of a kernel plugin's card: it runs on the Dart VM,
/// with the SDK of its kernel and whether that kernel is the shipped one or
/// was recompiled for this SDK; "Preparing…" while it is recompiled.
class KernelPluginBadge extends StatelessWidget {
  const KernelPluginBadge({super.key, required this.viewModel, required this.plugin});

  final PluginManagerViewModel viewModel;
  final String plugin;

  /// "Kernel · Dart 3.13.4 · shipped" and friends.
  static String labelOf(KernelPluginState? state) {
    if (state == null) return 'Kernel';
    if (state.progress != null) return 'Kernel · preparing';
    if (state.error != null) return 'Kernel · error';
    final sdk = state.vmSdk == null ? null : 'Dart ${state.vmSdk}';
    final source = switch (state.source) {
      KernelSource.shipped => 'shipped',
      KernelSource.recompiled => 'recompiled',
      KernelSource.cached => 'recompiled (cached)',
      null => null,
    };
    return ['Kernel', ?sdk, ?source].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final state = viewModel.kernelStateOf(plugin);
    final tooltip = state?.progress ??
        state?.error ??
        'Runs on the Dart VM from its kernel; enabled and disabled live, no editor build.';
    return Tooltip(
      tooltip: (_) => TooltipContainer(child: Text(tooltip)),
      child: OutlineBadge(
        key: ValueKey('plugin_kernel_badge_$plugin'),
        child: Text(labelOf(state), style: const TextStyle(fontSize: 10)),
      ),
    );
  }
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
        final unavailable = viewModel.inEditorUnavailableReason(name);
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
            if (viewModel.isKernel(name)) _KernelDetails(viewModel: viewModel, process: process),
            const SizedBox(height: 8),
            Row(
              children: [
                Switch(
                  key: ValueKey('plugin_process_in_editor_$name'),
                  value: unavailable == null && viewModel.runsInEditor(name),
                  onChanged: viewModel.switchingIsolation || unavailable != null
                      ? null
                      : (v) => viewModel.setRunInEditorProcess(name, v),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    unavailable == null
                        ? 'Run in editor process (debugging): this project runs the plugin inside the editor, '
                            'where a crash or hang in it affects the editor.'
                        : 'Run in editor process (debugging) is not available: $unavailable.',
                    key: ValueKey('plugin_process_in_editor_note_$name'),
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

/// A kernel plugin's kernel in the Process section: the SDK, shipped or
/// recompiled, the recompile progress, and a failed preparation with the
/// compiler's output.
class _KernelDetails extends StatelessWidget {
  const _KernelDetails({required this.viewModel, required this.process});

  final PluginManagerViewModel viewModel;
  final PluginProcessSupervisor process;

  @override
  Widget build(BuildContext context) {
    final name = process.pluginName;
    final state = viewModel.kernelStateOf(name);
    final muted = Theme.of(context).colorScheme.mutedForeground;
    final lines = <String>[
      if (state?.vmSdk != null) 'Dart VM ${state!.vmSdk}',
      if (state?.shippedSdk != null) 'shipped kernel built by Dart ${state!.shippedSdk}',
      if (state?.source == KernelSource.shipped) 'running the shipped kernel',
      if (state?.source == KernelSource.recompiled) 'recompiled for this SDK',
      if (state?.source == KernelSource.cached) 'recompiled for this SDK (cached)',
    ];
    final error = process.preparationError ?? state?.error;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        key: ValueKey('plugin_kernel_details_$name'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kernel plugin: runs on the Dart VM; enabling or disabling it needs no editor build.',
              style: TextStyle(fontSize: 11, color: muted)),
          if (lines.isNotEmpty) Text(lines.join(' · '), style: TextStyle(fontSize: 11, color: muted)),
          if (state?.progress != null)
            Text(state!.progress!,
                key: ValueKey('plugin_kernel_progress_$name'),
                style: const TextStyle(fontSize: 11, color: EditorColors.logWarning)),
          if (error != null)
            Text(error,
                key: ValueKey('plugin_kernel_error_$name'),
                maxLines: 12,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: EditorColors.destructive)),
        ],
      ),
    );
  }
}
