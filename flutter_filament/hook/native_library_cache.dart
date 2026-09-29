// A machine-wide, content-addressed cache of the wrapper library the
// native-assets hook builds. Package-agnostic: the
// package name, library file name and inputs are passed in, so the other
// FFI packages' hooks can reuse it.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Everything that decides the built library's bytes.
class NativeBuildInputs {
  /// Compiled sources (absolute paths), hashed by content, order-free.
  final List<String> sources;

  /// Headers the sources include from the package (absolute), by content.
  final List<String> headers;

  /// Linked static archives (absolute), by path + size + mtime: hashing
  /// ~44 multi-MB archives on every run would make a hit slow, and a relink
  /// rewrites the file.
  final List<String> archives;

  final List<String> includes;
  final Map<String, String?> defines;

  /// Compiler / linker flags other than the archives, verbatim.
  final List<String> flags;
  final List<String> libraries;
  final String targetOS;
  final String targetArchitecture;
  final String linkMode;
  final String buildMode;

  /// The compiler's identity (`clang --version`, MSVC's tools version).
  final String compiler;

  const NativeBuildInputs({
    required this.sources,
    required this.headers,
    required this.archives,
    required this.includes,
    required this.defines,
    required this.flags,
    required this.libraries,
    required this.targetOS,
    required this.targetArchitecture,
    required this.linkMode,
    required this.buildMode,
    required this.compiler,
  });
}

class NativeLibraryCache {
  final Directory root;

  NativeLibraryCache({Directory? root}) : root = root ?? defaultRoot();

  /// `$LUMINA_NATIVE_CACHE_DIR`, else `$XDG_CACHE_HOME/lumina/native`, else
  /// the platform cache folder: `%LOCALAPPDATA%\lumina\native` on Windows,
  /// `~/Library/Caches/lumina/native` on macOS, `~/.cache/lumina/native`.
  static Directory defaultRoot({Map<String, String>? environment, String? operatingSystem}) {
    final env = environment ?? Platform.environment;
    final os = operatingSystem ?? Platform.operatingSystem;
    final explicit = env['LUMINA_NATIVE_CACHE_DIR'];
    if (explicit != null && explicit.isNotEmpty) return Directory(explicit);
    final sep = os == 'windows' ? r'\' : '/';
    final xdg = env['XDG_CACHE_HOME'];
    if (os != 'windows' && xdg != null && xdg.isNotEmpty) return Directory('$xdg/lumina/native');
    if (os == 'windows') {
      final base = env['LOCALAPPDATA'] ?? '${env['USERPROFILE'] ?? '.'}${sep}AppData${sep}Local';
      return Directory('$base${sep}lumina${sep}native');
    }
    final home = env['HOME'] ?? '.';
    return Directory(os == 'macos' ? '$home/Library/Caches/lumina/native' : '$home/.cache/lumina/native');
  }

  /// Whether lookups and publishes happen: not when `LUMINA_NATIVE_CACHE=off`,
  /// and not when a `disabled` file sits in [root]. The hooks runner passes a
  /// hook only allow-listed environment variables (PATH, HOME, LOCALAPPDATA,
  /// TEMP, … — never LUMINA_*), so under `flutter build` / `flutter test` the
  /// file is the switch that reaches the hook; the variable covers direct runs.
  bool enabled({Map<String, String>? environment}) =>
      (environment ?? Platform.environment)['LUMINA_NATIVE_CACHE'] != 'off' &&
      !File('${root.path}/disabled').existsSync();

  /// SHA-256 (hex) over [inputs]; see [NativeBuildInputs] for what each part
  /// is hashed by.
  String key(NativeBuildInputs inputs) {
    String contentHash(String path) => sha256.convert(File(path).readAsBytesSync()).toString();
    // The archive's real path: each project editor reaches the engine's
    // archives through its own `filament` link.
    String archiveStamp(String path) {
      final file = File(path);
      final stat = file.statSync();
      final real = file.existsSync() ? file.resolveSymbolicLinksSync() : path;
      return '${real.replaceAll(r'\', '/')}|${stat.size}|${stat.modified.microsecondsSinceEpoch}';
    }

    final sortedSources = [...inputs.sources]..sort();
    final sortedHeaders = [...inputs.headers]..sort();
    final sortedArchives = [...inputs.archives]..sort();
    final defines = (inputs.defines.keys.toList()..sort()).map((k) => '$k=${inputs.defines[k] ?? ''}').toList();
    final manifest = <String, Object>{
      'sources': [for (final s in sortedSources) '${_name(s)}:${contentHash(s)}'],
      'headers': [for (final h in sortedHeaders) '${_name(h)}:${contentHash(h)}'],
      'archives': [for (final a in sortedArchives) archiveStamp(a)],
      'includes': inputs.includes,
      'defines': defines,
      'flags': inputs.flags,
      'libraries': inputs.libraries,
      'targetOS': inputs.targetOS,
      'targetArchitecture': inputs.targetArchitecture,
      'linkMode': inputs.linkMode,
      'buildMode': inputs.buildMode,
      'compiler': inputs.compiler,
    };
    return sha256.convert(utf8.encode(jsonEncode(manifest))).toString();
  }

  /// The file name of [path], so the key does not depend on where the
  /// package is checked out.
  static String _name(String path) => path.replaceAll(r'\', '/').split('/').last;

  /// The cached library for [key], only if its entry is complete.
  File? lookup(String package, String key, String libraryFileName) {
    final entry = Directory('${root.path}/$package/$key');
    final lib = File('${entry.path}/$libraryFileName');
    if (!File('${entry.path}/complete').existsSync() || !lib.existsSync()) return null;
    return lib;
  }

  /// Copies [built] into a fresh temp directory, marks it complete, then
  /// renames it into place. A crash leaves only a `*.tmp-*` directory, which
  /// [lookup] never returns; if another writer published the same key first,
  /// its (identical) entry is kept.
  Future<void> publish(String package, String key, File built) async {
    final pkgDir = Directory('${root.path}/$package');
    await pkgDir.create(recursive: true);
    final final_ = Directory('${pkgDir.path}/$key');
    if (File('${final_.path}/complete').existsSync()) return;
    final tmp = Directory('${pkgDir.path}/$key.tmp-$pid-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}');
    await tmp.create();
    try {
      await built.copy('${tmp.path}/${_name(built.path)}');
      await File('${tmp.path}/complete').writeAsString('complete\n', flush: true);
      try {
        await tmp.rename(final_.path);
      } on FileSystemException {
        // Lost the race: the other writer's entry stands.
        if (!File('${final_.path}/complete').existsSync()) rethrow;
      }
    } finally {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    }
  }
}
