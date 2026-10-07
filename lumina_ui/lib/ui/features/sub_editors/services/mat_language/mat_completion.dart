/// Code completion for Filament `.mat` material sources: header keys and
/// values in the `material { }` block, `MaterialInputs` /
/// `MaterialVertexInputs` fields after `material.`, declared parameters
/// after `materialParams.` / `materialParams_`, and the Filament shader APIs,
/// GLSL built-ins, types, keywords and local declarations in the `vertex` and
/// `fragment` blocks. The tables come from Filament's material documentation
/// (`filament_material_api.g.dart`). Pure Dart, no Flutter imports; a query
/// on a 200-line source takes well under a millisecond.
library;

import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/mat_completion_item.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/mat_completion_sources.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/mat_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/mat_fuzzy_match.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/mat_header_context.dart';

export 'package:lumina_ui/ui/features/sub_editors/services/mat_language/mat_completion_item.dart';

/// The suggestions for one caret position.
class MatCompletionResult {
  /// The range accepting an item replaces: the identifier around the caret.
  final int replaceStart;
  final int replaceEnd;

  /// Best match first.
  final List<MatCompletionItem> items;
  const MatCompletionResult(this.replaceStart, this.replaceEnd, this.items);

  bool get isEmpty => items.isEmpty;

  static const empty = MatCompletionResult(0, 0, []);
}

class MatCompletion {
  const MatCompletion._();

  static bool _isIdent(int c) =>
      (c >= 0x61 && c <= 0x7A) || (c >= 0x41 && c <= 0x5A) || (c >= 0x30 && c <= 0x39) || c == 0x5F;

  /// The suggestions at [offset] in [source]. With an empty prefix only an
  /// [explicit] request (Ctrl+Space) or a member access (`material.`)
  /// suggests anything. Inside comments and strings nothing is suggested.
  static MatCompletionResult suggest(String source, int offset, {bool explicit = false}) {
    if (offset < 0 || offset > source.length) return MatCompletionResult.empty;
    var start = offset;
    while (start > 0 && _isIdent(source.codeUnitAt(start - 1))) {
      start--;
    }
    var end = offset;
    while (end < source.length && _isIdent(source.codeUnitAt(end))) {
      end++;
    }
    final prefix = source.substring(start, offset);
    final none = MatCompletionResult(start, end, const []);
    final doc = MatDocumentIndex.of(source);
    if (doc.isInCommentOrString(offset)) return none;
    final memberAccess = start > 0 && source.codeUnitAt(start - 1) == 0x2E; // '.'
    if (prefix.isEmpty && !explicit && !memberAccess) return none;

    final block = doc.blockAt(offset);
    final List<MatCompletionItem> candidates;
    if (block == null) {
      if (memberAccess) return none;
      candidates = MatCompletionSources.blockSnippets(doc);
    } else if (block.name == 'material') {
      if (memberAccess) return none;
      final context = MatHeaderContext.at(doc, block, start);
      candidates = context == null ? const [] : MatCompletionSources.header(doc, context);
    } else if (block.name == 'fragment' || block.name == 'vertex') {
      final vertex = block.name == 'vertex';
      if (memberAccess) {
        final receiver = _receiver(source, start - 1);
        candidates = MatCompletionSources.members(doc, receiver, vertex: vertex);
      } else {
        if (prefix.isNotEmpty && _isDigit(prefix.codeUnitAt(0))) return none; // a number
        candidates = MatCompletionSources.identifiers(doc, block, start, vertex: vertex);
      }
    } else {
      return none;
    }
    return MatCompletionResult(start, end, rank(candidates, prefix));
  }

  static bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

  /// The identifier just before the `.` at [dot]; empty when it is not one
  /// (`foo().`, `a[0].`).
  static String _receiver(String source, int dot) {
    var s = dot;
    while (s > 0 && _isIdent(source.codeUnitAt(s - 1))) {
      s--;
    }
    return source.substring(s, dot);
  }

  /// Filters [candidates] by [prefix] and sorts them: exact label, then the
  /// match tier and its score, then the kind's relevance, then alphabetically.
  static List<MatCompletionItem> rank(List<MatCompletionItem> candidates, String prefix) {
    final scored = <(MatCompletionItem, int, int)>[];
    for (final c in candidates) {
      final m = matchLabel(c.label, prefix);
      if (m == null) continue;
      final tier = c.label == prefix ? -1 : m.tier;
      scored.add((c.withHighlights(m.positions), tier, m.score));
    }
    scored.sort((a, b) {
      final t = a.$2.compareTo(b.$2);
      if (t != 0) return t;
      final sc = a.$3.compareTo(b.$3);
      if (sc != 0) return sc;
      final k = a.$1.kind.relevance.compareTo(b.$1.kind.relevance);
      if (k != 0) return k;
      final l = a.$1.label.toLowerCase().compareTo(b.$1.label.toLowerCase());
      return l != 0 ? l : a.$1.label.compareTo(b.$1.label);
    });
    return [for (final s in scored) s.$1];
  }
}
