// GENERATED CODE - DO NOT MODIFY BY HAND.
// Blueprint enum contents/enums/E_DoorState.lmas, compiled by Lumina.
// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'package:lumina/lumina_runtime.dart';

enum EDoorState {
  closed('Closed'),
  opening('Opening'),
  open('Open');

  /// The value name as Blueprint pins carry it.
  final String blueprintName;
  const EDoorState(this.blueprintName);

  /// The document the registry serves at run time.
  static const LuminaBlueprintEnumDocument document = LuminaBlueprintEnumDocument(name: 'E_DoorState', values: ['Closed', 'Opening', 'Open']);

  static EDoorState? fromBlueprintName(String name) {
    for (final v in values) {
      if (v.blueprintName == name) return v;
    }
    return null;
  }
}
