
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:lumina/lumina.dart' show EngineBootstrapStep, EngineCheckout, EnginePrerequisite;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../core/host/editor_host.dart';
import '../../../core/theme/editor_theme.dart';
import '../view_models/engine_bootstrap_view_model.dart';

/// The first-launch screen of an installed Lumina Studio: it fetches the
/// engine source of its own release before the launcher opens. Steps with
/// progress (prerequisites, engine source, Filament, packages), the log, a
/// clear report of missing prerequisites and Retry.
class EngineBootstrapView extends StatefulWidget {
  const EngineBootstrapView(
      {super.key, required this.viewModel, required this.onReady, this.autoStart = true, this.force = false, this.onQuit, this.quitLabel = 'Quit'});

  final EngineBootstrapViewModel viewModel;

  /// The checkout is ready (and active): continue to the launcher.
  final void Function(EngineCheckout checkout) onReady;

  /// Start the bootstrap when the screen appears.
  final bool autoStart;

  /// Delete the checkout and download it again ("Re-download engine").
  final bool force;

  /// Quit (default: exit the process).
  final VoidCallback? onQuit;

  /// The label of the [onQuit] button.
  final String quitLabel;

  @override
  State<EngineBootstrapView> createState() => _EngineBootstrapViewState();
}

class _EngineBootstrapViewState extends State<EngineBootstrapView> {
  bool _showLog = false;
  final ScrollController _logScroll = ScrollController();

  EngineBootstrapViewModel get vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    vm.addListener(_changed);
    if (widget.autoStart) _start();
  }

  void _start({bool retry = false}) {
    (retry ? vm.retry() : vm.start(force: widget.force)).then((checkout) {
      if (mounted && checkout != null) widget.onReady(checkout);
    });
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (_showLog && _logScroll.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_logScroll.hasClients) _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
      });
    }
  }

  @override
  void dispose() {
    vm.removeListener(_changed);
    _logScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = vm.bootstrap;
    final commit = b.commit.isEmpty ? b.version : b.commit.substring(0, b.commit.length < 12 ? b.commit.length : 12);
    return Container(
      key: const Key('engine_bootstrap_view'),
      color: EditorColors.background,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Image.asset('assets/logo_color.png', height: 36, errorBuilder: (_, _, _) => const SizedBox(height: 36)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Setting up Lumina Studio',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: EditorColors.foreground)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Lumina Studio ${b.version} builds games from the engine source of its own release. This first start '
                'downloads it once (commit $commit) with the matching prebuilt Filament and OpenRigLogic libraries; later starts work offline.',
                style: const TextStyle(fontSize: 12, color: EditorColors.mutedForeground),
              ),
              const SizedBox(height: 4),
              Text(b.checkoutDir.path,
                  key: const Key('engine_bootstrap_checkout_path'),
                  style: const TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
              const SizedBox(height: 16),
              _card([for (final s in EngineBootstrapStep.values) _stepRow(s)]),
              if (vm.failed) ...[const SizedBox(height: 12), _errorPanel()],
              if (vm.warnings.isNotEmpty) ...[const SizedBox(height: 12), _warningPanel(vm.warnings)],
              const SizedBox(height: 12),
              Row(
                children: [
                  GhostButton(
                    key: const Key('engine_bootstrap_toggle_log'),
                    density: ButtonDensity.compact,
                    onPressed: () => setState(() => _showLog = !_showLog),
                    leading: const Icon(LucideIcons.terminal, size: 12),
                    child: Text(_showLog ? 'Hide log' : 'Show log', style: const TextStyle(fontSize: 11)),
                  ),
                  GhostButton(
                    key: const Key('engine_bootstrap_copy_log'),
                    density: ButtonDensity.compact,
                    onPressed: () => Clipboard.setData(ClipboardData(text: vm.log.join('\n'))),
                    leading: const Icon(LucideIcons.copy, size: 12),
                    child: const Text('Copy log', style: TextStyle(fontSize: 11)),
                  ),
                  const Spacer(),
                  if (vm.failed || vm.running)
                    OutlineButton(
                      key: const Key('engine_bootstrap_quit'),
                      onPressed: widget.onQuit ?? () => EditorHandOff.instance.quit(),
                      child: Text(widget.quitLabel),
                    ),
                  if (vm.failed) ...[
                    const SizedBox(width: 8),
                    PrimaryButton(
                      key: const Key('engine_bootstrap_retry'),
                      onPressed: () => _start(retry: true),
                      leading: const Icon(LucideIcons.refreshCw, size: 14),
                      child: const Text('Retry'),
                    ),
                  ],
                ],
              ),
              if (_showLog) ...[const SizedBox(height: 8), _logPanel()],
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(List<Widget> children, {Key? key, Color? border}) => Container(
        key: key,
        decoration: BoxDecoration(
          color: EditorColors.card,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border ?? EditorColors.border),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );

  Widget _stepRow(EngineBootstrapStep s) {
    final st = vm.step(s);
    final (IconData icon, Color color) = switch (st.status) {
      BootstrapStepStatus.pending => (LucideIcons.circle, EditorColors.mutedForeground),
      BootstrapStepStatus.running => (LucideIcons.loaderCircle, EditorColors.primary),
      BootstrapStepStatus.done || BootstrapStepStatus.skipped => (LucideIcons.circleCheck, EditorColors.chart3),
      BootstrapStepStatus.failed => (LucideIcons.circleX, EditorColors.destructive),
    };
    return Padding(
      key: Key('engine_bootstrap_step_${s.name}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s.label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: st.status == BootstrapStepStatus.running ? FontWeight.w600 : FontWeight.normal,
                        color: st.status == BootstrapStepStatus.pending ? EditorColors.mutedForeground : EditorColors.foreground)),
                if (st.message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(st.message,
                        key: Key('engine_bootstrap_step_${s.name}_message'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            color: st.status == BootstrapStepStatus.failed ? EditorColors.destructive : EditorColors.mutedForeground)),
                  ),
                if (st.status == BootstrapStepStatus.running)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: LinearProgressIndicator(
                      key: Key('engine_bootstrap_step_${s.name}_progress'),
                      value: st.fraction,
                      minHeight: 3,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorPanel() {
    final missing = vm.missing;
    final error = vm.error!;
    return _card(
      key: const Key('engine_bootstrap_error'),
      border: EditorColors.destructive,
      [
        Row(
          children: [
            const Icon(LucideIcons.circleAlert, size: 16, color: EditorColors.destructive),
            const SizedBox(width: 8),
            Expanded(
              child: Text(missing.isNotEmpty ? 'Missing prerequisites' : 'Setup stopped',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: EditorColors.foreground)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (missing.isEmpty)
          Text(error.message, style: const TextStyle(fontSize: 12, color: EditorColors.foreground))
        else
          for (final pr in missing) _prerequisiteRow(pr),
        const SizedBox(height: 8),
        Text(
          missing.isNotEmpty
              ? 'The Lumina installer sets these up: run it again (or install them yourself), then press Retry.'
              : 'Everything downloaded so far is kept: Retry continues where this stopped.',
          key: const Key('engine_bootstrap_hint'),
          style: const TextStyle(fontSize: 11, color: EditorColors.mutedForeground),
        ),
      ],
    );
  }

  Widget _warningPanel(List<EnginePrerequisite> warnings) => _card(
        key: const Key('engine_bootstrap_warnings'),
        border: EditorColors.warning,
        [
          const Row(
            children: [
              Icon(LucideIcons.triangleAlert, size: 16, color: EditorColors.warning),
              SizedBox(width: 8),
              Expanded(
                child: Text('C++ toolchain not found',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: EditorColors.foreground)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('The editor starts without it, but building and playing games needs it. The Lumina installer sets it up.',
              style: TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
          const SizedBox(height: 6),
          for (final pr in warnings) _prerequisiteRow(pr),
        ],
      );

  Widget _prerequisiteRow(EnginePrerequisite pr) => Padding(
        key: Key('engine_bootstrap_missing_${pr.name}'),
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(pr.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: EditorColors.foreground)),
            Text(pr.hint, style: const TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
          ],
        ),
      );

  Widget _logPanel() => Container(
        key: const Key('engine_bootstrap_log'),
        height: 220,
        decoration: BoxDecoration(
          color: EditorColors.rail,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: EditorColors.border),
        ),
        padding: const EdgeInsets.all(8),
        child: ListView.builder(
          controller: _logScroll,
          itemCount: vm.log.length,
          itemBuilder: (_, i) => Text(vm.log[i],
              style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 10, height: 1.3, color: EditorColors.mutedForeground)),
        ),
      );
}
