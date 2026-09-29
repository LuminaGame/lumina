import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/services/editor_mesh_budget.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The level viewport and the sub-editor viewports draw on one
/// Filament engine and share mesh uploads through lumina's engine-scoped
/// cache.
final _fixture = '${Directory.current.parent.path}/test-assets/fixtures/YVO3D_44368.glb';

class _Project {
  _Project(this.root, this.lmas, this.mesh);
  final Directory root;
  final String lmas;
  final GlbMeshData mesh;
}

/// A real project on disk whose `contents/meshes/static/SM_Fixture.lmas` has
/// the textured fixture as its `.entity.glb` companion, loaded the way the
/// editor loads a placed mesh (`AssetRepository.loadMeshFromDisk`).
Future<_Project> _project(WidgetTester tester) async {
  final root = Directory.systemTemp.createTempSync('lumina_shared_engine_');
  final dir = Directory('${root.path}/SharedEngine/contents/meshes/static')..createSync(recursive: true);
  File('${root.path}/SharedEngine/SharedEngine.lmproject').writeAsStringSync('{"project_name":"SharedEngine"}');
  final lmas = '${dir.path}/SM_Fixture.lmas';
  File(lmas).writeAsBytesSync(
      const LuminaAsset(assetId: 'SM_Fixture', name: 'SM_Fixture', type: AssetType.filamesh).toProtoBufferBytes());
  File('${dir.path}/SM_Fixture.entity.glb').writeAsBytesSync(File(_fixture).readAsBytesSync());
  final mesh = (await tester.runAsync(() => AssetRepository.loadMeshFromDisk(lmas)))!;
  return _Project(root, lmas, mesh);
}

EditorActorNode _actor(String id, _Project p, double x) =>
    EditorActorNode(id: id, name: id, type: 'StaticMesh', location: [x, 0, 0], meshData: p.mesh, meshAssetPath: p.lmas);

EditorViewModel _vm(Directory root) => EditorViewModel(
      initialProject: const LuminaProject(projectName: 'SharedEngine'),
      projectLocation: root.path,
      enableTimers: false,
      autoInitAssets: false,
    );

Future<void> _settle(WidgetTester tester, bool Function() done, {int frames = 400}) async {
  for (var i = 0; i < frames && !done(); i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
  }
}

FilamentEngine? _engine() => FilamentEngineHost.liveEngines.where((e) => !e.isDisposed).firstOrNull;
LuminaMeshCacheEntryInfo? _entry() {
  final engine = _engine();
  if (engine == null) return null;
  return LuminaMeshAssetCache.existingFor(engine)?.entries.where((e) => e.sourcePath.endsWith('SM_Fixture.entity.glb')).firstOrNull;
}

void main() {
  final hasFixture = File(_fixture).existsSync();

  setUp(() {
    // Whatever an earlier test's thumbnail renderer holds is not ours.
    FilamentThumbnailRenderer.shared.dispose();
  });

  testWidgets('two level actors placing one mesh draw instances of one upload', (tester) async {
    final p = await _project(tester);
    addTearDown(() => p.root.deleteSync(recursive: true));
    final vm = _vm(p.root);
    vm.restoreSnapshot([_actor('a1', p, -200), _actor('a2', p, 200)]);
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: ViewportWidget(viewModel: vm)));
    await _settle(tester, () => (_entry()?.handles ?? 0) >= 2);
    final engine = _engine()!;
    expect(FilamentEngineHost.liveEngineCount, 1);
    expect(_entry()!.handles, 2, reason: 'one instance per actor');
    expect(LuminaMeshAssetCache.existingFor(engine)!.uploadCount, 1, reason: 'the mesh is uploaded once');
    expect(EditorMeshBudget.isInstalled, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(engine.isDisposed, isTrue, reason: 'the last viewport gave the engine back');
    vm.dispose();
  }, skip: !hasFixture);

  testWidgets('a sub-editor on the level\'s mesh shares its engine and upload; closing it leaves nothing behind',
      (tester) async {
    final p = await _project(tester);
    addTearDown(() => p.root.deleteSync(recursive: true));
    final vm = _vm(p.root);
    vm.restoreSnapshot([_actor('a1', p, 0)]);
    tester.view.physicalSize = const Size(1600, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    Widget app({required bool subEditor}) => ShadcnApp(
          theme: luminaEditorTheme(),
          home: Row(children: [
            Expanded(child: ViewportWidget(viewModel: vm)),
            if (subEditor)
              Expanded(
                child: SubEditor3DViewport(title: 'Static Mesh', glbMesh: p.mesh, meshSourcePath: p.lmas),
              ),
          ]),
        );

    await tester.pumpWidget(app(subEditor: false));
    await _settle(tester, () => (_entry()?.handles ?? 0) >= 1);
    final engine = _engine()!;
    // A few frames so the level viewport's render targets exist.
    await _settle(tester, () => false, frames: 20);
    final levelOnly = engine.resourceCounts;

    await tester.pumpWidget(app(subEditor: true));
    await _settle(tester, () => (_entry()?.handles ?? 0) >= 2);
    expect(FilamentEngineHost.liveEngineCount, 1, reason: 'one engine for both viewports');
    expect(FilamentEngineHost.leaseOwners(engine),
        containsAll(['Level viewport', 'Level viewport state', 'SubEditor3DViewport', 'SubEditor3DViewport state']));
    expect(LuminaMeshAssetCache.existingFor(engine)!.uploadCount, 1, reason: 'the sub-editor uploads nothing');
    final both = engine.resourceCounts;
    // The fixture has three textures; the sub-editor's only new texture is
    // its own image-based light's cubemap.
    expect((both - levelOnly).textures, (both - levelOnly).indirectLights, reason: 'no second copy of the mesh textures: ${(both - levelOnly).nonZero}');
    expect((both - levelOnly).views, 1);
    expect((both - levelOnly).lights, 3, reason: 'the sub-editor studio rig');

    await tester.pumpWidget(app(subEditor: false));
    await _settle(tester, () => false, frames: 10);
    expect(engine.isDisposed, isFalse, reason: 'the level viewport keeps drawing');
    final after = engine.resourceCounts - levelOnly;
    for (final (name, value) in [
      ('views', after.views),
      ('scenes', after.scenes),
      ('swapChains', after.swapChains),
      ('lights', after.lights),
      ('renderables', after.renderables),
      ('textures', after.textures),
      ('skyboxes', after.skyboxes),
      ('indirectLights', after.indirectLights),
    ]) {
      expect(value, 0, reason: 'closing the sub-editor left $name behind: ${after.nonZero}');
    }
    expect(_entry()!.handles, 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(engine.isDisposed, isTrue);
    vm.dispose();
  }, skip: !hasFixture);

  testWidgets('a preview world loading the mesh by path shares the level viewport\'s budgeted upload', (tester) async {
    final p = await _project(tester);
    addTearDown(() => p.root.deleteSync(recursive: true));
    final vm = _vm(p.root);
    vm.restoreSnapshot([_actor('a1', p, 0)]);
    tester.view.physicalSize = const Size(1600, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    LuminaStaticMeshComponent? previewMesh;

    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Row(children: [
        Expanded(child: ViewportWidget(viewModel: vm)),
        Expanded(
          child: SubEditor3DViewport(
            title: 'Blueprint',
            onPreviewWorldReady: (world) {
              previewMesh = LuminaStaticMeshComponent(meshAssetPath: p.lmas);
              world.persistentLevel.registerActor(LuminaActor(root: previewMesh!));
            },
          ),
        ),
      ]),
    ));
    await _settle(tester, () => (_entry()?.handles ?? 0) >= 2 && (previewMesh?.isLoaded ?? false));
    expect(previewMesh?.isLoaded, isTrue);
    final engine = _engine()!;
    final cache = LuminaMeshAssetCache.existingFor(engine)!;
    expect(cache.uploadCount, 1, reason: 'the budget filter gives the path-based load the level viewport\'s bytes');
    expect(_entry()!.handles, 2);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(engine.isDisposed, isTrue);
    vm.dispose();
  }, skip: !hasFixture);

  testWidgets('the last viewport frees its wireframe, section materials and meshes before the engine goes',
      (tester) async {
    final p = await _project(tester);
    addTearDown(() => p.root.deleteSync(recursive: true));
    FilamentMaterialBuilder.initEngine();
    final builder = FilamentMaterialBuilder.create()
      ..setName('SectionRed')
      ..setShading(FilamatShading.unlit)
      ..setCode('void material(inout MaterialInputs material) { prepareMaterial(material); material.baseColor = vec4(1.0, 0.1, 0.1, 1.0); }');
    final red = builder.build();
    builder.dispose();
    expect(red, isNotNull);
    final node = p.mesh.allNodes.firstWhere((n) => n.meshIndex != null);

    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: SubEditor3DViewport(
        title: 'Static Mesh',
        glbMesh: p.mesh,
        selectedNode: node,
        sectionMaterialOverrides: {0: red!},
      ),
    ));
    await _settle(tester, () => (_entry()?.handles ?? 0) >= 1);
    await _settle(tester, () => false, frames: 20);
    final engine = _engine()!;
    expect(FilamentEngineHost.leaseCount(engine), 2);

    // The FilamentWidget child is disposed before the viewport's own State;
    // the viewport's lease keeps the engine until it has freed everything.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(engine.isDisposed, isTrue);
    expect(FilamentEngineHost.liveEngineCount, 0);
  }, skip: !hasFixture);

  testWidgets('a new GPU preference gives new viewports a new engine; open ones keep theirs', (tester) async {
    final before = FilamentEngine.defaultGpuPreference;
    addTearDown(() => FilamentEngine.defaultGpuPreference = before);
    final devices = FilamentGpu.listVulkanDevices();
    if (devices.length < 2) {
      markTestSkipped('needs two Vulkan devices');
      return;
    }
    FilamentEngine? first;
    FilamentEngine? second;
    Widget app({required bool two}) => ShadcnApp(
          theme: luminaEditorTheme(),
          home: Row(children: [
            Expanded(
                child: SubEditor3DViewport(
              title: 'A',
              onPreviewWorldReady: (w) => first = w.filamentEngine,
            )),
            if (two)
              Expanded(
                  child: SubEditor3DViewport(
                title: 'B',
                onPreviewWorldReady: (w) => second = w.filamentEngine,
              )),
          ]),
        );
    FilamentEngine.defaultGpuPreference = FilamentGpuPreference(deviceName: devices[0].name);
    await tester.pumpWidget(app(two: false));
    await _settle(tester, () => first != null);
    FilamentEngine.defaultGpuPreference = FilamentGpuPreference(deviceName: devices[1].name);
    await tester.pumpWidget(app(two: true));
    await _settle(tester, () => second != null);
    expect(identical(first, second), isFalse);
    expect(first!.gpuName, devices[0].name);
    expect(second!.gpuName, devices[1].name);
    expect(FilamentEngineHost.liveEngineCount, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(FilamentEngineHost.liveEngineCount, 0);
  });
}
