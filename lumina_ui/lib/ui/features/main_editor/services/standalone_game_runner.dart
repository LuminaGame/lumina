import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumina/data/repositories/project_repository.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/lumina.dart' show LuminaGraphicsDevices, ProjectEngineLink, SpaceFreeBuildDir;

/// Where Play Standalone is.
enum StandaloneState { idle, building, running }

/// Play Standalone: builds
/// the project with the real `flutter build linux|windows --debug` (the
/// host's platform) and runs the built
/// game as its own process, where everything runs — the project's Dart
/// functions exposed to Blueprints included, which the editor process never
/// executes. The build's and the game's output stream into the Output Log;
/// [stop] kills the game (or the build).
///
/// The game is launched from its bundle rather than through `flutter run`
/// so the process Stop kills is the game itself, not a tool that owns it.
class StandaloneGameRunner extends ChangeNotifier {
  final String projectDir;
  final String flutterExecutable;
  final EngineLoggerService _logger = EngineLoggerService();

  StandaloneGameRunner(this.projectDir, {this.flutterExecutable = 'flutter'});

  StandaloneState _state = StandaloneState.idle;
  Process? _build;
  Process? _game;
  bool _stopRequested = false;
  bool _disposed = false;

  StandaloneState get state => _state;
  bool get isActive => _state != StandaloneState.idle;

  /// The running game's process id, while it runs.
  int? get pid => _game?.pid;

  /// The id of the last game process started (kept after it ends, so a test
  /// can check it is gone).
  int? lastPid;

  /// How the last game process ended, once it has.
  int? lastExitCode;

  /// Lines the build and the game printed (also in the Output Log).
  final List<String> output = [];

  static const String _source = 'Standalone';

  /// The environment the game runs in: the editor's, on the GPU the editor
  /// renders with (the one chosen in the launcher) unless the
  /// environment already picks one.
  static Map<String, String> gameEnvironment([Map<String, String>? base]) {
    final env = Map<String, String>.from(base ?? Platform.environment);
    final preferred = LuminaGraphicsDevices.inUse.value;
    final overridden = (env['FILAMENT_GPU'] ?? '').isNotEmpty || (env['VK_DEVICE_INDEX'] ?? '').isNotEmpty;
    if (!overridden && preferred != null && preferred.isNotEmpty) env['FILAMENT_GPU'] = preferred;
    return env;
  }

  /// The desktop platform the game is built for: the host's.
  static String get hostPlatform => Platform.isWindows ? 'windows' : 'linux';

  /// The built game's executable: `build/linux/<arch>/debug/bundle/<name>`
  /// on Linux, `build/windows/<arch>/runner/Debug/<name>.exe` on Windows.
  File? bundleExecutable() {
    final name = _binaryName();
    if (name == null) return null;
    final out = Directory('$projectDir/build/$hostPlatform');
    if (!out.existsSync()) return null;
    for (final arch in out.listSync().whereType<Directory>()) {
      final exe = Platform.isWindows
          ? File('${arch.path}/runner/Debug/$name.exe')
          : File('${arch.path}/debug/bundle/$name');
      if (exe.existsSync()) return exe;
    }
    return null;
  }

  /// `BINARY_NAME` of the project's `<platform>/CMakeLists.txt`.
  String? _binaryName() {
    final cmake = File('$projectDir/$hostPlatform/CMakeLists.txt');
    if (!cmake.existsSync()) return null;
    final m = RegExp(r'set\(BINARY_NAME\s+"([^"]+)"\)').firstMatch(cmake.readAsStringSync());
    return m?.group(1);
  }

  /// Builds and launches the game. Returns whether the game started.
  Future<bool> start({Map<String, String>? environment}) async {
    if (isActive) return false;
    _stopRequested = false;
    output.clear();
    lastExitCode = null;
    final platform = hostPlatform;
    if (!File('$projectDir/$platform/CMakeLists.txt').existsSync()) {
      _logger.log('Play Standalone needs the project\'s $platform runner ($platform/CMakeLists.txt); '
          'run `flutter create --platforms=$platform .` in $projectDir.', level: 'error', source: _source);
      return false;
    }
    // Ensure all content asset directories are registered in pubspec.yaml before building.
    ProjectRepository.ensurePubspecAssets(projectDir);
    // From a local engine checkout: its packages (pubspec_overrides.yaml) and
    // this machine's Filament build for the native hooks, kept current.
    if (ProjectEngineLink.localEngineRoot(luminaPackageDir: ProjectRepository.luminaPackagePath) != null) {
      try {
        ProjectEngineLink.apply(projectDir,
            luminaPackageDir: ProjectRepository.luminaPackagePath,
            onLog: (m) => _logger.log(m, level: 'warning', source: _source));
      } on Object catch (e) {
        _logger.log('Could not link the project to the local engine: $e', level: 'warning', source: _source);
      }
    }
    final env = gameEnvironment(environment);
    _setState(StandaloneState.building);
    _logger.log('Play Standalone: flutter build $platform --debug${env['FILAMENT_GPU'] != null ? ' (GPU "${env['FILAMENT_GPU']}")' : ''}',
        level: 'info', source: _source);
    try {
      // On Windows through a space-free alias of the project: the
      // native-assets hooks cannot compile under a path with a space.
      final buildDir = SpaceFreeBuildDir.of(projectDir);
      // `flutter` is a .bat on Windows, found only through the shell.
      final build = await Process.start(flutterExecutable, ['build', platform, '--debug'],
          workingDirectory: buildDir, environment: env, runInShell: Platform.isWindows);
      _build = build;
      _pipe(build, 'info');
      final code = await build.exitCode;
      _build = null;
      if (_stopRequested) {
        _logger.log('Play Standalone stopped during the build.', level: 'warning', source: _source);
        _setState(StandaloneState.idle);
        return false;
      }
      if (code != 0) {
        _logger.log('Play Standalone: the build failed (exit $code). The build output is above.', level: 'error', source: _source);
        _setState(StandaloneState.idle);
        return false;
      }
      final exe = bundleExecutable();
      if (exe == null) {
        _logger.log('Play Standalone: the build succeeded but no game executable is in build/$platform.',
            level: 'error', source: _source);
        _setState(StandaloneState.idle);
        return false;
      }
      final game = await Process.start(exe.path, const [], workingDirectory: exe.parent.path, environment: env);
      _game = game;
      lastPid = game.pid;
      _setState(StandaloneState.running);
      _logger.log('Play Standalone: ${exe.uri.pathSegments.last} running (pid ${game.pid}).', level: 'success', source: _source);
      _pipe(game, 'info');
      unawaited(game.exitCode.then((code) {
        lastExitCode = code;
        if (!identical(_game, game)) return;
        _game = null;
        _logger.log('Play Standalone: the game exited (${_stopRequested ? 'stopped' : 'exit $code'}).',
            level: code == 0 || _stopRequested ? 'info' : 'warning', source: _source);
        _setState(StandaloneState.idle);
      }));
      return true;
    } catch (e) {
      _build = null;
      _logger.log('Play Standalone could not start: $e', level: 'error', source: _source);
      _setState(StandaloneState.idle);
      return false;
    }
  }

  void _pipe(Process process, String level) {
    void forward(Stream<List<int>> stream, String lineLevel) {
      stream.transform(const Utf8Decoder(allowMalformed: true)).transform(const LineSplitter()).listen((line) {
        if (line.trim().isEmpty) return;
        output.add(line);
        _logger.log(line, level: lineLevel, source: _source);
      });
    }

    forward(process.stdout, level);
    forward(process.stderr, 'warning');
  }

  /// Stops the game (SIGTERM, then SIGKILL after [grace]) or the build, and
  /// completes when the process has ended.
  Future<void> stop({Duration grace = const Duration(seconds: 3)}) async {
    if (!isActive) return;
    _stopRequested = true;
    final process = _game ?? _build;
    if (process == null) return;
    process.kill(ProcessSignal.sigterm);
    final ended = await process.exitCode.timeout(grace, onTimeout: () {
      process.kill(ProcessSignal.sigkill);
      return -9;
    });
    if (identical(process, _game)) {
      lastExitCode ??= ended;
      _game = null;
      _setState(StandaloneState.idle);
    }
  }

  void _setState(StandaloneState s) {
    _state = s;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _game?.kill(ProcessSignal.sigkill);
    _build?.kill(ProcessSignal.sigkill);
    super.dispose();
  }
}
