import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/anim_graph_asset_service.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/scaffold_game_project.dart';
import '../helpers/temp_project.dart';

/// An authored Animation Sequence is a clip in its skeletal mesh's GLB plus an
/// animation `.lmas`: undoing its creation, trashing it and restoring it move
/// the clip out of and back into the mesh together with the `.lmas`, and leave
/// the other sequences on that mesh alone.
void main() {
  const meshRel = LuminaThirdPersonContent.projectMeshAssetPath;

  Future<(String, EditorViewModel)> openProject(WidgetTester tester, String name) async {
    final root = Directory.systemTemp.createTempSync('lumina_seq_trash_');
    addTearDown(() => deleteTempProject(root));
    final dir = (await tester.runAsync(() => scaffoldGameProject(root, name: name, widgetLibrary: 'flutter')))!;
    final project =
        LuminaProject.fromMap(Map<String, dynamic>.from(jsonDecode(File('$dir/$name.lmproject').readAsStringSync()) as Map));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    addTearDown(vm.dispose);
    vm.refreshAssets();
    return (dir, vm);
  }

  Uint8List meshGlb(String dir) => AnimationImportBinder.meshGlb('$dir/$meshRel')!;

  /// The mesh's clips as its `.lmas` lists them and as its GLB holds them.
  List<List<String>> clipsOf(String dir) {
    final listed = LuminaAsset.fromBytes(File('$dir/$meshRel').readAsBytesSync()).metadata['animation_clips'] ?? '';
    return [listed.isEmpty ? <String>[] : listed.split(','), GlbAnimationMerger.animationNames(meshGlb(dir))];
  }

  /// [clip]'s channels in the mesh GLB: node, path, times and values.
  Future<List<String>> channelsOf(WidgetTester tester, String dir, String clip) async {
    final mesh = (await tester.runAsync(() => GlbParserService.parseGlb(meshGlb(dir))))!;
    final anim = mesh.animations.firstWhere((a) => a.name == clip);
    return [for (final c in anim.channels) '${c.nodeName}/${c.path}/${c.interpolation}/${c.keyframeTimes}/${c.values}'];
  }

  testWidgets('undoing a sequence created in the Content Browser takes its clip out of the mesh; redo puts it back',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (dir, vm) = await openProject(tester, 'seq_undo');
    final glbBefore = meshGlb(dir);
    final clipsBefore = clipsOf(dir);
    expect(clipsBefore[0], isNotEmpty, reason: 'the template character has its own clips');

    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: ContentBrowserWidget(viewModel: vm))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Asset').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Animation → Animation Sequence (.lmas)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('anim_asset_name')), 'Wave');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('anim_asset_create')));
    await tester.pumpAndSettle();

    const rel = 'contents/animations/SKM_Superhero_Female/Wave.lmas';
    expect(File('$dir/$rel').existsSync(), isTrue);
    final glbCreated = meshGlb(dir);
    expect(clipsOf(dir)[0], [...clipsBefore[0], 'Wave']);
    expect(clipsOf(dir)[1], [...clipsBefore[1], 'Wave']);
    final channels = await channelsOf(tester, dir, 'Wave');
    expect(vm.transactions.canUndo, isTrue, reason: 'creating the sequence is an undo step');

    vm.transactions.undo();
    await tester.pumpAndSettle();
    expect(File('$dir/$rel').existsSync(), isFalse, reason: 'the .lmas is in the trash');
    expect(clipsOf(dir), clipsBefore, reason: 'the clip leaves the mesh GLB and its animation_clips');
    expect(meshGlb(dir).length, lessThanOrEqualTo(glbBefore.length), reason: 'the clip\'s data leaves the GLB too');

    vm.transactions.redo();
    await tester.pumpAndSettle();
    expect(File('$dir/$rel').existsSync(), isTrue);
    expect(clipsOf(dir)[0], [...clipsBefore[0], 'Wave']);
    expect(clipsOf(dir)[1], [...clipsBefore[1], 'Wave']);
    expect(await channelsOf(tester, dir, 'Wave'), channels);
    expect(meshGlb(dir).length, glbCreated.length);
    expect(AuthoredAnimationStore.load(dir, rel)!.name, 'Wave');
    await tester.pumpWidget(const SizedBox());
    await drainRealIo(tester);
  });

  testWidgets('trashing one of two sequences on a mesh keeps the other; undo and restore bring it back in place',
      (tester) async {
    final (dir, vm) = await openProject(tester, 'seq_trash');
    final clipsBefore = clipsOf(dir);
    final glbBefore = meshGlb(dir);

    // Two sequences with keys of their own.
    String make(String name, double angle) {
      final rel = AnimGraphAssetService.createAnimationSequence(dir, name: name, meshRelPath: meshRel, lengthFrames: 30);
      final clip = AuthoredAnimationStore.load(dir, rel)!;
      clip.setKey('upperarm_r', AuthoredChannel.rotation, 30, [math.sin(angle / 2), 0, 0, math.cos(angle / 2)]);
      AuthoredAnimationStore.save(projectDir: dir, animationRelPath: rel, clip: clip);
      return rel;
    }

    final relA = make('SwingA', 0.4);
    final relB = make('SwingB', 0.8);
    vm.refreshAssets();
    final both = clipsOf(dir);
    expect(both[1], [...clipsBefore[1], 'SwingA', 'SwingB']);
    final glbBoth = meshGlb(dir);
    final channelsA = await channelsOf(tester, dir, 'SwingA');
    final channelsB = await channelsOf(tester, dir, 'SwingB');
    final assetA = vm.realAssets.firstWhere((a) => a.relativePath == relA);

    final (:entry, removed: _) = (await tester.runAsync(() => vm.deleteAssetsToTrash([assetA])))!;
    expect(File('$dir/$relA').existsSync(), isFalse);
    expect(clipsOf(dir)[0], [...clipsBefore[0], 'SwingB']);
    expect(clipsOf(dir)[1], [...clipsBefore[1], 'SwingB']);
    expect(await channelsOf(tester, dir, 'SwingB'), channelsB, reason: 'the other sequence keeps its clip');
    expect(meshGlb(dir).length, lessThan(glbBoth.length));
    expect(meshGlb(dir).length, greaterThan(glbBefore.length));

    // Undo: SwingA is back where it was, before SwingB.
    vm.transactions.undo();
    expect(File('$dir/$relA').existsSync(), isTrue);
    expect(clipsOf(dir), both);
    expect(await channelsOf(tester, dir, 'SwingA'), channelsA);
    expect(await channelsOf(tester, dir, 'SwingB'), channelsB);
    expect(meshGlb(dir).length, glbBoth.length);

    // Redo trashes it again; restoring the trash entry brings it back.
    vm.transactions.redo();
    expect(clipsOf(dir)[1], [...clipsBefore[1], 'SwingB']);
    await tester.runAsync(() => vm.restoreFromTrash(entry.id));
    expect(File('$dir/$relA').existsSync(), isTrue);
    expect(clipsOf(dir), both);
    expect(await channelsOf(tester, dir, 'SwingA'), channelsA);
    expect(await channelsOf(tester, dir, 'SwingB'), channelsB);
    expect(meshGlb(dir).length, glbBoth.length);

    // Trashing both and undoing restores both in their order.
    vm.refreshAssets();
    final pair = vm.realAssets.where((a) => a.relativePath == relA || a.relativePath == relB).toList();
    await tester.runAsync(() => vm.deleteAssetsToTrash(pair));
    expect(clipsOf(dir), clipsBefore);
    expect(meshGlb(dir).length, lessThanOrEqualTo(glbBefore.length));
    vm.transactions.undo();
    expect(clipsOf(dir), both);
    expect(await channelsOf(tester, dir, 'SwingA'), channelsA);
    expect(await channelsOf(tester, dir, 'SwingB'), channelsB);
  });

  testWidgets('a permanent delete of a sequence takes its clip out of the mesh too', (tester) async {
    final (dir, vm) = await openProject(tester, 'seq_hard');
    final clipsBefore = clipsOf(dir);
    final rel = AnimGraphAssetService.createAnimationSequence(dir, name: 'Gone', meshRelPath: meshRel, lengthFrames: 20);
    vm.refreshAssets();
    expect(clipsOf(dir)[1], [...clipsBefore[1], 'Gone']);
    await tester.runAsync(() => vm.deleteAsset(vm.realAssets.firstWhere((a) => a.relativePath == rel)));
    expect(File('$dir/$rel').existsSync(), isFalse);
    expect(clipsOf(dir), clipsBefore);
  });
}
