import 'dart:io' show Platform;

import 'package:flutter_filament/filament.dart';
import 'package:lumina_core/lumina_core.dart' show ProjectNeuralRenderingSettings;

import 'package:lumina/src/utility/lumina_platform.dart';

/// Where a view's OpenDLSS-NR pass stands.
enum LuminaNeuralRenderingState {
  /// The project did not opt in (or the user turned it off).
  off,

  /// This GPU, driver, backend or platform cannot run it ([LuminaNeuralRenderingStatus.reason]).
  unsupported,

  /// Opted in, but no model weights are set.
  weightsMissing,

  /// The weights folder does not match what the network reads.
  invalidWeights,

  /// Validating and loading the weights (background isolates).
  loading,

  /// The pass runs on the view.
  running,

  /// Loading or running failed; the view renders without it.
  failed,
}

/// The state with its reason and, while running, the GPU time of the pass.
class LuminaNeuralRenderingStatus {
  const LuminaNeuralRenderingStatus(this.state, [this.reason = '', this.gpuMs = 0.0]);

  static const LuminaNeuralRenderingStatus off = LuminaNeuralRenderingStatus(LuminaNeuralRenderingState.off);

  final LuminaNeuralRenderingState state;
  final String reason;
  final double gpuMs;

  bool get running => state == LuminaNeuralRenderingState.running;

  @override
  bool operator ==(Object other) =>
      other is LuminaNeuralRenderingStatus && other.state == state && other.reason == reason && other.gpuMs == gpuMs;

  @override
  int get hashCode => Object.hash(state, reason, gpuMs);

  @override
  String toString() => 'LuminaNeuralRenderingStatus(${state.name}${reason.isEmpty ? '' : ': $reason'})';
}

/// OpenDLSS-NR (experimental, third-party) for Lumina's views: a project's
/// opt-in, the weights path a view uses, and the device feature request.
///
/// The editor viewport and Play-In-Editor follow the open project's
/// [ProjectNeuralRenderingSettings] and its weights path. A packaged game
/// runs it only when its project opted in (the generated `main()` sets
/// [projectOptIn], without a weights path): the game ships no weights and
/// reads a model folder from the player's `GameUserSettings.json`
/// (`neural_rendering_weights`) or from the [weightsEnvironmentVariable];
/// without one the pass stays off and the reason is logged.
abstract final class LuminaNeuralRendering {
  /// The environment variable a game reads a weights folder from.
  static const String weightsEnvironmentVariable = 'LUMINA_OPENDLSS_NR_WEIGHTS';

  /// The `GameUserSettings.json` key a game reads a weights folder from.
  static const String userSettingsKey = 'neural_rendering_weights';

  /// The upstream project page (its requirements are documented there).
  static String get upstreamUrl => OpenDlssNr.upstreamUrl;

  /// The project's opt-in, as the generated game (or Play-In-Editor) sets
  /// it; null: off. Only [ProjectNeuralRenderingSettings.active] settings run.
  static ProjectNeuralRenderingSettings? projectOptIn;

  /// The weights folder the editor hands Play-In-Editor (the project's
  /// machine-local path); null in packaged games.
  static String? editorWeightsPath;

  static bool _requested = false;

  /// Asks the engines created from now on for the device features the pass
  /// needs (desktop only; harmless where the GPU lacks them). Once.
  static void requestDeviceFeatures() {
    if (_requested || LuminaPlatform.isWeb) return;
    _requested = true;
    try {
      OpenDlssNr.requestDeviceFeatures();
    } catch (_) {
      // a build without the native library: nothing to request
    }
  }

  /// The weights folder a view uses: the editor's path, then the player's
  /// setting, then [weightsEnvironmentVariable]; empty when none is set.
  static String resolveWeightsPath({String? userSetting, Map<String, String>? environment}) {
    final editor = editorWeightsPath?.trim() ?? '';
    if (editor.isNotEmpty) return ProjectNeuralRenderingSettings.weightsDirectoryOf(editor);
    final user = userSetting?.trim() ?? '';
    if (user.isNotEmpty) return ProjectNeuralRenderingSettings.weightsDirectoryOf(user);
    if (LuminaPlatform.isWeb) return '';
    final env = (environment ?? Platform.environment)[weightsEnvironmentVariable]?.trim() ?? '';
    return ProjectNeuralRenderingSettings.weightsDirectoryOf(env);
  }

  /// The pass's controls for [settings].
  static OpenDlssNrControls controlsFor(ProjectNeuralRenderingSettings settings) => OpenDlssNrControls(
        intensity: settings.intensity,
        localTone: settings.localTone,
        localStructure: settings.localStructure,
        autoMask: settings.autoMask,
        style: switch (settings.style) {
          ProjectNeuralRenderingSettings.styleNatural => OpenDlssNrStyle.natural,
          ProjectNeuralRenderingSettings.styleCinematic => OpenDlssNrStyle.cinematic,
          _ => OpenDlssNrStyle.none,
        },
        paperWhite: settings.paperWhite,
        colorStrength: settings.colorStrength,
      );

  /// The reason a view without weights logs.
  static const String weightsMissingReason =
      'OpenDLSS-NR is on but no model weights are set (editor: Project Settings > Neural rendering; '
      "games: '$userSettingsKey' in GameUserSettings.json or $weightsEnvironmentVariable); it stays off";
}
