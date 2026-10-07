import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

class _KeyedHero extends LuminaActor {
  _KeyedHero({super.key}) : super(bSaveGame: true);

  double health = 100;

  @override
  Map<String, dynamic> captureSaveData() => {'health': health};

  @override
  void restoreSaveData(Map<String, dynamic> data) => health = (data['health'] as num).toDouble();
}

class _Script extends LuminaLevelScriptActor with LuminaBlueprintLevelActors {
  _Script() : super(key: const LuminaObjectKey('L_Keys_script'));

  @override
  Map<String, String> get levelActorIds => const {'Door': 'door_01'};
}

void main() {
  test('keys are equal by value', () {
    expect(const LuminaObjectKey('a'), const LuminaObjectKey('a'));
    expect(LuminaObjectKey('a'), isNot(const LuminaObjectKey('b')));
    expect(LuminaObjectKey('a').hashCode, const LuminaObjectKey('a').hashCode);
    expect({const LuminaObjectKey('a'), LuminaObjectKey('a')}, hasLength(1));
    expect(const LuminaObjectKey('a').value, 'a');
  });

  test('the key prints the text saves and level names have always embedded', () {
    expect(const LuminaObjectKey('door_01').toString(), "[<'door_01'>]");
    expect(LuminaLevel(key: const LuminaObjectKey('L_Keys')).effectiveName, "[<'L_Keys'>]");
  });

  test('a world finds its placed actors by key', () {
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final door = LuminaActor(key: const LuminaObjectKey('door_01'), location: Vector3(0, 0, 400));
    final crate = LuminaActor(key: const LuminaObjectKey('crate_01'));
    world.persistentLevel
      ..registerActor(door)
      ..registerActor(crate);
    final script = _Script();
    world.persistentLevel.scriptActor = script;
    world.beginPlay();

    expect(world.actors.where((a) => a.key == const LuminaObjectKey('crate_01')), [same(crate)]);
    expect(script.levelActor('Door'), same(door));
    world.destroyActor(door);
    world.tick(1 / 60);
    expect(script.levelActor('Door'), isNull);
  });

  test('a save written when actors carried a string value key restores onto the keyed actor', () async {
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final saves = LuminaSaveGameSubsystem(saveDirectoryPath: null);
    world.subsystems.registerSubsystem<LuminaSaveGameSubsystem>(saves, world);
    final hero = _KeyedHero(key: const LuminaObjectKey('hero_01'));
    world.persistentLevel.registerActor(hero);

    // The JSON as an earlier version wrote it: the saveId holds Flutter's
    // `ValueKey<String>` text.
    final legacy = jsonDecode('''
{"levelName": "DefaultLevel", "dataLayerStates": {}, "actors": [
  {"saveId": "LuminaLevel/_KeyedHero_[<'hero_01'>]", "actorClassName": "_KeyedHero",
   "location": [10.0, 20.0, 30.0], "rotation": [0.0, 0.0, 0.0, 1.0],
   "customData": {"health": 42.0}, "componentData": {}}
]}''') as Map<String, dynamic>;

    expect(hero.saveId, "LuminaLevel/_KeyedHero_[<'hero_01'>]");
    final report = await saves.restoreWorldState(LuminaWorldStateSnapshot.fromJson(legacy));
    expect(report.restored, 1);
    expect(hero.health, 42.0);
    expect(hero.actorLocation, Vector3(10, 20, 30));
  });
}
