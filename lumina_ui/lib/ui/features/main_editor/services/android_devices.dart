import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumina_core/lumina_core.dart';

import 'package:lumina_ui/ui/features/main_editor/services/android_sdk.dart';

/// Starts a child process for Play on Device (adb, the emulator, flutter).
/// Tests pass one that records the command lines.
typedef AndroidProcessStarter = Future<Process> Function(String executable, List<String> arguments,
    {String? workingDirectory, Map<String, String>? environment});

/// The real starter: `flutter` is a `.bat` on Windows, found only through
/// the shell; adb and the emulator are run directly.
Future<Process> defaultAndroidProcessStarter(String executable, List<String> arguments,
        {String? workingDirectory, Map<String, String>? environment}) =>
    Process.start(executable, arguments,
        workingDirectory: workingDirectory,
        environment: environment,
        runInShell: Platform.isWindows && !executable.toLowerCase().endsWith('.exe'));

/// What a short command printed and how it ended.
typedef AndroidCommandResult = ({int exitCode, String stdout, String stderr});

/// Runs [executable] to completion through [starter]; a command still running
/// after [timeout] is killed and reported with exit code -1.
Future<AndroidCommandResult> runAndroidCommand(AndroidProcessStarter starter, String executable, List<String> arguments,
    {Duration timeout = const Duration(seconds: 15), String? workingDirectory}) async {
  final Process process;
  try {
    process = await starter(executable, arguments, workingDirectory: workingDirectory);
  } on Object catch (e) {
    return (exitCode: -1, stdout: '', stderr: '$e');
  }
  final out = process.stdout.transform(const Utf8Decoder(allowMalformed: true)).join();
  final err = process.stderr.transform(const Utf8Decoder(allowMalformed: true)).join();
  final code = await process.exitCode.timeout(timeout, onTimeout: () {
    process.kill(ProcessSignal.sigkill);
    return -1;
  });
  return (exitCode: code, stdout: await out, stderr: await err);
}

/// How a device answers adb.
enum AndroidDeviceState {
  /// Ready (`device`).
  online,

  /// Connected but not answering yet (`offline`; an emulator still booting).
  offline,

  /// The USB debugging prompt on the device was not accepted (`unauthorized`).
  unauthorized,

  /// The host may not open the USB device (`no permissions`, Linux udev).
  noPermissions,

  /// An emulator (AVD) that is not running.
  stopped,

  /// Anything else adb reports (`bootloader`, `recovery`, `sideload`, …).
  other,
}

/// A physical device or an emulator.
enum AndroidDeviceKind { physical, emulator }

/// One line of `adb devices -l`.
class AdbDeviceEntry {
  final String serial;
  final AndroidDeviceState state;

  /// adb's raw state word(s) (`device`, `offline`, `unauthorized`, …).
  final String rawState;

  /// The `key:value` pairs (`model`, `product`, `device`, `transport_id`, `usb`).
  final Map<String, String> properties;

  const AdbDeviceEntry({required this.serial, required this.state, required this.rawState, this.properties = const {}});

  bool get isEmulator => serial.startsWith('emulator-');

  /// `adb devices -l` output → its device lines (the header, daemon notices
  /// and blank lines skipped).
  static List<AdbDeviceEntry> parseList(String output) {
    final entries = <AdbDeviceEntry>[];
    for (final raw in const LineSplitter().convert(output)) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('*') || line.startsWith('List of devices')) continue;
      final tokens = line.split(RegExp(r'\s+'));
      if (tokens.length < 2) continue;
      final serial = tokens[0];
      var rest = tokens.sublist(1);
      String rawState;
      AndroidDeviceState state;
      if (rest.length >= 2 && rest[0] == 'no' && rest[1].startsWith('permissions')) {
        rawState = 'no permissions';
        state = AndroidDeviceState.noPermissions;
        // "no permissions (…); see [http://…]" — the reason runs up to the
        // first key:value pair.
        final firstPair = rest.indexWhere((t) => RegExp(r'^[a-z_]+:').hasMatch(t) && !t.startsWith('http'));
        rest = firstPair < 0 ? const [] : rest.sublist(firstPair);
      } else {
        rawState = rest[0];
        state = switch (rawState) {
          'device' => AndroidDeviceState.online,
          'offline' => AndroidDeviceState.offline,
          'unauthorized' => AndroidDeviceState.unauthorized,
          _ => AndroidDeviceState.other,
        };
        rest = rest.sublist(1);
      }
      final props = <String, String>{};
      for (final t in rest) {
        final i = t.indexOf(':');
        if (i > 0) props[t.substring(0, i)] = t.substring(i + 1);
      }
      entries.add(AdbDeviceEntry(serial: serial, state: state, rawState: rawState, properties: props));
    }
    return entries;
  }
}

/// `adb shell getprop` (every `[key]: [value]` line) → a map.
Map<String, String> parseGetprop(String output) {
  final props = <String, String>{};
  final re = RegExp(r'^\[([^\]]+)\]:\s*\[(.*)\]\s*$');
  for (final line in const LineSplitter().convert(output)) {
    final m = re.firstMatch(line.trim());
    if (m != null) props[m.group(1)!] = m.group(2)!;
  }
  return props;
}

/// `emulator -list-avds` → the AVD names (the emulator's own INFO / WARNING
/// lines skipped: an AVD name has no spaces).
List<String> parseAvdList(String output) => [
      for (final raw in const LineSplitter().convert(output))
        if (RegExp(r'^[A-Za-z0-9._\-]+$').hasMatch(raw.trim())) raw.trim(),
    ];

/// An AVD `key=value` file (`<name>.ini`, `config.ini`) → a map.
Map<String, String> parseIni(String text) {
  final map = <String, String>{};
  for (final line in const LineSplitter().convert(text)) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith('#') || t.startsWith(';')) continue;
    final i = t.indexOf('=');
    if (i > 0) map[t.substring(0, i).trim()] = t.substring(i + 1).trim();
  }
  return map;
}

/// An Android release: its marketing version and the codename Android
/// Studio shows (`Android 10.0 ("Q")`).
typedef AndroidRelease = ({String version, String codename});

/// API level → release, as Android Studio names them.
const Map<int, AndroidRelease> androidReleases = {
  21: (version: '5.0', codename: 'Lollipop'),
  22: (version: '5.1', codename: 'Lollipop'),
  23: (version: '6.0', codename: 'Marshmallow'),
  24: (version: '7.0', codename: 'Nougat'),
  25: (version: '7.1.1', codename: 'Nougat'),
  26: (version: '8.0', codename: 'Oreo'),
  27: (version: '8.1', codename: 'Oreo'),
  28: (version: '9.0', codename: 'Pie'),
  29: (version: '10.0', codename: 'Q'),
  30: (version: '11.0', codename: 'R'),
  31: (version: '12.0', codename: 'S'),
  32: (version: '12L', codename: 'Sv2'),
  33: (version: '13.0', codename: 'Tiramisu'),
  34: (version: '14.0', codename: 'UpsideDownCake'),
  35: (version: '15.0', codename: 'VanillaIceCream'),
  36: (version: '16.0', codename: 'Baklava'),
  37: (version: '17.0', codename: 'CinnamonBun'),
};

/// The release for [apiLevel]; for a level the table does not know, the
/// device's own [release] (`ro.build.version.release`) and [codename]
/// (`ro.build.version.codename`, `REL` meaning none).
AndroidRelease androidReleaseFor(int? apiLevel, {String? release, String? codename}) {
  final known = apiLevel == null ? null : androidReleases[apiLevel];
  if (known != null) return known;
  var version = (release ?? '').trim();
  if (version.isNotEmpty && !version.contains('.') && int.tryParse(version) != null) version = '$version.0';
  final name = (codename ?? '').trim();
  return (
    version: version.isEmpty ? (apiLevel == null ? '?' : 'API $apiLevel') : version,
    codename: name.isEmpty || name == 'REL' ? '' : name,
  );
}

/// The short ABI Android Studio shows (`arm64-v8a` → `arm64`).
String shortAbi(String abi) => switch (abi) {
      'arm64-v8a' => 'arm64',
      'armeabi-v7a' || 'armeabi' => 'arm',
      _ => abi,
    };

/// The `flutter build apk --target-platform` for [abi].
String? flutterTargetPlatformFor(String abi) => switch (abi) {
      'arm64-v8a' => 'android-arm64',
      'armeabi-v7a' || 'armeabi' => 'android-arm',
      'x86_64' => 'android-x64',
      _ => null,
    };

/// An AVD read from `<avdHome>/<name>.ini` and its `config.ini`.
class AvdInfo {
  final String name;
  final String displayName;
  final int? apiLevel;
  final String abi;

  const AvdInfo({required this.name, required this.displayName, required this.apiLevel, required this.abi});

  /// The AVD [name] under [avdHome]; its folder is the `.ini`'s `path` when
  /// that exists, else `path.rel`, else `<name>.avd` beside it. Null when
  /// neither the `.ini` nor the folder exists.
  static AvdInfo? read(String avdHome, String name) {
    final ini = File('$avdHome/$name.ini');
    final pointer = ini.existsSync() ? parseIni(ini.readAsStringSync()) : const <String, String>{};
    final candidates = [
      ?pointer['path'],
      if (pointer['path.rel'] != null) '$avdHome/${pointer['path.rel']!.replaceAll('\\', '/').split('/').last}',
      '$avdHome/$name.avd',
    ];
    Map<String, String>? config;
    for (final dir in candidates) {
      final file = File('$dir/config.ini');
      if (file.existsSync()) {
        config = parseIni(file.readAsStringSync());
        break;
      }
    }
    if (config == null && pointer.isEmpty) return null;
    config ??= const {};
    final target = config['target'] ?? pointer['target'] ?? config['image.sysdir.1'] ?? '';
    final api = RegExp(r'android-(\d+)').firstMatch(target)?.group(1);
    return AvdInfo(
      name: name,
      displayName: (config['avd.ini.displayname'] ?? '').isNotEmpty ? config['avd.ini.displayname']! : name.replaceAll('_', ' '),
      apiLevel: api == null ? null : int.parse(api),
      abi: config['abi.type'] ?? config['hw.cpu.arch'] ?? '',
    );
  }
}

/// A device or emulator Play on Device can run the game on.
class AndroidDevice {
  final AndroidDeviceKind kind;
  final AndroidDeviceState state;

  /// adb's serial; null for an emulator that is not running.
  final String? serial;

  /// The AVD, for an emulator.
  final String? avdName;

  /// The name shown (`Xiaomi MI 8 Lite`, `Medium Phone API 37.0`).
  final String name;
  final int? apiLevel;
  final AndroidRelease release;

  /// The primary ABI (`arm64-v8a`, `x86_64`).
  final String abi;

  const AndroidDevice({
    required this.kind,
    required this.state,
    required this.name,
    required this.release,
    required this.abi,
    this.serial,
    this.avdName,
    this.apiLevel,
  });

  /// Stable across runs and reboots: `avd:<name>` for an emulator, else
  /// `serial:<serial>`.
  String get id => avdName != null ? 'avd:$avdName' : 'serial:$serial';

  bool get isEmulator => kind == AndroidDeviceKind.emulator;

  /// Running and answering adb.
  bool get isOnline => state == AndroidDeviceState.online;

  /// Play on Device can be chosen: online, or an emulator to start.
  bool get canRun => isOnline || (isEmulator && state == AndroidDeviceState.stopped && avdName != null);

  /// `Android 10.0 ("Q") | arm64`.
  String get description {
    final parts = <String>[
      'Android ${release.version}${release.codename.isEmpty ? '' : ' ("${release.codename}")'}',
      if (abi.isNotEmpty) shortAbi(abi),
    ];
    return parts.join(' | ');
  }

  /// What to do when it cannot be chosen, or null.
  String? get hint => switch (state) {
        AndroidDeviceState.unauthorized => 'Unauthorized: accept the "Allow USB debugging?" prompt on the device, then Refresh.',
        AndroidDeviceState.offline => isEmulator ? 'Offline: the emulator is still booting; Refresh in a moment.' : 'Offline: reconnect the cable or restart adb, then Refresh.',
        AndroidDeviceState.noPermissions => 'No permissions: the host may not open this USB device (udev rules), then Refresh.',
        AndroidDeviceState.other => 'Not ready for adb; Refresh once it has booted.',
        _ => null,
      };

  AndroidDevice copyWith({AndroidDeviceState? state, String? serial}) => AndroidDevice(
        kind: kind,
        state: state ?? this.state,
        name: name,
        release: release,
        abi: abi,
        serial: serial ?? this.serial,
        avdName: avdName,
        apiLevel: apiLevel,
      );

  @override
  String toString() => 'AndroidDevice($id, $name, ${state.name}, $description)';
}

/// Lists the devices adb sees and the AVDs the emulator knows, through
/// [starter].
class AndroidDeviceProbe {
  final AndroidSdk sdk;
  final AndroidProcessStarter starter;
  final Duration commandTimeout;

  AndroidDeviceProbe(this.sdk, {AndroidProcessStarter? starter, this.commandTimeout = const Duration(seconds: 15)})
      : starter = starter ?? defaultAndroidProcessStarter;

  Future<AndroidCommandResult> adb(List<String> args, {Duration? timeout}) =>
      runAndroidCommand(starter, sdk.adbPath, args, timeout: timeout ?? commandTimeout);

  /// `adb devices -l`.
  Future<List<AdbDeviceEntry>> adbDevices() async {
    final r = await adb(const ['devices', '-l']);
    if (r.exitCode != 0) throw ProcessException(sdk.adbPath, const ['devices', '-l'], r.stderr.trim(), r.exitCode);
    return AdbDeviceEntry.parseList(r.stdout);
  }

  /// The AVD a running emulator was started from (`adb emu avd name`, which
  /// answers while the emulator is still offline).
  Future<String?> emulatorAvdName(String serial) async {
    final r = await adb(['-s', serial, 'emu', 'avd', 'name']);
    if (r.exitCode != 0) return null;
    final first = const LineSplitter().convert(r.stdout).map((l) => l.trim()).firstWhere((l) => l.isNotEmpty, orElse: () => '');
    return first.isEmpty || first == 'OK' || first.startsWith('KO') ? null : first;
  }

  /// `adb -s <serial> shell getprop`.
  Future<Map<String, String>> getprop(String serial) async {
    final r = await adb(['-s', serial, 'shell', 'getprop']);
    return r.exitCode == 0 ? parseGetprop(r.stdout) : const {};
  }

  /// The AVD names: `emulator -list-avds`, else the `.ini` files of the AVD
  /// folder.
  Future<List<String>> avdNames() async {
    final emulator = sdk.emulatorPath;
    if (emulator != null) {
      final r = await runAndroidCommand(starter, emulator, const ['-list-avds'], timeout: commandTimeout);
      if (r.exitCode == 0) return parseAvdList(r.stdout);
    }
    final dir = Directory(sdk.avdHome);
    if (!dir.existsSync()) return const [];
    return [
      for (final f in dir.listSync().whereType<File>())
        if (f.path.endsWith('.ini')) f.uri.pathSegments.last.replaceAll(RegExp(r'\.ini$'), ''),
    ]..sort();
  }

  /// Connected devices first (physical, by name), then the emulators: every
  /// AVD (running ones carrying their serial and adb state) and any running
  /// emulator without a known AVD.
  Future<List<AndroidDevice>> list() async {
    final results = await Future.wait([adbDevices(), avdNames()]);
    final entries = results[0] as List<AdbDeviceEntry>;
    final avds = results[1] as List<String>;

    final physical = <AndroidDevice>[];
    final runningEmulators = <String, AndroidDevice>{};
    final looseEmulators = <AndroidDevice>[];
    await Future.wait(entries.map((e) async {
      final props = e.state == AndroidDeviceState.online ? await getprop(e.serial) : const <String, String>{};
      final api = int.tryParse(props['ro.build.version.sdk'] ?? '');
      final release = androidReleaseFor(api, release: props['ro.build.version.release'], codename: props['ro.build.version.codename']);
      final abi = props['ro.product.cpu.abi'] ?? '';
      if (e.isEmulator) {
        final avd = await emulatorAvdName(e.serial) ?? props['ro.boot.qemu.avd_name'] ?? props['ro.kernel.qemu.avd_name'];
        final info = avd == null ? null : AvdInfo.read(sdk.avdHome, avd);
        final device = AndroidDevice(
          kind: AndroidDeviceKind.emulator,
          state: e.state,
          serial: e.serial,
          avdName: avd,
          name: info?.displayName ?? avd?.replaceAll('_', ' ') ?? props['ro.product.model'] ?? e.serial,
          apiLevel: api ?? info?.apiLevel,
          release: api != null ? release : androidReleaseFor(info?.apiLevel),
          abi: abi.isNotEmpty ? abi : (info?.abi ?? ''),
        );
        if (avd != null) {
          runningEmulators[avd] = device;
        } else {
          looseEmulators.add(device);
        }
        return;
      }
      final model = props['ro.product.model'] ?? e.properties['model']?.replaceAll('_', ' ') ?? e.serial;
      final maker = props['ro.product.manufacturer'] ?? '';
      physical.add(AndroidDevice(
        kind: AndroidDeviceKind.physical,
        state: e.state,
        serial: e.serial,
        name: maker.isEmpty || model.toLowerCase().startsWith(maker.toLowerCase()) ? model : '$maker $model',
        apiLevel: api,
        release: release,
        abi: abi,
      ));
    }));
    physical.sort((a, b) => a.name.compareTo(b.name));

    final emulators = <AndroidDevice>[];
    for (final name in avds) {
      final running = runningEmulators.remove(name);
      if (running != null) {
        emulators.add(running);
        continue;
      }
      final info = AvdInfo.read(sdk.avdHome, name);
      emulators.add(AndroidDevice(
        kind: AndroidDeviceKind.emulator,
        state: AndroidDeviceState.stopped,
        avdName: name,
        name: info?.displayName ?? name.replaceAll('_', ' '),
        apiLevel: info?.apiLevel,
        release: androidReleaseFor(info?.apiLevel),
        abi: info?.abi ?? '',
      ));
    }
    emulators
      ..addAll(runningEmulators.values)
      ..addAll(looseEmulators);
    return [...physical, ...emulators];
  }
}

/// The device list Play on Device shows: refreshed every time the menu opens
/// (without blocking it), and the device chosen last, kept per user in
/// `play_on_device.json` in the editor's config directory.
class AndroidDeviceList extends ChangeNotifier {
  final AndroidDeviceProbe? probe;
  final Directory? configDir;

  AndroidDeviceList(this.probe, {this.configDir}) {
    try {
      final decoded = ConfigJsonFile(_file).read();
      final last = decoded is Map ? decoded['lastDevice'] : null;
      if (last is String && last.isNotEmpty) _lastDeviceId = last;
    } on Object {
      // Unreadable: nothing remembered.
    }
  }

  static const String fileName = 'play_on_device.json';

  File get _file => LuminaConfigDir.file(fileName, explicit: configDir);

  /// Whether an Android SDK was found (the menu shows the section only then).
  bool get available => probe != null;

  List<AndroidDevice> _devices = const [];
  bool _loading = false;
  bool _loadedOnce = false;
  String? _error;
  String? _lastDeviceId;
  Future<void>? _pending;
  bool _disposed = false;

  List<AndroidDevice> get devices => _devices;
  List<AndroidDevice> get connected => [for (final d in _devices) if (!d.isEmulator) d];
  List<AndroidDevice> get emulators => [for (final d in _devices) if (d.isEmulator) d];
  bool get loading => _loading;

  /// Whether a listing has finished at least once.
  bool get loadedOnce => _loadedOnce;

  /// Why the last listing failed, or null.
  String? get error => _error;

  /// [AndroidDevice.id] of the device chosen last.
  String? get lastDeviceId => _lastDeviceId;

  set lastDeviceId(String? id) {
    if (id == _lastDeviceId) return;
    _lastDeviceId = id;
    try {
      ConfigJsonFile(_file).write({'lastDevice': id});
    } on Object catch (e) {
      debugPrint('[PlayOnDevice] could not remember the device: $e');
    }
    _notify();
  }

  /// Lists the devices again; a listing already running is shared.
  Future<void> refresh() {
    final probe = this.probe;
    if (probe == null) return Future.value();
    return _pending ??= () async {
      _loading = true;
      _notify();
      try {
        _devices = List.unmodifiable(await probe.list());
        _error = null;
      } on Object catch (e) {
        _error = '$e';
      } finally {
        _loading = false;
        _loadedOnce = true;
        _pending = null;
        _notify();
      }
    }();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
