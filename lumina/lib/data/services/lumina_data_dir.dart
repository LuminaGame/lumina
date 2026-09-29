import 'dart:io';

import 'package:path/path.dart' as p;

/// The per-user directory Lumina keeps downloaded data in: the engine
/// source a release build fetches for itself (`engine/<version>/`), the
/// prebuilt Filament builds (`filament/<version>/`) and the prebuilt
/// OpenRigLogic libraries (`openriglogic/<release tag>/`).
///
/// - Windows: `%LOCALAPPDATA%\Lumina`;
/// - Linux: `$XDG_DATA_HOME/lumina`, else `~/.local/share/lumina` (where the
///   user plugins and the MiniAI models live too);
/// - macOS: `~/Library/Application Support/Lumina`.
///
/// `LUMINA_DATA_DIR` redirects it for a whole process; [override] does the
/// same in-process (test harnesses).
abstract final class LuminaDataDir {
  static const String environmentVariable = 'LUMINA_DATA_DIR';

  /// In-process redirect, ahead of [environmentVariable].
  static Directory? override;

  /// The data directory for [environment] (default: the process
  /// environment) on [operatingSystem] (default: this one).
  static Directory resolve({Map<String, String>? environment, String? operatingSystem}) {
    final redirected = override;
    if (redirected != null) return redirected;
    final env = environment ?? Platform.environment;
    final fromEnv = env[environmentVariable];
    if (fromEnv != null && fromEnv.isNotEmpty) return Directory(fromEnv);
    final os = operatingSystem ?? Platform.operatingSystem;
    final home = env['HOME'] ?? env['USERPROFILE'] ?? '.';
    switch (os) {
      case 'windows':
        final local = env['LOCALAPPDATA'];
        final base = local != null && local.isNotEmpty ? local : p.join(env['USERPROFILE'] ?? home, 'AppData', 'Local');
        return Directory(p.join(base, 'Lumina'));
      case 'macos':
        return Directory(p.join(home, 'Library', 'Application Support', 'Lumina'));
      default:
        final xdg = env['XDG_DATA_HOME'];
        return Directory(xdg != null && xdg.isNotEmpty ? p.join(xdg, 'lumina') : p.join(home, '.local', 'share', 'lumina'));
    }
  }

  /// `<data>/engine`: one checkout per release tag.
  static Directory engineRoot({Map<String, String>? environment, String? operatingSystem}) =>
      Directory(p.join(resolve(environment: environment, operatingSystem: operatingSystem).path, 'engine'));

  /// `<data>/filament`: one prebuilt Filament per Filament version.
  static Directory filamentRoot({Map<String, String>? environment, String? operatingSystem}) =>
      Directory(p.join(resolve(environment: environment, operatingSystem: operatingSystem).path, 'filament'));

  /// `<data>/openriglogic`: one prebuilt OpenRigLogic per release tag.
  static Directory openriglogicRoot({Map<String, String>? environment, String? operatingSystem}) =>
      Directory(p.join(resolve(environment: environment, operatingSystem: operatingSystem).path, 'openriglogic'));
}
