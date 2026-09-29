// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).
// Blueprint contents/blueprints/bp_physics.lmas, compiled by Lumina.
// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';

class BpPhysics extends LuminaActor with LuminaBlueprintRuntime {
  BpPhysics({super.key, super.location, super.rotation}) {
    blueprintComponentTree = _components;
    blueprintComponents = LuminaBlueprintComponents.construct(this, _components);
  }

  @override
  String get blueprintClassName => 'bp_physics';

  /// The component tree (the Blueprint's construction script).
  static final List<LuminaBlueprintComponent> _components = [
    LuminaBlueprintComponent(
      id: 'root',
      name: 'DefaultSceneRoot',
      type: 'LuminaSceneComponent',
      parentId: null,
      properties: <String, dynamic>{},
      isSceneComponent: true,
    ),
    LuminaBlueprintComponent(
      id: 'crate',
      name: 'Crate',
      type: 'LuminaBoxComponent',
      parentId: 'root',
      properties: <String, dynamic>{'boxExtent': <dynamic>[25.0, 25.0, 25.0], 'location': <dynamic>[0.0, 0.0, 120.0], 'physics': <String, dynamic>{'simulate': true, 'overrideMass': true, 'massKg': 10.0, 'friction': 0.5, 'restitution': 0.2, 'linearDamping': 0.01, 'angularDamping': 0.0, 'enableGravity': true, 'locks': <String, dynamic>{'position': <dynamic>[false, false, false], 'rotation': <dynamic>[false, false, false]}}},
      isSceneComponent: true,
    ),
    LuminaBlueprintComponent(
      id: 'ball',
      name: 'Ball',
      type: 'LuminaSphereComponent',
      parentId: 'root',
      properties: <String, dynamic>{'radius': 20.0, 'location': <dynamic>[150.0, 0.0, 60.0], 'physics': <String, dynamic>{'simulate': true, 'restitution': 0.4}},
      isSceneComponent: true,
    ),
  ];

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    _onBegin();
  }

  @override
  void onTick(double deltaSeconds) {
    super.onTick(deltaSeconds);
    advanceBlueprintLatent(deltaSeconds);
    _onTick(deltaSeconds);
  }

  @override
  void notifyActorHit(LuminaActor other, LuminaCollisionComponent selfComponent, LuminaCollisionComponent otherComponent, HitResult hit) {
    super.notifyActorHit(other, selfComponent, otherComponent, hit);
    final hitOutputs = LuminaBlueprintFunctionLibrary.hitEventOutputs(this, other, hit);
    _onHit(hitOutputs);
  }

  /// Event BeginPlay (node begin).
  void _onBegin() {
    final p0 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Crate');
    if (trace != null) blueprintTrace('begin', 'crate', 'get_component', {'component': 'Crate', 'return_value': p0});
    final p1 = LuminaBlueprintFunctionLibrary.getMass(p0);
    if (trace != null) blueprintTrace('begin', 'crate_mass', 'get_mass', {'target': p0, 'return_value': p1});
    final p2 = LuminaBlueprintFunctionLibrary.floatToString(p1, 1);
    if (trace != null) blueprintTrace('begin', 'crate_mass_text', 'float_to_string', {'in_float': p1, 'decimals': 1, 'return_value': p2});
    LuminaBlueprintFunctionLibrary.printString(this, p2, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_crate_mass', 'print_string', {'in_string': p2, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p2);
    final p3 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Crate');
    if (trace != null) blueprintTrace('begin', 'crate', 'get_component', {'component': 'Crate', 'return_value': p3});
    final p4 = LuminaBlueprintFunctionLibrary.isSimulatingPhysics(p3);
    if (trace != null) blueprintTrace('begin', 'crate_simulating', 'is_simulating_physics', {'target': p3, 'return_value': p4});
    final p5 = LuminaBlueprintFunctionLibrary.boolToString(p4);
    if (trace != null) blueprintTrace('begin', 'crate_simulating_text', 'bool_to_string', {'in_bool': p4, 'return_value': p5});
    LuminaBlueprintFunctionLibrary.printString(this, p5, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_simulating', 'print_string', {'in_string': p5, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p5);
    final p6 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Ball');
    if (trace != null) blueprintTrace('begin', 'ball', 'get_component', {'component': 'Ball', 'return_value': p6});
    LuminaBlueprintFunctionLibrary.setMassOverrideInKg(p6, '', 3.0, true);
    if (trace != null) blueprintTrace('begin', 'ball_mass', 'set_mass_override_in_kg', {'target': p6, 'bone_name': '', 'mass_in_kg': 3.0, 'override_mass': true});
    final p7 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Ball');
    if (trace != null) blueprintTrace('begin', 'ball', 'get_component', {'component': 'Ball', 'return_value': p7});
    final p8 = LuminaBlueprintFunctionLibrary.getMass(p7);
    if (trace != null) blueprintTrace('begin', 'ball_mass_value', 'get_mass', {'target': p7, 'return_value': p8});
    final p9 = LuminaBlueprintFunctionLibrary.floatToString(p8, 1);
    if (trace != null) blueprintTrace('begin', 'ball_mass_text', 'float_to_string', {'in_float': p8, 'decimals': 1, 'return_value': p9});
    LuminaBlueprintFunctionLibrary.printString(this, p9, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_ball_mass', 'print_string', {'in_string': p9, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p9);
    final p10 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Crate');
    if (trace != null) blueprintTrace('begin', 'crate', 'get_component', {'component': 'Crate', 'return_value': p10});
    LuminaBlueprintFunctionLibrary.setLinearDamping(p10, 0.05);
    if (trace != null) blueprintTrace('begin', 'crate_damping', 'set_linear_damping', {'target': p10, 'in_damping': 0.05});
    final p11 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Ball');
    if (trace != null) blueprintTrace('begin', 'ball', 'get_component', {'component': 'Ball', 'return_value': p11});
    LuminaBlueprintFunctionLibrary.setAngularDamping(p11, 0.1);
    if (trace != null) blueprintTrace('begin', 'ball_damping', 'set_angular_damping', {'target': p11, 'in_damping': 0.1});
    final p12 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Ball');
    if (trace != null) blueprintTrace('begin', 'ball', 'get_component', {'component': 'Ball', 'return_value': p12});
    LuminaBlueprintFunctionLibrary.setEnableGravity(p12, true);
    if (trace != null) blueprintTrace('begin', 'ball_gravity', 'set_enable_gravity', {'target': p12, 'gravity_enabled': true});
    final p13 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Ball');
    if (trace != null) blueprintTrace('begin', 'ball', 'get_component', {'component': 'Ball', 'return_value': p13});
    LuminaBlueprintFunctionLibrary.addImpulse(p13, Vector3(900.0, 0.0, 0.0), '', false);
    if (trace != null) blueprintTrace('begin', 'kick_ball', 'add_impulse', {'target': p13, 'impulse': Vector3(900.0, 0.0, 0.0), 'bone_name': '', 'vel_change': false});
    final p14 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Ball');
    if (trace != null) blueprintTrace('begin', 'ball', 'get_component', {'component': 'Ball', 'return_value': p14});
    final p15 = LuminaBlueprintFunctionLibrary.getPhysicsLinearVelocity(p14, '');
    if (trace != null) blueprintTrace('begin', 'ball_velocity', 'get_physics_linear_velocity', {'target': p14, 'bone_name': '', 'return_value': p15});
    final p16 = LuminaBlueprintFunctionLibrary.vectorToString(p15);
    if (trace != null) blueprintTrace('begin', 'ball_velocity_text', 'vector_to_string', {'in_vec': p15, 'return_value': p16});
    LuminaBlueprintFunctionLibrary.printString(this, p16, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_ball_velocity', 'print_string', {'in_string': p16, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p16);
    final p17 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Crate');
    if (trace != null) blueprintTrace('begin', 'crate', 'get_component', {'component': 'Crate', 'return_value': p17});
    LuminaBlueprintFunctionLibrary.addImpulse(p17, Vector3(0.0, 0.0, 500.0), '', false);
    if (trace != null) blueprintTrace('begin', 'lift_crate', 'add_impulse', {'target': p17, 'impulse': Vector3(0.0, 0.0, 500.0), 'bone_name': '', 'vel_change': false});
    final p18 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Crate');
    if (trace != null) blueprintTrace('begin', 'crate', 'get_component', {'component': 'Crate', 'return_value': p18});
    LuminaBlueprintFunctionLibrary.addAngularImpulseInRadians(p18, Vector3(0.0, 0.0, 2000.0), '', false);
    if (trace != null) blueprintTrace('begin', 'spin_crate', 'add_angular_impulse', {'target': p18, 'impulse': Vector3(0.0, 0.0, 2000.0), 'bone_name': '', 'vel_change': false});
    final p19 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Ball');
    if (trace != null) blueprintTrace('begin', 'ball', 'get_component', {'component': 'Ball', 'return_value': p19});
    LuminaBlueprintFunctionLibrary.setPhysicsAngularVelocityInDegrees(p19, Vector3(0.0, 90.0, 0.0), true, '');
    if (trace != null) blueprintTrace('begin', 'spin_ball', 'set_physics_angular_velocity', {'target': p19, 'new_ang_vel': Vector3(0.0, 90.0, 0.0), 'add_to_current': true, 'bone_name': ''});
    final p20 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Ball');
    if (trace != null) blueprintTrace('begin', 'ball', 'get_component', {'component': 'Ball', 'return_value': p20});
    final p21 = LuminaBlueprintFunctionLibrary.getPhysicsAngularVelocityInDegrees(p20, '');
    if (trace != null) blueprintTrace('begin', 'ball_spin', 'get_physics_angular_velocity', {'target': p20, 'bone_name': '', 'return_value': p21});
    final p22 = LuminaBlueprintFunctionLibrary.vectorToString(p21);
    if (trace != null) blueprintTrace('begin', 'ball_spin_text', 'vector_to_string', {'in_vec': p21, 'return_value': p22});
    LuminaBlueprintFunctionLibrary.printString(this, p22, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_ball_spin', 'print_string', {'in_string': p22, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p22);
    final p23 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Crate');
    if (trace != null) blueprintTrace('begin', 'crate', 'get_component', {'component': 'Crate', 'return_value': p23});
    LuminaBlueprintFunctionLibrary.setPhysicsLinearVelocity(p23, Vector3(10.0, 0.0, 0.0), true, '');
    if (trace != null) blueprintTrace('begin', 'crate_velocity', 'set_physics_linear_velocity', {'target': p23, 'new_vel': Vector3(10.0, 0.0, 0.0), 'add_to_current': true, 'bone_name': ''});
    final p24 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Crate');
    if (trace != null) blueprintTrace('begin', 'crate', 'get_component', {'component': 'Crate', 'return_value': p24});
    LuminaBlueprintFunctionLibrary.addForce(p24, Vector3(5000.0, 0.0, 0.0), '', false);
    if (trace != null) blueprintTrace('begin', 'push_crate', 'add_force', {'target': p24, 'force': Vector3(5000.0, 0.0, 0.0), 'bone_name': '', 'accel_change': false});
    final p25 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Crate');
    if (trace != null) blueprintTrace('begin', 'crate', 'get_component', {'component': 'Crate', 'return_value': p25});
    LuminaBlueprintFunctionLibrary.addForceAtLocation(p25, Vector3(0.0, 2000.0, 0.0), Vector3(0.0, 0.0, 140.0), '');
    if (trace != null) blueprintTrace('begin', 'push_crate_high', 'add_force_at_location', {'target': p25, 'force': Vector3(0.0, 2000.0, 0.0), 'location': Vector3(0.0, 0.0, 140.0), 'bone_name': ''});
    final p26 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Crate');
    if (trace != null) blueprintTrace('begin', 'crate', 'get_component', {'component': 'Crate', 'return_value': p26});
    LuminaBlueprintFunctionLibrary.addTorqueInRadians(p26, Vector3(0.0, 0.0, 10000.0), '', false);
    if (trace != null) blueprintTrace('begin', 'twist_crate', 'add_torque', {'target': p26, 'torque': Vector3(0.0, 0.0, 10000.0), 'bone_name': '', 'accel_change': false});
    final p27 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Crate');
    if (trace != null) blueprintTrace('begin', 'crate', 'get_component', {'component': 'Crate', 'return_value': p27});
    LuminaBlueprintFunctionLibrary.addImpulseAtLocation(p27, Vector3(0.0, 100.0, 0.0), Vector3(20.0, 0.0, 140.0), '');
    if (trace != null) blueprintTrace('begin', 'tap_crate', 'add_impulse_at_location', {'target': p27, 'impulse': Vector3(0.0, 100.0, 0.0), 'location': Vector3(20.0, 0.0, 140.0), 'bone_name': ''});
    final p28 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Ball');
    if (trace != null) blueprintTrace('begin', 'ball', 'get_component', {'component': 'Ball', 'return_value': p28});
    LuminaBlueprintFunctionLibrary.putRigidBodyToSleep(p28, '');
    if (trace != null) blueprintTrace('begin', 'ball_sleep', 'put_rigid_body_to_sleep', {'target': p28, 'bone_name': ''});
    final p29 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Ball');
    if (trace != null) blueprintTrace('begin', 'ball', 'get_component', {'component': 'Ball', 'return_value': p29});
    final p30 = LuminaBlueprintFunctionLibrary.isAnyRigidBodyAwake(p29);
    if (trace != null) blueprintTrace('begin', 'ball_awake', 'is_any_rigid_body_awake', {'target': p29, 'return_value': p30});
    final p31 = LuminaBlueprintFunctionLibrary.boolToString(p30);
    if (trace != null) blueprintTrace('begin', 'ball_awake_text', 'bool_to_string', {'in_bool': p30, 'return_value': p31});
    LuminaBlueprintFunctionLibrary.printString(this, p31, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_ball_awake', 'print_string', {'in_string': p31, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p31);
    final p32 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Ball');
    if (trace != null) blueprintTrace('begin', 'ball', 'get_component', {'component': 'Ball', 'return_value': p32});
    LuminaBlueprintFunctionLibrary.wakeRigidBody(p32, '');
    if (trace != null) blueprintTrace('begin', 'ball_wake', 'wake_rigid_body', {'target': p32, 'bone_name': ''});
    final p33 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Crate');
    if (trace != null) blueprintTrace('begin', 'crate', 'get_component', {'component': 'Crate', 'return_value': p33});
    LuminaBlueprintFunctionLibrary.setSimulatePhysics(p33, true);
    if (trace != null) blueprintTrace('begin', 'crate_on', 'set_simulate_physics', {'target': p33, 'simulate': true});
  }

  /// Event Tick (node tick).
  void _onTick(double deltaSeconds) {
    final p34 = LuminaBlueprintFunctionLibrary.getComponent(this, 'Crate');
    if (trace != null) blueprintTrace('tick', 'crate', 'get_component', {'component': 'Crate', 'return_value': p34});
    final p35 = LuminaBlueprintFunctionLibrary.getPhysicsLinearVelocity(p34, '');
    if (trace != null) blueprintTrace('tick', 'crate_velocity_now', 'get_physics_linear_velocity', {'target': p34, 'bone_name': '', 'return_value': p35});
    final p36 = LuminaBlueprintFunctionLibrary.vectorLength(p35);
    if (trace != null) blueprintTrace('tick', 'crate_speed', 'vector_length', {'in_vec': p35, 'return_value': p36});
    final p37 = LuminaBlueprintFunctionLibrary.floatToString(p36, 3);
    if (trace != null) blueprintTrace('tick', 'crate_speed_text', 'float_to_string', {'in_float': p36, 'decimals': 3, 'return_value': p37});
    LuminaBlueprintFunctionLibrary.printString(this, p37, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('tick', 'say_crate_speed', 'print_string', {'in_string': p37, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p37);
  }

  /// Event Hit (node hit).
  void _onHit(Map<String, Object?> hitOutputs) {
    final p38 = LuminaBlueprintFunctionLibrary.vectorLength((hitOutputs['normal_impulse'] as Vector3));
    if (trace != null) blueprintTrace('hit', 'hit_impulse', 'vector_length', {'in_vec': (hitOutputs['normal_impulse'] as Vector3), 'return_value': p38});
    final p39 = LuminaBlueprintFunctionLibrary.floatToString(p38, 1);
    if (trace != null) blueprintTrace('hit', 'hit_impulse_text', 'float_to_string', {'in_float': p38, 'decimals': 1, 'return_value': p39});
    LuminaBlueprintFunctionLibrary.printString(this, p39, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('hit', 'say_hit', 'print_string', {'in_string': p39, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p39);
  }

  // BEGIN USER CODE: class_body
  // END USER CODE
}
