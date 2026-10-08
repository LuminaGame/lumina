import 'package:lumina/lumina.dart';
import 'package:lumina_core/testing.dart';

/// An Animation Blueprint whose entry state plays motion matching over a
/// synthetic locomotion database, with a Frozen (hold) state entered while
/// the `Freeze` variable is true.
abstract final class MotionMatchingBlueprintFixture {
  static const String meshPath = 'contents/meshes/Rig.glb';
  static const String databasePath = 'contents/animations/PSD_Rig.lmas';

  /// The rig's GLB: idle, start, forward walk loop and stop clips.
  static List<LuminaSyntheticClip> clips() => [
        LuminaSyntheticLocomotionRig.idle('Idle'),
        LuminaSyntheticLocomotionRig.start('Start'),
        LuminaSyntheticLocomotionRig.walk('WalkF', 0, 1),
        LuminaSyntheticLocomotionRig.stop('Stop'),
      ];

  static const LuminaPoseSearchDatabaseDocument database = LuminaPoseSearchDatabaseDocument(
    targetMesh: meshPath,
    clips: [
      LuminaPoseSearchClip('Idle', loop: true),
      LuminaPoseSearchClip('Start'),
      LuminaPoseSearchClip('WalkF', loop: true),
      LuminaPoseSearchClip('Stop'),
    ],
  );

  static LuminaAnimBlueprintDocument animBlueprint() {
    final variables = [
      const LuminaBlueprintVariable(name: 'Freeze', typeName: 'Bool', defaultValue: false),
      const LuminaBlueprintVariable(name: LuminaAnimBlueprintInstance.matchedClipVariable, typeName: 'String', defaultValue: ''),
    ];
    final context = LuminaBlueprintTypeContext(variables: variables);
    LuminaBlueprintNode place(String id, String nodeId, double x, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, x: x, y: 0, literals: literals, context: context);
    LuminaBlueprintGraph flag({bool not = false}) => LuminaBlueprintGraph(
          nodes: [
            place(LuminaBlueprintNodeLibrary.variableGet, 'flag', 0, {'variable': 'Freeze'}),
            if (not) place('bool_not', 'not', 240),
            place(LuminaBlueprintNodeLibrary.transitionResult, 'result', 480),
          ],
          wires: [
            if (not) ...[
              LuminaBlueprintWire(id: 'w0', fromNodeId: 'flag', fromPinId: 'value', toNodeId: 'not', toPinId: 'a'),
              LuminaBlueprintWire(id: 'w1', fromNodeId: 'not', fromPinId: 'return_value', toNodeId: 'result', toPinId: 'can_enter'),
            ] else
              LuminaBlueprintWire(id: 'w0', fromNodeId: 'flag', fromPinId: 'value', toNodeId: 'result', toPinId: 'can_enter'),
          ],
        );
    return LuminaAnimBlueprintDocument(
      targetMesh: meshPath,
      variables: variables,
      eventGraph: LuminaBlueprintGraph(nodes: [
        LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.updateAnimation, nodeId: 'update', x: 0, y: 0),
      ]),
      stateMachines: [
        LuminaAnimStateMachine(
          name: 'Locomotion',
          entryState: 'Locomotion',
          states: const [
            LuminaAnimState('Locomotion', LuminaAnimPose.motionMatching(databasePath, blendTime: 0.25), x: 120, y: 60),
            LuminaAnimState('Frozen', LuminaAnimPose.hold(), x: 360, y: 60),
          ],
          transitions: [
            LuminaAnimTransition(id: 'locomotion_to_frozen', from: 'Locomotion', to: 'Frozen', rule: flag()),
            LuminaAnimTransition(id: 'frozen_to_locomotion', from: 'Frozen', to: 'Locomotion', rule: flag(not: true)),
          ],
        ),
      ],
    );
  }
}
