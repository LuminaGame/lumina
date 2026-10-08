import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_compile_status.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/anim_graph_asset_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/pose_search_database_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/anim_blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/pose_search_database_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/pose_search/pose_search.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/anim_test_project.dart';
import '../helpers/scaffold_game_project.dart';

/// The Pose Search Database editor and the Motion Matching state pose on a
/// real scaffolded Third Person project (the mannequin and its clips on
/// disk), with no mocks.
void main() {
  late Directory root;
  late String dir;
  const quinn = LuminaThirdPersonContent.projectMeshAssetPath;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_psd_editor_');
    dir = await scaffoldGameProject(root, name: 'psd_project', widgetLibrary: 'flutter');
    ensureTemplateAnimAssets(dir);
  });
  tearDownAll(() => root.deleteSync(recursive: true));

  test('creating a Pose Search Database writes PSD_*.lmas for the mesh and lists it', () {
    final rel = AnimGraphAssetService.createPoseSearchDatabase(dir, name: 'Locomotion', meshRelPath: quinn);
    expect(rel, endsWith('/PSD_Locomotion.lmas'));
    final asset = LuminaAsset.fromBytes(File('$dir/$rel').readAsBytesSync());
    expect(asset.type, AssetType.poseSearchDatabase);
    expect(asset.metadata[AnimGraphAssetService.targetMeshKey], quinn);
    expect(AnimGraphAssetService.readPoseSearchDatabase(dir, rel)!.targetMesh, quinn);
    expect(AnimGraphAssetService.poseSearchDatabasesFor(dir, quinn), contains(rel));
  });

  test('the view model adds clips by filter, edits with undo, saves and builds off the UI isolate', () async {
    final rel = AnimGraphAssetService.createPoseSearchDatabase(dir, name: 'Walks', meshRelPath: quinn);
    final vm = PoseSearchDatabaseEditorViewModel(assetPath: '$dir/$rel');
    await vm.load();
    expect(vm.meshClips, LuminaThirdPersonContent.clipNames);
    expect(vm.cacheState, PoseSearchCacheState.missing);

    expect(vm.addMatching('walk'), isTrue);
    final walks = [for (final c in vm.meshClips) if (c.toLowerCase().contains('walk')) c];
    expect(vm.document.clips.map((c) => c.clip), walks);
    expect(vm.isDirty, isTrue);

    final mirrorBefore = vm.document.clips.first.mirror;
    vm.updateClip(0, (c) => c.copyWith(mirror: !mirrorBefore));
    expect(vm.document.clips.first.mirror, !mirrorBefore);
    vm.undo();
    expect(vm.document.clips.first.mirror, mirrorBefore);

    expect(vm.setTrajectoryTimes('-0.2, 0.25, 0.5, 1'), isTrue);
    expect(vm.document.schema.trajectoryTimes, [-0.2, 0.25, 0.5, 1.0]);
    expect(vm.addBone('hand_l'), isTrue);
    expect(vm.setTags(0, 'walk, loop'), isTrue);
    expect(vm.document.clips.first.tags, ['walk', 'loop']);

    await vm.save();
    expect(vm.isDirty, isFalse);
    expect(AnimGraphAssetService.readPoseSearchDatabase(dir, rel)!.clips.length, walks.length);

    final report = await vm.build();
    expect(vm.error, isNull);
    expect(report!.stats.rows, greaterThan(0));
    expect(report.stats.clips, walks.length);
    expect(File('$dir/${PoseSearchDatabaseService.cachePathOf(rel)}').existsSync(), isTrue);
    expect(vm.cacheState, PoseSearchCacheState.upToDate);

    vm.removeClip(0);
    expect(vm.cacheState, PoseSearchCacheState.stale, reason: 'an edit makes the built cache out of date');
    vm.dispose();
  });

  testWidgets('the editor shows the clip tree, the database clips and the Details, and Build reports the stats',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final rel = AnimGraphAssetService.createPoseSearchDatabase(dir, name: 'Widget', meshRelPath: quinn);
    final vm = PoseSearchDatabaseEditorViewModel(assetPath: '$dir/$rel');
    await tester.runAsync(vm.load);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: PoseSearchDatabaseSubEditor(assetName: 'PSD_Widget', assetPath: '$dir/$rel', viewModel: vm)),
    ));
    await tester.pump();

    expect(find.byType(PoseSearchClipTree), findsOneWidget);
    expect(find.byType(PoseSearchDatabaseClipList), findsOneWidget);
    expect(find.byType(PoseSearchDetailsPanel), findsOneWidget);
    expect(find.text('Add clips from the list on the left.'), findsOneWidget);

    // A click on a mesh clip adds it to the database.
    await tester.tap(find.byKey(const ValueKey('psd_mesh_clip_Idle_Loop')));
    await tester.pump();
    expect(vm.document.clips.map((c) => c.clip), ['Idle_Loop']);
    expect(find.byKey(const ValueKey('psd_clip_0')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('psd_add_matching')));
    await tester.pump();
    expect(vm.document.clips.length, LuminaThirdPersonContent.clipNames.length, reason: 'no filter: Add all clips');

    await tester.runAsync(vm.build);
    await tester.pump();
    expect(find.byKey(const ValueKey('psd_stats_line')), findsOneWidget);
    expect(find.text('Feature cache up to date'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });

  test('a Motion Matching state over a database compiles in the Animation Blueprint editor', () async {
    final db = AnimGraphAssetService.createPoseSearchDatabase(dir, name: 'Abp', meshRelPath: quinn);
    AnimGraphAssetService.writePoseSearchDatabase(
        dir,
        db,
        LuminaPoseSearchDatabaseDocument(targetMesh: quinn, clips: [
          for (final c in LuminaThirdPersonContent.clipNames) LuminaPoseSearchClip(c, loop: true),
        ]));
    final abp = AnimGraphAssetService.createAnimBlueprint(dir, name: 'Matching', meshRelPath: quinn);
    final vm = AnimBlueprintEditorViewModel(assetPath: '$dir/$abp');
    await vm.load();
    expect(vm.poseDatabasePaths, contains(db));
    final state = vm.machine!.entryState;
    vm.setStatePose(state, LuminaAnimPose.motionMatching(db, orientToMovement: true));
    expect(vm.machine!.state(state)!.pose.kind, LuminaAnimPoseKind.motionMatching);
    expect(vm.machine!.state(state)!.pose.database, db);
    expect(await vm.compile(), isTrue);
    expect(vm.compileStatus, BlueprintCompileStatus.upToDate);
    vm.dispose();
  });
}
