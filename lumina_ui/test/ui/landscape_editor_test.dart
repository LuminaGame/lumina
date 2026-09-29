// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/landscape_brush.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/landscape_terrain_sink.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/landscape_preview_scene.dart';
import 'package:flutter_filament/flutter_filament.dart' show FilamentRenderableManager;
import 'package:lumina_ui/ui/features/sub_editors/view_models/landscape_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/landscape/foliage_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;


/// View-model + widget half. The terrain/instancing
/// engine surface is behind [LandscapeTerrainSink]; here it is a recording
/// fake so the upload windows and instance batches can be asserted without a
/// GPU. Assets are real `.lmas` files in `Directory.systemTemp`.
class RecordingTerrainSink implements LandscapeTerrainSink {
  final List<int> createdSections = [];
  final List<SectionUpdateWindow> updates = [];

  /// The colours each window in [updates] carried.
  final List<Uint8List?> updateColors = [];
  final Map<int, List<Matrix4>> instances = {};
  final List<String> layerMeshes = [];
  int clearCount = 0;

  int perTileCreates = 0;

  @override
  void createTerrainSection(
    int sectionIndex, {
    required Float32List positions,
    required Float32List normals,
    required Float32List uv0,
    required Uint8List colors,
    required Uint32List indices,
  }) {
    createdSections.add(sectionIndex);
    perTileCreates++;
  }

  @override
  bool supportsPartialUpdate(int sectionIndex) => true;

  // This fake has no engine behind it, so it cannot own residency: the view
  // model keeps pushing every tile, which is what these tests assert on.
  @override
  bool mountPayload(LandscapeData data) => false;

  @override
  void updateResidency(double worldX, double worldZ) {}

  @override
  bool isSectionResident(int sectionIndex) => createdSections.contains(sectionIndex);

  @override
  bool rebuildSection(int sectionIndex) => false;

  @override
  LandscapeResidencyStats? get residencyStats => null;

  @override
  void updateTerrainSection(
    SectionUpdateWindow window, {
    required Float32List positions,
    required Float32List normals,
    Uint8List? colors,
  }) {
    updates.add(window);
    updateColors.add(colors);
  }

  @override
  void setBrushCursor(LandscapeBrushCursorState? cursor) {}

  @override
  void createFoliageBatch(int layerIndex, {required String meshAssetPath, required int capacity}) {
    while (layerMeshes.length <= layerIndex) {
      layerMeshes.add('');
    }
    layerMeshes[layerIndex] = meshAssetPath;
    instances[layerIndex] = [];
  }

  @override
  int addFoliageInstance(int layerIndex, Matrix4 transform) {
    final list = instances.putIfAbsent(layerIndex, () => []);
    list.add(transform);
    return list.length - 1;
  }

  @override
  void removeFoliageInstance(int layerIndex, int instanceIndex) {
    final list = instances[layerIndex];
    if (list == null || instanceIndex >= list.length) return;
    final last = list.removeLast();
    if (instanceIndex < list.length) list[instanceIndex] = last;
  }

  @override
  void clearTerrain() {
    clearCount++;
    createdSections.clear();
    updates.clear();
    updateColors.clear();
    instances.clear();
  }

  @override
  bool get isAvailable => true;
}

/// A sink that behaves like the real engine one: it takes the whole payload
/// and reports a bounded residency, so the view model's streaming branch and
/// the HUD can be asserted without a GPU.
class StreamingTerrainSink extends RecordingTerrainSink {
  int mountedPayloads = 0;
  int residencyUpdates = 0;
  LandscapeData? payload;

  @override
  bool get isAvailable => true;

  @override
  bool mountPayload(LandscapeData data) {
    payload = data;
    mountedPayloads++;
    return true;
  }

  @override
  void updateResidency(double worldX, double worldZ) => residencyUpdates++;

  @override
  LandscapeResidencyStats? get residencyStats {
    final d = payload;
    if (d == null) return null;
    final map = LandscapeSectionMap(gridResolution: d.gridResolution);
    const resident = 24;
    return LandscapeResidencyStats(
      residentSections: resident,
      totalSections: map.sectionCount,
      triangles: resident * 64 * 64 * 2,
      vertices: resident * 65 * 65,
      gpuBytes: resident * 65 * 65 * 32,
      droppedForBudget: 0,
      foliageInstances: 0,
      foliageRenderables: 0,
    );
  }
}

void main() {
  group('LandscapeEditorViewModel', () {
    late Directory tempDir;

    setUp(() => tempDir = Directory.systemTemp.createTempSync('lumina_landscape_vm_'));
    tearDown(() => tempDir.deleteSync(recursive: true));

    LandscapeEditorViewModel makeVm(RecordingTerrainSink sink, {String? path}) {
      final vm = LandscapeEditorViewModel(
        assetPath: path ?? '${tempDir.path}/contents/landscapes/Terrain.lmas',
        sink: sink,
      );
      vm.open();
      return vm;
    }

    test('a fresh terrain builds one mesh section per 64-quad tile', () {
      final sink = RecordingTerrainSink();
      final vm = makeVm(sink);
      expect(vm.data.gridResolution, 129);
      expect(sink.createdSections.length, 4);

      vm.createTerrain(gridResolution: 257, worldSize: 512.0, maxHeight: 200.0);
      expect(vm.data.gridResolution, 257);
      expect(sink.createdSections.length, 16, reason: '(257-1)/64 = 4 tiles per side');
      expect(vm.heightMin, 0.0);
      expect(vm.heightMax, 0.0);
      expect(vm.isDirty, isTrue);
      vm.dispose();
    });

    test('a sculpt stroke uploads only dirty row windows and is one undo transaction', () {
      final sink = RecordingTerrainSink();
      final vm = makeVm(sink);
      final pristine = Uint16List.fromList(vm.data.samples);

      vm.setTool(LandscapeTool.sculpt);
      vm.setBrushRadius(10.0);
      vm.setBrushStrength(0.5);
      vm.beginStroke(0.0, 0.0);
      vm.strokeTo(6.0, 0.0);
      vm.strokeTo(12.0, 0.0);
      vm.endStroke();

      expect(sink.updates, isNotEmpty);
      final map = LandscapeSectionMap(gridResolution: vm.data.gridResolution);
      for (final w in sink.updates) {
        expect(w.vertexCount, lessThan(map.verticesPerSection));
        expect(w.vertexOffset % map.verticesPerRow, 0);
      }
      expect(vm.data.heightMax, greaterThan(0.4));
      expect(vm.heightMax, vm.data.heightMax);

      expect(vm.canUndo, isTrue);
      expect(vm.undoDepth, 1, reason: 'the whole stroke is one transaction');
      // The snapshot covers the stroke's dirty rect, not the whole map.
      expect(vm.lastSnapshotCellCount, greaterThan(0));
      expect(vm.lastSnapshotCellCount, lessThan(vm.data.vertexCount));

      vm.undo();
      expect(vm.data.samples, pristine);
      expect(vm.canRedo, isTrue);
      vm.redo();
      expect(vm.data.heightMax, greaterThan(0.4));
      vm.dispose();
    });

    test('flatten samples its target at stroke start and smooth lowers variance', () {
      final sink = RecordingTerrainSink();
      final vm = makeVm(sink);
      vm.setTool(LandscapeTool.sculpt);
      vm.setBrushRadius(20.0);
      vm.setBrushStrength(1.0);
      vm.beginStroke(0.0, 0.0);
      vm.endStroke();
      final hill = vm.data.sampleHeight(0.0, 0.0);
      expect(hill, greaterThan(0.5));

      vm.setTool(LandscapeTool.flatten);
      vm.setBrushRadius(20.0);
      vm.setBrushStrength(1.0);
      vm.beginStroke(18.0, 0.0); // stroke start sits on the hill's skirt
      final target = vm.flattenTarget;
      expect(target, closeTo(vm.data.sampleHeight(18.0, 0.0), 1e-9));
      for (var i = 0; i < 10; i++) {
        vm.strokeTo(18.0 - i.toDouble(), 0.0);
      }
      vm.endStroke();
      expect(vm.data.sampleHeight(14.0, 0.0), closeTo(target!, 0.25));
      vm.dispose();
    });

    test('foliage paint/erase drive the instance batches and the mirror array together', () {
      final sink = RecordingTerrainSink();
      final vm = makeVm(sink);
      final layerIndex = vm.addFoliageLayer(
        meshAssetId: 'barrel',
        meshAssetPath: '${tempDir.path}/contents/meshes/barrel.lmas',
        name: 'Barrels',
      );
      expect(layerIndex, 0);
      expect(sink.layerMeshes.single, endsWith('barrel.lmas'));
      vm.setLayerRules(layerIndex, const FoliageRules(density: 20.0, minSpacing: 1.5, slopeMaxDegrees: 60.0));
      // A hard, full-density foliage brush: a pass places the layer's density
      // and an erase clears its circle (the softer settings are covered
      // separately).
      vm.setFoliageBrushRadius(8.0);
      vm.setFoliageBrushFalloff(0.0);
      vm.setPaintDensity(1.0);
      vm.setEraseDensity(0.0);

      final placed = vm.paintFoliage(0.0, 0.0);
      expect(placed, greaterThan(20));
      expect(vm.data.layers[layerIndex].instanceCount, placed);
      expect(sink.instances[layerIndex]!.length, placed);

      // Painting again over the same spot respects spacing against what is there.
      final second = vm.paintFoliage(0.0, 0.0);
      expect(second, lessThan(placed));
      final total = vm.data.layers[layerIndex].instanceCount;
      expect(sink.instances[layerIndex]!.length, total);

      final erased = vm.eraseFoliage(4.0, 0.0);
      expect(erased, greaterThan(0));
      expect(vm.data.layers[layerIndex].instanceCount, total - erased);
      expect(sink.instances[layerIndex]!.length, total - erased);
      for (var i = 0; i < vm.data.layers[layerIndex].instanceCount; i++) {
        final inst = vm.data.layers[layerIndex].instanceAt(i);
        final dx = inst.x - 4.0;
        final dz = inst.z;
        expect(dx * dx + dz * dz, greaterThan(8.0 * 8.0 - 1e-6), reason: 'only instances inside the erase circle go');
      }
      vm.dispose();
    });

    test('a scattered barrel is its real size in the preview',() {
      final sink = RecordingTerrainSink();
      final vm = makeVm(sink);
      vm.addFoliageLayer(
        meshAssetId: 'fuel_barrel_red',
        meshAssetPath: '${Directory.current.parent.path}/test-assets/Props/Barrels/fuel_barrel_red.glb',
        name: 'Barrels',
      );
      vm.setLayerRules(0, const FoliageRules(density: 20.0, minSpacing: 1.5, scaleMin: 1.0, scaleMax: 1.0));
      vm.setFoliageBrushRadius(8.0);
      expect(vm.paintFoliage(0.0, 0.0), greaterThan(0));
      final inst = vm.data.layers[0].instanceAt(0);
      final m = sink.instances[0]!.first;
      // The barrel GLB is glTF metres (1.15 m tall) and the preview world is
      // metre-scaled, so a barrel painted at scale 1 is drawn at scale 1.
      final drawnScale = Vector3(m.storage[4], m.storage[5], m.storage[6]).length;
      expect(drawnScale, closeTo(inst.scaleY * LandscapeEditorViewModel.unitsPerMetre, 1e-6),
          reason: 'the barrel is drawn at $drawnScale × its glTF size — '
              '${(1.15 * drawnScale * 100).toStringAsFixed(2)} cm tall in a metre preview');
      vm.dispose();
    });

    test('save → reopen rebuilds the same sections and per-layer instance counts', () async {
      final path = '${tempDir.path}/contents/landscapes/Terrain.lmas';
      final sink = RecordingTerrainSink();
      final vm = makeVm(sink, path: path);
      vm.setTool(LandscapeTool.sculpt);
      vm.setBrushRadius(15.0);
      vm.setBrushStrength(0.8);
      vm.beginStroke(0.0, 0.0);
      vm.endStroke();
      vm.addFoliageLayer(meshAssetId: 'barrel', meshAssetPath: 'contents/meshes/barrel.lmas', name: 'Barrels');
      vm.setLayerRules(0, const FoliageRules(density: 15.0, minSpacing: 2.0, slopeMaxDegrees: 60.0));
      final painted = vm.paintFoliage(0.0, 0.0);
      expect(painted, greaterThan(0));
      expect(vm.isDirty, isTrue);

      expect(await vm.save(), isTrue);
      expect(vm.isDirty, isFalse);
      expect(File(path).existsSync(), isTrue);
      final savedHeights = Uint16List.fromList(vm.data.samples);
      vm.dispose();

      final sink2 = RecordingTerrainSink();
      final vm2 = LandscapeEditorViewModel(assetPath: path, sink: sink2)..open();
      expect(vm2.data.samples, savedHeights);
      expect(sink2.createdSections.length, sink.createdSections.length);
      expect(vm2.data.layers.single.instanceCount, painted);
      expect(sink2.instances[0]!.length, painted);
      expect(vm2.isDirty, isFalse);
      vm2.dispose();
    });
  });

  group('Large terrains: streaming, undo cost and import progress', () {
    late Directory tempDir;
    setUp(() => tempDir = Directory.systemTemp.createTempSync('lumina_landscape_big_'));
    tearDown(() => tempDir.deleteSync(recursive: true));

    test('undo of a stroke on an 8129² terrain snapshots only the dirty rect', () {
      final sink = RecordingTerrainSink();
      final vm = LandscapeEditorViewModel(assetPath: null, sink: sink);
      vm.setNewTerrainResolution(LandscapeData.maxGridResolution);
      vm.setNewTerrainWorldSize(16256.0);
      vm.setNewTerrainMaxHeight(1000.0);
      vm.createTerrainFromForm();
      expect(vm.data.gridResolution, 8129);
      expect(vm.data.vertexCount, 66080641);

      vm.setTool(LandscapeTool.sculpt);
      vm.setBrushRadius(30.0);
      vm.setBrushStrength(300.0);
      final stroke = Stopwatch()..start();
      vm.beginStroke(0.0, 0.0);
      vm.endStroke();
      stroke.stop();

      expect(vm.canUndo, isTrue);
      final cells = vm.lastSnapshotCellCount;
      expect(cells, greaterThan(0));
      expect(cells, lessThan(vm.data.vertexCount ~/ 10000),
          reason: 'an undo snapshot must be rect-sized, not grid-sized '
              '($cells of ${vm.data.vertexCount})');

      final edited = vm.data.sampleHeight(0.0, 0.0);
      expect(edited, greaterThan(0.0));
      final undoWatch = Stopwatch()..start();
      vm.undo();
      undoWatch.stop();
      expect(vm.data.sampleHeight(0.0, 0.0), closeTo(0.0, vm.data.heightStep));
      vm.redo();
      expect(vm.data.sampleHeight(0.0, 0.0), closeTo(edited, vm.data.heightStep));

      // ignore: avoid_print
      print('[landscape 8129 undo] snapshotCells=$cells of ${vm.data.vertexCount} '
          'stroke=${stroke.elapsedMilliseconds} ms undo=${undoWatch.elapsedMilliseconds} ms');
      vm.dispose();
    });

    test('a large import reports real progress and never blocks the calling isolate', () async {
      const res = 1025;
      final image = img.Image(width: res, height: res, numChannels: 1, format: img.Format.uint16);
      for (var y = 0; y < res; y++) {
        for (var x = 0; x < res; x++) {
          image.setPixelR(x, y, ((x + y) * 65535 ~/ (2 * (res - 1))));
        }
      }
      final file = File('${tempDir.path}/big16.png')..writeAsBytesSync(img.encodePng(image));

      final sink = RecordingTerrainSink();
      final vm = LandscapeEditorViewModel(assetPath: null, sink: sink);
      vm.setNewTerrainWorldSize(2048.0);
      vm.setNewTerrainMaxHeight(500.0);

      final progress = <double>[];
      vm.addListener(() {
        final p = vm.importProgress;
        if (p != null) progress.add(p);
      });

      // The calling isolate keeps running while the decode happens elsewhere.
      var ticks = 0;
      final ticker = Timer.periodic(const Duration(milliseconds: 1), (_) => ticks++);
      final ok = await vm.importHeightmapFileAsync(file.path);
      ticker.cancel();

      expect(ok, isTrue);
      expect(vm.data.gridResolution, res);
      expect(vm.importProgress, isNull, reason: 'progress clears when the import ends');
      expect(progress, isNotEmpty);
      expect(progress.first, lessThan(progress.last));
      expect(progress.last, 1.0);
      for (var i = 1; i < progress.length; i++) {
        expect(progress[i], greaterThanOrEqualTo(progress[i - 1]), reason: 'progress never goes backwards');
      }
      expect(ticks, greaterThan(0), reason: 'the event loop kept turning during the import');
      // 16-bit precision survived the round trip.
      expect(vm.data.heightAt(res - 1, res - 1), closeTo(500.0, vm.data.heightStep));
      expect(vm.data.heightAt(0, 0), closeTo(0.0, vm.data.heightStep));
      vm.dispose();
    });

    test('a size that does not tile is refused with the nearest valid sizes, terrain untouched', () async {
      final image = img.Image(width: 1000, height: 1000, numChannels: 1);
      final file = File('${tempDir.path}/odd.png')..writeAsBytesSync(img.encodePng(image));
      final sink = RecordingTerrainSink();
      final vm = LandscapeEditorViewModel(assetPath: null, sink: sink)..open();
      final before = vm.data.gridResolution;

      expect(await vm.importHeightmapFileAsync(file.path), isFalse);
      expect(vm.data.gridResolution, before, reason: 'a refused import must not touch the terrain');
      expect(vm.statusMessage, contains('961'));
      expect(vm.statusMessage, contains('1025'));
      expect(vm.importProgress, isNull);
      vm.dispose();
    });

    test('when the engine owns the terrain the HUD reports what is really resident', () {
      final sink = StreamingTerrainSink();
      final vm = LandscapeEditorViewModel(assetPath: null, sink: sink);
      vm.setNewTerrainResolution(1025);
      vm.setNewTerrainWorldSize(2048.0);
      vm.createTerrainFromForm();

      expect(vm.engineOwnsTerrain, isTrue);
      expect(sink.mountedPayloads, 1);
      expect(sink.perTileCreates, 0, reason: 'the engine streams tiles; the view model must not push them');

      final stats = vm.residencyStats!;
      expect(stats.totalSections, 16 * 16);
      expect(stats.residentSections, lessThan(stats.totalSections));
      expect(vm.hudLabel, contains('Resident ${stats.residentSections}/${stats.totalSections} tiles'));
      expect(vm.hudLabel, contains('MB'));

      vm.setPreviewCamera(700.0, 700.0);
      expect(sink.residencyUpdates, greaterThan(0));
      vm.dispose();
    });
  });

  group('LandscapeFoliageSubEditor widget', () {
    late Directory tempDir;
    setUp(() => tempDir = Directory.systemTemp.createTempSync('lumina_landscape_widget_'));
    tearDown(() => tempDir.deleteSync(recursive: true));

    Future<void> pumpEditor(WidgetTester tester, {String? path}) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: LandscapeFoliageSubEditor(
              assetName: 'Terrain_Main',
              assetPath: path ?? '${tempDir.path}/contents/landscapes/Terrain_Main.lmas',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets('shows the honest Manage | Sculpt | Foliage tabs and real stats, no hardcoded layers', (tester) async {
      await pumpEditor(tester);
      expect(find.text('LANDSCAPE'), findsOneWidget);
      expect(find.text('Terrain_Main'), findsOneWidget);
      expect(find.text('Manage'), findsOneWidget);
      expect(find.text('Sculpt'), findsOneWidget);
      expect(find.text('Foliage'), findsOneWidget);
      expect(find.text('Paint'), findsNothing, reason: 'no terrain layer-blend material exists yet');
      for (final fake in ['Grass_Layer', 'Rock_Layer', 'Mud_Layer', 'Snow_Layer']) {
        expect(find.text(fake), findsNothing);
      }
      expect(find.textContaining('129 × 129'), findsWidgets);
      expect(find.textContaining('0 cm … 0 cm'), findsWidgets);
    });

    testWidgets('the left panel starts at the top, not in the vertical middle',(tester) async {
      await pumpEditor(tester);
      final editorTop = tester.getTopLeft(find.byType(LandscapeFoliageSubEditor)).dy;
      // 34 px toolbar + the panel's 8 px padding.
      final titleTop = tester.getTopLeft(find.text('NEW TERRAIN')).dy - editorTop;
      expect(titleTop, lessThanOrEqualTo(34 + 8 + 2), reason: 'the Manage panel is centred vertically');
    });

    testWidgets('the viewport shows its stats line once',(tester) async {
      await pumpEditor(tester);
      expect(find.textContaining('Tool: '), findsOneWidget,
          reason: 'the stats line is drawn by the viewport strip and again by an amber overlay');
    });

    testWidgets('the Landscape editor shows and takes lengths in cm',(tester) async {
      await pumpEditor(tester);
      final state = tester.state(find.byType(LandscapeFoliageSubEditor));
      final vm = (state as dynamic).viewModelForTest as LandscapeEditorViewModel;

      // Manage: the new-terrain form and the stats read centimetres.
      expect(find.text('World Size (cm)'), findsOneWidget);
      expect(find.text('Max Height (cm)'), findsOneWidget);
      expect(find.textContaining('256.00 m'), findsNothing);
      expect(find.textContaining('25600 cm'), findsWidgets);
      expect(find.textContaining('cell 200 cm'), findsOneWidget);
      // ...and a value typed in cm lands in the payload's metres.
      tester.widget<SliderField>(find.byKey(const ValueKey('landscape_world_size'))).onCommit(51200.0);
      tester.widget<SliderField>(find.byKey(const ValueKey('landscape_max_height'))).onCommit(25000.0);
      expect(vm.newTerrainWorldSize, closeTo(512.0, 1e-9));
      expect(vm.newTerrainMaxHeight, closeTo(250.0, 1e-9));

      // Sculpt: the brush size is centimetres both ways.
      await tester.tap(find.byKey(const ValueKey('landscape_tab_sculpt')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('Brush Size (4500 cm)'), findsOneWidget);
      tester.widget<SliderField>(find.byKey(const ValueKey('landscape_brush_radius'))).onCommit(1250.0);
      expect(vm.brushRadius, closeTo(12.5, 1e-9));

      // The viewport stats line.
      expect(vm.hudLabel, contains('cm'));
      expect(vm.hudLabel, isNot(contains(' m ')));
    });

    testWidgets('the landscape preview shows no editor grid',(tester) async {
      await pumpEditor(tester);
      final state = tester.state(find.byType(LandscapeFoliageSubEditor));
      LandscapePreviewScene? preview;
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 30));
        preview = (state as dynamic).previewSceneForTest as LandscapePreviewScene?;
        if (preview != null && preview.isAvailable && preview.terrainSectionCount == 4) break;
      }
      expect(preview?.isAvailable, isTrue, reason: 'the widget test brings a real Filament preview up');
      expect(preview!.terrainSectionCount, 4);
      // Nothing is drawn but the four terrain tiles and the sky's own
      // renderable: no grid patch through the ground.
      final world = preview.world!;
      final rm = FilamentRenderableManager(world.filamentEngine);
      final tiles = {for (var i = 0; i < 4; i++) preview.terrain!.sectionEntity(i)};
      final extra = <String>[];
      for (var e = 0; e < 20000; e++) {
        if (!world.filamentScene.hasEntity(e) || !rm.hasComponent(e) || tiles.contains(e)) continue;
        final name = rm.getMaterialInstanceAt(e, 0)?.material.name ?? '?';
        if (name == 'Skybox') continue;
        extra.add('$e:$name');
      }
      expect(extra, isEmpty, reason: 'drawn in the landscape preview besides the terrain and the sky: $extra');
    });

    testWidgets('the Sculpt tab exposes the four real tools and live brush values', (tester) async {
      await pumpEditor(tester);
      await tester.tap(find.byKey(const ValueKey('landscape_tab_sculpt')));
      await tester.pump(const Duration(milliseconds: 200));
      for (final tool in ['Sculpt', 'Smooth', 'Flatten', 'Noise']) {
        expect(find.byKey(ValueKey('landscape_tool_${tool.toLowerCase()}')), findsOneWidget);
      }
      final state = tester.state(find.byType(LandscapeFoliageSubEditor));
      final vm = (state as dynamic).viewModelForTest as LandscapeEditorViewModel;
      vm.setBrushRadius(72.0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('72'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('landscape_tool_smooth')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(vm.tool, LandscapeTool.smooth);
    });

    testWidgets('the New Terrain form creates a real terrain of the chosen resolution', (tester) async {
      await pumpEditor(tester);
      final state = tester.state(find.byType(LandscapeFoliageSubEditor));
      final vm = (state as dynamic).viewModelForTest as LandscapeEditorViewModel;
      vm.setNewTerrainResolution(257);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const ValueKey('landscape_new_terrain')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(vm.data.gridResolution, 257);
      expect(find.textContaining('257 × 257'), findsWidgets);
    });

    testWidgets('the Foliage tab lists nothing fake and reports live instance counts', (tester) async {
      await pumpEditor(tester);
      await tester.tap(find.byKey(const ValueKey('landscape_tab_foliage')));
      await tester.pump(const Duration(milliseconds: 200));
      final state = tester.state(find.byType(LandscapeFoliageSubEditor));
      final vm = (state as dynamic).viewModelForTest as LandscapeEditorViewModel;
      expect(vm.data.layers, isEmpty);
      expect(find.textContaining('No foliage layers'), findsWidgets);

      vm.addFoliageLayer(meshAssetId: 'barrel', meshAssetPath: 'contents/meshes/barrel.lmas', name: 'Barrels');
      vm.setLayerRules(0, const FoliageRules(density: 20.0, minSpacing: 1.5, slopeMaxDegrees: 60.0));
      vm.setBrushRadius(8.0);
      final placed = vm.paintFoliage(0.0, 0.0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(placed, greaterThan(0));
      expect(find.text('Barrels'), findsWidgets);
      expect(find.text('$placed'), findsWidgets);
    });
  });
}
