import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:lumina_editor_data/lumina_editor.dart';

/// The Blueprint assets of a project whose generated game
/// registers every registry — an enum, an interface, a save-game class, a
/// montage, a particle system and an actor Blueprint (`BP_Door`) — written
/// as the editor writes them.

const LuminaBlueprintEnumDocument registryDoorState =
    LuminaBlueprintEnumDocument(name: 'E_DoorState', values: ['Closed', 'Opening', 'Open']);

const LuminaBlueprintInterfaceDocument registryInteractable = LuminaBlueprintInterfaceDocument(name: 'BPI_Interactable', functions: [
  LuminaBlueprintFunctionSignature(name: 'Interact', inputs: [LuminaBlueprintVariable(name: 'Instigator', typeName: 'Actor')]),
]);

const LuminaBlueprintSaveGameDocument registryPlayerSave = LuminaBlueprintSaveGameDocument(name: 'SG_Player', fields: [
  LuminaBlueprintVariable(name: 'Score', typeName: 'Int', defaultValue: 0),
  LuminaBlueprintVariable(name: 'Door', typeName: 'Enum:E_DoorState', defaultValue: 'Closed'),
]);

/// A montage of a real Third Person bundle clip, with a notify.
const LuminaBlueprintMontageDocument registryWave = LuminaBlueprintMontageDocument(
  name: 'AM_Wave',
  clip: 'Walk_Fwd_Loop',
  length: 1.5,
  sections: [LuminaBlueprintMontageSection(name: 'Default', startTime: 0.0)],
  notifies: [LuminaBlueprintMontageNotify(name: 'Step', time: 0.75)],
);

/// The particle editor's stored emitter config for `P_Sparks`.
Map<String, dynamic> registrySparksConfig() => LuminaParticleEmitterConfig(spawnRate: 40.0, lifetimeMin: 0.5, lifetimeMax: 1.0, looping: true).toJson();

const String registryDoorPath = 'contents/blueprints/BP_Door.lmas';
const String registryWavePath = 'contents/montages/AM_Wave.lmas';
const String registrySparksPath = 'contents/particles/P_Sparks.lmas';

/// BP_Door: a capsule the level can hit and a barrel mesh (a project-relative
/// path, [registryBarrelPath]); BeginPlay prints "BP_Door ready".
const String registryBarrelPath = 'contents/meshes/fuel_barrel_red.glb';

LuminaBlueprintDocument registryDoorBlueprint() {
  final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
    LuminaBlueprintComponent(id: 'cap', name: 'Capsule', type: 'LuminaCapsuleComponent', properties: {
      'capsuleRadius': 45.0,
      'capsuleHalfHeight': 90.0,
      'location': [0.0, 0.0, 90.0],
    }),
    LuminaBlueprintComponent(id: 'mesh', name: 'Barrel', type: 'LuminaStaticMeshComponent', parentId: 'cap', properties: {
      'location': [0.0, 0.0, -90.0],
      'staticMeshAsset': registryBarrelPath,
    }),
  ]);
  final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'BP_Door');
  doc.eventGraph.nodes.addAll([
    LuminaBlueprintNodeLibrary.place('event_beginplay', nodeId: 'begin', context: context),
    LuminaBlueprintNodeLibrary.place('print_string', nodeId: 'say', literals: {'in_string': 'BP_Door ready'}, context: context),
  ]);
  doc.eventGraph.wires.add(const LuminaBlueprintWire(id: 'w0', fromNodeId: 'begin', fromPinId: 'exec_out', toNodeId: 'say', toPinId: 'exec_in'));
  return doc;
}

void _writeActorAsset(String projectDir, String path, Map<String, dynamic> payload) {
  final name = path.split('/').last.replaceAll('.lmas', '');
  File('$projectDir/$path')
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(LuminaAsset(
      assetId: 'test_$name',
      name: name,
      type: AssetType.actor,
      rawPayload: Uint8List.fromList(utf8.encode(jsonEncode(payload))),
    ).toProtoBufferBytes());
}

/// Writes every asset above into [projectDir]'s `contents/` and compiles
/// BP_Door into `lib/actors/` (which also writes the project registry).
Future<void> writeRegistryProjectAssets(String projectDir, {String? barrelGlb}) async {
  _writeActorAsset(projectDir, 'contents/enums/E_DoorState.lmas', registryDoorState.toJson());
  _writeActorAsset(projectDir, 'contents/interfaces/BPI_Interactable.lmas', registryInteractable.toJson());
  _writeActorAsset(projectDir, 'contents/savegames/SG_Player.lmas', registryPlayerSave.toJson());
  _writeActorAsset(projectDir, registryWavePath, registryWave.toJson());
  File('$projectDir/$registrySparksPath')
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(LuminaAsset(
      assetId: 'test_P_Sparks',
      name: 'P_Sparks',
      type: AssetType.particle,
      metadata: {
        LuminaProjectBlueprintAssets.particleSystemMetadataKey: jsonEncode({
          'v': 1,
          'emitters': [
            {'name': 'Disabled', 'enabled': false, 'config': LuminaParticleEmitterConfig(spawnRate: 1.0).toJson()},
            {'name': 'Sparks', 'enabled': true, 'config': registrySparksConfig()},
          ],
        }),
      },
    ).toProtoBufferBytes());
  if (barrelGlb != null) {
    File('$projectDir/$registryBarrelPath')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(File(barrelGlb).readAsBytesSync());
  }
  final door = registryDoorBlueprint().toJson();
  _writeActorAsset(projectDir, registryDoorPath, door);
  final compiled = await DartCodeGeneratorService().compileAndWriteActor(projectDir, 'BP_Door', door, assetPath: registryDoorPath);
  if (!compiled) throw StateError('BP_Door did not compile');
}
