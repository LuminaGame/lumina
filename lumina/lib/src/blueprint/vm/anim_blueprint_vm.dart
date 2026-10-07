import 'package:lumina/src/components/mesh/animated_mesh_component.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/blueprint/anim/anim_blueprint_instance.dart';
import 'package:lumina/src/blueprint/anim/anim_blueprint_model.dart';
import 'package:lumina/src/blueprint/anim/anim_blueprint_validator.dart';
import 'package:lumina/src/blueprint/blueprint_model.dart';
import 'package:lumina/src/blueprint/blueprint_validator.dart';
import 'package:lumina/src/blueprint/node_library.dart';
import 'package:lumina/src/blueprint/vm/blueprint_vm.dart';

/// An Animation Blueprint ready to run in the VM: its update
/// graph and every transition rule validated once.
class LuminaAnimBlueprintClass {
  final String name;
  final LuminaAnimBlueprintDocument document;
  final Map<String, LuminaBlendSpaceDocument> blendSpaces;
  final List<LuminaBlueprintDiagnostic> diagnostics;

  LuminaAnimBlueprintClass._(this.name, this.document, this.blendSpaces, this.diagnostics);

  factory LuminaAnimBlueprintClass.fromDocument(
    LuminaAnimBlueprintDocument document, {
    String name = 'AnimBlueprint',
    Map<String, LuminaBlendSpaceDocument> blendSpaces = const {},
  }) {
    final diagnostics = validateAnimBlueprint(document, blendSpaces: blendSpaces);
    return LuminaAnimBlueprintClass._(name, document, blendSpaces, diagnostics);
  }

  bool get hasErrors => diagnostics.any((d) => d.isError);

  LuminaVmAnimBlueprintInstance instantiate(LuminaAnimatedMeshComponent mesh) {
    if (hasErrors) throw LuminaBlueprintCompileError(name, diagnostics.where((d) => d.isError).toList());
    return LuminaVmAnimBlueprintInstance._(this, mesh);
  }

  LuminaAnimBlueprintFactory get factory => instantiate;
}

/// An Animation Blueprint run by the VM: the update graph and the transition
/// rules go through [LuminaBlueprintInterpreter], with the owning pawn as the
/// function library's `self`.
class LuminaVmAnimBlueprintInstance extends LuminaAnimBlueprintInstance implements LuminaBlueprintGraphHost {
  final LuminaAnimBlueprintClass animClass;
  late final _pins = _resolvePins(animClass.document.eventGraph);
  late final Map<String, _RuleHost> _rules = {
    for (final t in animClass.document.stateMachine!.transitions) t.id: _RuleHost(this, t),
  };

  /// A single update stops after this many nodes.
  int maxNodesPerEvent = 100000;

  String? lastError;

  LuminaVmAnimBlueprintInstance._(this.animClass, LuminaAnimatedMeshComponent mesh)
      : super(
          mesh: mesh,
          stateMachine: animClass.document.stateMachine!,
          blendSpaces: animClass.blendSpaces,
          meshYawOffsetDegrees: animClass.document.meshYawOffsetDegrees,
          aimOffset: animClass.document.aimOffset,
          initialVariables: luminaAnimVariableDefaults(animClass.document.variables),
        );

  Map<String, ({List<LuminaBlueprintPinSpec> inputs, List<LuminaBlueprintPinSpec> outputs})> _resolvePins(
      LuminaBlueprintGraph graph) {
    final context = LuminaBlueprintTypeContext(variables: animClass.document.variables);
    return {for (final n in graph.nodes) n.id: LuminaBlueprintNodeLibrary.pinsOf(n, context)!};
  }

  @override
  void updateAnimation(double deltaTimeX) {
    for (final node in animClass.document.eventGraph.nodes) {
      if (node.registryId == LuminaBlueprintNodeLibrary.updateAnimation) {
        LuminaBlueprintInterpreter.run(this, node.id, 'exec_out', {'delta_time_x': deltaTimeX});
      }
    }
  }

  @override
  bool evaluateRule(LuminaAnimTransition transition) {
    final host = _rules[transition.id]!;
    final result = LuminaBlueprintInterpreter.evaluateInput(host, transition.resultNode!.id, 'can_enter');
    return result == true;
  }

  @override
  LuminaBlueprintGraph get hostGraph => animClass.document.eventGraph;
  @override
  Map<String, ({List<LuminaBlueprintPinSpec> inputs, List<LuminaBlueprintPinSpec> outputs})> get hostPins => _pins;
  @override
  Map<String, Object?> get hostVariables => variables;
  @override
  LuminaActor get hostSelf => pawnOwner;
  @override
  int get hostMaxNodes => maxNodesPerEvent;
  @override
  String get hostName => animClass.name;
  @override
  void hostTrace(String eventNodeId, String nodeId, String registryId, Map<String, Object?> values, {String? printed}) =>
      blueprintTrace(eventNodeId, nodeId, registryId, values, printed: printed);
  /// Unreachable: the validator rejects latent nodes in an Animation Blueprint.
  @override
  void hostDelay(String nodeId, double seconds, void Function() resume) =>
      hostError('Delay cannot run in an Animation Blueprint (node $nodeId).');
  @override
  void hostRetriggerableDelay(String nodeId, double seconds, void Function() resume) => hostDelay(nodeId, seconds, resume);
  @override
  final Map<String, Object?> hostFlowState = {};
  @override
  void hostError(String message) => lastError = message;
  @override
  Map<String, Object?> get hostLocals => const {};
  @override
  LuminaBlueprintInstance? get hostInstance => null;
}

/// A transition rule's graph, evaluated with the instance's variables.
class _RuleHost implements LuminaBlueprintGraphHost {
  final LuminaVmAnimBlueprintInstance anim;
  final LuminaAnimTransition transition;
  late final _pins = anim._resolvePins(transition.rule);

  _RuleHost(this.anim, this.transition);

  @override
  LuminaBlueprintGraph get hostGraph => transition.rule;
  @override
  Map<String, ({List<LuminaBlueprintPinSpec> inputs, List<LuminaBlueprintPinSpec> outputs})> get hostPins => _pins;
  @override
  Map<String, Object?> get hostVariables => anim.variables;
  @override
  LuminaActor get hostSelf => anim.pawnOwner;
  @override
  int get hostMaxNodes => anim.maxNodesPerEvent;
  @override
  String get hostName => '${anim.animClass.name}.${transition.id}';
  @override
  void hostTrace(String eventNodeId, String nodeId, String registryId, Map<String, Object?> values, {String? printed}) =>
      anim.blueprintTrace(transition.id, nodeId, registryId, values, printed: printed);
  @override
  void hostDelay(String nodeId, double seconds, void Function() resume) => anim.hostDelay(nodeId, seconds, resume);
  @override
  void hostRetriggerableDelay(String nodeId, double seconds, void Function() resume) => anim.hostDelay(nodeId, seconds, resume);
  @override
  Map<String, Object?> get hostFlowState => anim.hostFlowState;
  @override
  void hostError(String message) => anim.hostError(message);
  @override
  Map<String, Object?> get hostLocals => const {};
  @override
  LuminaBlueprintInstance? get hostInstance => null;
}
