/// A tolerant index of a `.mat` source for code completion: its top-level
/// blocks, its comments and strings, what the `material` header declares
/// (shading model, parameters, constants, variables, required attributes)
/// and the declarations inside the `vertex` / `fragment` blocks. Unlike
/// `MatSource.parse` it never throws, so it works on a source being typed.
/// Pure Dart, no Flutter imports.
library;

import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/filament_material_api.g.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/glsl_builtins.dart';

/// One top-level block, `name { … }`.
class MatBlockRange {
  final String name;

  /// The offset just after the block's `{`.
  final int bodyStart;

  /// The offset of the matching `}`, or the source length when unclosed.
  final int bodyEnd;
  const MatBlockRange(this.name, this.bodyStart, this.bodyEnd);

  bool contains(int offset) => offset >= bodyStart && offset <= bodyEnd;
}

/// A `parameters` or `constants` entry of the header.
class MatDeclaredParam {
  final String name;
  final String type;
  const MatDeclaredParam(this.name, this.type);
  bool get isSampler => type.startsWith('sampler');
}

enum MatLocalKind { variable, parameter, function }

/// A declaration inside a shader block: `float3 tint`, a function parameter
/// (`inout MaterialInputs material`) or a function (`float noise(float2 p)`).
class MatLocal {
  final String name;
  final String type;
  final MatLocalKind kind;

  /// Where the name is declared.
  final int offset;

  /// A function's parameter list as written, `(float2 p)`.
  final String parameters;
  const MatLocal(this.name, this.type, this.kind, this.offset, {this.parameters = ''});
}

class MatDocumentIndex {
  final String source;

  /// The source with every comment replaced by spaces (strings kept).
  final String masked;

  /// Comment and string spans: an offset `o` is inside span `i` when
  /// `_starts[i] < o < _ends[i]`.
  final List<int> _starts;
  final List<int> _ends;

  final List<MatBlockRange> blocks;

  /// The header's `shadingModel`, null when it does not set one.
  final String? shadingModel;
  final List<MatDeclaredParam> parameters;
  final List<MatDeclaredParam> constants;
  final List<String> variables;
  final List<String> requires;

  /// The declarations of the `vertex` and `fragment` blocks, by offset.
  final List<MatLocal> locals;

  MatDocumentIndex._(
    this.source,
    this.masked,
    this._starts,
    this._ends,
    this.blocks, {
    required this.shadingModel,
    required this.parameters,
    required this.constants,
    required this.variables,
    required this.requires,
    required this.locals,
  });

  static MatDocumentIndex? _last;

  /// The index of [source]; the last one is cached, so repeated queries on
  /// the same text (moving through the suggestions) scan it once.
  static MatDocumentIndex of(String source) {
    final last = _last;
    if (last != null && (identical(last.source, source) || last.source == source)) return last;
    return _last = _build(source);
  }

  /// The shading model in effect: the header's, else Filament's default.
  String get effectiveShadingModel =>
      shadingModel ?? filamentHeaderKeys.firstWhere((k) => k.name == 'shadingModel').defaultValue ?? 'lit';

  bool isInCommentOrString(int offset) {
    // Spans are sorted by start; find the last span starting before offset.
    var lo = 0;
    var hi = _starts.length - 1;
    var found = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (_starts[mid] < offset) {
        found = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return found >= 0 && offset < _ends[found];
  }

  /// The top-level block whose body holds [offset]; null outside every block.
  MatBlockRange? blockAt(int offset) {
    for (final b in blocks) {
      if (b.contains(offset)) return b;
    }
    return null;
  }

  MatBlockRange? block(String name) {
    for (final b in blocks) {
      if (b.name == name) return b;
    }
    return null;
  }

  /// The declarations of [block] made before [offset].
  Iterable<MatLocal> localsBefore(MatBlockRange block, int offset) =>
      locals.where((l) => l.offset >= block.bodyStart && l.offset < offset && l.offset <= block.bodyEnd);

  static bool _isIdent(int c) =>
      (c >= 0x61 && c <= 0x7A) || (c >= 0x41 && c <= 0x5A) || (c >= 0x30 && c <= 0x39) || c == 0x5F;

  static MatDocumentIndex _build(String s) {
    final starts = <int>[];
    final ends = <int>[];
    final masked = StringBuffer();
    final blocks = <MatBlockRange>[];
    var depth = 0;
    String? pendingName;
    String? openName;
    var openBody = 0;
    var i = 0;
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (c == 0x2F && i + 1 < s.length && s.codeUnitAt(i + 1) == 0x2F) {
        var end = s.indexOf('\n', i);
        if (end < 0) end = s.length;
        starts.add(i);
        ends.add(end + 1);
        masked.write(' ' * (end - i));
        i = end;
        continue;
      }
      if (c == 0x2F && i + 1 < s.length && s.codeUnitAt(i + 1) == 0x2A) {
        final close = s.indexOf('*/', i + 2);
        final end = close < 0 ? s.length : close + 2;
        starts.add(i);
        ends.add(close < 0 ? s.length + 1 : end);
        masked.write(s.substring(i, end).replaceAll(RegExp(r'[^\n]'), ' '));
        i = end;
        continue;
      }
      if (c == 0x22) {
        var j = i + 1;
        while (j < s.length && s.codeUnitAt(j) != 0x22 && s.codeUnitAt(j) != 0x0A) {
          j++;
        }
        final closed = j < s.length && s.codeUnitAt(j) == 0x22;
        starts.add(i);
        ends.add(j + 1); // an unclosed string runs to the end of its line
        final end = closed ? j + 1 : j;
        masked.write(s.substring(i, end));
        i = end;
        continue;
      }
      if (depth == 0 && _isIdent(c)) {
        var j = i;
        while (j < s.length && _isIdent(s.codeUnitAt(j))) {
          j++;
        }
        pendingName = s.substring(i, j);
        masked.write(pendingName);
        i = j;
        continue;
      }
      if (c == 0x7B) {
        if (depth == 0) {
          openName = pendingName ?? '';
          openBody = i + 1;
        }
        depth++;
      } else if (c == 0x7D && depth > 0) {
        depth--;
        if (depth == 0 && openName != null) {
          blocks.add(MatBlockRange(openName, openBody, i));
          openName = null;
          pendingName = null;
        }
      } else if (depth == 0 && c != 0x20 && c != 0x0A && c != 0x0D && c != 0x09) {
        pendingName = null;
      }
      masked.writeCharCode(c);
      i++;
    }
    if (openName != null) blocks.add(MatBlockRange(openName, openBody, s.length));
    final m = masked.toString();

    final header = blocks.where((b) => b.name == 'material').firstOrNull;
    final headerText = header == null ? '' : m.substring(header.bodyStart, header.bodyEnd);
    final locals = <MatLocal>[];
    final structs = <String>{};
    for (final b in blocks) {
      if (b.name == 'vertex' || b.name == 'fragment') _scanLocals(m, b, locals, structs);
    }
    return MatDocumentIndex._(
      s,
      m,
      starts,
      ends,
      blocks,
      shadingModel: RegExp(r'\bshadingModel\s*:\s*"?(\w+)').firstMatch(headerText)?[1],
      parameters: _entries(headerText, 'parameters'),
      constants: _entries(headerText, 'constants'),
      variables: _variables(headerText),
      requires: [
        for (final w in RegExp(r'\w+').allMatches(_listBody(headerText, 'requires') ?? '')) w[0]!,
      ],
      locals: locals,
    );
  }

  /// The text inside `key : [ … ]` of the header, or null.
  static String? _listBody(String header, String key) {
    final open = RegExp('\\b$key\\s*:\\s*\\[').firstMatch(header);
    if (open == null) return null;
    var depth = 1;
    for (var i = open.end; i < header.length; i++) {
      final c = header[i];
      if (c == '[') depth++;
      if (c == ']' && --depth == 0) return header.substring(open.end, i);
    }
    return header.substring(open.end);
  }

  static List<MatDeclaredParam> _entries(String header, String key) {
    final body = _listBody(header, key);
    if (body == null) return const [];
    final out = <MatDeclaredParam>[];
    for (final obj in RegExp(r'\{([^{}]*)\}?').allMatches(body)) {
      final text = obj[1]!;
      final name = RegExp(r'\bname\s*:\s*"?(\w+)').firstMatch(text)?[1];
      final type = RegExp(r'\btype\s*:\s*"?(\w+(?:\[\d+\])?)').firstMatch(text)?[1];
      if (name != null) out.add(MatDeclaredParam(name, type ?? ''));
    }
    return out;
  }

  static List<String> _variables(String header) {
    final body = _listBody(header, 'variables');
    if (body == null) return const [];
    final out = <String>[];
    final objects = RegExp(r'\{[^{}]*\}?');
    for (final obj in objects.allMatches(body)) {
      final name = RegExp(r'\bname\s*:\s*"?(\w+)').firstMatch(obj[0]!)?[1];
      if (name != null) out.add(name);
    }
    for (final w in RegExp(r'(?:^|,)\s*"?([A-Za-z_]\w*)"?\s*(?=,|$)').allMatches(body.replaceAll(objects, ''))) {
      out.add(w[1]!);
    }
    return out;
  }

  static final Set<String> _knownTypes = {
    for (final t in glslTypes) t.name,
    for (final t in filamentTypeAliases) t.name,
    'float3x3',
    'float4x4',
  };

  static final RegExp _qualifiers = RegExp(r'\b(?:const|in|out|inout|highp|mediump|lowp|flat|smooth)\s+$');

  static void _scanLocals(String m, MatBlockRange b, List<MatLocal> out, Set<String> structs) {
    final body = m.substring(b.bodyStart, b.bodyEnd);
    for (final st in RegExp(r'\bstruct\s+(\w+)').allMatches(body)) {
      structs.add(st[1]!);
      out.add(MatLocal(st[1]!, 'struct', MatLocalKind.variable, b.bodyStart + st.start + st[0]!.lastIndexOf(st[1]!)));
    }
    final decl = RegExp(r'\b([A-Za-z_]\w*)\s+([A-Za-z_]\w*)\s*(\[[^\]]*\])?\s*(?=[=;,)(])');
    var parenDepth = 0;
    var scanned = 0;
    for (final d in decl.allMatches(body)) {
      final type = d[1]!;
      if (!_knownTypes.contains(type) && !structs.contains(type)) continue;
      final name = d[2]!;
      if (_knownTypes.contains(name) || glslKeywords.contains(name)) continue;
      for (; scanned < d.start; scanned++) {
        final c = body[scanned];
        if (c == '(') parenDepth++;
        if (c == ')' && parenDepth > 0) parenDepth--;
      }
      final next = body[d.end];
      if (next == '(') {
        // The entry points are called by Filament, never by the material.
        if (name == 'material' || name == 'materialVertex') continue;
        final close = body.indexOf(')', d.end);
        out.add(MatLocal(name, type, MatLocalKind.function, b.bodyStart + d.start + d[0]!.indexOf(d[2]!, d[1]!.length),
            parameters: body.substring(d.end, close < 0 ? body.length : close + 1)));
        continue;
      }
      var before = body.substring(d.start < 48 ? 0 : d.start - 48, d.start).trimRight();
      final q = _qualifiers.firstMatch('$before ');
      if (q != null) before = before.substring(0, q.start).trimRight();
      final isParam = parenDepth > 0 && (before.endsWith('(') || before.endsWith(','));
      out.add(MatLocal(name, type, isParam ? MatLocalKind.parameter : MatLocalKind.variable, b.bodyStart + d.start + d[0]!.indexOf(d[2]!, d[1]!.length)));
    }
  }
}
