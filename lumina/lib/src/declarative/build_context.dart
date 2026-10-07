import 'package:lumina/src/declarative/lumina_object.dart';
import 'package:lumina/src/world/world.dart';
import 'package:lumina/src/world/level.dart';
import 'package:lumina/src/object/actor.dart';

/// Context interface provided to [LuminaObject.build] during tree construction.
abstract class LuminaBuildContext implements LuminaObjectContext {
  /// Reference to the current [LuminaWorld] context.
  LuminaWorld? get world;

  /// Reference to the current active [LuminaLevel].
  LuminaLevel? get level;

  /// Reference to the enclosing [LuminaActor], if any.
  LuminaActor? get actor;

  /// Convenience finder for the nearest enclosing [LuminaWorld].
  LuminaWorld? findAncestorWorld();

  /// Convenience finder for the nearest enclosing [LuminaLevel].
  LuminaLevel? findAncestorLevel();

  /// Convenience finder for the nearest enclosing [LuminaActor].
  LuminaActor? findAncestorActor();

  /// Searches up the tree for the nearest ancestor matching exact runtimeType [T].
  @override
  T? findAncestorOfExactType<T extends LuminaObject>();

  /// Searches up the tree for the nearest ancestor matching subtype [T].
  @override
  T? findAncestorOfType<T extends LuminaObject>();

  /// Walks up the ancestor chain from parent to root, stopping when visitor returns false.
  @override
  void visitAncestorElements(bool Function(LuminaObject node) visitor);
}

/// Deprecated shim maintained for backwards compatibility.
@Deprecated('Use LuminaElement directly as LuminaBuildContext.')
class LuminaElementContext implements LuminaBuildContext {
  @override
  final LuminaWorld? world;

  @override
  final LuminaLevel? level;

  @override
  final LuminaActor? actor;

  final LuminaObject node;
  final LuminaElementContext? parent;

  LuminaElementContext({
    required this.node,
    this.world,
    this.level,
    this.actor,
    this.parent,
  });

  @override
  LuminaWorld? findAncestorWorld() => world;

  @override
  LuminaLevel? findAncestorLevel() => level;

  @override
  LuminaActor? findAncestorActor() => actor;

  @override
  T? findAncestorOfExactType<T extends LuminaObject>() {
    LuminaElementContext? current = parent;
    while (current != null) {
      if (current.node.runtimeType == T) {
        return current.node as T;
      }
      current = current.parent;
    }
    return null;
  }

  @override
  T? findAncestorOfType<T extends LuminaObject>() {
    LuminaElementContext? current = parent;
    while (current != null) {
      if (current.node is T) {
        return current.node as T;
      }
      current = current.parent;
    }
    return null;
  }

  @override
  void visitAncestorElements(bool Function(LuminaObject node) visitor) {
    LuminaElementContext? current = parent;
    while (current != null) {
      if (!visitor(current.node)) break;
      current = current.parent;
    }
  }
}
