import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'anim_rig.dart';

void main() {
  LuminaBlueprintGraph flag(String variable) => LuminaBlueprintGraph(
        nodes: [
          LuminaBlueprintNode(
            id: 'flag',
            registryId: 'variable_get',
            title: 'Get $variable',
            literals: {'variable': variable},
            outputs: const [LuminaBlueprintPin(id: 'value', name: 'Value', type: LuminaPinType.boolean, isOutput: true)],
          ),
          LuminaBlueprintNode(
            id: 'result',
            registryId: 'transition_result',
            title: 'Result',
            inputs: const [LuminaBlueprintPin(id: 'can_enter', name: 'Can Enter', type: LuminaPinType.boolean, isOutput: false)],
          ),
        ],
        wires: const [
          LuminaBlueprintWire(id: 'w0', fromNodeId: 'flag', fromPinId: 'value', toNodeId: 'result', toPinId: 'can_enter'),
        ],
      );

  const reserved = [
    LuminaBlueprintVariable(name: LuminaAnimBlueprintInstance.stateTimeVariable, typeName: 'Float', defaultValue: 0.0),
    LuminaBlueprintVariable(name: LuminaAnimBlueprintInstance.clipFinishedVariable, typeName: 'Bool', defaultValue: false),
    LuminaBlueprintVariable(name: LuminaAnimBlueprintInstance.rootYawOffsetVariable, typeName: 'Float', defaultValue: 0.0),
  ];

  LuminaAnimBlueprintClass missingClipClass() => LuminaAnimBlueprintClass.fromDocument(
        LuminaAnimBlueprintDocument(variables: reserved.toList(), stateMachines: [
          LuminaAnimStateMachine(name: 'Locomotion', entryState: 'Idle', states: const [
            LuminaAnimState('Idle', LuminaAnimPose.clip('Idle_Loop')),
            LuminaAnimState('MissingState', LuminaAnimPose.clip('Non_Existent_Clip')),
          ], transitions: [
            LuminaAnimTransition(id: 'idle_to_missing', from: 'Idle', to: 'MissingState', rule: flag('ClipFinished')),
          ]),
        ]),
        name: 'ABP_Missing',
      );

  group('AnimBlueprint missing clip safety', () {
    test('instance holds pose safely when transitioning to a missing clip', () {
      final cls = missingClipClass();
      final rig = AnimRig.abp((mesh) => cls.instantiate(mesh)..clipDurationFallbacks['Idle_Loop'] = 0.1);
      rig.world.beginPlay();

      // Advance past Idle_Loop so ClipFinished becomes true and transitions to MissingState
      rig.world.tick(0.15);
      expect(rig.anim!.currentState, 'MissingState');

      // Ticking in MissingState should not throw an ArgumentError
      expect(() => rig.world.tick(0.1), returnsNormally);
    });

    test('random clip selects from available clips when mesh has loaded clips', () {
      final cls = LuminaAnimBlueprintClass.fromDocument(
        LuminaAnimBlueprintDocument(variables: reserved.toList(), stateMachines: [
          LuminaAnimStateMachine(
            name: 'Locomotion',
            entryState: 'Break',
            states: [
              LuminaAnimState('Break', LuminaAnimPose.randomClip(['NonExistent_A', 'NonExistent_B', 'FallbackClip'])),
            ],
            transitions: const [],
          ),
        ]),
        name: 'ABP_Random',
      );

      final rig = AnimRig.abp((mesh) => cls.instantiate(mesh)..clipDurationFallbacks['FallbackClip'] = 1.0);
      rig.world.beginPlay();

      expect(() => rig.world.tick(0.1), returnsNormally);
    });
  });
}
