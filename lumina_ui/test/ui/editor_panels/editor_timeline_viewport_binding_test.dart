import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter_filament/flutter_filament.dart' show FilamentBackend;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart' show PluginBoundViewport;
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/interaction/editor_interaction.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/native_widget_elements.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/timeline/editor_timeline.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

Directory get _assets => Directory(Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets');

/// A Timeline bound to a Viewport node drives that node's animation time
/// on the Viewport's own preview (noop backend, the mannequin skeletal mesh
/// and its idle animation as `.lmas` files in a temp project): scrubbed to
/// frame 45 at 30 fps the node shows 1.5 s, with no event leaving the
/// timeline while it scrubs (no graph run, no process message).
void main() {
  late Directory project;
  const mesh = 'contents/meshes/skeletal/SKM_Mannequin.lmas';
  const idle = 'contents/animations/Idle/Idle.lmas';
  final source = File('${_assets.path}/mannequin/MM_Idle.glb');

  setUp(() {
    if (!source.existsSync()) return;
    project = Directory.systemTemp.createTempSync('lumina_tl_vp_');
    final glb = source.readAsBytesSync();
    final clip = GlbAnimationMerger.animationNames(glb).first;
    void write(String path, LuminaAsset asset) => (File('${project.path}/$path')..parent.createSync(recursive: true)).writeAsBytesSync(asset.toProtoBufferBytes());
    write(mesh, LuminaAsset(assetId: 'mannequin', name: 'SKM_Mannequin', type: AssetType.filameshSk, rawPayload: Uint8List.fromList(glb), metadata: {
      'payload_format': 'glb',
      'animation_clips': clip,
    }));
    File('${project.path}/${mesh.replaceAll('.lmas', '.entity.glb')}').writeAsBytesSync(glb);
    write(idle, LuminaAsset(
      assetId: 'idle',
      name: 'Idle',
      type: AssetType.animation,
      references: const [AssetReference(slotName: 'skeletal_mesh', assetId: 'mannequin', assetPath: mesh)],
      metadata: {'source_mesh': mesh, 'clip_name': clip, 'clip_index': '0'},
    ));
    LuminaAssets.projectDir = project.path;
  });

  tearDown(() {
    LuminaAssets.projectDir = null;
    if (source.existsSync()) project.deleteSync(recursive: true);
  });

  Future<void> frames(WidgetTester tester, [int n = 1]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
    }
  }

  testWidgets('a timeline bound to a Viewport node scrubbed to frame 45 sets the node animation time to 1.5 s locally', (tester) async {
    if (!source.existsSync()) {
      markTestSkipped('test-assets/mannequin missing');
      return;
    }
    // The panel's instance: a Viewport showing the mannequin playing its
    // idle animation, and a Timeline bound to that node.
    final preview = <String, Object?>{'type': 'viewport', 'name': 'Preview', 'visibility': 'Visible'};
    final scene = LuminaViewportScene.of(preview)..gridVisible = false;
    final node = scene.addNode(LuminaViewportNodeKind.skeletalMesh, asset: mesh);
    scene
      ..playAnimation(node, idle)
      ..frameNode(node);
    final timelineState = <String, Object?>{
      'type': 'editorTimeline',
      'name': 'Motion',
      'fps': 30,
      'length': 120,
      'zoom': 4,
      'tracks': [
        {'id': 'body', 'label': 'Full Body', 'kind': 'keys'},
      ],
      'boundViewport': {'element': 'Preview', 'node': node},
    };
    final instance = <String, Object?>{
      'class': 'EPW_Motion',
      'elements': <String, Object?>{'Preview': preview, 'Motion': timelineState},
    };
    final binding = LuminaUmgInstanceBinding(instance);
    final viewports = <String, LuminaViewportController>{};
    final viewportEvents = <String>[];
    final timelineEvents = <EditorWidgetEvent>[];
    final driver = EditorPanelViewportDriver(
      instance: () => instance,
      binding: () => binding,
      viewports: viewports,
      bound: PluginBoundViewport(element: 'Preview', node: node),
    );
    final key = GlobalKey<LuminaUmgViewportState>();
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: LuminaUmgInstanceScope(
          binding: binding,
          child: Column(children: [
            SizedBox(
              height: 400,
              child: LuminaUmgViewport(
                key: key,
                instance: instance,
                name: 'Preview',
                backend: FilamentBackend.noop,
                budget: LuminaViewportBudget(scope: LuminaViewportScope.editor),
                onEvent: (e, _) => viewportEvents.add(e),
                onController: (c) => c == null ? viewports.remove('Preview') : viewports['Preview'] = c,
              ),
            ),
            Expanded(
              child: EditorTimeline(
                name: 'Motion',
                state: timelineState,
                onEvent: timelineEvents.add,
                onState: (changes, {required edit}) {},
                viewport: driver,
              ),
            ),
          ]),
        ),
      ),
    ));
    for (var i = 0; i < 40 && key.currentState?.controller == null; i++) {
      await frames(tester);
    }
    final controller = key.currentState?.controller;
    if (controller == null) {
      markTestSkipped('no native assets');
      return;
    }
    for (var i = 0; i < 200 && !controller.runtime.isReady; i++) {
      await frames(tester);
    }
    final skeletal = controller.runtime.componentOf(node);
    expect(skeletal, isA<LuminaAnimatedMeshComponent>());
    await frames(tester, 4);
    timelineEvents.clear();

    // Scrub the ruler to frame 45 and hold.
    final ruler = tester.getTopLeft(find.byKey(const ValueKey('editor_timeline_Motion_ruler')));
    final g = await tester.startGesture(ruler + const Offset(10 * 4, 10), kind: PointerDeviceKind.mouse, buttons: kPrimaryMouseButton);
    await frames(tester, 2);
    await g.moveTo(ruler + const Offset(45 * 4, 10));
    await frames(tester, 2);
    final time = (skeletal! as LuminaAnimatedMeshComponent).currentTime;
    expect(time, closeTo(1.5, 1e-6), reason: 'frame 45 at 30 fps');
    expect(timelineEvents, isEmpty, reason: 'no event while scrubbing: no graph run, no process message');
    final description = ((LuminaViewportScene.of(preview).json['nodes'] as List).single as Map)['animation'] as Map;
    expect(description['playing'], isFalse, reason: 'the timeline drives the time; the animation no longer runs by itself');
    await g.up();
    await frames(tester, 2);
    expect(description['time'], closeTo(1.5, 1e-6), reason: 'kept in the description when the playhead stops');
    expect(timelineEvents.map((e) => e.event), [LuminaEditorWidgetEvents.onPlayheadChanged]);
    expect(viewportEvents.where((e) => e != LuminaWidgetEvents.onSceneReady), isEmpty);
    await tester.pumpWidget(const SizedBox());
    await frames(tester, 2);
  });
}
