import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'physics_fixture.dart';

/// A body's mass comes from its override, else the static mesh
/// asset's `metadata.physics.massKg`, else density × volume.
void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('lumina_physics_mass_');
    Directory('${project.path}/contents/meshes').createSync(recursive: true);
    // SM_Chair.lmas as the Static Mesh editor saves it: 23 kg, centre of
    // mass 10 cm up (authoring Z).
    final asset = LuminaAsset(
      assetId: 'sm_chair',
      name: 'SM_Chair',
      type: AssetType.filamesh,
      metadata: {
        'physics': jsonEncode({
          'massKg': 23.0,
          'centerOfMassOffset': [0.0, 0.0, 10.0],
        }),
      },
    );
    File('${project.path}/contents/meshes/SM_Chair.lmas').writeAsBytesSync(asset.toProtoBufferBytes());
    LuminaBlueprintComponents.meshPhysicsResolver = (stored) => MeshPhysicsService.forMeshAsset(stored, projectDir: project.path);
  });

  tearDown(() {
    LuminaBlueprintComponents.meshPhysicsResolver = null;
    project.deleteSync(recursive: true);
  });

  /// BP_Chair: a root, the chair mesh and a Box collision under it.
  LuminaBlueprintDocument chair({Map<String, dynamic>? boxPhysics}) => LuminaBlueprintDocument(
        parentClass: 'LuminaActor',
        components: [
          LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
          LuminaBlueprintComponent(
              id: 'mesh',
              name: 'Chair',
              type: 'LuminaStaticMeshComponent',
              parentId: 'root',
              properties: {'staticMeshAsset': 'contents/meshes/SM_Chair.lmas'}),
          LuminaBlueprintComponent(
              id: 'box',
              name: 'Box',
              type: 'LuminaBoxComponent',
              parentId: 'mesh',
              properties: {
                'boxExtent': [30.0, 30.0, 50.0],
                'location': [0.0, 0.0, 50.0],
                'physics': boxPhysics ?? {'simulate': true},
              }),
        ],
      );

  test('a Blueprint box over a static mesh whose .lmas says 23 kg reports get_mass 23; overrideMass 5 → 5', () {
    final w = PhysicsWorld();
    addTearDown(w.dispose);
    final actor = LuminaBlueprintClass.fromDocument(chair(), name: 'bp_chair').instantiate();
    final box = (actor as LuminaBlueprintRuntime).blueprintComponents['box'] as LuminaBoxComponent;
    expect(box.simulatePhysics, isTrue);
    expect(LuminaBlueprintFunctionLibrary.getMass(box), closeTo(23.0, 1e-9), reason: 'inherited before play too');
    w.world.persistentLevel.registerActor(actor as LuminaActor);
    w.begin();
    expect(box.physicsBody, isNotNull);
    expect(LuminaBlueprintFunctionLibrary.getMass(box), closeTo(23.0, 1e-9));
    // The mesh's centre of mass offset (authoring Z 10 → runtime y 10).
    expect(box.physicsBody!.localCenterOfMass.y, closeTo(10.0, 1e-9));

    LuminaBlueprintFunctionLibrary.setMassOverrideInKg(box, '', 5.0, true);
    expect(LuminaBlueprintFunctionLibrary.getMass(box), closeTo(5.0, 1e-9));
    LuminaBlueprintFunctionLibrary.setMassOverrideInKg(box, '', 5.0, false);
    expect(LuminaBlueprintFunctionLibrary.getMass(box), closeTo(23.0, 1e-9), reason: 'override off: inherited again');
  });

  test('the component JSON overrides the mass (overrideMass: true, massKg: 5)', () {
    final actor = LuminaBlueprintClass.fromDocument(chair(boxPhysics: {'simulate': true, 'overrideMass': true, 'massKg': 5.0}),
            name: 'bp_chair')
        .instantiate();
    final box = (actor as LuminaBlueprintRuntime).blueprintComponents['box'] as LuminaBoxComponent;
    expect(box.resolvedMassKg, closeTo(5.0, 1e-9));
  });

  test('without the mesh (a generated game) the baked meshPhysics is used; without either, density × volume', () {
    LuminaBlueprintComponents.meshPhysicsResolver = null;
    final baked = LuminaBlueprintClass.fromDocument(
            chair(boxPhysics: {
              'simulate': true,
              'meshPhysics': {'massKg': 23.0, 'centerOfMassOffset': [0.0, 0.0, 10.0]},
            }),
            name: 'bp_chair')
        .instantiate();
    final bakedBox = (baked as LuminaBlueprintRuntime).blueprintComponents['box'] as LuminaBoxComponent;
    expect(bakedBox.resolvedMassKg, closeTo(23.0, 1e-9));

    final bare = LuminaBlueprintClass.fromDocument(chair(), name: 'bp_chair').instantiate();
    final bareBox = (bare as LuminaBlueprintRuntime).blueprintComponents['box'] as LuminaBoxComponent;
    // 60 × 60 × 100 cm of density 1 g/cm³ = 360 kg.
    expect(bareBox.resolvedMassKg, closeTo(360.0, 1e-6));
    bareBox.physicalMaterial = const LuminaPhysicalMaterial(density: 0.5);
    expect(bareBox.resolvedMassKg, closeTo(180.0, 1e-6));
  });

  test('the physics JSON round-trips in authoring space', () {
    final box = LuminaBoxComponent()
      ..applyPhysicsJson({
        'simulate': true,
        'massKg': 12.5,
        'overrideMass': true,
        'centerOfMassOffset': [1.0, 2.0, 3.0],
        'linearDamping': 0.2,
        'angularDamping': 0.4,
        'enableGravity': false,
        'friction': 0.3,
        'restitution': 0.6,
        'locks': {
          'position': [false, false, true],
          'rotation': [true, true, false],
        },
      });
    expect(box.centerOfMassOffset, Vector3(1, 3, -2), reason: 'authoring (x, y, z) → runtime (x, z, −y)');
    expect(box.lockPositionZ, isTrue);
    expect(box.lockRotationX && box.lockRotationY && !box.lockRotationZ, isTrue);
    expect(box.physicalMaterial!.friction, 0.3);
    final json = box.toPhysicsJson();
    expect(json['simulate'], isTrue);
    expect(json['massKg'], 12.5);
    expect(json['overrideMass'], isTrue);
    expect((json['centerOfMassOffset'] as List).map((e) => (e as double).roundToDouble()), [1.0, 2.0, 3.0]);
    expect(json['linearDamping'], 0.2);
    expect(json['angularDamping'], 0.4);
    expect(json['enableGravity'], isFalse);
    expect(json['friction'], 0.3);
    expect(json['restitution'], 0.6);
    expect(json['locks'], {
      'position': [false, false, true],
      'rotation': [true, true, false],
    });
  });

  test('analytic volumes and inertia: box, sphere, cylinder, cone and a convex hull agree with their formulas', () {
    final box = LuminaShapeMass.box(Vector3(10, 20, 30));
    expect(box.volume, closeTo(20 * 40 * 60, 1e-6));
    final hull = LuminaShapeMass.convex(ConvexHullShape([
      for (var i = 0; i < 8; i++) Vector3(i & 1 == 0 ? -10 : 10, i & 2 == 0 ? -20 : 20, i & 4 == 0 ? -30 : 30),
    ]));
    expect(hull.volume, closeTo(box.volume, 1e-6));
    for (var i = 0; i < 9; i++) {
      expect(hull.unitInertia.storage[i], closeTo(box.unitInertia.storage[i], 1e-6), reason: 'inertia entry $i');
    }
    expect(hull.centroid.length, lessThan(1e-9));
    final cone = LuminaShapeMass.cone(10, 40);
    expect(cone.centroid.y, closeTo(-10, 1e-9), reason: 'a quarter of the height above the base');
  });
}
