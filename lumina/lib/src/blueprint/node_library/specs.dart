part of '../node_library.dart';

/// How a node takes part in execution.
enum LuminaBlueprintNodeKind {
  /// An entry point: BeginPlay, Tick, an input action.
  event,

  /// Runs when its exec input fires, then continues from its exec output.
  impure,

  /// No exec pins; evaluated when an impure node pulls one of its outputs.
  pure,

  /// Chooses where execution continues (Branch, Sequence).
  flow,

  /// Continues later (Delay).
  latent,
}

/// A pin as the library declares it.
class LuminaBlueprintPinSpec {
  final String id;
  final String name;
  final LuminaPinType type;
  final Object? defaultValue;

  /// A required input must be wired or given a literal.
  final bool required;

  /// The class of an object pin: `Widget:WBP_HUD`,
  /// `WidgetElement:text`, `Component:LuminaSpringArmComponent`,
  /// `Actor:BP_Door`; null is any object.
  final String? objectClass;

  /// The element type of an array pin.
  final LuminaPinType? elementType;

  /// The enum of an enum pin.
  final String? enumName;

  const LuminaBlueprintPinSpec(this.id, this.name, this.type,
      {this.defaultValue, this.required = false, this.objectClass, this.elementType, this.enumName});

  /// The pin a declared parameter / variable makes: id and name are its name.
  factory LuminaBlueprintPinSpec.ofVariable(LuminaBlueprintVariable v) => LuminaBlueprintPinSpec(
        v.name,
        v.name,
        v.type ?? LuminaPinType.wildcard,
        defaultValue: v.defaultValue,
        objectClass: v.objectClass,
        elementType: v.elementType,
        enumName: v.enumName,
      );

  LuminaBlueprintPin toPin({required bool isOutput}) => LuminaBlueprintPin(
      id: id,
      name: name,
      type: type,
      isOutput: isOutput,
      defaultValue: defaultValue,
      objectClass: objectClass,
      elementType: elementType,
      enumName: enumName);

  /// This pin with another type and class.
  LuminaBlueprintPinSpec retyped(LuminaPinType type, {String? objectClass, LuminaPinType? elementType, String? enumName}) =>
      LuminaBlueprintPinSpec(id, name, type,
          defaultValue: defaultValue,
          required: required,
          objectClass: objectClass,
          elementType: elementType,
          enumName: enumName ?? this.enumName);

  /// This pin with another name.
  LuminaBlueprintPinSpec renamed(String name) => LuminaBlueprintPinSpec(id, name, type,
      defaultValue: defaultValue, required: required, objectClass: objectClass, elementType: elementType, enumName: enumName);
}

/// One node of the library: its pins and kind. Behaviour lives in
/// `LuminaBlueprintFunctionLibrary` (pure and impure nodes) or in the VM
/// ([LuminaBlueprintNodeLibrary.intrinsics]).
class LuminaBlueprintNodeSpec {
  final String id;
  final String title;
  final String category;
  final LuminaBlueprintNodeKind kind;
  final List<LuminaBlueprintPinSpec> inputs;
  final List<LuminaBlueprintPinSpec> outputs;
  final List<String> keywords;

  /// ARGB header colour, one per node family.
  final int headerColor;

  /// Non-null for a node kept only so old documents load; the message says
  /// what replaces it.
  final String? deprecation;

  /// Non-null when the node loads but is not executed yet; the message says
  /// why. Reported as a warning.
  final String? unsupported;

  /// What the palette shows on hover: an exposed Dart function's doc comment,
  /// or a built-in node's description.
  final String? tooltip;

  /// The node only stages a game user setting; it takes effect when Apply
  /// Scalability Settings runs. The editor shows [applyHint] on the node.
  final bool requiresApply;

  /// The node runs only in an editor panel's graph (the editor function
  /// library, the Json nodes): never offered or accepted in a game graph.
  final bool editorOnly;

  /// The editor panel capability (`level`, `assets`, `process`, `mcp`) a
  /// graph must declare to use this node; null when reading needs none.
  final String? editorCapability;

  /// The line the editor shows on a [requiresApply] node.
  static const String applyHint = 'Needs Apply Scalability Settings';

  /// The sentence that ends a [requiresApply] node's [tooltip].
  static const String stagedNote = 'Staged: takes effect when Apply Scalability Settings runs.';

  const LuminaBlueprintNodeSpec({
    required this.id,
    required this.title,
    required this.category,
    required this.kind,
    this.inputs = const [],
    this.outputs = const [],
    this.keywords = const [],
    required this.headerColor,
    this.deprecation,
    this.unsupported,
    this.tooltip,
    this.requiresApply = false,
    this.editorOnly = false,
    this.editorCapability,
  });

  bool get hasExecIn => inputs.any((p) => p.type == LuminaPinType.exec);
}
