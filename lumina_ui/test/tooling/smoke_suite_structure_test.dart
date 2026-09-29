import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A `testWidgets(` / `test(` / `group(` call found in a Dart source file.
class DeclaredTest {
  final String kind;
  final String? name;
  final int line;

  /// The enclosing test call's line, when this call sits inside another
  /// test's body (which throws "Can't call test() once tests have begun
  /// running" the moment the outer test runs).
  final int? nestedInLine;

  const DeclaredTest(this.kind, this.name, this.line, this.nestedInLine);
}

/// Scans [source] for test declarations and reports, for each, the test
/// call it is nested in. Comments and string literals (with their
/// `${…}` interpolations) are skipped so their braces do not count.
List<DeclaredTest> scanTestDeclarations(String source) {
  final found = <DeclaredTest>[];
  // Each open `(` / `{` / `[`; for a `(` that opens a test call, the index
  // of that call in [found].
  final stack = <(String, int?)>[];
  var line = 1;
  var i = 0;
  final n = source.length;

  bool isIdent(int c) =>
      (c >= 0x30 && c <= 0x39) || (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c == 0x5F || c == 0x24;

  /// Skips a string literal starting at [start] (at its opening quote,
  /// after any `r` prefix) and returns (end index, plain text or null).
  (int, String?) skipString(int start, bool raw) {
    final q = source[start];
    final triple = source.startsWith('$q$q$q', start);
    final close = triple ? '$q$q$q' : q;
    var j = start + close.length;
    final text = StringBuffer();
    var plain = true;
    while (j < n) {
      if (source.startsWith(close, j)) return (j + close.length, plain ? text.toString() : null);
      final ch = source[j];
      if (ch == '\n') line++;
      if (!raw && ch == r'\') {
        text.write(source[j + 1]);
        j += 2;
        continue;
      }
      if (!raw && ch == r'$') {
        plain = false;
        if (j + 1 < n && source[j + 1] == '{') {
          // Interpolated expression: skip to its matching brace, stepping
          // over nested strings.
          var depth = 1;
          j += 2;
          while (j < n && depth > 0) {
            final c = source[j];
            if (c == '\n') line++;
            if (c == "'" || c == '"') {
              j = skipString(j, false).$1;
              continue;
            }
            if (c == '{') depth++;
            if (c == '}') depth--;
            j++;
          }
          continue;
        }
      }
      text.write(ch);
      j++;
    }
    return (j, null);
  }

  while (i < n) {
    final ch = source[i];
    if (ch == '\n') {
      line++;
      i++;
      continue;
    }
    if (source.startsWith('//', i)) {
      while (i < n && source[i] != '\n') {
        i++;
      }
      continue;
    }
    if (source.startsWith('/*', i)) {
      final end = source.indexOf('*/', i + 2);
      final stop = end < 0 ? n : end + 2;
      line += '\n'.allMatches(source.substring(i, stop)).length;
      i = stop;
      continue;
    }
    if (ch == "'" || ch == '"') {
      i = skipString(i, false).$1;
      continue;
    }
    if (ch == 'r' && i + 1 < n && (source[i + 1] == "'" || source[i + 1] == '"') && (i == 0 || !isIdent(source.codeUnitAt(i - 1)))) {
      i = skipString(i + 1, true).$1;
      continue;
    }
    if (isIdent(source.codeUnitAt(i))) {
      final start = i;
      while (i < n && isIdent(source.codeUnitAt(i))) {
        i++;
      }
      final word = source.substring(start, i);
      if ((word == 'testWidgets' || word == 'test' || word == 'group') &&
          (start == 0 || source[start - 1] != '.')) {
        var j = i;
        while (j < n && (source[j] == ' ' || source[j] == '\n' || source[j] == '\t' || source[j] == '\r')) {
          if (source[j] == '\n') line++;
          j++;
        }
        if (j < n && source[j] == '(') {
          int? outer;
          for (final frame in stack.reversed) {
            final idx = frame.$2;
            if (idx != null && found[idx].kind != 'group') {
              outer = found[idx].line;
              break;
            }
          }
          final callLine = line;
          // The name: the first argument, when it is a plain string literal.
          String? name;
          var k = j + 1;
          while (k < n && (source[k] == ' ' || source[k] == '\n' || source[k] == '\t' || source[k] == '\r')) {
            k++;
          }
          if (k < n && (source[k] == "'" || source[k] == '"')) {
            final savedLine = line;
            name = skipString(k, false).$2;
            line = savedLine;
          }
          found.add(DeclaredTest(word, name, callLine, outer));
          stack.add(('(', found.length - 1));
          i = j + 1;
        }
      }
      continue;
    }
    if (ch == '(' || ch == '{' || ch == '[') {
      stack.add((ch, null));
    } else if ((ch == ')' || ch == '}' || ch == ']') && stack.isNotEmpty) {
      stack.removeLast();
    }
    i++;
  }
  return found;
}

void main() {
  group('scanTestDeclarations', () {
    test('finds top-level tests and their names', () {
      final tests = scanTestDeclarations('''
void main() {
  testWidgets('first', (tester) async {
    final s = "braces { in a string";
    final t = 'interpolated \${a.map((e) => '}').join()}';
  });
  testWidgets("second", (tester) async {});
}
''');
      expect(tests.map((t) => (t.name, t.nestedInLine)), [('first', null), ('second', null)]);
    });

    test('reports a test declared inside another test body', () {
      final tests = scanTestDeclarations('''
void main() {
  testWidgets('outer', (tester) async {
    try {
    } finally {
      cleanup();
      testWidgets('inner', (tester) async {});
    }
  });
}
''');
      final inner = tests.singleWhere((t) => t.name == 'inner');
      expect(inner.nestedInLine, 2);
      expect(inner.line, 6);
    });

    test('tests inside groups are not nested tests', () {
      final tests = scanTestDeclarations('''
void main() {
  group('g', () {
    test('a', () {});
  });
}
''');
      expect(tests.singleWhere((t) => t.name == 'a').nestedInLine, isNull);
    });
  });

  // The Details smoke declared three copies of one test inside
  // another test's body, so the file failed with "Can't call test() once
  // tests have begun running" and the multi-edit scenarios never ran.
  test('every smoke test file declares its tests at the top level, each name once', () {
    final files = [
      ...Directory('integration_test/smoke').listSync(),
      ...Directory('test/smoke').listSync(),
    ].whereType<File>().where((f) => f.path.endsWith('_test.dart')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, isNotEmpty);

    final problems = <String>[];
    for (final file in files) {
      final tests = scanTestDeclarations(file.readAsStringSync()).where((t) => t.kind != 'group').toList();
      for (final t in tests.where((t) => t.nestedInLine != null)) {
        problems.add('${file.path}:${t.line}: "${t.name}" is declared inside the test at line ${t.nestedInLine}');
      }
      final seen = <String>{};
      for (final t in tests) {
        if (t.name != null && !seen.add(t.name!)) {
          problems.add('${file.path}:${t.line}: "${t.name}" is declared more than once');
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
