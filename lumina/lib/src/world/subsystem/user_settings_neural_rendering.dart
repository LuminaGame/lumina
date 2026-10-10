import 'package:flutter_filament/filament.dart';

import 'package:lumina/src/post_process/neural_rendering/neural_rendering.dart';
import 'package:lumina/src/post_process/neural_rendering/neural_rendering_controller.dart';
import 'package:lumina/src/world/subsystem/world_subsystem.dart';

/// The OpenDLSS-NR half of the game user settings: a game whose project opted
/// in ([LuminaNeuralRendering.projectOptIn]) runs the pass on the world's view
/// with the model weights the player points it at
/// ([neuralRenderingWeightsPath], `neural_rendering_weights` in
/// `GameUserSettings.json`, or the `LUMINA_OPENDLSS_NR_WEIGHTS` environment
/// variable); Play-In-Editor uses the editor's path. Without weights, on an
/// unsupported GPU or after a failure it stays off and logs why
/// ([neuralRenderingStatus]).
mixin LuminaUserSettingsNeuralRendering on LuminaWorldSubsystem {
  String _neuralRenderingWeights = '';
  LuminaNeuralRenderingController? _neuralRendering;
  FilamentView? _neuralRenderingView;

  /// The player's model weights folder (or its `manifest.json`); empty: none.
  String get neuralRenderingWeightsPath => _neuralRenderingWeights;

  /// Stages the player's weights folder; Apply Scalability Settings applies it.
  void setNeuralRenderingWeightsPath(String path) => _neuralRenderingWeights = path.trim();

  /// Where the world's pass stands (off without a view or an opt-in).
  LuminaNeuralRenderingStatus get neuralRenderingStatus =>
      _neuralRendering?.status.value ?? LuminaNeuralRenderingStatus.off;

  /// The controller of the world's view, once there is one.
  LuminaNeuralRenderingController? get neuralRenderingController => _neuralRendering;

  /// The key [neuralRenderingWeightsPath] is kept under (only when set).
  Map<String, dynamic> neuralRenderingSettingsMap() => {
        if (_neuralRenderingWeights.isNotEmpty) LuminaNeuralRendering.userSettingsKey: _neuralRenderingWeights,
      };

  /// Takes the weights path from a settings map (what
  /// [neuralRenderingSettingsMap] wrote).
  void stageNeuralRenderingFrom(Map<String, dynamic> map) {
    final path = map[LuminaNeuralRendering.userSettingsKey];
    if (path is String) _neuralRenderingWeights = path.trim();
  }

  /// Puts the project's opt-in on the world's view (asynchronous: the weights
  /// are checked and loaded on background isolates).
  void applyNeuralRendering() {
    final optIn = LuminaNeuralRendering.projectOptIn;
    final controller = _neuralRenderingController(create: optIn != null && optIn.active);
    if (controller == null) return;
    controller.apply(optIn, weightsPath: LuminaNeuralRendering.resolveWeightsPath(userSetting: _neuralRenderingWeights));
  }

  /// Follows a view that appeared or changed, and the pass's state.
  void tickNeuralRendering() {
    final optIn = LuminaNeuralRendering.projectOptIn;
    final view = world?.filamentViewOrNull;
    if (optIn != null && optIn.active && view != null && !identical(view, _neuralRenderingView)) {
      applyNeuralRendering();
    }
    _neuralRendering?.tick();
  }

  void disposeNeuralRendering() {
    _neuralRendering?.dispose();
    _neuralRendering = null;
    _neuralRenderingView = null;
  }

  LuminaNeuralRenderingController? _neuralRenderingController({required bool create}) {
    final w = world;
    final engine = w?.filamentEngineOrNull;
    final view = w?.filamentViewOrNull;
    if (engine == null || view == null) {
      disposeNeuralRendering();
      return null;
    }
    if (_neuralRendering == null || !identical(_neuralRenderingView, view)) {
      disposeNeuralRendering();
      if (!create) return null;
      _neuralRendering = LuminaNeuralRenderingController(engine: engine, view: view);
      _neuralRenderingView = view;
    }
    return _neuralRendering;
  }
}
