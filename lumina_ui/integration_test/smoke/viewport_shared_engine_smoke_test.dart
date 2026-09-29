import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Shared engine smoke — every editor viewport on one Filament engine, and
/// the FaceMesh smoke.
///
/// `SKM_TestChar_FaceMesh.glb` (fourteen 8192² textures, ~4.67 GB of VRAM
/// unbudgeted) lives outside the repo: `LUMINA_FACEMESH_GLB`, else
/// [_defaultFaceMesh]. Missing → both scenarios are skipped with a message.
///
/// The window shows what the run is doing (a status line over the editor)
/// from the first frame on; the long steps (the import's 8K downscale, mesh
/// loads) keep pumping frames and are bounded, so a run cannot hold the
/// shared test lock indefinitely.
///
/// Runs on GPU 1 (NVIDIA RTX PRO 2000) — `tool/smoke_report.dart` injects the
/// GPU environment. VRAM is this process's usage on GPU 1, from nvidia-smi and
/// from the engine's `VK_EXT_memory_budget` readback.
final String _faceMesh = Platform.environment['LUMINA_FACEMESH_GLB'] ?? '';
const _usedAssets = ['SKM_TestChar_FaceMesh.glb (outside the repo: 14 × 8192² textures)'];

String? _gpu1Uuid;

/// This process's memory on GPU 1 as nvidia-smi reports it (MiB).
int? _nvidiaSmiMiB() {
  try {
    _gpu1Uuid ??= () {
      final r = Process.runSync('nvidia-smi', ['--query-gpu=index,uuid', '--format=csv,noheader']);
      for (final line in '${r.stdout}'.split('\n')) {
        final parts = line.split(',').map((s) => s.trim()).toList();
        if (parts.length == 2 && parts[0] == '1') return parts[1];
      }
      return null;
    }();
    final r = Process.runSync(
        'nvidia-smi', ['--query-compute-apps=pid,used_memory,gpu_uuid', '--format=csv,noheader,nounits']);
    int? total;
    for (final line in '${r.stdout}'.split('\n')) {
      final parts = line.split(',').map((s) => s.trim()).toList();
      if (parts.length == 3 && parts[0] == '$pid' && parts[2] == _gpu1Uuid) {
        total = (total ?? 0) + (int.tryParse(parts[1]) ?? 0);
      }
    }
    return total;
  } catch (_) {
    return null;
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final hasFaceMesh = _faceMesh.isNotEmpty && File(_faceMesh).existsSync();
  final skip = hasFaceMesh ? null : 'SKM_TestChar_FaceMesh.glb not found at $_faceMesh (set LUMINA_FACEMESH_GLB)';
  if (skip != null) {
    // ignore: avoid_print
    print('SKIP viewport shared engine smoke: $skip');
  }

  /// Boots the editor on a fresh temp project with a status line, imports the
  /// face mesh (optionally replacing its budgeted `.entity.glb` with the raw
  /// 8K source, as an import from before texture budgeting left it) and places it.
  Future<_Run> boot(WidgetTester tester, {required String label, required bool unbudgetedCompanion}) async {
    final status = ValueNotifier<String>('Preparing a temp project for $label…');
    final root = Directory.systemTemp.createTempSync('lumina_smoke_shared_engine_');
    addTearDown(() => root.deleteSync(recursive: true));
    final pDir = Directory('${root.path}/SharedEngine')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SharedEngine', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SharedEngine.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path);
    addTearDown(vm.dispose);

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(
        theme: luminaEditorTheme(),
        home: Stack(children: [
          Positioned.fill(child: MainEditorView(viewModel: vm)),
          // What the smoke is doing, over the editor, so the window never
          // sits unexplained during a long step.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: ValueListenableBuilder<String>(
                valueListenable: status,
                builder: (_, text, _) => Container(
                  color: const Color(0xE0101418),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('shared engine smoke — $text',
                      style: const TextStyle(color: Color(0xFFFFD166), fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ]),
      ),
    ));
    final run = _Run(tester, binding, vm, pDir, status, boundaryKey);
    await run.settle(20);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    await run.settle(20);
    return run;
  }

  testWidgets('Viewport Shared Engine Smoke: level viewport and two sub-editors on one heavy mesh share one engine',
      (tester) async {
    const testName = 'Viewport Shared Engine Smoke: level viewport and two sub-editors on one heavy mesh share one engine';
    final run = await boot(tester, label: 'the measurement', unbudgetedCompanion: false);
    final rec = run.recorder();
    await run.sample('editor open', rec);

    final mesh = await run.importFaceMesh(unbudgetedCompanion: false);
    await run.sample('imported', rec);

    run.status.value = 'Placing SKM_TestChar_FaceMesh in the level viewport…';
    await tester.runAsync(() => run.vm.spawnActorFromAsset(mesh));
    await run.until('the level viewport draws the face mesh', () => (run.faceEntry()?.handles ?? 0) >= 1,
        limit: const Duration(minutes: 3), rec: rec);
    await run.sample('level viewport draws the mesh', rec);
    final engine = run.engine!;

    run.status.value = 'Opening the Skeletal Mesh editor on SKM_TestChar_FaceMesh…';
    run.vm.openSubEditorTab('SKELETAL', asset: mesh);
    await run.until('the Skeletal Mesh editor draws it', () => (run.faceEntry()?.handles ?? 0) >= 2,
        limit: const Duration(minutes: 3), rec: rec);
    await run.sample('+ Skeletal Mesh editor', rec);

    final bp = await run.openBlueprintOn(mesh, rec);
    await run.until('the Blueprint preview draws it', () => (run.faceEntry()?.handles ?? 0) >= 3,
        limit: const Duration(minutes: 3), rec: rec);
    await run.sample('+ Blueprint editor 3D Viewport', rec);
    SmokeArtifacts.saveScreenshot('viewport_shared_engine_blueprint_on_face_mesh', await run.capture(),
        usedAssets: _usedAssets);

    expect(FilamentEngineHost.liveEngineCount, 1, reason: 'every viewport and the thumbnails share one engine');
    // ignore: avoid_print
    print('Engine leases: ${FilamentEngineHost.leaseOwners(engine)}');
    final cache = LuminaMeshAssetCache.existingFor(engine)!;
    // ignore: avoid_print
    print('Mesh cache: ${cache.entries}');
    expect(run.faceEntry()!.handles, 3, reason: 'level actor, Skeletal Mesh editor and Blueprint preview: 3 instances');
    expect(cache.entries.where((e) => e.sourcePath.contains('SKM_TestChar_FaceMesh')), hasLength(1),
        reason: 'one upload of the face mesh');
    expect(bp.preview.diagnostics.where((d) => d.isError), isEmpty);

    run.vm.selectTab(0);
    await run.hold(rec, const Duration(seconds: 2));
    await run.sample('back on the level tab', rec);
    SmokeArtifacts.saveScreenshot('viewport_shared_engine_level_tab', await run.capture(), usedAssets: _usedAssets);
    run.writeSamples('after_budgeted');
    rec.save(testName, usedAssets: _usedAssets);
  }, skip: skip != null, timeout: const Timeout(Duration(minutes: 12)));

  testWidgets('Viewport Shared Engine Smoke: FaceMesh in the Blueprint viewport with the level viewport open',
      (tester) async {
    const testName = 'Viewport Shared Engine Smoke: FaceMesh in the Blueprint viewport with the level viewport open';
    final run = await boot(tester, label: 'the FaceMesh smoke', unbudgetedCompanion: true);
    final rec = run.recorder();
    await run.sample('editor open', rec);

    final mesh = await run.importFaceMesh(unbudgetedCompanion: true);
    await run.sample('imported (unbudgeted 8K .entity.glb)', rec);

    run.status.value = 'Placing the 8K SKM_TestChar_FaceMesh in the level viewport (budgeted on load)…';
    await tester.runAsync(() => run.vm.spawnActorFromAsset(mesh));
    await run.until('the level viewport draws the face mesh', () => (run.faceEntry()?.handles ?? 0) >= 1,
        limit: const Duration(minutes: 4), rec: rec);
    await run.sample('level viewport draws the mesh', rec);

    final bp = await run.openBlueprintOn(mesh, rec);
    await run.until('the Blueprint preview draws it', () => (run.faceEntry()?.handles ?? 0) >= 2,
        limit: const Duration(minutes: 3), rec: rec);
    await run.sample('+ Blueprint editor 3D Viewport', rec);
    final engine = run.engine!;
    expect(FilamentEngineHost.liveEngineCount, 1);
    expect(bp.preview.diagnostics.where((d) => d.isError), isEmpty);
    // Budgeted: 14 × 2048² RGBA8 with mips is ~300 MB; unbudgeted it is 4.67 GB.
    final memory = engine.gpuMemory;
    if (memory != null) {
      expect(memory.usageMiB, lessThan(2048), reason: 'the 8K companion is drawn budgeted ($memory)');
    }
    final png = await run.capture();
    SmokeArtifacts.saveScreenshot('viewport_shared_engine_face_mesh_blueprint', png, usedAssets: _usedAssets);

    // Orbit the Blueprint's view a little: the process is alive and drawing.
    final rect = tester.getRect(find.byType(SubEditor3DViewport).last);
    await rec.drag(rect.center + const Offset(-100, 10), rect.center + const Offset(120, 30), steps: 45);
    run.vm.selectTab(0);
    await run.hold(rec, const Duration(seconds: 2));
    await run.sample('back on the level tab', rec);
    SmokeArtifacts.saveScreenshot('viewport_shared_engine_face_mesh_level', await run.capture(), usedAssets: _usedAssets);
    run.writeSamples('after_unbudgeted');
    rec.save(testName, usedAssets: _usedAssets);
  }, skip: skip != null, timeout: const Timeout(Duration(minutes: 12)));
}

class _Run {
  _Run(this.tester, this.binding, this.vm, this.projectDir, this.status, this.boundaryKey);
  final WidgetTester tester;
  final IntegrationTestWidgetsFlutterBinding binding;
  final EditorViewModel vm;
  final Directory projectDir;
  final ValueNotifier<String> status;
  final GlobalKey boundaryKey;
  final List<Map<String, Object?>> samples = [];

  SmokeRecorder recorder() => SmokeRecorder(tester, boundary: find.byKey(boundaryKey));

  FilamentEngine? get engine => FilamentEngineHost.liveEngines.where((e) => !e.isDisposed).firstOrNull;

  LuminaMeshCacheEntryInfo? faceEntry() {
    final e = engine;
    if (e == null) return null;
    return LuminaMeshAssetCache.existingFor(e)
        ?.entries
        .where((x) => x.sourcePaths.any((p) => p.contains('SKM_TestChar_FaceMesh')))
        .firstOrNull;
  }

  Future<void> settle([int frames = 12]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
    }
  }

  Future<void> hold(SmokeRecorder rec, Duration d) => rec.hold(d);

  Future<Uint8List> capture() =>
      SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));

  /// Pumps (and records a frame every ~0.5 s) until [done], failing after [limit].
  Future<void> until(String what, bool Function() done, {required Duration limit, SmokeRecorder? rec}) async {
    status.value = 'Waiting: $what…';
    final clock = Stopwatch()..start();
    var lastFrame = Duration.zero;
    while (!done()) {
      if (clock.elapsed > limit) {
        fail('Timed out after ${limit.inSeconds} s waiting for: $what');
      }
      await settle(4);
      if (rec != null && clock.elapsed - lastFrame > const Duration(milliseconds: 500)) {
        lastFrame = clock.elapsed;
        await rec.captureIfChanged();
      }
    }
  }

  /// Runs [work] (real async) while the window keeps drawing its status line.
  Future<T> busy<T>(String what, Future<T> Function() work, {required Duration limit}) async {
    status.value = what;
    late Future<T> future;
    T? result;
    Object? error;
    var finished = false;
    await tester.runAsync(() async {
      future = work();
      unawaited(future.then((v) {
        result = v;
        finished = true;
      }, onError: (Object e) {
        error = e;
        finished = true;
      }));
    });
    final clock = Stopwatch()..start();
    while (!finished) {
      if (clock.elapsed > limit) fail('Timed out after ${limit.inSeconds} s: $what');
      await settle(3);
      status.value = '$what (${clock.elapsed.inSeconds} s)';
    }
    if (error != null) throw error!;
    return result as T;
  }

  Future<RealAssetInfo> importFaceMesh({required bool unbudgetedCompanion}) async {
    await busy('Importing SKM_TestChar_FaceMesh (205 MB, 14 × 8192² textures, downscaled to 2048²)…',
        () => vm.processImportPipeline(sourceFilePath: _faceMesh),
        limit: const Duration(minutes: 5));
    vm.refreshAssets();
    final mesh = vm.realAssets.firstWhere(
      (a) => (a.type == AssetType.filamesh || a.type == AssetType.filameshSk) &&
          a.fileName.toLowerCase().contains('facemesh'),
      orElse: () => throw StateError('the face mesh import produced no mesh asset'),
    );
    if (unbudgetedCompanion) {
      // What an import from before texture budgeting left on disk: the raw 8K GLB as
      // the mesh's .entity.glb.
      final companion = File(mesh.lmasPath!.replaceAll('.lmas', '.entity.glb'));
      await busy('Replacing the .entity.glb with the unbudgeted 8K source (an import from before texture budgeting)…',
          () => File(_faceMesh).copy(companion.path), limit: const Duration(minutes: 1));
    }
    return mesh;
  }

  /// A real Blueprint (.lmas) whose skeletal mesh component is the face mesh,
  /// opened in the Blueprint editor's 3D Viewport.
  Future<dynamic> openBlueprintOn(RealAssetInfo mesh, SmokeRecorder rec) async {
    status.value = 'Opening BP_FaceMesh (a Skeletal Mesh component on SKM_TestChar_FaceMesh) in the Blueprint editor…';
    final bpDir = Directory('${projectDir.path}/contents/blueprints')..createSync(recursive: true);
    final meshRel = mesh.lmasPath!.substring(projectDir.path.length + 1);
    final doc = LuminaBlueprintDocument(components: [
      LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
      LuminaBlueprintComponent(
        id: 'mesh',
        name: 'FaceMesh',
        type: 'LuminaSkeletalMeshComponent',
        parentId: 'root',
        properties: {'skeletalMeshAsset': meshRel},
      ),
    ]);
    final json = doc.toFormattedJson();
    File('${bpDir.path}/BP_FaceMesh.lmas').writeAsBytesSync(LuminaAsset(
      assetId: 'BP_FaceMesh',
      name: 'BP_FaceMesh',
      type: AssetType.actor,
      rawPayload: Uint8List.fromList(utf8.encode(json)),
      rawMatSource: json,
      metadata: const {'parent_class': 'LuminaActor'},
    ).toProtoBufferBytes());
    vm.refreshAssets();
    final bpAsset = vm.realAssets.firstWhere((a) => a.fileName.startsWith('BP_FaceMesh'));
    vm.openSubEditorTab('Blueprint', asset: bpAsset);
    await until('the Blueprint editor opens', () => find.byType(BlueprintSubEditor).evaluate().isNotEmpty,
        limit: const Duration(seconds: 30), rec: rec);
    await settle(10);
    final bp = tester.state<BlueprintSubEditorState>(find.byType(BlueprintSubEditor)).viewModel;
    await tester.tap(find.text('3D Viewport'));
    await settle(6);
    return bp;
  }

  /// Records this process's VRAM on GPU 1 at [step] (nvidia-smi and the
  /// engine's own budget readback), holding the view for the video.
  Future<void> sample(String step, SmokeRecorder rec) async {
    await rec.hold(const Duration(milliseconds: 1500));
    var smi = 0;
    for (var i = 0; i < 3; i++) {
      smi = [smi, _nvidiaSmiMiB() ?? 0].reduce((a, b) => a > b ? a : b);
      await rec.hold(const Duration(milliseconds: 300));
    }
    final e = engine;
    final memory = e?.gpuMemory;
    final counts = e?.resourceCounts;
    samples.add({
      'step': step,
      'nvidiaSmiMiB': smi,
      'engineUsageMiB': memory == null ? null : double.parse(memory.usageMiB.toStringAsFixed(1)),
      'engines': FilamentEngineHost.liveEngineCount,
      'textures': counts?.textures,
      'faceMeshHolders': faceEntry()?.handles,
    });
    // ignore: avoid_print
    print('VRAM ${samples.last}');
  }

  void writeSamples(String label) {
    final out = File('${Directory.systemTemp.path}/vram_$label.json');
    out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(samples));
    // ignore: avoid_print
    print('VRAM samples written to ${out.path}');
  }
}
