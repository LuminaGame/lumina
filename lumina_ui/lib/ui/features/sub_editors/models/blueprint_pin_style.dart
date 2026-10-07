import 'package:flutter/widgets.dart';
import 'package:lumina/lumina.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

// These are the Blueprint pin colours (white exec, red boolean, green
// numbers, violet vectors, teal-green Vector2D, lavender rotators, pink names,
// blue objects). They live in EditorColors as `pin*` theme tokens, with these
// values as Lumina Dark's.

/// How the graph editor draws a pin of [LuminaPinType]: its colour and the
/// label the My Blueprint panel's type chip shows. Presentation only; the
/// types themselves come from lumina's node library.
abstract final class BlueprintPinStyle {
  static Color color(LuminaPinType? type) {
    switch (type) {
      case null:
        return EditorColors.pinUnknown;
      case LuminaPinType.exec:
        return EditorColors.pinExec;
      case LuminaPinType.boolean:
        return EditorColors.pinBoolean;
      case LuminaPinType.integer:
        return EditorColors.pinInteger;
      case LuminaPinType.float:
        return EditorColors.pinFloat;
      case LuminaPinType.string:
        return EditorColors.pinString;
      case LuminaPinType.name:
        return EditorColors.pinName;
      case LuminaPinType.vector:
        return EditorColors.pinVector;
      case LuminaPinType.vector2D:
        return EditorColors.pinVector2D;
      case LuminaPinType.rotator:
        return EditorColors.pinRotator;
      case LuminaPinType.object:
        return EditorColors.pinObject;
      case LuminaPinType.transform:
        return EditorColors.pinTransform;
      case LuminaPinType.structEnum:
        return EditorColors.pinStruct;
      case LuminaPinType.color:
        return EditorColors.pinColor;
      case LuminaPinType.array:
        return EditorColors.pinArray;
      case LuminaPinType.hitResult:
        return EditorColors.pinHitResult;
      case LuminaPinType.wildcard:
        return EditorColors.pinWildcard;
      case LuminaPinType.enumeration:
        return EditorColors.pinEnum;
      case LuminaPinType.delegate:
        return EditorColors.pinDelegate;
      case LuminaPinType.timerHandle:
        return EditorColors.pinTimerHandle;
    }
  }

  static String label(LuminaPinType? type) {
    switch (type) {
      case null:
        return 'Unknown';
      case LuminaPinType.exec:
        return 'Exec';
      case LuminaPinType.boolean:
        return 'Boolean';
      case LuminaPinType.integer:
        return 'Integer';
      case LuminaPinType.float:
        return 'Float';
      case LuminaPinType.string:
        return 'String';
      case LuminaPinType.name:
        return 'Name';
      case LuminaPinType.vector:
        return 'Vector';
      case LuminaPinType.vector2D:
        return 'Vector 2D';
      case LuminaPinType.rotator:
        return 'Rotator';
      case LuminaPinType.object:
        return 'Object';
      case LuminaPinType.transform:
        return 'Transform';
      case LuminaPinType.structEnum:
        return 'Struct';
      case LuminaPinType.color:
        return 'Color';
      case LuminaPinType.array:
        return 'Array';
      case LuminaPinType.hitResult:
        return 'Hit Result';
      case LuminaPinType.wildcard:
        return 'Wildcard';
      case LuminaPinType.enumeration:
        return 'Enum';
      case LuminaPinType.delegate:
        return 'Delegate';
      case LuminaPinType.timerHandle:
        return 'Timer Handle';
    }
  }

  /// The basic variable types the My Blueprint panel offers, as stored in
  /// the document's `type` field (lumina's `LuminaPinType.parseVariableType`).
  static const List<String> variableTypeNames = [
    'Bool',
    'Int',
    'Float',
    'Name',
    'String',
    'Vector',
    'Vector2D',
    'Rotator',
    'Color',
    'Transform',
  ];

  /// What a pin's tooltip and the palette's "From" line call [pin]: the
  /// class of an object pin (`Widget (WBP_HUD)`, `Text Block`, `Spring Arm`),
  /// `Array of Float` for a typed array, the type otherwise.
  static String pinLabel(LuminaBlueprintPinSpec pin) {
    if (pin.type == LuminaPinType.object) return LuminaBlueprintObjectClass.displayName(pin.objectClass);
    if (pin.type == LuminaPinType.enumeration && pin.enumName != null) return pin.enumName!;
    if (pin.type == LuminaPinType.array && pin.elementType != null) {
      final inner = pin.elementType == LuminaPinType.object
          ? LuminaBlueprintObjectClass.displayName(pin.objectClass)
          : label(pin.elementType);
      return 'Array of $inner';
    }
    return label(pin.type);
  }

  /// What the type chip shows for a variable declared as [typeName]: the
  /// class of an object variable (`Widget (WBP_HUD)`, `Text Block`, `Spring
  /// Arm`, `BP_Door`), `Array of Float` for arrays, the type otherwise.
  static String variableLabel(String typeName) {
    final type = LuminaPinType.parseVariableType(typeName);
    if (type == LuminaPinType.array) {
      return 'Array of ${variableLabel(typeName.substring('array:'.length))}';
    }
    if (type == LuminaPinType.object) return LuminaBlueprintObjectClass.displayName(luminaBlueprintObjectClassOf(typeName));
    if (type == LuminaPinType.enumeration) return luminaBlueprintEnumNameOf(typeName) ?? 'Enum';
    return label(type);
  }

  /// The My Blueprint type picker's groups: Basic,
  /// Object, the project's widget classes, every widget element type, the
  /// document's component classes and the actor classes, each as the type
  /// name the document stores.
  static List<BlueprintVariableTypeGroup> variableTypeGroups(LuminaBlueprintTypeContext context) {
    final componentClasses = <String>{for (final c in context.components) c.componentClass};
    final actorClasses = <String>{...context.actorParents.keys, 'LuminaActor', 'LuminaPawn', 'LuminaCharacter'};
    return [
      const BlueprintVariableTypeGroup('Basic', variableTypeNames),
      const BlueprintVariableTypeGroup('Object', [LuminaBlueprintObjectClass.any]),
      BlueprintVariableTypeGroup('Widgets', [for (final w in context.widgetClasses) w.objectClass]),
      BlueprintVariableTypeGroup('Widget Elements', [
        for (final t in LuminaBlueprintObjectClass.elementDisplayNames.keys) LuminaBlueprintObjectClass.widgetElement(t),
      ]),
      BlueprintVariableTypeGroup('Components', [for (final c in componentClasses) LuminaBlueprintObjectClass.component(c)]),
      BlueprintVariableTypeGroup('Actors', [for (final a in actorClasses) LuminaBlueprintObjectClass.actor(a)]),
      BlueprintVariableTypeGroup('Enums', [for (final e in context.enums) 'Enum:${e.name}']),
    ];
  }

  /// Types a function / macro / dispatcher parameter may take: the variable
  /// types plus `Exec` for macro pins when [allowExec].
  static List<BlueprintVariableTypeGroup> parameterTypeGroups(LuminaBlueprintTypeContext context, {bool allowExec = false}) => [
        if (allowExec) const BlueprintVariableTypeGroup('Flow', ['Exec']),
        ...variableTypeGroups(context),
      ];

  /// The literal a new variable (or a reset pin) of [typeName] starts at.
  static Object? defaultValueFor(String typeName) {
    switch (LuminaPinType.parseVariableType(typeName)) {
      case LuminaPinType.boolean:
        return false;
      case LuminaPinType.integer:
        return 0;
      case LuminaPinType.string:
      case LuminaPinType.name:
        return '';
      case LuminaPinType.vector:
      case LuminaPinType.rotator:
        return const [0.0, 0.0, 0.0];
      case LuminaPinType.vector2D:
        return const [0.0, 0.0];
      case LuminaPinType.color:
        return const [1.0, 1.0, 1.0, 1.0];
      case LuminaPinType.transform:
        return const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0];
      case LuminaPinType.object:
      case LuminaPinType.hitResult:
      case LuminaPinType.wildcard:
        return null;
      case LuminaPinType.array:
        return const [];
      case LuminaPinType.enumeration:
        return LuminaBlueprintEnums.valuesOf(luminaBlueprintEnumNameOf(typeName)).firstOrNull ?? '';
      case LuminaPinType.exec:
      case LuminaPinType.delegate:
      case LuminaPinType.timerHandle:
        return null;
      default:
        return 0.0;
    }
  }
}

/// One group of the type picker: its heading and the type names it offers.
class BlueprintVariableTypeGroup {
  final String title;
  final List<String> typeNames;
  const BlueprintVariableTypeGroup(this.title, this.typeNames);
}
