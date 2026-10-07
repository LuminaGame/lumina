/// Where the caret is inside the `material { }` header: at a key, or at the
/// value of a key, possibly inside a nested entry object (`parameters : [
/// { type : | } ]`) or a list (`requires : [ uv0, | ]`). Pure Dart.
library;

import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/mat_document.dart';

enum MatHeaderPosition { key, value }

class MatHeaderContext {
  final MatHeaderPosition position;

  /// The header key owning the object or list the caret is in: null for the
  /// header itself, else `parameters`, `constants`, `variables`,
  /// `blendFunction`, `requires`, ….
  final String? owner;

  /// At a value: the key whose value is typed (for a list item, the list's key).
  final String? key;

  /// At a value: whether it is an item of a list.
  final bool inList;

  /// The keys already written in the object the caret is in.
  final Set<String> existingKeys;

  const MatHeaderContext({
    required this.position,
    this.owner,
    this.key,
    this.inList = false,
    this.existingKeys = const {},
  });

  /// The context at [offset] (the start of the identifier being typed) in
  /// the header [block]; null right after a complete value, where nothing
  /// but `,` or a closing bracket can follow.
  static MatHeaderContext? at(MatDocumentIndex doc, MatBlockRange block, int offset) {
    final s = doc.masked;
    final frames = <_Frame>[_Frame(isList: false, owner: null)];
    var i = block.bodyStart;
    while (i < offset) {
      final c = s.codeUnitAt(i);
      final f = frames.last;
      if (c == 0x22) {
        // A quoted value.
        var j = i + 1;
        while (j < offset && s.codeUnitAt(j) != 0x22 && s.codeUnitAt(j) != 0x0A) {
          j++;
        }
        f.state = _State.afterValue;
        i = j + 1;
        continue;
      }
      if (_isWord(c)) {
        var j = i;
        while (j < offset && _isWord(s.codeUnitAt(j))) {
          j++;
        }
        final word = s.substring(i, j);
        if (!f.isList && f.state == _State.key) {
          f.pendingKey = word;
          f.keys.add(word);
          f.state = _State.afterKey;
        } else {
          f.state = _State.afterValue;
        }
        i = j;
        continue;
      }
      switch (c) {
        case 0x3A: // ':'
          if (!f.isList && f.state == _State.afterKey) f.state = _State.value;
        case 0x2C: // ','
          f.state = f.isList ? _State.value : _State.key;
        case 0x7B: // '{'
          final owner = f.isList ? f.owner : f.pendingKey;
          frames.add(_Frame(isList: false, owner: owner));
        case 0x5B: // '['
          frames.add(_Frame(isList: true, owner: f.isList ? f.owner : f.pendingKey)..state = _State.value);
        case 0x7D || 0x5D: // '}' ']'
          if (frames.length > 1) frames.removeLast();
          frames.last.state = _State.afterValue;
      }
      i++;
    }
    final f = frames.last;
    final nested = frames.length > 1;
    switch (f.state) {
      case _State.key:
        return MatHeaderContext(
          position: MatHeaderPosition.key,
          owner: nested ? f.owner : null,
          existingKeys: f.keys,
        );
      case _State.value:
        return MatHeaderContext(
          position: MatHeaderPosition.value,
          owner: nested ? f.owner : null,
          key: f.isList ? f.owner : f.pendingKey,
          inList: f.isList,
        );
      case _State.afterKey || _State.afterValue:
        return null;
    }
  }

  static bool _isWord(int c) =>
      (c >= 0x61 && c <= 0x7A) ||
      (c >= 0x41 && c <= 0x5A) ||
      (c >= 0x30 && c <= 0x39) ||
      c == 0x5F ||
      c == 0x2E ||
      c == 0x2D;
}

enum _State { key, afterKey, value, afterValue }

class _Frame {
  final bool isList;
  final String? owner;
  _State state = _State.key;
  String? pendingKey;
  final Set<String> keys = {};
  _Frame({required this.isList, required this.owner});
}
