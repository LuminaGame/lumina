part of '../blueprint_function_library.dart';

/// What a node function gets when the VM calls it: the
/// Blueprint instance it runs on.
class LuminaBlueprintCallContext {
  final LuminaActor self;
  const LuminaBlueprintCallContext(this.self);
}

/// A node's behaviour as the VM calls it: inputs by pin id → outputs by pin id.
typedef LuminaBlueprintFunction =
    Map<String, Object?> Function(
      LuminaBlueprintCallContext context,
      Map<String, Object?> inputs,
    );

/// How generated code calls a node's function: the static
/// method on [LuminaBlueprintFunctionLibrary], its arguments as input pin ids
/// in order, whether the Blueprint itself (`self`) comes first, and its
/// outputs: none, `return_value`, or record fields named after the pins.
///
/// A Dart function exposed with `@BlueprintCallable` / `@BlueprintPure`
/// also names the [library] it is imported from, and which
/// arguments are [named] and which [optional] (left out of a direct call when
/// the pin is neither wired nor set, so Dart's default applies).
class LuminaBlueprintCallShape {
  /// The function: a method of [LuminaBlueprintFunctionLibrary], or for a
  /// [library] function its name (`applyDamage`, `Class.method`).
  final String method;
  final List<String> args;
  final bool self;
  final List<String> outputs;

  /// The library URI an exposed function is imported from; null for the
  /// function library.
  final String? library;

  /// Arguments passed by name.
  final Set<String> named;

  /// Arguments with a Dart default (optional named or positional).
  final Set<String> optional;

  /// The outputs are a record's fields even when there is one.
  final bool record;

  const LuminaBlueprintCallShape(
    this.method,
    this.args, {
    this.self = false,
    this.outputs = const [],
    this.library,
    this.named = const {},
    this.optional = const {},
    this.record = false,
  });

  bool get returnsRecord => record || outputs.length > 1;
}

/// [LuminaBlueprintFunctionLibrary.functions]: the built-ins, then the
/// registry's callable functions, read live.
class _WithRegistered
    extends UnmodifiableMapBase<String, LuminaBlueprintFunction> {
  @override
  LuminaBlueprintFunction? operator [](Object? key) => key is String
      ? LuminaBlueprintFunctionLibrary.builtInFunctions[key] ??
            LuminaBlueprintFunctionRegistry.function(key)
      : null;

  @override
  bool containsKey(Object? key) => this[key] != null;

  @override
  Iterable<String> get keys => LuminaBlueprintFunctionRegistry.isEmpty
      ? LuminaBlueprintFunctionLibrary.builtInFunctions.keys
      : [
          ...LuminaBlueprintFunctionLibrary.builtInFunctions.keys,
          ...LuminaBlueprintFunctionRegistry.callableIds,
        ];
}
