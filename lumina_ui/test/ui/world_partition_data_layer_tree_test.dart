import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Data layers nest like outliner folders: a child sits under its parent,
/// a collapsed parent hides its subtree, removing a parent removes the
/// subtree, and a long list scrolls inside a 200 px box.
void main() {
  late Directory tempDir;
  late Directory projDir;
  const project = LuminaProject(projectName: 'WpTree', activeLevel: 'contents/levels/L_Main.lmas');

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_wp_tree_');
    projDir = Directory('${tempDir.path}/WpTree')..createSync(recursive: true);
    Directory('${projDir.path}/contents/levels').createSync(recursive: true);
    File('${projDir.path}/WpTree.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    addTearDown(() => tempDir.deleteSync(recursive: true));
  });

  EditorViewModel makeEditor() => EditorViewModel(
        initialProject: project,
        projectLocation: tempDir.path,
        enableTimers: false,
        autoInitAssets: false,
      )..setWorldPartitionEnabled(true);

  test('layers nest, keep tree order, rename follows, and a parent takes its subtree along', () {
    final vm = makeEditor();
    addTearDown(vm.dispose);
    final world = vm.addWorldPartitionDataLayer('World');
    final props = vm.addWorldPartitionDataLayer('Props');
    final interiors = vm.addWorldPartitionDataLayer('Interiors', world);
    final rooms = vm.addWorldPartitionDataLayer('Rooms', interiors);
    expect(vm.worldPartitionDataLayers.map((l) => l['name']), ['World', 'Interiors', 'Rooms', 'Props'],
        reason: 'children follow their parent, before the next root');
    expect(vm.worldPartitionDataLayers[1]['parent'], 'World');
    expect(vm.worldPartitionDataLayers[2]['parent'], 'Interiors');
    expect(vm.worldPartitionDataLayerRows.map((r) => (r.depth, r.hasChildren)), [(0, true), (1, true), (2, false), (0, false)]);

    vm.setWorldPartitionDataLayerName(0, 'Level');
    expect(vm.worldPartitionDataLayers[1]['parent'], 'Level', reason: 'children point at the new name');

    vm.toggleWorldPartitionDataLayerExpanded('Level');
    expect(vm.worldPartitionDataLayerRows.map((r) => r.index), [0, 3], reason: 'a collapsed parent hides its subtree');
    vm.toggleWorldPartitionDataLayerExpanded('Level');

    vm.setWorldPartitionDataLayerParent(0, interiors);
    expect(vm.worldPartitionDataLayers[0]['parent'], isNull, reason: 'a layer cannot move under its own descendant');
    vm.setWorldPartitionDataLayerParent(3, 'Level');
    expect(vm.worldPartitionDataLayers.firstWhere((l) => l['name'] == props)['parent'], 'Level');

    vm.removeWorldPartitionDataLayer(1);
    expect(vm.worldPartitionDataLayers.map((l) => l['name']), ['Level', 'Props'], reason: 'Interiors took Rooms with it');
    expect(rooms, 'Rooms');
  });

  testWidgets('the Details tree shows depth, folds a parent and stays 200 px tall for many layers', (tester) async {
    final vm = makeEditor();
    addTearDown(vm.dispose);
    for (var i = 0; i < 14; i++) {
      vm.addWorldPartitionDataLayer('Layer$i');
    }
    vm.addWorldPartitionDataLayer('Child', 'Layer0');
    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: SizedBox(width: 420, height: 900, child: DetailsWidget(viewModel: vm)),
      ),
    );
    await tester.pumpAndSettle();
    final box = tester.getSize(find.byKey(const ValueKey('wp_layers_list')));
    expect(box.height, 200, reason: 'fifteen rows of 24 px are clipped to the box and scroll');
    expect(find.byKey(const ValueKey('wp_layer_chevron_0')), findsOneWidget, reason: 'Layer0 has a child');
    expect(find.byKey(const ValueKey('wp_layer_chevron_1')), findsNothing);
    final childRow = find.byKey(const ValueKey('wp_layer_name_1'));
    expect(childRow, findsOneWidget, reason: 'the child is the second entry, right after its parent');
    final parentX = tester.getTopLeft(find.byKey(const ValueKey('wp_layer_name_0'))).dx;
    expect(tester.getTopLeft(childRow).dx, greaterThan(parentX), reason: 'indented by one step');
    await tester.tap(find.byKey(const ValueKey('wp_layer_chevron_0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wp_layer_name_1')), findsNothing, reason: 'folded away');
    await tester.tap(find.byKey(const ValueKey('wp_layer_add_child_2')));
    await tester.pumpAndSettle();
    expect(vm.worldPartitionDataLayers.where((l) => l['parent'] == 'Layer1'), hasLength(1));
  });
}
