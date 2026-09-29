import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The level viewport's Wireframe view mode draws every mesh actor
/// as its edges only, hides the solid renderables, and
/// the header label follows the mode; Lit / Unlit / Wireframe round-trip and
/// the View menu's `setViewportMode` and the toolbar's `setViewMode` are the
/// same field.
final _fixture = '${Directory.current.parent.path}/test-assets/fixtures/YVO3D_44368.glb';

class _Project {
  _Project(this.root, this.lmas, this.mesh);
  final Directory root;
  final String lmas;
  final GlbMeshData mesh;
}

Future<_Project> _project(WidgetTester tester) async {
  final root = Directory.systemTemp.createTempSync('lumina_wireframe_');
  final dir = Directory('${root.path}/Wire/contents/meshes/static')..createSync(recursive: true);
  File('${root.path}/Wire/Wire.lmproject').writeAsStringSync('{"project_name":"Wire"}');
  final lmas = '${dir.path}/SM_Fixture.lmas';
  File(lmas).writeAsBytesSync(
      const LuminaAsset(assetId: 'SM_Fixture', name: 'SM_Fixture', type: AssetType.filamesh).toProtoBufferBytes());
  File('${dir.path}/SM_Fixture.entity.glb').writeAsBytesSync(File(_fixture).readAsBytesSync());
  final mesh = (await tester.runAsync(() => AssetRepository.loadMeshFromDisk(lmas)))!;
  return _Project(root, lmas, mesh);
}

EditorActorNode _actor(String id, _Project p, double x) =>
    EditorActorNode(id: id, name: id, type: 'StaticMesh', location: [x, 0, 0], meshData: p.mesh, meshAssetPath: p.lmas);

/// Pumps until [done] holds — always at least one frame: the
/// Wireframe switch builds its edge meshes synchronously inside the view
/// model's notification, so [done] can already hold before the tree has
/// rebuilt, and the header text only changes on a frame.
Future<void> _settle(WidgetTester tester, bool Function() done, {int frames = 400}) async {
  await tester.pump();
  for (var i = 0; i < frames && !done(); i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
  }
}

void main() {
  final hasFixture = File(_fixture).existsSync();

  test('setViewportMode and setViewMode are one persisted field', () {
    final root = Directory.systemTemp.createTempSync('lumina_wireframe_vm_');
    addTearDown(() => root.deleteSync(recursive: true));
    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'Wire'),
      projectLocation: root.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    expect(vm.viewMode, 'Lit');
    expect(vm.viewportMode, 'Lit');
    vm.setViewMode('Wireframe');
    expect(vm.viewportMode, 'Wireframe', reason: 'the header reads what the toolbar set');
    vm.setViewportMode('Unlit');
    expect(vm.viewMode, 'Unlit', reason: 'the View menu writes what the toolbar reads');
    expect(vm.project.editorViewport.viewMode, 'Unlit', reason: 'persisted with the project');
    vm.setViewportMode('Lit');
    expect(vm.viewMode, 'Lit');
    vm.dispose();
  });

  testWidgets('Wireframe draws edge lines per mesh actor and hides the solids; Unlit and Lit restore them',
      (tester) async {
    final p = await _project(tester);
    addTearDown(() => p.root.deleteSync(recursive: true));
    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'Wire'),
      projectLocation: p.root.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    vm.restoreSnapshot([_actor('a1', p, -200), _actor('a2', p, 200)]);
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: ViewportWidget(viewModel: vm)));
    dynamic viewport() => tester.state(find.byType(ViewportWidget));
    await _settle(tester, () => viewport().editorActorsInSceneForTest == 2);
    expect(viewport().editorActorsInSceneForTest, 2, reason: 'both solids drawn in Lit');
    expect(viewport().meshWiresForTest, isEmpty);
    expect(find.text('Perspective  |  Lit  |  Realtime'), findsOneWidget);
    final FilamentScene scene = viewport().nativeSceneForTest;
    final FilamentEngine engine = viewport().nativeEngineForTest;

    // Toolbar → Wireframe.
    vm.selectActorById('a2');
    vm.setViewMode('Wireframe');
    await _settle(tester, () => viewport().meshWiresForTest.length == 2, frames: 60);
    expect(viewport().meshWiresForTest, {'a1', 'a2'}, reason: 'one wireframe per mesh actor');
    expect(viewport().editorActorsInSceneForTest, 0, reason: 'no filled surface in Wireframe');
    for (final id in ['a1', 'a2']) {
      final int entity = viewport().meshWireEntityForTest(id);
      expect(scene.hasEntity(entity), isTrue, reason: '$id\'s wire is in the scene');
    }
    expect(find.text('Perspective  |  Wireframe  |  Realtime'), findsOneWidget, reason: 'the header follows');

    // The wire sits where the solid was drawn: the solid root's matrix.
    final tm = FilamentTransformManager(engine);
    final wireMatrix = tm.getTransform(viewport().meshWireEntityForTest('a1'));
    expect(wireMatrix[12], closeTo(-200, 1e-3), reason: 'x = the actor\'s location (cm, Y up)');
    expect(wireMatrix[0], closeTo(LuminaUnits.unitsPerMetre, 1e-6), reason: 'glTF metres → cm on the wire too');

    // Unlit: solids back, wires gone.
    vm.setViewMode('Unlit');
    await _settle(tester, () => viewport().editorActorsInSceneForTest == 2, frames: 60);
    expect(viewport().meshWiresForTest, isEmpty);
    expect(viewport().editorActorsInSceneForTest, 2);
    expect(find.text('Perspective  |  Unlit  |  Realtime'), findsOneWidget);

    // Round-trip through the View menu's setter.
    vm.setViewportMode('Wireframe');
    await _settle(tester, () => viewport().meshWiresForTest.length == 2, frames: 60);
    expect(viewport().editorActorsInSceneForTest, 0);
    vm.setViewportMode('Lit');
    await _settle(tester, () => viewport().editorActorsInSceneForTest == 2, frames: 60);
    expect(viewport().meshWiresForTest, isEmpty);
    expect(find.text('Perspective  |  Lit  |  Realtime'), findsOneWidget);

    // Wireframe, then the viewport goes: nothing is left on the engine.
    vm.setViewMode('Wireframe');
    await _settle(tester, () => viewport().meshWiresForTest.length == 2, frames: 60);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(engine.isDisposed, isTrue, reason: 'the last viewport gave the engine back');
    vm.dispose();
  }, skip: !hasFixture);
}
