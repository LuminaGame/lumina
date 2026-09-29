import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/outliner_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/scaffold_game_project.dart';
import '../helpers/temp_project.dart';

/// Content Browser: double-clicking a level asset opens that level (as File
/// → Open Level does) — the manifest's active level changes and the outliner
/// shows the level's actors.
void main() {
  late Directory root;
  late String dir;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_cb_open_level_');
    dir = await scaffoldGameProject(root, name: 'cb_level', widgetLibrary: 'flutter');
  });
  // The editor's git probe may still hold the folder on Windows.
  tearDownAll(() => deleteTempProject(root));

  testWidgets('double-clicking the second level makes it the active level and the outliner lists its actors', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final project = LuminaProject.fromMap(
        Map<String, dynamic>.from(jsonDecode(File('$dir/cb_level.lmproject').readAsStringSync()) as Map));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    final firstLevel = vm.project.activeLevel;
    final firstFile = File('$dir/$firstLevel');
    expect(firstFile.existsSync(), isTrue);

    // A second level file next to it, with one actor of its own.
    final secondMap = Map<String, dynamic>.from(jsonDecode(firstFile.readAsStringSync()) as Map);
    secondMap['name'] = 'L_Second';
    secondMap['metadata'] = {
      ...Map<String, dynamic>.from(secondMap['metadata'] as Map? ?? const {}),
      'actors': [
        {'id': 'act_second', 'name': 'SecondLevelCube', 'type': 'Mesh', 'location': [0.0, 0.0, 0.0]},
      ],
    };
    const secondLevel = 'contents/levels/L_Second.lmas';
    File('$dir/$secondLevel').writeAsStringSync(jsonEncode(secondMap));
    vm.refreshAssets();
    expect(vm.realAssets.where((a) => a.type == AssetType.level).length, greaterThanOrEqualTo(2));
    vm.selectedFolder = 'contents/levels';

    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: Row(children: [
          SizedBox(width: 1100, child: ContentBrowserWidget(viewModel: vm)),
          Expanded(child: OutlinerWidget(viewModel: vm)),
        ]),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    final card = find.byKey(const ValueKey('asset_item_$secondLevel'));
    expect(card, findsOneWidget);
    expect(find.text('SecondLevelCube'), findsNothing);

    await tester.tap(card);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(card);
    await tester.pump(const Duration(milliseconds: 400));

    expect(vm.project.activeLevel, secondLevel);
    expect(vm.actors.map((a) => a.name), ['SecondLevelCube']);
    expect(find.text('SecondLevelCube'), findsOneWidget, reason: 'the outliner shows the opened level');
    final manifest = LuminaProject.fromMap(
        Map<String, dynamic>.from(jsonDecode(File('$dir/cb_level.lmproject').readAsStringSync()) as Map));
    expect(manifest.activeLevel, secondLevel, reason: 'the manifest remembers the active level');
    vm.dispose();
  });
}
