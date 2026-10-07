import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lumina_core/lumina_core.dart';
import 'package:path/path.dart' as p;

/// The recorded real `flutter build windows --release -v` output of a
/// generated project editor host (lumina `test/fixtures/editor_build/`).
List<String> recordedEditorBuildLog() => const LineSplitter().convert(File(p.join(
        LuminaWorkspace.package('lumina'), 'test', 'fixtures', 'editor_build', 'windows_release.log'))
    .readAsStringSync());

/// Replays recorded output line by line as a real [Process] streams it:
/// [hang] keeps it running after the last line until killed.
class ReplayProcess implements Process {
  final List<String> lines;
  final int code;
  final bool hang;
  final _out = StreamController<List<int>>();
  final _exit = Completer<int>();
  bool killed = false;

  ReplayProcess(this.lines, {this.code = 0, this.hang = false}) {
    () async {
      for (final l in lines) {
        if (killed) break;
        _out.add(utf8.encode('$l\n'));
      }
      while (hang && !killed) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await _out.close();
      if (!_exit.isCompleted) _exit.complete(killed ? -1 : code);
    }();
  }

  @override
  Stream<List<int>> get stdout => _out.stream;
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  Future<int> get exitCode => _exit.future;
  @override
  int get pid => 424242;
  @override
  IOSink get stdin => IOSink(StreamController<List<int>>().sink);
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => killed = true;
}
