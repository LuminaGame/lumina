import 'package:flutter/foundation.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

/// OpenDLSS-NR (experimental, third-party) on the level viewport: follows the
/// open project's applied Project Settings ▸ Neural rendering on the
/// viewport's view, which Play-In-Editor renders into as well, and publishes
/// what Project Settings shows: the GPU's [capability] and the pass's
/// [status].
class EditorNeuralRendering {
  EditorNeuralRendering(this._project);

  /// The applied project (the editor view model's `project`).
  final LuminaProject Function() _project;

  /// The level viewport's engine capability (null before an engine exists).
  static final ValueNotifier<OpenDlssNrCapability?> capability = ValueNotifier<OpenDlssNrCapability?>(null);

  /// Where the viewport's pass stands.
  static final ValueNotifier<LuminaNeuralRenderingStatus> status =
      ValueNotifier<LuminaNeuralRenderingStatus>(LuminaNeuralRenderingStatus.off);

  LuminaNeuralRenderingController? _controller;
  ProjectNeuralRenderingSettings? _applied;

  /// The viewport's engine and view exist: probe the GPU and apply.
  void attach(FilamentEngine engine, FilamentView view) {
    detach();
    try {
      capability.value = OpenDlssNr.capability(engine);
    } catch (e) {
      capability.value = OpenDlssNrCapability(OpenDlssNrCapabilityCode.notVulkan, 'OpenDLSS-NR is not available: $e');
    }
    final controller = LuminaNeuralRenderingController(engine: engine, view: view);
    controller.status.addListener(_publish);
    _controller = controller;
    _applied = null;
    sync();
  }

  /// Re-applies when the project's neural rendering settings changed.
  void sync() {
    final controller = _controller;
    if (controller == null) return;
    final settings = _project().neuralRendering;
    if (settings == _applied) return;
    _applied = settings;
    controller.apply(settings);
  }

  /// Once per viewport frame: polls the running pass.
  void tick() => _controller?.tick();

  void detach() {
    final controller = _controller;
    _controller = null;
    _applied = null;
    if (controller != null) {
      controller.status.removeListener(_publish);
      controller.dispose();
    }
    status.value = LuminaNeuralRenderingStatus.off;
  }

  void _publish() {
    final controller = _controller;
    if (controller != null) status.value = controller.status.value;
  }
}
