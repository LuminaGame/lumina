/// Rewrites what a `.mat` source uses that the Filament release of the
/// generated tables (`filament_material_api.g.dart`) deprecated or removed,
/// to the current form, without changing what the material does:
///
/// - header values matc ignores or no longer accepts (`variantFilter :
///   [directionalLighting]`) are dropped; filtering a variant out only ever
///   removed code, and these filters already had no effect;
/// - values matc keeps as backward-compatible aliases
///   (`specularAmbientOcclusion : true`) become the value they stand for
///   (`simple`);
/// - calls of deprecated shader getters (`getWorldOffset()`) become the
///   expression the getter returns in Filament's shaders.
///
/// Edits never add or remove a line, so the compiler's line numbers still
/// point at the source the user sees. Pure Dart.
library;

import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/filament_material_api.g.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/mat_api_types.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/mat_document.dart';

/// One rewrite, for the Output Log.
class MatMigrationChange {
  /// 1-based line of the source the change was made on.
  final int line;
  final String message;
  const MatMigrationChange(this.line, this.message);

  @override
  String toString() => 'line $line: $message';
}

class MatMigration {
  /// The rewritten source; the input when nothing needed rewriting.
  final String source;
  final List<MatMigrationChange> changes;
  const MatMigration._(this.source, this.changes);

  bool get changed => changes.isNotEmpty;

  /// The header keys with values to rewrite, and the deprecated getters with
  /// a replacement, from the generated tables.
  static final List<MatHeaderKeyInfo> _keys = [
    for (final k in filamentHeaderKeys)
      if (k.removedValues.isNotEmpty || k.valueAliases.isNotEmpty) k,
  ];
  static final List<MatFunctionInfo> _getters = [
    for (final f in filamentFunctions)
      if (f.deprecated != null && f.replacement != null && !f.hasArguments) f,
  ];

  /// Rewrites [source] to the current `.mat` language.
  static MatMigration of(String source) {
    final index = MatDocumentIndex.of(source);
    final edits = <_Edit>[];
    final header = index.block('material');
    if (header != null) _header(index, header, edits);
    for (final block in index.blocks) {
      if (block.name != 'material') _shader(index, block, edits);
    }
    if (edits.isEmpty) return MatMigration._(source, const []);
    edits.sort((a, b) => a.start.compareTo(b.start));
    final out = StringBuffer();
    var at = 0;
    for (final e in edits) {
      out
        ..write(source.substring(at, e.start))
        ..write(e.text);
      at = e.end;
    }
    out.write(source.substring(at));
    return MatMigration._(out.toString(), [for (final e in edits) e.change]);
  }

  static final _token = RegExp(r'"?([A-Za-z_]\w*)"?');

  static void _header(MatDocumentIndex index, MatBlockRange header, List<_Edit> edits) {
    final masked = index.masked;
    for (final key in _keys) {
      final pattern = RegExp('(?<![\\w])${key.name}\\s*:\\s*');
      for (final m in pattern.allMatches(masked.substring(header.bodyStart, header.bodyEnd))) {
        final at = header.bodyStart + m.end;
        if (at >= masked.length) continue;
        if (masked[at] == '[') {
          final close = masked.indexOf(']', at);
          if (close < 0 || close > header.bodyEnd) continue;
          final edit = _list(index, key, at + 1, close);
          if (edit != null) edits.add(edit);
          continue;
        }
        final value = _token.matchAsPrefix(masked, at);
        if (value == null) continue;
        final current = key.valueAliases[value[1]!];
        if (current == null) continue;
        edits.add(_Edit(
          value.start,
          value.end,
          value[0]!.replaceFirst(value[1]!, current),
          MatMigrationChange(_line(masked, at), '${key.name}: ${value[1]} is kept only for backward compatibility; '
              'replaced with $current.'),
        ));
      }
    }
  }

  /// The edit of the items of a `[ … ]` value between [start] and [end]:
  /// removed values dropped with their comma, aliases replaced.
  static _Edit? _list(MatDocumentIndex index, MatHeaderKeyInfo key, int start, int end) {
    final masked = index.masked;
    final body = masked.substring(start, end);
    final notes = <String>[];
    final out = StringBuffer();
    var at = 0;
    for (final m in _token.allMatches(body)) {
      final value = m[1]!;
      final removed = key.removedValues[value];
      final current = key.valueAliases[value];
      if (removed == null && current == null) continue;
      out.write(index.source.substring(start + at, start + m.start));
      if (removed != null) {
        notes.add('removed $value ($removed)');
        // The item's own comma (and the spaces after it, on its line); the
        // last item has none, so the comma before it goes instead, keeping
        // any line break between them.
        final comma = RegExp(r'[ \t]*,[ \t]*').matchAsPrefix(body, m.end);
        if (comma != null) {
          at = comma.end;
        } else {
          final kept = out.toString().replaceFirstMapped(
            RegExp(r',(\s*)$'),
            (c) => c[1]!.contains('\n') ? c[1]! : '',
          );
          out
            ..clear()
            ..write(kept);
          at = m.end;
        }
      } else {
        notes.add('replaced $value with $current (kept only for backward compatibility)');
        out.write(index.source.substring(start + m.start, start + m.end).replaceFirst(value, current!));
        at = m.end;
      }
    }
    if (notes.isEmpty) return null;
    out.write(index.source.substring(start + at, end));
    // `[ a ]` with `a` dropped reads `[]`, not `[  ]` (line breaks stay).
    final text = out.toString().trim().isEmpty && !out.toString().contains('\n') ? '' : out.toString();
    return _Edit(start, end, text,MatMigrationChange(_line(masked, start), '${key.name}: ${notes.join('; ')}.'));
  }

  static void _shader(MatDocumentIndex index, MatBlockRange block, List<_Edit> edits) {
    final masked = index.masked;
    final body = masked.substring(block.bodyStart, block.bodyEnd);
    for (final f in _getters) {
      // A source that declares a function of the same name means its own.
      if (RegExp('\\b\\w+\\s+${f.name}\\s*\\(').hasMatch(masked)) continue;
      final replacement = RegExp(r'^[\w.\[\]()]+$').hasMatch(f.replacement!) ? f.replacement! : '(${f.replacement})';
      for (final m in RegExp('(?<![\\w.])${f.name}\\s*\\(\\s*\\)').allMatches(body)) {
        final start = block.bodyStart + m.start;
        edits.add(_Edit(
          start,
          block.bodyStart + m.end,
          replacement,
          MatMigrationChange(_line(masked, start), '${f.name}() is deprecated (${f.deprecated}); replaced with '
              '${f.replacement}, what it returns.'),
        ));
      }
    }
  }

  static int _line(String text, int offset) => '\n'.allMatches(text.substring(0, offset)).length + 1;
}

class _Edit {
  final int start;
  final int end;
  final String text;
  final MatMigrationChange change;
  const _Edit(this.start, this.end, this.text, this.change);
}
