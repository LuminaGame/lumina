// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/navigation_editor_state.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/viewport_ray.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/navigation_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/navigation_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

import '../helpers/temp_project.dart';

/// Every scenario runs
/// against a real temp project whose level `.lmas` lives on disk.
/// The nav backend is the real pure-Dart
/// `LuminaNavigationSystem` (walkable grid + A*), so no GPU is needed.
void main() {
  late Directory tempDir;
  late Directory projDir;
  late File levelFile;

  const project = LuminaProject(
    projectName: 'NavGame',
    activeLevel: 'contents/levels/L_Main.lmas',
  );

  /// Writes a real, minimal binary glTF (GLB 2.0) unit cube — 8 vertices at
  /// ±[sizeMetres]/2, 12 triangles — that the editor's own GLB parser hydrates
  /// into the level's mesh actors (`_loadActorMeshData` scans contents/).
  /// glTF is metres; the editor draws an imported mesh ×100, so the default
  /// cube is a 100 cm box in the level.
  void writeCubeGlb(File target, {double sizeMetres = 1.0}) {
    final h = sizeMetres / 2;
    final positions = Float32List.fromList([
      -h, -h, -h, h, -h, -h, h, h, -h, -h, h, -h, // back face
      -h, -h, h, h, -h, h, h, h, h, -h, h, h, // front face
    ]);
    final indices = Uint16List.fromList([
      0, 1, 2, 0, 2, 3, 4, 6, 5, 4, 7, 6, // back / front
      0, 4, 5, 0, 5, 1, 3, 2, 6, 3, 6, 7, // bottom / top
      0, 3, 7, 0, 7, 4, 1, 5, 6, 1, 6, 2, // left / right
    ]);
    final posBytes = positions.buffer.asUint8List();
    final idxBytes = indices.buffer.asUint8List();
    final bin = BytesBuilder()..add(posBytes)..add(idxBytes);
    while (bin.length % 4 != 0) {
      bin.addByte(0);
    }
    final binBytes = bin.toBytes();
    final json = jsonEncode({
      'asset': {'version': '2.0', 'generator': 'lumina_ui navigation_editor_test'},
      'scene': 0,
      'scenes': [
        {'nodes': [0]}
      ],
      'nodes': [
        {'mesh': 0, 'name': 'Cube'}
      ],
      'meshes': [
        {
          'primitives': [
            {
              'attributes': {'POSITION': 0},
              'indices': 1,
              'mode': 4,
            }
          ]
        }
      ],
      'accessors': [
        {'bufferView': 0, 'componentType': 5126, 'count': 8, 'type': 'VEC3', 'min': [-h, -h, -h], 'max': [h, h, h]},
        {'bufferView': 1, 'componentType': 5123, 'count': 36, 'type': 'SCALAR'},
      ],
      'bufferViews': [
        {'buffer': 0, 'byteOffset': 0, 'byteLength': posBytes.length},
        {'buffer': 0, 'byteOffset': posBytes.length, 'byteLength': idxBytes.length},
      ],
      'buffers': [
        {'byteLength': binBytes.length}
      ],
    });
    final jsonBuilder = BytesBuilder()..add(utf8.encode(json));
    while (jsonBuilder.length % 4 != 0) {
      jsonBuilder.addByte(0x20);
    }
    final jsonBytes = jsonBuilder.toBytes();
    final total = 12 + 8 + jsonBytes.length + 8 + binBytes.length;
    final out = BytesBuilder();
    final header = ByteData(12)
      ..setUint32(0, 0x46546C67, Endian.little)
      ..setUint32(4, 2, Endian.little)
      ..setUint32(8, total, Endian.little);
    out.add(header.buffer.asUint8List());
    final jsonHeader = ByteData(8)
      ..setUint32(0, jsonBytes.length, Endian.little)
      ..setUint32(4, 0x4E4F534A, Endian.little);
    out.add(jsonHeader.buffer.asUint8List());
    out.add(jsonBytes);
    final binHeader = ByteData(8)
      ..setUint32(0, binBytes.length, Endian.little)
      ..setUint32(4, 0x004E4942, Endian.little);
    out.add(binHeader.buffer.asUint8List());
    out.add(binBytes);
    target.parent.createSync(recursive: true);
    target.writeAsBytesSync(out.toBytes());
  }

  /// Bounds volume actor, stored like every level actor: location in cm,
  /// Z up. A 1 m box × scale → size in metres along X / Y / Z == scale; the
  /// default is a 10 × 10 m footprint, 5 m tall, resting on z = 0.
  EditorActorNode volumeNode(String id, String name, {List<double>? centre, List<double>? extent}) => EditorActorNode(
        id: id,
        name: name,
        type: NavMeshBoundsVolume.actorType,
        location: centre ?? [0.0, 0.0, 250.0],
        scale: extent ?? [10.0, 10.0, 5.0],
        mobility: 'Static',
      );

  /// A 1×1×1 m (100 cm) blocking box: a Mesh actor whose geometry is the real
  /// `SM_Cube.glb` written into the project (hydrated from disk on open).
  /// Location / scale are stored Z up.
  EditorActorNode boxNode(String id, {List<double>? centre, List<double>? scale}) => EditorActorNode(
        id: id,
        name: 'SM_Block_$id',
        type: 'Mesh',
        location: centre ?? [0.0, 0.0, 0.0],
        scale: scale,
      );

  void writeLevel(List<EditorActorNode> actors, {Map<String, dynamic>? navigation}) {
    levelFile.writeAsStringSync(jsonEncode({
      'assetId': 'level_L_Main',
      'name': 'L_Main',
      'type': 'level',
      'relativePath': 'contents/levels/L_Main.lmas',
      'metadata': {
        'actors': actors.map((a) => a.toMap()).toList(),
        'navigation': ?navigation,
      },
    }));
  }

  Map<String, dynamic> readLevel() => jsonDecode(levelFile.readAsStringSync()) as Map<String, dynamic>;

  Future<EditorViewModel> openEditor() async {
    final vm = EditorViewModel(initialProject: project, projectLocation: tempDir.path, enableTimers: false);
    await vm.ensureDefaultLevelAssets();
    return vm;
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_navigation_editor_');
    projDir = Directory('${tempDir.path}/NavGame')..createSync(recursive: true);
    Directory('${projDir.path}/contents/levels').createSync(recursive: true);
    File('${projDir.path}/NavGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    levelFile = File('${projDir.path}/contents/levels/L_Main.lmas');
    writeCubeGlb(File('${projDir.path}/contents/meshes/SM_Cube.glb'));
    writeLevel([
      EditorActorNode(id: 'act_1', name: 'PlayerPawn_Default', type: 'Pawn', location: [0.0, 0.0, 0.0]),
    ]);
  });

  // The editor's git probe may still hold the folder on Windows.
  tearDown(() async {
    await deleteTempProject(tempDir);
  });

  Future<void> pumpEditor(WidgetTester tester, EditorViewModel editor, NavigationEditorViewModel vm) async {
    // The editor panel is laid out at 1400x820; the default 800x600 test
    // surface would clip (and so un-hit-test) everything past its edges.
    tester.view.physicalSize = const Size(1400, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SizedBox(
            width: 1400,
            height: 820,
            child: NavigationSubEditor(assetName: 'Navigation', editorViewModel: editor, viewModel: vm),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('opening on a seeded level lists exactly its NavMeshBoundsVolume actors; the mockup names are gone', (tester) async {
    writeLevel([
      EditorActorNode(id: 'act_1', name: 'PlayerPawn_Default', type: 'Pawn', location: [0.0, 0.0, 0.0]),
      volumeNode('act_nav_a', 'NavBounds_Courtyard'),
      volumeNode('act_nav_b', 'NavBounds_Garage', centre: [3000.0, 0.0, 250.0]),
      boxNode('act_box', centre: [0.0, 0.0, 0.0]),
    ]);
    // Real disk I/O (level + GLB hydration) must run outside the widget test's fake-async zone.
    final editor = (await tester.runAsync(openEditor))!;
    addTearDown(editor.dispose);
    final vm = NavigationEditorViewModel(editor: editor)..open();
    addTearDown(vm.dispose);

    expect(vm.volumes.map((v) => v.name), ['NavBounds_Courtyard', 'NavBounds_Garage']);
    expect(vm.volumes.length, 2, reason: 'the box mesh and the pawn are not volumes');

    await pumpEditor(tester, editor, vm);
    expect(find.text('NAVIGATION'), findsOneWidget);
    expect(find.text('NAV BOUNDS VOLUMES'), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_volume_row_act_nav_a')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_volume_row_act_nav_b')), findsOneWidget);
    expect(find.byType(SubEditor3DViewport), findsOneWidget);

    // The four hardcoded mockup names never appear in the UI…
    for (final fake in ['NavMeshBoundsVolume_Main', 'NavModifierVolume_Water', 'NavLinkProxy_LedgeJump', 'NavLinkProxy_Ladder']) {
      expect(find.text(fake), findsNothing);
    }
    expect(find.textContaining('Walkable Polygons'), findsNothing);
    expect(find.text('Rebuild NavMesh'), findsNothing);
    // …and are gone from the widget source too.
    final source = File('lib/ui/features/sub_editors/views/navigation_sub_editor.dart').readAsStringSync();
    for (final fake in ['NavMeshBoundsVolume_Main', 'NavModifierVolume_Water', 'NavLinkProxy_LedgeJump', 'NavLinkProxy_Ladder', '14,210', '0.38ms']) {
      expect(source.contains(fake), isFalse, reason: 'mockup literal "$fake" must not survive');
    }
    expect(source.contains('package:flutter/material.dart'), isFalse, reason: 'shadcn_flutter only');

    // Opening on a level with volumes triggers a real build.
    expect(vm.lastBuild, isNotNull);
    expect(vm.snapshot, isNotNull);
    expect(vm.lastBuild!.walkableCells, greaterThan(0));

    // Filter narrows the tree.
    vm.setVolumeFilter('garage');
    expect(vm.filteredVolumes.map((v) => v.name), ['NavBounds_Garage']);
    // Let the viewport's file reads started under the fake clock
    // finish, or Windows keeps the project folder open.
    await drainRealIo(tester);
  });

  test('+ Add Bounds Volume adds a real undoable actor with the default 20×20×5 m extent; Delete removes it (undoable)', () async {
    final editor = await openEditor();
    addTearDown(editor.dispose);
    final vm = NavigationEditorViewModel(editor: editor)..open();
    addTearDown(vm.dispose);
    expect(vm.volumes, isEmpty);
    expect(vm.canBuild, isFalse);
    expect(editor.project.isDirty, isFalse);

    final volume = vm.addBoundsVolume();
    expect(vm.volumes.single.id, volume.id);
    expect(volume.type, NavMeshBoundsVolume.actorType);
    expect(NavMeshBoundsVolume.defaultExtentMetres, [20.0, 20.0, 5.0], reason: 'Z up: 20 × 20 m footprint, 5 m tall');
    expect(NavMeshBoundsVolume.extentMetresOf(volume), NavMeshBoundsVolume.defaultExtentMetres);
    expect(volume.scale, NavMeshBoundsVolume.defaultExtentMetres, reason: 'scale is the size in metres');
    expect(NavMeshBoundsVolume.extentCmOf(volume), [2000.0, 2000.0, 500.0]);
    // Centred on the viewport focus (pivot, stored Z up), bottom face resting
    // on the pivot height: lifted along Z by half of the 500 cm height.
    expect(volume.location[0], editor.cameraPanX);
    expect(volume.location[1], editor.cameraPanY);
    expect(volume.location[2], editor.cameraPanZ + 250.0);
    // In the runtime (Y-up) grid space the volume spans 2000 × 2000 cm on
    // X/Z and 500 cm up from the pivot height.
    final box = NavMeshBoundsVolume.aabb(volume);
    expect(box.min.y, closeTo(editor.cameraPanZ, 1e-9));
    expect(box.max.y - box.min.y, closeTo(500.0, 1e-9));
    expect(box.max.x - box.min.x, closeTo(2000.0, 1e-9));
    expect(box.max.z - box.min.z, closeTo(2000.0, 1e-9));
    expect(editor.actors.any((a) => a.id == volume.id), isTrue, reason: 'real level actor');
    expect(editor.rootActors.map((a) => a.id), contains(volume.id), reason: 'outliner-visible');
    expect(editor.project.isDirty, isTrue);
    expect(vm.canBuild, isTrue);
    expect(vm.selectedVolume?.id, volume.id);

    // Adding is one undo step.
    editor.transactions.undo();
    expect(vm.volumes, isEmpty);
    editor.transactions.redo();
    expect(vm.volumes.single.id, volume.id);

    // Delete → gone, undo → back.
    vm.deleteVolume(volume.id);
    expect(vm.volumes, isEmpty);
    expect(editor.actors.any((a) => a.id == volume.id), isFalse);
    editor.transactions.undo();
    expect(vm.volumes.single.id, volume.id);

    // Rename writes through to the actor; second volume gets a unique name.
    vm.renameVolume(volume.id, 'NavBounds_Arena');
    expect(editor.actors.singleWhere((a) => a.id == volume.id).name, 'NavBounds_Arena');
    final second = vm.addBoundsVolume();
    expect(second.name, isNot(editor.actors.singleWhere((a) => a.id == volume.id).name));
    expect(second.id, isNot(volume.id));
  });

  test('build() on a 10×10 m volume with cellSize 50 cm and no obstacles → 400 walkable cells in HUD model and overlay snapshot', () async {
    writeLevel([volumeNode('act_nav', 'NavBounds', extent: [10.0, 10.0, 5.0])]);
    final editor = await openEditor();
    addTearDown(editor.dispose);
    final vm = NavigationEditorViewModel(editor: editor)..open();
    addTearDown(vm.dispose);

    vm.setCellSize(50.0);
    final result = vm.build();
    expect(result, isNotNull);
    expect(result!.walkableCells, 400);
    expect(result.cols, 20);
    expect(result.rows, 20);
    expect(result.obstacleCount, 0);
    expect(result.duration, isNotNull);
    // The bake bounds are the volume in runtime cm: 1000 × 1000 cm on X/Z,
    // resting on y = 0, 500 cm tall.
    expect(result.bounds.min.x, closeTo(-500.0, 1e-9));
    expect(result.bounds.max.x, closeTo(500.0, 1e-9));
    expect(result.bounds.min.z, closeTo(-500.0, 1e-9));
    expect(result.bounds.max.z, closeTo(500.0, 1e-9));
    expect(result.bounds.min.y, closeTo(0.0, 1e-9));
    expect(result.bounds.max.y, closeTo(500.0, 1e-9));
    expect(vm.navigation!.isBuilt, isTrue);
    expect(vm.navigation!.walkableCellCount, 400);

    final snap = vm.snapshot!;
    expect(snap.cols * snap.rows, 400);
    expect(snap.walkableCount, 400);
    expect(snap.blockedCount, 0);
    expect(snap.cellSize, 50.0);
    // Cell centres map back to the engine's own walkability answer.
    expect(vm.navigation!.isWalkable(Vector3(snap.cellCenterX(0), 0.0, snap.cellCenterZ(0))), isTrue);
    expect(snap.cellCenterX(0), closeTo(-475.0, 1e-9));
    expect(snap.cellCenterZ(19), closeTo(475.0, 1e-9));
    expect(vm.hudGridLabel, 'Grid: 20×20 @ 50 cm');
    expect(vm.hudWalkableLabel, 'Walkable Cells: 400');
  });

  test('stored Z-up transforms reach the runtime grid through LuminaAxes: volume at [0,0,0] scale [20,20,5] bakes 2000×2000 cm, 500 tall; stored y is runtime −z', () async {
    writeLevel([
      volumeNode('act_nav', 'NavBounds', centre: [0.0, 0.0, 0.0], extent: [20.0, 20.0, 5.0]),
      // A 200 × 100 × 100 cm box (stored scale [2, 1, 1]) at stored
      // (200, 300, −200): resting on the volume's floor at z = −250.
      boxNode('act_box', centre: [200.0, 300.0, -200.0], scale: [2.0, 1.0, 1.0]),
    ]);
    final editor = await openEditor();
    addTearDown(editor.dispose);
    final vm = NavigationEditorViewModel(editor: editor)..open();
    addTearDown(vm.dispose);

    final volume = vm.volumes.single;
    expect(NavMeshBoundsVolume.sizeOf(volume), Vector3(2000.0, 500.0, 2000.0), reason: 'scale [20,20,5] m → runtime (x, y-up, z) cm');
    final box = NavigationWorldBuilder.obstaclesFrom(editor.actors).single;
    expect(box.center.x, closeTo(200.0, 1e-9));
    expect(box.center.y, closeTo(-200.0, 1e-9), reason: 'stored z is runtime y');
    expect(box.center.z, closeTo(-300.0, 1e-9), reason: 'stored +y is runtime −z');
    expect(box.halfExtent.x, closeTo(100.0, 1e-9));
    expect(box.halfExtent.y, closeTo(50.0, 1e-9));
    expect(box.halfExtent.z, closeTo(50.0, 1e-9));

    // The default engine cell size (50 cm) over the 2000 × 2000 cm area.
    expect(vm.config.cellSize, 50.0);
    final result = vm.lastBuild!;
    expect(result.bounds.min, Vector3(-1000.0, -250.0, -1000.0));
    expect(result.bounds.max, Vector3(1000.0, 250.0, 1000.0));
    expect(result.cols, 40);
    expect(result.rows, 40);
    expect(result.obstacleCount, 1);
    expect(vm.navigation!.isWalkable(Vector3(200.0, 0.0, -300.0)), isFalse, reason: 'the box footprint');
    expect(vm.navigation!.isWalkable(Vector3(200.0, 0.0, 300.0)), isTrue, reason: 'the mirror spot is clear');
    expect(vm.floorTapPlaneCm, -250.0, reason: 'the grid floor is the volume bottom, runtime Y');
  });

  test('1×1 m blocking box + agentRadius 35 cm blocks the inflated 170×170 cm footprint; agentRadius 10 cm shrinks the patch', () async {
    writeLevel([
      volumeNode('act_nav', 'NavBounds', extent: [10.0, 10.0, 5.0]),
      boxNode('act_box', centre: [0.0, 0.0, 0.0]),
    ]);
    final editor = await openEditor();
    addTearDown(editor.dispose);
    final vm = NavigationEditorViewModel(editor: editor)..open();
    addTearDown(vm.dispose);

    // The box is a real obstacle candidate: the 1 m glTF cube drawn ×100 is
    // 100 × 100 × 100 cm at the origin.
    final obstacles = NavigationWorldBuilder.obstaclesFrom(editor.actors);
    expect(obstacles.length, 1);
    expect(obstacles.single.halfExtent.x, closeTo(50.0, 1e-9));
    expect(obstacles.single.halfExtent.y, closeTo(50.0, 1e-9));
    expect(obstacles.single.halfExtent.z, closeTo(50.0, 1e-9));

    vm.setCellSize(25.0);
    vm.setAgentRadius(35.0);
    final wide = vm.build()!;
    expect(wide.obstacleCount, 1);
    final snapWide = vm.snapshot!;
    for (var r = 0; r < snapWide.rows; r++) {
      for (var c = 0; c < snapWide.cols; c++) {
        final x = snapWide.cellCenterX(c);
        final z = snapWide.cellCenterZ(r);
        final insideInflated = x.abs() < 85.0 && z.abs() < 85.0;
        if (insideInflated) {
          expect(snapWide.isWalkableCell(c, r), isFalse, reason: 'cell ($x, $z) lies inside the 170 cm footprint');
        }
        if (x.abs() > 120.0 || z.abs() > 120.0) {
          expect(snapWide.isWalkableCell(c, r), isTrue, reason: 'cell ($x, $z) is clear of the obstacle');
        }
      }
    }
    expect(snapWide.blockedCount, 64, reason: '8×8 cells of 25 cm cover the 170 cm footprint');
    expect(wide.walkableCells, 1600 - 64);

    vm.setAgentRadius(10.0);
    final narrow = vm.build()!;
    expect(vm.snapshot!.blockedCount, lessThan(snapWide.blockedCount));
    expect(vm.snapshot!.blockedCount, 36, reason: '6×6 cells cover the 120 cm footprint');
    expect(narrow.walkableCells, greaterThan(wide.walkableCells));
    expect(vm.navigation!.config.agentRadius, 10.0, reason: 'NavGridConfig maps 1:1 onto the draft');
  });

  test('path tester: open ground collapses to 2 points with measured time; around the box every point stays outside and isPartial == false', () async {
    writeLevel([
      volumeNode('act_nav', 'NavBounds', extent: [10.0, 10.0, 5.0]),
      boxNode('act_box', centre: [0.0, 0.0, 0.0]),
    ]);
    final editor = await openEditor();
    addTearDown(editor.dispose);
    final vm = NavigationEditorViewModel(editor: editor)..open();
    addTearDown(vm.dispose);
    vm.setCellSize(50.0);
    vm.build();

    // Open ground: runtime z = 300 cm row, clear of the obstacle → straight line.
    final open = vm.testPath(Vector3(-400.0, 0.0, 300.0), Vector3(400.0, 0.0, 300.0));
    expect(open.state, NavPathState.found);
    expect(open.path!.points.length, 2);
    expect(open.path!.isPartial, isFalse);
    expect(open.length, closeTo(800.0, 50.0));
    expect(open.queryTimeMs, greaterThan(0.0));
    expect(vm.hudPathLabel, startsWith('Path: 2 points'));
    expect(vm.hudPathLabel, contains(' cm,'));

    // Around the box: every point outside the inflated footprint.
    final around = vm.testPath(Vector3(-300.0, 0.0, 0.0), Vector3(300.0, 0.0, 0.0));
    expect(around.state, NavPathState.found);
    expect(around.path!.isPartial, isFalse);
    expect(around.path!.points.length, greaterThan(2), reason: 'a straight line would cross the obstacle');
    for (final p in around.path!.points) {
      expect(p.x.abs() >= 85.0 || p.z.abs() >= 85.0, isTrue, reason: 'point $p lies inside the inflated obstacle');
    }
    expect(around.length, greaterThan(600.0));
    expect(vm.pathDebugLine, contains('→'));
    expect(vm.pathDebugLine, contains('smoothed points'));
    // Endpoints print in authoring axes (X / Y, Z up), cm.
    expect(vm.pathDebugLine, startsWith('(-300, 0) → (300, 0) cm:'));

    // Click-driven placement: the viewport reports floor hits in runtime cm.
    // First = start, second = goal, third moves the nearer flag.
    vm.clearPath();
    expect(vm.pathResult, isNull);
    vm.setPathTesterMode(true);
    vm.placePathPoint(Vector3(-300.0, 0.0, 0.0));
    expect(vm.pathStart, isNotNull);
    expect(vm.pathGoal, isNull);
    expect(vm.pathResult, isNull);
    vm.placePathPoint(Vector3(300.0, 0.0, 0.0));
    expect(vm.pathGoal, isNotNull);
    expect(vm.pathResult!.state, NavPathState.found);
    vm.placePathPoint(Vector3(350.0, 0.0, 50.0));
    expect(vm.pathGoal!.x, closeTo(350.0, 1e-9), reason: 'nearer flag (goal) moved');
    expect(vm.pathGoal!.z, closeTo(50.0, 1e-9));
    expect(vm.pathStart!.x, closeTo(-300.0, 1e-9));
    vm.clearPath();
    expect(vm.pathStart, isNull);
    expect(vm.pathGoal, isNull);
    expect(vm.pathResult, isNull);
  });

  test('goal inside a large obstacle → Partial path; goal walled off with the start as nearest cell → No path, no crash', () async {
    // 6×6 m block (stored Z up: 6 × 6 m footprint, 1 m tall): the goal at its
    // centre has no walkable cell within the engine's 200 cm projection
    // radius, so A* runs to exhaustion and returns the closest reachable
    // point flagged partial.
    writeLevel([
      volumeNode('act_nav', 'NavBounds', extent: [10.0, 10.0, 5.0]),
      boxNode('act_big', centre: [0.0, 0.0, 0.0], scale: [6.0, 6.0, 1.0]),
    ]);
    final editor = await openEditor();
    addTearDown(editor.dispose);
    final vm = NavigationEditorViewModel(editor: editor)..open();
    addTearDown(vm.dispose);
    vm.setCellSize(50.0);
    vm.build();
    final partial = vm.testPath(Vector3(-450.0, 0.0, -450.0), Vector3(0.0, 0.0, 0.0));
    expect(partial.state, NavPathState.partial);
    expect(partial.path!.isPartial, isTrue);
    expect(vm.hudPathBadge, 'Partial path');

    // Walled-off goal: a closed ring of four walls around the origin. The
    // start sits directly east of the ring on the goal's row, which makes
    // it the closest reachable cell — the engine then has nothing better
    // than the start itself and returns null (No path). Walls are stored
    // Z up (runtime z = −stored y; a wall 4 m along runtime Z is 4 m along
    // stored Y).
    writeLevel([
      volumeNode('act_nav', 'NavBounds', extent: [10.0, 10.0, 5.0]),
      boxNode('act_w', centre: [-175.0, 0.0, 0.0], scale: [0.5, 4.0, 1.0]),
      boxNode('act_e', centre: [175.0, 0.0, 0.0], scale: [0.5, 4.0, 1.0]),
      boxNode('act_n', centre: [0.0, -175.0, 0.0], scale: [4.0, 0.5, 1.0]),
      boxNode('act_s', centre: [0.0, 175.0, 0.0], scale: [4.0, 0.5, 1.0]),
    ]);
    final editor2 = await openEditor();
    addTearDown(editor2.dispose);
    final vm2 = NavigationEditorViewModel(editor: editor2)..open();
    addTearDown(vm2.dispose);
    vm2.setCellSize(50.0);
    vm2.build();
    expect(vm2.navigation!.isWalkable(Vector3(0.0, 0.0, 0.0)), isTrue, reason: 'the pocket interior is clear');
    expect(vm2.navigation!.isWalkable(Vector3(175.0, 0.0, 0.0)), isFalse, reason: 'east wall');
    expect(vm2.navigation!.isWalkable(Vector3(0.0, 0.0, 175.0)), isFalse, reason: 'wall at stored y = −175');
    final none = vm2.testPath(Vector3(275.0, 0.0, 25.0), Vector3(25.0, 0.0, 25.0));
    expect(none.state, NavPathState.noPath);
    expect(none.path, isNull);
    expect(vm2.hudPathBadge, 'No path');
    // A start elsewhere still yields a partial path ending outside the ring.
    final elsewhere = vm2.testPath(Vector3(-450.0, 0.0, -450.0), Vector3(25.0, 0.0, 25.0));
    expect(elsewhere.state, NavPathState.partial);
    expect(vm2.navigation!.isWalkable(elsewhere.path!.points.last), isTrue);
  });

  testWidgets('agent/grid inputs update the NavGridConfig draft; Save round-trips config + volumes through the level .lmas', (tester) async {
    writeLevel([volumeNode('act_nav', 'NavBounds', extent: [10.0, 10.0, 5.0])]);
    final editor = (await tester.runAsync(openEditor))!;
    addTearDown(editor.dispose);
    final vm = NavigationEditorViewModel(editor: editor)..open();
    addTearDown(vm.dispose);
    await pumpEditor(tester, editor, vm);

    expect(find.text('AGENT & GRID'), findsOneWidget);
    expect(vm.config, NavigationEditorConfig.defaults());
    // Defaults are the runtime's own NavGridConfig(), in cm.
    const engine = NavGridConfig();
    expect(vm.config.cellSize, engine.cellSize);
    expect(vm.config.agentRadius, engine.agentRadius);
    expect(vm.config.agentHeight, engine.agentHeight);
    expect(vm.config.maxStepHeight, engine.maxStepHeight);
    expect(vm.config.cellSize, 50.0);
    // Labels name the unit the fields show (cm) and the selected volume's
    // inspector uses the Details panel's Z-up axes.
    expect(find.text('Agent Radius (cm) — inflates every obstacle at bake time'), findsOneWidget);
    expect(find.text('Agent Height (cm) — geometry above this is overhead'), findsOneWidget);
    expect(find.text('Max Step Height (cm) — geometry below this is floor'), findsOneWidget);
    expect(find.text('Cell Size (cm, 10–200)'), findsOneWidget);
    expect(find.text('Center (cm, Z up)'), findsOneWidget);
    expect(find.text('Extent (cm, Z up)'), findsOneWidget);
    expect(find.text('10×10×5 m'), findsOneWidget, reason: 'volume row summarises the size in metres');
    expect(find.textContaining('(m'), findsNothing, reason: 'no metre-labelled field is left');

    // Typed edit through the real numeric field.
    final radiusField = find.descendant(of: find.byKey(const ValueKey('nav_agent_radius')), matching: find.byType(TextField));
    expect(radiusField, findsOneWidget);
    await tester.tap(radiusField);
    await tester.pump();
    await tester.enterText(radiusField, '60');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(vm.config.agentRadius, closeTo(60.0, 1e-9));

    final cellField = find.descendant(of: find.byKey(const ValueKey('nav_cell_size')), matching: find.byType(TextField));
    await tester.tap(cellField);
    await tester.pump();
    await tester.enterText(cellField, '25');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(vm.config.cellSize, closeTo(25.0, 1e-9));

    // The mask key sits on the TextField itself, not on a wrapper.
    final maskField = find.byKey(const ValueKey('nav_layer_mask'));
    expect(maskField, findsOneWidget);
    await tester.enterText(maskField, '0x0000000F');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(vm.config.walkableLayerMask, 0xF);

    vm.setAgentHeight(210.0);
    vm.setMaxStepHeight(45.0);
    final cfg = vm.config.toNavGridConfig();
    expect(cfg.agentRadius, closeTo(60.0, 1e-9));
    expect(cfg.cellSize, closeTo(25.0, 1e-9));
    expect(cfg.agentHeight, 210.0);
    expect(cfg.maxStepHeight, 45.0);
    expect(cfg.walkableLayerMask, 0xF);
    expect(vm.isDirty, isTrue);
    expect(editor.project.isDirty, isTrue, reason: 'nav edits mark the level dirty for auto-save');

    // Volume centre / extent inputs write through to the actor (cm, stored
    // Z-up axes; the extent lands in the scale as metres).
    vm.selectVolume('act_nav');
    vm.setVolumeExtent('act_nav', 0, 1200.0);
    vm.setVolumeCenter('act_nav', 2, 150.0);
    final actor = editor.actors.singleWhere((a) => a.id == 'act_nav');
    expect(actor.scale[0], 12.0, reason: '1200 cm → scale 12 (metres)');
    expect(actor.location[2], 150.0, reason: 'stored Z is the height');
    expect(NavMeshBoundsVolume.centreOf(actor).y, 150.0, reason: 'stored Z up → runtime Y up');
    expect(NavMeshBoundsVolume.sizeOf(actor).x, closeTo(1200.0, 1e-9));

    // Undo of a config edit restores the previous draft.
    final before = vm.config;
    vm.setCellSize(50.0);
    editor.transactions.undo();
    expect(vm.config, before);

    expect(await tester.runAsync(vm.save), isTrue);
    expect(vm.isDirty, isFalse);
    final nav = readLevel()['metadata']['navigation'] as Map<String, dynamic>;
    final saved = nav['config'] as Map<String, dynamic>;
    // Persisted in cm, like the model.
    expect(saved['cellSize'], 25.0);
    expect(saved['agentRadius'], 60.0);
    expect(saved['agentHeight'], 210.0);
    expect(saved['maxStepHeight'], 45.0);
    expect(saved['walkableLayerMask'], 0xF);
    expect((nav['volumes'] as List).cast<Map>().single['id'], 'act_nav');
    final actors = (readLevel()['metadata']['actors'] as List).cast<Map>();
    final volMap = actors.firstWhere((a) => a['id'] == 'act_nav');
    expect(volMap['type'], NavMeshBoundsVolume.actorType);
    expect((volMap['scale'] as List).first, 12.0);

    final reloaded = (await tester.runAsync(openEditor))!;
    addTearDown(reloaded.dispose);
    final vm2 = NavigationEditorViewModel(editor: reloaded)..open();
    addTearDown(vm2.dispose);
    expect(vm2.config, vm.config, reason: 'full config round-trip through the real .lmas');
    expect(vm2.volumes.single.scale[0], 12.0);
    expect(vm2.isDirty, isFalse);
  });

  test('Auto-rebuild on change: moving the blocking actor triggers exactly one debounced rebuild; off: nothing until Build', () async {
    writeLevel([
      volumeNode('act_nav', 'NavBounds', extent: [10.0, 10.0, 5.0]),
      boxNode('act_box', centre: [0.0, 0.0, 0.0]),
    ]);
    final editor = await openEditor();
    addTearDown(editor.dispose);

    fakeAsync((async) {
      final vm = NavigationEditorViewModel(editor: editor)..open();
      addTearDown(vm.dispose);
      vm.setCellSize(50.0);
      vm.build();
      final builds = vm.buildCount;
      final blockedBefore = vm.snapshot!.blockedCount;
      expect(vm.navigation!.isWalkable(Vector3(0.0, 0.0, 0.0)), isFalse);

      // Off: moving the box marks the grid stale but does not rebuild. The
      // location is stored Z up: [300, −300, 0] is runtime (300, 0, 300).
      expect(vm.config.autoRebuild, isFalse);
      editor.selectActorById('act_box');
      editor.updateActorLocation([300.0, -300.0, 0.0]);
      async.elapse(const Duration(seconds: 2));
      expect(vm.buildCount, builds);
      expect(vm.isStale, isTrue);
      vm.build();
      expect(vm.buildCount, builds + 1);
      expect(vm.isStale, isFalse);
      expect(vm.navigation!.isWalkable(Vector3(0.0, 0.0, 0.0)), isTrue, reason: 'origin cleared after the move');
      expect(vm.navigation!.isWalkable(Vector3(300.0, 0.0, 300.0)), isFalse);
      expect(vm.navigation!.isWalkable(Vector3(300.0, 0.0, -300.0)), isTrue, reason: 'stored y maps onto runtime −z');

      // On: a burst of moves collapses into one rebuild after the 500 ms debounce.
      vm.setAutoRebuild(true);
      final beforeBurst = vm.buildCount;
      editor.updateActorLocation([-300.0, 300.0, 0.0]);
      async.elapse(const Duration(milliseconds: 100));
      editor.updateActorLocation([-200.0, 200.0, 0.0]);
      async.elapse(const Duration(milliseconds: 100));
      editor.updateActorLocation([0.0, 0.0, 0.0]);
      expect(vm.buildCount, beforeBurst, reason: 'debounce pending');
      async.elapse(const Duration(milliseconds: 499));
      expect(vm.buildCount, beforeBurst);
      async.elapse(const Duration(milliseconds: 2));
      expect(vm.buildCount, beforeBurst + 1, reason: 'exactly one rebuild');
      async.elapse(const Duration(seconds: 2));
      expect(vm.buildCount, beforeBurst + 1);
      expect(vm.snapshot!.blockedCount, blockedBefore);
      expect(vm.navigation!.isWalkable(Vector3(0.0, 0.0, 0.0)), isFalse, reason: 'overlay updated to the box back at the origin');

      // A config commit with auto-rebuild on rebuilds too (no inflation → the
      // 100 cm box covers 3×3 cells of 50 cm instead of 4×4).
      vm.setAgentRadius(0.0);
      async.elapse(const Duration(milliseconds: 600));
      expect(vm.buildCount, beforeBurst + 2);
      expect(vm.snapshot!.blockedCount, lessThan(blockedBefore));
      expect(vm.snapshot!.blockedCount, 9);
    });
  });

  testWidgets('build with zero volumes → button disabled with an explanatory state, not an exception', (tester) async {
    final editor = (await tester.runAsync(openEditor))!;
    addTearDown(editor.dispose);
    final vm = NavigationEditorViewModel(editor: editor)..open();
    addTearDown(vm.dispose);
    expect(vm.canBuild, isFalse);
    expect(vm.buildDisabledReason, contains('Add a NavMeshBoundsVolume'));
    expect(vm.build(), isNull);
    expect(vm.lastBuild, isNull);
    expect(vm.testPath(Vector3.zero(), Vector3(100, 0, 100)).state, NavPathState.noPath, reason: 'no grid yet → honest No path');

    await pumpEditor(tester, editor, vm);
    final button = tester.widget<PrimaryButton>(find.byKey(const ValueKey('nav_build')));
    expect(button.onPressed, isNull, reason: 'disabled');
    expect(find.text(vm.buildDisabledReason), findsOneWidget);
    expect(find.textContaining('Walkable Cells'), findsNothing, reason: 'no fabricated stats before a build');

    // Toolbar Build Navigation command from the shell requests a build on the tab.
    editor.requestNavigationBuild();
    await tester.pump();
    expect(editor.openTabs.any((t) => t.category == 'navmesh'), isTrue);
    expect(vm.lastBuild, isNull, reason: 'still nothing to build');

    // Add a volume through the real button → Build becomes enabled.
    await tester.tap(find.byKey(const ValueKey('nav_add_volume')));
    await tester.pump();
    expect(vm.volumes.length, 1);
    final enabled = tester.widget<PrimaryButton>(find.byKey(const ValueKey('nav_build')));
    expect(enabled.onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('nav_build')));
    await tester.pump();
    expect(vm.lastBuild, isNotNull);
    expect(find.textContaining('Walkable Cells: ${vm.lastBuild!.walkableCells}'), findsOneWidget);

    // Shell request now dispatches the same build.
    final count = vm.buildCount;
    editor.requestNavigationBuild();
    await tester.pump();
    expect(vm.buildCount, count + 1);
  });

  test('viewport floor unprojection: the screen centre of a Y-up orbit camera hits the pivot on the floor plane', () {
    // Camera 1000 cm above the origin looking straight down (pitch 89°) → the
    // centre pixel lands on the pivot; a pixel to the right lands at +x.
    final centre = unprojectViewportToPlaneY(
      local: const Offset(400, 300),
      size: const Size(800, 600),
      yawDeg: 0.0,
      pitchDeg: 89.0,
      distance: 1000.0,
      target: Vector3.zero(),
      planeY: 0.0,
    );
    expect(centre, isNotNull);
    expect(centre!.x, closeTo(0.0, 20.0));
    expect(centre.z, closeTo(0.0, 20.0));
    final right = unprojectViewportToPlaneY(
      local: const Offset(600, 300),
      size: const Size(800, 600),
      yawDeg: 0.0,
      pitchDeg: 89.0,
      distance: 1000.0,
      target: Vector3.zero(),
      planeY: 0.0,
    );
    expect(right!.x, greaterThan(100.0));
    expect(right.y, closeTo(0.0, 1e-9));
    // A camera looking up never hits the floor.
    final miss = unprojectViewportToPlaneY(
      local: const Offset(400, 0),
      size: const Size(800, 600),
      yawDeg: 0.0,
      pitchDeg: 0.0,
      distance: 1000.0,
      target: Vector3(0, 500, 0),
      planeY: 0.0,
    );
    expect(miss, isNull);
  });
}
