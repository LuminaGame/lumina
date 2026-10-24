import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/tab_bar_actions.dart';
import 'package:lumina_ui/ui/core/widgets/typed_tab_bar.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/static_mesh_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/temp_project.dart';

/// A sub-editor's toolbar: on its own it is the editor's row; in a
/// workspace tab its controls sit at the right end of the tab bar (the tab
/// already names the asset and closes it), so the editor's islands start
/// right under the tabs.
void main() {
  Future<void> settle(WidgetTester tester, {int frames = 20}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('on its own the toolbar is a row with the title, the controls and the close button', (tester) async {
    var closed = false;
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: Column(children: [
          SubEditorToolbar(children: [
            const SubEditorToolbarTitle(child: Text('SM_Barrel')),
            const Spacer(),
            PrimaryButton(key: const ValueKey('save'), onPressed: () {}, child: const Text('Save')),
            SubEditorToolbarClose(child: GhostButton(onPressed: () => closed = true, child: const Icon(LucideIcons.x))),
          ]),
        ]),
      ),
    ));
    expect(find.text('SM_Barrel'), findsOneWidget);
    expect(tester.getSize(find.byType(SubEditorToolbar)).height, 38);
    await tester.tap(find.byIcon(LucideIcons.x));
    expect(closed, isTrue);
  });

  testWidgets('in a workspace tab the Static Mesh actions sit in the tab bar, only while its tab is active', (tester) async {
    final barrel = File('${Directory.current.parent.path}/test-assets/Props/Barrels/fuel_barrel_red.glb');
    if (!barrel.existsSync()) return markTestSkipped('test-assets/Props/Barrels missing');
    final root = Directory.systemTemp.createTempSync('lumina_tab_actions_');
    addTearDown(() => deleteTempProject(root));
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late EditorViewModel vm;
    late RealAssetInfo mesh;
    await tester.runAsync(() async {
      Directory('${root.path}/TabGame/contents/levels').createSync(recursive: true);
      vm = EditorViewModel(
        initialProject: const LuminaProject(projectName: 'TabGame', activeLevel: 'contents/levels/L_Main.lmas'),
        projectLocation: root.path,
        enableTimers: false,
        autoInitAssets: false,
      );
      await vm.processImportPipeline(sourceFilePath: barrel.path);
      vm.refreshAssets();
      mesh = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh);
    });
    addTearDown(vm.dispose);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: MainEditorView(viewModel: vm))));
    await settle(tester);

    final bar = find.byType(EditorTypedTabBar);
    Finder inBar(Finder f) => find.descendant(of: bar, matching: f);
    expect(inBar(find.text('Save')), findsNothing, reason: 'the level tab publishes no toolbar');

    vm.openSubEditorTab('Mesh', asset: mesh);
    // The editor reads its asset from disk before it shows its toolbar.
    await drainRealIoUntil(tester, () => find.byKey(const ValueKey('static_mesh_island_lods')).evaluate().isNotEmpty);
    await settle(tester);
    expect(find.byType(StaticMeshSubEditor), findsOneWidget);
    expect(inBar(find.text('Save')), findsOneWidget, reason: 'the Static Mesh Save button is in the tab bar');
    expect(inBar(find.textContaining('Forced LOD')), findsOneWidget, reason: 'every control comes along');
    expect(find.text('STATIC MESH'), findsNothing, reason: 'the tab names the asset: no type badge');
    // The islands start right under the tab bar: no toolbar row between.
    final lods = tester.getRect(find.byKey(const ValueKey('static_mesh_island_lods')));
    expect(lods.top - tester.getRect(bar).bottom, lessThanOrEqualTo(10));

    // The tab bar's Save saves the mesh.
    final saveButton = inBar(find.text('Save'));
    expect(saveButton.hitTestable(), findsOneWidget);

    vm.selectTab(0);
    await settle(tester);
    expect(inBar(find.text('Save')), findsNothing, reason: 'the level tab shows its own (no) actions');
    vm.selectTab(1);
    await settle(tester);
    expect(inBar(find.text('Save')), findsOneWidget);
  });
}
