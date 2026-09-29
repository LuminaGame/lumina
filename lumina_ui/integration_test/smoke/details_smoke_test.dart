import 'dart:convert';
import 'dart:io';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/property_editors/asset_ref_field.dart';
import 'package:lumina_ui/ui/core/property_editors/color_field.dart';
import 'package:lumina_ui/ui/core/property_editors/scrub_numeric_field.dart';
import 'package:lumina_ui/ui/core/property_editors/vector_row.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/features/details/models/editor_component_node.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';

import '../../test/helpers/scaffold_game_project.dart';

const _barrelGlb = 'Props/Barrels/fuel_barrel_red.glb';

/// Boots the real editor on a real temp project with the barrel imported
/// through the real import pipeline, and returns the view model.
Future<EditorViewModel> _bootEditor(WidgetTester tester, Directory pDir, String projectName) async {
  final p = LuminaProject(
    projectName: projectName,
    activeLevel: 'contents/levels/L_Main.lmas',
    settings: const EngineScalabilitySettings(targetFps: 60),
  );
  final vm = EditorViewModel(initialProject: p, projectLocation: pDir.path, enableTimers: false);
  addTearDown(vm.dispose);
  // The view model loads (and seeds) the level asynchronously and then
  // replaces its actor list wholesale: let that land before adding actors, or
  // they vanish mid-scenario.
  await tester.runAsync(() => vm.ensureDefaultLevelAssets());
  await tester.runAsync(() => vm.processImportPipeline(
        sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/$_barrelGlb',
      ));
  vm.refreshAssets();
  return vm;
}

/// Spawns the imported barrel at [location] and returns the new actor's id.
Future<String> _spawnBarrel(WidgetTester tester, EditorViewModel vm, List<double> location) async {
  final mesh = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh);
  await tester.runAsync(() => vm.spawnActorFromAsset(mesh, location: location));
  return vm.actors.last.id;
}

/// Pumps a bounded run of frames on the live clock: the editor viewport runs
/// tickers for as long as it is mounted, so `pumpAndSettle` never settles.
Future<void> _settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
  }
}

/// Picks [item] from the menu bar's [top] menu, on video.
Future<void> _menu(WidgetTester tester, SmokeRecorder rec, String top, String item) async {
  await tester.tap(find.text(top).first);
  await _settle(tester);
  await rec.hold(const Duration(milliseconds: 600));
  // Undo/Redo carry the transaction's name ("Undo Duplicate Subtree").
  await tester.tap(find.byWidgetPredicate((w) => w is Text && (w.data ?? '').startsWith(item)).last);
  await _settle(tester);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Details Smoke Scenario: Modifying Properties', (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('details_smoke_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeProjectDetails')..createSync(recursive: true);

    try {
      final vm = await _bootEditor(tester, pDir, 'SmokeProjectDetails');
      vm.addActorNodeForTest(EditorActorNode(
        id: 'directional-light',
        name: 'DirectionalLight_Sun',
        type: 'LuminaLight',
        location: [0, 0, 500],
        components: [
          EditorComponentNode(
            id: 'c1',
            type: 'LuminaLightComponent',
            name: 'Light',
            properties: {'lightColorHex': '#FFFFFF', 'lightIntensity': 100000.0, 'castShadows': true},
          ),
        ],
      ));
      final barrelId = await _spawnBarrel(tester, vm, [0, 0, 0]);
      vm.clearSelection();

      // The boundary wraps the whole app: the asset picker and Add Component
      // dialogs are overlays above the page.
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(
          title: 'Smoke Details',
          theme: luminaEditorTheme(),
          home: Scaffold(child: MainEditorView(viewModel: vm)),
        ),
      ));
      await _settle(tester, 30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));

      // Select the light by clicking its outliner row.
      await tester.tap(find.byKey(const ValueKey('row_gesture_directional-light')));
      await _settle(tester);
      expect(vm.selectedActor?.id, 'directional-light');
      expect(find.byType(ColorField), findsOneWidget);
      await rec.hold(const Duration(seconds: 1));

      // Type a new light colour into the Light Color field and press Enter.
      final colorText = find.descendant(of: find.byType(ColorField), matching: find.byType(TextField));
      await tester.tap(colorText);
      await rec.typeText(colorText, '#FFB347');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _settle(tester);
      expect(vm.actors.firstWhere((a) => a.id == 'directional-light').components.first.properties['lightColorHex'], '#FFB347');
      await rec.hold(const Duration(seconds: 1));

      // Select the barrel in the outliner: the panel switches to it.
      await tester.tap(find.byKey(ValueKey('row_gesture_$barrelId')));
      await _settle(tester);
      expect(vm.selectedActor?.id, barrelId);
      await rec.hold(const Duration(seconds: 1));

      // Scrub the Location Z field: the barrel rises in the viewport as the
      // value is dragged.
      final zField = find.descendant(of: find.byType(VectorRow).first, matching: find.byType(ScrubNumericField)).at(2);
      final zCenter = tester.getCenter(zField) + const Offset(10, 0);
      final z0 = vm.actors.firstWhere((a) => a.id == barrelId).location[2];
      // The first pixels go slowly, as a hand does: a scrub is a horizontal
      // drag, and it has to win over the text field's own drag-to-select.
      final scrub = await tester.startGesture(zCenter, kind: PointerDeviceKind.mouse);
      for (var i = 0; i < 3; i++) {
        await scrub.moveBy(const Offset(1, 0));
        await rec.hold(const Duration(milliseconds: 33));
      }
      for (var i = 0; i < 40; i++) {
        await scrub.moveBy(const Offset(4, 0));
        await rec.hold(const Duration(milliseconds: 33));
      }
      await scrub.up();
      await _settle(tester);
      final z = vm.actors.firstWhere((a) => a.id == barrelId).location[2];
      expect(z, greaterThan(20), reason: 'the scrub moved the barrel up');
      await rec.hold(const Duration(seconds: 1));

      // The scrub is one undo step: Edit -> Undo puts the barrel
      // back on the ground, Edit -> Redo lifts it again.
      await _menu(tester, rec, 'Edit', 'Undo');
      expect(vm.actors.firstWhere((a) => a.id == barrelId).location[2], z0, reason: 'Undo reverts the scrub');
      await rec.hold(const Duration(seconds: 1));
      await _menu(tester, rec, 'Edit', 'Redo');
      expect(vm.actors.firstWhere((a) => a.id == barrelId).location[2], closeTo(z, 1e-9), reason: 'Redo re-applies it');
      await rec.hold(const Duration(seconds: 1));

      // Click Location X and type a value: the click itself writes nothing,
      // and the typed value is one undo step.
      final xField = find.descendant(of: find.byType(VectorRow).first, matching: find.byType(ScrubNumericField)).at(0);
      final x0 = vm.actors.firstWhere((a) => a.id == barrelId).location[0];
      await tester.tap(xField, kind: PointerDeviceKind.mouse);
      await _settle(tester);
      expect(vm.actors.firstWhere((a) => a.id == barrelId).location[0], x0, reason: 'a click does not move the barrel');
      await rec.typeText(find.descendant(of: xField, matching: find.byType(EditableText)), '120');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _settle(tester);
      expect(vm.actors.firstWhere((a) => a.id == barrelId).location[0], 120);
      await rec.hold(const Duration(seconds: 1));
      await _menu(tester, rec, 'Edit', 'Undo');
      expect(vm.actors.firstWhere((a) => a.id == barrelId).location[0], x0, reason: 'one Undo reverts the typed X');
      expect(vm.actors.firstWhere((a) => a.id == barrelId).location[2], closeTo(z, 1e-9), reason: 'and only the typed X');
      await _menu(tester, rec, 'Edit', 'Redo');
      expect(vm.actors.firstWhere((a) => a.id == barrelId).location[0], 120);
      await rec.hold(const Duration(seconds: 1));

      // Mobility: Movable.
      await tester.tap(find.text('Movable'));
      await _settle(tester);
      expect(vm.actors.firstWhere((a) => a.id == barrelId).mobility, 'Movable');
      await rec.hold(const Duration(milliseconds: 800));

      // Add a Mesh component through the Add Component dialog.
      await tester.tap(find.descendant(of: find.byType(DetailsWidget), matching: find.text('Add')));
      await _settle(tester);
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Mesh')));
      await _settle(tester);
      final barrel = vm.actors.firstWhere((a) => a.id == barrelId);
      expect(barrel.components.map((c) => c.type), contains('LuminaMeshComponent'));
      await rec.hold(const Duration(seconds: 1));

      // Pick the imported material for the Materials slot from the shared
      // searchable asset picker. The Details list builds lazily:
      // scroll the new component's rows into view first.
      final materialsField = find.byWidgetPredicate((w) => w is AssetRefField && w.slotName == 'materials');
      await tester.scrollUntilVisible(materialsField, 120,
          scrollable: find.ancestor(
              of: find.descendant(of: find.byType(DetailsWidget), matching: find.text('Transform')),
              matching: find.byType(Scrollable)).first);
      await _settle(tester);
      await tester.tap(find.descendant(of: materialsField, matching: find.text('None')));
      await _settle(tester);
      await rec.hold(const Duration(seconds: 1));
      final material = vm.realAssets.firstWhere((a) => a.type == AssetType.filamat);
      await tester.tap(find.byKey(ValueKey('asset_ref_materials_item_${material.fileName}')));
      await _settle(tester);
      final meshComp = vm.actors.firstWhere((a) => a.id == barrelId).components.firstWhere((c) => c.type == 'LuminaMeshComponent');
      expect((meshComp.properties['materials'] as Map)['asset_path'], material.relativePath);
      await rec.hold(const Duration(seconds: 1));

      // Search the properties: only the shadow rows stay.
      await rec.typeText(find.byWidgetPredicate((w) => w is TextField && w.placeholder is Text && (w.placeholder as Text).data == 'Search Properties'), 'shadow');
      await _settle(tester);
      expect(find.text('Cast Shadow'), findsOneWidget);
      expect(find.text('Static Mesh Asset'), findsNothing);
      await rec.hold(const Duration(seconds: 1));

      final pngEditor = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('Details Smoke Scenario: Modifying Properties (property editors)', pngEditor, usedAssets: const [_barrelGlb]);
      rec.save('Details Smoke Scenario: Modifying Properties', usedAssets: const [_barrelGlb]);

      expect(pngEditor.length, greaterThan(0));
    } finally {
      if (tempProjectsDir.existsSync()) {
        tempProjectsDir.deleteSync(recursive: true);
      }
    }
  });

  testWidgets('Details Smoke Scenario: Multi-Edit Mode', (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('details_smoke_multi_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeProjectDetailsMulti')..createSync(recursive: true);

    try {
      final vm = await _bootEditor(tester, pDir, 'SmokeProjectDetailsMulti');
      // Three real barrels side by side, each with a Mesh component; the
      // middle one does not cast shadows, so that property is mixed.
      final ids = <String>[];
      for (final x in [-150.0, 0.0, 150.0]) {
        final id = await _spawnBarrel(tester, vm, [x, 0, 0]);
        ids.add(id);
        vm.addComponentWithTransaction(id, 'LuminaMeshComponent');
        final comp = vm.actors.firstWhere((a) => a.id == id).components.firstWhere((c) => c.type == 'LuminaMeshComponent');
        vm.updateComponentProperty(id, comp.id, 'castShadow', x != 0.0);
      }
      vm.clearSelection();

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(
          title: 'Smoke Details Multi',
          theme: luminaEditorTheme(),
          home: Scaffold(child: MainEditorView(viewModel: vm)),
        ),
      ));
      await _settle(tester, 30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));

      // One barrel, then Ctrl+click the other two in the outliner.
      await tester.tap(find.byKey(ValueKey('row_gesture_${ids[0]}')));
      await _settle(tester);
      await rec.hold(const Duration(seconds: 1));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.byKey(ValueKey('row_gesture_${ids[1]}')));
      await _settle(tester);
      await rec.hold(const Duration(milliseconds: 800));
      await tester.tap(find.byKey(ValueKey('row_gesture_${ids[2]}')));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _settle(tester);
      expect(vm.selectedActorIds, containsAll(ids));

      // The multi-edit panel: X differs (a dash), the shadow flag is mixed.
      expect(find.text('3 Actors Selected'), findsOneWidget);
      final locationX = find.descendant(of: find.byType(VectorRow).first, matching: find.byType(EditableText)).first;
      expect(tester.widget<EditableText>(locationX).controller.text, '—');
      final shadowBox = find.byWidgetPredicate((w) => w is Checkbox && w.state == CheckboxState.indeterminate);
      expect(shadowBox, findsWidgets);
      await rec.hold(const Duration(milliseconds: 1500));

      final pngEditor = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('Details Smoke Scenario: Multi-Edit Mode (multi-edit panel)', pngEditor, usedAssets: const [_barrelGlb]);

      List<List<double>> locations() => [for (final id in ids) List<double>.from(vm.actors.firstWhere((a) => a.id == id).location)];
      final multiLocation = find.descendant(of: find.byType(VectorRow).first, matching: find.byType(ScrubNumericField));

      // Multi-edit translation through the panel: scrub Location Z.
      // A scrub is relative, so the three barrels rise together, each keeping
      // its own X; the panel used to write the first barrel's X into all three.
      final lift = await tester.startGesture(tester.getCenter(multiLocation.at(2)) + const Offset(10, 0), kind: PointerDeviceKind.mouse);
      for (var i = 0; i < 3; i++) {
        await lift.moveBy(const Offset(1, 0));
        await rec.hold(const Duration(milliseconds: 33));
      }
      for (var i = 0; i < 40; i++) {
        await lift.moveBy(const Offset(4, 0));
        await rec.hold(const Duration(milliseconds: 33));
      }
      await lift.up();
      await _settle(tester);
      final lifted = locations()[0][2];
      expect(lifted, greaterThan(20), reason: 'the scrub lifted the barrels');
      expect(locations(), [
        [-150, 0, lifted],
        [0, 0, lifted],
        [150, 0, lifted],
      ], reason: 'each barrel keeps its own X');
      expect(tester.widget<EditableText>(find.descendant(of: multiLocation.at(0), matching: find.byType(EditableText))).controller.text, '—',
          reason: 'X is still mixed');
      await rec.hold(const Duration(seconds: 1));

      // Type Location Y: every barrel moves to Y = 60, again keeping its X.
      final yText = find.descendant(of: multiLocation.at(1), matching: find.byType(EditableText));
      await tester.tap(multiLocation.at(1), kind: PointerDeviceKind.mouse);
      await _settle(tester);
      await rec.typeText(yText, '60');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _settle(tester);
      expect(locations(), [
        [-150, 60, lifted],
        [0, 60, lifted],
        [150, 60, lifted],
      ]);
      await rec.hold(const Duration(seconds: 1));

      // Clicking the tri-state Cast Shadow box sets it on every barrel at once.
      await tester.ensureVisible(shadowBox.first);
      await _settle(tester);
      await tester.tap(shadowBox.first);
      await _settle(tester);
      final shadows = ids.map((id) => vm.actors.firstWhere((a) => a.id == id).components.firstWhere((c) => c.type == 'LuminaMeshComponent').properties['castShadow']).toSet();
      expect(shadows, hasLength(1), reason: 'one click made the flag common: $shadows');
      await rec.hold(const Duration(seconds: 1));

      // One Edit -> Undo reverts the shadow edit on all three at once.
      await _menu(tester, rec, 'Edit', 'Undo');
      final reverted = ids.map((id) => vm.actors.firstWhere((a) => a.id == id).components.firstWhere((c) => c.type == 'LuminaMeshComponent').properties['castShadow']).toList();
      expect(reverted, [true, false, true]);
      await rec.hold(const Duration(seconds: 1));

      // The next one takes back the typed Y, and the one after puts all three
      // barrels back on the ground, each at its own X.
      await _menu(tester, rec, 'Edit', 'Undo');
      expect(locations(), [
        [-150, 0, lifted],
        [0, 0, lifted],
        [150, 0, lifted],
      ]);
      await rec.hold(const Duration(milliseconds: 600));
      await _menu(tester, rec, 'Edit', 'Undo');
      expect(locations(), [
        [-150, 0, 0],
        [0, 0, 0],
        [150, 0, 0],
      ]);
      await rec.hold(const Duration(seconds: 1));
      rec.save('Details Smoke Scenario: Multi-Edit Mode', usedAssets: const [_barrelGlb]);

      expect(pngEditor.length, greaterThan(0));
    } finally {
      if (tempProjectsDir.existsSync()) {
        tempProjectsDir.deleteSync(recursive: true);
      }
    }
  });

  testWidgets('Details Smoke Scenario: searchable asset picker', (tester) async {
    // A launcher Third Person project (Quinn) with the real
    // barrel, AC unit and banana bunch imported (materials + image textures).
    // In the Skeletal Mesh editor the material slot picker opens with a
    // search field and a thumbnail per material (the editor renders missing
    // ones in the background and swaps them in), "barrel" narrows it, Enter
    // binds the match, and "Browse to asset" selects it in the Content
    // Browser.
    const sources = ['Props/Barrels/fuel_barrel_red.glb', 'Props/AC_units/ac_unit_a_300x300.glb', 'Props/Banana Bunch/banana_bunch_long.glb'];
    final root = Directory.systemTemp.createTempSync('lumina_smoke_details04_');
    addTearDown(() => root.deleteSync(recursive: true));
    final projectDir = (await tester.runAsync(() => scaffoldGameProject(root, name: 'picker_smoke', widgetLibrary: 'flutter')))!;
    final used = <String>[];
    for (final source in sources) {
      final file = File('${SmokeArtifacts.testAssetsDir.path}/$source');
      if (!file.existsSync()) continue;
      final imported = (await tester.runAsync(() => ImportAssetUseCase()(projectDir: projectDir, sourceFilePath: file.path)))!;
      expect(imported.isSuccess, isTrue, reason: imported.error);
      used.add(source);
    }
    expect(used, isNotEmpty, reason: 'test-assets present');
    final project = LuminaProject.fromMap(
        Map<String, dynamic>.from(jsonDecode(File('$projectDir/picker_smoke.lmproject').readAsStringSync()) as Map));
    final editor = EditorViewModel(initialProject: project, projectLocation: root.path);
    addTearDown(editor.dispose);
    await tester.runAsync(editor.ensureDefaultLevelAssets);
    editor.refreshAssets();

    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: editor)),
    ));
    await _settle(tester, 40);
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    Future<void> shot(String name) async => SmokeArtifacts.saveScreenshot(
        name, await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)),
        usedAssets: used);
    await rec.hold(const Duration(milliseconds: 800));

    // --- Quinn in the Skeletal Mesh editor -------------------------------------
    // Opened by path (File → New Asset, MCP `open_asset_editor`): the same
    // Skeleton editor a Content Browser double-click opens.
    final quinn = editor.realAssets.firstWhere((a) => a.relativePath == LuminaThirdPersonContent.projectMeshAssetPath);
    expect(quinn.type, AssetType.filameshSk);
    editor.openAssetEditorByPath(LuminaThirdPersonContent.projectMeshAssetPath);
    expect(editor.currentTab.category, 'Skeleton');
    final picker = find.byKey(const ValueKey('skeletal_material_slot_0'));
    for (var i = 0; i < 300 && picker.evaluate().isEmpty; i++) {
      await rec.hold(const Duration(milliseconds: 100));
    }
    expect(picker, findsOneWidget);
    expect(tester.widget(picker), isA<AssetPickerSelect>());
    await rec.hold(const Duration(milliseconds: 1500));

    // --- Open the picker: a search field and one thumbnail row per material ---
    await tester.ensureVisible(picker);
    await _settle(tester, 4);
    await tester.tap(picker);
    await _settle(tester, 8);
    const prefix = 'skeletal_material_picker_0';
    expect(find.byKey(const ValueKey('${prefix}_search')), findsOneWidget);
    final materials = editor.realAssets.where((a) => a.type == AssetType.filamat).toList();
    List<AssetThumbnail> thumbs() => tester
        .widgetList<AssetThumbnail>(find.descendant(of: find.byType(AssetPickerPopup), matching: find.byType(AssetThumbnail)))
        .toList();
    expect(thumbs(), isNotEmpty);
    // Materials without a thumbnail show their icon and get one rendered.
    for (var i = 0; i < 300 && thumbs().any((t) => t.bytes == null); i++) {
      await rec.hold(const Duration(milliseconds: 100));
    }
    expect(thumbs().where((t) => t.bytes != null), isNotEmpty, reason: 'material rows show their rendered thumbnails');
    await rec.hold(const Duration(milliseconds: 1200));
    await shot('details_asset_picker_all_materials');

    // --- Type a query: only the barrel's materials stay ----------------------
    await rec.typeText(find.byKey(const ValueKey('${prefix}_search')), 'barrel', perCharacter: const Duration(milliseconds: 160));
    await _settle(tester, 4);
    final rows = tester
        .widgetList(find.byWidgetPredicate(
            (w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('${prefix}_item_')))
        .map((w) => (w.key as ValueKey<String>).value.substring('${prefix}_item_'.length))
        .toList();
    expect(rows, isNotEmpty);
    final barrelMaterials = materials.where((m) => m.relativePath.toLowerCase().contains('barrel')).map((m) => m.fileName).toSet();
    expect(rows.toSet(), barrelMaterials, reason: 'the query leaves the barrel materials');
    expect(thumbs().where((t) => t.bytes != null), isNotEmpty);
    await rec.hold(const Duration(milliseconds: 1200));
    await shot('details_searchable_asset_picker');

    // --- Enter binds the first match; the closed control shows it ------------
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await _settle(tester, 10);
    expect(find.byType(AssetPickerPopup), findsNothing);
    final chosen = rows.first.replaceAll('.lmas', '');
    expect(find.descendant(of: picker, matching: find.text(chosen)), findsOneWidget);
    await rec.hold(const Duration(milliseconds: 1500));
    await shot('details_asset_picker_bound_slot');

    // --- Reopen: the pick leads Recently used; Escape closes -----------------
    await tester.tap(picker);
    await _settle(tester, 8);
    expect(find.byKey(ValueKey('${prefix}_recent_${rows.first}')), findsOneWidget, reason: 'Recently used lists the pick first');
    expect(find.text('RECENTLY USED'), findsOneWidget);
    await rec.hold(const Duration(milliseconds: 1500));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester, 8);
    expect(find.byType(AssetPickerPopup), findsNothing);
    await rec.hold(const Duration(milliseconds: 800));

    // --- Browse to asset: the Content Browser selects it ---------------------
    await tester.tap(find.byKey(const ValueKey('${prefix}_browse')));
    await _settle(tester, 12);
    final bound = materials.firstWhere((m) => m.fileName == rows.first);
    expect(editor.contentBrowserRevealPath, bound.relativePath);
    expect(editor.activeTabIndex, 0, reason: 'the level tab (and its Content Browser) comes to the front');
    await rec.hold(const Duration(milliseconds: 2000));
    await shot('details_asset_picker_browse_to_asset');
    final video = rec.save('Details Smoke Scenario: searchable asset picker', usedAssets: used);
    expect(SmokeArtifacts.videoDurationSeconds(video)!, greaterThanOrEqualTo(10.0));
  }, timeout: const Timeout(Duration(minutes: 10)));

  const removeScenario = 'Details Smoke Scenario: × removes exactly one component and Undo restores it in place';
  testWidgets(removeScenario, (tester) async {
    // × on one of two same-type components removed both, on every
    // selected actor, and Undo brought back only the first, at the end.
    final tempProjectsDir = Directory.systemTemp.createTempSync('details_remove_component_smoke_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeRemoveComponent')..createSync(recursive: true);
    try {
      final vm = await _bootEditor(tester, pDir, 'SmokeRemoveComponent');
      final barrelId = await _spawnBarrel(tester, vm, [0, 0, 0]);
      final otherId = await _spawnBarrel(tester, vm, [250, 0, 0]);
      const audioType = 'LuminaPlayerComponent';
      vm.addComponentWithTransaction(barrelId, audioType);
      vm.addComponentWithTransaction(barrelId, audioType);
      final barrel = vm.actors.firstWhere((a) => a.id == barrelId);
      final added = barrel.components.where((c) => c.type == audioType).toList().reversed.take(2).toList().reversed.toList();
      added[0].name = 'Player One';
      added[1].name = 'Player Two';
      final other = vm.actors.firstWhere((a) => a.id == otherId);
      final otherBefore = other.components.map((c) => c.id).toList();
      final orderBefore = barrel.components.map((c) => c.id).toList();

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: MainEditorView(viewModel: vm))),
      ));
      await _settle(tester, 30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(milliseconds: 1500));
      // Select the barrel in the World Outliner, as a user does.
      await tester.tap(find.byKey(ValueKey('row_gesture_$barrelId')));
      await _settle(tester, 20);
      expect(vm.selectedActor?.id, barrelId);
      // Window → Outliner off: Details takes the whole left column.
      await _menu(tester, rec, 'Window', 'Outliner');
      await _settle(tester, 20);
      expect(vm.layoutState.outlinerVisible, isFalse);
      // The component sections sit below the transform in the Details list:
      // scroll the panel down to them.
      final detailsScroll = find.descendant(of: find.byType(DetailsWidget), matching: find.byType(Scrollable)).first;
      // (A drag would land on the Transform's scrub fields, which take the
      // drag as a value change: move the list itself.)
      // The lazy list's extent grows as sections build: step until Player Two shows.
      final position = tester.state<ScrollableState>(detailsScroll).position;
      for (var i = 0; i < 60 && find.text('Player Two').evaluate().isEmpty; i++) {
        position.jumpTo((position.pixels + 200).clamp(0.0, position.maxScrollExtent));
        await _settle(tester, 3);
      }
      await tester.ensureVisible(find.text('Player Two'));
      await _settle(tester, 5);
      await _settle(tester, 10);
      await rec.hold(const Duration(seconds: 1));
      expect(find.text('Player One'), findsOneWidget);
      expect(find.text('Player Two'), findsOneWidget);
      SmokeArtifacts.saveScreenshot('$removeScenario: two Player components',
          await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));

      // The × on the row of "Player Two": the × icon level with its header.
      final headerY = tester.getCenter(find.text('Player Two')).dy;
      final xs = find.descendant(of: find.byType(DetailsWidget), matching: find.byIcon(LucideIcons.x)).evaluate().toList();
      final removeX = xs.map((e) => e.renderObject as RenderBox).reduce((a, b) =>
          ((a.localToGlobal(a.size.center(Offset.zero)).dy - headerY).abs() <=
                  (b.localToGlobal(b.size.center(Offset.zero)).dy - headerY).abs())
              ? a
              : b);
      await tester.tapAt(removeX.localToGlobal(removeX.size.center(Offset.zero)));
      await _settle(tester, 20);
      expect(barrel.components.map((c) => c.id), isNot(contains(added[1].id)));
      expect(barrel.components.map((c) => c.id), contains(added[0].id), reason: 'the other Player component stays');
      expect(other.components.map((c) => c.id).toList(), otherBefore, reason: 'the other barrel is untouched');
      expect(find.text('Player Two'), findsNothing);
      expect(find.text('Player One'), findsOneWidget);
      await rec.hold(const Duration(seconds: 2));
      SmokeArtifacts.saveScreenshot('$removeScenario: only Player Two removed',
          await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));

      // Edit → Undo puts it back where it was; Edit → Redo removes it again.
      await _menu(tester, rec, 'Edit', 'Undo');
      await _settle(tester, 20);
      expect(barrel.components.map((c) => c.id).toList(), orderBefore);
      expect(find.text('Player Two'), findsOneWidget);
      await rec.hold(const Duration(seconds: 2));
      SmokeArtifacts.saveScreenshot('$removeScenario: Undo restores it in place',
          await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));
      await _menu(tester, rec, 'Edit', 'Redo');
      await _settle(tester, 20);
      expect(barrel.components.map((c) => c.id), isNot(contains(added[1].id)));
      expect(barrel.components.map((c) => c.id), contains(added[0].id));
      await rec.hold(const Duration(seconds: 2));
      rec.save(removeScenario);
    } finally {
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  });
}
