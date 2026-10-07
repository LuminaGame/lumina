/// Parses Filament's material documentation (`docs_src/src_markdeep/
/// Materials.md.html`, published as https://google.github.io/filament/Materials.md.html)
/// into the `.mat` language tables: header keys, `MaterialInputs` and
/// `MaterialVertexInputs` fields, shader functions, type aliases and
/// constants. Pure Dart; the caller reads the file.
library;

import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/mat_api_types.dart';

/// Everything the `.mat` completion needs from the documentation.
class FilamentMaterialDoc {
  final List<MatHeaderKeyInfo> headerKeys;
  final List<MatParamTypeInfo> parameterTypes;
  final List<MatParamTypeInfo> constantTypes;
  final List<String> precisions;
  final List<MatEntryKeyInfo> parameterEntryKeys;
  final List<MatEntryKeyInfo> constantEntryKeys;
  final List<MatEntryKeyInfo> variableEntryKeys;
  final List<MatEntryKeyInfo> blendFunctionKeys;
  final List<MatStructFieldInfo> fragmentInputs;
  final List<MatStructFieldInfo> vertexInputs;
  final List<MatFunctionInfo> functions;
  final List<MatTypeInfo> typeAliases;
  final List<MatConstantInfo> constants;

  const FilamentMaterialDoc({
    required this.headerKeys,
    required this.parameterTypes,
    required this.constantTypes,
    required this.precisions,
    required this.parameterEntryKeys,
    required this.constantEntryKeys,
    required this.variableEntryKeys,
    required this.blendFunctionKeys,
    required this.fragmentInputs,
    required this.vertexInputs,
    required this.functions,
    required this.typeAliases,
    required this.constants,
  });

  /// The headings of the "Shader public APIs" tables the functions come from.
  static const apiTables = [
    'Math',
    'Matrices',
    'Frame constants',
    'Material globals',
    'Vertex only',
    'Fragment only',
  ];

  static FilamentMaterialDoc parse(String html) => _DocParser(html).parse();

  /// Every function name the "Shader public APIs" tables list, with
  /// `getCustom0()` to `getCustom7()` expanded; for checking the tables.
  static Set<String> listedFunctionNames(String html) {
    final parser = _DocParser(html);
    final names = <String>{};
    for (final table in apiTables) {
      for (final row in parser.boldRows(parser.section(table, level: 3))) {
        for (final sig in _expandRange(row.first)) {
          final open = sig.indexOf('(');
          if (open > 0) names.add(sig.substring(0, open));
        }
      }
    }
    return names;
  }
}

/// A heading and the lines up to the next heading of the same or a higher level.
class _Section {
  final String title;
  final int level;
  final List<String> lines;
  const _Section(this.title, this.level, this.lines);
}

/// Strips Markdeep markup from documentation prose.
/// Marks the items of a flattened `- item` list with bullets.
String _bullets(String text) => text.replaceAllMapped(RegExp(r'(^|\s)- '), (m) => '${m[1]}• ');

String cleanDocText(String text) {
  var t = text;
  t = t.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m[1]!);
  t = t.replaceAll(r'\frac{\pi}{2}', 'π/2').replaceAll(r'\pi', 'π');
  t = t.replaceAllMapped(RegExp(r'\\sqrt\{([^}]*)\}'), (m) => 'sqrt(${m[1]})');
  t = t.replaceAll(r'\cdot', '·');
  t = t.replaceAll(r'$', '');
  t = t.replaceAll('**', '').replaceAll('`', '');
  t = t.replaceAllMapped(RegExp(r'(^|[\s(])[*_]([^*_\s][^*_]*?)[*_](?=[\s.,:;)]|$)'), (m) => '${m[1]}${m[2]}');
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// `getCustom0()** to **getCustom7()` → `getCustom0()`, …, `getCustom7()`.
List<String> _expandRange(String cell) {
  final range = RegExp(r'^\*\*(\w*?)(\d+)\((.*?)\)\*\*\s+to\s+\*\*\1(\d+)\(\3\)\*\*$').firstMatch(cell.trim());
  if (range != null) {
    final from = int.parse(range[2]!);
    final to = int.parse(range[4]!);
    return [for (var i = from; i <= to; i++) '${range[1]}$i(${range[3]})'];
  }
  final bold = RegExp(r'^\*\*(.+)\*\*$').firstMatch(cell.trim());
  return [bold != null ? bold[1]! : cell.trim()];
}

class _DocParser {
  final List<String> lines;
  late final List<_Section> sections = _sections();

  _DocParser(String html) : lines = html.replaceAll('\r\n', '\n').split('\n');

  List<_Section> _sections() {
    final heads = <(int, int, String)>[];
    var fenced = false;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trimLeft().startsWith('~~~~')) {
        fenced = !fenced;
        continue;
      }
      if (fenced) continue;
      final m = RegExp(r'^(#+) (.+)$').firstMatch(line);
      if (m != null) heads.add((i, m[1]!.length, m[2]!.trim()));
    }
    final out = <_Section>[];
    for (var h = 0; h < heads.length; h++) {
      final (start, level, title) = heads[h];
      var end = lines.length;
      for (var n = h + 1; n < heads.length; n++) {
        if (heads[n].$2 <= level) {
          end = heads[n].$1;
          break;
        }
      }
      out.add(_Section(title, level, lines.sublist(start + 1, end)));
    }
    return out;
  }

  _Section section(String title, {int? level}) => sections.firstWhere(
    (s) => s.title == title && (level == null || s.level == level),
    orElse: () => throw FormatException('section "$title" not found in the material documentation'),
  );

  /// The first paragraph of the definition [term] (`Type`, `Value`, …).
  String? definition(_Section s, String term) {
    for (var i = 0; i + 1 < s.lines.length; i++) {
      if (s.lines[i].trim() != term || !s.lines[i + 1].startsWith(':')) continue;
      final buf = <String>[s.lines[i + 1].substring(1)];
      for (var j = i + 2; j < s.lines.length; j++) {
        final l = s.lines[j];
        // A blank line ends the paragraph unless an indented list follows.
        if (l.trim().isEmpty && j + 1 < s.lines.length && RegExp(r'^\s+- ').hasMatch(s.lines[j + 1])) continue;
        if (l.trim().isEmpty || l.trimLeft().startsWith('~~~~') || l.trimLeft().contains('|')) break;
        buf.add(l);
      }
      return buf.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    return null;
  }

  /// Table rows whose first cell is bold (`**name** | …`), split into cells.
  List<List<String>> boldRows(_Section s) => [
    for (final l in s.lines)
      if (l.trimLeft().startsWith('**') && l.contains('|')) l.split('|').map((c) => c.trim()).toList(),
  ];

  /// The body rows of the table captioned `[Table [id]: …]`.
  List<List<String>> captionedRows(String id) {
    final caption = lines.indexWhere((l) => l.trim().startsWith('[Table [$id]'));
    if (caption < 0) throw FormatException('table $id not found in the material documentation');
    final rows = <List<String>>[];
    for (var i = caption - 1; i >= 0; i--) {
      final l = lines[i];
      if (l.contains('---')) break;
      rows.insert(0, l.split('|').map((c) => c.trim()).toList());
    }
    return rows;
  }

  FilamentMaterialDoc parse() {
    final headerKeys = _headerKeys();
    final shadingModels = headerKeys.firstWhere((k) => k.name == 'shadingModel').values;
    final params = section('General: parameters', level: 3);
    final paramValue = definition(params, 'Value') ?? '';
    final precisions = _backticked(
      RegExp(r'can be\s+one of (.*?)\. The type').firstMatch(paramValue)?[1]?.replaceAll(RegExp(r'\([^)]*\)'), '') ?? '',
    );
    final parameterTypes = [
      for (final r in captionedRows('materialParamsTypes')) MatParamTypeInfo(r[0], cleanDocText(r[1])),
    ];
    final constantTypes = [
      for (final r in captionedRows('materialConstantsTypes'))
        MatParamTypeInfo(r[0], '${cleanDocText(r[1])}. Defaults to ${r[2]}.'),
    ];
    final paramName = 'The parameter name. ${cleanDocText(RegExp(r'The\s+name must be a valid GLSL identifier\.').firstMatch(paramValue)?[0] ?? '')}'.trim();
    final parameterEntryKeys = <MatEntryKeyInfo>[
      MatEntryKeyInfo('type', [for (final t in parameterTypes) t.name], 'The parameter type.'),
      MatEntryKeyInfo('name', const [], paramName),
      MatEntryKeyInfo('precision', precisions, 'The precision of the parameter.'),
      ..._samplerFields(params),
      const MatEntryKeyInfo('transformName', [], 'Android external textures: the name of the material parameter '
          'that exposes the transform matrix of the external sampler.'),
    ];
    final constants = section('General: constants', level: 3);
    final constantEntryKeys = <MatEntryKeyInfo>[
      MatEntryKeyInfo('name', const [], 'The constant name, a valid GLSL identifier.'),
      MatEntryKeyInfo('type', [for (final t in constantTypes) t.name], 'The constant type.'),
      MatEntryKeyInfo('default', const [], 'Optional ${cleanDocText(
        RegExp(r'Entries also have an optional (.*?)\. The type').firstMatch(definition(constants, 'Value') ?? '')?[1] ?? '',
      )}.'),
    ];
    final variableEntryKeys = <MatEntryKeyInfo>[
      const MatEntryKeyInfo('name', [], 'The interpolant name, a valid GLSL identifier.'),
      MatEntryKeyInfo('precision', precisions, 'The interpolant precision, used as-is in the vertex and fragment stages.'),
    ];
    final blend = section('Blending and transparency: blendFunction', level: 3);
    final blendText = blend.lines.join(' ');
    final blendValues = _backticked(RegExp(r'one of (.*?)~~~~').firstMatch(blendText)?[1] ?? '');
    final blendFunctionKeys = [
      for (final f in _backticked(definition(blend, 'Fields') ?? ''))
        MatEntryKeyInfo(f, blendValues, _blendFieldDescription(f)),
    ];
    final props = _propertyDocs();
    return FilamentMaterialDoc(
      headerKeys: headerKeys,
      parameterTypes: parameterTypes,
      constantTypes: constantTypes,
      precisions: precisions,
      parameterEntryKeys: parameterEntryKeys,
      constantEntryKeys: constantEntryKeys,
      variableEntryKeys: variableEntryKeys,
      blendFunctionKeys: blendFunctionKeys,
      fragmentInputs: _structFields('MaterialInputs', shadingModels, props),
      vertexInputs: _structFields('MaterialVertexInputs', shadingModels, props),
      functions: _functions(),
      typeAliases: [
        for (final r in boldRows(section('Types', level: 3)))
          MatTypeInfo(_expandRange(r[0]).single, r[1], cleanDocText(r[2])),
      ],
      constants: [
        for (final r in boldRows(section('Math', level: 3)))
          if (!r[0].contains('(')) MatConstantInfo(_expandRange(r[0]).single, r[1], cleanDocText(r[2])),
      ],
    );
  }

  static String _blendFieldDescription(String field) {
    final channel = field.endsWith('RGB') ? 'RGB channels' : 'alpha channel';
    final side = field.startsWith('src') ? 'Source' : 'Destination';
    return '$side blend function applied to the $channel.';
  }

  List<MatEntryKeyInfo> _samplerFields(_Section params) {
    final out = <MatEntryKeyInfo>[];
    for (final l in params.lines) {
      final m = RegExp(r'^\s*- `(\w+)` : (.*)$').firstMatch(l);
      if (m == null) continue;
      final text = m[2]!;
      var values = _backticked(text.split('(defaults').first);
      if (values.isEmpty && text.contains('boolean')) values = const ['true', 'false'];
      out.add(MatEntryKeyInfo(m[1]!, values, 'Samplers: ${cleanDocText(text)}'));
    }
    return out;
  }

  static List<String> _backticked(String text) {
    final out = <String>[];
    final tokens = RegExp(r'`([^`]+)`').allMatches(text).map((m) => m[1]!).toList();
    for (var i = 0; i < tokens.length; i++) {
      final range = RegExp(r'^(\D+)(\d+)$');
      final a = range.firstMatch(tokens[i]);
      final through = i + 1 < tokens.length && RegExp('`${RegExp.escape(tokens[i])}`\\s+through\\s+`').hasMatch(text);
      if (a != null && through) {
        final b = range.firstMatch(tokens[i + 1]);
        if (b != null && b[1] == a[1]) {
          for (var n = int.parse(a[2]!); n <= int.parse(b[2]!); n++) {
            if (!out.contains('${a[1]}$n')) out.add('${a[1]}$n');
          }
          i++;
          continue;
        }
      }
      if (!out.contains(tokens[i])) out.add(tokens[i]);
    }
    return out;
  }

  List<MatHeaderKeyInfo> _headerKeys() {
    final out = <MatHeaderKeyInfo>[];
    for (final s in sections) {
      if (s.level != 3) continue;
      final m = RegExp(r'^([\w -]+): (\w+)$').firstMatch(s.title);
      if (m == null) continue;
      final type = cleanDocText(definition(s, 'Type') ?? '');
      final value = definition(s, 'Value') ?? '';
      final valuePart = value.split(RegExp(r'Defaults to|, set to')).first;
      var values = valuePart.contains('between') || valuePart.startsWith('Each entry is an object')
          ? <String>[]
          : _backticked(valuePart);
      if (values.isEmpty) {
        final either = RegExp(r'either ([\d, or]+)').firstMatch(valuePart);
        if (either != null) values = RegExp(r'\d+').allMatches(either[1]!).map((d) => d[0]!).toList();
      }
      final def = RegExp(r'Defaults to (.*?)(?:\.\s|\.$)').firstMatch(value)?[1] ??
          RegExp(r'set to (\S+) by default').firstMatch(value)?[1];
      out.add(MatHeaderKeyInfo(
        name: m[2]!,
        group: m[1]!,
        type: type,
        values: values,
        defaultValue: def == null ? null : cleanDocText(def),
        description: _bullets(cleanDocText(definition(s, 'Description') ?? '')),
      ));
    }
    // `apiLevel` is described in its own chapter rather than as a header section.
    final api = section('Material API level', level: 1);
    final define = section('Define `apiLevel` in `.mat` files', level: 2);
    final intro = api.lines.takeWhile((l) => l.trim().isNotEmpty).join(' ');
    out.add(MatHeaderKeyInfo(
      name: 'apiLevel',
      group: 'General',
      type: 'number',
      defaultValue: RegExp(r'defaults to (\d+)').firstMatch(define.lines.join(' '))?[1],
      description: cleanDocText(intro),
    ));
    return out;
  }

  /// Property name → (description, api level), from the material model tables.
  Map<String, (String, int)> _propertyDocs() {
    final docs = <String, String>{};
    final notes = <String, String>{};
    final levels = <String, int>{};
    final models = section('Material models', level: 1);
    for (final row in boldRows(models)) {
      final name = _expandRange(row[0]).single;
      if (row.length == 2) {
        final level = int.tryParse(row[1]);
        if (level != null) {
          levels.putIfAbsent(name, () => level);
        } else {
          docs.putIfAbsent(name, () => cleanDocText(row[1]));
        }
      } else if (row.length >= 4) {
        final note = cleanDocText(row[3]);
        notes.putIfAbsent(name, () => 'Range ${row[2]}${note.isEmpty ? '' : '. $note'}.');
      }
    }
    return {
      for (final name in {...docs.keys, ...notes.keys})
        name: ([if (docs[name] != null) '${docs[name]}.', if (notes[name] != null) notes[name]!].join(' '), levels[name] ?? 1),
    };
  }

  List<MatStructFieldInfo> _structFields(
    String struct,
    List<String> allModels,
    Map<String, (String, int)> props,
  ) {
    final start = lines.indexWhere((l) => l.trim() == 'struct $struct {');
    if (start < 0) throw FormatException('struct $struct not found in the material documentation');
    List<String> modelsIn(String text) => [
      for (final m in allModels)
        if (RegExp('\\b$m\\b').hasMatch(text)) m,
    ];
    var base = List<String>.of(allModels);
    var section = base;
    final notes = <String>[];
    final order = <String>[];
    final fields = <String, MatStructFieldInfo>{};
    for (var i = start + 1; i < lines.length && !lines[i].trim().startsWith('}'); i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        section = base;
        notes.clear();
        continue;
      }
      if (line.startsWith('//')) {
        final c = line.substring(2).trim();
        final noOther = RegExp(r'no other field is available with the (\w+) shading model').firstMatch(c);
        if (noOther != null) {
          base = [for (final m in allModels) if (m != noOther[1]) m];
          section = base;
          continue;
        }
        final notWhen = RegExp(r'not available when the shading model is (.+)').firstMatch(c);
        final onlyWhen = RegExp(r'only available when the shading model is (.+)').firstMatch(c);
        if (notWhen != null) {
          final excluded = modelsIn(notWhen[1]!);
          section = [for (final m in section) if (!excluded.contains(m)) m];
        } else if (onlyWhen != null && !c.contains('refraction')) {
          section = modelsIn(onlyWhen[1]!);
        }
        notes.add(c);
        continue;
      }
      final f = RegExp(r'^(\w+)\s+(\w+);\s*(?://\s*(.*))?$').firstMatch(line);
      if (f == null) continue;
      final type = f[1]!;
      final name = f[2]!;
      final comment = f[3] ?? '';
      String? def;
      var rest = comment;
      final d = RegExp(r'^default:?\s*').firstMatch(comment);
      if (d != null) {
        final body = comment.substring(d.end);
        var depth = 0;
        var cut = body.length;
        for (var k = 0; k < body.length; k++) {
          final ch = body[k];
          if (ch == '(') depth++;
          if (ch == ')') depth--;
          if (ch == ',' && depth == 0) {
            cut = k;
            break;
          }
        }
        def = body.substring(0, cut).trim();
        rest = cut < body.length ? body.substring(cut + 1).trim() : '';
      }
      var models = List<String>.of(section);
      final notWith = RegExp(r'not available with (\w+(?: or \w+)*)$').firstMatch(rest);
      if (notWith != null && modelsIn(notWith[1]!).isNotEmpty) {
        final excluded = modelsIn(notWith[1]!);
        models = [for (final m in models) if (!excluded.contains(m)) m];
      }
      final notModel = RegExp(r'only if the shading model is not (\w+)').firstMatch(rest);
      if (notModel != null) models = [for (final m in models) if (m != notModel[1]) m];
      final availability = cleanDocText([...notes, if (rest.isNotEmpty) rest].join('; '));
      final prop = props[name];
      final info = MatStructFieldInfo(
        name: name,
        glslType: type,
        defaultValue: def,
        shadingModels: models.length == allModels.length ? const [] : models,
        availability: availability,
        description: prop?.$1 ?? '',
        apiLevel: prop?.$2 ?? 1,
      );
      final previous = fields[name];
      if (previous == null) {
        order.add(name);
        fields[name] = info;
      } else {
        final merged = {...previous.shadingModels, ...info.shadingModels}.toList();
        fields[name] = MatStructFieldInfo(
          name: name,
          glslType: previous.glslType,
          defaultValue: previous.defaultValue == info.defaultValue || info.defaultValue == null
              ? previous.defaultValue
              : '${previous.defaultValue} (${info.shadingModels.join(', ')}: ${info.defaultValue})',
          shadingModels: merged.length == allModels.length ? const [] : merged,
          availability: [previous.availability, info.availability].where((a) => a.isNotEmpty).join('; '),
          description: previous.description,
          apiLevel: previous.apiLevel,
        );
      }
    }
    return [for (final n in order) fields[n]!];
  }

  List<MatFunctionInfo> _functions() {
    final out = <MatFunctionInfo>[];
    for (final table in FilamentMaterialDoc.apiTables) {
      final s = section(table, level: 3);
      final stage = switch (table) {
        'Vertex only' => MatStage.vertex,
        'Fragment only' => MatStage.fragment,
        _ => MatStage.any,
      };
      for (final row in boldRows(s)) {
        final hasLevel = row.length >= 4;
        final ret = row[1];
        final level = hasLevel ? int.tryParse(row[2]) ?? 1 : 1;
        final description = cleanDocText(row[hasLevel ? 3 : 2]);
        for (final sig in _expandRange(row[0])) {
          final open = sig.indexOf('(');
          if (open < 0) continue; // a constant (PI)
          out.add(MatFunctionInfo(
            name: sig.substring(0, open),
            signature: '$ret $sig',
            returnType: ret,
            stage: stage,
            description: description,
            apiLevel: level,
            category: table,
          ));
        }
      }
    }
    final prepare = section('prepareMaterial function', level: 3);
    out.add(MatFunctionInfo(
      name: 'prepareMaterial',
      signature: 'void prepareMaterial(inout MaterialInputs material)',
      returnType: 'void',
      stage: MatStage.fragment,
      description: cleanDocText(prepare.lines.skipWhile((l) => l.trim().isEmpty).takeWhile((l) => l.trim().isNotEmpty).join(' ')),
      category: 'Fragment block',
    ));
    return out;
  }
}
