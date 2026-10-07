import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/property_editors/collision_section_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/details/models/editor_component_node.dart';
import 'package:lumina_ui/ui/features/details/services/blueprint_collision_overrides.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/blueprint_test_project.dart';

/// The reusable Collision section (lumina's collision
/// JSON) and the level Details of a placed Blueprint's collision components,
/// on a real project with a real BP_Chair and level `.lmas`.
void main() {
  group('CollisionJson', () {
    test('a preset writes its table; Trigger turns overlap events on', () {
      final json = CollisionJson.withPreset(const {'generateOverlapEvents': false}, LuminaCollisionPreset.trigger);
      expect(json['preset'], 'trigger');
      expect(json['objectType'], 'worldDynamic');
      expect(json['responses'], {'worldStatic': 'ignore', 'worldDynamic': 'overlap', 'pawn': 'overlap'});
      expect(json['generateOverlapEvents'], isTrue);
      expect(json['collisionEnabled'], isTrue);
      expect(CollisionJson.preset(json), LuminaCollisionPreset.trigger);
    });

    test('an empty value shows the base (Block All Dynamic, or Pawn for a character capsule)', () {
      expect(CollisionJson.preset(const {}), LuminaCollisionPreset.blockAllDynamic);
      expect(CollisionJson.preset(const {}, base: LuminaCollisionProfile.forPreset(LuminaCollisionPreset.pawn)), LuminaCollisionPreset.pawn);
    });

    test('Custom keeps the grid and sticks, even when the grid matches a table', () {
      final trigger = CollisionJson.withPreset(const {}, LuminaCollisionPreset.trigger);
      final custom = CollisionJson.withPreset(trigger, LuminaCollisionPreset.custom);
      expect(custom['preset'], 'custom');
      expect(custom['responses'], trigger['responses']);
      expect(CollisionJson.preset(custom), LuminaCollisionPreset.custom);
      final block = CollisionJson.withResponse(custom, CollisionObjectType.pawn, CollisionResponse.block);
      expect(block['preset'], 'custom');
      expect((block['responses'] as Map)['pawn'], 'block');
      // Back to the table's value: still Custom.
      final back = CollisionJson.withResponse(block, CollisionObjectType.pawn, CollisionResponse.overlap);
      expect(CollisionJson.preset(back), LuminaCollisionPreset.custom);
      // lumina reads the same thing.
      final c = LuminaBoxComponent()..applyCollisionJson(block);
      expect(c.getResponse(CollisionObjectType.pawn), CollisionResponse.block);
      expect(c.getResponse(CollisionObjectType.worldStatic), CollisionResponse.ignore);
    });

    test('No Collision disables; Generate Overlap Events keeps the preset; object type and enabled make it Custom', () {
      final none = CollisionJson.withPreset(const {}, LuminaCollisionPreset.noCollision);
      expect(none['collisionEnabled'], isFalse);
      expect(none['responses'], {'worldStatic': 'ignore', 'worldDynamic': 'ignore', 'pawn': 'ignore'});
      final pawn = CollisionJson.withPreset(const {}, LuminaCollisionPreset.pawn);
      final quiet = CollisionJson.withGenerateOverlapEvents(pawn, false);
      expect(quiet['preset'], 'pawn');
      expect(quiet['generateOverlapEvents'], isFalse);
      expect(CollisionJson.withObjectType(pawn, CollisionObjectType.worldStatic)['preset'], 'custom');
      expect(CollisionJson.withCollisionEnabled(pawn, false)['preset'], 'custom');
    });
  });

  group('level Details', () {
    late BlueprintTestProject project;
    const chairPath = 'contents/blueprints/BP_Chair.lmas';

    setUp(() {
      project = BlueprintTestProject.create(name: 'ChairLevel');
      writeBlueprint(
        project.dir,
        'BP_Chair',
        LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
          LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
          LuminaBlueprintComponent(id: 'seat_box', name: 'SeatBox', type: 'LuminaBoxComponent', parentId: 'root', properties: {
            'boxExtent': [40.0, 40.0, 50.0],
            'location': [0.0, 0.0, 50.0],
            ...LuminaCollisionProfile.forPreset(LuminaCollisionPreset.blockAll).toJson(),
          }),
          LuminaBlueprintComponent(id: 'arrow', name: 'Arrow', type: 'LuminaArrowComponent', parentId: 'root'),
        ]),
      );
    });
    tearDown(() => project.dispose());

    Future<EditorViewModel> editor() async {
      final manifest = LuminaProject.fromMap(
          Map<String, dynamic>.from(jsonDecode(File('${project.dir}/ChairLevel.lmproject').readAsStringSync()) as Map));
      final vm = EditorViewModel(initialProject: manifest, projectLocation: project.root.path, enableTimers: false, autoInitAssets: false);
      await vm.ensureDefaultLevelAssets();
      vm.refreshAssets();
      return vm;
    }

    Future<void> pumpDetails(WidgetTester tester, EditorViewModel vm) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: DetailsWidget(viewModel: vm))));
      await tester.pump(const Duration(milliseconds: 50));
    }

    Map<String, dynamic> savedActor(EditorViewModel vm, String id) {
      final level = jsonDecode(File('${vm.projectDirPath}/contents/levels/${vm.activeLevelName}.lmas').readAsStringSync()) as Map;
      return Map<String, dynamic>.from((level['metadata']['actors'] as List).cast<Map>().firstWhere((a) => a['id'] == id));
    }

    testWidgets('a placed BP_Chair shows its box\'s Collision section; Overlap All persists in the level .lmas', (tester) async {
      final vm = (await tester.runAsync(editor))!;
      addTearDown(vm.dispose);
      final asset = vm.realAssets.firstWhere((a) => a.relativePath == chairPath);
      await tester.runAsync(() => vm.spawnActorFromAsset(asset, location: [200.0, 0.0, 0.0]));
      final chair = vm.actors.firstWhere((a) => a.blueprintClass == chairPath);
      vm.selectActorById(chair.id);
      await pumpDetails(tester, vm);

      expect(find.byKey(const ValueKey('details_collision_seat_box_section')), findsOneWidget, reason: 'the box has a Collision section');
      expect(find.text('SeatBox (Box)'), findsOneWidget);
      expect(find.byKey(const ValueKey('details_collision_arrow_section')), findsNothing, reason: 'an arrow does not collide');
      Select<LuminaCollisionPreset> preset() =>
          tester.widget<Select<LuminaCollisionPreset>>(find.byKey(const ValueKey('details_collision_seat_box_preset')));
      expect(preset().value, LuminaCollisionPreset.blockAll, reason: 'the class\'s preset');

      await tester.tap(find.byKey(const ValueKey('details_collision_seat_box_preset')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('details_collision_seat_box_preset_overlapAll')).last);
      await tester.pumpAndSettle();
      expect(preset().value, LuminaCollisionPreset.overlapAll);
      final override = BlueprintCollisionOverrides.overrideOf(chair, 'seat_box')!;
      expect(override.type, 'LuminaBoxComponent');
      expect(override.properties['preset'], 'overlapAll');
      expect(override.properties['responses'], {'worldStatic': 'overlap', 'worldDynamic': 'overlap', 'pawn': 'overlap'});
      expect(
        tester.widget<RadioGroup<CollisionResponse>>(find.byKey(const ValueKey('details_collision_seat_box_response_pawn'))).value,
        CollisionResponse.overlap,
      );
      // The class keeps Block All: this is the placement's own.
      expect(readBlueprint('${project.dir}/$chairPath').components.singleWhere((c) => c.id == 'seat_box').properties['preset'], 'blockAll');

      // One undo step, and back.
      vm.transactions.undo();
      await tester.pump();
      expect(BlueprintCollisionOverrides.overrideOf(chair, 'seat_box'), isNull);
      expect(preset().value, LuminaCollisionPreset.blockAll);
      vm.transactions.redo();
      await tester.pump();
      expect(preset().value, LuminaCollisionPreset.overlapAll);

      await tester.runAsync(vm.saveLevelAndGenerateCode);
      final saved = savedActor(vm, chair.id);
      final stored = (saved['components'] as List).cast<Map>().singleWhere((c) => c['properties']?['blueprintComponentId'] == 'seat_box');
      expect(stored['properties']['preset'], 'overlapAll');
      expect(stored['properties']['objectType'], 'worldStatic');

      // Reopened from disk, the level Details shows it again.
      final reopened = (await tester.runAsync(editor))!;
      addTearDown(reopened.dispose);
      final again = reopened.actors.firstWhere((a) => a.id == chair.id);
      expect(BlueprintCollisionOverrides.collisionOf(again,
              BlueprintCollisionOverrides.collisionComponentsOf(again, reopened.projectDirPath).single)['preset'],
          'overlapAll');
      reopened.selectActorById(chair.id);
      await pumpDetails(tester, reopened);
      expect(preset().value, LuminaCollisionPreset.overlapAll);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('an actor\'s own collision component edits its collision in place, one undo step', (tester) async {
      final vm = (await tester.runAsync(editor))!;
      addTearDown(vm.dispose);
      vm.spawnNewActor('Pawn');
      final pawn = vm.actors.last;
      pawn.components.add(EditorComponentNode(id: '${pawn.id}_box', type: 'LuminaBoxComponent', name: 'Box Collision'));
      vm.selectActorById(pawn.id);
      await pumpDetails(tester, vm);
      final prefix = 'details_collision_${pawn.id}_box';
      expect(find.byKey(ValueKey('${prefix}_section')), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('${prefix}_preset')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('${prefix}_preset_pawn')).last);
      await tester.pumpAndSettle();
      final box = pawn.components.singleWhere((c) => c.id == '${pawn.id}_box');
      expect(box.properties['preset'], 'pawn');
      expect(box.properties['objectType'], 'pawn');
      vm.transactions.undo();
      await tester.pump();
      expect(box.properties.containsKey('preset'), isFalse);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
