part of '../build_manager_sub_editor.dart';

/// The right panel: target platforms, build configuration and output.
extension _BuildManagerPackagingPanel on _BuildManagerSubEditorState {
  // --- right: packaging -----------------------------------------------------

  Widget _rightPanel() {
    return Padding(
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
}
