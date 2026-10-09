part of '../engine_bootstrap.dart';

/// What the release workflow compiles into a Lumina Studio build
/// (`--dart-define`): the release tag, its commit and the engine repo. All
/// empty in a dev build.
abstract final class LuminaRelease {
  /// The release tag, e.g. `v0.1.0`; empty in dev builds.
  static const String version = String.fromEnvironment('LUMINA_VERSION');

  /// The full commit SHA the release was built from.
  static const String commit = String.fromEnvironment('LUMINA_COMMIT');

  static const String _repo = String.fromEnvironment('LUMINA_REPO');

  /// The engine repo the release fetches its source from.
  static String get repo => _repo.isEmpty ? kLuminaGitUrl : _repo;

  /// Whether this is a release build.
  static bool get isRelease => version.isNotEmpty;

  /// The build version the editor shows, without the tag's `v`: the release
  /// tag in a release build (`0.0.1-dev.6`), else the source version.
  static String get displayVersion => (isRelease ? version : kLuminaEngineDisplayVersion).replaceFirst(RegExp('^v'), '');
}

/// Downloads (or finds) the prebuilt Filament build [version] and returns
/// its directory, usable as the hooks' `filament_dir`: from the
/// `filament-<version>` release, else from the [releaseTag] release (the
/// editor's own, for releases that attached Filament themselves). The
/// signature of [FilamentPrebuilt.ensure].
typedef FilamentProvider = Future<Directory> Function({
  required String version,
  required String releaseTag,
  required Directory cacheRoot,
  void Function(double progress, String message)? onProgress,
});

/// Downloads (or finds) the prebuilt OpenRigLogic library of the
/// [releaseTag] release and returns its directory, whose `lib` folder the
/// root pubspec's `riglogic_lib_dir` names. The signature of
/// [OpenRigLogicPrebuilt.ensure].
typedef OpenRigLogicProvider = Future<Directory> Function({
  required String releaseTag,
  required Directory cacheRoot,
  void Function(double progress, String message)? onProgress,
});

/// The steps of [EngineBootstrap.ensure], in order.
enum EngineBootstrapStep {
  prerequisites('Checking prerequisites'),
  source('Downloading engine source'),
  filament('Downloading Filament'),
  openriglogic('Downloading OpenRigLogic'),
  packages('Resolving packages');

  const EngineBootstrapStep(this.label);

  final String label;
}

/// An event of [EngineBootstrap.run] / [EngineBootstrap.ensure].
sealed class EngineBootstrapEvent {
  const EngineBootstrapEvent();
}

/// [step] started or advanced; [fraction] is null while unknown.
final class EngineBootstrapProgress extends EngineBootstrapEvent {
  final EngineBootstrapStep step;
  final double? fraction;
  final String message;

  const EngineBootstrapProgress(this.step, this.message, {this.fraction});

  @override
  String toString() => '[${step.name}] $message${fraction == null ? '' : ' (${(fraction! * 100).round()}%)'}';
}

/// A line of tool output (git, flutter) during [step].
final class EngineBootstrapLog extends EngineBootstrapEvent {
  final EngineBootstrapStep step;
  final String line;

  const EngineBootstrapLog(this.step, this.line);

  @override
  String toString() => '[${step.name}] $line';
}

/// [step] finished; [skipped] when there was nothing to do.
final class EngineBootstrapStepDone extends EngineBootstrapEvent {
  final EngineBootstrapStep step;
  final bool skipped;

  const EngineBootstrapStepDone(this.step, {this.skipped = false});
}

/// The prerequisite check's findings (sent whether or not any is missing).
final class EngineBootstrapPrerequisites extends EngineBootstrapEvent {
  final List<EnginePrerequisite> prerequisites;

  const EngineBootstrapPrerequisites(this.prerequisites);
}

/// The checkout is ready and active.
final class EngineBootstrapCompleted extends EngineBootstrapEvent {
  final EngineCheckout checkout;

  const EngineBootstrapCompleted(this.checkout);
}

/// The bootstrap stopped; running it again resumes.
final class EngineBootstrapFailed extends EngineBootstrapEvent {
  final EngineBootstrapException error;

  const EngineBootstrapFailed(this.error);
}

/// A tool the engine source needs on this machine.
class EnginePrerequisite {
  /// Display name, e.g. `Git`.
  final String name;

  /// Where it was found (a path, a version), or null when missing.
  final String? location;

  /// Missing required prerequisites stop the bootstrap; the others (the C++
  /// toolchain, needed only to build games and project editors) are
  /// reported.
  final bool required;

  /// How to install it.
  final String hint;

  const EnginePrerequisite({required this.name, required this.location, required this.required, required this.hint});

  bool get found => location != null;

  @override
  String toString() => '$name: ${location ?? 'missing'}';
}

/// Why [EngineBootstrap.ensure] stopped.
class EngineBootstrapException implements Exception {
  final String message;

  /// The step that failed.
  final EngineBootstrapStep step;

  /// The required prerequisites that are missing (step
  /// [EngineBootstrapStep.prerequisites]).
  final List<EnginePrerequisite> missing;

  const EngineBootstrapException(this.message, {required this.step, this.missing = const []});

  @override
  String toString() => 'EngineBootstrapException(${step.name}): $message';
}

/// A complete engine checkout, as recorded in its marker file.
class EngineCheckout {
  /// The checkout directory (`<data>/engine/<version>`).
  final String dir;

  /// The release tag it belongs to.
  final String version;

  /// The commit it is checked out at (detached).
  final String commit;

  /// The git URL it was cloned from.
  final String repo;

  /// The prebuilt Filament version (`tool/filament/VERSION`) and directory
  /// its `filament` link points at.
  final String filamentVersion;
  final String filamentDir;

  /// The prebuilt OpenRigLogic directory its `openriglogic` link points at.
  final String openriglogicDir;

  final DateTime completedAt;

  const EngineCheckout({
    required this.dir,
    required this.version,
    required this.commit,
    required this.repo,
    required this.filamentVersion,
    required this.filamentDir,
    required this.openriglogicDir,
    required this.completedAt,
  });

  Map<String, Object?> toJson() => {
        'version': version,
        'commit': commit,
        'repo': repo,
        'filamentVersion': filamentVersion,
        'filamentDir': filamentDir,
        'openriglogicDir': openriglogicDir,
        'completedAt': completedAt.toUtc().toIso8601String(),
      };

  static EngineCheckout? fromJson(String dir, Object? json) {
    if (json is! Map) return null;
    String? s(String k) => json[k] is String ? json[k] as String : null;
    final version = s('version'), commit = s('commit'), repo = s('repo');
    final fv = s('filamentVersion'), fd = s('filamentDir'), rd = s('openriglogicDir');
    if (version == null || commit == null || repo == null || fv == null || fd == null || rd == null) return null;
    return EngineCheckout(
      dir: dir,
      version: version,
      commit: commit,
      repo: repo,
      filamentVersion: fv,
      filamentDir: fd,
      openriglogicDir: rd,
      completedAt: DateTime.tryParse(s('completedAt') ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
