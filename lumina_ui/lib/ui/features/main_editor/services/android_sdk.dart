import 'dart:convert';
import 'dart:io';

/// An Android SDK on this machine (the one Android Studio installs, or one
/// named by `ANDROID_HOME`): what Play on Device lists devices and
/// emulators with.
class AndroidSdk {
  /// The SDK folder.
  final String root;

  /// `platform-tools/adb` (`adb.exe` on Windows).
  final String adbPath;

  /// `emulator/emulator` (`emulator.exe` on Windows), when installed.
  final String? emulatorPath;

  /// The folder holding the AVDs (`<name>.ini` + `<name>.avd/`).
  final String avdHome;

  const AndroidSdk({required this.root, required this.adbPath, required this.emulatorPath, required this.avdHome});

  /// The SDK, looked for in this order: `ANDROID_HOME`, `ANDROID_SDK_ROOT`,
  /// Flutter's `android-sdk` setting (`flutter config --android-sdk`), then
  /// the folder Android Studio installs it to (Windows
  /// `%LOCALAPPDATA%\Android\Sdk`, macOS `~/Library/Android/sdk`, Linux
  /// `~/Android/Sdk`). A candidate counts only with `platform-tools/adb`.
  /// Null when there is none.
  ///
  /// [environment], [operatingSystem] and [homeDir] default to this
  /// process's.
  static AndroidSdk? locate({Map<String, String>? environment, String? operatingSystem, String? homeDir}) {
    final env = environment ?? Platform.environment;
    final os = operatingSystem ?? Platform.operatingSystem;
    final windows = os == 'windows';
    final home = homeDir ?? (windows ? env['USERPROFILE'] : env['HOME']) ?? '';
    for (final candidate in candidates(env, os, home)) {
      final sdk = at(candidate, operatingSystem: os, environment: env, homeDir: home);
      if (sdk != null) return sdk;
    }
    return null;
  }

  /// The folders [locate] tries, in order (missing ones included).
  static List<String> candidates(Map<String, String> env, String os, String home) {
    final windows = os == 'windows';
    String? nonEmpty(String? v) => v == null || v.trim().isEmpty ? null : v.trim();
    return [
      ?nonEmpty(env['ANDROID_HOME']),
      ?nonEmpty(env['ANDROID_SDK_ROOT']),
      ?flutterSettingsSdk(env, os, home),
      if (windows)
        ?(nonEmpty(env['LOCALAPPDATA']) == null ? null : '${env['LOCALAPPDATA']}\\Android\\Sdk')
      else if (os == 'macos')
        '$home/Library/Android/sdk'
      else
        '$home/Android/Sdk',
    ];
  }

  /// The `android-sdk` entry of Flutter's settings file
  /// (`%APPDATA%\.flutter_settings` on Windows, `~/.config/flutter/settings`
  /// elsewhere), which `flutter config --android-sdk <path>` writes.
  static String? flutterSettingsSdk(Map<String, String> env, String os, String home) {
    final paths = [
      if (os == 'windows' && (env['APPDATA'] ?? '').isNotEmpty) '${env['APPDATA']}\\.flutter_settings',
      if ((env['XDG_CONFIG_HOME'] ?? '').isNotEmpty) '${env['XDG_CONFIG_HOME']}/flutter/settings',
      '$home/.config/flutter/settings',
      '$home/.flutter_settings',
    ];
    for (final path in paths) {
      final file = File(path);
      if (!file.existsSync()) continue;
      try {
        final decoded = jsonDecode(file.readAsStringSync());
        final sdk = decoded is Map ? decoded['android-sdk'] : null;
        if (sdk is String && sdk.trim().isNotEmpty) return sdk.trim();
      } on Object {
        // An unreadable settings file names no SDK.
      }
    }
    return null;
  }

  /// The SDK at [root], or null when it has no `platform-tools/adb`.
  static AndroidSdk? at(String root, {String? operatingSystem, Map<String, String>? environment, String? homeDir}) {
    final os = operatingSystem ?? Platform.operatingSystem;
    final env = environment ?? Platform.environment;
    final ext = os == 'windows' ? '.exe' : '';
    final sep = os == 'windows' ? '\\' : '/';
    final base = root.endsWith('/') || root.endsWith('\\') ? root.substring(0, root.length - 1) : root;
    if (!Directory(base).existsSync()) return null;
    final adb = '$base${sep}platform-tools${sep}adb$ext';
    if (!File(adb).existsSync()) return null;
    final emulator = '$base${sep}emulator${sep}emulator$ext';
    final home = homeDir ?? (os == 'windows' ? env['USERPROFILE'] : env['HOME']) ?? '';
    return AndroidSdk(
      root: base,
      adbPath: adb,
      emulatorPath: File(emulator).existsSync() ? emulator : null,
      avdHome: avdHomeFor(env, home, sep),
    );
  }

  /// `ANDROID_AVD_HOME`, else `ANDROID_USER_HOME/avd`, else `~/.android/avd`.
  static String avdHomeFor(Map<String, String> env, String home, [String sep = '/']) {
    final explicit = env['ANDROID_AVD_HOME'];
    if (explicit != null && explicit.trim().isNotEmpty) return explicit.trim();
    final user = env['ANDROID_USER_HOME'];
    if (user != null && user.trim().isNotEmpty) return '${user.trim()}${sep}avd';
    return '$home$sep.android${sep}avd';
  }

  @override
  String toString() => 'AndroidSdk($root)';
}
