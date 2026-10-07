// A placed landscape must hold the character up in
// Play-In-Editor, along the real PIE sequence: actors are mounted first, the
// collision subsystem is installed after them, then beginPlay and the player
// session. The landscape's collider has to reach that subsystem.
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/services/pie_controller.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

void main() {
  late Directory tempDir;
  setUp(() => tempDir = Directory.systemTemp.createTempSync('lumina_pie_landscape_'));
  tearDown(() => tempDir.deleteSync(recursive: true));

  /// A real LANDSCAPE .lmas: a 64 m terrain rising 3 m towards +X.
  String writeLandscape() {
    final data = LandscapeData.flat(gridResolution: 129, worldSize: 64.0, maxHeight: 20.0);
    for (var r = 0; r < 129; r++) {
      for (var c = 0; c < 129; c++) {
        data.setHeight(c, r, math.max(0.0, data.worldXOf(c)) * (3.0 / 32.0));
      }
    }
    final dir = Directory('${tempDir.path}/contents/landscapes')..createSync(recursive: true);
    final path = '${dir.path}/NewLandscape_34.lmas';
    File(path).writeAsBytesSync(LuminaAsset(
      assetId: 'landscape_NewLandscape_34',
      name: 'NewLandscape_34',
      type: AssetType.landscape,
      rawPayload: data.toBytes(),
    ).toProtoBufferBytes());
    return path;
  }

  test('the Third Person character stands on a placed landscape in PIE instead of falling through it', () {
    final path = writeLandscape();
    final template = GameTemplateCatalog.byId(kThirdPersonTemplateId);
    // The template's gameplay actors (no floor primitive: the landscape is the
    // only ground) plus the placed landscape, as the editor stores it.
    final actors = template.levelActors
        .map(EditorActorNode.fromMap)
        .where((a) => a.type != 'Primitive')
        .toList()
      ..add(EditorActorNode(
        id: 'act_land',
        name: 'NewLandscape_34',
        type: 'Landscape',
        location: [0.0, 0.0, 0.0],
        meshAssetPath: path,
      ));
    final project = LuminaProject(projectName: 'PieLandscape', template: kThirdPersonTemplateId);
    final game = EditorPieGame(
      actors,
      templateKind: template.kind,
      input: ProjectInputBinder.bind(project.input.actions.isEmpty ? template.input : project.input),
    );
    final world = LuminaWorld();
    // The real PIE order: mount, install the subsystems, beginPlay, login.
    game.mountIntoWorldForTest(world);

    final landscape = world.persistentLevel.actors
        .map((a) => a.rootComponent)
        .whereType<LuminaLandscapeComponent>()
        .single;
    expect(landscape.collisionComponent, isNotNull, reason: 'the landscape built its collider');
    final collision = world.getSubsystem<LuminaCollisionSubsystem>()!;
    final hit = HitResult();
    expect(
      collision.raycast(Vector3(0.0, 1000.0, 0.0), Vector3(0.0, -1.0, 0.0), 5000.0, hit),
      isTrue,
      reason: 'the landscape collider must be registered with the PIE collision subsystem',
    );

    final pawn = game.playerPawn!;
    final halfHeight = pawn.capsuleComponent.halfHeight;
    var lowest = double.infinity;
    for (var tick = 0; tick < 180; tick++) {
      world.tick(1 / 60);
      final at = pawn.actorLocation;
      final gap = (at.y - halfHeight) - landscape.sampleHeightAtWorld(at.x, at.z);
      lowest = math.min(lowest, gap);
      expect(gap, greaterThan(-5.0), reason: 'tick $tick: the capsule is ${-gap} cm under the terrain');
    }
    expect(pawn.characterMovement.isWalking, isTrue, reason: 'landed and walking after 3 s');
    expect(lowest, greaterThan(-5.0));
  });
}
