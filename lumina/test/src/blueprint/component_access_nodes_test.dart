import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../blueprint/third_person_blueprint.dart';

/// `Get <Component>` on Self yields a typed component pin, and
/// the per-type nodes change the live components of a real world.
void main() {
  var wireCount = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${wireCount++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  final actions = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input).actions.values.toList();

  LuminaWorld world() {
    final w = LuminaWorld(worldType: LuminaWorldType.game);
    w.subsystems.registerSubsystem<LuminaCollisionSubsystem>(LuminaCollisionSubsystem(), w);
    w.persistentLevel.registerActor(
        LuminaPrimitiveActor(shape: LuminaPrimitiveShape.plane, size: Vector3(6000, 0, 6000), color: Vector3.all(0.5)));
    return w;
  }

  test('Get CameraBoom on the Third Person character is a Spring Arm pin; unknown names are errors', () {
    final doc = thirdPersonCharacterBlueprint(inputActions: actions);
    final context = LuminaBlueprintTypeContext.forDocument(doc, inputActions: actions, className: 'BP_ThirdPersonCharacter');
    expect(context.selfClass, 'Actor:BP_ThirdPersonCharacter');
    expect(context.actorParents['BP_ThirdPersonCharacter'], 'LuminaCharacter');
    expect(context.components.map((c) => c.name), containsAll(['CameraBoom', 'FollowCamera', 'CharacterMovement']));
    final boom = LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.getComponent,
        nodeId: 'boom', literals: {'component': 'CameraBoom'}, context: context);
    expect(boom.title, 'Get CameraBoom');
    expect(boom.category, 'Components');
    expect(boom.pin('return_value')!.objectClass, 'Component:LuminaSpringArmComponent');
    final camera = LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.getComponent,
        nodeId: 'cam', literals: {'component': 'FollowCamera'}, context: context);
    expect(camera.pin('return_value')!.objectClass, 'Component:LuminaCameraComponent');
    final movement = LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.getComponent,
        nodeId: 'cm', literals: {'component': 'CharacterMovement'}, context: context);
    expect(movement.pin('return_value')!.objectClass, 'Component:LuminaCharacterMovementComponent');

    final boomOut = LuminaBlueprintNodeLibrary.pinsOf(boom, context)!.outputs.single;
    LuminaBlueprintPinSpec target(String id) =>
        LuminaBlueprintNodeLibrary.spec(id)!.inputs.firstWhere((p) => p.id == 'target');
    expect(LuminaBlueprintNodeLibrary.canConnect(boomOut, target('set_target_arm_length'), context: context), isTrue);
    expect(LuminaBlueprintNodeLibrary.canConnect(boomOut, target('set_relative_location'), context: context), isTrue,
        reason: 'a spring arm is a scene component');
    expect(LuminaBlueprintNodeLibrary.connectionError(boomOut, target('set_field_of_view'), context: context),
        'Cannot connect Spring Arm to Camera.');

    doc.eventGraph.nodes.add(LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.getComponent,
        nodeId: 'nope', literals: {'component': 'Missing'}, context: context));
    final errors = validateBlueprint(doc, inputActions: actions, className: 'BP_ThirdPersonCharacter').where((d) => d.isError);
    expect(errors.single.message, contains("unknown component 'Missing'"));
  });

  test('component nodes change the live components: arm length, active camera, walk speed, transforms', () {
    final doc = thirdPersonCharacterBlueprint(inputActions: actions);
    final context = LuminaBlueprintTypeContext.forDocument(doc, inputActions: actions, className: 'BP_ThirdPersonCharacter');
    LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    doc.eventGraph.nodes.addAll([
      place('event_beginplay', 'begin'),
      place(LuminaBlueprintNodeLibrary.getComponent, 'boom', {'component': 'CameraBoom'}),
      place('set_target_arm_length', 'arm', {'target_arm_length': 500.0}),
      place('get_target_arm_length', 'arm_len'),
      place('add_component', 'add_cam', {'class': 'Component:LuminaCameraComponent', 'name': 'SecondCamera'}),
      place('set_camera_active', 'activate', {'active': true}),
      place(LuminaBlueprintNodeLibrary.getComponent, 'cm', {'component': 'CharacterMovement'}),
      place('set_max_walk_speed', 'speed', {'max_walk_speed': 900.0}),
      place('set_relative_location', 'boom_at', {'new_location': [0.0, 0.0, 120.0]}),
      place('get_component_by_class', 'capsule', {'class': 'Component:LuminaCapsuleComponent'}),
      place('set_collision_layer', 'layer', {'layer': 4}),
      place('crouch', 'duck'),
      place('is_crouched', 'crouched'),
      place('print_string', 'report'),
      place('get_class_name', 'boom_class'),
    ]);
    doc.eventGraph.wires.addAll([
      wire('begin', 'exec_out', 'arm', 'exec_in'),
      wire('boom', 'return_value', 'arm', 'target'),
      wire('arm', 'exec_out', 'add_cam', 'exec_in'),
      wire('add_cam', 'exec_out', 'activate', 'exec_in'),
      wire('add_cam', 'return_value', 'activate', 'target'),
      wire('activate', 'exec_out', 'speed', 'exec_in'),
      wire('cm', 'return_value', 'speed', 'target'),
      wire('speed', 'exec_out', 'boom_at', 'exec_in'),
      wire('boom', 'return_value', 'boom_at', 'target'),
      wire('boom_at', 'exec_out', 'layer', 'exec_in'),
      wire('capsule', 'return_value', 'layer', 'target'),
      wire('layer', 'exec_out', 'duck', 'exec_in'),
      wire('cm', 'return_value', 'duck', 'target'),
      wire('duck', 'exec_out', 'report', 'exec_in'),
      wire('boom', 'return_value', 'boom_class', 'object'),
      wire('boom_class', 'return_value', 'report', 'in_string'),
    ]);
    final cls = LuminaBlueprintClass.fromDocument(doc, name: 'BP_ThirdPersonCharacter', inputActions: actions);
    expect(cls.diagnostics, isEmpty, reason: '${cls.diagnostics}');
    final w = world();
    final character = cls.instantiate(location: Vector3(0, 100, 0)) as LuminaBlueprintCharacter;
    final trace = <LuminaBlueprintTraceEvent>[];
    character.trace = trace.add;
    w.persistentLevel.registerActor(character);
    w.beginPlay();
    final arm = character.blueprintComponents['boom'] as LuminaSpringArmComponent;
    expect(arm.targetArmLength, 500.0);
    expect(LuminaBlueprintFunctionLibrary.getTargetArmLength(arm), 500.0);
    expect(arm.relativeLocation, Vector3(0, 120, 0), reason: 'authoring (0,0,120) is 120 cm up');
    final original = character.blueprintComponents['camera'] as LuminaCameraComponent;
    final second = character.components.whereType<LuminaCameraComponent>().firstWhere((c) => c != original);
    expect(LuminaBlueprintFunctionLibrary.getComponent(character, 'SecondCamera'), same(second));
    expect(LuminaBlueprintFunctionLibrary.getDisplayName(second), 'SecondCamera');
    expect(LuminaBlueprintFunctionLibrary.getDisplayName(arm), 'CameraBoom');
    expect(second.isActive, isTrue);
    expect(original.isActive, isFalse, reason: 'activating one camera deactivates the other');
    expect(w.activeCamera, same(second));
    expect(character.characterMovement.maxWalkSpeed, 900.0);
    expect(character.capsuleComponent.collisionLayer, 4);
    expect(character.characterMovement.isCrouched, isTrue);
    expect(LuminaBlueprintFunctionLibrary.isCrouched(character, null), isTrue);
    expect(trace.firstWhere((t) => t.printed != null).printed, 'LuminaSpringArmComponent');
    expect(LuminaBlueprintFunctionLibrary.classOf(arm), 'Component:LuminaSpringArmComponent');
    expect(LuminaBlueprintFunctionLibrary.isA(arm, 'Component:LuminaSceneComponent'), isTrue);
    expect(LuminaBlueprintFunctionLibrary.isA(arm, 'Component:LuminaCameraComponent'), isFalse);
    expect(LuminaBlueprintFunctionLibrary.getComponentByClass(character, 'Component:LuminaSpringArmComponent'), same(arm));

    // Crouching caps the walk speed; Un Crouch restores it; Launch starts a fall.
    LuminaBlueprintFunctionLibrary.unCrouch(character, null);
    expect(character.characterMovement.isCrouched, isFalse);
    for (var i = 0; i < 30; i++) {
      w.tick(1 / 60);
    }
    expect(character.characterMovement.isFalling, isFalse, reason: 'landed on the plane');
    LuminaBlueprintFunctionLibrary.launchCharacter(character, null, Vector3(0, 0, 600), false, true);
    expect(character.characterMovement.isFalling, isTrue);
    expect(character.characterMovement.velocity.y, 600.0);
    LuminaBlueprintFunctionLibrary.stopMovementImmediately(character, null);
    expect(character.characterMovement.velocity, Vector3.zero());
    expect(LuminaBlueprintFunctionLibrary.getMovementMode(character, null), 'Falling');
    LuminaBlueprintFunctionLibrary.setMovementMode(character, null, 'Flying');
    expect(character.characterMovement.isFlying, isTrue);
    w.cleanup();
  });

  test('world and relative transforms, attach, visibility and camera FOV on a plain actor', () {
    final actor = LuminaActor();
    final parent = LuminaSceneComponent()..attachToComponent(actor.rootComponent);
    final child = LuminaSceneComponent();
    actor.addComponent(parent);
    actor.addComponent(child);
    LuminaBlueprintFunctionLibrary.setRelativeLocation(parent, Vector3(100, 0, 0));
    LuminaBlueprintFunctionLibrary.setRelativeRotation(parent, const LuminaRotator(0, 0, 90));
    LuminaBlueprintFunctionLibrary.attachToComponent(child, parent);
    expect(child.parentComponent, same(parent));
    LuminaBlueprintFunctionLibrary.setWorldLocation(child, Vector3(100, 50, 0));
    final world = LuminaBlueprintFunctionLibrary.getWorldLocation(child);
    expect(world.x, closeTo(100, 1e-6));
    expect(world.y, closeTo(50, 1e-6));
    expect(world.z, closeTo(0, 1e-6));
    expect(LuminaBlueprintFunctionLibrary.getRelativeLocation(child).length, closeTo(50, 1e-6));
    LuminaBlueprintFunctionLibrary.setWorldRotation(child, const LuminaRotator(0, 0, 0));
    expect(LuminaBlueprintFunctionLibrary.getWorldRotation(child).yaw.abs(), lessThan(1e-6));
    expect(LuminaBlueprintFunctionLibrary.getRelativeRotation(child).yaw, closeTo(-90, 1e-6));
    expect(LuminaBlueprintFunctionLibrary.getRelativeRotation(parent).yaw, closeTo(90, 1e-6));
    LuminaBlueprintFunctionLibrary.setRelativeScale(child, Vector3(1, 2, 3));
    expect(LuminaBlueprintFunctionLibrary.getRelativeScale(child), Vector3(1, 2, 3));
    LuminaBlueprintFunctionLibrary.setHiddenInGame(child, true);
    expect(child.isVisible, isFalse);
    LuminaBlueprintFunctionLibrary.setComponentVisibility(child, true);
    expect(child.isVisible, isTrue);
    final camera = LuminaCameraComponent();
    LuminaBlueprintFunctionLibrary.setFieldOfView(camera, 75);
    expect(LuminaBlueprintFunctionLibrary.getFieldOfView(camera), 75.0);
    expect(LuminaBlueprintFunctionLibrary.isCameraActive(camera), isFalse);
    LuminaBlueprintFunctionLibrary.setCameraActive(camera, true);
    expect(LuminaBlueprintFunctionLibrary.isCameraActive(camera), isTrue);
    expect(LuminaBlueprintFunctionLibrary.getDisplayName(camera), 'LuminaCameraComponent');
    // Nulls are ignored, never thrown on.
    LuminaBlueprintFunctionLibrary.setTargetArmLength(null, 1);
    expect(LuminaBlueprintFunctionLibrary.getWorldLocation(null), Vector3.zero());
  });
}
