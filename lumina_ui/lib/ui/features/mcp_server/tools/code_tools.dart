import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lumina/lumina.dart' show AssetType;
import 'package:path/path.dart' as p;

import '../../main_editor/view_models/editor_view_model.dart';
import '../services/mcp_file_snapshots.dart';
import '../services/mcp_protocol.dart';
import '../services/mcp_tool.dart';
import '../services/project_dart_sdk.dart';
import '../services/project_sandbox.dart';
import 'blueprint_tool_support.dart' show mcpRefuseWhilePlaying;
import 'fs_tools.dart' show mcpFileSnapshotsOf, mcpSandboxed;
import 'package:lumina/data/services/dart_identifiers.dart';

/// One line of `dart analyze --format=machine`.
class DartDiagnostic {
  final String severity;
  final String type;
  final String code;
  final String file;
  final int line;
  final int column;
  final int length;
  final String message;

  const DartDiagnostic({
    required this.severity,
    required this.type,
    required this.code,
    required this.file,
    required this.line,
    required this.column,
    required this.length,
    required this.message,
  });

  static const List<String> severities = ['info', 'warning', 'error'];

  int get rank => severities.indexOf(severity);

  Map<String, Object?> toJson() => {
        'severity': severity,
        'type': type,
        'code': code,
        'file': file,
        'line': line,
        'column': column,
        'length': length,
        'message': message,
      };

  /// `SEVERITY|TYPE|CODE|FILE|LINE|COL|LENGTH|MESSAGE` with `\|` and `\\`
  /// escaped; null for any other line.
  static DartDiagnostic? parse(String line) {
    final fields = <String>[];
    final b = StringBuffer();
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == r'\' && i + 1 < line.length) {
        b.write(line[++i]);
      } else if (c == '|') {
        fields.add(b.toString());
        b.clear();
      } else {
        b.write(c);
      }
    }
    fields.add(b.toString());
    if (fields.length < 8) return null;
    final severity = fields[0].trim().toLowerCase();
    if (!severities.contains(severity)) return null;
    final lineNo = int.tryParse(fields[4]);
    final col = int.tryParse(fields[5]);
    final len = int.tryParse(fields[6]);
    if (lineNo == null || col == null || len == null) return null;
    return DartDiagnostic(
      severity: severity,
      type: fields[1],
      code: fields[2].toLowerCase(),
      file: fields[3],
      line: lineNo,
      column: col,
      length: len,
      message: fields.sublist(7).join('|'),
    );
  }
}

/// One `dart analyze` at a time per project (a second call waits).
final Map<String, Future<void>> _analysisQueue = {};

/// The code tools, group `code`: the project's `dart analyze`
/// diagnostics, run with the SDK its packages were resolved with, and the
/// editor's Generate Dart Code, awaited.
void registerCodeTools(McpToolRegistry registry, EditorViewModel vm) {
  const code = {McpToolGroups.code};

  String relativeTo(ProjectSandbox box, String file) {
    for (final base in [box.root, p.normalize(p.absolute(vm.projectDirPath))]) {
      if (p.isWithin(base, file)) return p.relative(file, from: base).replaceAll(r'\', '/');
    }
    return file;
  }

  Future<McpToolResult> analyze(McpArgs args) async {
    final box = ProjectSandbox(vm.projectDirPath);
    final paths = args.has('paths') ? args.stringList('paths') : const <String>[];
    final targets = [for (final raw in paths) box.resolve(raw, access: SandboxAccess.read).relative];
    if (!ProjectDartSdk.packageConfig(vm.projectDirPath).existsSync()) {
      return McpToolResult.error('The packages are not resolved; run `flutter pub get` in the project (${vm.projectDirPath}).');
    }
    final sdk = ProjectDartSdk.resolve(vm.projectDirPath);
    if (sdk == null) {
      return McpToolResult.error('No Dart SDK found: neither the project\'s package_config.json flutterRoot nor FLUTTER_ROOT '
          'names a Flutter SDK. Run `flutter pub get` in the project with the Flutter SDK it should use.');
    }
    final minSeverity = args.optionalString('min_severity') ?? 'info';
    final minRank = DartDiagnostic.severities.indexOf(minSeverity);
    final max = args.integer('max_results', fallback: 200).clamp(1, 1000);

    final sw = Stopwatch()..start();
    final process = await Process.start(
      ProjectDartSdk.dartExecutable(sdk),
      ['analyze', '--format=machine', ...(targets.isEmpty ? ['.'] : targets)],
      workingDirectory: box.root,
      environment: const {'DART_SUPPRESS_ANALYTICS': 'true', 'FLUTTER_SUPPRESS_ANALYTICS': 'true'},
    );
    final out = process.stdout.transform(utf8.decoder).join();
    final err = process.stderr.transform(utf8.decoder).join();
    int exit;
    try {
      exit = await process.exitCode.timeout(const Duration(seconds: 180));
    } on TimeoutException {
      process.kill();
      return McpToolResult.error('dart analyze did not finish within 180 s and was stopped.');
    }
    final stdoutText = await out;
    final stderrText = await err;
    final diagnostics = <DartDiagnostic>[];
    for (final line in const LineSplitter().convert('$stdoutText\n$stderrText')) {
      final d = DartDiagnostic.parse(line.trim());
      if (d != null) diagnostics.add(d);
    }
    if (exit > 3 && diagnostics.isEmpty) {
      return McpToolResult.error('dart analyze failed (exit $exit): ${stderrText.trim().isEmpty ? stdoutText.trim() : stderrText.trim()}');
    }
    int count(String s) => diagnostics.where((d) => d.severity == s).length;
    // The user sees what the agent sees, in the Output Log.
    final errors = diagnostics.where((d) => d.severity == 'error').toList();
    vm.logger.log(
      errors.isEmpty
          ? 'dart analyze: no errors (${count('warning')} warnings, ${count('info')} infos)'
          : 'dart analyze: ${errors.length} error(s)',
      level: errors.isEmpty ? 'success' : 'error',
      source: 'MCP',
    );
    for (final d in errors.take(5)) {
      vm.logger.log('  ${relativeTo(box, d.file)}:${d.line}:${d.column} ${d.code}: ${d.message}', level: 'error', source: 'MCP');
    }
    final shown = [
      for (final d in diagnostics)
        if (d.rank >= minRank) d,
    ]..sort((a, b) => b.rank != a.rank ? b.rank.compareTo(a.rank) : '${a.file}:${a.line}'.compareTo('${b.file}:${b.line}'));
    return McpToolResult.json({
      'ok': count('error') == 0,
      'counts': {'error': count('error'), 'warning': count('warning'), 'info': count('info')},
      'diagnostics': [
        for (final d in shown.take(max))
          {...d.toJson(), 'file': relativeTo(box, d.file)},
      ],
      'truncated': shown.length > max,
      'elapsed_ms': sw.elapsedMilliseconds,
      'sdk': sdk,
    });
  }

  registry.registerAll([
    McpTool(
      name: 'dart_analyze',
      title: 'Analyze the game code',
      risk: McpToolRisk.readOnly,
      groups: code,
      openWorld: false,
      description: 'Runs the project\'s `dart analyze` (the SDK its packages were resolved with) on the project or on '
          'paths inside it and returns {ok (no errors), counts {error, warning, info}, diagnostics [{severity, type, '
          'code, file, line, column, length, message}] (errors first, project-relative files), truncated, elapsed_ms, '
          'sdk}. min_severity drops lesser diagnostics from the list (counts keep them). Needs resolved packages '
          '(`flutter pub get`). One analysis at a time per project; 180 s timeout.',
      inputSchema: McpSchema.object({
        'paths': McpSchema.stringArray('Files or folders inside the project (default: the whole project).'),
        'min_severity': McpSchema.string('The least severity listed (default "info").', enumValues: DartDiagnostic.severities),
        'max_results': McpSchema.integer('At most this many diagnostics (default 200, cap 1000).'),
      }),
      handler: (args) => mcpSandboxed(() async {
        final key = p.normalize(p.absolute(vm.projectDirPath));
        final previous = _analysisQueue[key] ?? Future<void>.value();
        final done = Completer<void>();
        final mine = done.future;
        _analysisQueue[key] = mine;
        try {
          await previous;
          return await analyze(args);
        } finally {
          done.complete();
          if (identical(_analysisQueue[key], mine)) _analysisQueue.remove(key);
        }
      }),
    ),
    McpTool(
      name: 'run_codegen',
      title: 'Generate Dart code',
      risk: McpToolRisk.mutating,
      // Build → Generate Dart Code, so the build group lists it too.
      groups: const {McpToolGroups.code, McpToolGroups.build},
      idempotent: true,
      wraps: const {'build.generateDartCode'},
      description: 'Build → Generate Dart Code, awaited: saves the open level (its .lmas) and regenerates lib/main.dart '
          'and lib/levels/<level>.dart (snake_case: L_Main → l_main.dart) — the same routine as Save Level. Each file is snapshotted first (fs_history / '
          'fs_restore bring a hand edit back). Returns {written_files, level, elapsed_ms, stale_blueprints, snapshots}; '
          'stale_blueprints are Blueprint .lmas newer than their lib/actors/<name>.dart, snake_case (compile_blueprint them). '
          'Refused while Play runs.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) async {
        final refusal = mcpRefuseWhilePlaying(vm);
        if (refusal != null) return refusal;
        final level = vm.activeLevelName;
        final targets = ['contents/levels/$level.lmas', 'lib/main.dart', 'lib/levels/${dartFileName(level)}'];
        final store = mcpFileSnapshotsOf(vm);
        final context = McpSnapshotContext.current();
        final taken = [for (final t in targets) store.take(t, 'run_codegen', context)];
        final sw = Stopwatch()..start();
        final written = await vm.generateDartCode();
        final dir = vm.projectDirPath;
        String rel(String abs) => p.isWithin(dir, abs) ? p.relative(abs, from: dir).replaceAll(r'\', '/') : abs;
        final stale = <String>[];
        for (final asset in vm.realAssets.where((a) => a.type == AssetType.actor)) {
          final lmas = File(p.join(dir, asset.relativePath));
          final generated = File(p.join(dir, 'lib', 'actors', dartFileName(p.basenameWithoutExtension(asset.relativePath))));
          if (lmas.existsSync() && generated.existsSync() && lmas.lastModifiedSync().isAfter(generated.lastModifiedSync())) {
            stale.add(asset.relativePath);
          }
        }
        return McpToolResult.json({
          'written_files': [targets.first, for (final w in written) rel(w)],
          'level': level,
          'elapsed_ms': sw.elapsedMilliseconds,
          'stale_blueprints': stale,
          'snapshots': [for (final s in taken) {'id': s.id, 'path': s.path}],
        });
      },
    ),
  ]);
}
