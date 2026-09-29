// GENERATED CODE - DO NOT MODIFY BY HAND
// Lumina Engine 0.0.1: every Blueprint asset the runtime resolves by name,
// registered by main() before the game starts.
// ignore_for_file: unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:lumina/lumina_runtime.dart';

import 'actors/actors.g.dart';
import 'enums/e_door_state.g.dart';
import 'interfaces/bpi_interactable.g.dart';

/// Registers the project's Blueprint classes, enums, interfaces, save-game
/// classes, montages and particle templates with the runtime.
void registerProjectBlueprints() {
  // Spawn Actor from Class: every compiled Blueprint actor class, by name.
  LuminaBlueprintActorClasses.registerAll({
    'BP_Door': () => luminaBlueprintFactories['contents/blueprints/BP_Door.lmas']!(),
  });
  LuminaBlueprintEnums.registerAll(const [
    EDoorState.document,
  ]);
  LuminaBlueprintInterfaces.registerAll(const [
    BpiInteractable.document,
  ]);
  LuminaBlueprintSaveGameClasses.registerAll([
    // contents/savegames/SG_Player.lmas
    LuminaBlueprintSaveGameDocument.fromJson(<String, dynamic>{'kind': 'savegame', 'name': 'SG_Player', 'fields': <dynamic>[<String, dynamic>{'name': 'Score', 'type': 'Int', 'default': 0}, <String, dynamic>{'name': 'Door', 'type': 'Enum:E_DoorState', 'default': 'Closed'}]}),
  ]);
  LuminaBlueprintMontages.register(LuminaBlueprintMontageDocument.fromJson(<String, dynamic>{'kind': 'montage', 'name': 'AM_Wave', 'clip': 'Walk_Fwd_Loop', 'length': 1.5, 'sections': <dynamic>[<String, dynamic>{'name': 'Default', 'startTime': 0.0}], 'notifies': <dynamic>[<String, dynamic>{'name': 'Step', 'time': 0.75}], 'blendInTime': 0.25, 'blendOutTime': 0.25}),
      path: 'contents/montages/AM_Wave.lmas');
  LuminaBlueprintParticleTemplates.register('contents/particles/P_Sparks.lmas',
      LuminaParticleEmitterConfig.fromJson(<String, dynamic>{'spawnRate': 40.0, 'bursts': <dynamic>[], 'maxParticles': 256, 'lifetimeMin': 0.5, 'lifetimeMax': 1.0, 'speedMin': 100.0, 'speedMax': 100.0, 'coneAngleDegrees': 45.0, 'inheritVelocityScale': <dynamic>[0.0, 0.0, 0.0], 'gravity': <dynamic>[0.0, -980.0, 0.0], 'drag': 0.0, 'colorOverLife': <dynamic>[], 'sizeOverLife': <dynamic>[], 'looping': true, 'duration': 1.0, 'meshAssetPath': null, 'billboard': true}));
}
