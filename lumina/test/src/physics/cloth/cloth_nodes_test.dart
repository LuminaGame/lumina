import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

import '../../../blueprint/cloth_blueprint.dart';
import '../physics_fixture.dart';

void main() {
  tearDown(() => LuminaPhysicsSubsystem.defaultBackend = LuminaPhysicsBackendKind.auto);

  test('the cloth nodes have specs, VM functions and call shapes; the component is a scene component', () {
    for (final id in ['set_cloth_wind', 'set_cloth_simulation_enabled', 'is_cloth_simulating', 'reset_cloth', 'pin_cloth_vertex']) {
      expect(LuminaBlueprintNodeLibrary.spec(id), isNotNull, reason: id);
      expect(LuminaBlueprintFunctionLibrary.builtInFunctions.containsKey(id), isTrue, reason: id);
      expect(LuminaBlueprintFunctionLibrary.callShapes.containsKey(id), isTrue, reason: id);
    }
    expect(LuminaBlueprintObjectClass.ancestors('Component:LuminaClothComponent'),
        ['Component:LuminaSceneComponent', 'Component:LuminaActorComponent']);
    expect(LuminaBlueprintComponents.classNameOf(LuminaClothComponent()), 'LuminaClothComponent');
  });

  test('a Blueprint flag simulates, takes wind and a pin, switches off and back on (VM, Jolt)', () async {
    LuminaPhysicsSubsystem.defaultBackend = LuminaPhysicsBackendKind.jolt;
    final w = PhysicsWorld();
    addTearDown(w.dispose);
    final actor = LuminaBlueprintClass.fromDocument(clothBlueprint(), name: 'bp_cloth').instantiate();
    final trace = <LuminaBlueprintTraceEvent>[];
    (actor as LuminaBlueprintRuntime).trace = trace.add;
    final cloth = actor.getComponent<LuminaClothComponent>()!;
    expect(cloth.gridColumns, 12);
    expect(cloth.pinning, LuminaClothPinning.topEdge);
    expect(cloth.worldLocation.y, closeTo(300, 1e-9), reason: 'authoring Z up is runtime Y');
    w.world.persistentLevel.registerActor(actor);
    w.begin();
    await cloth.ready;
    final printed = [for (final t in trace) if (t.printed != null) t.printed!];
    expect(printed, ['true', 'false', 'true']);
    expect(cloth.wind.x, closeTo(600, 1e-9));
    expect(cloth.windDrag, 2.0);
    expect(cloth.pinnedVertices, [100]);
    expect(cloth.resolvePinnedVertices(), contains(100));
    w.run(1);
    expect(cloth.isSimulating, isTrue);
  });
}
