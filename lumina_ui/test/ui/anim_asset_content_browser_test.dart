import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/anim_graph_asset_service.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/scaffold_game_project.dart';
import '../helpers/temp_project.dart';

/// Content Browser → New Asset → Animation →
/// Animation Blueprint / Blend Space asks for the target skeletal mesh,
/// writes the asset next to the mesh's clips and opens its editor tab.
void main() {
  late Directory root;
  late String dir;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_anim_assets_cb_');
    dir = await scaffoldGameProject(root, name: 'anim_cb', widgetLibrary: 'flutter');
  });
  // The editor's git probe may still hold the folder on Windows.
  tearDownAll(() => deleteTempProject(root));

  for (final (label, type, category, prefix) in [
    ('Animation → Animation Blueprint (.lmas)', AssetType.animBlueprint, 'AnimBlueprint', 'ABP_'),
    ('Animation → Blend Space (.lmas)', AssetType.blendSpace, 'BlendSpace', 'BS_'),
  ]) {
    testWidgets('New Asset → $label creates the asset for Quinn and opens it', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final project = LuminaProject.fromMap(
          Map<String, dynamic>.from(jsonDecode(File('$dir/anim_cb.lmproject').readAsStringSync()) as Map));
      final vm = EditorViewModel(
          initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
      expect(vm.projectDirPath, dir);
      vm.refreshAssets();
      await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: ContentBrowserWidget(viewModel: vm))));
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Asset').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text(type == AssetType.animBlueprint ? 'New Animation Blueprint' : 'New Blend Space'), findsOneWidget);
      expect(find.text('Target Skeletal Mesh'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('anim_asset_create')));
      await tester.pumpAndSettle();

      final tab = vm.openTabs.last;
      expect(tab.category, category);
      final asset = tab.asset!;
      expect(asset.type, type);
      expect(asset.fileName, startsWith(prefix));
      expect(asset.relativePath, startsWith('contents/animations/SKM_Superhero_Female/'));
      expect(AnimGraphAssetService.blendSpaceTarget(dir, asset.relativePath),
          LuminaThirdPersonContent.projectMeshAssetPath);
      expect(File('$dir/${asset.relativePath}').existsSync(), isTrue);
      vm.dispose();
    });
  }
}
