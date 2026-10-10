import 'package:lumina_core/lumina_core.dart' show ObservableValue;

/// How a built game shows its frames.
enum LuminaPresentationMode {
  /// Filament renders offscreen, the frame is read back and Flutter
  /// composites it with the UI and presents it (works everywhere; the editor
  /// viewport always does this).
  flutter('flutter'),

  /// Filament renders into a swap chain on a native window covering the game
  /// and presents it itself; the game's UI is rendered by Flutter offscreen
  /// and blended by Filament over every presented frame. What frame
  /// generation needs to show its frames. Desktop Vulkan only.
  direct('direct');

  const LuminaPresentationMode(this.id);

  /// The value in `.lmproject` and `GameUserSettings.json`.
  final String id;

  /// The mode named [id]; null for anything else.
  static LuminaPresentationMode? parse(Object? id) {
    if (id is! String) return null;
    final key = id.trim().toLowerCase();
    for (final mode in values) {
      if (mode.id == key) return mode;
    }
    return null;
  }
}

/// The presentation a game runs with and why.
class LuminaPresentationDecision {
  const LuminaPresentationDecision(this.mode, {this.reason});

  final LuminaPresentationMode mode;

  /// Why: what asked for direct presentation ("frame generation", "project
  /// setting", "player setting"), or why it is not used when it was asked
  /// for (the fallback reason).
  final String? reason;

  @override
  bool operator ==(Object other) => other is LuminaPresentationDecision && other.mode == mode && other.reason == reason;

  @override
  int get hashCode => Object.hash(mode, reason);

  @override
  String toString() => 'LuminaPresentationDecision(${mode.id}${reason == null ? '' : ': $reason'})';
}

/// The game's presentation mode: Flutter (the default) or Direct.
///
/// The project's setting (Project Settings > Presentation, passed to the
/// game host by the generated `main()`) is the default
/// ([setProjectDefault]); the player's choice in `GameUserSettings.json`
/// (key `presentation`, [restore] / [apply]) wins over it. Frame generation
/// (DLSS or FSR3) in force asks for Direct by itself, since its frames only
/// reach the screen when Filament presents ([setFrameGenerationRequested]).
///
/// The game host tries what [requested] says; when the platform cannot
/// (the web, a backend other than Vulkan, a runner without the
/// presentation window, a failure) it reports the reason with
/// [reportFallback] and keeps Flutter. [decision] is what is in force.
///
/// While a game is shown through Flutter ([flutterPresentation] non-null,
/// set by the game host and Play-In-Editor) frame generation is not applied
/// to its view: Flutter shows one frame per rendered frame, so generated
/// frames would only cost frame rate. The request for Direct comes from the
/// frame generation the player chose ([setFrameGenerationRequested]), not
/// from what is applied, so a Direct fallback is stable: Flutter, frame
/// generation inactive, no retry.
abstract final class LuminaGamePresentation {
  /// The key in the settings file.
  static const String settingsKey = 'presentation';

  static LuminaPresentationMode _project = LuminaPresentationMode.flutter;
  static LuminaPresentationMode? _player;
  static bool _frameGeneration = false;
  static String? _fallback;

  /// What the game asks for (before the platform had a say).
  static final ObservableValue<LuminaPresentationDecision> requested =
      ObservableValue(const LuminaPresentationDecision(LuminaPresentationMode.flutter));

  /// What is in force: [requested], or Flutter with the reason Direct could
  /// not run.
  static final ObservableValue<LuminaPresentationDecision> decision =
      ObservableValue(const LuminaPresentationDecision(LuminaPresentationMode.flutter));

  /// The project's presentation, where the player chose none.
  static LuminaPresentationMode get projectDefault => _project;

  /// The player's choice, if any.
  static LuminaPresentationMode? get playerChoice => _player;

  /// Whether frame generation is chosen and supported (asks for Direct; it
  /// is applied only where the game is not shown through Flutter).
  static bool get frameGenerationRequested => _frameGeneration;

  /// Why the game is shown through Flutter right now, null when nothing
  /// shows it through Flutter: the game host presents directly, or no
  /// Flutter host is mounted (an engine loop presenting its own swap chain).
  /// The game host sets it ([setFlutterPresentation]): `player setting`,
  /// a fallback reason, `Direct presentation starting`, `Play-In-Editor`,
  /// `the host presents through Flutter`.
  static final ObservableValue<String?> flutterPresentation = ObservableValue<String?>(null);

  /// The host shows the game through Flutter for [reason] (null: it does
  /// not, or it went away).
  static void setFlutterPresentation(String? reason) {
    if (flutterPresentation.value != reason) flutterPresentation.value = reason;
  }

  /// What [project], the [player]'s choice and [frameGeneration] ask for:
  /// the player's choice wins over the project's; frame generation turns
  /// Direct on unless the player chose Flutter.
  static LuminaPresentationDecision resolve({
    required LuminaPresentationMode project,
    LuminaPresentationMode? player,
    bool frameGeneration = false,
  }) {
    if (player == LuminaPresentationMode.flutter) {
      return const LuminaPresentationDecision(LuminaPresentationMode.flutter, reason: 'player setting');
    }
    if (frameGeneration) {
      return const LuminaPresentationDecision(LuminaPresentationMode.direct, reason: 'frame generation');
    }
    if (player == LuminaPresentationMode.direct) {
      return const LuminaPresentationDecision(LuminaPresentationMode.direct, reason: 'player setting');
    }
    if (project == LuminaPresentationMode.direct) {
      return const LuminaPresentationDecision(LuminaPresentationMode.direct, reason: 'project setting');
    }
    return const LuminaPresentationDecision(LuminaPresentationMode.flutter);
  }

  /// The project's setting.
  static void setProjectDefault(LuminaPresentationMode mode) {
    _project = mode;
    _publish();
  }

  /// The player's choice (null forgets it: the project's setting again).
  static void apply(LuminaPresentationMode? mode) {
    _player = mode;
    _publish();
  }

  /// Start-up: the player's choice stored in [saved] (the settings file's
  /// content), if any.
  static void restore(Map<String, dynamic> saved) {
    final mode = LuminaPresentationMode.parse(saved[settingsKey]);
    if (mode != null) apply(mode);
  }

  /// The key this class keeps in the settings file (null removes it).
  static Map<String, Object?> settingsPatch() => {settingsKey: _player?.id};

  /// Frame generation was chosen (and is supported) or turned off: the
  /// game user settings call this on every apply.
  static void setFrameGenerationRequested(bool requested) {
    if (requested == _frameGeneration) return;
    _frameGeneration = requested;
    _publish();
  }

  /// The host could not present directly: Flutter with [reason] until the
  /// request changes. Null clears it (Direct runs).
  static void reportFallback(String? reason) {
    _fallback = reason;
    _publishDecision();
  }

  /// Back to the defaults (tests, a new Play session).
  static void reset() {
    _project = LuminaPresentationMode.flutter;
    _player = null;
    _frameGeneration = false;
    _fallback = null;
    flutterPresentation.value = null;
    _publish();
  }

  static void _publish() {
    final next = resolve(project: _project, player: _player, frameGeneration: _frameGeneration);
    if (next != requested.value) {
      _fallback = null;
      requested.value = next;
    }
    _publishDecision();
  }

  static void _publishDecision() {
    final asked = requested.value;
    decision.value = asked.mode == LuminaPresentationMode.direct && _fallback != null
        ? LuminaPresentationDecision(LuminaPresentationMode.flutter, reason: _fallback)
        : asked;
  }
}
