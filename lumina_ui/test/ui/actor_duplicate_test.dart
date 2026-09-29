import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/details/models/editor_component_node.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_transform.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/blueprint_test_project.dart';
import '../helpers/scaffold_game_project.dart';

/// A duplicated actor dropped its Blueprint class, mesh and
/// components, so the copy of a placed Blueprint drew nothing in the level
/// viewport, saved without its class and was missing from Play. Undoing the
/// duplicate stripped the class from every placed Blueprint.
///
/// A real Third Person project with `BP_Tunnel`: a scene root, an AC unit
/// and two barrels under it (a component chain), all real Props meshes.
final _props = '${Directory.current.parent.path}/test-assets/Props';
const _unitMesh = 'contents/meshes/static/SM_AcUnit.glb';
const _barrelMesh = 'contents/meshes/static/SM_Barrel.glb';
const _tunnelPath = 'contents/blueprints/BP_Tunnel.lmas';

void main() {
  late Directory root;
  late String dir;
  final hasProps =
      File('$_props/AC_units/ac_unit_b_600x600.glb').existsSync() && File('$_props/Barrels/fuel_barrel_red.glb').existsSync();

  setUpAll(() async {
    if (!hasProps) return;
    root = Directory.systemTemp.createTempSync('lumina_dup81_');
    dir = await scaffoldGameProject(root, name: 'dup_game', widgetLibrary: 'flutter');
    for (final (from, to) in [('AC_units/ac_unit_b_600x600.glb', _unitMesh), ('Barrels/fuel_barrel_red.glb', _barrelMesh)]) {
      File('$dir/$to')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(File('$_props/$from').readAsBytesSync());
    }
    writeBlueprint(
      dir,
      'BP_Tunnel',
      LuminaBlueprintDocument(
        parentClass: 'LuminaActor',
        components: [
          LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
          LuminaBlueprintComponent(
            id: 'unit',
            name: 'Unit',
            type: 'LuminaStaticMeshComponent',
            parentId: 'root',
            properties: {
              'staticMeshAsset': _unitMesh,
              'location': [0.0, 0.0, 0.0],
            },
          ),
          LuminaBlueprintComponent(
            id: 'barrel_l',
            name: 'BarrelL',
            type: 'LuminaStaticMeshComponent',
            parentId: 'unit',
            properties: {
              'staticMeshAsset': _barrelMesh,
              'location': [-120.0, 0.0, 0.0],
            },
          ),
          LuminaBlueprintComponent(
            id: 'barrel_r',
            name: 'BarrelR',
            type: 'LuminaStaticMeshComponent',
            parentId: 'barrel_l',
            properties: {
              'staticMeshAsset': _barrelMesh,
              'location': [240.0, 0.0, 0.0],
            },
          ),
        ],
      ),
    );
  });
  tearDownAll(() {
    if (hasProps && root.existsSync()) root.deleteSync(recursive: true);
  });

  LuminaProject manifest() =>
      LuminaProject.fromMap(Map<String, dynamic>.from(jsonDecode(File('$dir/dup_game.lmproject').readAsStringSync()) as Map));

  Future<EditorViewModel> editorFor(WidgetTester tester) async {
    final vm = EditorViewModel(
      initialProject: manifest(),
      projectLocation: root.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    vm.refreshAssets();
    return vm;
  }

  // The editor viewport's tickers never let pumpAndSettle settle.
  Future<void> settle(WidgetTester tester, bool Function() done, {int frames = 400}) async {
    await tester.pump();
    for (var i = 0; i < frames && !done(); i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
  }

  Future<void> chord(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump(const Duration(milliseconds: 16));
  }

  Future<EditorActorNode> placeTunnel(WidgetTester tester, EditorViewModel vm, List<double> at) async {
    final asset = vm.realAssets.firstWhere((a) => a.relativePath == _tunnelPath);
    await tester.runAsync(() => vm.spawnActorFromAsset(asset, location: at));
    return vm.actors.lastWhere((a) => a.blueprintClass == _tunnelPath);
  }

  Future<ViewportState> pumpEditor(WidgetTester tester, EditorViewModel vm, {double height = 1000}) async {
    tester.view.physicalSize = Size(1600, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: MainEditorView(viewModel: vm),
      ),
    );
    await settle(tester, () => false, frames: 10);
    return ViewportState(tester);
  }

  testWidgets('Ctrl+D on a placed Blueprint draws the copy with its own renderables; moving it leaves the original; '
      'undo keeps the original\'s class', (tester) async {
    final vm = await editorFor(tester);
    final viewport = await pumpEditor(tester, vm);
    final original = await placeTunnel(tester, vm, [0.0, 0.0, 0.0]);
    expect(original.meshData, isNotNull);
    await settle(tester, () => viewport.instanceOf(original.id) != null);
    final drawnOriginal = viewport.instanceOf(original.id)!;
    expect(drawnOriginal.entities, isNotEmpty);

    // Ctrl+D with the viewport focused, as a user does it.
    await tester.tapAt(tester.getCenter(find.byType(ViewportWidget)), kind: PointerDeviceKind.mouse);
    await settle(tester, () => false, frames: 3);
    vm.selectActor(original);
    final before = vm.actors.map((a) => a.id).toSet();
    await chord(tester, LogicalKeyboardKey.keyD);
    final copies = vm.actors.where((a) => !before.contains(a.id)).toList();
    expect(copies, hasLength(1), reason: 'Ctrl+D made one copy');
    final copy = copies.single;
    expect(copy.name, '${original.name}_Copy');
    expect(copy.type, 'Blueprint');
    expect(copy.blueprintClass, _tunnelPath, reason: 'the copy is an instance of the same class');
    expect(copy.meshData, isNotNull, reason: 'the copy has the class\'s mesh to draw');
    expect(copy.meshAssetPath, original.meshAssetPath);
    expect(copy.blueprintPreview?.meshAsset, _unitMesh);

    // Its own instance in the scene: as many renderables as the original, not
    // the original's entities.
    await settle(tester, () => viewport.instanceOf(copy.id) != null);
    final drawnCopy = viewport.instanceOf(copy.id);
    expect(drawnCopy, isNotNull, reason: 'the viewport draws the copy');
    expect(drawnCopy!.entities.length, drawnOriginal.entities.length);
    expect(drawnCopy.entities.toSet().intersection(drawnOriginal.entities.toSet()), isEmpty);
    final scene = viewport.state.nativeSceneForTest as FilamentScene;
    expect(drawnCopy.entities.every(scene.hasEntity), isTrue);

    // Moved: the copy's root follows, the original stays where it was.
    vm.selectActor(copy);
    vm.updateActorLocation([400.0, 250.0, 0.0]);
    await settle(tester, () => viewport.rootX(copy.id) != null && viewport.rootX(copy.id)! > 1);
    final tm = FilamentTransformManager(viewport.state.nativeEngineForTest as FilamentEngine);
    final copyRoot = tm.getTransform(drawnCopy.root);
    final expected = EditorTransforms.meshMatrix(copy).getTranslation();
    expect(copyRoot[12], closeTo(expected.x, 1e-3));
    expect(copyRoot[13], closeTo(expected.y, 1e-3));
    expect(copyRoot[14], closeTo(expected.z, 1e-3));
    final originalRoot = tm.getTransform(drawnOriginal.root);
    final originalAt = EditorTransforms.meshMatrix(original).getTranslation();
    expect(originalRoot[12], closeTo(originalAt.x, 1e-3), reason: 'the original did not move');
    expect(original.location, [0.0, 0.0, 0.0]);

    // Undo the move and the duplicate: the copy leaves, the original keeps
    // its class and stays drawn; redo brings a drawn copy back.
    vm.transactions.undo();
    vm.transactions.undo();
    await settle(tester, () => viewport.instanceOf(copy.id) == null);
    expect(vm.actors.where((a) => a.id == copy.id), isEmpty);
    final restored = vm.actors.firstWhere((a) => a.id == original.id);
    expect(restored.blueprintClass, _tunnelPath, reason: 'undo does not strip the class');
    expect(restored.meshData, isNotNull);
    expect(restored.toMap()['blueprintClass'], _tunnelPath);
    await settle(tester, () => viewport.instanceOf(original.id) != null);
    expect(viewport.instanceOf(original.id), isNotNull);
    vm.transactions.redo();
    final redone = vm.actors.where((a) => !before.contains(a.id)).toList();
    expect(redone, hasLength(1));
    expect(redone.single.blueprintClass, _tunnelPath);
    await settle(tester, () => viewport.instanceOf(redone.single.id) != null);
    expect(viewport.instanceOf(redone.single.id), isNotNull, reason: 'the redone copy is drawn');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    vm.dispose();
  }, skip: !hasProps);

  testWidgets(
    'Outliner ▸ Duplicate and Edit ▸ Duplicate copy the class too; the copy survives save → reload and Play spawns it',
    (tester) async {
      final vm = await editorFor(tester);
      await pumpEditor(tester, vm);
      final original = await placeTunnel(tester, vm, [0.0, -600.0, 0.0]);

      // What the Outliner's right-click ▸ Duplicate and MCP `duplicate_actor`
      // run on the selected actor. (The context menu itself is not driven here:
      // under the widget test binding its dropdown opens below the window.)
      vm.selectActor(original);
      vm.duplicateSelectedActor();
      await tester.pump(const Duration(milliseconds: 16));
      final fromOutliner = vm.actors.where((a) => a.name == '${original.name}_Copy').toList();
      expect(fromOutliner, hasLength(1), reason: 'Outliner ▸ Duplicate made a copy');
      expect(fromOutliner.single.blueprintClass, _tunnelPath);
      expect(fromOutliner.single.meshData, isNotNull);

      // Edit ▸ Duplicate (the menu's command).
      final copy = fromOutliner.single;
      vm.selectActor(copy);
      vm.updateActorLocation([500.0, -600.0, 0.0]);
      vm.selectActor(original);
      vm.commands.execute('edit.duplicate');
      final fromMenu = vm.actors.where((a) => a.id != copy.id && a.name == '${original.name}_Copy').toList();
      expect(fromMenu, hasLength(1));
      expect(fromMenu.single.blueprintClass, _tunnelPath);
      expect(fromMenu.single.id, isNot(copy.id));

      // Save, reopen the project: the copy is still a BP_Tunnel at its place.
      await tester.runAsync(vm.saveLevelAndGenerateCode);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      vm.dispose();

      final reopened = await editorFor(tester);
      final reloaded = reopened.actors.where((a) => a.id == copy.id).firstOrNull;
      expect(reloaded, isNotNull, reason: 'the copy was saved');
      expect(reloaded!.blueprintClass, _tunnelPath, reason: 'saved with its class');
      expect(reloaded.location, [500.0, -600.0, 0.0]);
      await tester.runAsync(() => reopened.ensureActorMeshDataForTest(reloaded));
      expect(reloaded.meshData, isNotNull, reason: 'reloaded, the copy draws the class\'s mesh');
      final reloadedOriginal = reopened.actors.firstWhere((a) => a.id == original.id);
      expect(reloadedOriginal.blueprintClass, _tunnelPath);
      expect(reloadedOriginal.location, [0.0, -600.0, 0.0], reason: 'the original is unchanged');

      // Play spawns both BP_Tunnels with their components.
      expect(await tester.runAsync(reopened.requestPlay), isTrue, reason: '${reopened.playBlockers}');
      final world = LuminaWorld();
      reopened.pieController.startHeadlessForTest(world);
      LuminaActor runtimeOf(String id) => world.persistentLevel.actors.firstWhere((a) => a.key == ValueKey(id));
      final runtimeCopy = runtimeOf(copy.id);
      expect(runtimeCopy, isA<LuminaBlueprintActor>(), reason: 'Play spawns the copy as the Blueprint');
      expect(runtimeCopy.actorLocation, LuminaAxes.location([500.0, -600.0, 0.0]));
      final components = (runtimeCopy as LuminaBlueprintInstance).blueprintComponents;
      for (final id in ['unit', 'barrel_l', 'barrel_r']) {
        expect(components[id], isA<LuminaStaticMeshComponent>(), reason: 'the copy has its $id mesh in Play');
      }
      expect(runtimeOf(original.id).actorLocation, LuminaAxes.location([0.0, -600.0, 0.0]));
      reopened.pieController.stopHeadlessForTest();
      reopened.dispose();
    },
    skip: !hasProps,
  );

  test('a duplicate keeps what every actor kind draws, with its own components', () async {
    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'DupKinds'),
      projectLocation: Directory.systemTemp.createTempSync('lumina_dup81_kinds_').path,
      enableTimers: false,
      autoInitAssets: false,
    );
    addTearDown(() => Directory(vm.projectDirPath).parent.deleteSync(recursive: true));
    final mesh = EditorActorNode(
      id: 'mesh_1',
      name: 'Barrel_1',
      type: 'StaticMesh',
      location: [10.0, 20.0, 0.0],
      meshAssetPath: '/abs/SM_Barrel.lmas',
      components: [
        EditorComponentNode(
          id: 'mesh_1_mesh',
          type: 'LuminaMeshComponent',
          name: 'Mesh Component',
          properties: {
            'collision': {'preset': 'BlockAll'},
            'offset': [1.0, 2.0, 3.0],
          },
        ),
      ],
    );
    vm.restoreSnapshot([mesh]);
    for (final type in ['Primitive', 'PointLight', 'Environment']) {
      vm.spawnNewActor(type);
    }
    for (final actor in List.of(vm.actors)) {
      final before = vm.actors.map((a) => a.id).toSet();
      vm.selectActor(actor);
      vm.duplicateSelectedActor();
      final copy = vm.actors.firstWhere((a) => !before.contains(a.id));
      expect(copy.meshAssetPath, actor.meshAssetPath, reason: '${actor.type}: mesh path');
      expect(copy.components.map((c) => c.type), actor.components.map((c) => c.type), reason: '${actor.type}: components');
      expect(
        jsonEncode([for (final c in copy.components) c.properties]),
        jsonEncode([for (final c in actor.components) c.properties]),
        reason: '${actor.type}: component properties',
      );
      final ids = {for (final c in actor.components) c.id};
      expect(
        copy.components.where((c) => ids.contains(c.id)),
        isEmpty,
        reason: '${actor.type}: the copy\'s components have their own ids',
      );
      // A deep copy: editing the copy leaves the original.
      for (final c in copy.components) {
        c.properties['edited'] = true;
      }
      expect(actor.components.any((c) => c.properties.containsKey('edited')), isFalse);
      if (actor.id == 'mesh_1') {
        ((copy.components.single.properties['offset']) as List)[0] = 99.0;
        expect((actor.components.single.properties['offset'] as List)[0], 1.0, reason: 'nested lists are copied');
      }
    }
    vm.dispose();
  });
}

/// The viewport's test seams, typed.
class ViewportState {
  ViewportState(this.tester);
  final WidgetTester tester;

  dynamic get state => tester.state(find.byType(ViewportWidget));

  ({int root, List<int> entities})? instanceOf(String id) =>
      state.actorInstanceInSceneForTest(id) as ({int root, List<int> entities})?;

  double? rootX(String id) {
    final instance = instanceOf(id);
    if (instance == null) return null;
    return FilamentTransformManager(state.nativeEngineForTest as FilamentEngine).getTransform(instance.root)[12];
  }
}
