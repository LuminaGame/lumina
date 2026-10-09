part of '../../project_settings_sub_editor.dart';

/// Packaging & Target category: target rows, status badges and the
/// packaging log console.
mixin _ProjectSettingsPackaging on _ProjectSettingsSubEditorStateBase {

  @override
  Widget _buildPackaging() {
    final pk = _vm.project.packaging;
    final run = _vm.packaging;
    if (_vm.hostTargets == null && !_vm.isProbingTargets) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _vm.probeTargets();
      });
    }
    final disabled = _vm.packageDisabledReason;
    return _section('Packaging & Target', [
      _row(
        'Target Platforms',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final t in kPackagingPlatforms) _targetRow(t, pk.isSelected(t), run),
            if (_vm.isProbingTargets)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Probing flutter doctor -v…', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
              ),
          ],
        ),
        help: 'Package Project builds every ticked platform in turn',
      ),
      _row(
        'Output Directory',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            key: const ValueKey('project_settings_output_dir'),
            controller: _controllerFor('outdir', pk.outputDir),
            focusNode: _focusFor('outdir'),
            onChanged: _vm.setOutputDir,
          ),
          const SizedBox(height: 3),
          Text(
            'Each target goes to ${pk.outputDirIn(_vm.projectDirPath)}/package/<target>',
            key: const ValueKey('project_settings_output_resolved'),
            style: const TextStyle(fontSize: 8.5, fontFamily: EditorTypography.monoFamily, color: EditorColors.mutedForeground),
          ),
        ]),
      ),
      _row(
        'Package Project',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            PrimaryButton(
              key: const ValueKey('project_settings_package'),
              onPressed: disabled == null ? () => _vm.packageProject() : null,
              child: Text(run.isRunning ? 'Packaging…' : 'Package Project', style: const TextStyle(fontSize: 10)),
            ),
            if (run.isRunning) ...[
              const SizedBox(width: 8),
              OutlineButton(
                key: const ValueKey('project_settings_package_cancel'),
                onPressed: _vm.cancelPackaging,
                child: const Text('Cancel', style: TextStyle(fontSize: 10)),
              ),
            ],
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                run.stage ?? disabled ?? 'Shipping configuration (flutter build … --release)',
                key: const ValueKey('project_settings_package_stage'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  color: run.result == BuildStepStatus.ok
                      ? EditorColors.logSuccess
                      : run.result != null
                          ? EditorColors.logError
                          : EditorColors.mutedForeground,
                ),
              ),
            ),
          ]),
          if (run.isRunning) ...[
            const SizedBox(height: 6),
            const SizedBox(height: 4, child: LinearProgressIndicator(key: ValueKey('project_settings_package_progress'))),
          ],
          if (_vm.packagingLog.isNotEmpty) ...[
            const SizedBox(height: 6),
            _packagingConsole(),
          ],
        ]),
        help: 'Generates the game code once, then runs a real flutter build per target',
      ),
    ]);
  }

  Widget _targetRow(String target, bool selected, PackagingRunState run) {
    // The web module's own line (download button, progress, retry) replaces
    // its "not available" reason.
    final reasons = [
      for (final r in _vm.reasonsFor(target))
        if (r != FlutterFilamentWebModule.missingReason) r,
    ];
    final status = run.statuses[target];
    final dir = run.packageDirs[target];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Checkbox(
              key: ValueKey('project_settings_target_$target'),
              state: selected ? CheckboxState.checked : CheckboxState.unchecked,
              onChanged: run.isRunning ? null : (v) => _vm.setTargetSelected(target, v == CheckboxState.checked),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 64,
              child: Text(packagingPlatformLabel(target), style: const TextStyle(fontSize: 10, color: EditorColors.foreground)),
            ),
            Text('flutter build ${flutterBuildSubcommand(target)}',
                style: const TextStyle(fontSize: 8.5, fontFamily: EditorTypography.monoFamily, color: EditorColors.mutedForeground)),
            const SizedBox(width: 8),
            if (status != null) _targetBadge(target, status),
            if (run.durations[target] != null && status != PackageTargetStatus.unbuildable) ...[
              const SizedBox(width: 6),
              Text(_fmt(run.durations[target]!), style: const TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground)),
            ],
          ]),
          for (var i = 0; i < reasons.length; i++)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 1),
              child: Text(
                reasons[i],
                key: ValueKey('project_settings_target_reason_${target}_$i'),
                style: const TextStyle(fontSize: 8.5, color: EditorColors.logWarning),
              ),
            ),
          if (target == 'web') WebModuleDownloadPanel(download: _vm.webModuleDownload, module: _vm.webModule),
          if (dir != null)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 1),
              child: Text(dir,
                  key: ValueKey('project_settings_target_package_$target'),
                  style: const TextStyle(fontSize: 8.5, fontFamily: EditorTypography.monoFamily, color: EditorColors.logSuccess)),
            )
          else if (status == PackageTargetStatus.failed && run.messages[target] != null)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 1),
              child: Text(run.messages[target]!, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 8.5, color: EditorColors.logError)),
            ),
        ],
      ),
    );
  }

  Widget _targetBadge(String target, PackageTargetStatus status) {
    final key = ValueKey('project_settings_target_status_$target');
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

  Widget _packagingConsole() {
    final lines = _vm.packagingLog;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _packagingScroll.hasClients) _packagingScroll.jumpTo(_packagingScroll.position.maxScrollExtent);
    });
    return Container(
      key: const ValueKey('project_settings_package_log'),
      height: 170,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: EditorColors.border),
      ),
      child: ListView.builder(
        controller: _packagingScroll,
        itemCount: lines.length,
        itemBuilder: (context, i) {
          final l = lines[i];
          final color = switch (l.level) {
            'error' => EditorColors.logError,
            'warning' => EditorColors.logWarning,
            'success' => EditorColors.logSuccess,
            _ => EditorColors.foreground,
          };
          final tag = l.target;
          return Text.rich(
            TextSpan(children: [
              TextSpan(
                text: tag == null ? '[package] ' : '[$tag] ',
                style: const TextStyle(fontWeight: FontWeight.bold, color: EditorColors.primary),
              ),
              TextSpan(text: l.message, style: TextStyle(color: color)),
            ]),
            style: const TextStyle(fontSize: 8.5, fontFamily: EditorTypography.monoFamily),
          );
        },
      ),
    );
  }
}

String _fmt(Duration d) =>
    d.inMilliseconds < 1000 ? '${d.inMilliseconds} ms' : '${(d.inMilliseconds / 1000).toStringAsFixed(1)} s';
