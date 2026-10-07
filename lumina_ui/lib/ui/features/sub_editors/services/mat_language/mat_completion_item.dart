/// One `.mat` completion suggestion. Pure Dart.
library;

/// What a suggestion is; orders suggestions that match equally well.
enum MatCompletionKind {
  variable(0),
  parameter(0),
  field(1),
  property(1),
  value(1),
  function(2),
  constant(3),
  type(4),
  keyword(5),
  snippet(6);

  /// Lower ranks first among equally good matches.
  final int relevance;
  const MatCompletionKind(this.relevance);
}

class MatCompletionItem {
  /// The text shown and matched against the typed prefix.
  final String label;
  final MatCompletionKind kind;

  /// A short description shown right-aligned: a signature or a type.
  final String detail;

  /// The longer documentation for the details pane.
  final String documentation;

  /// The text inserted in place of the replaced range.
  final String insertText;

  /// Where the caret goes inside [insertText] (inside the parentheses of a
  /// function that takes arguments); null puts it at the end.
  final int? cursorOffsetInInsert;

  /// The indexes of [label] the typed prefix matched.
  final List<int> highlights;

  const MatCompletionItem({
    required this.label,
    required this.kind,
    this.detail = '',
    this.documentation = '',
    String? insertText,
    this.cursorOffsetInInsert,
    this.highlights = const [],
  }) : insertText = insertText ?? label;

  /// Where the caret lands relative to the insertion's start.
  int get caretOffset => cursorOffsetInInsert ?? insertText.length;

  MatCompletionItem withHighlights(List<int> positions) => MatCompletionItem(
    label: label,
    kind: kind,
    detail: detail,
    documentation: documentation,
    insertText: insertText,
    cursorOffsetInInsert: cursorOffsetInInsert,
    highlights: positions,
  );

  @override
  String toString() => '${kind.name} $label';
}
