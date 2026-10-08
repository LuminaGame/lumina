part of '../blueprint_function_library.dart';

/// [LuminaBlueprintFunctionLibrary.callShapes]: traversal.
const Map<String, LuminaBlueprintCallShape> _traversalCallShapes = <String, LuminaBlueprintCallShape>{
  'try_traversal_action':
      LuminaBlueprintCallShape('tryTraversalAction', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'traversal_check': LuminaBlueprintCallShape('traversalCheck', [], self: true, outputs: [
    'action_type',
    'obstacle_height',
    'obstacle_depth',
    'back_ledge_height',
    'has_front_ledge',
  ]),
  'is_traversing': LuminaBlueprintCallShape('isTraversing', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
};

/// [LuminaBlueprintFunctionLibrary.builtInFunctions]: traversal.
final Map<String, LuminaBlueprintFunction> _traversalFunctions = <String, LuminaBlueprintFunction>{
  'try_traversal_action': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.tryTraversalAction(c.self)),
  'traversal_check': (c, i) {
    final r = LuminaBlueprintFunctionLibrary.traversalCheck(c.self);
    return {
      'action_type': r.actionType,
      'obstacle_height': r.obstacleHeight,
      'obstacle_depth': r.obstacleDepth,
      'back_ledge_height': r.backLedgeHeight,
      'has_front_ledge': r.hasFrontLedge,
    };
  },
  'is_traversing': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.isTraversing(c.self)),
};

LuminaTraversalComponent? _traversal(LuminaActor self) => self.getComponent<LuminaTraversalComponent>();

bool _tryTraversalAction(LuminaActor self) => _traversal(self)?.tryTraversalAction() ?? false;

({String actionType, double obstacleHeight, double obstacleDepth, double backLedgeHeight, bool hasFrontLedge}) _traversalCheck(
    LuminaActor self) {
  final r = _traversal(self)?.checkTraversal();
  return (
    actionType: (r?.actionType ?? LuminaTraversalActionType.none).label,
    obstacleHeight: r?.obstacleHeight ?? 0.0,
    obstacleDepth: r?.obstacleDepth ?? 0.0,
    backLedgeHeight: r?.backLedgeHeight ?? 0.0,
    hasFrontLedge: r?.hasFrontLedge ?? false,
  );
}

bool _isTraversing(LuminaActor self) => _traversal(self)?.isTraversing ?? false;
