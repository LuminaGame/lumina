/// Merges the `.mat` tables read from Filament's material documentation with
/// what its source says (`filament_material_code.dart`). The source decides
/// what is valid: the values a key accepts, the keys, fields and shader
/// functions the documentation leaves out, and what is deprecated. The
/// documentation still supplies the descriptions, groups and defaults.
library;

import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/mat_api_types.dart';

import 'filament_material_code.dart';
import 'filament_material_doc.dart';

/// The group of the header keys the documentation does not describe.
const undocumentedGroup = 'Not in the documentation';

FilamentMaterialDoc mergeFilamentMaterialCode(FilamentMaterialDoc doc, FilamentMaterialCode code) {
  final codeKeys = {for (final k in code.headerKeys) k.name: k};
  final headerKeys = <MatHeaderKeyInfo>[
    for (final k in doc.headerKeys) _mergeKey(k, codeKeys[k.name]),
    for (final c in code.headerKeys)
      if (!doc.headerKeys.any((k) => k.name == c.name))
        MatHeaderKeyInfo(
          name: c.name,
          group: undocumentedGroup,
          type: c.typeName,
          values: c.jsonType == 'BOOL' ? const ['true', 'false'] : c.values,
          description: c.builderDoc.isEmpty
              ? 'matc accepts this key; neither the material documentation nor MaterialBuilder describes it.'
              : c.builderDoc,
          documented: false,
          removedValues: c.ignored,
          valueAliases: c.aliases,
        ),
  ];

  final docParamTypes = {for (final t in doc.parameterTypes) t.name};
  final parameterTypes = [
    ...doc.parameterTypes,
    for (final MapEntry(key: name, value: canonical) in code.parameterTypes.entries)
      if (!docParamTypes.contains(name))
        MatParamTypeInfo(
          name,
          canonical != name
              ? 'Same as $canonical (filamat accepts both spellings).'
              : 'Accepted by filamat; the material documentation does not list it.',
        ),
  ];

  final blendFunctionKeys = [
    for (final k in doc.blendFunctionKeys)
      MatEntryKeyInfo(k.name, code.blendFunctions.isEmpty ? k.values : _ordered(k.values, code.blendFunctions), k.description),
  ];

  final docFields = {for (final f in doc.fragmentInputs) f.name};
  final propertyDocs = doc.propertyDescriptions;
  // The shaders declare some fields for every model (unlit too, where they
  // do nothing); a property the documentation describes but its Unlit model
  // does not list is not offered for unlit.
  List<String> modelsOf(CodeStructField f) {
    final all = f.shadingModels.isEmpty ? shadingModelMacros.keys.toList() : f.shadingModels;
    final documentedElsewhere = propertyDocs.containsKey(f.name) && !doc.unlitProperties.contains(f.name);
    final models = [for (final m in all) if (!(m == 'unlit' && documentedElsewhere)) m];
    return models.length == shadingModelMacros.length ? const [] : models;
  }

  final fragmentInputs = [
    ...doc.fragmentInputs,
    for (final f in code.materialInputs)
      if (!docFields.contains(f.name))
        MatStructFieldInfo(
          name: f.name,
          glslType: f.glslType,
          shadingModels: modelsOf(f),
          availability: modelsOf(f).isEmpty ? '' : 'Shading models: ${modelsOf(f).join(', ')}',
          description: propertyDocs[f.name] ??
              'A property the shaders declare (shaders/src/surface_material_inputs.fs) that the material '
                  'documentation does not describe.',
          apiLevel: f.apiLevel,
          documented: false,
        ),
  ];

  final deprecated = {for (final f in code.functions) if (f.deprecated != null) f.name: f};
  final docFunctionNames = {for (final f in doc.functions) f.name};
  final functions = <MatFunctionInfo>[
    for (final f in doc.functions)
      deprecated[f.name] == null
          ? f
          : MatFunctionInfo(
              name: f.name,
              signature: f.signature,
              returnType: f.returnType,
              stage: f.stage,
              description: f.description,
              apiLevel: f.apiLevel,
              category: f.category,
              deprecated: deprecated[f.name]!.deprecated,
              replacement: deprecated[f.name]!.replacement,
            ),
    for (final f in code.functions)
      if (!docFunctionNames.contains(f.name))
        MatFunctionInfo(
          name: f.name,
          signature: f.signature,
          returnType: f.returnType,
          stage: switch (f.stage) {
            'vertex' => MatStage.vertex,
            'fragment' => MatStage.fragment,
            'compute' => MatStage.compute,
            _ => MatStage.any,
          },
          description: 'A public API of Filament\'s shaders (shaders/src/${f.file}) the material documentation '
              'does not list.',
          category: undocumentedGroup,
          deprecated: f.deprecated,
          replacement: f.replacement,
          documented: false,
        ),
  ];

  return FilamentMaterialDoc(
    headerKeys: headerKeys,
    parameterTypes: parameterTypes,
    constantTypes: doc.constantTypes,
    precisions: code.precisions.isEmpty ? doc.precisions : _ordered(doc.precisions, code.precisions),
    parameterEntryKeys: [
      for (final k in doc.parameterEntryKeys)
        k.name == 'type' ? MatEntryKeyInfo(k.name, [for (final t in parameterTypes) t.name], k.description) : k,
    ],
    constantEntryKeys: doc.constantEntryKeys,
    variableEntryKeys: doc.variableEntryKeys,
    blendFunctionKeys: blendFunctionKeys,
    fragmentInputs: fragmentInputs,
    vertexInputs: doc.vertexInputs,
    functions: functions,
    typeAliases: doc.typeAliases,
    constants: doc.constants,
    propertyDescriptions: doc.propertyDescriptions,
    unlitProperties: doc.unlitProperties,
  );
}

MatHeaderKeyInfo _mergeKey(MatHeaderKeyInfo k, MatcHeaderKey? c) {
  // An object key's table (blendFunction) holds the values of its fields, not of the key.
  if (c == null || c.jsonType == 'OBJECT') return k;
  final values = c.values.isEmpty ? k.values : _ordered(k.values, c.values);
  final removed = <String, String>{
    for (final v in k.values)
      if (!c.values.contains(v) && !c.aliases.containsKey(v) && c.values.isNotEmpty)
        v: c.ignored[v] ?? 'matc no longer accepts $v for ${k.name}.',
    ...c.ignored,
  };
  return MatHeaderKeyInfo(
    name: k.name,
    group: k.group,
    type: k.type,
    values: values,
    defaultValue: k.defaultValue,
    description: k.description,
    removedValues: removed,
    valueAliases: c.aliases,
  );
}

/// [code]'s values, in [doc]'s order first and then in [code]'s.
List<String> _ordered(List<String> doc, List<String> code) => [
  for (final v in doc)
    if (code.contains(v)) v,
  for (final v in code)
    if (!doc.contains(v)) v,
];
