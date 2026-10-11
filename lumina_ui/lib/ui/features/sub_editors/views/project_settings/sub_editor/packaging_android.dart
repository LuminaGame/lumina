part of '../../project_settings_sub_editor.dart';

/// Packaging > Android (Meta Quest): the XR profile, application id,
/// versions, SDK levels, signing and the read-only preview of the manifest a
/// build composes (each line with its source: template, project or plugin).
mixin _ProjectSettingsPackagingAndroid on _ProjectSettingsSubEditorStateBase {
  static const _mono = TextStyle(fontSize: 8.5, fontFamily: EditorTypography.monoFamily, color: EditorColors.mutedForeground);

  Widget _textField(String id, String value, void Function(String) onChanged, {String? placeholder}) => TextField(
        key: ValueKey('project_settings_android_$id'),
        controller: _controllerFor('android_$id', value),
        focusNode: _focusFor('android_$id'),
        placeholder: placeholder == null ? null : Text(placeholder),
        onChanged: onChanged,
      );

  @override
  Widget _androidSection() {
    final a = _vm.androidSettings;
    if (_vm.androidPreviewStale && !_vm.androidPreviewLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _vm.refreshAndroidPreview();
      });
    }
    return _section('Android${a.isQuest ? ' (Meta Quest)' : ''}', [
      _row(
        'XR Profile',
        _select(a.xr, kAndroidXrProfiles, _vm.setAndroidXrProfile, label: androidXrProfileLabel),
        help: a.isQuest
            ? 'A standalone headset app: arm64 only, minSdk $kQuestMinSdk / targetSdk $kQuestTargetSdk '
                '(Meta Horizon Store, 2026-10-11), Impeller off; the enabled XR plugins add their manifest entries'
            : 'A phone or tablet app',
      ),
      _row(
        'Application Id',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _textField('application_id', a.applicationId, _vm.setAndroidApplicationId, placeholder: _vm.androidApplicationId),
          const SizedBox(height: 3),
          Text(
            _vm.androidApplicationIdProblem ?? 'Builds as ${_vm.androidApplicationId} (launch: ${_vm.androidApplicationId}/.MainActivity)',
            key: const ValueKey('project_settings_android_application_id_resolved'),
            style: _mono.copyWith(color: _vm.androidApplicationIdProblem == null ? EditorColors.mutedForeground : EditorColors.logError),
          ),
        ]),
        help: 'Empty: com.lumina.<project>',
      ),
      _row(
        'Version',
        Row(children: [
          Expanded(child: _textField('version_name', a.versionName, _vm.setAndroidVersionName, placeholder: '1.0.0')),
          const SizedBox(width: 6),
          SizedBox(width: 70, child: _textField('version_code', '${a.versionCode}', _vm.setAndroidVersionCode, placeholder: '1')),
        ]),
        help: 'Version name and code',
      ),
      _row(
        'SDK Levels',
        Row(children: [
          const Text('min', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          const SizedBox(width: 4),
          SizedBox(width: 60, child: _textField('min_sdk', '${a.minSdk}', _vm.setAndroidMinSdk)),
          const SizedBox(width: 10),
          const Text('target', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          const SizedBox(width: 4),
          SizedBox(width: 60, child: _textField('target_sdk', '${a.targetSdk}', _vm.setAndroidTargetSdk)),
          const SizedBox(width: 10),
          Text(a.abis.join(', '), style: _mono),
        ]),
      ),
      if (a.isQuest) ...[
        _row(
          'Refresh Rate',
          _select('${a.refreshRate}', [for (final r in kQuestRefreshRates) '$r'], (v) => _vm.setAndroidRefreshRate(int.parse(v)),
              label: (v) => '$v Hz'),
          help: 'What the immersive game asks the headset for',
        ),
        _row(
          'Multiview',
          Align(
            alignment: Alignment.centerLeft,
            child: Switch(key: const ValueKey('project_settings_android_multiview'), value: a.multiview, onChanged: _vm.setAndroidMultiview),
          ),
          help: 'Both eyes in one pass',
        ),
      ],
      _row(
        'Impeller',
        Align(
          alignment: Alignment.centerLeft,
          child: Switch(key: const ValueKey('project_settings_android_impeller'), value: a.impeller, onChanged: _vm.setAndroidImpeller),
        ),
        help: 'Flutter\'s renderer for the app UI (off for a Quest)',
      ),
      _row(
        'Signing',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: _textField('keystore', a.keystorePath, _vm.setAndroidKeystorePath, placeholder: 'release keystore (.jks), empty: debug key')),
            const SizedBox(width: 6),
            SizedBox(width: 110, child: _textField('key_alias', a.keyAlias, _vm.setAndroidKeyAlias, placeholder: 'key alias')),
          ]),
          const SizedBox(height: 3),
          Text(
            a.hasReleaseKeystore
                ? 'Passwords from ${AndroidGradleConfigurator.storePasswordVariable} / ${AndroidGradleConfigurator.keyPasswordVariable}; never stored in the project'
                : 'Debug signing (Flutter\'s debug keystore)',
            style: _mono,
          ),
        ]),
      ),
      _row('Manifest Preview', _manifestPreview(), help: 'Read-only: Flutter\'s template + project settings + enabled plugins'),
    ]);
  }

  Widget _manifestPreview() {
    final preview = _vm.androidManifestPreview;
    final error = _vm.androidPreviewError;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        OutlineButton(
          key: const ValueKey('project_settings_android_preview_refresh'),
          onPressed: _vm.androidPreviewLoading ? null : _vm.refreshAndroidPreview,
          child: Text(_vm.androidPreviewLoading ? 'Composing…' : 'Refresh', style: const TextStyle(fontSize: 10)),
        ),
        const SizedBox(width: 8),
        if (preview != null) Expanded(child: Text(preview.summary.join(', '), style: _mono, overflow: TextOverflow.ellipsis)),
      ]),
      const SizedBox(height: 6),
      if (error != null)
        Text(error, key: const ValueKey('project_settings_android_preview_error'), style: _mono.copyWith(color: EditorColors.logWarning))
      else if (preview != null)
        Container(
          key: const ValueKey('project_settings_android_manifest_preview'),
          height: 260,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: EditorColors.card,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: EditorColors.border),
          ),
          child: ListView.builder(
            itemCount: preview.lines.length,
            itemBuilder: (context, i) {
              final line = preview.lines[i];
              final generated = line.source != 'template';
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 120,
                  child: Text(line.source, overflow: TextOverflow.ellipsis,
                      style: _mono.copyWith(color: generated ? EditorColors.primary : EditorColors.mutedForeground)),
                ),
                Expanded(
                  child: Text(line.text,
                      style: _mono.copyWith(color: generated ? EditorColors.foreground : EditorColors.mutedForeground)),
                ),
              ]);
            },
          ),
        ),
    ]);
  }
}
