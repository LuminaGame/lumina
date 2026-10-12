import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

import '../physics_fixture.dart';
import '../ragdoll/ragdoll_fixture.dart';

/// A garment as a Blueprint component: its properties round-trip, the
/// component mapping builds it on the skeletal mesh it is attached to, and
/// it simulates there on Jolt.
void main() {
  tearDown(() => LuminaPhysicsSubsystem.defaultBackend = LuminaPhysicsBackendKind.auto);

  test('the garment properties round-trip and default like the constructor', () {
    final skirt = LuminaSkinnedClothComponent.fromProperties({
      'waistBone': 'pelvis',
      'skirtLength': 52.0,
      'hemRadius': 40.0,
      'maxDistance': 30.0,
      'legFollow': 0.25,
      'backstopDistance': 2.0,
      'backstopRadius': 15.0,
      'maxDistanceMap': [0.0, 1.0, 2.0],
      'paintedMaps': true,
      'inertiaScale': 0.4,
      'teleportDistance': 80.0,
      'massKg': 0.9,
      'color': '#336699',
      'wind': [100.0, 0.0, 0.0],
    });
    expect(skirt.skirtLength, 52);
    expect(skirt.backstopDistance, 2);
    expect(skirt.maxDistanceMap, [0, 1, 2]);
    expect(skirt.inertiaScale, 0.4);
    expect(skirt.wind.x, closeTo(100, 1e-9));
    final back = LuminaSkinnedClothComponent.fromProperties(skirt.toProperties());
    expect(back.toProperties(), skirt.toProperties());
    expect(back.legFollow, 0.25);
    expect(back.paintedMaps, isTrue);
    final defaults = LuminaSkinnedClothComponent.fromProperties(const {});
    final constructed = LuminaSkinnedClothComponent();
    expect(defaults.toProperties(), constructed.toProperties());
    expect(defaults.backstopDistance, isNull);
    expect(LuminaSkinnedClothComponent.fromProperties(const {'backstopDistance': -1}).backstopDistance, isNull);
  });

  test('the component mapping puts the garment on its skeletal mesh; it simulates on Jolt', () async {
    LuminaPhysicsSubsystem.defaultBackend = LuminaPhysicsBackendKind.jolt;
    expect(LuminaBlueprintObjectClass.ancestors('Component:LuminaSkinnedClothComponent'),
        ['Component:LuminaClothComponent', 'Component:LuminaSceneComponent', 'Component:LuminaActorComponent']);
    expect(LuminaBlueprintComponents.classNameOf(LuminaSkinnedClothComponent()), 'LuminaSkinnedClothComponent');
    final w = PhysicsWorld();
    addTearDown(w.dispose);
    final actor = LuminaActor(root: LuminaSceneComponent());
    final built = LuminaBlueprintComponents.construct(actor, [
      LuminaBlueprintComponent(
        id: 'mesh',
        name: 'Body',
        type: 'LuminaSkeletalMeshComponent',
        parentId: null,
        isSceneComponent: true,
        properties: {'skeletalMeshAsset': mannyFile.path},
      ),
      LuminaBlueprintComponent(
        id: 'skirt',
        name: 'Skirt',
        type: 'LuminaSkinnedClothComponent',
        parentId: 'mesh',
        isSceneComponent: true,
        properties: {'hemRadius': 36.0, 'color': '#8C1A5A'},
      ),
    ], resolveAsset: (stored) => stored);
    final mesh = built['mesh'] as LuminaAnimatedMeshComponent;
    final skirt = built['skirt'] as LuminaSkinnedClothComponent;
    expect(skirt.hemRadius, 36);
    expect(skirt.parentComponent, same(mesh));
    w.world.persistentLevel.registerActor(actor);
    w.begin();
    await skirt.ready;
    expect(skirt.mesh, same(mesh));
    expect(skirt.skeleton!.slotNamed('pelvis'), greaterThanOrEqualTo(0));
    expect(skirt.isSimulating, isTrue);
  }, skip: mannySkip);
}
