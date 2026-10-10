import 'dart:isolate';

import 'package:flutter_filament/filament.dart';
import 'package:lumina_core/lumina_core.dart'
    show EngineLoggerService, ObservableValue, ProjectNeuralRenderingSettings;

import 'package:lumina/src/post_process/neural_rendering/neural_rendering.dart';
import 'package:lumina/src/utility/lumina_platform.dart';

/// Validates [directory] off the UI isolate.
OpenDlssNrModelCheck _validate(String directory) => OpenDlssNr.validateModel(directory);

/// Loads [args] (engine address, directory) off the UI isolate; the model's
/// address, or the reason as a string.
Object _load((int, String) args) {
  try {
    return OpenDlssNr.loadModelAddress(args.$1, args.$2);
  } catch (e) {
    return e is StateError ? e.message : '$e';
  }
}

/// OpenDLSS-NR on one view: validates and loads the weights on background
/// isolates, registers the pass, follows the controls and reports its
/// [status]. Every failure turns it off with a reason (logged once); the view
/// keeps rendering without it.
class LuminaNeuralRenderingController {
  LuminaNeuralRenderingController({required this.engine, required this.view});

  final FilamentEngine engine;
  final FilamentView view;

  /// Where the pass stands; listeners hear every change.
  final ObservableValue<LuminaNeuralRenderingStatus> status =
      ObservableValue<LuminaNeuralRenderingStatus>(LuminaNeuralRenderingStatus.off);

  OpenDlssNrModel? _model;
  OpenDlssNrPass? _pass;
  String _loadedDirectory = '';
  int _generation = 0;
  int _ticks = 0;
  bool _disposed = false;
  String _lastLogged = '';

  bool get isRunning => _pass != null && status.value.running;

  /// Brings the view to [settings] with the weights folder [weightsPath]
  /// (falling back to the settings' own path). Cheap when only the controls
  /// changed. Completes once the pass runs or is off with a reason.
  Future<void> apply(ProjectNeuralRenderingSettings? settings, {String? weightsPath}) async {
    if (_disposed) return;
    final generation = ++_generation;
    if (settings == null || !settings.active) {
      _detach();
      _set(LuminaNeuralRenderingStatus.off);
      return;
    }
    if (LuminaPlatform.isWeb) {
      _detach();
      _set(const LuminaNeuralRenderingStatus(
          LuminaNeuralRenderingState.unsupported, 'OpenDLSS-NR is not available on the web (desktop Vulkan only)'));
      return;
    }
    OpenDlssNrCapability capability;
    try {
      capability = OpenDlssNr.capability(engine);
    } catch (e) {
      capability = OpenDlssNrCapability(OpenDlssNrCapabilityCode.notVulkan, 'OpenDLSS-NR is not available: $e');
    }
    if (!capability.supported) {
      _detach();
      _set(LuminaNeuralRenderingStatus(LuminaNeuralRenderingState.unsupported, capability.reason));
      return;
    }
    final directory = ProjectNeuralRenderingSettings.weightsDirectoryOf(weightsPath ?? settings.weightsPath);
    if (directory.isEmpty) {
      _detach();
      _set(const LuminaNeuralRenderingStatus(
          LuminaNeuralRenderingState.weightsMissing, LuminaNeuralRendering.weightsMissingReason));
      return;
    }
    final controls = LuminaNeuralRendering.controlsFor(settings);
    if (_pass != null && directory == _loadedDirectory && !_pass!.status.failed) {
      if (_pass!.controls != controls) _pass!.controls = controls;
      return;
    }
    _detach();
    _set(const LuminaNeuralRenderingStatus(LuminaNeuralRenderingState.loading, 'checking the weights'));
    final check = await Isolate.run(() => _validate(directory));
    if (_stale(generation)) return;
    if (!check.ok) {
      _set(LuminaNeuralRenderingStatus(
          check.code == OpenDlssNrModelCode.missing
              ? LuminaNeuralRenderingState.weightsMissing
              : LuminaNeuralRenderingState.invalidWeights,
          'OpenDLSS-NR weights at $directory: ${check.message}'));
      return;
    }
    _set(const LuminaNeuralRenderingStatus(LuminaNeuralRenderingState.loading, 'loading the weights'));
    final address = engine.nativePointer.address;
    final loaded = await Isolate.run(() => _load((address, directory)));
    if (loaded is! int) {
      if (!_stale(generation)) {
        _set(LuminaNeuralRenderingStatus(LuminaNeuralRenderingState.failed, 'OpenDLSS-NR could not load the weights: $loaded'));
      }
      return;
    }
    final model = OpenDlssNrModel.fromAddress(engine, loaded);
    if (_stale(generation)) {
      model.destroy();
      return;
    }
    try {
      _pass = OpenDlssNrPass.create(engine: engine, view: view, model: model, controls: controls);
      _model = model;
      _loadedDirectory = directory;
      _ticks = 0;
      _set(const LuminaNeuralRenderingStatus(LuminaNeuralRenderingState.running));
    } catch (e) {
      model.destroy();
      _set(LuminaNeuralRenderingStatus(
          LuminaNeuralRenderingState.failed, e is StateError ? e.message : 'OpenDLSS-NR could not start: $e'));
    }
  }

  /// Polls the running pass (call once per frame; reads its state every 30
  /// calls): a pass that turned itself off is released with its reason.
  void tick() {
    final pass = _pass;
    if (pass == null || _disposed || ++_ticks % 30 != 0) return;
    final s = pass.status;
    if (s.failed) {
      _detach();
      _set(LuminaNeuralRenderingStatus(LuminaNeuralRenderingState.failed, s.failure));
      return;
    }
    if (s.gpuMsAverage > 0) {
      _set(LuminaNeuralRenderingStatus(LuminaNeuralRenderingState.running, '', double.parse(s.gpuMsAverage.toStringAsFixed(1))));
    }
  }

  /// The pass's state right now (null when none runs).
  OpenDlssNrStatus? get passStatus => _pass?.status;

  void dispose() {
    if (_disposed) return;
    _generation++;
    _detach();
    _disposed = true;
  }

  bool _stale(int generation) => _disposed || generation != _generation;

  void _detach() {
    final pass = _pass;
    final model = _model;
    _pass = null;
    _model = null;
    _loadedDirectory = '';
    try {
      pass?.destroy();
      model?.destroy();
    } catch (e) {
      EngineLoggerService().log('OpenDLSS-NR release failed: $e', level: 'warning', source: 'LuminaNeuralRendering');
    }
  }

  void _set(LuminaNeuralRenderingStatus next) {
    status.value = next;
    final loggable = switch (next.state) {
      LuminaNeuralRenderingState.unsupported ||
      LuminaNeuralRenderingState.weightsMissing ||
      LuminaNeuralRenderingState.invalidWeights ||
      LuminaNeuralRenderingState.failed =>
        true,
      _ => false,
    };
    if (loggable && next.reason != _lastLogged) {
      _lastLogged = next.reason;
      EngineLoggerService().log(next.reason, level: 'warning', source: 'LuminaNeuralRendering');
    } else if (next.state == LuminaNeuralRenderingState.running && _lastLogged != 'running') {
      _lastLogged = 'running';
      EngineLoggerService().log('OpenDLSS-NR (experimental, third-party) runs on this view', source: 'LuminaNeuralRendering');
    }
  }
}
