// GENERATED CODE - DO NOT MODIFY BY HAND.
// Blueprint interface contents/interfaces/BPI_Interactable.lmas, compiled by Lumina.
// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'package:lumina/lumina_runtime.dart';

/// Implementers answer each function through `callBlueprint(name, args)`.
abstract mixin class BpiInteractable {
  static const LuminaBlueprintInterfaceDocument document = LuminaBlueprintInterfaceDocument(name: 'BPI_Interactable', functions: [
    LuminaBlueprintFunctionSignature(name: 'Interact', inputs: [LuminaBlueprintVariable(name: 'Instigator', typeName: 'Actor')], outputs: []),
  ]);

  /// Interact(Instigator: Actor)
  Map<String, Object?> interact(Map<String, Object?> args);
}
