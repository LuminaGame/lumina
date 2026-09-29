import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/temp_project.dart';

/// The Content Browser's Delete moves assets to the
/// project trash (`.lumina/trash`) as one undo step.
void main() {
  final glb = File('${Directory.current.parent.path}/test-assets/Props/Barrels/fuel_barrel_red.glb');

  testWidgets('deleting an imported barrel trashes its files; Edit → Undo restores them byte-identical and the actor', (tester) async {
    if (!glb.existsSync()) return markTestSkipped('test-assets not present');
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final root = Directory.systemTemp.createTempSync('cb_trash_');
    final projectDir = Directory('${root.path}/TrashGame')..createSync();
    const project = LuminaProject(projectName: 'TrashGame', activeLevel: 'contents/levels/L_Main.lmas');
    File('${projectDir.path}/TrashGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false)
      ..showAllAssets = true;
    addTearDown(() => deleteTempProject(root));

    await tester.runAsync(() async {
      await vm.ensureDefaultLevelAssets();
      await vm.processImportPipeline(sourceFilePath: glb.path);
    });
    final mesh = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains('fuel_barrel_red'));
    await tester.runAsync(() => vm.spawnActorFromAsset(mesh, location: const [0.0, 0.0, 0.0]));
    final actorId = vm.actors.last.id;
    final lmas = File(mesh.lmasPath!);
    final lmasBytes = lmas.readAsBytesSync();
    final historyBefore = vm.transactions.history(limit: 200).length;

    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: SizedBox(width: 1200, height: 600, child: ContentBrowserWidget(viewModel: vm))),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(ValueKey('asset_item_${mesh.relativePath}')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.textContaining('Delete (1)'));
    await tester.pump(const Duration(milliseconds: 200));
    final note = tester.widget<Text>(find.byKey(const ValueKey('delete_dialog_trash_note')));
    expect(note.data, contains('project trash'));
    expect(note.data, contains('Edit → Undo'));
    await tester.tap(find.text('Delete Selected'));
    await drainRealIo(tester);

    expect(lmas.existsSync(), isFalse);
    expect(vm.actors.any((a) => a.id == actorId), isFalse);
    final entries = vm.projectTrash.list();
    expect(entries, hasLength(1));
    final entryDir = Directory('${vm.projectDirPath}/.lumina/trash/${entries.single.id}');
    final manifest = jsonDecode(File('${entryDir.path}/manifest.json').readAsStringSync()) as Map;
    for (final f in (manifest['files'] as List).cast<Map>()) {
      expect(sha256.convert(File('${entryDir.path}/${f['stored']}').readAsBytesSync()).toString(), f['sha256']);
    }
    expect(vm.transactions.history(limit: 200).length, historyBefore + 1, reason: 'one undo step');
    expect(tester.widget<Text>(find.byKey(const ValueKey('delete_trash_toast'))).data, contains(entries.single.id));

    expect(vm.commands.execute('edit.undo'), isTrue);
    await tester.pump();
    expect(lmas.readAsBytesSync(), lmasBytes);
    expect(vm.actors.any((a) => a.id == actorId), isTrue, reason: 'the same actor id');
    expect(vm.projectTrash.list(), isEmpty);

    await tester.pump(const Duration(seconds: 10)); // the toast times out
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
}
