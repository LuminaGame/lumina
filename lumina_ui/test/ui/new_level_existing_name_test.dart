import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/new_level_dialog.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// `File → New Level…` with the name of a level that already exists
/// overwrote that level's `.lmas` with the template, and the recorded undo then
/// deleted the file. Creating an asset must never replace an existing file
/// (no mocks: a real temp project, real level files).
void main() {
  late Directory tempDir;
  late Directory projDir;

  const project = LuminaProject(
    projectName: 'ExistingLevelGame',
    activeLevel: 'contents/levels/L_Main.lmas',
  );

  Future<EditorViewModel> openEditor() async {
    final vm = EditorViewModel(initialProject: project, projectLocation: tempDir.path, enableTimers: false);
    await vm.ensureDefaultLevelAssets();
    return vm;
  }

  File levelFile(String name) => File('${projDir.path}/contents/levels/$name.lmas');

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_new_level_existing_');
    projDir = Directory('${tempDir.path}/ExistingLevelGame')..createSync(recursive: true);
    Directory('${projDir.path}/contents/levels').createSync(recursive: true);
    File('${projDir.path}/ExistingLevelGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('New Level over an existing level name leaves that level untouched and records no undo', () async {
    final vm = await openEditor();
    addTearDown(vm.dispose);

    // A populated level the user already has.
    await vm.createLevelFromTemplate('L_Keep', kDefaultLevelTemplateId);
    final keep = levelFile('L_Keep');
    final bytesBefore = keep.readAsBytesSync();
    final actorsBefore = vm.actors.map((a) => a.name).toList();
    expect(actorsBefore, isNotEmpty);
    final undoLabelBefore = vm.transactions.undoLabel;

    await vm.createLevelFromTemplate('L_Keep', kEmptyLevelTemplateId);

    expect(keep.readAsBytesSync(), bytesBefore, reason: 'the existing level is byte-identical');
    expect(vm.project.activeLevel, 'contents/levels/L_Keep.lmas');
    expect(vm.actors.map((a) => a.name), actorsBefore, reason: 'the open level still shows its actors');
    expect(vm.transactions.undoLabel, undoLabelBefore, reason: 'a refused New Level records nothing');

    // Undo now reverts the first (real) New Level, which deletes only the file it created.
    vm.transactions.undo();
    expect(keep.existsSync(), isFalse);
    expect(levelFile('L_Main').existsSync(), isTrue, reason: 'the previously active level survives');
    expect(vm.project.activeLevel, 'contents/levels/L_Main.lmas');
  });

  test('New Asset never overwrites an existing NewAsset_N file', () async {
    final vm = await openEditor();
    addTearDown(vm.dispose);

    // Two New Assets, then the first is removed from disk: the asset count
    // drops by one, so the next auto-name (NewAsset_<count + 1>) is the
    // second one's name, which still holds real content.
    final n = vm.realAssets.length;
    await vm.createNewAsset(type: AssetType.particle, subFolder: 'particles');
    await vm.createNewAsset(type: AssetType.particle, subFolder: 'particles');
    File('${projDir.path}/contents/particles/NewAsset_${n + 1}.lmas').deleteSync();
    final occupied = File('${projDir.path}/contents/particles/NewAsset_${n + 2}.lmas');
    const original = '{"assetId":"keep_me","name":"Keep Me","type":"particle"}';
    occupied.writeAsStringSync(original);
    vm.refreshAssets();
    final next = vm.realAssets.length + 1;
    expect(next, n + 2, reason: 'the auto-name now points at the occupied file');

    await vm.createNewAsset(type: AssetType.particle, subFolder: 'particles');

    expect(occupied.readAsStringSync(), original, reason: 'the existing asset file is untouched');
    final created = Directory('${projDir.path}/contents/particles')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.startsWith('NewAsset_') && n != 'NewAsset_$next.lmas');
    expect(created, isNotEmpty, reason: 'the new asset got a free name instead');
  });

  testWidgets('the New Level dialog flags an existing name and disables Create', (tester) async {
    late EditorViewModel vm;
    await tester.runAsync(() async => vm = await openEditor());
    addTearDown(vm.dispose);
    final main = levelFile('L_Main');
    final bytesBefore = main.readAsBytesSync();

    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: MainEditorView(viewModel: vm),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    vm.commands.execute('file.newLevel', tester.element(find.byType(MainEditorView)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(NewLevelDialog), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('new_level_name')), 'L_Main');
    await tester.pump();

    expect(find.text('A level named L_Main already exists.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('new_level_create')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    }

    expect(find.byType(NewLevelDialog), findsOneWidget, reason: 'the dialog stays open');
    expect(main.readAsBytesSync(), bytesBefore, reason: 'L_Main is untouched');

    // A free name clears the message and creates normally.
    await tester.enterText(find.byKey(const ValueKey('new_level_name')), 'L_Fresh');
    await tester.pump();
    expect(find.text('A level named L_Main already exists.'), findsNothing);
  });
}
