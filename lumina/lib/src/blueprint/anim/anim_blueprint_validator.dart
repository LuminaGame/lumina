import 'package:lumina/src/blueprint/blueprint_model.dart';
import 'package:lumina/src/blueprint/blueprint_validator.dart';
import 'package:lumina/src/blueprint/node_library.dart';
import 'package:lumina/src/blueprint/anim/anim_blueprint_model.dart';
import 'package:lumina_core/lumina_core.dart';

/// Checks an Animation Blueprint the way the VM and the code
/// generator both need it: the update graph as a Blueprint graph without
/// latent nodes, one state machine whose entry state exists, every blend
/// space a state plays in [blendSpaces], and every transition joining two
/// states with a pure rule graph that ends in a Result node.
List<LuminaBlueprintDiagnostic> validateAnimBlueprint(
  LuminaAnimBlueprintDocument document, {
  Map<String, LuminaBlendSpaceDocument> blendSpaces = const {},
  Map<String, LuminaPoseSearchDatabaseDocument> poseDatabases = const {},
}) {
  final diagnostics = validateBlueprint(document.updateDocument);
  for (final n in document.eventGraph.nodes) {
    if (LuminaBlueprintNodeLibrary.spec(n.registryId)?.kind == LuminaBlueprintNodeKind.latent) {
      diagnostics.add(LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.error,
          '${n.title} cannot run in an Animation Blueprint: the update graph runs to the end every frame.',
          nodeId: n.id));
    }
  }
  final machine = document.stateMachine;
  if (machine == null) {
    diagnostics.add(const LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.error, 'The AnimGraph has no state machine.'));
    return diagnostics;
  }
  if (document.stateMachines.length > 1) {
    diagnostics.add(LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.warning,
        "Only the first state machine ('${machine.name}') drives the pose; the others are ignored."));
  }
  if (machine.state(machine.entryState) == null) {
    diagnostics.add(LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.error, "Entry state '${machine.entryState}' does not exist."));
  }
  for (final s in machine.states) {
    final space = s.pose.blendSpace;
    if (space != null && !blendSpaces.containsKey(space)) {
      diagnostics.add(LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.error, "State '${s.name}' plays a missing blend space '$space'."));
    }
    if (s.pose.kind == LuminaAnimPoseKind.motionMatching) {
      final db = s.pose.database ?? '';
      if (db.isEmpty) {
        diagnostics.add(LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.error, "State '${s.name}' plays motion matching without a database."));
      } else if (!poseDatabases.containsKey(db)) {
        diagnostics.add(LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.error, "State '${s.name}' plays a missing pose search database '$db'."));
      }
    }
    if (s.pose.kind == LuminaAnimPoseKind.clip && (s.pose.clip ?? '').isEmpty) {
      diagnostics.add(LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.error, "State '${s.name}' plays no clip."));
    }
  }
  for (final t in machine.transitions) {
    if (machine.state(t.from) == null || machine.state(t.to) == null) {
      diagnostics.add(LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.error, "Transition '${t.id}' joins a missing state."));
    }
    final result = t.resultNode;
    if (result == null) {
      diagnostics.add(LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.error, "Transition '${t.id}' has no Result node."));
      continue;
    }
    if (!t.automaticRule && t.rule.wireInto(result.id, 'can_enter') == null && result.literals['can_enter'] != true) {
      diagnostics.add(LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.warning,
          "Transition '${t.id}' (${t.from} → ${t.to}) can never be taken: nothing is connected to its Result.",
          nodeId: result.id));
    }
    for (final d in validateBlueprint(LuminaBlueprintDocument(eventGraph: t.rule, variables: document.variables))) {
      diagnostics.add(LuminaBlueprintDiagnostic(d.severity, "Transition '${t.id}': ${d.message}", nodeId: d.nodeId, pinId: d.pinId));
    }
    if (t.rule.nodes.any((n) => LuminaBlueprintNodeLibrary.spec(n.registryId)?.kind != LuminaBlueprintNodeKind.pure)) {
      diagnostics.add(LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.error, "Transition '${t.id}': a rule can use pure nodes only."));
    }
  }
  return diagnostics;
}
