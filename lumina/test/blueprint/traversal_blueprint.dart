import 'dart:math' as math;

import 'package:lumina/lumina.dart';
import 'package:lumina_core/testing.dart';
import 'package:vector_math/vector_math_64.dart';

/// A Character Blueprint with a traversal component whose Jump input tries
/// a traversal action first and jumps when none fits, and a synthetic rig
/// with root-motion traversal clips for it.
abstract final class TraversalBlueprintFixture {
  /// A hurdle: the root runs 2.4 m forward in 1.5 s, rising 1.1 m over the
  /// obstacle in the middle.
  static LuminaSyntheticClip hurdle() => LuminaSyntheticClip(
        'Hurdle',
        1.5,
        (t) => (x: 0.0, z: 2.4 * t / 1.5, yaw: 0.0),
        height: (t) => t < 0.3 || t > 1.0 ? 0.0 : 1.1 * math.sin(math.pi * (t - 0.3) / 0.7),
      );

  /// A mantle: 0.9 m forward while rising 1.2 m in the first 0.7 s, then a
  /// step on.
  static LuminaSyntheticClip mantle() => LuminaSyntheticClip(
        'Mantle',
        1.4,
        (t) => (x: 0.0, z: 0.9 * t / 1.4, yaw: 0.0),
        height: (t) {
          final a = ((t - 0.1) / 0.6).clamp(0.0, 1.0);
          return 1.2 * a * a * (3 - 2 * a);
        },
      );

  static LuminaSyntheticClip vault() => LuminaSyntheticClip(
        'Vault',
        1.2,
        (t) => (x: 0.0, z: 2.0 * t / 1.2, yaw: 0.0),
        height: (t) => t < 0.2 || t > 0.9 ? 0.0 : 1.0 * math.sin(math.pi * (t - 0.2) / 0.7),
      );

  static LuminaPoseSearchRig rig() => LuminaPoseSearchRig(
        LuminaGlbAnimationSampler.fromGlb(LuminaSyntheticLocomotionRig.build(
            [LuminaSyntheticLocomotionRig.idle('Idle'), hurdle(), mantle(), vault()],
            fps: 60)),
        const LuminaPoseSearchSchema(),
      );

  /// The chooser rows for [rig]'s clips.
  static const List<LuminaTraversalAnimation> animations = [
    LuminaTraversalAnimation(
      action: LuminaTraversalActionType.hurdle,
      clip: 'Hurdle',
      maxHeight: 125,
      blendOutTime: 1.2,
      windows: [
        LuminaWarpWindow(target: 'FrontLedge', start: 0.2, end: 0.55, warpRotation: true),
        LuminaWarpWindow(target: 'BackFloor', start: 0.8, end: 1.05),
      ],
    ),
    LuminaTraversalAnimation(
      action: LuminaTraversalActionType.vault,
      clip: 'Vault',
      maxHeight: 125,
      windows: [LuminaWarpWindow(target: 'FrontLedge', start: 0.1, end: 0.5, warpRotation: true)],
    ),
    LuminaTraversalAnimation(
      action: LuminaTraversalActionType.mantle,
      clip: 'Mantle',
      maxHeight: 275,
      windows: [LuminaWarpWindow(target: 'FrontLedge', start: 0.05, end: 0.7, warpRotation: true)],
    ),
  ];

  static LuminaBlueprintDocument characterBlueprint({List<LuminaInputAction> inputActions = const []}) {
    final context = LuminaBlueprintTypeContext(inputActions: inputActions);
    LuminaBlueprintNode place(String id, String registryId, double y, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(registryId, nodeId: id, x: 0, y: y, literals: literals, context: context);
    var n = 0;
    LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
        LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
    final nodes = [
      place('jump_input', LuminaBlueprintNodeLibrary.enhancedInputAction, 0, {'action': 'IA_Jump'}),
      place('traverse', 'try_traversal_action', 120),
      place('fits', 'branch', 240),
      place('jump', 'jump', 360),
      place('stop_jumping', 'stop_jumping', 480),
    ];
    final wires = [
      wire('jump_input', 'started', 'traverse', 'exec_in'),
      wire('traverse', 'exec_out', 'fits', 'exec_in'),
      wire('traverse', 'return_value', 'fits', 'condition'),
      wire('fits', 'false_out', 'jump', 'exec_in'),
      wire('jump_input', 'completed', 'stop_jumping', 'exec_in'),
    ];
    return LuminaBlueprintDocument(
      parentClass: 'LuminaCharacter',
      components: [
        LuminaBlueprintComponent(
          id: 'capsule',
          name: 'CapsuleComponent',
          type: 'LuminaCapsuleComponent',
          properties: {'capsuleRadius': 35.0, 'capsuleHalfHeight': 90.0},
        ),
        LuminaBlueprintComponent(
          id: 'movement',
          name: 'CharacterMovement',
          type: 'LuminaCharacterMovementComponent',
          isSceneComponent: false,
          properties: {'maxWalkSpeed': 500.0},
        ),
        LuminaBlueprintComponent(
          id: 'traversal',
          name: 'Traversal',
          type: 'LuminaTraversalComponent',
          isSceneComponent: false,
          properties: {'animations': [for (final a in animations) a.toJson()]},
        ),
      ],
      eventGraph: LuminaBlueprintGraph(nodes: nodes, wires: wires),
    );
  }

  /// A floor (top at y 0) and a box [height] × [depth] whose front face is
  /// 200 cm ahead of the origin along −Z.
  static void level(LuminaWorld world, {double height = 100, double depth = 30}) {
    void box(Vector3 min, Vector3 max) {
      final actor = LuminaActor(location: (min + max) * 0.5);
      final c = LuminaCollisionComponent(shapeType: CollisionShapeType.box)..boxExtent = (max - min) * 0.5;
      CollisionProfile.applyBlockAll(c);
      actor.addComponent(c);
      world.persistentLevel.registerActor(actor);
    }

    box(Vector3(-3000, -100, -3000), Vector3(3000, 0, 3000));
    if (height > 0) box(Vector3(-200, 0, -200 - depth), Vector3(200, height, -200));
  }
}
