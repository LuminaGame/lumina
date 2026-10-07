import 'dart:io';

import 'package:lumina/data/models/lumina_project.dart';

/// Keeps a game project's `pubspec.yaml` in line with its UMG widget library:
/// a `shadcn` project depends on shadcn_flutter at the editor's
/// version ([kGameShadcnFlutterVersion]), a `flutter` project does not. The
/// dependency lives in a marked block so switching back and forth is exact
/// and idempotent.
abstract final class UmgWidgetLibraryService {
  static const String beginMarker = '  # BEGIN LUMINA UI (generated)';
  static const String endMarker = '  # END LUMINA UI';

  static String get _block => '$beginMarker\n  shadcn_flutter: $kGameShadcnFlutterVersion\n$endMarker\n';

  /// Makes `<projectDir>/pubspec.yaml` match [library]. Returns whether the
  /// file changed; the caller then runs `flutter pub get`.
  static bool apply(String projectDir, String library) {
    final file = File('$projectDir/pubspec.yaml');
    // Edited as LF and written back with the file's own line endings:
    // `flutter create` writes CRLF on Windows, where an LF-only match missed
    // `dependencies:` and appended a duplicate mapping key.
    final raw = file.readAsStringSync();
    final crlf = raw.contains('\r\n');
    final original = crlf ? raw.replaceAll('\r\n', '\n') : raw;
    var text = _withoutBlock(original);
    if (library == kUmgWidgetLibraryShadcn) {
      final deps = RegExp(r'^dependencies:[ \t]*\n', multiLine: true).firstMatch(text);
      text = deps == null ? '$text\ndependencies:\n$_block' : text.replaceRange(deps.end, deps.end, _block);
    }
    if (text == original) return false;
    file.writeAsStringSync(crlf ? text.replaceAll('\n', '\r\n') : text);
    return true;
  }

  /// Whether the project's pubspec declares shadcn_flutter (in the block or
  /// by hand), i.e. whether shadcn code compiles in the game.
  static bool dependsOnShadcn(String projectDir) {
    final file = File('$projectDir/pubspec.yaml');
    return file.existsSync() && RegExp(r'^\s+shadcn_flutter:', multiLine: true).hasMatch(file.readAsStringSync());
  }

  /// The library the generated launcher and widgets can actually target:
  /// shadcn only when the project chose it *and* depends on it, so a
  /// manifest predating the setting never gets code its pubspec cannot build.
  static String effectiveLibrary(String projectDir, LuminaProject? project) {
    final chosen = project?.ui.widgetLibrary ?? kUmgWidgetLibraryShadcn;
    return chosen == kUmgWidgetLibraryShadcn && dependsOnShadcn(projectDir) ? kUmgWidgetLibraryShadcn : kUmgWidgetLibraryFlutter;
  }

  static String _withoutBlock(String text) {
    final start = text.indexOf(beginMarker);
    if (start < 0) return text;
    final end = text.indexOf(endMarker, start);
    if (end < 0) return text;
    var stop = end + endMarker.length;
    if (stop < text.length && text[stop] == '\n') stop++;
    return text.replaceRange(start, stop, '');
  }
}
