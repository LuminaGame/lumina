import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/features/sub_editors/services/android_packaging_hooks.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/build_pipeline_service.dart' show HostBuildTargets;
import 'package:lumina_ui/ui/features/main_editor/services/android_devices.dart';
import 'package:lumina_ui/ui/features/main_editor/services/android_sdk.dart';

/// Where a Play on Device run is.
enum AndroidRunState { idle, booting, building, installing, running }

/// Play on Device: runs the project on an Android device or emulator.
///
/// 1. An emulator that is not running is started (`emulator -avd <name>`)
///    and waited for: its serial appears in `adb devices`, then
///    `sys.boot_completed` is 1.
/// 2. `flutter build apk --debug --target-platform <the device's ABI>`.
/// 3. `adb -s <serial> install -r build/app/outputs/flutter-apk/app-debug.apk`.
/// 4. `adb -s <serial> shell monkey -p <applicationId> -c android.intent.category.LAUNCHER 1`;
///    a Meta Quest: `adb -s <serial> shell am start -n <applicationId>/.MainActivity`, after
///    [prepareProject] composed the project's Meta Quest profile (manifest,
///    Gradle settings, the enabled plugins' runtime modules).
/// 5. The game's log (`adb logcat --pid`) streams into the Output Log until
///    the app ends or [stop] force-stops it.
/// 6. While it runs, [captureScreenshot] (`adb exec-out screencap -p`) and
///    [recordVideo] (`adb shell screenrecord --time-limit`, then `adb pull`)
///    save into the project's `Saved/Captures/`.
///
/// Every child process goes through [starter], so a test records the
/// commands instead of building or touching a device.
class AndroidDeviceRunner extends ChangeNotifier {
  final String projectDir;
  final AndroidSdk sdk;
  final AndroidProcessStarter starter;
  final String flutterExecutable;

  /// How often the boot wait and the running game are checked.
  final Duration pollInterval;

  /// How long an emulator may take to boot.
  final Duration bootTimeout;

  /// Prepares the project's Android app for a device (default
  /// [prepareAndroidApp]); returns false to stop the run.
  final Future<bool> Function(String projectDir, AndroidDevice device, void Function(String message, String level) log)? preparer;

  final EngineLoggerService _logger = EngineLoggerService();
  static const String _source = 'Play on Device';

  AndroidDeviceRunner(
    this.projectDir,
    this.sdk, {
    AndroidProcessStarter? starter,
    this.flutterExecutable = 'flutter',
    this.pollInterval = const Duration(seconds: 2),
    this.bootTimeout = const Duration(minutes: 5),
    this.preparer,
  }) : starter = starter ?? defaultAndroidProcessStarter;

  /// Composes the project's Android app for [device]: a Meta Quest gets the
  /// project's Meta Quest profile (the saved settings when the project has
  /// chosen it, else the profile's defaults for this run); any device gets
  /// the manifest the enabled plugins contribute and their runtime modules.
  /// A folder without a `.lmproject` is left as it is.
  static Future<bool> prepareAndroidApp(String projectDir, AndroidDevice device, void Function(String, String) log) async {
    File? manifest;
    await for (final e in Directory(projectDir).list()) {
      if (e is File && e.path.endsWith('.lmproject')) manifest = e;
    }
    if (manifest == null) return true;
    final loaded = await ProjectRepository().loadProject(manifest.path);
    if (loaded == null) return true;
    var project = loaded;
    if (device.isQuest && !project.packaging.android.isQuest) {
      project = project.copyWith(packaging: project.packaging.copyWith(android: project.packaging.android.withXrProfile('quest')));
      log('${device.title}: building the Meta Quest profile for this run (Project Settings > Packaging > Android keeps it).', 'info');
    }
    try {
      final plugins = await AndroidPackagingHooks.enabledPluginsOf(projectDir, project);
      final prep = await AndroidPackaging.prepare(projectDir, project, plugins);
      final modules = prep.runtimeModules.map((d) => d.package).join(', ');
      log('Android app: ${prep.applicationId}; manifest ${prep.manifest.summary.join(', ')}'
          '${modules.isEmpty ? '' : '; plugin runtime modules $modules'}', 'info');
      return true;
    } on Object catch (e) {
      log('The Android app could not be prepared: $e', 'error');
      return false;
    }
  }

  /// Prepares the project for [device] ([preparer]); Play on Device runs it
  /// before the game code is generated, so `main()` registers the plugins'
  /// runtime modules.
  Future<bool> prepareProject(AndroidDevice device) => (preparer ?? prepareAndroidApp)(projectDir, device, _log);

  AndroidRunState _state = AndroidRunState.idle;
  AndroidDevice? _device;
  String? _serial;
  String? _applicationId;
  Process? _current;
  Process? _startedEmulator;
  Process? _logcat;
  Timer? _watch;
  bool _stopRequested = false;
  bool _disposed = false;

  AndroidRunState get state => _state;
  bool get isActive => _state != AndroidRunState.idle;

  /// The device of the current (or last) run.
  AndroidDevice? get device => _device;

  /// The adb serial the game runs on.
  String? get serial => _serial;

  /// The app's id (`applicationId` of `android/app/build.gradle[.kts]`).
  String? get applicationId => _applicationId;

  /// Lines the run printed (also in the Output Log).
  final List<String> output = [];

  /// `flutter build apk`'s debug APK.
  String get apkPath => '$projectDir/build/app/outputs/flutter-apk/app-debug.apk';

  /// The `applicationId` of the project's Android app, or null.
  static String? readApplicationId(String projectDir) {
    for (final name in const ['build.gradle.kts', 'build.gradle']) {
      final file = File('$projectDir/android/app/$name');
      if (!file.existsSync()) continue;
      final m = RegExp(r'''applicationId\s*=?\s*["']([^"']+)["']''').firstMatch(file.readAsStringSync());
      if (m != null) return m.group(1);
    }
    return null;
  }

  /// Runs the project on [device]. Returns whether the game was launched.
  Future<bool> start(AndroidDevice device) async {
    if (isActive) return false;
    _stopRequested = false;
    _device = device;
    _serial = device.serial;
    output.clear();
    if (!device.canRun) {
      _log('${device.name} cannot run the game now: ${device.hint ?? device.state.name}', 'error');
      return false;
    }
    final appId = readApplicationId(projectDir);
    if (!Directory('$projectDir/android').existsSync() || appId == null) {
      _log('Play on Device needs the project\'s Android app (android/app/build.gradle.kts with an applicationId); '
          'run `flutter create --platforms=android .` in $projectDir.', 'error');
      return false;
    }
    _applicationId = appId;
    try {
      if (!device.isOnline) {
        _setState(AndroidRunState.booting);
        final serial = await _bootEmulator(device.avdName!);
        if (serial == null) return _fail();
        _serial = serial;
      }
      final serial = _serial!;

      _setState(AndroidRunState.building);
      if (!await _build(device)) return _fail();

      _setState(AndroidRunState.installing);
      _log('Installing on ${device.name} ($serial)…', 'info');
      final install = await _run(sdk.adbPath, ['-s', serial, 'install', '-r', apkPath], timeout: const Duration(minutes: 5));
      if (_stopRequested) return _fail(stopped: true);
      if (install.exitCode != 0 || !install.stdout.contains('Success')) {
        _log('adb install failed (exit ${install.exitCode}): ${(install.stderr.isEmpty ? install.stdout : install.stderr).trim()}', 'error');
        return _fail();
      }

      // A headset starts the activity itself (immersive); a phone through
      // the launcher intent.
      final launch = device.isQuest
          ? await _run(sdk.adbPath, ['-s', serial, 'shell', 'am', 'start', '-n', '$appId/.MainActivity'])
          : await _run(sdk.adbPath, ['-s', serial, 'shell', 'monkey', '-p', appId, '-c', 'android.intent.category.LAUNCHER', '1']);
      if (_stopRequested) return _fail(stopped: true);
      if (launch.exitCode != 0 || launch.stdout.contains('No activities found') || '${launch.stdout}${launch.stderr}'.contains('Error:')) {
        _log('Could not launch $appId on $serial: ${(launch.stdout + launch.stderr).trim()}', 'error');
        return _fail();
      }
      final pid = await _pidOf(serial, appId);
      _setState(AndroidRunState.running);
      _log('$appId running on ${device.name}${pid == null ? '' : ' (pid $pid)'}.', 'success');
      if (pid != null) {
        final logcat = await starter(sdk.adbPath, ['-s', serial, 'logcat', '-v', 'brief', '--pid=$pid']);
        _logcat = logcat;
        _pipe(logcat);
      }
      _watch = Timer.periodic(pollInterval, (_) => unawaited(_checkStillRunning(serial, appId)));
      return true;
    } on Object catch (e) {
      _log('Play on Device could not start: $e', 'error');
      return _fail();
    }
  }

  /// Starts the AVD and waits until it has booted; its serial, or null.
  Future<String?> _bootEmulator(String avd) async {
    final emulator = sdk.emulatorPath;
    if (emulator == null) {
      _log('The Android SDK at ${sdk.root} has no emulator; install it from Android Studio\'s SDK Manager.', 'error');
      return null;
    }
    final before = {for (final e in await _adbDevices()) e.serial};
    _log('Starting the emulator $avd…', 'info');
    final process = await starter(emulator, ['-avd', avd]);
    _startedEmulator = process;
    // The emulator prints a lot; drained so its pipes never fill.
    process.stdout.drain<void>();
    process.stderr.drain<void>();
    var exited = false;
    unawaited(process.exitCode.then((_) => exited = true));
    final deadline = DateTime.now().add(bootTimeout);
    String? serial;
    while (DateTime.now().isBefore(deadline)) {
      if (_stopRequested) return null;
      if (exited) {
        _log('The emulator $avd exited before it booted.', 'error');
        return null;
      }
      if (serial == null) {
        for (final e in await _adbDevices()) {
          if (!e.isEmulator) continue;
          if (before.contains(e.serial) && e.state == AndroidDeviceState.online) continue;
          if (await _avdNameOf(e.serial) == avd) {
            serial = e.serial;
            _log('The emulator $avd is $serial; waiting for it to boot…', 'info');
            break;
          }
        }
      }
      if (serial != null) {
        final booted = await _run(sdk.adbPath, ['-s', serial, 'shell', 'getprop', 'sys.boot_completed']);
        if (booted.exitCode == 0 && booted.stdout.trim() == '1') {
          _log('The emulator $avd has booted.', 'success');
          return serial;
        }
      }
      await Future<void>.delayed(pollInterval);
    }
    if (!_stopRequested) _log('The emulator $avd did not boot within ${bootTimeout.inMinutes} minutes.', 'error');
    return null;
  }

  Future<List<AdbDeviceEntry>> _adbDevices() async {
    final r = await _run(sdk.adbPath, const ['devices', '-l']);
    return r.exitCode == 0 ? AdbDeviceEntry.parseList(r.stdout) : const [];
  }

  Future<String?> _avdNameOf(String serial) async {
    final r = await _run(sdk.adbPath, ['-s', serial, 'emu', 'avd', 'name']);
    if (r.exitCode != 0) return null;
    final lines = const LineSplitter().convert(r.stdout).map((l) => l.trim()).where((l) => l.isNotEmpty);
    return lines.isEmpty ? null : lines.first;
  }

  Future<bool> _build(AndroidDevice device) async {
    ProjectRepository.ensurePubspecAssets(projectDir);
    if (ProjectEngineLink.localEngineRoot(luminaPackageDir: ProjectRepository.luminaPackagePath) != null) {
      try {
        ProjectEngineLink.apply(projectDir,
            luminaPackageDir: ProjectRepository.luminaPackagePath, onLog: (m) => _log(m, 'warning'));
      } on Object catch (e) {
        _log('Could not link the project to the local engine: $e', 'warning');
      }
    }
    final engineReason = HostBuildTargets.engineUnsupportedReason('apk');
    if (engineReason != null) _log('The game may not render on the device yet: $engineReason', 'warning');
    final target = flutterTargetPlatformFor(device.abi);
    final args = ['build', 'apk', '--debug', if (target != null) ...['--target-platform', target]];
    _log('flutter ${args.join(' ')}', 'info');
    // Through a space-free alias of the project on Windows (the native-assets
    // hooks cannot compile under a path with a space).
    final build = await starter(flutterExecutable, args, workingDirectory: SpaceFreeBuildDir.of(projectDir));
    _current = build;
    _pipe(build);
    final code = await build.exitCode;
    _current = null;
    if (_stopRequested) {
      _log('Play on Device stopped during the build.', 'warning');
      return false;
    }
    if (code != 0) {
      _log('The Android build failed (exit $code). The build output is above.', 'error');
      return false;
    }
    if (!File(apkPath).existsSync()) {
      _log('The build succeeded but there is no APK at build/app/outputs/flutter-apk/app-debug.apk.', 'error');
      return false;
    }
    return true;
  }

  Future<String?> _pidOf(String serial, String appId) async {
    for (var i = 0; i < 10; i++) {
      final r = await _run(sdk.adbPath, ['-s', serial, 'shell', 'pidof', appId]);
      final pid = r.stdout.trim().split(RegExp(r'\s+')).first;
      if (r.exitCode == 0 && int.tryParse(pid) != null) return pid;
      if (_stopRequested) return null;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return null;
  }

  bool _checking = false;
  Future<void> _checkStillRunning(String serial, String appId) async {
    if (_checking || _state != AndroidRunState.running) return;
    _checking = true;
    try {
      final r = await _run(sdk.adbPath, ['-s', serial, 'shell', 'pidof', appId]);
      if (_state == AndroidRunState.running && r.stdout.trim().isEmpty) {
        _log('$appId is no longer running on ${_device?.name ?? serial}.', 'info');
        _finish();
      }
    } finally {
      _checking = false;
    }
  }

  /// Where captures are saved: `<project>/Saved/Captures`.
  String get capturesDir => '$projectDir/Saved/Captures';

  String _stamp() => DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');

  String get _captureName {
    final model = _device?.model ?? '';
    return model.isEmpty ? 'device' : model.replaceAll(' ', '_');
  }

  /// Saves the device's screen as a PNG (`adb exec-out screencap -p`) into
  /// [capturesDir]; null when no game runs or the capture failed.
  Future<File?> captureScreenshot() async {
    final serial = _serial;
    if (_state != AndroidRunState.running || serial == null) return null;
    final Process process;
    try {
      process = await starter(sdk.adbPath, ['-s', serial, 'exec-out', 'screencap', '-p']);
    } on Object catch (e) {
      _log('Capture failed: $e', 'error');
      return null;
    }
    final bytes = <int>[];
    final out = process.stdout.listen(bytes.addAll).asFuture<void>();
    unawaited(process.stderr.drain<void>());
    final code = await process.exitCode.timeout(const Duration(seconds: 20), onTimeout: () {
      process.kill(ProcessSignal.sigkill);
      return -1;
    });
    await out;
    const png = [0x89, 0x50, 0x4E, 0x47];
    final isPng = bytes.length > 8 && [for (var i = 0; i < 4; i++) bytes[i] == png[i]].every((b) => b);
    if (code != 0 || !isPng) {
      _log('Capture failed (exit $code, ${bytes.length} bytes that are not a PNG).', 'error');
      return null;
    }
    final file = File('$capturesDir/${_captureName}_${_stamp()}.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    _log('Screenshot saved: ${file.path}', 'success');
    return file;
  }

  /// Records [seconds] of the device's screen (`adb shell screenrecord
  /// --time-limit`), pulls it into [capturesDir] and removes it from the
  /// device; null when no game runs or recording failed.
  Future<File?> recordVideo({int seconds = 15}) async {
    final serial = _serial;
    if (_state != AndroidRunState.running || serial == null) return null;
    final name = '${_captureName}_${_stamp()}.mp4';
    final remote = '/sdcard/$name';
    _log('Recording $seconds s on ${_device?.title ?? serial}…', 'info');
    final rec = await _run(sdk.adbPath, ['-s', serial, 'shell', 'screenrecord', '--time-limit', '$seconds', remote],
        timeout: Duration(seconds: seconds + 30));
    if (rec.exitCode != 0) {
      _log('screenrecord failed (exit ${rec.exitCode}): ${(rec.stderr.isEmpty ? rec.stdout : rec.stderr).trim()}', 'error');
      return null;
    }
    final file = File('$capturesDir/$name');
    await file.parent.create(recursive: true);
    final pull = await _run(sdk.adbPath, ['-s', serial, 'pull', remote, file.path], timeout: const Duration(minutes: 2));
    await _run(sdk.adbPath, ['-s', serial, 'shell', 'rm', '-f', remote]);
    if (pull.exitCode != 0 || !await file.exists()) {
      _log('adb pull failed (exit ${pull.exitCode}): ${(pull.stderr.isEmpty ? pull.stdout : pull.stderr).trim()}', 'error');
      return null;
    }
    _log('Video saved: ${file.path}', 'success');
    return file;
  }

  /// Force-stops the game on the device, or cancels the boot / build /
  /// install. An emulator this run started is closed only when the run is
  /// stopped before it booted.
  Future<void> stop() async {
    if (!isActive) return;
    _stopRequested = true;
    final state = _state;
    _current?.kill(ProcessSignal.sigkill);
    if (state == AndroidRunState.booting) {
      _startedEmulator?.kill(ProcessSignal.sigkill);
    }
    final serial = _serial;
    final appId = _applicationId;
    if (state == AndroidRunState.running && serial != null && appId != null) {
      await _run(sdk.adbPath, ['-s', serial, 'shell', 'am', 'force-stop', appId]);
      _log('Stopped $appId on ${_device?.name ?? serial}.', 'info');
      _finish();
    }
  }

  void _finish() {
    _watch?.cancel();
    _watch = null;
    _logcat?.kill(ProcessSignal.sigkill);
    _logcat = null;
    _setState(AndroidRunState.idle);
  }

  bool _fail({bool stopped = false}) {
    if (stopped || _stopRequested) _log('Play on Device stopped.', 'warning');
    _current = null;
    _finish();
    return false;
  }

  Future<AndroidCommandResult> _run(String exe, List<String> args, {Duration timeout = const Duration(seconds: 20)}) async {
    final Process process;
    try {
      process = await starter(exe, args);
    } on Object catch (e) {
      return (exitCode: -1, stdout: '', stderr: '$e');
    }
    _current = process;
    final out = process.stdout.transform(const Utf8Decoder(allowMalformed: true)).join();
    final err = process.stderr.transform(const Utf8Decoder(allowMalformed: true)).join();
    final code = await process.exitCode.timeout(timeout, onTimeout: () {
      process.kill(ProcessSignal.sigkill);
      return -1;
    });
    if (identical(_current, process)) _current = null;
    return (exitCode: code, stdout: await out, stderr: await err);
  }

  void _pipe(Process process) {
    void forward(Stream<List<int>> stream, String level) {
      stream.transform(const Utf8Decoder(allowMalformed: true)).transform(const LineSplitter()).listen((line) {
        if (line.trim().isEmpty) return;
        output.add(line);
        _logger.log(line, level: level, source: _source);
      });
    }

    forward(process.stdout, 'info');
    forward(process.stderr, 'warning');
  }

  void _log(String message, String level) {
    output.add(message);
    _logger.log(message, level: level, source: _source);
  }

  void _setState(AndroidRunState s) {
    _state = s;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _watch?.cancel();
    _current?.kill(ProcessSignal.sigkill);
    _logcat?.kill(ProcessSignal.sigkill);
    super.dispose();
  }
}
