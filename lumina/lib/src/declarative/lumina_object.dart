import 'package:lumina/src/object/lumina_object_key.dart';

/// Base root class for all declarative nodes in the Lumina Game Engine.
/// Inspired by Flutter's Widget architecture.
abstract class LuminaObject {
  /// Unique key for element identity reconciliation.
  final LuminaObjectKey? key;

  const LuminaObject({this.key});

  /// Builds the child or hierarchy of sub-nodes for this node.
  ///
  /// The tree passes a `LuminaBuildContext` (which adds the world, the level
  /// and the actor); overrides declare that type.
  LuminaObject? build(covariant LuminaObjectContext context) => null;

  /// Returns children of this node if it contains multiple nodes.
  List<LuminaObject> get children => const [];
}

/// What [LuminaObject.build] can ask of the tree without knowing the world:
/// its ancestors. `LuminaBuildContext` extends it with the world, the level
/// and the enclosing actor.
abstract interface class LuminaObjectContext {
  /// Searches up the tree for the nearest ancestor matching exact runtimeType [T].
  T? findAncestorOfExactType<T extends LuminaObject>();

  /// Searches up the tree for the nearest ancestor matching subtype [T].
  T? findAncestorOfType<T extends LuminaObject>();

  /// Walks up the ancestor chain from parent to root, stopping when visitor returns false.
  void visitAncestorElements(bool Function(LuminaObject node) visitor);
}

/// Helper container node for multiple children.
class LuminaNodeGroup extends LuminaObject {
  @override
  final List<LuminaObject> children;

  const LuminaNodeGroup({super.key, required this.children});

  @override
  LuminaObject? build(LuminaObjectContext context) => null;
}
