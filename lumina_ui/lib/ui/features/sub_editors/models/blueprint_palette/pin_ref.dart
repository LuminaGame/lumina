import 'package:lumina_editor_data/lumina_editor.dart';

/// A pin a new node could be wired from: the pin the user dragged off. An
/// object pin carries its class and an array pin its element
/// type, so the palette can be context sensitive.
class BlueprintPinRef {
  final String nodeId;
  final String pinId;
  final LuminaPinType type;
  final bool isOutput;
  final String? objectClass;
  final LuminaPinType? elementType;

  /// The enum of an enumeration pin.
  final String? enumName;

  const BlueprintPinRef({
    required this.nodeId,
    required this.pinId,
    required this.type,
    required this.isOutput,
    this.objectClass,
    this.elementType,
    this.enumName,
  });

  /// The ref of [pin] on node [nodeId].
  factory BlueprintPinRef.of(String nodeId, LuminaBlueprintPinSpec pin, {required bool isOutput}) => BlueprintPinRef(
        nodeId: nodeId,
        pinId: pin.id,
        type: pin.type,
        isOutput: isOutput,
        objectClass: pin.objectClass,
        elementType: pin.elementType,
        enumName: pin.enumName,
      );

  /// A `Self` reference: what the Blueprint's own actor pins carry
  /// (`Actor:BP_ThirdPersonCharacter`); dragging it lists the component
  /// tree. The node id is empty: nothing is wired to it.
  factory BlueprintPinRef.self(LuminaBlueprintTypeContext context) => BlueprintPinRef(
        nodeId: '',
        pinId: 'self',
        type: LuminaPinType.object,
        isOutput: true,
        objectClass: context.selfClass,
      );

  bool get isSelf => nodeId.isEmpty && pinId == 'self';

  /// This pin as the library describes it, for [LuminaBlueprintNodeLibrary.canConnect].
  LuminaBlueprintPinSpec get spec =>
      LuminaBlueprintPinSpec(pinId, pinId, type, objectClass: objectClass, elementType: elementType, enumName: enumName);
}
