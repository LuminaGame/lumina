/// The value types of the `.mat` language tables: Filament's material
/// header keys, shader input structures, functions, type aliases and
/// constants (the generated `filament_material_api.g.dart`) and the GLSL ES
/// 3.0 built-ins (`glsl_builtins.dart`). Pure Dart, no Flutter imports.
library;

/// Which shader block a function may be called from.
enum MatStage { any, vertex, fragment }

/// A property of the `material { }` header block.
class MatHeaderKeyInfo {
  /// The key as written in the header (`shadingModel`).
  final String name;

  /// The documentation group (`General`, `Blending and transparency`, …).
  final String group;

  /// The value type (`string`, `boolean`, `array of string`, …).
  final String type;

  /// The values the key accepts; empty when any value of [type] is valid.
  final List<String> values;

  /// The default value, as the documentation states it; null when none.
  final String? defaultValue;

  /// The documentation's description, one paragraph.
  final String description;

  const MatHeaderKeyInfo({
    required this.name,
    required this.group,
    required this.type,
    this.values = const [],
    this.defaultValue,
    required this.description,
  });
}

/// A key of an entry object nested in the header (a `parameters`,
/// `constants` or `variables` entry, or `blendFunction`).
class MatEntryKeyInfo {
  final String name;
  final List<String> values;
  final String description;
  const MatEntryKeyInfo(this.name, this.values, this.description);
}

/// A value type of a `parameters` (or `constants`) entry.
class MatParamTypeInfo {
  final String name;
  final String description;
  const MatParamTypeInfo(this.name, this.description);

  bool get isSampler => name.startsWith('sampler');
}

/// A field of `MaterialInputs` (fragment) or `MaterialVertexInputs` (vertex).
class MatStructFieldInfo {
  final String name;
  final String glslType;

  /// The default value; null when the documentation gives none.
  final String? defaultValue;

  /// The shading models the field is available with; empty means all.
  final List<String> shadingModels;

  /// When the field is available, as the documentation states it.
  final String availability;

  /// The property's description (with its range and notes when known).
  final String description;

  /// The material API level the field needs.
  final int apiLevel;

  const MatStructFieldInfo({
    required this.name,
    required this.glslType,
    this.defaultValue,
    this.shadingModels = const [],
    this.availability = '',
    this.description = '',
    this.apiLevel = 1,
  });

  bool availableWith(String shadingModel) => shadingModels.isEmpty || shadingModels.contains(shadingModel);
}

/// A shader function: a Filament public API or a GLSL built-in.
class MatFunctionInfo {
  final String name;

  /// The full signature, `float3 getWorldPosition()`.
  final String signature;
  final String returnType;
  final MatStage stage;
  final String description;

  /// The material API level the function needs.
  final int apiLevel;

  /// The documentation table (`Math`, `Fragment only`, `GLSL`, …).
  final String category;

  const MatFunctionInfo({
    required this.name,
    required this.signature,
    required this.returnType,
    this.stage = MatStage.any,
    required this.description,
    this.apiLevel = 1,
    this.category = '',
  });

  /// Whether the function takes arguments (the caret goes inside `()`).
  bool get hasArguments {
    final open = signature.indexOf('(');
    final close = signature.lastIndexOf(')');
    return open >= 0 && close > open + 1 && signature.substring(open + 1, close).trim().isNotEmpty;
  }

  bool availableIn(MatStage block) => stage == MatStage.any || stage == block;
}

/// A Filament type alias (`float3` for `vec3`) or a GLSL type.
class MatTypeInfo {
  final String name;

  /// The GLSL type the alias stands for; equal to [name] for GLSL types.
  final String glslType;
  final String description;
  const MatTypeInfo(this.name, this.glslType, this.description);
}

/// A shader constant (`PI`).
class MatConstantInfo {
  final String name;
  final String type;
  final String description;
  const MatConstantInfo(this.name, this.type, this.description);
}
