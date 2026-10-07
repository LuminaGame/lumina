import 'dart:io';

import 'package:lumina/data/services/dart_identifiers.dart';

/// Brings a project's generated Dart written by earlier Lumina versions to
/// the current naming rules ([dartTypeName], [dartFileName]).
///
/// Earlier generators named the files in `lib/levels/`, `lib/actors/`,
/// `lib/anim/` and `lib/widgets/` after their assets (`L_Main.dart`,
/// `BP_Door.dart`) and their classes `L_Main`, `BPDoor`, `WBPHud`. Today the
/// files are snake_case (`l_main.dart`, `bp_door.dart`) and the classes
/// UpperCamelCase (`LMain`, `BpDoor`, `WbpHud`). [migrate] renames the legacy
/// files — keeping their contents, so `BEGIN USER CODE` regions survive —
/// renames the classes they declare, and rewrites the imports and class
/// references of every Dart file under `lib/`, so a project regenerates
/// cleanly and still compiles in between. A legacy file whose snake_case
/// file already exists is stale and is deleted. Generated code that keyed
/// engine objects with Flutter's `ValueKey` moves to `LuminaObjectKey`
/// ([migrateObjectKeys]).
class LuminaGeneratedCodeMigration {
  LuminaGeneratedCodeMigration._();

  /// The `lib/` folders whose files are named after assets.
  static const List<String> generatedFolders = ['levels', 'actors', 'anim', 'widgets'];

  /// Suffixes generated classes append to a generated class name
  /// (`_L_MainScript`, `WBPHudGraph`, `_WBPHudState`).
  static const List<String> _classSuffixes = ['StreamingPlayerStart', 'Script', 'Graph', 'State'];

  static final RegExp _declaredClass = RegExp(r'^(?:abstract\s+)?class\s+([A-Za-z]\w*)', multiLine: true);
  static final RegExp _directive = RegExp(r'''^(\s*(?:import|export|part)\s+')([^']+)(')''', multiLine: true);

  /// Migrates [projectDir]'s generated Dart; returns the renamed files,
  /// `lib/…` old path → new path (empty when there was nothing to migrate).
  static Map<String, String> migrate(String projectDir) {
    final lib = Directory('$projectDir/lib');
    if (!lib.existsSync()) return const {};
    migrateObjectKeys(projectDir);

    // 1. Legacy files and the classes they declare.
    final renames = <String, String>{}; // lib-relative old path → new path
    final stale = <File>[];
    final moves = <File, String>{};
    final classes = <String, String>{}; // old class → new class
    for (final folder in generatedFolders) {
      final dir = Directory('${lib.path}/$folder');
      if (!dir.existsSync()) continue;
      final names = {for (final f in dir.listSync().whereType<File>()) f.uri.pathSegments.last};
      for (final name in names) {
        if (!name.endsWith('.dart') || name.endsWith('.g.dart')) continue;
        final stem = name.substring(0, name.length - '.dart'.length);
        final target = dartFileName(stem);
        if (target == name) continue;
        final file = File('${dir.path}/$name');
        renames['lib/$folder/$name'] = 'lib/$folder/$target';
        if (names.contains(target)) {
          stale.add(file);
          continue;
        }
        moves[file] = '${dir.path}/$target';
        String source;
        try {
          source = file.readAsStringSync();
        } catch (_) {
          continue;
        }
        final declared = _declaredClass.firstMatch(source)?.group(1);
        final newClass = dartTypeName(stem);
        if (declared != null && declared != newClass) classes[declared] = newClass;
      }
    }
    if (renames.isEmpty) return const {};

    // 2. Imports and class references in every Dart file under lib/ (the
    // legacy files included, before they move; stale ones are deleted).
    final staleSet = stale.map((f) => f.absolute.path).toSet();
    final classPattern = classes.isEmpty ? null : _classReferences(classes.keys);
    for (final file in lib.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') || staleSet.contains(file.absolute.path)) continue;
      String source;
      try {
        source = file.readAsStringSync();
      } catch (_) {
        continue;
      }
      final from = _libRelativeDir(lib, file);
      var updated = source.replaceAllMapped(_directive, (m) {
        final uri = m.group(2)!;
        if (uri.contains(':')) return m.group(0)!;
        final target = renames[_normalise('$from/$uri')];
        if (target == null) return m.group(0)!;
        final slash = uri.lastIndexOf('/');
        return '${m.group(1)}${uri.substring(0, slash + 1)}${target.split('/').last}${m.group(3)}';
      });
      if (classPattern != null) {
        updated = updated.replaceAllMapped(
            classPattern, (m) => '${m.group(1)}${classes[m.group(2)]}${m.group(3) ?? ''}');
      }
      if (updated != source) file.writeAsStringSync(updated);
    }

    // 3. The files themselves: a case-only rename (Windows, macOS) goes
    // through a temporary name.
    for (final f in stale) {
      f.deleteSync();
    }
    for (final e in moves.entries) {
      final temp = '${e.key.path}.lumina_migrate';
      e.key.renameSync(temp);
      File(temp).renameSync(e.value);
    }
    return renames;
  }

  /// The generated folders whose code keys engine objects (widgets keep
  /// Flutter's keys).
  static const List<String> objectKeyFolders = ['levels', 'actors', 'anim'];

  static final RegExp _foundationKeyImport =
      RegExp(r"^import 'package:flutter/foundation\.dart' show ([\w, ]+);[ \t]*\r?\n", multiLine: true);

  /// Earlier generators keyed placed actors and level scripts with Flutter's
  /// `ValueKey` (`key: const ValueKey('act_floor')`, a `{Key? key, …}` actor
  /// factory, `key is ValueKey<String>` in the data-layer assignment) and
  /// imported `package:flutter/foundation.dart` for it. Engine objects carry
  /// a `LuminaObjectKey` now: this rewrites those files of [objectKeyFolders]
  /// in place and returns them (`lib/…`; empty when none needed it).
  /// [migrate] runs it first.
  static List<String> migrateObjectKeys(String projectDir) {
    final rewritten = <String>[];
    for (final folder in objectKeyFolders) {
      final dir = Directory('$projectDir/lib/$folder');
      if (!dir.existsSync()) continue;
      for (final file in dir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        String source;
        try {
          source = file.readAsStringSync();
        } catch (_) {
          continue;
        }
        if (!source.contains('Key')) continue;
        final updated = rewriteObjectKeys(source);
        if (updated == source) continue;
        file.writeAsStringSync(updated);
        final rel = file.absolute.path.replaceAll(r'\', '/').substring(dir.absolute.path.replaceAll(r'\', '/').length + 1);
        rewritten.add('lib/$folder/$rel');
      }
    }
    return rewritten..sort();
  }

  /// [source] with Flutter's `Key` / `ValueKey` on engine objects replaced
  /// by `LuminaObjectKey`, and their `foundation.dart` import dropped.
  static String rewriteObjectKeys(String source) {
    var out = source.replaceAllMapped(_foundationKeyImport, (m) {
      final kept = m.group(1)!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty && s != 'Key' && s != 'ValueKey');
      return kept.isEmpty ? '' : "import 'package:flutter/foundation.dart' show ${kept.join(', ')};\n";
    });
    out = out
        .replaceAll(RegExp(r'\bValueKey<String>'), 'LuminaObjectKey')
        .replaceAll(RegExp(r'\bValueKey\('), 'LuminaObjectKey(')
        .replaceAll(RegExp(r'(?<![\w.])Key\? key\b'), 'LuminaObjectKey? key');
    return out;
  }

  /// Matches a reference to one of [oldClasses] — bare, `_`-prefixed and
  /// with a generated suffix — but not inside a path or a quoted name
  /// (`'L_Main'`, `contents/levels/L_Main.lmas`, `` `L_Main` ``).
  static RegExp _classReferences(Iterable<String> oldClasses) {
    final names = oldClasses.toList()..sort((a, b) => b.length.compareTo(a.length));
    final alternatives = names.map(RegExp.escape).join('|');
    return RegExp("(?<![A-Za-z0-9'`/\$])(_?)($alternatives)(${_classSuffixes.join('|')})?(?![A-Za-z0-9_])");
  }

  static String _libRelativeDir(Directory lib, File file) {
    final root = lib.absolute.path.replaceAll(r'\', '/');
    final path = file.parent.absolute.path.replaceAll(r'\', '/');
    final rel = path.length > root.length ? path.substring(root.length + 1) : '';
    return rel.isEmpty ? 'lib' : 'lib/$rel';
  }

  /// `lib/actors/../anim/X.dart` → `lib/anim/X.dart`.
  static String _normalise(String path) {
    final out = <String>[];
    for (final s in path.split('/')) {
      if (s.isEmpty || s == '.') continue;
      if (s == '..') {
        if (out.isNotEmpty) out.removeLast();
      } else {
        out.add(s);
      }
    }
    return out.join('/');
  }
}
