import 'package:lumina/lumina.dart';

/// An Actor Blueprint exercising physics for VM ↔ codegen parity: a
/// simulating Crate (Box, 10 kg override, friction / restitution) and a Ball
/// (Sphere, mass from density) built by the component mapping, every Physics
/// node on BeginPlay, the crate's and ball's velocities printed each Tick, and
/// Event Hit printing the physics contacts' normal impulse.
LuminaBlueprintDocument physicsBlueprint() {
  final components = [
    LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
    LuminaBlueprintComponent(id: 'crate', name: 'Crate', type: 'LuminaBoxComponent', parentId: 'root', properties: {
      'boxExtent': [25.0, 25.0, 25.0],
      'location': [0.0, 0.0, 120.0],
      'physics': {
        'simulate': true,
        'overrideMass': true,
        'massKg': 10.0,
        'friction': 0.5,
        'restitution': 0.2,
        'linearDamping': 0.01,
        'angularDamping': 0.0,
        'enableGravity': true,
        'locks': {
          'position': [false, false, false],
          'rotation': [false, false, false],
        },
      },
    }),
    LuminaBlueprintComponent(id: 'ball', name: 'Ball', type: 'LuminaSphereComponent', parentId: 'root', properties: {
      'radius': 20.0,
      'location': [150.0, 0.0, 60.0],
      'physics': {'simulate': true, 'restitution': 0.4},
    }),
  ];
  final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor', components: components);
  final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'bp_physics');
  LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
  var n = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  doc.eventGraph.nodes.addAll([
    place('event_beginplay', 'begin'),
    place(LuminaBlueprintNodeLibrary.getComponent, 'crate', {'component': 'Crate'}),
    place(LuminaBlueprintNodeLibrary.getComponent, 'ball', {'component': 'Ball'}),
    place('get_mass', 'crate_mass'),
    place('float_to_string', 'crate_mass_text', {'decimals': 1}),
    place('print_string', 'say_crate_mass'),
    place('is_simulating_physics', 'crate_simulating'),
    place('bool_to_string', 'crate_simulating_text'),
    place('print_string', 'say_simulating'),
    place('set_mass_override_in_kg', 'ball_mass', {'mass_in_kg': 3.0, 'override_mass': true}),
    place('get_mass', 'ball_mass_value'),
    place('float_to_string', 'ball_mass_text', {'decimals': 1}),
    place('print_string', 'say_ball_mass'),
    place('set_linear_damping', 'crate_damping', {'in_damping': 0.05}),
    place('set_angular_damping', 'ball_damping', {'in_damping': 0.1}),
    place('set_enable_gravity', 'ball_gravity', {'gravity_enabled': true}),
    place('add_impulse', 'kick_ball', {'impulse': [900.0, 0.0, 0.0]}),
    place('get_physics_linear_velocity', 'ball_velocity'),
    place('vector_to_string', 'ball_velocity_text'),
    place('print_string', 'say_ball_velocity'),
    place('add_impulse', 'lift_crate', {'impulse': [0.0, 0.0, 500.0], 'vel_change': false}),
    place('add_angular_impulse', 'spin_crate', {'impulse': [0.0, 0.0, 2000.0]}),
    place('set_physics_angular_velocity', 'spin_ball', {'new_ang_vel': [0.0, 90.0, 0.0], 'add_to_current': true}),
    place('get_physics_angular_velocity', 'ball_spin'),
    place('vector_to_string', 'ball_spin_text'),
    place('print_string', 'say_ball_spin'),
    place('set_physics_linear_velocity', 'crate_velocity', {'new_vel': [10.0, 0.0, 0.0], 'add_to_current': true}),
    place('add_force', 'push_crate', {'force': [5000.0, 0.0, 0.0]}),
    place('add_force_at_location', 'push_crate_high', {'force': [0.0, 2000.0, 0.0], 'location': [0.0, 0.0, 140.0]}),
    place('add_torque', 'twist_crate', {'torque': [0.0, 0.0, 10000.0]}),
    place('add_impulse_at_location', 'tap_crate', {'impulse': [0.0, 100.0, 0.0], 'location': [20.0, 0.0, 140.0]}),
    place('put_rigid_body_to_sleep', 'ball_sleep'),
    place('is_any_rigid_body_awake', 'ball_awake'),
    place('bool_to_string', 'ball_awake_text'),
    place('print_string', 'say_ball_awake'),
    place('wake_rigid_body', 'ball_wake'),
    place('set_simulate_physics', 'crate_on', {'simulate': true}),
    place('event_tick', 'tick'),
    place('get_physics_linear_velocity', 'crate_velocity_now'),
    place('vector_length', 'crate_speed'),
    place('float_to_string', 'crate_speed_text', {'decimals': 3}),
    place('print_string', 'say_crate_speed'),
    place('event_hit', 'hit'),
    place('vector_length', 'hit_impulse'),
    place('float_to_string', 'hit_impulse_text', {'decimals': 1}),
    place('print_string', 'say_hit'),
  ]);

  final chain = [
    'begin', 'say_crate_mass', 'say_simulating', 'ball_mass', 'say_ball_mass', 'crate_damping', 'ball_damping',
    'ball_gravity', 'kick_ball', 'say_ball_velocity', 'lift_crate', 'spin_crate', 'spin_ball', 'say_ball_spin',
    'crate_velocity', 'push_crate', 'push_crate_high', 'twist_crate', 'tap_crate', 'ball_sleep', 'say_ball_awake',
    'ball_wake', 'crate_on', //
  ];
  for (var i = 0; i + 1 < chain.length; i++) {
    doc.eventGraph.wires.add(wire(chain[i], 'exec_out', chain[i + 1], 'exec_in'));
  }
  void target(String component, List<String> nodes) {
    for (final node in nodes) {
      doc.eventGraph.wires.add(wire(component, 'return_value', node, 'target'));
    }
  }

  target('crate', ['crate_mass', 'crate_simulating', 'crate_damping', 'lift_crate', 'spin_crate', 'crate_velocity', 'push_crate',
      'push_crate_high', 'twist_crate', 'tap_crate', 'crate_on', 'crate_velocity_now']);
  target('ball', ['ball_mass', 'ball_mass_value', 'ball_damping', 'ball_gravity', 'kick_ball', 'ball_velocity', 'spin_ball',
      'ball_spin', 'ball_sleep', 'ball_awake', 'ball_wake']);
  doc.eventGraph.wires.addAll([
    wire('crate_mass', 'return_value', 'crate_mass_text', 'in_float'),
    wire('crate_mass_text', 'return_value', 'say_crate_mass', 'in_string'),
    wire('crate_simulating', 'return_value', 'crate_simulating_text', 'in_bool'),
    wire('crate_simulating_text', 'return_value', 'say_simulating', 'in_string'),
    wire('ball_mass_value', 'return_value', 'ball_mass_text', 'in_float'),
    wire('ball_mass_text', 'return_value', 'say_ball_mass', 'in_string'),
    wire('ball_velocity', 'return_value', 'ball_velocity_text', 'in_vec'),
    wire('ball_velocity_text', 'return_value', 'say_ball_velocity', 'in_string'),
    wire('ball_spin', 'return_value', 'ball_spin_text', 'in_vec'),
    wire('ball_spin_text', 'return_value', 'say_ball_spin', 'in_string'),
    wire('ball_awake', 'return_value', 'ball_awake_text', 'in_bool'),
    wire('ball_awake_text', 'return_value', 'say_ball_awake', 'in_string'),
    wire('tick', 'exec_tick_out', 'say_crate_speed', 'exec_in'),
    wire('crate_velocity_now', 'return_value', 'crate_speed', 'in_vec'),
    wire('crate_speed', 'return_value', 'crate_speed_text', 'in_float'),
    wire('crate_speed_text', 'return_value', 'say_crate_speed', 'in_string'),
    wire('hit', 'exec_out', 'say_hit', 'exec_in'),
    wire('hit', 'normal_impulse', 'hit_impulse', 'in_vec'),
    wire('hit_impulse', 'return_value', 'hit_impulse_text', 'in_float'),
    wire('hit_impulse_text', 'return_value', 'say_hit', 'in_string'),
  ]);
  return doc;
}
