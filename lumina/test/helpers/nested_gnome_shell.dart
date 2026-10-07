import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lumina_core/lumina_core.dart';
import 'package:path/path.dart' as p;

/// A nested, isolated, headless GNOME Shell for native pointer-capture checks,
/// driven through
/// `lumina_mouse_capture/tool/nested_compositor/nested_session.py serve` (the
/// tools repo's package, found through the workspace's package config): the shell runs under bwrap with the GPU hidden, on a private
/// D-Bus with private HOME/XDG directories; input comes from Mutter's
/// RemoteDesktop API on that bus. Nothing reaches the desktop of the person
/// working at this machine.
class NestedGnomeShell {
  NestedGnomeShell._(this._process, this._replies);

  final Process _process;
  final StreamIterator<String> _replies;

  /// The environment a client of the nested shell (and only it) runs with.
  late final Map<String, String> clientEnvironment;

  /// The lumina_mouse_capture package (tools repo) as the workspace resolved
  /// it: the local `../tools` override, or its git checkout in the pub cache.
  static String get packageDir => LuminaWorkspace.package('lumina_mouse_capture');

  static String get script => p.join(packageDir, 'tool', 'nested_compositor', 'nested_session.py');

  /// Why the nested shell cannot run here, or null when it can.
  static Future<String?> unavailableReason() async {
    for (final exe in ['gnome-shell', 'bwrap', 'dbus-run-session', 'python3', 'ss']) {
      final which = await Process.run('which', [exe]);
      if (which.exitCode != 0) return '$exe is not installed';
    }
    final gi = await Process.run('python3', ['-c', "import gi; gi.require_version('Gio', '2.0')"]);
    if (gi.exitCode != 0) return 'python3-gi is not installed';
    if (!File(script).existsSync()) return '$script not found (run `flutter pub get` in the workspace)';
    return null;
  }

  static Future<NestedGnomeShell> start() async {
    final process = await Process.start('python3', [script, 'serve']);
    process.stderr.transform(utf8.decoder).listen(stderr.write);
    final replies = StreamIterator(process.stdout.transform(utf8.decoder).transform(const LineSplitter()));
    final shell = NestedGnomeShell._(process, replies);
    final started = await shell._send({'cmd': 'start'}, timeout: const Duration(seconds: 60));
    // A nested client is a real app, not a test: `flutter test` exports
    // FLUTTER_TEST, and a debug Flutter app that sees it reports
    // `defaultTargetPlatform == android` (foundation's _platform_io.dart),
    // so lumina_mouse_capture chose the recording backend ("not Linux").
    shell.clientEnvironment = Map<String, String>.from(started['env'] as Map)..remove('FLUTTER_TEST');
    return shell;
  }

  Future<Map<String, dynamic>> _send(Map<String, Object?> command, {Duration timeout = const Duration(seconds: 20)}) async {
    _process.stdin.writeln(jsonEncode(command));
    await _process.stdin.flush();
    if (!await _replies.moveNext().timeout(timeout)) {
      throw StateError('nested_session.py ended before answering ${command['cmd']}');
    }
    final reply = jsonDecode(_replies.current) as Map<String, dynamic>;
    if (reply['ok'] != true) throw StateError('nested_session.py ${command['cmd']}: ${reply['error']}');
    return reply;
  }

  /// Opens the RemoteDesktop session (after the client's window is up).
  Future<void> connectInput() => _send({'cmd': 'input'});

  Future<void> move(double dx, double dy) => _send({'cmd': 'move', 'dx': dx, 'dy': dy});

  Future<void> key(int keysym) => _send({'cmd': 'key', 'keysym': keysym});

  Future<void> click() => _send({'cmd': 'click'});

  /// The nested screen, cursor included, as PNG bytes.
  Future<List<int>> screenshot(String path) async {
    await _send({'cmd': 'shot', 'path': path});
    return File(path).readAsBytesSync();
  }

  /// Screenshots at [fps] into [dir] until [stopRecording].
  Future<void> startRecording(String dir, {int fps = 30}) => _send({'cmd': 'record', 'dir': dir, 'fps': fps});

  /// The recorded frames: `(path, seconds since epoch)`.
  Future<List<({String path, double t})>> stopRecording() async {
    final reply = await _send({'cmd': 'stop_record'}, timeout: const Duration(seconds: 30));
    return [
      for (final f in reply['frames'] as List)
        (path: (f as Map)['path'] as String, t: (f['t'] as num).toDouble()),
    ];
  }

  Future<void> stop() async {
    try {
      await _send({'cmd': 'stop'}, timeout: const Duration(seconds: 30));
    } catch (_) {
      _process.kill();
    }
    await _process.exitCode.timeout(const Duration(seconds: 30), onTimeout: () {
      _process.kill(ProcessSignal.sigkill);
      return -1;
    });
  }
}

/// Keysyms the scenario sends.
abstract final class Keysym {
  static const int c = 0x63;
  static const int f4 = 0xFFC1;
  static const int escape = 0xFF1B;
}

/// A client's JSON stdout lines, as the scenario reads them.
class JsonEventLog {
  JsonEventLog(Process process) {
    process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('{')) return;
      try {
        events.add(Map<String, dynamic>.from(jsonDecode(trimmed) as Map));
      } on FormatException {
        // Not one of ours.
      }
    });
  }

  final List<Map<String, dynamic>> events = [];

  int get mark => events.length;

  List<Map<String, dynamic>> since(int index, [String? kind]) =>
      [for (final e in events.skip(index)) if (kind == null || e['ev'] == kind) e];

  Future<Map<String, dynamic>> waitFor(String kind,
      {int since = 0, Duration timeout = const Duration(seconds: 15), bool Function(Map<String, dynamic>)? where}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      for (final e in this.since(since, kind)) {
        if (where == null || where(e)) return e;
      }
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    throw StateError('no "$kind" event within $timeout; last events: ${this.since(since).reversed.take(8).toList()}');
  }
}
