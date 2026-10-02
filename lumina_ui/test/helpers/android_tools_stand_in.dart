import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:lumina_ui/ui/features/main_editor/services/android_devices.dart';

/// Real child processes standing in for `adb`, `emulator` and `flutter`
/// (Play on Device must never touch a real phone from a test). One compiled
/// program answers as the tool its executable path ends with, from files in
/// a state folder:
///
/// - `adb devices -l` → `devices.txt` (+ `devices_booted.txt` once an
///   emulator was started);
/// - `adb -s <s> shell getprop` → `getprop_<s>.txt` (exit 1 "device offline"
///   when missing); `getprop sys.boot_completed` → 1 once booted;
/// - `adb -s <s> emu avd name` → `avdname_<s>.txt`;
/// - `install` → Success; `monkey` → Events injected; `pidof` → 4242 until
///   `am force-stop` writes `stopped`; `logcat` prints a game line and waits;
/// - `emulator -list-avds` → `list_avds.txt`; `emulator -avd <n>` writes
///   `booted` and waits;
/// - `flutter build apk …` writes `build/app/outputs/flutter-apk/app-debug.apk`
///   under its working directory.
///
/// Every command line is appended to `commands.log` (tool name, then the
/// arguments), every pid to `pids.log`.
class AndroidToolsStandIn {
  final Directory state;
  final String executable;

  AndroidToolsStandIn._(this.state, this.executable);

  static String? _compiled;

  /// Compiles the stand-in once per test process (cached by its source in
  /// the system temp folder) and sets up [state].
  static Future<AndroidToolsStandIn> create(Directory state) async {
    state.createSync(recursive: true);
    return AndroidToolsStandIn._(state, _compiled ??= await _compile());
  }

  static Future<String> _compile() async {
    final digest = sha1.convert(utf8.encode(_source)).toString().substring(0, 12);
    final dir = Directory('${Directory.systemTemp.path}/lumina_android_stand_in_$digest')..createSync(recursive: true);
    final exe = File('${dir.path}/stand_in${Platform.isWindows ? '.exe' : ''}');
    if (exe.existsSync()) return exe.path;
    final src = File('${dir.path}/stand_in.dart')..writeAsStringSync(_source);
    final r = await Process.run(dartExecutable(), ['compile', 'exe', src.path, '-o', exe.path]);
    if (r.exitCode != 0) throw StateError('could not compile the stand-in: ${r.stdout}\n${r.stderr}');
    return exe.path;
  }

  /// The starter Play on Device uses: records, then runs the stand-in as the
  /// tool named by [executable]'s last path segment.
  AndroidProcessStarter get starter => (String exe, List<String> args, {String? workingDirectory, Map<String, String>? environment}) async {
        final tool = exe.replaceAll('\\', '/').split('/').last.replaceAll('.exe', '').replaceAll('.bat', '');
        File('${state.path}/commands.log').writeAsStringSync('${[tool, ...args].join(' ')}\n', mode: FileMode.append);
        final process = await Process.start(executable, [state.path, tool, ...args], workingDirectory: workingDirectory);
        File('${state.path}/pids.log').writeAsStringSync('${process.pid}\n', mode: FileMode.append);
        return process;
      };

  /// The command lines run so far, oldest first.
  List<String> get commands {
    final log = File('${state.path}/commands.log');
    return log.existsSync() ? log.readAsLinesSync().where((l) => l.isNotEmpty).toList() : const [];
  }

  /// Kills every stand-in still running (the waiting emulator / logcat).
  void killAll() {
    final log = File('${state.path}/pids.log');
    if (!log.existsSync()) return;
    for (final line in log.readAsLinesSync()) {
      final pid = int.tryParse(line.trim());
      if (pid != null) Process.killPid(pid, ProcessSignal.sigkill);
    }
  }

  void write(String name, String content) => File('${state.path}/$name').writeAsStringSync(content);
}

/// The SDK's own dart binary (`flutter test` runs flutter_tester).
String dartExecutable() {
  final sdkDart = Platform.isWindows ? 'bin/cache/dart-sdk/bin/dart.exe' : 'bin/dart';
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && File('$root/$sdkDart').existsSync()) return '$root/$sdkDart';
  final exe = Platform.resolvedExecutable.replaceAll(r'\', '/');
  final idx = exe.indexOf('/bin/cache/');
  if (idx > 0) {
    final candidate = '${exe.substring(0, idx)}/$sdkDart';
    if (File(candidate).existsSync()) return candidate;
  }
  return 'dart';
}

const String _source = r'''
import 'dart:io';

Future<void> main(List<String> argv) async {
  final state = argv[0];
  final tool = argv[1];
  final args = argv.sublist(2);
  File f(String name) => File('$state/$name');
  String read(String name) => f(name).existsSync() ? f(name).readAsStringSync() : '';

  if (tool == 'flutter') {
    if (args.length >= 2 && args[0] == 'build' && args[1] == 'apk') {
      stdout.writeln('Running Gradle task assembleDebug...');
      if (f('build_fails').existsSync()) {
        stderr.writeln('FAILURE: Build failed with an exception.');
        exit(1);
      }
      final out = Directory('build/app/outputs/flutter-apk')..createSync(recursive: true);
      File('${out.path}/app-debug.apk').writeAsStringSync('apk');
      stdout.writeln('Built build/app/outputs/flutter-apk/app-debug.apk');
      exit(0);
    }
    exit(64);
  }

  if (tool == 'emulator') {
    if (args.isNotEmpty && args[0] == '-list-avds') {
      stdout.write(read('list_avds.txt'));
      exit(0);
    }
    if (args.length >= 2 && args[0] == '-avd') {
      f('booted').writeAsStringSync(args[1]);
      stdout.writeln('INFO | Android emulator version (stand-in)');
      await Future<void>.delayed(const Duration(seconds: 60));
      exit(0);
    }
    exit(64);
  }

  // adb
  if (args.length >= 2 && args[0] == 'devices') {
    stdout.write(read('devices.txt'));
    if (f('booted').existsSync()) stdout.write(read('devices_booted.txt'));
    stdout.writeln();
    exit(0);
  }
  if (args.length < 3 || args[0] != '-s') exit(64);
  final serial = args[1];
  final cmd = args.sublist(2);
  if (cmd.length == 3 && cmd[0] == 'emu' && cmd[1] == 'avd' && cmd[2] == 'name') {
    final name = read('avdname_$serial.txt');
    if (name.isEmpty) {
      stderr.writeln('error: no emulator detected');
      exit(1);
    }
    stdout.write(name);
    exit(0);
  }
  if (cmd[0] == 'shell' && cmd.length >= 2 && cmd[1] == 'getprop') {
    final props = read('getprop_$serial.txt');
    if (props.isEmpty) {
      stderr.writeln('adb.exe: device offline');
      exit(1);
    }
    if (cmd.length == 3) {
      final m = RegExp('^\\[${RegExp.escape(cmd[2])}\\]: \\[(.*)\\]', multiLine: true).firstMatch(props);
      stdout.writeln(m?.group(1) ?? '');
      exit(0);
    }
    stdout.write(props);
    exit(0);
  }
  if (cmd[0] == 'install') {
    stdout.writeln('Performing Streamed Install');
    stdout.writeln('Success');
    exit(0);
  }
  if (cmd[0] == 'shell' && cmd.length >= 2 && cmd[1] == 'monkey') {
    stdout.writeln('  bash arg: -p');
    stdout.writeln('Events injected: 1');
    exit(0);
  }
  if (cmd[0] == 'shell' && cmd.length >= 2 && cmd[1] == 'pidof') {
    if (f('stopped').existsSync()) exit(1);
    stdout.writeln('4242');
    exit(0);
  }
  if (cmd[0] == 'shell' && cmd.length >= 4 && cmd[1] == 'am' && cmd[2] == 'force-stop') {
    f('stopped').writeAsStringSync(cmd[3]);
    exit(0);
  }
  if (cmd[0] == 'logcat') {
    stdout.writeln('I/flutter ( 4242): Lumina game started');
    await Future<void>.delayed(const Duration(seconds: 60));
    exit(0);
  }
  exit(64);
}
''';
