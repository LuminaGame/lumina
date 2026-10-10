part of '../project_settings_view_model.dart';

/// Validates a weights folder off the UI isolate.
OpenDlssNrModelCheck _checkNeuralRenderingWeights(String directory) => OpenDlssNr.validateModel(directory);

/// What Project Settings shows about the weights path.
enum NeuralRenderingWeightsState {
  /// No path set: the feature stays off until one is.
  missing,

  /// Checking the folder (a background isolate).
  checking,

  /// The folder matches the network's layout.
  valid,

  /// The folder does not match ([ProjectSettingsViewModel.neuralRenderingWeightsMessage] says why).
  invalid,
}

/// Neural rendering (experimental): the OpenDLSS-NR opt-in, its warning
/// acknowledgement, the weights path (checked against the network's layout)
/// and the controls. Turning it on goes through [acceptNeuralRenderingWarning]
/// only, after the user accepted the warning dialog.
mixin _ProjectSettingsNeuralRendering on _ProjectSettingsViewModelState {
  NeuralRenderingWeightsState _weightsState = NeuralRenderingWeightsState.missing;
  String _weightsMessage = '';
  String _weightsChecked = '';
  int _weightsGeneration = 0;

  ProjectNeuralRenderingSettings get neuralRendering => project.neuralRendering;

  /// The level viewport's GPU check (null before its engine exists).
  OpenDlssNrCapability? get neuralRenderingCapability => EditorNeuralRendering.capability.value;

  /// Whether "Use OpenDLSS-NR" can be ticked here.
  bool get neuralRenderingSupported => neuralRenderingCapability?.supported ?? false;

  /// Why it cannot (empty when it can).
  String get neuralRenderingUnavailableReason {
    final capability = neuralRenderingCapability;
    if (capability == null) return 'The level viewport has not started its GPU engine yet; open the level first.';
    return capability.supported ? '' : capability.reason;
  }

  NeuralRenderingWeightsState get neuralRenderingWeightsState => _weightsState;
  String get neuralRenderingWeightsMessage => _weightsMessage;

  /// The user accepted the warning: turn it on and record when.
  void acceptNeuralRenderingWarning({DateTime? now}) {
    final at = (now ?? DateTime.now()).toUtc().toIso8601String();
    _update((p) => p.copyWith(neuralRendering: p.neuralRendering.copyWith(enabled: true, acknowledgedAt: at)));
    unawaited(checkNeuralRenderingWeights());
  }

  /// Turns it off; the acknowledgement stays on record.
  void disableNeuralRendering() =>
      _update((p) => p.copyWith(neuralRendering: p.neuralRendering.copyWith(enabled: false)));

  /// The model folder, or its `manifest.json`; checked right away.
  void setNeuralRenderingWeightsPath(String path) {
    _update((p) => p.copyWith(neuralRendering: p.neuralRendering.copyWith(weightsPath: path.trim())));
    unawaited(checkNeuralRenderingWeights());
  }

  void setNeuralRenderingIntensity(double v) =>
      _update((p) => p.copyWith(neuralRendering: p.neuralRendering.copyWith(intensity: v)));
  void setNeuralRenderingLocalTone(double v) =>
      _update((p) => p.copyWith(neuralRendering: p.neuralRendering.copyWith(localTone: v)));
  void setNeuralRenderingLocalStructure(double v) =>
      _update((p) => p.copyWith(neuralRendering: p.neuralRendering.copyWith(localStructure: v)));
  void setNeuralRenderingAutoMask(bool v) =>
      _update((p) => p.copyWith(neuralRendering: p.neuralRendering.copyWith(autoMask: v)));
  void setNeuralRenderingStyle(String v) =>
      _update((p) => p.copyWith(neuralRendering: p.neuralRendering.copyWith(style: v)));
  void setNeuralRenderingPaperWhite(double v) =>
      _update((p) => p.copyWith(neuralRendering: p.neuralRendering.copyWith(paperWhite: v)));
  void setNeuralRenderingColorStrength(double v) =>
      _update((p) => p.copyWith(neuralRendering: p.neuralRendering.copyWith(colorStrength: v)));

  /// Checks the working copy's weights path against the network's layout on
  /// a background isolate (once per path).
  Future<void> checkNeuralRenderingWeights() async {
    final directory = neuralRendering.weightsDirectory;
    if (directory == _weightsChecked && _weightsState != NeuralRenderingWeightsState.checking) return;
    final generation = ++_weightsGeneration;
    _weightsChecked = directory;
    if (directory.isEmpty) {
      _weightsState = NeuralRenderingWeightsState.missing;
      _weightsMessage = 'No weights set: OpenDLSS-NR stays off until you choose a model folder.';
      if (!_disposed) notifyListeners();
      return;
    }
    _weightsState = NeuralRenderingWeightsState.checking;
    _weightsMessage = 'Checking $directory';
    if (!_disposed) notifyListeners();
    OpenDlssNrModelCheck check;
    try {
      check = await compute(_checkNeuralRenderingWeights, directory);
    } catch (e) {
      check = OpenDlssNrModelCheck(code: OpenDlssNrModelCode.ioError, message: '$e');
    }
    if (_disposed || generation != _weightsGeneration) return;
    if (check.ok) {
      _weightsState = NeuralRenderingWeightsState.valid;
      _weightsMessage =
          'Valid: ${check.blockCount} blocks, ${check.tensorCount} tensors, ${(check.totalBytes / (1 << 20)).toStringAsFixed(0)} MiB';
    } else if (check.code == OpenDlssNrModelCode.missing) {
      _weightsState = NeuralRenderingWeightsState.missing;
      _weightsMessage = 'Weights missing: ${check.message}';
    } else {
      _weightsState = NeuralRenderingWeightsState.invalid;
      _weightsMessage = 'Invalid weights: ${check.message}';
    }
    notifyListeners();
  }
}
