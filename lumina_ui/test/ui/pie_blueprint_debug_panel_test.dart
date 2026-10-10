import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/pie_blueprint_debug_panel.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_debugger.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/scaffold_game_project.dart';
import '../helpers/temp_project.dart';

/// The PIE Blueprint debug panel loads the debugged pawn's graph in the
/// background; stopping Play before that load finishes drops the graph
/// quietly — the half-loaded view model is not notified after it was
/// disposed.
void main() {
  late Directory root;
  late String dir;
  const name = 'pie_debug_panel';

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_pie_debug_panel_');
    dir = await scaffoldGameProject(root, name: name, widgetLibrary: 'flutter');
  });
  tearDownAll(() => deleteTempProject(root));
  tearDown(() {
    BlueprintPieDebugger.instance.clear();
    LuminaBlueprintActorClasses.clear();
  });

  LuminaProject manifest() =>
      LuminaProject.fromMap(Map<String, dynamic>.from(jsonDecode(File('$dir/$name.lmproject').readAsStringSync()) as Map));

  testWidgets('stopping Play while the panel still loads the pawn graph drops it without notifying a disposed view model',
      (tester) async {
    final vm = EditorViewModel(initialProject: manifest(), projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    addTearDown(vm.dispose);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    vm.refreshAssets();

    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: PieBlueprintDebugPanel(viewModel: vm))));

    expect(await tester.runAsync(vm.requestPlay), isTrue, reason: '${vm.playBlockers}');
    final pie = vm.pieController;
    pie.startHeadlessForTest(LuminaWorld());
    expect(BlueprintPieDebugger.instance.targets, isNotEmpty, reason: 'the Third Person pawn is a Blueprint');
    final panel = tester.state<PieBlueprintDebugPanelState>(find.byType(PieBlueprintDebugPanel));
    expect(panel.graphViewModel, isNotNull, reason: 'the panel started loading the pawn graph');

    // Stop before the read completes, then let it complete.
    pie.stopHeadlessForTest();
    vm.stopSimulation();
    expect(panel.graphViewModel, isNull);
    await drainRealIo(tester);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Press Play'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await drainRealIo(tester);
  });
}
