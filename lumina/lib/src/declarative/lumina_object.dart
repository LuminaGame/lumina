import 'package:flutter/foundation.dart';
import 'build_context.dart';

/// Base root class for all declarative nodes in the Lumina Game Engine.
/// Inspired by Flutter's Widget architecture.
abstract class LuminaObject {
  /// Unique key for element identity reconciliation.
  final Key? key;

  const LuminaObject({this.key});

  /// Builds the child or hierarchy of sub-nodes for this node.
  LuminaObject? build(LuminaBuildContext context) => null;

  /// Returns children of this node if it contains multiple nodes.
  List<LuminaObject> get children => const [];
}

/// Helper container node for multiple children.
class LuminaNodeGroup extends LuminaObject {
  @override
  final List<LuminaObject> children;

  const LuminaNodeGroup({super.key, required this.children});

  @override
  LuminaObject? build(LuminaBuildContext context) => null;
}
