import 'dart:convert';

/// Why a crash report exists.
enum CrashReportKind {
  /// An error nobody caught while the editor was running.
  uncaught,

  /// The previous editor session ended without closing (the process died or
  /// was killed): found at the next launch.
  previousRun,

  /// A plugin's own process (an isolated plugin) died: the editor kept
  /// running. Carries the plugin, its exit code and its log tail.
  pluginCrash;

  String get wire => switch (this) { uncaught => 'uncaught', previousRun => 'previous_run', pluginCrash => 'plugin_crash' };

  static CrashReportKind fromWire(String? value) => switch (value) {
        'previous_run' => previousRun,
        'plugin_crash' => pluginCrash,
        _ => uncaught,
      };
}

/// What the crash report screen shows and, when the user agrees, sends:
/// the error, where it happened in the code, which build on which machine,
/// and the tail of the editor log. Nothing from the project but its name.
class CrashReport {
  const CrashReport({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.error,
    this.stackTrace = '',
    this.release = '',
    this.commit = '',
    this.editor = '',
    this.platform = '',
    this.osVersion = '',
    this.gpu = '',
    this.filament = '',
    this.project = '',
    this.plugin = '',
    this.logTail = const [],
    this.exitCode,
    this.sentId,
  });

  /// A local id (`<millis>-<counter>`), also the file name under `crashes/`.
  final String id;
  final CrashReportKind kind;
  final DateTime createdAt;

  /// The error's text (`toString()` of the exception, or a sentence for a
  /// previous-run report).
  final String error;
  final String stackTrace;

  /// The release tag and commit (empty in a dev build), the editor's own
  /// version string, `<os>-<arch>`, the OS version, the GPU in use and the
  /// linked Filament version.
  final String release;
  final String commit;
  final String editor;
  final String platform;
  final String osVersion;
  final String gpu;
  final String filament;

  /// The open project's name, when one was open.
  final String project;

  /// The plugin attributing this crash, or empty if from the engine/editor.
  final String plugin;

  bool get isPluginCrash => plugin.isNotEmpty;

  /// The last lines of the editor log before the crash (for a
  /// [CrashReportKind.pluginCrash], the plugin process's own log).
  final List<String> logTail;

  /// The exit code of a plugin process that died (null when it is not
  /// known, e.g. a process killed by a signal on some systems).
  final int? exitCode;

  /// The server's id once the report was sent.
  final String? sentId;

  bool get sent => sentId != null;

  /// The first line of [error], for titles.
  String get headline {
    final line = error.trim().split('\n').first.trim();
    return line.length > 160 ? '${line.substring(0, 157)}...' : line;
  }

  CrashReport copyWith({String? sentId, String? plugin}) => CrashReport(
        id: id,
        kind: kind,
        createdAt: createdAt,
        error: error,
        stackTrace: stackTrace,
        release: release,
        commit: commit,
        editor: editor,
        platform: platform,
        osVersion: osVersion,
        gpu: gpu,
        filament: filament,
        project: project,
        plugin: plugin ?? this.plugin,
        logTail: logTail,
        exitCode: exitCode,
        sentId: sentId ?? this.sentId,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.wire,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'error': error,
        'stackTrace': stackTrace,
        'release': release,
        'commit': commit,
        'editor': editor,
        'platform': platform,
        'osVersion': osVersion,
        'gpu': gpu,
        'filament': filament,
        'project': project,
        if (plugin.isNotEmpty) 'plugin': plugin,
        'logTail': logTail,
        if (exitCode != null) 'exitCode': exitCode,
        if (sentId != null) 'sentId': sentId,
      };

  factory CrashReport.fromJson(Map<String, Object?> j) => CrashReport(
        id: j['id'] as String,
        kind: CrashReportKind.fromWire(j['kind'] as String?),
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        error: j['error'] as String? ?? '',
        stackTrace: j['stackTrace'] as String? ?? '',
        release: j['release'] as String? ?? '',
        commit: j['commit'] as String? ?? '',
        editor: j['editor'] as String? ?? '',
        platform: j['platform'] as String? ?? '',
        osVersion: j['osVersion'] as String? ?? '',
        gpu: j['gpu'] as String? ?? '',
        filament: j['filament'] as String? ?? '',
        project: j['project'] as String? ?? '',
        plugin: j['plugin'] as String? ?? '',
        logTail: [for (final l in (j['logTail'] as List?) ?? const []) l.toString()],
        exitCode: j['exitCode'] as int?,
        sentId: j['sentId'] as String?,
      );

  /// The body `POST /api/v1/crash-reports` receives: this report plus what
  /// the user typed; the log only with [includeLog].
  Map<String, Object?> toSubmission({String description = '', String email = '', bool includeLog = true}) => {
        'kind': kind.wire,
        'error': error,
        'stackTrace': stackTrace,
        'description': description.trim(),
        if (email.trim().isNotEmpty) 'email': email.trim(),
        if (release.isNotEmpty) 'release': release,
        if (commit.isNotEmpty) 'commit': commit,
        if (editor.isNotEmpty) 'editor': editor,
        if (platform.isNotEmpty) 'platform': platform,
        if (osVersion.isNotEmpty) 'osVersion': osVersion,
        if (gpu.isNotEmpty) 'gpu': gpu,
        if (filament.isNotEmpty) 'filament': filament,
        if (project.isNotEmpty) 'project': project,
        if (plugin.isNotEmpty) 'plugin': plugin,
        if (exitCode != null) 'exitCode': exitCode,
        if (includeLog) 'logTail': logTail,
        'reportId': id,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  /// The report as text: what Copy puts on the clipboard and what the
  /// screen shows under "What is sent".
  String toText({String description = '', String email = '', bool includeLog = true}) {
    final b = StringBuffer()
      ..writeln('Lumina Studio crash report $id')
      ..writeln('Kind: ${switch (kind) {
        CrashReportKind.uncaught => 'uncaught error',
        CrashReportKind.previousRun => 'previous session ended unexpectedly',
        CrashReportKind.pluginCrash => 'plugin process ended unexpectedly',
      }}')
      ..writeln('When: ${createdAt.toUtc().toIso8601String()}');
    if (release.isNotEmpty || commit.isNotEmpty) b.writeln('Release: $release ${commit.isNotEmpty ? '(${commit.length > 12 ? commit.substring(0, 12) : commit})' : ''}'.trim());
    if (editor.isNotEmpty) b.writeln('Editor: $editor');
    if (platform.isNotEmpty || osVersion.isNotEmpty) b.writeln('System: $platform $osVersion'.trim());
    if (gpu.isNotEmpty) b.writeln('GPU: $gpu');
    if (filament.isNotEmpty) b.writeln('Filament: $filament');
    if (project.isNotEmpty) b.writeln('Project: $project');
    if (plugin.isNotEmpty) b.writeln('Plugin: $plugin');
    if (exitCode != null) b.writeln('Exit code: $exitCode');
    if (description.trim().isNotEmpty) b..writeln()..writeln('Description:')..writeln(description.trim());
    if (email.trim().isNotEmpty) b.writeln('Contact: ${email.trim()}');
    b..writeln()..writeln('Error:')..writeln(error.trim());
    if (stackTrace.trim().isNotEmpty) b..writeln()..writeln('Stack trace:')..writeln(stackTrace.trim());
    if (includeLog && logTail.isNotEmpty) {
      b..writeln()..writeln('Log (last ${logTail.length} lines):');
      logTail.forEach(b.writeln);
    }
    return b.toString();
  }

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());
}
