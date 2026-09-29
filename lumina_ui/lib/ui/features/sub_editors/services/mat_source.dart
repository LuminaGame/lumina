/// A `.mat` material source split into its top-level blocks (`material`,
/// `vertex`, `fragment`, …) and the `material` header's entries, so the graph
/// generator can rewrite the parameters and the fragment while keeping
/// everything else as it was written.
library;

/// A header value: a bare word or number, a quoted string, a list or an object.
sealed class MatValue {
  const MatValue();
  String render({int indent = 0});
}

class MatAtom extends MatValue {
  final String text;
  const MatAtom(this.text);
  @override
  String render({int indent = 0}) => text;
}

class MatString extends MatValue {
  final String text;
  const MatString(this.text);
  @override
  String render({int indent = 0}) => '"$text"';
}

class MatList extends MatValue {
  final List<MatValue> items;
  const MatList(this.items);
  @override
  String render({int indent = 0}) {
    if (items.isEmpty) return '[]';
    if (items.every((i) => i is! MatObject && i is! MatList)) {
      return '[ ${items.map((i) => i.render()).join(', ')} ]';
    }
    final pad = '    ' * (indent + 1);
    return '[\n${items.map((i) => '$pad${i.render(indent: indent + 1)}').join(',\n')}\n${'    ' * indent}]';
  }
}

class MatObject extends MatValue {
  final List<MatEntry> entries;
  const MatObject(this.entries);

  MatValue? operator [](String key) {
    for (final e in entries) {
      if (e.key == key) return e.value;
    }
    return null;
  }

  @override
  String render({int indent = 0}) => '{ ${entries.map((e) => '${e.key} : ${e.value.render()}').join(', ')} }';
}

class MatEntry {
  final String key;
  final MatValue value;
  const MatEntry(this.key, this.value);
}

/// One top-level block: `name { body }`.
class MatBlock {
  final String name;
  final String body;
  const MatBlock(this.name, this.body);
}

/// A parameter the header declares.
class MatParameterDecl {
  final String type;
  final String name;
  final MatValue? defaultValue;

  /// The declaration as written, for re-emitting a parameter the graph does not model.
  final MatObject raw;
  const MatParameterDecl(this.type, this.name, this.defaultValue, this.raw);

  bool get isSampler => type.toLowerCase().startsWith('sampler');
}

class MatSource {
  final List<MatBlock> blocks;

  /// The `material` block's entries, in order; empty when there is none.
  final List<MatEntry> header;

  const MatSource(this.blocks, this.header);

  MatBlock? block(String name) {
    for (final b in blocks) {
      if (b.name == name) return b;
    }
    return null;
  }

  MatValue? headerValue(String key) {
    for (final e in header) {
      if (e.key == key) return e.value;
    }
    return null;
  }

  String? get materialName {
    final v = headerValue('name');
    if (v is MatString) return v.text;
    if (v is MatAtom) return v.text;
    return null;
  }

  List<String> get requires {
    final v = headerValue('requires');
    if (v is! MatList) return const [];
    return [for (final i in v.items) if (i is MatAtom) i.text];
  }

  List<MatParameterDecl> get parameters {
    final v = headerValue('parameters');
    if (v is! MatList) return const [];
    final out = <MatParameterDecl>[];
    for (final item in v.items) {
      if (item is! MatObject) continue;
      final type = item['type'];
      final name = item['name'];
      if (type == null || name == null) continue;
      String text(MatValue v) => v is MatString ? v.text : (v as MatAtom).text;
      if (type is MatList || name is MatList || type is MatObject || name is MatObject) continue;
      out.add(MatParameterDecl(text(type), text(name), item['default'], item));
    }
    return out;
  }

  /// Splits [source] into blocks. Throws [FormatException] on unbalanced braces.
  static MatSource parse(String source) {
    final blocks = <MatBlock>[];
    var i = 0;
    while (true) {
      i = _skipSpaceAndComments(source, i);
      if (i >= source.length) break;
      final nameMatch = RegExp(r'[A-Za-z_][A-Za-z0-9_]*').matchAsPrefix(source, i);
      if (nameMatch == null) throw FormatException('expected a block name', source, i);
      final name = nameMatch.group(0)!;
      i = _skipSpaceAndComments(source, nameMatch.end);
      if (i >= source.length || source[i] != '{') throw FormatException("expected '{' after $name", source, i);
      final close = matchingBrace(source, i);
      blocks.add(MatBlock(name, source.substring(i + 1, close)));
      i = close + 1;
    }
    final material = blocks.where((b) => b.name == 'material').firstOrNull;
    return MatSource(blocks, material == null ? const [] : _HeaderReader(material.body).entries());
  }

  /// The index of the brace closing the one at [open], skipping strings and comments.
  static int matchingBrace(String s, int open) {
    var depth = 0;
    var i = open;
    while (i < s.length) {
      final c = s[i];
      if (c == '/' && i + 1 < s.length && (s[i + 1] == '/' || s[i + 1] == '*')) {
        i = _skipComment(s, i);
        continue;
      }
      if (c == '"') {
        i = s.indexOf('"', i + 1);
        if (i < 0) break;
        i++;
        continue;
      }
      if (c == '{') depth++;
      if (c == '}') {
        depth--;
        if (depth == 0) return i;
      }
      i++;
    }
    throw FormatException('unbalanced braces', s, open);
  }

  static int _skipComment(String s, int i) {
    if (s[i + 1] == '/') {
      final end = s.indexOf('\n', i);
      return end < 0 ? s.length : end + 1;
    }
    final end = s.indexOf('*/', i + 2);
    return end < 0 ? s.length : end + 2;
  }

  static int _skipSpaceAndComments(String s, int i) {
    while (i < s.length) {
      if (s[i].trim().isEmpty) {
        i++;
      } else if (s[i] == '/' && i + 1 < s.length && (s[i + 1] == '/' || s[i + 1] == '*')) {
        i = _skipComment(s, i);
      } else {
        break;
      }
    }
    return i;
  }

  /// Renders a `material` header block from [entries].
  static String renderHeader(List<MatEntry> entries) {
    final b = StringBuffer('material {\n');
    for (var k = 0; k < entries.length; k++) {
      final e = entries[k];
      b.write('    ${e.key} : ${e.value.render(indent: 1)}');
      b.write(k == entries.length - 1 ? '\n' : ',\n');
    }
    b.write('}');
    return b.toString();
  }
}

/// Reads the `material { … }` header: `key : value` pairs separated by commas.
class _HeaderReader {
  final String s;
  int i = 0;
  _HeaderReader(this.s);

  List<MatEntry> entries() {
    final out = <MatEntry>[];
    while (true) {
      _skip();
      if (i >= s.length) break;
      if (s[i] == ',') {
        i++;
        continue;
      }
      final key = RegExp(r'[A-Za-z_][A-Za-z0-9_]*').matchAsPrefix(s, i);
      if (key == null) throw FormatException('expected a header key', s, i);
      i = key.end;
      _skip();
      if (i >= s.length || s[i] != ':') throw FormatException("expected ':' after ${key.group(0)}", s, i);
      i++;
      out.add(MatEntry(key.group(0)!, _value()));
    }
    return out;
  }

  void _skip() => i = MatSource._skipSpaceAndComments(s, i);

  MatValue _value() {
    _skip();
    if (i >= s.length) throw FormatException('expected a value', s, i);
    final c = s[i];
    if (c == '[') {
      i++;
      final items = <MatValue>[];
      while (true) {
        _skip();
        if (i < s.length && s[i] == ']') {
          i++;
          break;
        }
        items.add(_value());
        _skip();
        if (i < s.length && s[i] == ',') i++;
      }
      return MatList(items);
    }
    if (c == '{') {
      i++;
      final entries = <MatEntry>[];
      while (true) {
        _skip();
        if (i < s.length && s[i] == '}') {
          i++;
          break;
        }
        final key = RegExp(r'[A-Za-z_][A-Za-z0-9_]*').matchAsPrefix(s, i);
        if (key == null) throw FormatException('expected a key', s, i);
        i = key.end;
        _skip();
        if (i >= s.length || s[i] != ':') throw FormatException("expected ':'", s, i);
        i++;
        entries.add(MatEntry(key.group(0)!, _value()));
        _skip();
        if (i < s.length && s[i] == ',') i++;
      }
      return MatObject(entries);
    }
    if (c == '"') {
      final end = s.indexOf('"', i + 1);
      if (end < 0) throw FormatException('unterminated string', s, i);
      final text = s.substring(i + 1, end);
      i = end + 1;
      return MatString(text);
    }
    final start = i;
    while (i < s.length && !',]}\n'.contains(s[i])) {
      i++;
    }
    final text = s.substring(start, i).trim();
    if (text.isEmpty) throw FormatException('empty value', s, start);
    return MatAtom(text);
  }
}
