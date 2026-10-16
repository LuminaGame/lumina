/// The value types of the `.mat` language tables: Filament's material
/// header keys, shader input structures, functions, type aliases and
/// constants (the generated `filament_material_api.g.dart`) and the GLSL ES
/// 3.0 built-ins (`glsl_builtins.dart`). Pure Dart, no Flutter imports.
library;

/// Which shader block a function may be called from.
enum MatStage { any, vertex, fragment, compute }

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

  /// The documentation's description, one paragraph; for a key the
  /// documentation leaves out, the comment of the `MaterialBuilder` method it sets.
  final String description;

  /// False for a key matc accepts that the material documentation does not describe.
  final bool documented;

  /// Values the documentation (or an earlier Filament) lists that matc no
  /// longer accepts or ignores → why. The editor does not suggest them and
  /// rewrites them out of a source (`MatMigration`).
  final Map<String, String> removedValues;

  /// Values matc still accepts for backward compatibility → the current value
  /// they stand for (`true` → `simple`). Not suggested; rewritten to the current one.
  final Map<String, String> valueAliases;

  const MatHeaderKeyInfo({
    required this.name,
    required this.group,
    required this.type,
    this.values = const [],
    this.defaultValue,
    required this.description,
    this.documented = true,
    this.removedValues = const {},
    this.valueAliases = const {},
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

  /// False for a field the shaders declare that the documentation's structure leaves out.
  final bool documented;

  const MatStructFieldInfo({
    required this.name,
    required this.glslType,
    this.defaultValue,
    this.shadingModels = const [],
    this.availability = '',
    this.description = '',
    this.apiLevel = 1,
    this.documented = true,
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

  /// The shaders' `@deprecated` note; null for a current function. A
  /// deprecated function is not suggested.
  final String? deprecated;

  /// The expression a call of a deprecated getter is rewritten to (its body
  /// in the shaders), e.g. `getUserWorldFromWorldMatrix()[3].xyz`.
  final String? replacement;

  /// False for a public API the shaders mark that the documentation does not list.
  final bool documented;

  const MatFunctionInfo({
    required this.name,
    required this.signature,
    required this.returnType,
    this.stage = MatStage.any,
    required this.description,
    this.apiLevel = 1,
    this.category = '',
    this.deprecated,
    this.replacement,
    this.documented = true,
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
