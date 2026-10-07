import 'dart:io';

/// The per-user directory Lumina Studio keeps its settings in:
/// `recent_projects.json`, `launcher_settings.json`, `editor_quality.json`,
/// `plugin_wizard.json`.
///
/// Every reader and writer of those files resolves the directory here, in
/// this order:
/// 1. a directory the caller passes explicitly (a repository's `configDir`);
/// 2. [override], the in-process redirect test harnesses set;
/// 3. the `LUMINA_CONFIG_DIR` environment variable;
/// 4. `~/.config/lumina`.
///
/// Test suites set [override] to a fresh temp directory in their
/// `flutter_test_config.dart`, so no test reads or writes the user's own
/// files.
abstract final class LuminaConfigDir {
  /// The environment variable that redirects the directory for a whole
  /// process (tooling exports it to the test runs it starts).
  static const String environmentVariable = 'LUMINA_CONFIG_DIR';

  /// In-process redirect, ahead of [environmentVariable]. Dart cannot set an
  /// environment variable for its own process, so a test harness sets this.
  static Directory? override;

  /// The config directory. [explicit] wins over everything else;
  /// [environment] defaults to the process environment.
  static Directory resolve({Directory? explicit, Map<String, String>? environment}) {
    if (explicit != null) return explicit;
    final redirected = override;
    if (redirected != null) return redirected;
    final env = environment ?? Platform.environment;
    final fromEnv = env[environmentVariable];
    if (fromEnv != null && fromEnv.isNotEmpty) return Directory(fromEnv);
    final home = env['HOME'] ?? env['USERPROFILE'] ?? '.';
    return Directory('$home/.config/lumina');
  }

  /// The file [name] in the resolved directory.
  static File file(String name, {Directory? explicit}) => File('${resolve(explicit: explicit).path}/$name');
}
