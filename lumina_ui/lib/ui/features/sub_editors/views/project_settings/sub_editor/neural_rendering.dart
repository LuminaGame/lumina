part of '../../project_settings_sub_editor.dart';

/// Engine & Graphics ▸ Neural rendering (experimental): the OpenDLSS-NR
/// opt-in behind its warning, the weights picker with its check, the
/// controls, and what the level viewport does with the applied settings.
mixin _ProjectSettingsNeuralRenderingSection on _ProjectSettingsSubEditorStateBase {
  @override
  Widget _buildNeuralRendering() {
    final s = _vm.neuralRendering;
    final supported = _vm.neuralRenderingSupported;
    // Unticking stays possible where it cannot run (a project opened on another machine).
    final canToggle = supported || s.enabled;
    return _section('Neural rendering (experimental)', [
      _row(
        'Use OpenDLSS-NR',
        Row(children: [
          Checkbox(
            key: const ValueKey('project_settings_neural_rendering_enabled'),
            state: s.enabled ? CheckboxState.checked : CheckboxState.unchecked,
            onChanged: canToggle ? (v) => _toggleNeuralRendering(v == CheckboxState.checked) : null,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Third-party, unofficial re-implementation of NVIDIA\'s DLSS 5 neural rendering. '
              'Needs NVIDIA\'s model weights, which Lumina does not provide.',
              style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
            ),
          ),
        ]),
        help: 'Editor viewport and Play-In-Editor; built games only when this is on (they read weights from the player)',
      ),
      if (!supported)
        _notice(
          const ValueKey('project_settings_neural_rendering_unavailable'),
          LucideIcons.circleSlash,
          EditorColors.mutedForeground,
          _vm.neuralRenderingUnavailableReason,
        ),
      if (s.acknowledged)
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Text('Warning accepted ${s.acknowledgedAt}',
              key: const ValueKey('project_settings_neural_rendering_acknowledged'),
              style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
        ),
      _row(
        'Weights',
        Row(children: [
          Expanded(
            child: TextField(
              key: const ValueKey('project_settings_neural_rendering_weights'),
              controller: _controllerFor('neural_rendering_weights', s.weightsPath),
              focusNode: _focusFor('neural_rendering_weights'),
              placeholder: const Text('model folder or its manifest.json'),
              onChanged: _vm.setNeuralRenderingWeightsPath,
            ),
          ),
          const SizedBox(width: 6),
          OutlineButton(
            key: const ValueKey('project_settings_neural_rendering_browse'),
            density: ButtonDensity.compact,
            onPressed: _chooseNeuralRenderingWeights,
            child: const Text('Browse…', style: TextStyle(fontSize: 10)),
          ),
        ]),
        help: 'A path on this machine; games never read it',
      ),
      _weightsNotice(),
      if (s.enabled) ...[
        _slider('Intensity', 'intensity', s.intensity, 0, 1, 1, _vm.setNeuralRenderingIntensity),
        _slider('Tone', 'tone', s.localTone, 0, 1, 1, _vm.setNeuralRenderingLocalTone),
        _slider('Structure', 'structure', s.localStructure, 0, 1, 1, _vm.setNeuralRenderingLocalStructure),
        _row(
          'Auto Mask',
          Align(
            alignment: Alignment.centerLeft,
            child: Switch(
              key: const ValueKey('project_settings_neural_rendering_auto_mask'),
              value: s.autoMask,
              onChanged: _vm.setNeuralRenderingAutoMask,
            ),
          ),
          help: 'The network masks skin and structure itself',
        ),
        _row(
          'Style',
          _select(s.style, ProjectNeuralRenderingSettings.styles, _vm.setNeuralRenderingStyle,
              label: (v) => v[0].toUpperCase() + v.substring(1)),
          help: 'The style id the network sees',
        ),
        _slider('Paper White', 'paper_white', s.paperWhite, 0.25, 4, 1, _vm.setNeuralRenderingPaperWhite),
        _slider('Color Strength', 'color_strength', s.colorStrength, 0, 1, 1, _vm.setNeuralRenderingColorStrength),
      ],
      ValueListenableBuilder<LuminaNeuralRenderingStatus>(
        valueListenable: EditorNeuralRendering.status,
        builder: (context, status, _) => _notice(
          const ValueKey('project_settings_neural_rendering_viewport'),
          status.running ? LucideIcons.circleCheck : LucideIcons.monitor,
          status.running ? EditorColors.logSuccess : EditorColors.mutedForeground,
          'Viewport (applied settings): ${_statusText(status)}',
        ),
      ),
    ]);
  }

  Widget _slider(String label, String id, double value, double min, double max, double defaultValue,
      void Function(double) onChanged) {
    return _row(
      label,
      SliderField(
        key: ValueKey('project_settings_neural_rendering_$id'),
        value: value,
        defaultValue: defaultValue,
        min: min,
        max: max,
        fractionDigits: 2,
        onChanged: onChanged,
        onCommit: onChanged,
        onReset: () => onChanged(defaultValue),
      ),
    );
  }

  Widget _weightsNotice() {
    final message = _vm.neuralRenderingWeightsMessage;
    final (icon, color) = switch (_vm.neuralRenderingWeightsState) {
      NeuralRenderingWeightsState.valid => (LucideIcons.circleCheck, EditorColors.logSuccess),
      NeuralRenderingWeightsState.invalid => (LucideIcons.circleX, EditorColors.destructive),
      NeuralRenderingWeightsState.checking => (LucideIcons.loader, EditorColors.mutedForeground),
      NeuralRenderingWeightsState.missing => (LucideIcons.triangleAlert, EditorColors.warning),
    };
    return _notice(const ValueKey('project_settings_neural_rendering_weights_state'), icon, color,
        message.isEmpty ? 'No weights set: OpenDLSS-NR stays off until you choose a model folder.' : message);
  }

  Widget _notice(Key key, IconData icon, Color color, String text) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(left: 6, right: 6, bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: TextStyle(fontSize: 9.5, color: color))),
      ]),
    );
  }

  String _statusText(LuminaNeuralRenderingStatus status) => switch (status.state) {
        LuminaNeuralRenderingState.off => 'off',
        LuminaNeuralRenderingState.running =>
          status.gpuMs > 0 ? 'running, ${status.gpuMs.toStringAsFixed(1)} ms GPU per frame' : 'running',
        LuminaNeuralRenderingState.loading => 'loading (${status.reason})',
        LuminaNeuralRenderingState.weightsMissing => 'weights missing, off',
        _ => status.reason,
      };

  Future<void> _toggleNeuralRendering(bool on) async {
    if (!on) {
      _vm.disableNeuralRendering();
      return;
    }
    final accepted = await showNeuralRenderingWarning(context);
    if (!mounted || !accepted) return;
    _vm.acceptNeuralRenderingWarning();
  }

  Future<void> _chooseNeuralRenderingWeights() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choose the model\'s manifest.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    final path = result?.files.single.path;
    if (path != null) _vm.setNeuralRenderingWeightsPath(path);
  }
}
