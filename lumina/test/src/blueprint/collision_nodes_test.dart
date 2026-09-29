import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// The Collision nodes change live shape components; the
/// component mapping builds every shape with its preset.
void main() {
  var wireCount = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${wireCount++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  LuminaWorld world() {
    final w = LuminaWorld(worldType: LuminaWorldType.game);
    w.subsystems.registerSubsystem<LuminaCollisionSubsystem>(LuminaCollisionSubsystem(), w);
    return w;
  }

  /// A character drifting along −Z at 300 cm/s for [seconds] (no gravity).
  double drift(LuminaWorld w, LuminaCharacter character, double seconds) {
    final movement = character.characterMovement;
    movement.gravityScale = 0.0;
    movement.setMovementMode(MovementMode.falling);
    for (var i = 0; i < (seconds * 60).round(); i++) {
      movement.velocity.setValues(0, 0, -300);
      w.tick(1 / 60);
    }
    return character.actorLocation.z;
  }

  test('the node specs exist in Components|Collision with typed targets', () {
    for (final id in [
      'set_collision_preset',
      'get_collision_preset',
      'set_collision_response_to_channel',
      'set_collision_response_to_all_channels',
      'get_collision_response_to_channel',
      'set_collision_object_type',
      'get_collision_object_type',
      'set_generate_overlap_events',
      'get_overlapping_actors',
      'get_overlapping_components',
      'is_overlapping_actor',
    ]) {
      final spec = LuminaBlueprintNodeLibrary.spec(id)!;
      expect(spec.category, 'Components|Collision', reason: id);
      expect(spec.inputs.firstWhere((p) => p.id == 'target').objectClass, 'Component:LuminaCollisionComponent', reason: id);
    }
    expect(LuminaBlueprintNodeLibrary.spec('set_box_extent')!.inputs.first.objectClass, isNull);
    expect(LuminaBlueprintNodeLibrary.spec('set_box_extent')!.inputs[1].objectClass, 'Component:LuminaBoxComponent');
    expect(LuminaBlueprintNodeLibrary.spec('get_sphere_radius')!.inputs.single.objectClass, 'Component:LuminaSphereComponent');
    expect(LuminaBlueprintNodeLibrary.spec('set_capsule_size')!.inputs[1].objectClass, 'Component:LuminaCapsuleComponent');
    expect(LuminaBlueprintNodeLibrary.spec('set_collision_enabled')!.inputs.last.type, LuminaPinType.string);
    expect(LuminaBlueprintNodeLibrary.spec('set_collision_enabled')!.inputs.last.defaultValue, 'QueryAndPhysics');
    for (final id in LuminaBlueprintFunctionLibrary.callShapes.keys.where((k) => k.contains('collision') || k.contains('overlapping'))) {
      expect(LuminaBlueprintFunctionLibrary.builtInFunctions.containsKey(id), isTrue, reason: '$id has a VM function');
    }
    // A box is a collision component: its Get pin connects to Set Collision Preset's target.
    expect(LuminaBlueprintObjectClass.ancestors('Component:LuminaBoxComponent'),
        ['Component:LuminaCollisionComponent', 'Component:LuminaSceneComponent', 'Component:LuminaActorComponent']);
  });

  test('a Blueprint with Box (Trigger), Sphere (OverlapAll) and Cylinder (BlockAll) round-trips and builds real components', () {
    final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
      LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
      LuminaBlueprintComponent(
          id: 'box',
          name: 'TriggerBox',
          type: 'LuminaBoxComponent',
          parentId: 'root',
          properties: {'boxExtent': [100.0, 120.0, 140.0], 'preset': 'Trigger', 'location': [0.0, 200.0, 0.0]}),
      LuminaBlueprintComponent(
          id: 'sphere',
          name: 'PickupSphere',
          type: 'LuminaSphereComponent',
          parentId: 'root',
          properties: {'radius': 60.0, 'preset': 'OverlapAll', 'generateOverlapEvents': true}),
      LuminaBlueprintComponent(
          id: 'pillar',
          name: 'Pillar',
          type: 'LuminaCylinderComponent',
          parentId: 'root',
          properties: {'radius': 30.0, 'halfHeight': 150.0, 'preset': 'BlockAll'}),
      LuminaBlueprintComponent(
          id: 'cone',
          name: 'Cone',
          type: 'LuminaConeComponent',
          parentId: 'root',
          properties: {
            'radius': 40.0,
            'halfHeight': 60.0,
            'preset': 'custom',
            'objectType': 'pawn',
            'responses': {'worldStatic': 'block', 'worldDynamic': 'ignore', 'pawn': 'overlap'},
            'collisionEnabled': true,
          }),
      LuminaBlueprintComponent(
          id: 'hull', name: 'Hull', type: 'LuminaConvexComponent', parentId: 'root', properties: {'hullAsset': 'contents/meshes/static/SM_Missing.lmas'}),
    ]);
    final json = doc.toJson();
    final back = LuminaBlueprintDocument.fromJson(json);
    expect(back.components.map((c) => c.type).toList(),
        ['LuminaSceneComponent', 'LuminaBoxComponent', 'LuminaSphereComponent', 'LuminaCylinderComponent', 'LuminaConeComponent', 'LuminaConvexComponent']);
    expect(back.components[1].properties['preset'], 'Trigger');
    expect((back.components[4].properties['responses'] as Map)['worldDynamic'], 'ignore');

    final actor = LuminaActor();
    final diagnostics = <LuminaBlueprintDiagnostic>[];
    final built = LuminaBlueprintComponents.construct(actor, back.components, diagnostics: diagnostics);
    final box = built['box'] as LuminaBoxComponent;
    expect(box.boxExtent, Vector3(100, 140, 120), reason: 'authoring (X, Y, Z) half extents are runtime (x, z, y)');
    expect(box.preset, LuminaCollisionPreset.trigger);
    expect(box.relativeLocation, Vector3(0, 0, -200), reason: 'authoring +Y is runtime −Z');
    final sphere = built['sphere'] as LuminaSphereComponent;
    expect(sphere.radius, 60.0);
    expect(sphere.preset, LuminaCollisionPreset.overlapAll);
    final pillar = built['pillar'] as LuminaCylinderComponent;
    expect(pillar.radius, 30.0);
    expect(pillar.halfHeight, 150.0);
    expect(pillar.height, 300.0);
    expect(pillar.preset, LuminaCollisionPreset.blockAll);
    final cone = built['cone'] as LuminaConeComponent;
    expect(cone.preset, LuminaCollisionPreset.custom);
    expect(cone.objectType, CollisionObjectType.pawn);
    expect(cone.getResponse(CollisionObjectType.worldDynamic), CollisionResponse.ignore);
    expect(cone.getResponse(CollisionObjectType.pawn), CollisionResponse.overlap);
    // No resolvable hull: the convex component collides as its box and says so.
    expect(built['hull'], isA<LuminaBoxComponent>());
    expect(diagnostics.single.message, contains("Convex component 'Hull' has no resolvable hull"));
    expect(diagnostics.single.severity, LuminaBlueprintSeverity.warning);
    for (final c in [box, sphere, pillar, cone]) {
      expect(LuminaBlueprintComponents.isA(c, 'LuminaCollisionComponent'), isTrue);
      expect(actor.components, contains(c));
    }
    expect(LuminaBlueprintComponents.classNameOf(box), 'LuminaBoxComponent');
    expect(LuminaBlueprintComponents.classNameOf(sphere), 'LuminaSphereComponent');
    expect(LuminaBlueprintComponents.classNameOf(pillar), 'LuminaCylinderComponent');
    expect(LuminaBlueprintComponents.classNameOf(cone), 'LuminaConeComponent');
    expect(LuminaBlueprintObjectClass.displayName('Component:LuminaBoxComponent'), 'Box');

    // A resolvable hull through hullPoints, and through the resolver.
    final cube = [for (var i = 0; i < 8; i++) [i & 1 == 0 ? -50.0 : 50.0, i & 2 == 0 ? -50.0 : 50.0, i & 4 == 0 ? -50.0 : 50.0]];
    final withPoints = LuminaBlueprintComponents.construct(LuminaActor(), [
      LuminaBlueprintComponent(id: 'h', name: 'Hull', type: 'LuminaConvexComponent', properties: {'hullPoints': cube, 'preset': 'BlockAll'}),
    ]);
    final convex = withPoints['h'] as LuminaConvexComponent;
    expect(convex.convexHull!.vertices, hasLength(8));
    expect(convex.preset, LuminaCollisionPreset.blockAll);
    expect(LuminaBlueprintComponents.classNameOf(convex), 'LuminaConvexComponent');
    LuminaBlueprintComponents.hullResolver = (asset) => asset.endsWith('SM_Cube.lmas') ? [for (final p in cube) Vector3(p[0], p[1], p[2])] : null;
    addTearDown(() => LuminaBlueprintComponents.hullResolver = null);
    final resolved = LuminaBlueprintComponents.construct(LuminaActor(), [
      LuminaBlueprintComponent(id: 'h', name: 'Hull', type: 'LuminaConvexComponent', properties: {'hullAsset': 'contents/meshes/static/SM_Cube.lmas'}),
    ]);
    expect((resolved['h'] as LuminaConvexComponent).hullAsset, 'contents/meshes/static/SM_Cube.lmas');
  });

  test('Set Collision Response To Channel Pawn Overlap on a BlockAll box lets the pawn through', () {
    final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
      LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
      LuminaBlueprintComponent(
          id: 'wall', name: 'Wall', type: 'LuminaBoxComponent', parentId: 'root', properties: {'boxExtent': [200.0, 20.0, 100.0], 'preset': 'BlockAll'}),
    ]);
    final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'BP_Wall');
    LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    final wallPin = place(LuminaBlueprintNodeLibrary.getComponent, 'wall', {'component': 'Wall'});
    expect(wallPin.pin('return_value')!.objectClass, 'Component:LuminaBoxComponent');
    doc.eventGraph.nodes.addAll([
      place('event_beginplay', 'begin'),
      wallPin,
      place('set_collision_response_to_channel', 'let_pawns', {'channel': 'Pawn', 'response': 'Overlap'}),
      place('get_collision_response_to_channel', 'read', {'channel': 'Pawn'}),
      place('get_collision_preset', 'preset'),
      place('print_string', 'say'),
      place('print_string', 'say_preset'),
    ]);
    doc.eventGraph.wires.addAll([
      wire('begin', 'exec_out', 'let_pawns', 'exec_in'),
      wire('wall', 'return_value', 'let_pawns', 'target'),
      wire('let_pawns', 'exec_out', 'say', 'exec_in'),
      wire('wall', 'return_value', 'read', 'target'),
      wire('read', 'return_value', 'say', 'in_string'),
      wire('say', 'exec_out', 'say_preset', 'exec_in'),
      wire('wall', 'return_value', 'preset', 'target'),
      wire('preset', 'return_value', 'say_preset', 'in_string'),
    ]);
    final cls = LuminaBlueprintClass.fromDocument(doc, name: 'BP_Wall');
    expect(cls.diagnostics, isEmpty, reason: '${cls.diagnostics}');
    final w = world();
    final wallActor = cls.instantiate(location: Vector3(0, 0, -300));
    final trace = <LuminaBlueprintTraceEvent>[];
    (wallActor as LuminaBlueprintRuntime).trace = trace.add;
    w.persistentLevel.registerActor(wallActor);
    final character = LuminaCharacter(location: Vector3.zero());
    w.persistentLevel.registerActor(character);
    w.beginPlay();
    final wall = wallActor.blueprintComponents['wall'] as LuminaBoxComponent;
    expect(wall.getResponse(CollisionObjectType.pawn), CollisionResponse.overlap);
    expect(wall.getResponse(CollisionObjectType.worldDynamic), CollisionResponse.block);
    expect([for (final t in trace) if (t.printed != null) t.printed], ['Overlap', 'Custom']);
    final z = drift(w, character, 2.0);
    expect(z, lessThan(-400), reason: 'the pawn walked through (z $z)');
    w.cleanup();
  });

  test('Get Overlapping Actors of a trigger returns the pawn inside and nothing after it leaves; Set Box Extent grows a box', () {
    final w = world();
    final triggerActor = LuminaActor(location: Vector3(0, 0, -300));
    final trigger = LuminaSphereComponent(radius: 100)..applyPreset(LuminaCollisionPreset.trigger);
    triggerActor.addComponent(trigger);
    w.persistentLevel.registerActor(triggerActor);
    final character = LuminaCharacter(location: Vector3.zero());
    w.persistentLevel.registerActor(character);
    final bystander = LuminaActor(location: Vector3(0, 0, -300));
    final bystanderShape = LuminaBoxComponent(boxExtent: Vector3(10, 10, 10))..applyPreset(LuminaCollisionPreset.overlapAllDynamic);
    bystander.addComponent(bystanderShape);
    w.persistentLevel.registerActor(bystander);
    w.beginPlay();
    expect(LuminaBlueprintFunctionLibrary.getOverlappingActors(trigger), isEmpty);
    drift(w, character, 0.75); // 225 cm: inside the 100 cm sphere at −300
    expect(LuminaBlueprintFunctionLibrary.isOverlappingActor(trigger, character), isTrue);
    expect(LuminaBlueprintFunctionLibrary.getOverlappingActors(trigger), containsAll([character, bystander]));
    expect(LuminaBlueprintFunctionLibrary.getOverlappingActors(trigger, 'Actor:LuminaCharacter'), [character]);
    expect(LuminaBlueprintFunctionLibrary.getOverlappingActors(trigger, 'Actor:LuminaPawn'), [character]);
    expect(LuminaBlueprintFunctionLibrary.getOverlappingComponents(trigger), containsAll([character.capsuleComponent, bystanderShape]));
    drift(w, character, 1.0); // now at −525: out
    expect(LuminaBlueprintFunctionLibrary.isOverlappingActor(trigger, character), isFalse);
    expect(LuminaBlueprintFunctionLibrary.getOverlappingActors(trigger, 'Actor:LuminaCharacter'), isEmpty);

    // Set Box Extent: a trace that missed the small box hits the grown one.
    final subsystem = w.getSubsystem<LuminaCollisionSubsystem>()!;
    final hit = HitResult();
    expect(subsystem.lineTraceSingle(start: Vector3(0, 150, -1000), end: Vector3(0, 150, 1000), out: hit), isFalse,
        reason: 'the ray passes 150 cm up, above the 10 cm box, the 100 cm trigger sphere and the pawn');
    LuminaBlueprintFunctionLibrary.setBoxExtent(bystanderShape, Vector3(10, 10, 200));
    expect(bystanderShape.boxExtent, Vector3(10, 200, 10), reason: 'authoring Z is runtime Y');
    expect(LuminaBlueprintFunctionLibrary.getBoxExtent(bystanderShape), Vector3(10, 10, 200));
    expect(subsystem.lineTraceSingle(start: Vector3(0, 150, -1000), end: Vector3(0, 150, 1000), out: hit), isTrue);
    expect(hit.component, same(bystanderShape));

    // The other size nodes.
    final sphere = LuminaSphereComponent(radius: 10);
    LuminaBlueprintFunctionLibrary.setSphereRadius(sphere, 75);
    expect(LuminaBlueprintFunctionLibrary.getSphereRadius(sphere), 75.0);
    final capsule = character.capsuleComponent..relativeScale = Vector3(2, 3, 2);
    LuminaBlueprintFunctionLibrary.setCapsuleSize(capsule, 30, 70);
    expect(LuminaBlueprintFunctionLibrary.getScaledCapsuleRadius(capsule), 60.0);
    expect(LuminaBlueprintFunctionLibrary.getScaledCapsuleHalfHeight(capsule), 210.0);
    LuminaBlueprintFunctionLibrary.setCollisionPreset(sphere, 'Trigger');
    expect(LuminaBlueprintFunctionLibrary.getCollisionPreset(sphere), 'Trigger');
    LuminaBlueprintFunctionLibrary.setCollisionObjectType(sphere, 'WorldStatic');
    expect(LuminaBlueprintFunctionLibrary.getCollisionObjectType(sphere), 'WorldStatic');
    expect(LuminaBlueprintFunctionLibrary.getCollisionPreset(sphere), 'Custom');
    LuminaBlueprintFunctionLibrary.setCollisionResponseToAllChannels(sphere, 'Ignore');
    expect(LuminaBlueprintFunctionLibrary.getCollisionResponseToChannel(sphere, 'WorldDynamic'), 'Ignore');
    LuminaBlueprintFunctionLibrary.setGenerateOverlapEvents(sphere, false);
    expect(sphere.generateOverlapEvents, isFalse);
    LuminaBlueprintFunctionLibrary.setCollisionEnabled(sphere, 'NoCollision');
    expect(sphere.collisionEnabled, isFalse);
    expect(LuminaBlueprintFunctionLibrary.getCollisionPreset(sphere), 'NoCollision');
    LuminaBlueprintFunctionLibrary.setCollisionEnabled(sphere, 'QueryOnly');
    expect(sphere.collisionEnabled, isTrue);
    expect(sphere.generateOverlapEvents, isTrue);
    LuminaBlueprintFunctionLibrary.setCollisionEnabled(sphere, false);
    expect(sphere.collisionEnabled, isFalse, reason: 'older graphs stored a bool');
    w.cleanup();
  });
}
