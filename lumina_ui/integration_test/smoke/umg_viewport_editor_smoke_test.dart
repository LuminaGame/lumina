import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/pie_widget_layer.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/widget_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// UMG Viewport smoke — the Viewport element in the widget designer and in
/// Play. A launcher Third Person project imports the UEFN mannequin and its
/// standing idle from `test-assets/FBX/GameAnimationSample/` through the real
/// importer; WBP_Showcase gets a Viewport `Preview` (the mannequin with its
/// idle as design-time preview content, shown live on the designer canvas)
/// and a Text `Status`; the graph's Construct adds the mannequin, plays the
/// idle and frames it, On Picked (Preview) writes the picked bone into
/// Status. The character's BeginPlay shows the widget; Play (GPU 1), click
/// the mannequin's head, and Status names the bone.
const _scenario = 'viewport element in the widget designer and in Play';

Directory get _assets => Directory(Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(_scenario, (tester) async {
    final meshFbx = File('${_assets.path}/FBX/GameAnimationSample/SKM_UEFN_Mannequin.fbx');
    final idleFbx = File('${_assets.path}/FBX/GameAnimationSample/M_Neutral_Stand_Idle_Loop.fbx');
    if (!meshFbx.existsSync() || !idleFbx.existsSync()) return markTestSkipped('test-assets/FBX/GameAnimationSample missing');
    final root = Directory.systemTemp.createTempSync('lumina_smoke_vp_');
    addTearDown(() async {
      for (var i = 0; i < 40; i++) {
        try {
          if (root.existsSync()) root.deleteSync(recursive: true);
          return;
        } on FileSystemException {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
    });
    const name = 'viewport_smoke';
    final repo = ProjectRepository();
    await tester.runAsync(() async {
      await for (final p in repo.createProjectStream(
          projectName: name, projectLocation: root.path, template: kThirdPersonTemplateId, widgetLibrary: kUmgWidgetLibraryFlutter)) {
        debugPrint('[create] ${p.message}');
      }
    });
    final projectDir = '${root.path}/$name';
    const characterPath = 'contents/blueprints/BP_ThirdPersonCharacter.lmas';

    // The mannequin and its idle through the real FBX importer.
    final mesh = (await tester.runAsync(() => ImportAssetUseCase()(projectDir: projectDir, sourceFilePath: meshFbx.path)))!;
    expect(mesh.isSuccess, isTrue, reason: mesh.error);
    final meshPath = mesh.asset!.relativePath;
    final idle = (await tester.runAsync(
        () => ImportAssetUseCase()(projectDir: projectDir, sourceFilePath: idleFbx.path, targetSkeletonPath: meshPath)))!;
    expect(idle.isSuccess, isTrue, reason: idle.error);
    final idlePath = idle.asset!.relativePath;
    debugPrint('[viewport_smoke] imported $meshPath and $idlePath');

    final project = (await tester.runAsync(() => repo.loadProject('$projectDir/$name.lmproject')))!;
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    final wbpPath = await vm.createWidgetBlueprint(name: 'WBP_Showcase');
    vm.refreshAssets();
    final widgetAsset = vm.realAssets.firstWhere((a) => a.relativePath == wbpPath);

    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> settle([int frames = 12]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
    }

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
    ));
    await settle(30);
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    Future<File> shot(String file) async =>
        SmokeArtifacts.saveScreenshot(file, await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));
    Future<void> holdUntil(bool Function() done, {int max = 300}) async {
      for (var i = 0; i < max && !done(); i++) {
        await settle(2);
        await rec.capture();
      }
    }

    await rec.hold(const Duration(milliseconds: 800));

    // --- Designer: a Viewport with the mannequin as preview, and a Text ------
    vm.openSubEditorTab('WIDGET', asset: widgetAsset);
    await settle(20);
    final umg = (tester.state(find.byType(UMGWidgetSubEditor)) as dynamic).viewModelForTest as UmgEditorViewModel;
    umg.snapToGrid = false;
    final rootId = umg.document.root.id;
    final status = umg.addWidget(UmgWidgetType.text, parentId: rootId, canvasPosition: const Offset(60, 60))!;
    final preview = umg.addWidget(UmgWidgetType.viewport, parentId: rootId, canvasPosition: const Offset(560, 140))!;
    expect(umg.rename(status.id, 'Status'), isTrue);
    expect(umg.rename(preview.id, 'Preview'), isTrue);
    umg.setProp(status.id, 'text', 'Click the mannequin');
    umg.setProp(status.id, 'fontSize', 30.0);
    umg.setCanvasSize(status.id, const Size(700, 56));
    umg.setCanvasSize(preview.id, const Size(640, 640));
    umg.setProp(preview.id, 'previewMesh', meshPath);
    umg.setProp(preview.id, 'previewAnimation', idlePath);
    umg.select(preview.id);
    await settle(10);
    // The canvas shows the design-time content live.
    await holdUntil(() => find.byType(LuminaUmgViewport).evaluate().isNotEmpty);
    final designer = tester.state<LuminaUmgViewportState>(find.byType(LuminaUmgViewport).first);
    await holdUntil(() => designer.controller?.runtime.isReady == true && designer.controller!.runtime.nodeIds.isNotEmpty);
    final framesBefore = designer.controller!.clock.framesRendered;
    await rec.hold(const Duration(milliseconds: 2500));
    debugPrint('[viewport_smoke] designer: count ${find.byType(LuminaUmgViewport).evaluate().length} '
        'failures ${designer.controller!.runtime.failures} path ${designer.path} render ${designer.renderSize} '
        'nodes ${designer.controller!.runtime.nodeIds.toList()} frames $framesBefore → ${designer.controller!.clock.framesRendered} '
        'animating ${designer.controller!.runtime.animating} stats ${designer.frameStats} orbit ${designer.controller!.runtime.orbit.target} ${designer.controller!.runtime.orbit.distance}');
    expect(designer.controller!.clock.framesRendered, greaterThan(framesBefore), reason: 'the idle plays on the canvas');
    await shot('umg_viewport_designer');

    // --- Details ▸ Widget Events: + OnPicked opens the Graph -----------------
    final plus = find.byKey(ValueKey('umg_event_add_OnPicked_${preview.id}'));
    await tester.ensureVisible(plus);
    await settle(6);
    await rec.hold(const Duration(milliseconds: 500));
    await tester.tap(plus);
    await settle(20);
    expect(umg.mode, UmgEditorMode.graph);
    final graph = umg.graphEditor;
    final g = graph.eventGraph;
    final picked = graph.boundEventNode('Preview', 'OnPicked')!;
    final x0 = picked.x;
    final top = picked.y - 420;
    LuminaBlueprintNode add(String id, double dx, double dy, [Map<String, dynamic>? literals]) =>
        g.addNode(id, Offset(x0 + dx, top + dy), literals: literals)!;
    void link(LuminaBlueprintNode from, String fromPin, LuminaBlueprintNode to, String toPin) =>
        expect(g.addWire(fromNodeId: from.id, fromPinId: fromPin, toNodeId: to.id, toPinId: toPin), isNotNull,
            reason: '${from.registryId}.$fromPin → ${to.registryId}.$toPin');
    final construct = add(LuminaBlueprintNodeLibrary.eventWidgetConstruct, 0, 0);
    final view = add(LuminaBlueprintNodeLibrary.getWidgetVariable, 0, 160, {'element': 'Preview'});
    final addHero = add('viewport_add_skeletal_mesh', 300, 0, {'skeletal_mesh': meshPath});
    final play = add('viewport_play_animation', 640, 0, {'animation': idlePath, 'loop': true, 'play_rate': 1.0});
    final frame = add('viewport_frame_node', 980, 0);
    final statusGet = add(LuminaBlueprintNodeLibrary.getWidgetVariable, 300, 560, {'element': 'Status'});
    final label = add('append', 300, 680, {'a': 'Picked: '});
    final show = add('set_element_text', 640, 420);
    await settle(4);
    link(construct, 'exec_out', addHero, 'exec_in');
    link(view, 'return_value', addHero, 'target');
    link(addHero, 'exec_out', play, 'exec_in');
    link(view, 'return_value', play, 'target');
    link(addHero, 'return_value', play, 'node_id');
    link(play, 'exec_out', frame, 'exec_in');
    link(view, 'return_value', frame, 'target');
    link(addHero, 'return_value', frame, 'node_id');
    link(picked, 'exec_out', show, 'exec_in');
    link(statusGet, 'return_value', show, 'target');
    link(picked, 'bone', label, 'b');
    link(label, 'return_value', show, 'in_text');
    await rec.hold(const Duration(milliseconds: 1500));
    await shot('umg_viewport_graph');

    // --- Compile, and the character's BeginPlay shows the widget ------------
    await tester.tap(find.byKey(const ValueKey('umg_compile')));
    for (var i = 0; i < 100 && umg.lastCompile == null && umg.compileError == null; i++) {
      await settle(2);
    }
    expect(umg.compileError, isNull);
    final generated = File('$projectDir/lib/widgets/wbp_showcase.dart').readAsStringSync();
    expect(generated, contains('LuminaUmgViewport('));
    expect(generated, contains('LuminaViewportNodes.addSkeletalMesh(this, '));
    expect(generated, contains("case ('Preview', 'OnPicked'):"));

    final character = BlueprintEditorViewModel(assetPath: '$projectDir/$characterPath');
    addTearDown(character.dispose);
    await tester.runAsync(character.load);
    final cg = character.eventGraph;
    final bottom = character.document.eventGraph.nodes.fold<double>(0, (m, n) => n.y > m ? n.y : m);
    final begin = character.document.eventGraph.nodes.where((n) => n.registryId == 'event_beginplay').firstOrNull ??
        cg.addNode('event_beginplay', Offset(0, bottom + 400))!;
    var tail = begin;
    for (var guard = 0; guard < 64; guard++) {
      final next = character.document.eventGraph.wires
          .where((w) => w.fromNodeId == tail.id && character.document.eventGraph.node(w.toNodeId) != null)
          .where((w) => cg.pin(tail.id, w.fromPinId, output: true)?.type == LuminaPinType.exec)
          .firstOrNull;
      if (next == null) break;
      tail = character.document.eventGraph.node(next.toNodeId)!;
    }
    final tailExec = cg.pinsOf(tail).outputs.firstWhere((p) => p.type == LuminaPinType.exec).id;
    final create = cg.addNode('create_widget', Offset(tail.x + 360, tail.y), literals: {'class': 'WBP_Showcase'})!;
    final addToViewport = cg.addNode('add_to_viewport', Offset(tail.x + 700, tail.y))!;
    expect(cg.addWire(fromNodeId: tail.id, fromPinId: tailExec, toNodeId: create.id, toPinId: 'exec_in'), isNotNull);
    expect(cg.addWire(fromNodeId: create.id, fromPinId: 'exec_out', toNodeId: addToViewport.id, toPinId: 'exec_in'), isNotNull);
    expect(cg.addWire(fromNodeId: create.id, fromPinId: 'return_value', toNodeId: addToViewport.id, toPinId: 'target'), isNotNull);
    expect(await tester.runAsync(character.save), isTrue);

    // --- Play: the widget's Viewport shows the mannequin; click its head ----
    vm.selectTab(0);
    await settle(10);
    await tester.tap(find.byKey(const ValueKey('toolbar_play')));
    for (var i = 0; i < 150 && !vm.pieController.isPlaying; i++) {
      await settle(2);
    }
    final pie = vm.pieController;
    expect(pie.isPlaying, isTrue, reason: 'blocked: ${vm.playBlockers} error: ${pie.lastError}');
    Finder inPie(Finder f) => find.descendant(of: find.byType(PieWidgetLayer), matching: f);
    await holdUntil(() => inPie(find.byType(LuminaUmgViewport)).evaluate().isNotEmpty, max: 120);
    expect(inPie(find.byType(LuminaUmgViewport)), findsOneWidget, reason: 'BeginPlay added WBP_Showcase to the viewport');
    final played = tester.state<LuminaUmgViewportState>(inPie(find.byType(LuminaUmgViewport)));
    await holdUntil(() => played.controller?.runtime.isReady == true && played.controller!.runtime.nodeIds.isNotEmpty);
    final c = played.controller!;
    expect(c.runtime.failures, isEmpty);
    final hero = c.scene!.nodes.firstWhere((n) => n['kind'] == LuminaViewportNodeKind.skeletalMesh)['id']! as String;
    final mannequin = c.runtime.componentOf(hero)! as LuminaAnimatedMeshComponent;
    expect(mannequin.currentClip, isNotNull, reason: 'Play Animation started the idle');
    await tester.sendKeyEvent(LogicalKeyboardKey.f4);
    pie.mouseCapture.release();
    await rec.hold(const Duration(milliseconds: 2000));
    final head = c.runtime.jointsOf(hero).firstWhere((j) => j.name == 'head');
    final (hx, hy) = c.runtime.project(head.position)!;
    final at = tester.getTopLeft(inPie(find.byType(LuminaUmgViewport))) + Offset(hx, hy);
    await tester.tapAt(at, kind: PointerDeviceKind.mouse, buttons: kPrimaryMouseButton);
    await holdUntil(() => inPie(find.textContaining('Picked: ')).evaluate().isNotEmpty, max: 60);
    expect(inPie(find.text('Picked: head')), findsOneWidget, reason: 'On Picked (Preview) wrote the bone into Status');
    // An orbit drag over the Viewport, then the final shot.
    final centre = tester.getCenter(inPie(find.byType(LuminaUmgViewport)));
    final drag = await tester.startGesture(centre + const Offset(0, 200), buttons: kPrimaryMouseButton, kind: PointerDeviceKind.mouse);
    for (var i = 0; i < 30; i++) {
      await drag.moveBy(const Offset(-6, 0));
      await settle(1);
      await rec.capture();
    }
    await drag.up();
    await rec.hold(const Duration(milliseconds: 1500));
    await shot('umg_viewport_pie_picked');
    await tester.tap(find.byKey(const ValueKey('toolbar_stop')));
    await settle(30);
    await rec.hold(const Duration(milliseconds: 600));

    final video = rec.save(_scenario);
    expect(SmokeArtifacts.videoDurationSeconds(video)!, greaterThanOrEqualTo(10.0));
    debugPrint('[viewport_smoke] ${jsonEncode({'widget': wbpPath, 'mesh': meshPath, 'idle': idlePath})}');
  }, timeout: const Timeout(Duration(minutes: 25)));
}

