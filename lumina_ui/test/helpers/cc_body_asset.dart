import 'dart:io';

import 'package:lumina_ui/testing.dart';

/// Finds a Character Creator body GLB (`CCMH_Body_Male.glb`,
/// `CCMH_Body_Female.glb`) on any machine. They are not part of
/// test-assets everywhere, so the places looked in are, in order:
///
/// 1. `$LUMINA_CC_BODY_DIR/<name>` — an explicit folder;
/// 2. anywhere under test-assets (`SmokeArtifacts.testAssetsDir`);
/// 3. `<home>/Documents/outfiles/<name>` (`HOME`, else `USERPROFILE`) — where
///    the bodies were exported on the Linux machine.
///
/// When none has it, [file] is null and [skipReason] says what was searched:
/// a test that needs the body skips with that reason instead of passing
/// without running.
class CcBodyAsset {
  CcBodyAsset._(this.name, this.file, this.skipReason);

  static const String male = 'CCMH_Body_Male.glb';
  static const String female = 'CCMH_Body_Female.glb';

  final String name;

  /// The GLB, or null when it is on none of the searched paths.
  final File? file;

  /// Why a test that needs [name] is skipped; null when [file] was found.
  final String? skipReason;

  static CcBodyAsset resolve(String name, {Map<String, String>? environment, Directory? testAssetsDir}) {
    final env = environment ?? Platform.environment;
    final looked = <String>[];

    final explicit = env['LUMINA_CC_BODY_DIR'];
    if (explicit != null && explicit.isNotEmpty) {
      final f = File('$explicit/$name');
      if (f.existsSync()) return CcBodyAsset._(name, f, null);
      looked.add('LUMINA_CC_BODY_DIR ($explicit)');
    } else {
      looked.add('LUMINA_CC_BODY_DIR (not set)');
    }

    final assets = testAssetsDir ?? SmokeArtifacts.testAssetsDir;
    if (assets.existsSync()) {
      for (final e in assets.listSync(recursive: true, followLinks: false)) {
        if (e is File && e.uri.pathSegments.last == name) return CcBodyAsset._(name, File(e.path.replaceAll(r'\', '/')), null);
      }
    }
    looked.add('test-assets (${assets.path})');

    final home = env['HOME'] ?? env['USERPROFILE'];
    if (home != null && home.isNotEmpty) {
      final f = File('$home/Documents/outfiles/$name');
      if (f.existsSync()) return CcBodyAsset._(name, f, null);
      looked.add('$home/Documents/outfiles');
    }

    return CcBodyAsset._(name, null, '$name is not on this machine; looked in ${looked.join(', ')}. '
        'Put it in one of those or set LUMINA_CC_BODY_DIR to its folder.');
  }
}
