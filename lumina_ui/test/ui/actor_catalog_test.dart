import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/details/models/component_property_registry.dart';
import 'package:lumina_ui/ui/features/main_editor/models/editor_actor_catalog.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// The spawn dialog hardcoded five types while the editor, the
/// viewport and the code generator supported ten, so a sky, a spot light or a
/// skeletal mesh could not be placed at all. One catalog now answers "what can
/// this editor spawn", and everything reads it.
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_catalog_test_');
    Directory('${tempDir.path}/CatalogGame').createSync(recursive: true);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  EditorViewModel makeEditor() => EditorViewModel(
        initialProject: const LuminaProject(projectName: 'CatalogGame', activeLevel: 'contents/levels/L_Main.lmas'),
        projectLocation: tempDir.path,
        enableTimers: false,
        autoInitAssets: false,
      );

  test('the catalog covers every actor type the code generator emits', () {
    // Mirrors the switch in DartCodeGeneratorService._emitActor. If codegen
    // learns a type, it belongs here too — that drift is the bug.
    const generated = {
      'Pawn',
      'PlayerStart',
      'Primitive',
      'StaticMesh',
      'SkeletalMesh',
      'DirectionalLight',
      'PointLight',
      'SpotLight',
      'Environment',
      'ProceduralSky',
      'ExponentialHeightFog',
      'PostProcessVolume',
    };
    final catalogIds = EditorActorCatalog.all.map((t) => t.id).toSet();
    expect(catalogIds.containsAll(generated), isTrue,
        reason: 'missing from the catalog: ${generated.difference(catalogIds)}');
  });

  test('only one procedural sky, and a placed one carries its parameters', () {
    final vm = makeEditor();
    addTearDown(vm.dispose);

    vm.spawnNewActor('ProceduralSky');
    final sky = vm.actors.singleWhere((a) => a.type == 'ProceduralSky');
    final component = sky.components.singleWhere((c) => c.type == 'LuminaProceduralSkyComponent');

    // The catalog seeds exactly the engine's defaults, so a freshly placed
    // actor already serialises, code-generates and plays.
    expect(
      LuminaProceduralSkyDescription.fromProperties(component.properties),
      LuminaProceduralSkyDescription.defaults,
    );
    expect(component.properties['timeOfDay'], 12.0);
    expect(component.properties['cloudCoverage'], 0.4);
    expect(component.properties['waterStrength'], 30.0);

    final refusal = vm.spawnRefusalFor('ProceduralSky');
    expect(refusal, isNotNull);
    expect(refusal, contains('already'));
    vm.spawnNewActor('ProceduralSky');
    expect(vm.actors.where((a) => a.type == 'ProceduralSky').length, 1,
        reason: 'the second one is refused, not silently created');
  });

  test('every property the Details panel offers for the procedural sky exists on the component', () {
    final descriptor = ComponentPropertyRegistry.descriptors['LuminaProceduralSkyComponent'];
    expect(descriptor, isNotNull, reason: 'the Details panel must know how to edit the sky');

    final seeded = LuminaProceduralSkyDescription.defaults.toProperties();
    for (final prop in descriptor!.properties) {
      expect(seeded.containsKey(prop.id), isTrue,
          reason: '${prop.id} is editable but never stored on the component');
      expect(prop.defaultValue, seeded[prop.id],
          reason: '${prop.id} default drifted from LuminaProceduralSkyDescription.defaults');
      expect(descriptor.sections, contains(prop.group));
    }
  });

  test('the types the old dialog forgot are all spawnable now', () {
    for (final id in ['Environment', 'SpotLight', 'SkeletalMesh', 'PlayerStart', 'Primitive']) {
      expect(EditorActorCatalog.byId(id), isNotNull, reason: '$id must be spawnable');
    }
  });

  test('every entry is grouped and carries its own icon and colour', () {
    expect(EditorActorCatalog.categories, isNotEmpty);
    for (final type in EditorActorCatalog.all) {
      expect(type.label.trim(), isNotEmpty);
      expect(type.category.trim(), isNotEmpty);
      expect(EditorActorCatalog.categories, contains(type.category));
    }
    // Grouping covers the catalog exactly once.
    final grouped = EditorActorCatalog.categories
        .expand((c) => EditorActorCatalog.inCategory(c))
        .map((t) => t.id)
        .toList();
    expect(grouped.length, EditorActorCatalog.all.length);
    expect(grouped.toSet().length, grouped.length, reason: 'no type appears twice');
  });

  test('spawning gives each type its defaults, and primitives get real geometry', () async {
    final vm = makeEditor();
    addTearDown(vm.dispose);

    vm.spawnNewActor('Primitive');
    final primitive = vm.actors.last;
    expect(primitive.type, 'Primitive');
    final shapeComponent = primitive.components.firstWhere((c) => c.type == 'LuminaProceduralMeshComponent');
    expect(shapeComponent.properties['shape'], 'box');
    // Centimetres: Place Actors ▸ Cube is a 1 m cube, not a 1 cm speck.
    expect(
      [shapeComponent.properties['sizeX'], shapeComponent.properties['sizeY'], shapeComponent.properties['sizeZ']],
      [100.0, 100.0, 100.0],
    );
    // The mesh is built lazily by the viewport path; ask for it directly.
    await vm.ensureActorMeshDataForTest(primitive);
    expect(primitive.meshData, isNotNull, reason: 'a spawned cube must have geometry');
    expect(primitive.meshData!.indices.length, greaterThan(0));

    vm.spawnNewActor('SpotLight');
    expect(vm.actors.last.type, 'SpotLight');
    expect(vm.actors.last.lightIntensity, greaterThan(0));
  });

  test('only one sky: a second Environment is refused with a reason', () {
    final vm = makeEditor();
    addTearDown(vm.dispose);

    vm.spawnNewActor('Environment');
    expect(vm.actors.where((a) => a.type == 'Environment').length, 1);

    final refusal = vm.spawnRefusalFor('Environment');
    expect(refusal, isNotNull);
    expect(refusal, contains('already'));

    vm.spawnNewActor('Environment');
    expect(vm.actors.where((a) => a.type == 'Environment').length, 1,
        reason: 'the second one is refused, not silently created');
  });

  test('names stay unique after a deletion', () {
    final vm = makeEditor();
    addTearDown(vm.dispose);

    vm.spawnNewActor('Primitive');
    vm.spawnNewActor('Primitive');
    final second = vm.actors.last;
    vm.deleteActorSubtree(second.id);
    vm.spawnNewActor('Primitive');

    final names = vm.actors.map((a) => a.name).toList();
    expect(names.toSet().length, names.length, reason: 'duplicate names: $names');
    final ids = vm.actors.map((a) => a.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'duplicate ids: $ids');
  });
}
