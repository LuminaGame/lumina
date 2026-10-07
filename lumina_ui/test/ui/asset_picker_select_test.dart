import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';
import 'package:lumina_ui/ui/core/property_editors/asset_ref_field.dart';
import 'package:lumina_ui/ui/core/services/asset_picker_catalog.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/anim_blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/skeletal_mesh_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/anim_blueprint/state_pose_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/material_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/particle/particle_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/skeletal_mesh/skeletal_mesh_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/library_source.dart';
import '../helpers/temp_project.dart';

/// `flutter create` on disk, `pub get` a no-op: nothing here resolves packages.
ProcessRunner _scaffoldingRunner() {
  return (String exec, List<String> args, {String? workingDirectory, bool runInShell = false}) async {
    if (args.isNotEmpty && args.first == 'create') {
      final target = args.last;
      final projectName = args[args.indexOf('--project-name') + 1];
      Directory('$target/lib').createSync(recursive: true);
      File('$target/pubspec.yaml').writeAsStringSync(
        'name: $projectName\nenvironment:\n  sdk: ^3.12.0\ndependencies:\n  flutter:\n    sdk: flutter\n',
      );
    }
    return ProcessResult(0, 0, '', '');
  };
}

/// Every asset-picking combobox is the shared searchable
/// [AssetPickerSelect] with thumbnails. A real Third Person project (Quinn,
/// its clips and ABP_Character), a real imported barrel (material + image
/// textures with thumbnails) and five face/body materials carrying real PNG
/// thumbnails.
void main() {
  final barrelGlb = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb');
  final acUnitGlb = File('${SmokeArtifacts.testAssetsDir.path}/Props/AC_units/ac_unit_a_300x300.glb');
  late Directory root;
  late String dir;
  const name = 'picker_game';
  const faceMaterials = ['M_Face_EyeShell', 'M_Face_Eyelashes_Upper', 'M_Face_Eyelashes_Lower', 'M_Face_Skin', 'M_Body_Skin'];

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_asset_picker_');
    final config = Directory('${root.path}/.config')..createSync(recursive: true);
    await ProjectRepository(configDir: config, processRunner: _scaffoldingRunner())
        .createProject(projectName: name, projectLocation: root.path, template: kThirdPersonTemplateId);
    dir = '${root.path}/$name';
    for (final glb in [barrelGlb, acUnitGlb]) {
      if (glb.existsSync()) await AssetRepository().importExternalFile(projectPath: dir, sourceFilePath: glb.path);
    }
    // The barrel's base-colour texture thumbnail (a real PNG) is the
    // thumbnail of the face materials.
    final textures = AssetRepository().scanProjectContents(dir).where((a) => a.type == AssetType.texture).toList();
    final png = textures.map((t) => t.thumbnailBytes).firstWhere((b) => b != null && b.isNotEmpty, orElse: () => null);
    Directory('$dir/contents/materials/face').createSync(recursive: true);
    for (final m in faceMaterials) {
      File('$dir/contents/materials/face/$m.lmas').writeAsBytesSync(LuminaAsset(
        assetId: m,
        name: m,
        type: AssetType.filamat,
        hasThumbnail: png != null,
        thumbnailPng: png,
        rawMatSource: 'material {\n    name : $m,\n    parameters : [\n        { type : sampler2d, name : baseColorMap }\n    ],\n    shadingModel : lit\n}\n',
      ).toProtoBufferBytes());
    }
  });
  // The editor's git probe may still hold the folder on Windows.
  tearDownAll(() => deleteTempProject(root));

  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1800, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> settle(WidgetTester tester, [int frames = 8]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Iterable<String> rowKeys(WidgetTester tester, String prefix, {String kind = 'item'}) => tester
      .widgetList(find.byWidgetPredicate(
          (w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('${prefix}_${kind}_')))
      .map((w) => (w.key as ValueKey<String>).value.substring('${prefix}_${kind}_'.length));

  List<AssetThumbnail> popupThumbnails(WidgetTester tester) => tester
      .widgetList<AssetThumbnail>(find.descendant(of: find.byType(AssetPickerPopup), matching: find.byType(AssetThumbnail)))
      .toList();

  String quinnPath() => '$dir/${LuminaThirdPersonContent.projectMeshAssetPath}';

  Future<SkeletalMeshEditorViewModel> openSkeletal(WidgetTester tester) async {
    bigView(tester);
    final vm = SkeletalMeshEditorViewModel(assetPath: quinnPath());
    await tester.runAsync(vm.load);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: SkeletalMeshSubEditor(assetName: 'SKM_Superhero_Female', assetPath: quinnPath(), viewModel: vm),
      ),
    ));
    await settle(tester);
    return vm;
  }

  group('AssetPickerCatalog', () {
    RealAssetInfo info(String rel, AssetType type) =>
        RealAssetInfo(fileName: rel.split('/').last, relativePath: rel, type: type, bytes: 1);

    test('ranks name prefix, then name contains, then folder, then type', () {
      final assets = [
        info('contents/eye_folder/M_Body.lmas', AssetType.filamat),
        info('contents/materials/M_EyeShell.lmas', AssetType.filamat),
        info('contents/materials/Eye_Base.lmas', AssetType.filamat),
        info('contents/materials/M_Arm.lmas', AssetType.filamat),
      ];
      expect(AssetPickerCatalog.filter(assets, 'eye').map((a) => a.fileName),
          ['Eye_Base.lmas', 'M_EyeShell.lmas', 'M_Body.lmas']);
      expect(AssetPickerCatalog.filter(assets, 'FILAMAT'), hasLength(4), reason: 'type matches, case-insensitive');
      expect(AssetPickerCatalog.filter(assets, 'materials arm').map((a) => a.fileName), ['M_Arm.lmas'], reason: 'every word somewhere');
      expect(AssetPickerCatalog.filter(assets, '').map((a) => a.fileName).first, 'Eye_Base.lmas', reason: 'empty query: by name');
    });

    test('match ranges merge overlaps for highlighting', () {
      expect(AssetPickerCatalog.matchRanges('M_Face_EyeShell', 'eye'), [(7, 10)]);
      expect(AssetPickerCatalog.matchRanges('abcabc', 'bc ab'), [(0, 6)]);
      expect(AssetPickerCatalog.matchRanges('abc', ''), isEmpty);
    });

    test('recents keep the last five per type in the editor preferences file, next to other settings', () {
      final file = File('${root.path}/prefs_${DateTime.now().microsecondsSinceEpoch}.json')
        ..writeAsStringSync(jsonEncode({'flightCameraControl': 'always'}));
      final recents = AssetPickerRecents(file: file);
      for (var i = 0; i < 7; i++) {
        recents.record(info('contents/materials/M_$i.lmas', AssetType.filamat));
      }
      recents.record(info('contents/textures/T_0.lmas', AssetType.texture));
      recents.record(info('contents/materials/M_3.lmas', AssetType.filamat));
      expect(AssetPickerRecents(file: file).recentPaths({AssetType.filamat}), [
        'contents/materials/M_3.lmas',
        'contents/materials/M_6.lmas',
        'contents/materials/M_5.lmas',
        'contents/materials/M_4.lmas',
        'contents/materials/M_2.lmas',
      ]);
      expect(AssetPickerRecents(file: file).recentPaths({AssetType.texture}), ['contents/textures/T_0.lmas']);
      expect((jsonDecode(file.readAsStringSync()) as Map)['flightCameraControl'], 'always');
    });
  });

  testWidgets('the Skeletal Mesh material slot picker searches, shows thumbnails, and Enter picks the first match',
      (tester) async {
    final vm = await openSkeletal(tester);
    final picker = find.byKey(const ValueKey('skeletal_material_slot_0'));
    expect(picker, findsOneWidget);
    expect(tester.widget(picker), isA<AssetPickerSelect>());

    await tester.tap(picker);
    await settle(tester);
    expect(find.byKey(const ValueKey('skeletal_material_picker_0_search')), findsOneWidget);
    final materials = vm.availableMaterials;
    expect(rowKeys(tester, 'skeletal_material_picker_0').toSet(), {for (final m in materials) m.fileName},
        reason: 'one row per project material');
    final thumbs = popupThumbnails(tester);
    expect(thumbs, hasLength(materials.length));
    final withThumb = materials.where((m) => m.thumbnailBytes?.isNotEmpty ?? false).length;
    expect(withThumb, greaterThanOrEqualTo(faceMaterials.length));
    expect(thumbs.where((t) => t.bytes != null).length, withThumb, reason: 'every material with a thumbnail shows its image');

    await tester.enterText(find.byKey(const ValueKey('skeletal_material_picker_0_search')), 'eye');
    await settle(tester, 3);
    final eyeRows = rowKeys(tester, 'skeletal_material_picker_0').toList();
    expect(eyeRows.toSet(), {'M_Face_EyeShell.lmas', 'M_Face_Eyelashes_Lower.lmas', 'M_Face_Eyelashes_Upper.lmas'});

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await settle(tester);
    expect(find.byType(AssetPickerPopup), findsNothing, reason: 'Enter picks and closes');
    expect(vm.materialSlots[0].assignedMaterialPath, '$dir/contents/materials/face/${eyeRows.first}');
    // Finish file reads started under the fake clock.
    await drainRealIo(tester);
  });

  testWidgets('the closed control shows the pick; clear restores the mesh material; arrows move the highlight',
      (tester) async {
    final vm = await openSkeletal(tester);
    vm.assignMaterial(0,
        materialAssetPath: '$dir/contents/materials/face/M_Face_Skin.lmas', materialAssetId: 'M_Face_Skin');
    await settle(tester);
    final picker = find.byKey(const ValueKey('skeletal_material_slot_0'));
    expect(find.descendant(of: picker, matching: find.text('M_Face_Skin')), findsOneWidget);
    final valueThumb = tester.widget<AssetThumbnail>(
        find.descendant(of: picker, matching: find.byKey(const ValueKey('skeletal_material_picker_0_value_thumbnail'))));
    expect(valueThumb.bytes, isNotNull, reason: "the closed control shows the chosen material's thumbnail");

    // Down, Down, Enter: the third match of "face".
    await tester.tap(picker);
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('skeletal_material_picker_0_search')), 'face');
    await settle(tester, 3);
    final order = rowKeys(tester, 'skeletal_material_picker_0').toList();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester, 2);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(vm.materialSlots[0].assignedMaterialPath, endsWith('/${order[2]}'));

    await tester.tap(picker);
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('skeletal_material_picker_0_clear')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await settle(tester);
    expect(vm.materialSlots[0].isBound, isFalse, reason: '— clear — restores the mesh material');
    // Finish file reads started under the fake clock.
    await drainRealIo(tester);
  });

  testWidgets('Recently used lists the last picked assets first on the next open', (tester) async {
    final vm = await openSkeletal(tester);
    final picker = find.byKey(const ValueKey('skeletal_material_slot_1'));
    for (final pick in ['M_Body_Skin', 'M_Face_Eyelashes_Upper']) {
      await tester.tap(picker);
      await settle(tester);
      await tester.enterText(find.byKey(const ValueKey('skeletal_material_picker_1_search')), pick);
      await settle(tester, 2);
      await tester.tap(find.byKey(ValueKey('skeletal_material_picker_1_item_$pick.lmas')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await settle(tester);
    }
    expect(vm.materialSlots[1].assignedMaterialPath, endsWith('M_Face_Eyelashes_Upper.lmas'));
    await tester.tap(picker);
    await settle(tester);
    final recent = rowKeys(tester, 'skeletal_material_picker_1', kind: 'recent').toList();
    expect(recent.take(2), ['M_Face_Eyelashes_Upper.lmas', 'M_Body_Skin.lmas']);
    expect(find.text('RECENTLY USED'), findsOneWidget);
    final recentY = tester.getTopLeft(find.byKey(const ValueKey('skeletal_material_picker_1_recent_M_Face_Eyelashes_Upper.lmas'))).dy;
    final allY = tester.getTopLeft(find.text('ALL ASSETS')).dy;
    expect(recentY, lessThan(allY), reason: 'recents come first');
    // Finish file reads started under the fake clock.
    await drainRealIo(tester);
  });

  testWidgets('Browse to asset selects it in the Content Browser', (tester) async {
    bigView(tester);
    final project = LuminaProject.fromMap(
        Map<String, dynamic>.from(jsonDecode(File('$dir/$name.lmproject').readAsStringSync()) as Map));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false)
      ..refreshAssets();
    addTearDown(vm.dispose);
    final materials = vm.realAssets.where((a) => a.type == AssetType.filamat).toList();
    String? picked = 'contents/materials/face/M_Face_EyeShell.lmas';
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        // The scope MainEditorView provides.
        child: AssetPickerScope(
          changes: vm,
          latest: vm.latestAsset,
          requestThumbnail: vm.requestAssetThumbnail,
          browse: vm.browseToAsset,
          child: ListenableBuilder(
            listenable: vm,
            builder: (context, _) => Column(children: [
              SizedBox(
                width: 300,
                child: StatefulBuilder(
                  builder: (context, setState) => AssetPickerSelect(
                    keyPrefix: 'browse_probe',
                    assets: materials,
                    selectedPath: picked,
                    onSelected: (a) => setState(() => picked = a.relativePath),
                    onCleared: () => setState(() => picked = null),
                  ),
                ),
              ),
              Expanded(child: ContentBrowserWidget(viewModel: vm)),
            ]),
          ),
        ),
      ),
    ));
    await settle(tester);
    expect(vm.selectedFolder, 'contents');

    await tester.tap(find.byKey(const ValueKey('browse_probe_browse')));
    await settle(tester);
    expect(vm.selectedFolder, 'contents/materials/face');
    expect(vm.contentBrowserRevealPath, 'contents/materials/face/M_Face_EyeShell.lmas');
    expect(find.text('1 Selected'), findsOneWidget, reason: 'the Content Browser selected the asset');

    // The row context menu offers the same.
    vm.selectedFolder = 'contents';
    await tester.tap(find.byKey(const ValueKey('browse_probe_value')));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('browse_probe_search')), 'face_skin');
    await settle(tester, 2);
    await tester.tap(find.byKey(const ValueKey('browse_probe_item_M_Face_Skin.lmas')), buttons: kSecondaryButton);
    await settle(tester);
    await tester.tap(find.text('Browse to asset'));
    await settle(tester);
    expect(vm.contentBrowserRevealPath, 'contents/materials/face/M_Face_Skin.lmas');
    expect(vm.selectedFolder, 'contents/materials/face');
    // Finish file reads started under the fake clock.
    await drainRealIo(tester);
  });

  testWidgets('the Material editor texture parameter picker lists textures with their images and searches',
      (tester) async {
    if (!barrelGlb.existsSync()) return markTestSkipped('test-assets missing');
    bigView(tester);
    final material = AssetRepository()
        .scanProjectContents(dir)
        .firstWhere((a) => a.type == AssetType.filamat && a.relativePath.contains('fuel_barrel_red'));
    final vm = MaterialEditorViewModel(assetPath: material.lmasPath!);
    await tester.runAsync(vm.load);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: MaterialSubEditor(assetName: vm.asset!.name, viewModel: vm)),
    ));
    await settle(tester);
    final field = find.byKey(const ValueKey('texture_picker_baseColorMap'));
    expect(tester.widget(field), isA<AssetPickerSelect>());
    await tester.tap(field);
    await settle(tester);
    expect(find.byKey(const ValueKey('texture_picker_search')), findsOneWidget);
    final textures = vm.availableTextures;
    expect(rowKeys(tester, 'texture_picker'), hasLength(textures.length));
    expect(popupThumbnails(tester).where((t) => t.bytes != null), hasLength(textures.length),
        reason: 'every texture row shows the texture itself');
    final wanted = textures.first.fileName;
    await tester.enterText(find.byKey(const ValueKey('texture_picker_search')), wanted.replaceAll('.lmas', ''));
    await settle(tester, 3);
    expect(rowKeys(tester, 'texture_picker').toList(), [wanted], reason: 'the search narrows the list to the match');
    // Finish file reads started under the fake clock.
    await drainRealIo(tester);
  });

  testWidgets('the anim Blueprint state pose editor lists clips (and Blend Spaces) with search', (tester) async {
    bigView(tester);
    final vm = AnimBlueprintEditorViewModel(assetPath: '$dir/${LuminaThirdPersonContent.projectAnimBlueprintPath}');
    await tester.runAsync(vm.load);
    final state = vm.machine!.states.first.name;
    vm.setStatePose(state, LuminaAnimPose.clip(vm.clips.first));
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      // The anim Blueprint editor rebuilds the pose editor on every change.
      home: Scaffold(
        child: ListenableBuilder(listenable: vm, builder: (context, _) => AnimStatePoseEditor(viewModel: vm, state: state)),
      ),
    ));
    await settle(tester);
    final clipPicker = find.byKey(const ValueKey('pose_clip'));
    expect(tester.widget(clipPicker), isA<AssetPickerSelect>());
    await tester.tap(clipPicker);
    await settle(tester);
    expect(find.text('Search ${vm.clips.length} assets...'), findsOneWidget, reason: 'every clip of the target mesh');
    expect(rowKeys(tester, 'pose_clip'), isNotEmpty);
    await tester.enterText(find.byKey(const ValueKey('pose_clip_search')), 'walk_bwd');
    await settle(tester, 3);
    expect(rowKeys(tester, 'pose_clip').toSet(),
        {'Walk_Bwd_Loop.lmas', 'Walk_Bwd_Left_Loop.lmas', 'Walk_Bwd_Right_Loop.lmas'});
    await tester.tap(find.byKey(const ValueKey('pose_clip_item_Walk_Bwd_Left_Loop.lmas')));
    await settle(tester);
    expect(vm.machine!.state(state)!.pose.clip, 'Walk_Bwd_Left_Loop');

    vm.setStatePose(state, LuminaAnimPose.blendSpace(vm.blendSpacePaths.first, xVariable: ''));
    await settle(tester);
    expect(tester.widget(find.byKey(const ValueKey('pose_bs'))), isA<AssetPickerSelect>());
    // Finish file reads started under the fake clock.
    await drainRealIo(tester);
  });

  testWidgets("the particle editor's mesh picker lists meshes with thumbnails", (tester) async {
    if (!barrelGlb.existsSync()) return markTestSkipped('test-assets missing');
    bigView(tester);
    final effect = '$dir/contents/effects/PS_Sparks.lmas';
    Directory('$dir/contents/effects').createSync(recursive: true);
    File(effect).writeAsBytesSync(
        const LuminaAsset(assetId: 'PS_Sparks', name: 'PS_Sparks', type: AssetType.particle).toProtoBufferBytes());
    addTearDown(() => File(effect).deleteSync());
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: ParticleSubEditor(assetName: 'PS_Sparks', assetPath: effect, projectDirPath: dir)),
    ));
    await settle(tester);
    // The Render stage's accordion trigger opens its module on the right.
    await tester.tap(find.text('RENDER'));
    await settle(tester);
    final picker = find.byKey(const ValueKey('particle_mesh_select'));
    expect(tester.widget(picker), isA<AssetPickerSelect>());
    await tester.ensureVisible(picker);
    await tester.tap(picker);
    await settle(tester);
    final rows = rowKeys(tester, 'particle_mesh_picker').toList();
    expect(rows, contains('fuel_barrel_red.lmas'));
    final thumbs = popupThumbnails(tester);
    expect(thumbs.where((t) => t.bytes != null), isNotEmpty, reason: 'the imported barrel carries its mesh thumbnail');
    await tester.tap(find.byKey(const ValueKey('particle_mesh_picker_item_fuel_barrel_red.lmas')));
    await settle(tester);
    expect(find.descendant(of: picker, matching: find.text('fuel_barrel_red')), findsOneWidget);
    // Finish file reads started under the fake clock.
    await drainRealIo(tester);
  });

  testWidgets("a placed actor's Static Mesh property in the Details panel opens the same picker", (tester) async {
    if (!barrelGlb.existsSync()) return markTestSkipped('test-assets missing');
    bigView(tester);
    final project = LuminaProject.fromMap(
        Map<String, dynamic>.from(jsonDecode(File('$dir/$name.lmproject').readAsStringSync()) as Map));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false)
      ..refreshAssets();
    addTearDown(vm.dispose);
    final barrel = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName == 'fuel_barrel_red.lmas');
    await tester.runAsync(() => vm.spawnActorFromAsset(barrel));
    final actor = vm.actors.last;
    vm.selectActor(actor);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: ListenableBuilder(
          listenable: vm,
          builder: (context, _) => SizedBox(width: 420, child: DetailsWidget(viewModel: vm)),
        ),
      ),
    ));
    await settle(tester);
    final picker = find.byKey(const ValueKey('details_mesh_select'));
    expect(picker, findsOneWidget, reason: 'the Static Mesh row of a placed mesh');
    expect(tester.widget(picker), isA<AssetPickerSelect>());
    expect(find.descendant(of: picker, matching: find.text('fuel_barrel_red')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('details_mesh_value')));
    await settle(tester);
    expect(find.byKey(const ValueKey('details_mesh_search')), findsOneWidget);
    final rows = rowKeys(tester, 'details_mesh').toList();
    expect(rows, contains('fuel_barrel_red.lmas'));
    expect(rows, isNot(contains('SKM_Superhero_Female.lmas')), reason: 'static meshes only');
    expect(popupThumbnails(tester).where((t) => t.bytes != null), isNotEmpty);
    if (!acUnitGlb.existsSync()) return;

    // Swap to the AC unit: one undo step back to the barrel.
    await tester.enterText(find.byKey(const ValueKey('details_mesh_search')), 'ac_unit');
    await settle(tester, 2);
    await tester.tap(find.byKey(const ValueKey('details_mesh_item_ac_unit_a_300x300.lmas')));
    // The new geometry loads from disk.
    for (var i = 0; i < 50 && !(actor.meshAssetPath ?? '').endsWith('ac_unit_a_300x300.lmas'); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await settle(tester);
    expect(actor.meshAssetPath, endsWith('ac_unit_a_300x300.lmas'));
    expect(actor.meshData, isNotNull);
    expect(find.descendant(of: picker, matching: find.text('ac_unit_a_300x300')), findsOneWidget);
    vm.transactions.undo();
    await settle(tester);
    expect(actor.meshAssetPath, endsWith('fuel_barrel_red.lmas'));
    // Finish file reads started under the fake clock.
    await drainRealIo(tester);
  });

  testWidgets("a component's asset reference property uses the same picker, narrowed to its type",
      (tester) async {
    if (!barrelGlb.existsSync()) return markTestSkipped('test-assets missing');
    final project = LuminaProject.fromMap(
        Map<String, dynamic>.from(jsonDecode(File('$dir/$name.lmproject').readAsStringSync()) as Map));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false)
      ..refreshAssets();
    addTearDown(vm.dispose);
    Map<String, dynamic>? committed;
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: SizedBox(
          width: 320,
          child: AssetRefField(
            value: null,
            slotName: 'meshAsset',
            assetType: 'LuminaStaticMesh',
            viewModel: vm,
            onCommit: (v) => committed = v,
          ),
        ),
      ),
    ));
    expect(find.byType(AssetPickerSelect), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('asset_ref_meshAsset_value')));
    await settle(tester);
    final rows = rowKeys(tester, 'asset_ref_meshAsset').toList();
    expect(rows, contains('fuel_barrel_red.lmas'));
    expect(rows, everyElement(isNot(startsWith('M_'))), reason: 'static meshes only');
    await tester.tap(find.byKey(const ValueKey('asset_ref_meshAsset_item_fuel_barrel_red.lmas')));
    await settle(tester);
    expect(committed?['asset_path'], endsWith('fuel_barrel_red.lmas'));
    // Finish file reads started under the fake clock.
    await drainRealIo(tester);
  });

  testWidgets('500 assets open the popup in under 200 ms (lazy list)', (tester) async {
    final project = Directory('${root.path}/many')..createSync();
    final folder = Directory('${project.path}/contents/materials')..createSync(recursive: true);
    for (var i = 0; i < 500; i++) {
      File('${folder.path}/M_Synthetic_${i.toString().padLeft(3, '0')}.lmas')
          .writeAsStringSync(jsonEncode(LuminaAsset(assetId: 'm$i', name: 'M_Synthetic_$i', type: AssetType.filamat).toMap()));
    }
    final assets = AssetRepository().scanProjectContents(project.path);
    expect(assets, hasLength(500));
    Widget host(String prefix, List<RealAssetInfo> list) => ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: SizedBox(
              width: 300,
              child: AssetPickerSelect(keyPrefix: prefix, assets: list, selectedPath: null, onSelected: (_) {}),
            ),
          ),
        );
    // Warm-up: open and close the same popup on three assets first.
    // The first popup in a process JIT-compiles its code — a one-time cost
    // that does not depend on the list and that, when this test ran first in
    // its process (a sharded run) or on a loaded machine, ate the budget. The
    // stopwatch then times what the budget guards: opening on 500 assets.
    await tester.pumpWidget(host('warm', assets.take(3).toList()));
    await tester.tap(find.byKey(const ValueKey('warm_value')));
    await settle(tester, 2);
    expect(find.byKey(const ValueKey('warm_search')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester, 2);
    await tester.pumpWidget(host('many', assets));
    final watch = Stopwatch()..start();
    await tester.tap(find.byKey(const ValueKey('many_value')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    watch.stop();
    expect(find.byKey(const ValueKey('many_search')), findsOneWidget);
    expect(watch.elapsedMilliseconds, lessThan(200));
    expect(rowKeys(tester, 'many').length, lessThan(40), reason: 'only the visible rows are built');
    await tester.enterText(find.byKey(const ValueKey('many_search')), '499');
    await settle(tester, 2);
    expect(rowKeys(tester, 'many').toList(), ['M_Synthetic_499.lmas']);
    // Finish file reads started under the fake clock.
    await drainRealIo(tester);
  });

  test('no asset-picking Select remains without search and thumbnails (grep)', () {
    // Every file that picks project assets uses the shared picker.
    const migrated = [
      'lib/ui/core/property_editors/asset_ref_field.dart',
      'lib/ui/features/main_editor/views/import_target_skeleton_select.dart',
      'lib/ui/features/sub_editors/views/static_mesh_sub_editor.dart',
      'lib/ui/features/sub_editors/views/skeletal_mesh/material_slots_panel.dart',
      'lib/ui/features/sub_editors/view_models/material_graph_editor.dart',
      'lib/ui/features/sub_editors/views/material/parameter_panel.dart',
      'lib/ui/features/sub_editors/views/material/node_details_panel.dart',
      'lib/ui/features/sub_editors/views/particle/particle_sub_editor.dart',
      'lib/ui/features/sub_editors/views/animation_sub_editor.dart',
      'lib/ui/features/sub_editors/widgets/animation_retarget_modal.dart',
      'lib/ui/features/sub_editors/widgets/anim_blueprint_retarget_modal.dart',
      'lib/ui/features/sub_editors/views/anim_blueprint/state_pose_editor.dart',
      'lib/ui/features/sub_editors/views/anim_blueprint/anim_blueprint_sub_editor.dart',
      'lib/ui/features/sub_editors/views/anim_blueprint/create_anim_asset_dialog.dart',
      'lib/ui/features/sub_editors/views/physics_asset_sub_editor.dart',
      'lib/ui/features/sub_editors/views/environment_lighting_sub_editor.dart',
      'lib/ui/features/sub_editors/views/umg/slot_inspector.dart',
      'lib/ui/features/sub_editors/views/blueprint/pin_literal_editor.dart',
      'lib/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart',
    ];
    for (final f in migrated) {
      expect(librarySource(f), contains('AssetPickerSelect('), reason: f);
    }
    // The superseded widgets are gone.
    expect(File('lib/ui/features/sub_editors/widgets/lmas_asset_picker.dart').existsSync(), isFalse);
    expect(File('lib/ui/features/sub_editors/widgets/texture_picker.dart').existsSync(), isFalse);

    final assetHint = RegExp(r'realAssets|RealAssetInfo|\.lmasPath|availableMeshes|availableMaterials|availableTextures|'
        r'availableSkeletalMeshes|textureAssets|hdriAssets|vm\.clips|blendSpacePaths|skeletalMeshCandidates');
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final path = f.path.replaceAll(r'\', '/');
      if (path.endsWith('umg_widget_codegen.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!RegExp(r'\bSelect<\w+>\(').hasMatch(lines[i])) continue;
        if (lines[i].contains('Select<RealAssetInfo>')) offenders.add('$path:${i + 1}');
        final window = lines.skip(i).take(30).join('\n');
        final end = window.indexOf('.call,');
        if (assetHint.hasMatch(end < 0 ? window : window.substring(0, end))) offenders.add('$path:${i + 1}');
      }
    }
    expect(offenders, isEmpty);
  });
}
