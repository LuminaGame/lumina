import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart' show Aabb3, Vector3;

import 'package:lumina_ui/ui/features/sub_editors/services/flutter_filament_web_module.dart';

export 'flutter_filament_web_module.dart' show FlutterFilamentWebModule;

part 'build_pipeline_service/material_precompile_step.dart';
part 'build_pipeline_service/navigation_thumbnail_validation_steps.dart';
part 'build_pipeline_service/cook_and_package_steps.dart';
part 'build_pipeline_service/host_build_targets.dart';

/// Build Manager pipeline: real build steps over the open
/// project — material precompile, navigation grid bake, thumbnail
/// regeneration, asset validation — and Cook & Package, which regenerates the
/// game's Dart code and drives a real `flutter build <target>` child process
/// with streamed output. Every event in the stream originates from actual
/// work; there are no fabricated counters.
///
/// The task file scopes this service into `package:lumina`; it lives here
/// because the engine package is frozen for this task (see the task notes).

/// The steps in their fixed documented execution order.
enum BuildStepKind {
  precompileMaterials('Precompile Materials'),
  buildNavigation('Build Navigation'),
  regenerateThumbnails('Regenerate Thumbnails'),
  validateAssets('Validate Assets'),
  cookAndPackage('Cook & Package');

  const BuildStepKind(this.label);
  final String label;
}

enum BuildStepStatus { pending, running, ok, failed, skipped, cancelled }

/// Build configuration names mapped to the literal `flutter build` flag.
enum BuildConfiguration {
  debug('Debug', '--debug', 'debug'),
  development('Development', '--profile', 'profile'),
  shipping('Shipping', '--release', 'release');

  const BuildConfiguration(this.label, this.flag, this.modeDir);
  final String label;

  /// The flag passed verbatim to `flutter build`.
  final String flag;

  /// Flutter's output-directory name for the mode.
  final String modeDir;
}

/// Cooperative cancellation shared by the pipeline and the running step.
class BuildCancellationToken {
  bool _cancelled = false;
  final List<void Function()> _listeners = [];

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  /// Registers [fn] to run when the token fires (immediately if already fired).
  void onCancel(void Function() fn) {
    if (_cancelled) {
      fn();
      return;
    }
    _listeners.add(fn);
  }

  void removeListener(void Function() fn) => _listeners.remove(fn);
}

// --- events ---------------------------------------------------------------

sealed class BuildEvent {
  final DateTime at = DateTime.now();
}

class BuildStepStarted extends BuildEvent {
  final BuildStepKind kind;
  BuildStepStarted(this.kind);
}

/// Measurable progress inside a step (materials compiled, thumbnails rendered…).
class BuildStepProgress extends BuildEvent {
  final BuildStepKind kind;
  final int completed;
  final int total;
  final int failed;
  final String label;
  BuildStepProgress(this.kind, {required this.completed, required this.total, this.failed = 0, required this.label});
}

class BuildLogEvent extends BuildEvent {
  final BuildStepKind? kind;
  final String level; // info | warning | error | success
  final String message;
  final String source;

  /// True when this line replaces the previous one (carriage-return progress
  /// spinners from `flutter build`).
  final bool replaceLast;
  BuildLogEvent({this.kind, required this.level, required this.message, required this.source, this.replaceLast = false});
}

class BuildStepFinished extends BuildEvent {
  final BuildStepKind kind;
  final BuildStepStatus status;
  final Duration duration;
  final String message;
  BuildStepFinished(this.kind, {required this.status, required this.duration, required this.message});
}

class BuildValidationIssue extends BuildEvent {
  final ValidationIssue issue;
  BuildValidationIssue(this.issue);
}

class BuildPipelineFinished extends BuildEvent {
  final BuildStepStatus status;
  final String? artifactPath;
  final Duration duration;
  BuildPipelineFinished({required this.status, this.artifactPath, required this.duration});
}

/// Where one packaging target stands in a multi-target run.
enum PackageTargetStatus { pending, running, ok, failed, unbuildable, cancelled }

/// A packaging target's build started.
class BuildTargetStarted extends BuildEvent {
  final String target;
  final int index;
  final int count;
  BuildTargetStarted(this.target, {required this.index, required this.count});
}

/// A packaging target finished: packaged into [packageDir], failed, was not
/// buildable (never spawned, [reasons] say why) or was cancelled.
class BuildTargetFinished extends BuildEvent {
  final String target;
  final PackageTargetStatus status;
  final String message;
  final String? packageDir;
  final Duration duration;
  final List<String> reasons;
  BuildTargetFinished(this.target, {required this.status, required this.message, this.packageDir, required this.duration, this.reasons = const []});
}

// --- validation ------------------------------------------------------------

enum ValidationIssueKind { missingTarget, danglingAssetId, selfReference, pathMismatch }

enum ValidationSeverity { error, warning }

class ValidationIssue {
  /// Project-relative path of the `.lmas` holding the broken reference.
  final String assetPath;
  final String slotName;
  final String targetPath;
  final String assetId;
  final ValidationIssueKind kind;
  final ValidationSeverity severity;
  final String message;
  const ValidationIssue({
    required this.assetPath,
    required this.slotName,
    required this.targetPath,
    required this.assetId,
    required this.kind,
    required this.severity,
    required this.message,
  });
}

// --- step contract ----------------------------------------------------------

class StepResult {
  final BuildStepStatus status;
  final String message;
  final String? artifactPath;
  final List<ValidationIssue> issues;
  const StepResult(this.status, this.message, {this.artifactPath, this.issues = const []});

  const StepResult.ok(String message, {String? artifactPath}) : this(BuildStepStatus.ok, message, artifactPath: artifactPath);
  const StepResult.failed(String message, {List<ValidationIssue> issues = const []}) : this(BuildStepStatus.failed, message, issues: issues);
  const StepResult.skipped(String message) : this(BuildStepStatus.skipped, message);
  const StepResult.cancelled(String message) : this(BuildStepStatus.cancelled, message);
}

/// What a step sees: the project on disk, the cancellation token and the
/// event sinks. Named to avoid clashing with Flutter's `BuildContext`.
class BuildStepContext {
  final String projectDir;
  final LuminaProject? project;
  final BuildCancellationToken token;
  final BuildStepKind kind;
  final void Function(BuildEvent event) _emit;

  /// The log source; the step's label unless a sub-task tags its lines
  /// (`Cook & Package [linux]`).
  final String source;

  BuildStepContext({
    required this.projectDir,
    required this.project,
    required this.token,
    required this.kind,
    required void Function(BuildEvent) emit,
    String? source,
  })  : _emit = emit, // ignore: prefer_initializing_formals
        source = source ?? kind.label;

  /// The same context with its log lines tagged [source].
  BuildStepContext withSource(String source) =>
      BuildStepContext(projectDir: projectDir, project: project, token: token, kind: kind, emit: _emit, source: source);

  void emit(BuildEvent event) => _emit(event);

  void log(String message, {String level = 'info', bool replaceLast = false}) =>
      _emit(BuildLogEvent(kind: kind, level: level, message: message, source: source, replaceLast: replaceLast));

  void progress({required int completed, required int total, int failed = 0, required String label}) =>
      _emit(BuildStepProgress(kind, completed: completed, total: total, failed: failed, label: label));

  void issue(ValidationIssue issue) => _emit(BuildValidationIssue(issue));

  /// Active level name (`L_Main`) from the manifest, or null.
  String? get activeLevelName {
    final rel = project?.activeLevel;
    if (rel == null || rel.isEmpty) return null;
    final base = rel.split('/').last;
    return base.endsWith('.lmas') ? base.substring(0, base.length - 5) : base;
  }

  File? get activeLevelFile {
    final rel = project?.activeLevel;
    if (rel == null || rel.isEmpty) return null;
    return File('$projectDir/$rel');
  }
}

abstract class BuildStep {
  BuildStepKind get kind;
  Future<StepResult> execute(BuildStepContext ctx);
}

class BuildPlan {
  final List<BuildStep> steps;
  const BuildPlan({required this.steps});
}

/// Process seam shared by the cook step and the toolchain probe (same shape
/// as `ProjectSettingsViewModel`'s `ProcessStarter`).
typedef BuildProcessStarter = Future<Process> Function(String executable, List<String> arguments, {String? workingDirectory});

Future<Process> defaultBuildProcessStarter(String executable, List<String> arguments, {String? workingDirectory}) =>
    Process.start(executable, arguments, workingDirectory: workingDirectory, runInShell: true);

// --- pipeline ---------------------------------------------------------------

class BuildPipelineService {
  /// Runs [plan]'s steps sequentially in the fixed [BuildStepKind] order
  /// (or in plan order when [keepPlanOrder]) and streams every event.
  /// [shouldContinue] is consulted before each step with the results so far;
  /// returning false ends the pipeline (used for the "validation failed —
  /// cook anyway?" confirmation).
  Stream<BuildEvent> run(
    BuildPlan plan, {
    required String projectDir,
    LuminaProject? project,
    BuildCancellationToken? token,
    bool keepPlanOrder = false,
    Future<bool> Function(BuildStepKind next, Map<BuildStepKind, StepResult> resultsSoFar)? shouldContinue,
  }) {
    final controller = StreamController<BuildEvent>();
    final tok = token ?? BuildCancellationToken();
    final steps = List<BuildStep>.of(plan.steps);
    if (!keepPlanOrder) steps.sort((a, b) => a.kind.index.compareTo(b.kind.index));

    Future<void> drive() async {
      final total = Stopwatch()..start();
      final results = <BuildStepKind, StepResult>{};
      String? artifactPath;
      var status = BuildStepStatus.ok;
      for (final step in steps) {
        if (tok.isCancelled) {
          status = BuildStepStatus.cancelled;
          break;
        }
        if (shouldContinue != null && !await shouldContinue(step.kind, Map.unmodifiable(results))) {
          controller.add(BuildLogEvent(kind: step.kind, level: 'warning', message: '${step.kind.label} not started', source: 'Pipeline'));
          if (status == BuildStepStatus.ok) status = BuildStepStatus.failed;
          break;
        }
        final ctx = BuildStepContext(projectDir: projectDir, project: project, token: tok, kind: step.kind, emit: controller.add);
        controller.add(BuildStepStarted(step.kind));
        final sw = Stopwatch()..start();
        StepResult result;
        try {
          result = await step.execute(ctx);
        } catch (e, st) {
          result = StepResult.failed('${step.kind.label} threw: $e');
          ctx.log('$e\n$st', level: 'error');
        }
        sw.stop();
        results[step.kind] = result;
        ctx.log(
          result.message,
          level: switch (result.status) {
            BuildStepStatus.ok => 'success',
            BuildStepStatus.failed => 'error',
            BuildStepStatus.cancelled => 'warning',
            _ => 'info',
          },
        );
        controller.add(BuildStepFinished(step.kind, status: result.status, duration: sw.elapsed, message: result.message));
        if (result.artifactPath != null) artifactPath = result.artifactPath;
        if (result.status == BuildStepStatus.cancelled) {
          status = BuildStepStatus.cancelled;
          break;
        }
        if (result.status == BuildStepStatus.failed && status == BuildStepStatus.ok) status = BuildStepStatus.failed;
      }
      if (tok.isCancelled) status = BuildStepStatus.cancelled;
      controller.add(BuildPipelineFinished(status: status, artifactPath: status == BuildStepStatus.ok ? artifactPath : null, duration: total.elapsed));
    }

    drive().whenComplete(controller.close);
    return controller.stream;
  }
}

// --- shared helpers ---------------------------------------------------------

class _ScannedAsset {
  final File file;
  final String relativePath;
  final LuminaAsset asset;
  const _ScannedAsset(this.file, this.relativePath, this.asset);
}

/// Every parseable `.lmas` under `contents/`, sorted by path. Unreadable
/// files are reported through [onError] and skipped.
List<_ScannedAsset> _scanLmas(String projectDir, {void Function(String path, Object error)? onError}) {
  final contents = Directory('$projectDir/contents');
  if (!contents.existsSync()) return const [];
  final out = <_ScannedAsset>[];
  final files = contents.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.lmas')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    try {
      final asset = LuminaAsset.fromBytes(f.readAsBytesSync());
      out.add(_ScannedAsset(f, _relative(projectDir, f.path), asset));
    } catch (e) {
      onError?.call(f.path, e);
    }
  }
  return out;
}

String _relative(String projectDir, String path) {
  // Project-relative paths use '/' on every host, as `.lmas` references store
  // them; directory listings on Windows mix in '\'.
  path = path.replaceAll(r'\', '/');
  final dir = projectDir.replaceAll(r'\', '/');
  final root = dir.endsWith('/') ? dir : '$dir/';
  if (path.startsWith(root)) return path.substring(root.length);
  if (path.startsWith('./')) return path.substring(2);
  return path;
}

/// Reads a level `.lmas` as a JSON map whether it was written by the editor
/// (plain JSON) or by [AssetRepository] (JSON behind the `LMAS` magic).
Map<String, dynamic> _readLevelMap(File levelFile) {
  final bytes = levelFile.readAsBytesSync();
  final hasMagic = bytes.length >= 4 && bytes[0] == 0x4C && bytes[1] == 0x4D && bytes[2] == 0x41 && bytes[3] == 0x53;
  final text = utf8.decode(hasMagic ? bytes.sublist(4) : bytes);
  final decoded = jsonDecode(text);
  if (decoded is! Map) throw const FormatException('level file is not a JSON object');
  return Map<String, dynamic>.from(decoded);
}

String _fmt(Duration d) => d.inMilliseconds < 1000 ? '${d.inMilliseconds} ms' : '${(d.inMilliseconds / 1000).toStringAsFixed(1)} s';
