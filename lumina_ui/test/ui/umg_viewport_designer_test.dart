import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/umg_widget_codegen.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/umg_viewport_preview.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/widget_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/scaffold_game_project.dart';
import '../helpers/temp_project.dart';

Directory get _assets => Directory(Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets');

/// The Viewport element in the UMG designer: in the palette's 3D category,
/// its Details (background, interaction, the design-time preview mesh picked
/// with the asset picker) saved in the widget, a live preview on the canvas,
/// and the generated widget class rendering `LuminaUmgViewport` in a game
/// that analyzes clean.
void main() {
  late Directory tempDir;
  late String projectDir;
  late String lmasPath;
  final barrel = File('${_assets.path}/Props/Barrels/fuel_barrel_red.glb');

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('umg_viewport_');
    projectDir = '${tempDir.path}/ShopProject';
    Directory('$projectDir/lib').createSync(recursive: true);
    File('$projectDir/ShopProject.lmproject').writeAsStringSync(jsonEncode(
      const LuminaProject(projectName: 'ShopProject', activeLevel: 'contents/levels/L_Main.lmas').toMap(),
    ));
    await AssetRepository().createAsset(projectPath: projectDir, subFolder: 'widgets', fileName: 'WBP_Shop.lmas', type: AssetType.widget);
    lmasPath = '$projectDir/contents/widgets/WBP_Shop.lmas';
    if (barrel.existsSync()) {
      // A static mesh as an import writes it: the .lmas with its GLB payload
      // and the .entity.glb companion.
      final glb = barrel.readAsBytesSync();
      final mesh = File('$projectDir/contents/meshes/static/SM_Barrel.lmas')..parent.createSync(recursive: true);
      mesh.writeAsBytesSync(LuminaAsset(assetId: 'barrel', name: 'SM_Barrel', type: AssetType.filamesh, rawPayload: glb, metadata: const {
        'payload_format': 'glb',
      }).toProtoBufferBytes());
      File('$projectDir/contents/meshes/static/SM_Barrel.entity.glb').writeAsBytesSync(glb);
    }
    LuminaAssets.projectDir = projectDir;
  });

  tearDown(() async {
    LuminaAssets.projectDir = null;
    LuminaViewportBudget.shared.reset();
    await deleteTempProject(tempDir);
  });

  Future<void> settle(WidgetTester tester, [int n = 10]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<UmgEditorViewModel> pumpEditor(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final vm = UmgEditorViewModel(assetPath: lmasPath);
    await tester.runAsync(() => vm.load());
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: UMGWidgetSubEditor(assetName: 'WBP_Shop', assetPath: lmasPath, viewModel: vm)),
    ));
    await settle(tester, 4);
    return vm;
  }

  Map<String, dynamic> savedProps(String nodeId) {
    final asset = LuminaAsset.fromBytes(File(lmasPath).readAsBytesSync());
    final doc = jsonDecode(utf8.decode(asset.rawPayload!)) as Map;
    Map? find(Map node) {
      if (node['id'] == nodeId) return node;
      for (final c in node['children'] as List? ?? const []) {
        final hit = find(c as Map);
        if (hit != null) return hit;
      }
      return null;
    }

    return Map<String, dynamic>.from(find(doc['root'] as Map)!['props'] as Map);
  }

  testWidgets('the Viewport sits in the 3D palette; its Details edit background, interaction and the preview mesh', (tester) async {
    if (!barrel.existsSync()) return markTestSkipped('test-assets missing');
    final vm = await pumpEditor(tester);
    expect(find.byKey(const ValueKey('umg_palette_category_3d')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('umg_palette_category_3d')), matching: find.text('Viewport')), findsOneWidget);
    expect(UmgWidgetType.viewport.category, UmgWidgetCategory.threeD);
    expect(UmgWidgetType.viewport.capacity, UmgChildCapacity.none);
    expect(UmgWidgetType.viewport.availableEvents, LuminaWidgetEvents.viewportEvents);

    final viewport = vm.addWidget(UmgWidgetType.viewport, parentId: vm.document.root.id, canvasPosition: const Offset(60, 60))!;
    vm.refreshTextures();
    vm.select(viewport.id);
    await settle(tester, 4);

    // Background: transparent.
    await tester.ensureVisible(find.byKey(ValueKey('umg_viewport_background_${viewport.id}')));
    await tester.tap(find.byKey(ValueKey('umg_viewport_background_${viewport.id}')));
    await settle(tester, 3);
    await tester.tap(find.text('transparent').last);
    await settle(tester, 3);
    expect(vm.document.findNode(viewport.id)!.props['background'], 'transparent');

    // Interaction: no pan.
    await tester.ensureVisible(find.byKey(ValueKey('umg_viewport_pan_${viewport.id}')));
    await tester.tap(find.byKey(ValueKey('umg_viewport_pan_${viewport.id}')));
    await settle(tester, 2);
    expect(vm.document.findNode(viewport.id)!.props['pan'], isFalse);

    // The design-time preview mesh, from the asset picker.
    final prefix = 'umg_viewport_previewMesh_${viewport.id}';
    await tester.ensureVisible(find.byKey(ValueKey('${prefix}_value')));
    await tester.tap(find.byKey(ValueKey('${prefix}_value')));
    await settle(tester, 3);
    // The dropdown opens under the control, at the bottom of the Details
    // column: press the item through its Clickable.
    tester.widget<Clickable>(find.byKey(ValueKey('${prefix}_item_SM_Barrel.lmas'))).onPressed!();
    await settle(tester, 3);
    expect(vm.document.findNode(viewport.id)!.props['previewMesh'], 'contents/meshes/static/SM_Barrel.lmas');

    // The canvas previews it live.
    final design = umgViewportDesignScene(vm.document.findNode(viewport.id)!.props);
    final scene = LuminaViewportScene(design);
    expect(scene.nodes.single['asset'], 'contents/meshes/static/SM_Barrel.lmas');
    expect(scene.environment['mode'], 'transparent');
    expect(scene.interaction['pan'], isFalse);
    expect(find.byKey(ValueKey('umg_rt_viewport_${viewport.id}')), findsOneWidget);

    expect(await tester.runAsync(() => vm.save()), isTrue);
    final saved = savedProps(viewport.id);
    expect(saved['background'], 'transparent');
    expect(saved['pan'], isFalse);
    expect(saved['previewMesh'], 'contents/meshes/static/SM_Barrel.lmas');
    await tester.pumpWidget(const SizedBox());
    await drainRealIo(tester);
  });

  test('the generated widget renders LuminaUmgViewport with the Details and routes bound events to the graph', () {
    final doc = UmgDocument.createDefault();
    final viewport = UmgNode.create(UmgWidgetType.viewport, name: 'Preview', id: 'v1');
    viewport.props
      ..['background'] = 'color'
      ..['renderScale'] = 0.5
      ..['autoRotate'] = 15.0;
    viewport.events.add(const UmgEvent(name: 'OnPicked', handler: 'onPickedPreview'));
    doc.root.children.add(viewport);
    for (final library in [kUmgWidgetLibraryFlutter, kUmgWidgetLibraryShadcn]) {
      final code = UmgWidgetCodegen.generateWidgetDart(doc, assetName: 'WBP_Shop', library: library);
      expect(code, contains('LuminaUmgViewport('), reason: library);
      expect(code, contains("name: 'Preview',"), reason: library);
      expect(code, contains("background: 'color',"), reason: library);
      expect(code, contains('renderScale: 0.5,'), reason: library);
      expect(code, contains('autoRotate: 15.0,'), reason: library);
      expect(code, contains('void _onPickedPreview(Map<String, Object?> args) {'), reason: library);
      expect(code, contains("case 'OnPicked':"), reason: library);
      expect(code, contains('LuminaUmgViewport, LuminaUserWidgets'), reason: library);
    }
    final widgetClass = UmgWidgetCodegen.widgetClassFor(doc, 'WBP_Shop');
    expect(widgetClass.elements.single.typeName, 'viewport');
  });

  test('a game with a Viewport widget analyzes clean', () async {
    final root = Directory.systemTemp.createTempSync('lumina_umg_vp_');
    addTearDown(() => root.deleteSync(recursive: true));
    final project = await scaffoldGameProject(root, name: 'umg_viewport', widgetLibrary: kUmgWidgetLibraryFlutter);
    final doc = UmgDocument.createDefault();
    final viewport = UmgNode.create(UmgWidgetType.viewport, name: 'Preview', id: 'v1');
    viewport.events.add(const UmgEvent(name: 'OnCameraChanged', handler: 'onCameraChangedPreview'));
    doc.root.children.add(viewport);
    final result = await UmgWidgetCodegen.compileAndWrite(projectPath: project, assetName: 'WBP_Shop', document: doc);
    expect(result.written, isTrue);
    expect(result.source, contains('LuminaUmgViewport('));
    final analysis = await analyzeGameProject(project);
    expect(analysis.exitCode, 0, reason: '${analysis.stdout}${analysis.stderr}');
  }, timeout: const Timeout(Duration(minutes: 4)));
}
