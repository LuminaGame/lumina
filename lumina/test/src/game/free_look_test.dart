import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../blueprint/anim_blueprints.dart';
import '../../blueprint/anim_rig.dart';

/// Alt + mouse (IA_FreeLook) orbits the camera while the body
/// keeps its heading and the aim offset turns the head; release recentres.
void main() {
  /// Clip lengths read from the shipped bundle, when it is built.
  Map<String, double> bundleDurations() {
    final file = File(LuminaThirdPersonContent.bundledMeshPath);
    if (!file.existsSync()) return const {};
    final doc = GlbDocument.parse(file.readAsBytesSync());
    final accessors = (doc.json['accessors'] as List).cast<Map<String, dynamic>>();
    return {
      for (final a in (doc.json['animations'] as List).cast<Map<String, dynamic>>())
        a['name'] as String: (a['samplers'] as List)
            .map((s) => ((accessors[(s as Map)['input'] as int]['max'] as List).first as num).toDouble())
            .reduce(math.max),
    };
  }

  late final durations = bundleDurations();

  /// BP_ThirdPersonCharacter run by the VM on the template's real input
  /// manifest, animated by ABP_Character (a recording mesh), on the rig floor.
  ({AnimRig rig, LuminaInputSubsystem input, LuminaPlayerController pc, LuminaSpringArmComponent boom}) character() {
    final world = AnimRig.floorWorld();
    final bound = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input);
    final input = world.registerSubsystem(LuminaInputSubsystem());
    for (final c in bound.contexts) {
      input.addMappingContext(c.context, priority: c.priority);
    }
    final actions = bound.actions.values.toList();
    final anim = templateAnimClass();
    final mesh = RecordingMesh();
    final cls = LuminaBlueprintClass.fromDocument(
      LuminaThirdPersonContent.characterBlueprint(inputActions: actions, meshAsset: 'never_loaded.glb'),
      name: LuminaThirdPersonContent.characterBlueprintName,
      inputActions: actions,
      animBlueprints: (path) => path == LuminaThirdPersonContent.projectAnimBlueprintPath
          ? (m) => (anim.instantiate(mesh)
            ..clipDurationFallbacks.addAll(durations)
            ..random = math.Random(5))
          : null,
    );
    expect(cls.diagnostics, isEmpty, reason: '${cls.diagnostics}');
    final character = cls.instantiate(location: Vector3(0.0, 100.0, 0.0)) as LuminaCharacter;
    final pc = LuminaPlayerController();
    world.persistentLevel.registerActor(character);
    pc.possess(character);
    world.beginPlay();
    final runtime = character as LuminaBlueprintRuntime;
    final instance = runtime.blueprintComponents['mesh.anim'] as LuminaAnimBlueprintInstance;
    final boom = runtime.blueprintComponents['boom'] as LuminaSpringArmComponent;
    for (var i = 0; i < 30; i++) {
      pc.onTick(1 / 60);
      world.tick(1 / 60);
    }
    expect(character.characterMovement.isFalling, isFalse);
    return (rig: AnimRig.attached(world, character, mesh, instance), input: input, pc: pc, boom: boom);
  }

  /// Ticks [frames] with [keys] held and [mouseX] per frame.
  void play(({AnimRig rig, LuminaInputSubsystem input, LuminaPlayerController pc, LuminaSpringArmComponent boom}) c, int frames,
      {List<LuminaKey> keys = const [], double mouseX = 0.0}) {
    for (final k in keys) {
      c.input.injectKeyDown(k);
    }
    for (var i = 0; i < frames; i++) {
      if (mouseX != 0.0) c.input.injectAnalog(LuminaKey.mouseX, mouseX);
      c.pc.onTick(1 / 60);
      c.rig.world.tick(1 / 60);
    }
    for (final k in keys) {
      c.input.injectKeyUp(k);
    }
  }

  double yawOf(LuminaActor a) => luminaPawnQuaternionToEuler(a.actorRotation).y;

  /// The boom camera's bearing around the character (degrees, right positive).
  double boomBearing(LuminaSpringArmComponent boom, LuminaActor a) {
    final d = boom.socketWorldLocation - a.actorLocation;
    return math.atan2(d.x, -d.z) * 180 / math.pi;
  }

  double wrap(double d) {
    var r = d % 360.0;
    if (r > 180) r -= 360;
    if (r < -180) r += 360;
    return r;
  }

  test('the manifest binds IA_FreeLook to Left Alt and the right thumbstick; the character Blueprint sets free look on it', () {
    final bound = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input);
    final freeLook = bound.actionByName('IA_FreeLook')!;
    expect(freeLook.valueType, InputValueType.digitalBool);
    final gameplay = bound.contexts.single.context;
    expect(gameplay.mappingsForKey(LuminaKey.keyLeftAlt).single.action, freeLook);
    expect(gameplay.mappingsForKey(LuminaKey.gamepadRightThumbstick).single.action, freeLook);
    expect(bound.unboundKeys, isEmpty);
    expect(kKeyIdAltLeft, 0x200000104, reason: "Flutter's LogicalKeyboardKey.altLeft");
    final doc = LuminaThirdPersonContent.characterBlueprint(inputActions: bound.actions.values.toList());
    expect(doc.eventGraph.nodes.map((n) => n.literals['action']), contains('IA_FreeLook'));
    expect(doc.eventGraph.nodes.where((n) => n.registryId == 'set_free_look').map((n) => n.literals['enabled']), [true, false]);
    expect(doc.eventGraph.nodes.map((n) => n.registryId), containsAll(['is_free_looking', 'select_float']));
    for (final id in ['set_free_look', 'is_free_looking']) {
      expect(LuminaBlueprintNodeLibrary.spec(id)!.category, 'Character');
      expect(LuminaBlueprintFunctionLibrary.callShapes[id], isNotNull);
      expect(LuminaBlueprintFunctionLibrary.builtInFunctions[id], isNotNull);
    }
  });

  test('Alt held: a 90° mouse turn leaves the body, orbits the boom 90°, AimYaw reads 80 (clamped) and the head turns; walking follows the body; release recentres in 0.25 s', () {
    final c = character();
    final pawn = c.rig.character;
    final anim = c.rig.anim!;
    final bodyYaw = yawOf(pawn);
    final bearingBefore = boomBearing(c.boom, pawn);
    expect(bodyYaw, closeTo(0.0, 1e-6));

    // Alt down, then 90° of mouse over 30 frames.
    c.input.injectKeyDown(LuminaKey.keyLeftAlt);
    c.pc.onTick(1 / 60);
    c.rig.world.tick(1 / 60);
    expect(pawn.freeLook, isTrue, reason: 'IA_FreeLook Started → Set Free Look true');
    const frames = 30;
    const perFrame = 90.0 / (frames * LuminaTemplateCharacterTuning.lookSensitivity);
    play(c, frames, mouseX: perFrame);
    expect(c.pc.controlRotation.y, closeTo(90.0, 1e-6));
    expect(yawOf(pawn), closeTo(bodyYaw, 1e-6), reason: 'the body kept its heading');
    play(c, 30); // let the boom's rotation lag settle
    expect(wrap(boomBearing(c.boom, pawn) - bearingBefore), closeTo(90.0, 3.0), reason: 'the camera orbited');
    expect(anim.variables['AimYaw'], closeTo(90.0, 1e-6), reason: 'controller − actor yaw');
    expect(anim.aimYaw, closeTo(80.0, 0.5), reason: 'clamped to maxYaw');
    expect(c.rig.mesh.jointOverrides['Head']!.rotationDegrees, closeTo(48.0, 0.5));
    expect(anim.rootYawOffsetDegrees, 0.0, reason: 'no turn in place from free-look yaw');
    expect(anim.currentState, 'Idle');

    // Walking forward during free look moves along the body heading (−Z), not the camera's (+X).
    final start = pawn.actorLocation.clone();
    play(c, 60, keys: const [LuminaKey.keyW, LuminaKey.keyLeftAlt]);
    c.input.injectKeyDown(LuminaKey.keyLeftAlt);
    final moved = pawn.actorLocation - start;
    expect(moved.z, lessThan(-150.0), reason: 'walked along the body heading');
    expect(moved.x.abs(), lessThan(10.0), reason: 'not along the camera');
    expect(yawOf(pawn), closeTo(bodyYaw, 1e-6));
    expect(pawn.freeLook, isTrue);

    // Release: the controller yaw recentres on the body within 0.25 s, AimYaw follows to 0.
    c.input.injectKeyUp(LuminaKey.keyLeftAlt);
    play(c, 1);
    expect(pawn.freeLook, isFalse, reason: 'Completed → Set Free Look false');
    expect(pawn.isRecenteringFromFreeLook, isTrue);
    play(c, 15); // 0.25 s
    expect(c.pc.controlRotation.y, closeTo(bodyYaw, 1e-6));
    expect(pawn.isRecenteringFromFreeLook, isFalse);
    expect(yawOf(pawn), closeTo(bodyYaw, 1e-6), reason: 'the body never turned');
    expect(anim.variables['AimYaw'], closeTo(0.0, 1e-6));
    play(c, 45);
    expect(anim.aimYaw.abs(), lessThan(0.5));
    expect(c.rig.mesh.jointOverrides['Head']!.rotationDegrees, lessThan(0.5));
    c.input.injectKeyUp(LuminaKey.keyW);
  });

  test('without Alt, mouse look still turns the body (regression)', () {
    final c = character();
    final pawn = c.rig.character;
    const perFrame = 60.0 / (30 * LuminaTemplateCharacterTuning.lookSensitivity);
    play(c, 30, mouseX: perFrame);
    expect(c.pc.controlRotation.y, closeTo(60.0, 1e-6));
    play(c, 1); // the pawn faces the control rotation on the controller's next tick
    expect(yawOf(pawn), closeTo(60.0, 1e-6), reason: 'the pawn follows the controller yaw');
    expect(c.rig.anim!.variables['AimYaw'], closeTo(0.0, 1e-6));
    expect(pawn.freeLook, isFalse);
  });

  test('the Dart LuminaTemplateCharacter mirrors it: third person free-looks, first person ignores it', () {
    final third = LuminaTemplateCharacter(thirdPerson: true, meshAssetPath: 'never_loaded.glb');
    third.onFreeLook(LuminaInputActionValue.raw(InputValueType.digitalBool, 1.0, 0.0, 0.0));
    expect(third.freeLook, isTrue);
    third.onFreeLook(LuminaInputActionValue.raw(InputValueType.digitalBool, 0.0, 0.0, 0.0));
    expect(third.freeLook, isFalse);
    expect(third.isRecenteringFromFreeLook, isTrue);
    final first = LuminaTemplateCharacter(thirdPerson: false, meshAssetPath: 'never_loaded.glb');
    first.onFreeLook(LuminaInputActionValue.raw(InputValueType.digitalBool, 1.0, 0.0, 0.0));
    expect(first.freeLook, isFalse);

    // Through the manifest: bindTemplateCharacterInput binds IA_FreeLook
    // Started on / Completed off, so holding Left Alt free-looks.
    for (final thirdPerson in [true, false]) {
      final world = AnimRig.floorWorld();
      final bound = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input);
      final character = LuminaTemplateCharacter(thirdPerson: thirdPerson, meshAssetPath: 'never_loaded.glb', location: Vector3(0, 100, 0));
      final pc = LuminaPlayerController();
      world.persistentLevel.registerActor(character);
      pc.possess(character);
      bindTemplateCharacterInput(character: character, world: world, input: bound);
      world.beginPlay();
      final input = world.getSubsystem<LuminaInputSubsystem>()!;
      input.injectKeyDown(LuminaKey.keyLeftAlt);
      pc.onTick(1 / 60);
      world.tick(1 / 60);
      pc.onTick(1 / 60);
      world.tick(1 / 60);
      expect(character.freeLook, thirdPerson, reason: 'held Alt (thirdPerson: $thirdPerson)');
      input.injectKeyUp(LuminaKey.keyLeftAlt);
      pc.onTick(1 / 60);
      world.tick(1 / 60);
      expect(character.freeLook, isFalse, reason: 'released Alt (thirdPerson: $thirdPerson)');
      world.cleanup();
    }
  });

  test('a plain pawn: faceRotation ignores the controller yaw while free looking and eases the yaw back afterwards', () {
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final pawn = LuminaPawn()..bUseControllerRotationYaw = true;
    world.persistentLevel.registerActor(pawn);
    final pc = LuminaPlayerController()..possess(pawn);
    world.beginPlay();
    pc.controlRotation.y = 40.0;
    pc.onTick(1 / 60);
    expect(yawOf(pawn), closeTo(40.0, 1e-6));
    pawn.freeLook = true;
    pc.controlRotation.y = 130.0;
    pc.onTick(1 / 60);
    expect(yawOf(pawn), closeTo(40.0, 1e-6));
    pawn.freeLook = false;
    pc.onTick(0.125);
    expect(pc.controlRotation.y, closeTo(85.0, 1e-6), reason: 'half way after half of 0.25 s');
    expect(yawOf(pawn), closeTo(40.0, 1e-6));
    pc.onTick(0.125);
    expect(pc.controlRotation.y, closeTo(40.0, 1e-6));
    pc.onTick(1 / 60);
    expect(yawOf(pawn), closeTo(40.0, 1e-6));
    // Back to normal: the body follows again.
    pc.controlRotation.y = 70.0;
    pc.onTick(1 / 60);
    expect(yawOf(pawn), closeTo(70.0, 1e-6));
    world.cleanup();
  });
}
