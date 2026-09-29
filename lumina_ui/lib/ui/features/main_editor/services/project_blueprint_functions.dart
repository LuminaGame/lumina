import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumina/data/services/blueprint_function_scanner.dart';
import 'package:lumina/data/services/engine_logger_service.dart';

/// The project's Dart functions exposed to Blueprints: lumina's [BlueprintFunctionScanner] over the
/// project's `lib/`, run when the project opens and whenever a Dart file
/// under `lib/` that mentions `@BlueprintCallable` / `@BlueprintPure` (or
/// did at the last scan) changes on disk — the editor's saves and an IDE's
/// alike, debounced by [debounce].
///
/// Each scan writes `lib/blueprint/blueprint_functions.g.dart` and
/// `project.blueprint_functions.json`, declares the functions to this
/// process ([BlueprintFunctionManifest.declareAll]) so the palette, the
/// validator and the code generator know them, and reports the scanner's
/// diagnostics in the Output Log with file and line. The editor never runs
/// project code: in Play In Editor such a node is skipped with a "requires
/// Play Standalone" notice.
class ProjectBlueprintFunctions extends ChangeNotifier {
  final String projectDir;
  final Duration debounce;
  final BlueprintFunctionScanner scanner;
  final EngineLoggerService _logger = EngineLoggerService();

  ProjectBlueprintFunctions(
    this.projectDir, {
    this.debounce = const Duration(milliseconds: 500),
    // Warm between scans: a save rescans in well under a second, so a new
    // node reaches the palette within the task's 2 s.
    this.scanner = const BlueprintFunctionScanner(keepWarm: true),
  });

  static final RegExp _marker = RegExp(r'\bBlueprint(Callable|Pure)\b');

  List<BlueprintExposedFunction> _functions = const [];
  List<BlueprintFunctionDiagnostic> _diagnostics = const [];
  Set<String> _annotated = const {};
  StreamSubscription<FileSystemEvent>? _watch;
  Timer? _debounceTimer;
  Future<void>? _running;
  bool _again = false;
  bool _disposed = false;

  /// The exposed functions of the last scan (or of the manifest on disk
  /// before the first one), sorted by node id.
  List<BlueprintExposedFunction> get functions => _functions;

  /// The scanner's findings on annotated functions it refused.
  List<BlueprintFunctionDiagnostic> get diagnostics => _diagnostics;

  bool get isScanning => _running != null;
  bool get isWatching => _watch != null;

  /// Scans completed in this session.
  int scanCount = 0;

  /// How long the last scan took (the analyzer resolves `package:lumina`
  /// once per scan when any file is annotated).
  Duration? lastScanDuration;

  /// The diagnostic of the function [name] (`applyDamage`, `Class.method`),
  /// if the last scan refused it.
  BlueprintFunctionDiagnostic? diagnosticFor(String name) =>
      _diagnostics.where((d) => d.function == name).firstOrNull;

  /// Opens the project: the manifest on disk first (the palette is right at
  /// once), then a watcher on `lib/` and a fresh scan.
  Future<void> open() async {
    loadManifest();
    watch();
    await scan();
  }

  /// Declares what `project.blueprint_functions.json` lists, without scanning.
  void loadManifest() {
    final manifest = BlueprintFunctionManifest.read(Directory(projectDir));
    if (manifest == null) return;
    manifest.declareAll();
    _functions = List.unmodifiable(manifest.functions);
    _diagnostics = List.unmodifiable(manifest.diagnostics);
    _annotated = {for (final f in manifest.functions) _abs('$projectDir/${f.path}')};
    if (!_disposed) notifyListeners();
  }

  /// Watches `lib/` for changes to annotated Dart files.
  void watch() {
    if (_watch != null) return;
    final lib = Directory('$projectDir/lib');
    if (!lib.existsSync()) return;
    _watch = lib.watch(recursive: true).listen(_onEvent, onError: (Object e) {
      _logger.log('Watching lib/ for Blueprint functions stopped: $e', level: 'warning', source: 'BlueprintFunctions');
    });
  }

  void _onEvent(FileSystemEvent event) {
    final paths = [event.path, if (event is FileSystemMoveEvent && event.destination != null) event.destination!];
    if (!paths.any(_relevant)) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () {
      if (!_disposed) scan();
    });
  }

  /// A Dart file (not generated) that is, or at the last scan was, annotated.
  bool _relevant(String path) {
    if (!path.endsWith('.dart') || path.endsWith('.g.dart')) return false;
    final abs = _abs(path);
    if (_annotated.contains(abs)) return true;
    try {
      return File(abs).existsSync() && _marker.hasMatch(File(abs).readAsStringSync());
    } catch (_) {
      return false;
    }
  }

  /// Rescans `lib/`. A scan requested while one runs runs after it; the
  /// returned future completes when the newest one has.
  Future<void> scan() {
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    final future = _loop();
    _running = future;
    return future.whenComplete(() => _running = null);
  }

  Future<void> _loop() async {
    do {
      _again = false;
      await _scanOnce();
    } while (_again && !_disposed);
  }

  Future<void> _scanOnce() async {
    final stopwatch = Stopwatch()..start();
    BlueprintFunctionScan scan;
    try {
      scan = await scanner.scan(Directory('$projectDir/lib'));
    } catch (e) {
      scan = BlueprintFunctionScan.empty([
        BlueprintFunctionDiagnostic(path: 'lib', line: 1, function: '', message: 'Reading the Blueprint functions failed: $e'),
      ]);
    }
    if (_disposed) return;
    final registration = File('$projectDir/${BlueprintFunctionScanner.registrationPath}');
    final manifest = File('$projectDir/${BlueprintFunctionManifest.fileName}');
    // A project that never exposed anything gets no files; one that did keeps
    // them in step (an empty registration keeps main.dart's import valid).
    if (scan.functions.isNotEmpty || scan.diagnostics.isNotEmpty || registration.existsSync() || manifest.existsSync()) {
      try {
        scanner.writeProjectOutputs(Directory(projectDir), scan);
      } catch (e) {
        _logger.log('Could not write the Blueprint function registration: $e', level: 'error', source: 'BlueprintFunctions');
      }
    }
    scan.manifest.declareAll();
    _functions = scan.functions;
    _diagnostics = scan.diagnostics;
    _annotated = _annotatedFiles();
    lastScanDuration = stopwatch.elapsed;
    scanCount++;

    for (final d in scan.diagnostics) {
      _logger.log('${d.path}:${d.line}: ${d.message}', level: 'error', source: 'BlueprintFunctions');
    }
    if (scan.functions.isNotEmpty || scan.diagnostics.isNotEmpty) {
      final names = scan.functions.map((f) => f.spec.title).join(', ');
      _logger.log(
        '${scan.functions.length} Blueprint function(s) exposed${names.isEmpty ? '' : ': $names'}'
        '${scan.diagnostics.isEmpty ? '' : ' · ${scan.diagnostics.length} refused'} '
        '(${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)} s)',
        level: scan.diagnostics.isEmpty ? 'success' : 'warning',
        source: 'BlueprintFunctions',
      );
    }
    notifyListeners();
  }

  Set<String> _annotatedFiles() {
    final lib = Directory('$projectDir/lib');
    if (!lib.existsSync()) return const {};
    final out = <String>{};
    for (final f in lib.listSync(recursive: true, followLinks: false).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('.g.dart')) continue;
      try {
        if (_marker.hasMatch(f.readAsStringSync())) out.add(_abs(f.path));
      } catch (_) {}
    }
    return out;
  }

  static String _abs(String path) => File(path).absolute.path;

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _watch?.cancel();
    _watch = null;
    if (scanner.keepWarm) unawaited(BlueprintFunctionScanner.release(Directory('$projectDir/lib')));
    super.dispose();
  }
}
