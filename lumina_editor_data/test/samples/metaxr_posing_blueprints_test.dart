import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:vector_math/vector_math_64.dart';

/// The test-assets mannequin: a humanoid skin the pose rig is detected on.
final String _mannequin = '${Directory.current.parent.parent.path}/test-assets/mannequin/SKM_Manny_Simple.glb';

/// A grabber played from a script (a controller's grip pose and squeeze).
class _ScriptedGrip implements LuminaGrabber {
  _ScriptedGrip(this.id);

  @override
  final String id;
  final Vector3 position = Vector3.zero();
  double squeeze = 0;
  final List<double> pulses = [];

  @override
  Matrix4 get worldTransform => Matrix4.translation(position);

  @override
  double get grip => squeeze;

  @override
  bool get isTracked => true;

  @override
  LuminaGrabRay? get ray => null;

  @override
  void pulse(double amplitude, double seconds) => pulses.add(amplitude);

  @override
  void grabbedAt(Vector3 point) {}
}

void main() {
  setUpAll(MetaXrPosingContent.declarePluginNodes);

  test('BP_PosedCharacter, BP_XRPlayer, BP_RoomPassthrough and W_WristHud compile in the VM without errors', () {
    final actions = MetaXrPosingContent.inputActions;
    for (final (name, doc) in [
      (MetaXrPosingContent.characterName, MetaXrPosingContent.characterBlueprint(meshAssetPath: 'never_loaded.glb')),
      (MetaXrPosingContent.playerName, MetaXrPosingContent.playerBlueprint()),
      (MetaXrPosingContent.passthroughName, MetaXrPosingContent.passthroughBlueprint()),
    ]) {
      final cls = LuminaBlueprintClass.fromDocument(doc, name: name, inputActions: actions);
      expect(cls.diagnostics.where((d) => d.isError), isEmpty, reason: '$name: ${cls.diagnostics}');
    }
    LuminaWidgetClassRegistry.register(MetaXrPosingWidgets.widgetClass);
    addTearDown(LuminaWidgetClassRegistry.clear);
    final hud = MetaXrPosingWidgets.blueprint();
    final hudClass = LuminaBlueprintClass.fromDocument(hud.blueprint,
        name: MetaXrPosingWidgets.hudName, widgetVariables: hud.variables);
    expect(hudClass.diagnostics.where((d) => d.isError), isEmpty, reason: '${hudClass.diagnostics}');
  });

  test('a scripted right-hand grip near hand_r moves the hand through the character\'s IK (VM, 60 ticks)', () async {
    if (!File(_mannequin).existsSync()) return markTestSkipped('test-assets mannequin missing');
    final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    final scene = engine.createScene();
    final world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
    addTearDown(() {
      world.cleanup();
      scene.dispose();
      engine.dispose();
    });
    final actions = MetaXrPosingContent.inputActions;
    final character = LuminaBlueprintClass.fromDocument(
      MetaXrPosingContent.characterBlueprint(meshAssetPath: _mannequin.replaceAll(r'\', '/')),
      name: MetaXrPosingContent.characterName,
      inputActions: actions,
    ).instantiate(location: LuminaAxes.location(const [0.0, MetaXrPosingLevel.characterDistance, 0.0]));
    final player = LuminaBlueprintClass.fromDocument(MetaXrPosingContent.playerBlueprint(),
            name: MetaXrPosingContent.playerName, inputActions: actions)
        .instantiate();
    world.persistentLevel
      ..registerActor(character)
      ..registerActor(player);
    world.beginPlay();
    final mesh = character.getComponent<LuminaAnimatedMeshComponent>()!;
    await mesh.loaded;
    final poser = character.getComponent<LuminaPoseAuthoringComponent>()!;
    // The rig is detected once the skeleton has played a frame.
    for (var i = 0; i < 30 && poser.rig == null; i++) {
      world.tick(1 / 72);
      await Future<void>.delayed(Duration.zero);
    }
    expect(poser.rig, isNotNull, reason: 'the mannequin\'s rig is detected');
    expect(poser.rig!.handleNames, containsAll(['hand_r', 'elbow_r', 'foot_l', 'knee_l', 'head', 'chest', 'pelvis']));

    final interactor = player.getComponent<LuminaPoseGrabInteractor>()!;
    final right = _ScriptedGrip('right');
    interactor.registerGrabber(right);
    final start = poser.handleWorldLocation('hand_r')!.clone();
    right.position.setFrom(start);
    world.tick(1 / 72);
    expect(interactor.hoveredBy(right)?.handle, 'hand_r');
    right.squeeze = 1;
    world.tick(1 / 72);
    expect(interactor.heldBy(right)?.handle, 'hand_r');
    expect(right.pulses, isNotEmpty, reason: 'a haptic tick on the grab');
    // Raise the hand 25 cm and pull it 10 cm towards the user over 60 frames.
    final target = start + Vector3(0, 25, 10);
    for (var i = 1; i <= 60; i++) {
      right.position.setFrom(start + (target - start) * (i / 60));
      world.tick(1 / 72);
    }
    final moved = poser.handleWorldLocation('hand_r')!;
    expect(moved.distanceTo(target), lessThan(4.0), reason: 'the hand follows the grip (IK)');
    // Released, the pose stays.
    right.squeeze = 0;
    for (var i = 0; i < 10; i++) {
      world.tick(1 / 72);
    }
    expect(poser.handleWorldLocation('hand_r')!.distanceTo(target), lessThan(4.0), reason: 'the pose holds on release');
    // Undo puts the hand back.
    expect(interactor.undoLastGrab(), isTrue);
    for (var i = 0; i < 5; i++) {
      world.tick(1 / 72);
    }
    expect(poser.handleWorldLocation('hand_r')!.distanceTo(start), lessThan(4.0));
  });
}
