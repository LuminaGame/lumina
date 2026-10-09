import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Get Player Character wired into Set Show Mouse Cursor's Target compiles,
/// and Compiler Results tells the user the Character's controller is used.
void main() {
  late Directory tempProject;

  setUp(() {
    tempProject = Directory.systemTemp.createTempSync('bp_ctrl_target_');
    Directory('${tempProject.path}/lib/actors').createSync(recursive: true);
    File('${tempProject.path}/my_project.lmproject').writeAsStringSync('{}');
  });

  tearDown(() {
    if (tempProject.existsSync()) tempProject.deleteSync(recursive: true);
  });

  testWidgets('a Character Target shows a warning row in Compiler Results', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final assetFile = File('${tempProject.path}/contents/blueprints/BP_Toggle.lmas');
    assetFile.parent.createSync(recursive: true);
    final vm = BlueprintEditorViewModel(
      assetPath: assetFile.path,
      initialAsset: LuminaAsset(assetId: 'BP_Toggle', name: 'BP_Toggle', type: AssetType.actor),
    );
    final begin = vm.addGraphNode('event_beginplay', const Offset(40, 40))!;
    final character = vm.addGraphNode('get_player_character', const Offset(40, 200))!;
    final cursor = vm.addGraphNode('set_show_mouse_cursor', const Offset(300, 40))!;
    vm.addGraphWire(fromNodeId: begin.id, fromPinId: 'exec_out', toNodeId: cursor.id, toPinId: 'exec_in');
    vm.addGraphWire(fromNodeId: character.id, fromPinId: 'return_value', toNodeId: cursor.id, toPinId: 'target');

    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: BlueprintSubEditor(assetName: 'BP_Toggle', assetPath: assetFile.path, viewModel: vm)),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    late bool ok;
    await tester.runAsync(() async => ok = await vm.compile());
    await tester.pump(const Duration(milliseconds: 100));

    expect(ok, isTrue, reason: vm.diagnostics.join('\n'));
    expect(find.text('0 error(s), 1 warning(s).'), findsOneWidget);
    expect(find.textContaining('it acts on the Player Controller that possesses it'), findsOneWidget);
  });
}
