/// The candidate suggestions of each `.mat` completion context, built from
/// Filament's documented tables, the GLSL built-ins and what the source
/// itself declares. The static candidate lists are built once. Pure Dart.
library;

import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/filament_material_api.g.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/glsl_builtins.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/mat_api_types.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/mat_completion_item.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/mat_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/mat_header_context.dart';

class MatCompletionSources {
  const MatCompletionSources._();

  static String _lines(List<String?> parts) => parts.where((p) => p != null && p.isNotEmpty).join('\n\n');

  // --- Header ----------------------------------------------------------------

  static final Map<String, MatHeaderKeyInfo> _headerKeys = {for (final k in filamentHeaderKeys) k.name: k};

  static MatCompletionItem _headerKeyItem(MatHeaderKeyInfo k) => MatCompletionItem(
    label: k.name,
    kind: MatCompletionKind.property,
    detail: k.type,
    documentation: _lines([
      '${k.group}: ${k.name}',
      k.description,
      if (k.values.isNotEmpty) 'Values: ${k.values.join(', ')}',
      if (k.defaultValue != null) 'Default: ${k.defaultValue}',
    ]),
    insertText: '${k.name} : ',
  );

  static MatCompletionItem _entryKeyItem(MatEntryKeyInfo k) => MatCompletionItem(
    label: k.name,
    kind: MatCompletionKind.property,
    detail: k.values.isEmpty ? '' : k.values.length > 4 ? '${k.values.take(4).join(' | ')} | …' : k.values.join(' | '),
    documentation: _lines([k.description, if (k.values.isNotEmpty) 'Values: ${k.values.join(', ')}']),
    insertText: '${k.name} : ',
  );

  static MatCompletionItem _valueItem(String value, String detail, String documentation) =>
      MatCompletionItem(label: value, kind: MatCompletionKind.value, detail: detail, documentation: documentation);

  static List<MatEntryKeyInfo> _entryKeysOf(String? owner) => switch (owner) {
    'parameters' => filamentParameterEntryKeys,
    'constants' => filamentConstantEntryKeys,
    'variables' => filamentVariableEntryKeys,
    'blendFunction' => filamentBlendFunctionKeys,
    _ => const [],
  };

  static List<MatCompletionItem> header(MatDocumentIndex doc, MatHeaderContext ctx) {
    if (ctx.position == MatHeaderPosition.key) {
      if (ctx.owner == null) {
        return [
          for (final k in filamentHeaderKeys)
            if (!ctx.existingKeys.contains(k.name)) _headerKeyItem(k),
        ];
      }
      return [
        for (final k in _entryKeysOf(ctx.owner))
          if (!ctx.existingKeys.contains(k.name)) _entryKeyItem(k),
      ];
    }
    final key = ctx.key;
    if (key == null) return const [];
    if (ctx.owner == null || (ctx.inList && ctx.owner == key)) {
      final info = _headerKeys[key];
      if (info == null) return const [];
      return [
        for (final v in info.values)
          _valueItem(v, v == info.defaultValue ? 'default' : key, _lines(['${info.name} : $v', info.description])),
      ];
    }
    // A key of a nested entry: a parameter's type, a variable's precision, ….
    for (final k in _entryKeysOf(ctx.owner)) {
      if (k.name != key) continue;
      final types = switch ((ctx.owner, key)) {
        ('parameters', 'type') => filamentParameterTypes,
        ('constants', 'type') => filamentConstantTypes,
        _ => null,
      };
      if (types != null) {
        return [
          for (final t in types)
            MatCompletionItem(
              label: t.name,
              kind: MatCompletionKind.type,
              detail: t.isSampler ? 'sampler' : ctx.owner!,
              documentation: t.description,
            ),
        ];
      }
      return [for (final v in k.values) _valueItem(v, key, k.description)];
    }
    return const [];
  }

  // --- Top level -------------------------------------------------------------

  static const String _fragmentSnippet =
      'fragment {\n    void material(inout MaterialInputs material) {\n        prepareMaterial(material);\n        \n    }\n}';
  static const String _vertexSnippet =
      'vertex {\n    void materialVertex(inout MaterialVertexInputs material) {\n        \n    }\n}';
  static const String _materialSnippet = 'material {\n    name : ,\n    shadingModel : lit,\n}';

  static List<MatCompletionItem> blockSnippets(MatDocumentIndex doc) => [
    if (doc.block('material') == null)
      MatCompletionItem(
        label: 'material',
        kind: MatCompletionKind.snippet,
        detail: 'material { }',
        documentation: 'The material block: the header properties (name, shading model, parameters, …).',
        insertText: _materialSnippet,
        cursorOffsetInInsert: _materialSnippet.indexOf(' ,') + 1,
      ),
    if (doc.block('fragment') == null)
      MatCompletionItem(
        label: 'fragment',
        kind: MatCompletionKind.snippet,
        detail: 'fragment { material() }',
        documentation: 'The fragment block, with the material() function that calls prepareMaterial().',
        insertText: _fragmentSnippet,
        cursorOffsetInInsert: _fragmentSnippet.indexOf('\n    }') ,
      ),
    if (doc.block('vertex') == null)
      MatCompletionItem(
        label: 'vertex',
        kind: MatCompletionKind.snippet,
        detail: 'vertex { materialVertex() }',
        documentation: 'The optional vertex block, with the materialVertex() function.',
        insertText: _vertexSnippet,
        cursorOffsetInInsert: _vertexSnippet.indexOf('\n    }'),
      ),
  ];

  // --- Members ---------------------------------------------------------------

  static MatCompletionItem _fieldItem(MatStructFieldInfo f, String struct) => MatCompletionItem(
    label: f.name,
    kind: MatCompletionKind.field,
    detail: f.glslType,
    documentation: _lines([
      '${f.glslType} $struct.${f.name}',
      f.description,
      if (f.defaultValue != null) 'Default: ${f.defaultValue}',
      if (f.availability.isNotEmpty) 'Availability: ${f.availability}',
      if (f.apiLevel > 1) 'API level ${f.apiLevel}',
    ]),
  );

  static List<MatCompletionItem> members(MatDocumentIndex doc, String receiver, {required bool vertex}) {
    final model = doc.effectiveShadingModel;
    if (receiver == 'material' && !vertex) {
      return [
        for (final f in filamentMaterialInputs)
          if (f.availableWith(model)) _fieldItem(f, 'MaterialInputs'),
      ];
    }
    if (receiver == 'material' && vertex) {
      return [
        for (final f in filamentMaterialVertexInputs)
          if (!f.name.startsWith('variable') && f.availableWith(model)) _fieldItem(f, 'MaterialVertexInputs'),
        for (final v in doc.variables)
          MatCompletionItem(
            label: v,
            kind: MatCompletionKind.field,
            detail: 'float4',
            documentation: 'float4 MaterialVertexInputs.$v\n\nA custom interpolant the header\'s variables declare; '
                'the fragment block reads it as variable_$v.',
          ),
      ];
    }
    if (receiver == 'materialParams') {
      return [
        for (final p in doc.parameters)
          if (!p.isSampler)
            MatCompletionItem(
              label: p.name,
              kind: MatCompletionKind.field,
              detail: p.type,
              documentation: '${p.type} materialParams.${p.name}\n\nA parameter the header declares.',
            ),
      ];
    }
    return const [];
  }

  // --- Identifiers -----------------------------------------------------------

  static final List<MatCompletionItem> _vertexStatic = _buildStatic(MatStage.vertex);
  static final List<MatCompletionItem> _fragmentStatic = _buildStatic(MatStage.fragment);

  static List<MatCompletionItem> _buildStatic(MatStage stage) {
    final types = <String, MatTypeInfo>{
      for (final t in glslTypes) t.name: t,
      for (final t in filamentTypeAliases) t.name: t,
    };
    final functions = <String, List<MatFunctionInfo>>{};
    for (final f in [...filamentFunctions, ...glslBuiltinFunctions]) {
      if (f.availableIn(stage)) (functions[f.name] ??= []).add(f);
    }
    final items = <MatCompletionItem>[];
    for (final MapEntry(key: name, value: overloads) in functions.entries) {
      final first = overloads.first;
      final docs = _lines([
        overloads.map((o) => o.signature).join('\n'),
        first.description,
        [
          if (first.category.isNotEmpty) first.category,
          if (first.stage != MatStage.any) '${first.stage.name} block only',
          if (first.apiLevel > 1) 'API level ${first.apiLevel}',
        ].join(' · '),
      ]);
      final type = types[name];
      if (type != null) {
        // A constructor (vec3, float): suggested once, as the type.
        types.remove(name);
        items.add(MatCompletionItem(
          label: name,
          kind: MatCompletionKind.type,
          detail: type.glslType == name ? 'type' : type.glslType,
          documentation: _lines([type.description, docs]),
        ));
        continue;
      }
      final args = overloads.any((o) => o.hasArguments);
      items.add(MatCompletionItem(
        label: name,
        kind: MatCompletionKind.function,
        detail: overloads.length > 1 ? '${first.signature} (+${overloads.length - 1} overload)' : first.signature,
        documentation: docs,
        insertText: '$name()',
        cursorOffsetInInsert: args ? name.length + 1 : name.length + 2,
      ));
    }
    for (final t in types.values) {
      items.add(MatCompletionItem(
        label: t.name,
        kind: MatCompletionKind.type,
        detail: t.glslType == t.name || t.glslType == 'struct' ? 'type' : t.glslType,
        documentation: t.description,
      ));
    }
    for (final c in filamentConstants) {
      items.add(MatCompletionItem(label: c.name, kind: MatCompletionKind.constant, detail: c.type, documentation: c.description));
    }
    for (final k in [...glslKeywords, if (stage == MatStage.fragment) ...glslFragmentKeywords]) {
      items.add(MatCompletionItem(label: k, kind: MatCompletionKind.keyword, detail: 'keyword'));
    }
    return items;
  }

  static List<MatCompletionItem> identifiers(MatDocumentIndex doc, MatBlockRange block, int offset, {required bool vertex}) {
    final items = <MatCompletionItem>[];
    final seen = <String>{};
    for (final l in doc.localsBefore(block, offset)) {
      if (!seen.add(l.name)) continue;
      items.add(switch (l.kind) {
        MatLocalKind.function => MatCompletionItem(
          label: l.name,
          kind: MatCompletionKind.function,
          detail: '${l.type} ${l.name}${l.parameters}',
          documentation: 'Declared in this block.',
          insertText: '${l.name}()',
          cursorOffsetInInsert: l.parameters.replaceAll(RegExp(r'[()\s]'), '').isEmpty ? l.name.length + 2 : l.name.length + 1,
        ),
        MatLocalKind.parameter => MatCompletionItem(
          label: l.name, kind: MatCompletionKind.parameter, detail: l.type, documentation: 'Function parameter.'),
        MatLocalKind.variable => MatCompletionItem(
          label: l.name,
          kind: l.type == 'struct' ? MatCompletionKind.type : MatCompletionKind.variable,
          detail: l.type,
          documentation: 'Declared in this block.',
        ),
      });
    }
    if (doc.parameters.any((p) => !p.isSampler)) {
      items.add(const MatCompletionItem(
        label: 'materialParams',
        kind: MatCompletionKind.variable,
        detail: 'struct',
        documentation: 'The header\'s non-sampler parameters, as fields: materialParams.<name>.',
      ));
    }
    for (final p in doc.parameters) {
      if (!p.isSampler) continue;
      items.add(MatCompletionItem(
        label: 'materialParams_${p.name}',
        kind: MatCompletionKind.variable,
        detail: p.type,
        documentation: 'The sampler parameter ${p.name} the header declares.',
      ));
    }
    for (final c in doc.constants) {
      items.add(MatCompletionItem(
        label: 'materialConstants_${c.name}',
        kind: MatCompletionKind.constant,
        detail: c.type,
        documentation: 'The constant ${c.name} the header declares (specialized when the material is loaded).',
      ));
    }
    if (!vertex) {
      for (final v in doc.variables) {
        items.add(MatCompletionItem(
          label: 'variable_$v',
          kind: MatCompletionKind.variable,
          detail: 'float4',
          documentation: 'The custom interpolant $v the header\'s variables declare, written by the vertex block.',
        ));
      }
    }
    for (final s in vertex ? _vertexStatic : _fragmentStatic) {
      if (!seen.contains(s.label)) items.add(s);
    }
    return items;
  }
}
