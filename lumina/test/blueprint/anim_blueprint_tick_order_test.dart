import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

import 'anim_blueprints.dart';

/// A mesh that notes, in a shared log, when it applies its pose.
class _LoggingMesh extends LuminaAnimatedMeshComponent {
  _LoggingMesh(this.log) : super(meshAssetPath: 'never_loaded.glb');

  final List<String> log;

  @override
  void onTick(double deltaTime) {
    log.add('mesh');
    super.onTick(deltaTime);
  }
}

/// A component that must tick before [target].
class _Before extends LuminaActorComponent {
  _Before(this.target, this.log, this.name);

  final LuminaActorComponent target;
  final List<String> log;
  final String name;

  @override
  LuminaActorComponent? get ticksBefore => target;

  @override
  void onTick(double deltaTime) => log.add(name);
}

class _Plain extends LuminaActorComponent {
  _Plain(this.log, this.name);

  final List<String> log;
  final String name;

  @override
  void onTick(double deltaTime) => log.add(name);
}

void main() {
  test('a component that must tick first makes an earlier one wait for it, the rest keep their order', () {
    final log = <String>[];
    final mesh = _LoggingMesh(log);
    final actor = LuminaActor(root: mesh)
      ..addComponent(_Plain(log, 'movement'))
      ..addComponent(_Before(mesh, log, 'anim'))
      ..addComponent(_Plain(log, 'after'));
    actor.onTick(1 / 60);
    expect(log, ['movement', 'anim', 'mesh', 'after']);
  });

  test("a skeletal mesh at the actor's root draws the pose its Animation Blueprint chose in the same frame", () {
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    addTearDown(world.cleanup);
    final log = <String>[];
    final mesh = _LoggingMesh(log);
    // As a placed level mesh is built: the mesh is the root, the Animation
    // Blueprint is added after it.
    final actor = LuminaActor(root: mesh);
    final anim = templateAnimClass().factory(mesh);
    anim.trace = (_) {
      if (log.isEmpty || log.last != 'anim') log.add('anim');
    };
    actor.addComponent(anim);
    world.persistentLevel.registerActor(actor);
    world.beginPlay();
    log.clear();
    for (var frame = 0; frame < 5; frame++) {
      world.tick(1 / 60);
    }
    expect(log, isNotEmpty);
    expect(log.first, 'anim', reason: 'the update graph runs before the mesh applies its pose');
    for (var i = 0; i + 1 < log.length; i += 2) {
      expect([log[i], log[i + 1]], ['anim', 'mesh'], reason: 'every frame: chosen, then drawn');
    }
  });
}
