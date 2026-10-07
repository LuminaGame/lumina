import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_asset_catalog.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_enum_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_modal.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/temp_project.dart';

/// A view model a tab's sub-editor created and disposed must not
/// stay bound to the tab, or a remounted editor (and MCP) adopts it.
void main() {
  late Directory root;
  late EditorViewModel vm;
  late String enumPath;

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumina_tab_remount_');
    const project = LuminaProject(projectName: 'Remount', activeLevel: 'contents/levels/L_Main.lmas');
    final dir = '${root.path}/Remount';
    Directory('$dir/contents/levels').createSync(recursive: true);
    File('$dir/Remount.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    enumPath = '$dir/${BlueprintAssetCatalog.writeEnum(dir, const LuminaBlueprintEnumDocument(name: 'E_DoorState', values: ['Closed', 'Open']))}';
    vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
  });

  tearDown(() async {
    vm.dispose();
    await deleteTempProject(root);
  });

  Widget tab() => ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SubEditorWorkspaceWidget(
            assetType: 'BlueprintEnum',
            assetName: 'E_DoorState.lmas',
            asset: RealAssetInfo(
              fileName: 'E_DoorState.lmas',
              relativePath: 'contents/enums/E_DoorState.lmas',
              type: AssetType.actor,
              bytes: File(enumPath).lengthSync(),
              lmasPath: enumPath,
            ),
            editorViewModel: vm,
            tabId: enumPath,
          ),
        ),
      );

  testWidgets('unmounting the tab\'s editor unbinds the view model it disposed; a remount binds a live one', (tester) async {
    await tester.pumpWidget(tab());
    await drainRealIo(tester);
    final first = vm.editorSessionFor(enumPath);
    expect(first, isA<BlueprintEnumViewModel>(), reason: 'the editor binds the view model it created');
    expect((first! as BlueprintEnumViewModel).values, ['Closed', 'Open']);

    // The tab stays open; only its widget goes (a rebuild that drops it).
    await tester.pumpWidget(const SizedBox());
    expect(vm.editorSessionFor(enumPath), isNull, reason: 'the disposed view model is no longer the tab\'s session');

    await tester.pumpWidget(tab());
    await drainRealIo(tester);
    final second = vm.editorSessionFor(enumPath);
    expect(second, isA<BlueprintEnumViewModel>());
    expect(identical(second, first), isFalse, reason: 'the remounted editor does not adopt the disposed view model');
    final live = second! as BlueprintEnumViewModel;
    expect(live.values, ['Closed', 'Open'], reason: 'the new view model loaded the asset');
    live.addValue('Opening');
    await tester.pump();
    expect(find.text('Opening'), findsOneWidget, reason: 'the editor listens to the live view model');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a view model the tab adopted (MCP\'s) stays bound when the editor unmounts', (tester) async {
    final agent = BlueprintEnumViewModel(assetPath: enumPath);
    addTearDown(agent.dispose);
    await tester.runAsync(agent.load);
    vm.bindTabSession(enumPath, notifier: agent, save: agent.save, isDirty: () => agent.isDirty);

    await tester.pumpWidget(tab());
    await drainRealIo(tester);
    expect(identical(vm.editorSessionFor(enumPath), agent), isTrue, reason: 'the editor adopts the bound view model');
    await tester.pumpWidget(const SizedBox());
    expect(identical(vm.editorSessionFor(enumPath), agent), isTrue, reason: 'its owner (MCP) keeps it bound');
  });
}
