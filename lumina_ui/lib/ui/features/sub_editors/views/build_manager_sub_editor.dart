import 'dart:async';

import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:lumina/lumina.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../core/theme/editor_theme.dart';
import '../../main_editor/view_models/editor_view_model.dart';
import '../services/build_pipeline_service.dart';
import '../sub_editor_binding.dart';
import '../view_models/build_manager_view_model.dart';

/// Build Manager (honestly scoped): the four real build steps
/// (material precompile, navigation bake, thumbnail regeneration, asset
/// validation) plus Cook & Package through a real `flutter build`.
///
/// Left: step checklist with live status badges + durations. Center: the
/// pipeline's log console and the validation issue table. Right: target /
/// configuration / extra flags / artifact path. Bottom: global progress,
/// stage, elapsed time, Cancel. Nothing here is fabricated — every number
/// and line comes from a [BuildEvent].
class BuildManagerSubEditor extends StatefulWidget {
  final String assetName;
  final String? projectDirPath;
  final LuminaProject? initialProject;
  final EditorViewModel? editorViewModel;
  final BuildManagerViewModel? viewModel;
  final VoidCallback? onClose;
  final SubEditorBindCallback? onBind;
  final void Function(ValidationIssue issue)? onRevealIssue;

  const BuildManagerSubEditor({
    super.key,
    required this.assetName,
    this.projectDirPath,
    this.initialProject,
    this.editorViewModel,
    this.viewModel,
    this.onClose,
    this.onBind,
    this.onRevealIssue,
  });

  @override
  State<BuildManagerSubEditor> createState() => _BuildManagerSubEditorState();
}

class _BuildManagerSubEditorState extends State<BuildManagerSubEditor> {
  late final BuildManagerViewModel _vm;
  late final bool _ownsVm;
  final ScrollController _logScroll = ScrollController();
  final TextEditingController _flagsController = TextEditingController();
  bool _pinToBottom = true;
  int _renderedLogCount = 0;

  @visibleForTesting
  BuildManagerViewModel get viewModelForTest => _vm;

  @override
  void initState() {
    super.initState();
    if (widget.viewModel != null) {
      _vm = widget.viewModel!;
      _ownsVm = false;
    } else if (widget.editorViewModel != null) {
      _vm = widget.editorViewModel!.buildManagerViewModel;
      _ownsVm = false;
    } else {
      _vm = BuildManagerViewModel(projectDirPath: widget.projectDirPath ?? '', project: widget.initialProject);
      _ownsVm = true;
    }
    _vm.confirmCookDespiteValidation ??= _confirmCook;
    if (widget.onRevealIssue != null) _vm.onRevealIssue = widget.onRevealIssue;
    _flagsController.text = _vm.extraFlags;
    _vm.addListener(_onVm);
    widget.onBind?.call(_vm, _vm.save, () => _vm.isDirty);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _vm.init();
    });
  }

  void _onVm() {
    if (!mounted) return;
    setState(() {});
    if (_pinToBottom && _vm.logLines.length != _renderedLogCount) {
      _renderedLogCount = _vm.logLines.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _logScroll.hasClients) {
          _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_onVm);
    _logScroll.dispose();
    _flagsController.dispose();
    if (_ownsVm) _vm.dispose();
    super.dispose();
  }

  Future<bool> _confirmCook(List<ValidationIssue> issues) async {
    if (!mounted) return false;
    final errors = issues.where((i) => i.severity == ValidationSeverity.error).length;
    final completer = Completer<bool>();
    void finish(BuildContext dialogContext, bool go) {
      closeOverlay(dialogContext);
      if (!completer.isCompleted) completer.complete(go);
    }

    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogContext) => AlertDialog(
        title: const Text('Asset validation failed'),
        content: Text(
          '$errors error(s) and ${issues.length - errors} warning(s) were found in contents/. '
          'Cook & Package the project anyway? Broken references ship as-is.',
          style: const TextStyle(fontSize: 11),
        ),
        actions: [
          OutlineButton(
            key: const ValueKey('build_manager_confirm_cook_no'),
            onPressed: () => finish(dialogContext, false),
            child: const Text('Stop'),
          ),
          DestructiveButton(
            key: const ValueKey('build_manager_confirm_cook_yes'),
            onPressed: () => finish(dialogContext, true),
            child: const Text('Cook anyway'),
          ),
        ],
      ),
    );
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _toolbar(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 900;
              return Row(
                children: [
                  SizedBox(width: narrow ? 210 : 250, child: _leftPanel()),
                  Expanded(child: _centerPanel()),
                  SizedBox(width: narrow ? 220 : 260, child: _rightPanel()),
                ],
              );
            },
          ),
        ),
        _bottomBar(),
      ],
    );
  }

  // --- toolbar ------------------------------------------------------------

  Widget _toolbar() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: EditorColors.cardHeader,
      child: Row(
        children: [
          const Icon(LucideIcons.hammer, size: 16, color: EditorColors.primary),
          const SizedBox(width: 8),
          const Text('Project Build & Cooking Manager',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
          const SizedBox(width: 8),
          if (_vm.flutterVersion != null)
            OutlineBadge(child: Text(_vm.flutterVersion!, style: const TextStyle(fontSize: 8))),
          const Spacer(),
          if (widget.onClose != null)
            GhostButton(onPressed: widget.onClose!, child: const Icon(LucideIcons.x, size: 14)),
        ],
      ),
    );
  }

  // --- left: steps ----------------------------------------------------------

  static const List<BuildStepKind> _assetSteps = [
    BuildStepKind.precompileMaterials,
    BuildStepKind.buildNavigation,
    BuildStepKind.regenerateThumbnails,
    BuildStepKind.validateAssets,
  ];

  Widget _leftPanel() {
    return Container(
      color: EditorColors.cardHeader,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Build Steps', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.primary)),
          const SizedBox(height: 8),
          for (final kind in _assetSteps) _stepRow(kind),
          const Divider(),
          _stepRow(BuildStepKind.cookAndPackage, checkable: false),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              key: const ValueKey('build_manager_build_all'),
              onPressed: _vm.isRunning ? null : () => _vm.buildAll(),
              child: const Text('Build All', style: TextStyle(fontSize: 10)),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: Tooltip(
              tooltip: (_) => TooltipContainer(
                child: Text(
                  _vm.cookDisabledReason ?? _vm.cookArguments.values.map((a) => 'flutter ${a.join(' ')}').join('\n'),
                  style: const TextStyle(fontSize: 9),
                ),
              ),
              child: PrimaryButton(
                key: const ValueKey('build_manager_cook'),
                onPressed: _vm.cookEnabled ? () => _vm.cookAndPackage() : null,
                child: const Text('Cook & Package', style: TextStyle(fontSize: 10)),
              ),
            ),
          ),
          if (_vm.cookDisabledReason != null && !_vm.isRunning) ...[
            const SizedBox(height: 4),
            Text(
              _vm.cookDisabledReason!,
              key: const ValueKey('build_manager_cook_disabled_reason'),
              style: const TextStyle(fontSize: 8, color: EditorColors.logWarning),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepRow(BuildStepKind kind, {bool checkable = true}) {
    final state = _vm.stepState(kind);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          if (checkable)
            Checkbox(
              key: ValueKey('build_manager_step_${kind.name}'),
              state: _vm.isStepEnabled(kind) ? CheckboxState.checked : CheckboxState.unchecked,
              onChanged: _vm.isRunning ? null : (s) => _vm.setStepEnabled(kind, s == CheckboxState.checked),
            )
          else
            const Icon(LucideIcons.package, size: 12, color: EditorColors.mutedForeground),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kind.label, style: const TextStyle(fontSize: 9, color: EditorColors.foreground)),
                if (state.duration != null)
                  Text(
                    _fmt(state.duration!),
                    key: ValueKey('build_manager_duration_${kind.name}'),
                    style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
                  ),
              ],
            ),
          ),
          _statusBadge(kind, state.status),
        ],
      ),
    );
  }

  Widget _statusBadge(BuildStepKind kind, BuildStepStatus status) {
    final key = ValueKey('build_manager_badge_${kind.name}');
    final label = Text(status.name.toUpperCase(), style: const TextStyle(fontSize: 8));
    return switch (status) {
      BuildStepStatus.pending => OutlineBadge(key: key, child: label),
      BuildStepStatus.running => PrimaryBadge(key: key, child: label),
      BuildStepStatus.ok => SecondaryBadge(key: key, child: Text('OK', style: TextStyle(fontSize: 8, color: EditorColors.logSuccess))),
      BuildStepStatus.failed => DestructiveBadge(key: key, child: label),
      BuildStepStatus.skipped => SecondaryBadge(key: key, child: label),
      BuildStepStatus.cancelled => DestructiveBadge(key: key, child: label),
    };
  }

  // --- center: log + issues -------------------------------------------------

  Widget _centerPanel() {
    final lines = _vm.logLines;
    final counter = _vm.currentStep != null ? _vm.stepState(_vm.currentStep!).progressLabel : _lastProgressLabel();
    return Container(
      color: EditorColors.background,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  counter ?? _vm.currentStage,
                  key: const ValueKey('build_manager_counter'),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.logWarning),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GhostButton(
                key: const ValueKey('build_manager_pin_bottom'),
                onPressed: () => setState(() => _pinToBottom = !_pinToBottom),
                child: Row(children: [
                  Icon(_pinToBottom ? LucideIcons.pin : LucideIcons.pinOff, size: 10, color: EditorColors.primary),
                  const SizedBox(width: 4),
                  Text(_pinToBottom ? 'Pinned' : 'Free', style: const TextStyle(fontSize: 9, color: EditorColors.primary)),
                ]),
              ),
              GhostButton(
                key: const ValueKey('build_manager_copy_log'),
                onPressed: () => Clipboard.setData(ClipboardData(text: _vm.logText)),
                child: const Row(children: [
                  Icon(LucideIcons.copy, size: 10, color: EditorColors.primary),
                  SizedBox(width: 4),
                  Text('Copy Log', style: TextStyle(fontSize: 9, color: EditorColors.primary)),
                ]),
              ),
              GhostButton(
                key: const ValueKey('build_manager_clear_log'),
                onPressed: _vm.clearLog,
                child: const Row(children: [
                  Icon(LucideIcons.trash2, size: 10, color: EditorColors.logError),
                  SizedBox(width: 4),
                  Text('Clear', style: TextStyle(fontSize: 9, color: EditorColors.logError)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: EditorColors.border),
              ),
              child: lines.isEmpty
                  ? const Center(
                      child: Text('No build output yet — pick steps and press Build All or Cook & Package.',
                          style: TextStyle(fontSize: 9, fontFamily: EditorTypography.monoFamily, color: EditorColors.mutedForeground)))
                  : ListView.builder(
                      key: const ValueKey('build_manager_log'),
                      controller: _logScroll,
                      itemCount: lines.length,
                      itemBuilder: (context, i) => _logLine(lines[i]),
                    ),
            ),
          ),
          if (_vm.issues.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Validation issues (${_vm.issues.length})',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.logError)),
            const SizedBox(height: 4),
            Expanded(flex: 2, child: _issueTable()),
          ],
        ],
      ),
    );
  }

  String? _lastProgressLabel() {
    for (final k in BuildStepKind.values.reversed) {
      final l = _vm.stepState(k).progressLabel;
      if (l != null) return l;
    }
    return null;
  }

  Widget _logLine(BuildLogLine l) {
    final color = switch (l.level) {
      'error' => EditorColors.logError,
      'warning' => EditorColors.logWarning,
      'success' => EditorColors.logSuccess,
      _ => EditorColors.foreground,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.timestamp, style: const TextStyle(fontSize: 9, fontFamily: EditorTypography.monoFamily, color: EditorColors.mutedForeground)),
          const SizedBox(width: 6),
          Text('[${l.source}]',
              style: const TextStyle(fontSize: 9, fontFamily: EditorTypography.monoFamily, fontWeight: FontWeight.bold, color: EditorColors.primary)),
          const SizedBox(width: 6),
          Expanded(child: Text(l.message, style: TextStyle(fontSize: 9, fontFamily: EditorTypography.monoFamily, color: color))),
        ],
      ),
    );
  }

  Widget _issueTable() {
    TableCell head(String t) => TableCell(child: Padding(padding: const EdgeInsets.all(4), child: Text(t, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold))));
    TableCell cell(Widget w) => TableCell(child: Padding(padding: const EdgeInsets.all(4), child: w));
    final rows = <TableRow>[
      TableHeader(cells: [head('Asset'), head('Slot'), head('Missing target'), head('Kind'), head('')]),
      for (var i = 0; i < _vm.issues.length; i++)
        TableRow(cells: [
          cell(Text(_vm.issues[i].assetPath, key: ValueKey('build_manager_issue_row_$i'), style: const TextStyle(fontSize: 9))),
          cell(Text(_vm.issues[i].slotName, style: const TextStyle(fontSize: 9))),
          cell(Text(_vm.issues[i].targetPath, style: const TextStyle(fontSize: 9, color: EditorColors.logError))),
          cell(Text(
            '${_vm.issues[i].kind.name} (${_vm.issues[i].severity.name})',
            style: TextStyle(fontSize: 9, color: _vm.issues[i].severity == ValidationSeverity.error ? EditorColors.logError : EditorColors.logWarning),
          )),
          cell(OutlineButton(
            key: ValueKey('build_manager_reveal_$i'),
            size: ButtonSize.small,
            onPressed: _vm.onRevealIssue == null ? null : () => _vm.onRevealIssue!(_vm.issues[i]),
            child: const Text('Reveal in Content Browser', style: TextStyle(fontSize: 8)),
          )),
        ]),
    ];
    return SingleChildScrollView(
      child: Table(rows: rows),
    );
  }

  // --- right: packaging -----------------------------------------------------

  Widget _rightPanel() {
    return Container(
      color: EditorColors.cardHeader,
      padding: const EdgeInsets.all(8),
      // Plain sections, all open: an Accordion keeps only one item expanded,
      // which hid Build Configuration and Output (and Launch in Browser).
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _section('Target Platforms', _targetSection()),
            _section('Build Configuration', _configSection()),
            _section('Output', _outputSection(), last: true),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, Widget content, {bool last = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
          const SizedBox(height: 8),
          content,
          if (!last) const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
        ],
      ),
    );
  }

  /// The project's packaging targets (the list Project Settings edits):
  /// every platform, ticked or not, with the reasons it cannot be built here.
  /// Unbuildable targets stay tickable and are
  /// reported when packaging.
  Widget _targetSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final t in kPackagingPlatforms) _targetRow(t),
        if (_vm.isProbing)
          const Text('Probing flutter doctor -v…', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
        const SizedBox(height: 4),
        const Text(
          'The project\'s packaging targets (Project Settings → Packaging & Target). Cook & Package builds every ticked one.',
          style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
        ),
      ],
    );
  }

  Widget _targetRow(String target) {
    final reasons = _vm.reasonsFor(target);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Checkbox(
              key: ValueKey('build_manager_target_$target'),
              state: _vm.isTargetSelected(target) ? CheckboxState.checked : CheckboxState.unchecked,
              onChanged: _vm.isRunning ? null : (s) => _vm.setTargetSelected(target, s == CheckboxState.checked),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(HostBuildTargets.labelFor(target), style: const TextStyle(fontSize: 9, color: EditorColors.foreground)),
            ),
          ]),
          for (var i = 0; i < reasons.length; i++)
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 1),
              child: Text(
                reasons[i],
                key: ValueKey('build_manager_target_reason_${target}_$i'),
                style: const TextStyle(fontSize: 8, color: EditorColors.logWarning),
              ),
            ),
        ],
      ),
    );
  }

  Widget _configSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Select<BuildConfiguration>(
          key: const ValueKey('build_manager_config'),
          value: _vm.configuration,
          onChanged: _vm.isRunning ? null : (c) => c != null ? _vm.setConfiguration(c) : null,
          itemBuilder: (context, item) => Text('${item.label}  (${item.flag})', style: const TextStyle(fontSize: 9.5)),
          popup: SelectPopup(
            items: SelectItemList(
              children: [
                for (final c in BuildConfiguration.values)
                  SelectItemButton(value: c, child: Text('${c.label}  (${c.flag})', style: const TextStyle(fontSize: 9.5))),
              ],
            ),
          ).call,
        ),
        // Offline web builds without typing the flag.
        if (_vm.isTargetSelected('web')) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                key: const ValueKey('build_manager_web_bundle_resources'),
                state: _vm.bundleWebResources ? CheckboxState.checked : CheckboxState.unchecked,
                onChanged: _vm.isRunning ? null : (s) => _vm.setBundleWebResources(s == CheckboxState.checked),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bundle web resources (works offline)', style: TextStyle(fontSize: 9, color: EditorColors.foreground)),
                    SizedBox(height: 2),
                    Text(
                      'CanvasKit ships inside build/web instead of loading from Google\'s CDN. Bigger build. '
                      '${CookAndPackageStep.bundleWebResourcesFlag}',
                      style: TextStyle(fontSize: 8, fontFamily: EditorTypography.monoFamily, color: EditorColors.mutedForeground),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        const Text('Extra flags', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
        const SizedBox(height: 4),
        TextField(
          key: const ValueKey('build_manager_extra_flags'),
          controller: _flagsController,
          enabled: !_vm.isRunning,
          placeholder: const Text('--dart-define=KEY=VALUE -v', style: TextStyle(fontSize: 9)),
          onChanged: _vm.setExtraFlags,
        ),
        const SizedBox(height: 6),
        Column(
          key: const ValueKey('build_manager_argv'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in _vm.cookArguments.entries)
              Text(
                'flutter ${e.value.join(' ')}',
                key: ValueKey('build_manager_argv_${e.key}'),
                style: const TextStyle(fontSize: 8, fontFamily: EditorTypography.monoFamily, color: EditorColors.mutedForeground),
              ),
          ],
        ),
      ],
    );
  }

  Widget _outputSection() {
    final targets = _vm.selectedTargets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Package folders', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
        const SizedBox(height: 4),
        if (targets.isEmpty) const Text('—', style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
        for (final t in targets) _outputRow(t),
        const SizedBox(height: 4),
        const Text(
          'Each ticked target is copied into its own folder once its flutter build succeeds.',
          style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
        ),
        // A web build is previewed through a local server.
        if (_vm.canLaunchInBrowser) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              key: const ValueKey('build_manager_launch_browser'),
              onPressed: () => _vm.launchInBrowser(),
              leading: const Icon(LucideIcons.globe, size: 12),
              child: const Text('Launch in Browser', style: TextStyle(fontSize: 10)),
            ),
          ),
          if (_vm.previewUrl != null) ...[
            const SizedBox(height: 4),
            SelectableText(
              _vm.previewUrl.toString(),
              key: const ValueKey('build_manager_preview_url'),
              style: const TextStyle(fontSize: 8, fontFamily: EditorTypography.monoFamily, color: EditorColors.logSuccess),
            ),
            const Text('Served from this editor until the next build.', style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
          ],
        ],
      ],
    );
  }

  Widget _outputRow(String target) {
    final state = _vm.targetState(target);
    final packaged = state.status == PackageTargetStatus.ok && state.packageDir != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(packagingPlatformLabel(target),
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
            ),
            if (state.status != PackageTargetStatus.pending || _vm.lastPipelineStatus != null) _targetBadge(target, state.status),
          ]),
          SelectableText(
            state.packageDir ?? _vm.packageDirFor(target),
            key: ValueKey('build_manager_artifact_path_$target'),
            style: TextStyle(
              fontSize: 8,
              fontFamily: EditorTypography.monoFamily,
              color: packaged ? EditorColors.logSuccess : EditorColors.mutedForeground,
            ),
          ),
          if (state.sizeBytes != null)
            Text(
              'Size: ${CookAndPackageStep.formatBytes(state.sizeBytes!)}',
              key: ValueKey('build_manager_artifact_size_$target'),
              style: const TextStyle(fontSize: 9, color: EditorColors.foreground),
            ),
          if (!packaged && state.message != null && state.status != PackageTargetStatus.pending)
            Text(state.message!, maxLines: 3, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 8, color: EditorColors.logError)),
        ],
      ),
    );
  }

  Widget _targetBadge(String target, PackageTargetStatus status) {
    final key = ValueKey('build_manager_target_status_$target');
    Text label(String t, [Color? c]) => Text(t, style: TextStyle(fontSize: 8, color: c));
    return switch (status) {
      PackageTargetStatus.pending => OutlineBadge(key: key, child: label('PENDING')),
      PackageTargetStatus.running => PrimaryBadge(key: key, child: label('RUNNING')),
      PackageTargetStatus.ok => SecondaryBadge(key: key, child: label('OK', EditorColors.logSuccess)),
      PackageTargetStatus.failed => DestructiveBadge(key: key, child: label('FAILED')),
      PackageTargetStatus.unbuildable => DestructiveBadge(key: key, child: label('NOT BUILDABLE')),
      PackageTargetStatus.cancelled => OutlineBadge(key: key, child: label('CANCELLED')),
    };
  }

  // --- bottom bar -------------------------------------------------------------

  Widget _bottomBar() {
    final progress = _vm.globalProgress;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: EditorColors.cardHeader,
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Progress(
              key: const ValueKey('build_manager_progress'),
              progress: _vm.isRunning ? progress : (progress ?? 0),
              color: _vm.lastPipelineStatus == BuildStepStatus.failed ? EditorColors.logError : EditorColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text('${_vm.completedSteps}/${_vm.totalSteps}', style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _vm.currentStage,
              key: const ValueKey('build_manager_stage'),
              style: const TextStyle(fontSize: 9, color: EditorColors.foreground),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(_fmt(_vm.elapsed), style: const TextStyle(fontSize: 9, fontFamily: EditorTypography.monoFamily, color: EditorColors.mutedForeground)),
          const SizedBox(width: 12),
          DestructiveButton(
            key: const ValueKey('build_manager_cancel'),
            size: ButtonSize.small,
            onPressed: _vm.isRunning ? _vm.cancel : null,
            child: const Text('Cancel', style: TextStyle(fontSize: 9)),
          ),
        ],
      ),
    );
  }

  static String _fmt(Duration d) =>
      d.inMilliseconds < 1000 ? '${d.inMilliseconds} ms' : '${(d.inMilliseconds / 1000).toStringAsFixed(1)} s';
}
