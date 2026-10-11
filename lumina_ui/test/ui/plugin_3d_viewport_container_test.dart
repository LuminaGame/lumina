import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/plugin_3d_viewport_container.dart';

Directory get _assets => Directory(Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets');

/// A plugin's 3D viewport runs on the UMG Viewport widget: a pick selects
/// the nearest bone (`onBoneSelected`), the bone gizmo's drag reports the
/// moved bone (`onBoneMoved`, glTF frame), ghost skeletons and the joint
/// pose reach the Viewport's description.
void main() {
  final mesh = File('${_assets.path}/mannequin/MM_Idle.glb');

  Future<void> frames(WidgetTester tester, [int n = 1]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
    }
  }

  testWidgets('bone selection, the bone gizmo and ghost skeletons through the adapter', (tester) async {
    if (!mesh.existsSync()) return markTestSkipped('test-assets missing');
    final selected = <String>[];
    final moved = <(String, List<double>, List<double>)>[];
    Widget host(Plugin3DViewportOptions o) => Directionality(
          textDirection: TextDirection.ltr,
          child: Align(alignment: Alignment.topLeft, child: SizedBox(width: 640, height: 480, child: Plugin3DViewportContainer(options: o))),
        );
    Plugin3DViewportOptions options({String? bone, List<PluginGhostSkeleton>? ghosts}) => Plugin3DViewportOptions(
          title: 'Motion',
          meshPath: mesh.path,
          showBones: true,
          selectedBoneName: bone,
          ghostSkeletons: ghosts,
          onBoneSelected: selected.add,
          onBoneMoved: (b, p, d) => moved.add((b, p, d)),
        );
    await tester.pumpWidget(host(options()));
    LuminaUmgViewportState state() => tester.state<LuminaUmgViewportState>(find.byType(LuminaUmgViewport));
    for (var i = 0; i < 300 && !(state().controller?.runtime.isReady == true && state().controller!.runtime.nodeIds.isNotEmpty); i++) {
      await frames(tester);
    }
    final c = state().controller;
    if (c == null) return markTestSkipped('no GPU engine');
    final node = c.scene!.nodes.single['id']! as String;
    expect(c.scene!.skeletonOverlay(node)!['color'], [1.0, 0.85, 0.2, 1.0], reason: 'showBones draws the skeleton');

    // A tap on the head selects the head bone.
    c.runtime.frameNode(node);
    c.frame(1 / 60);
    final head = c.runtime.jointsOf(node).firstWhere((j) => j.name == 'head');
    final (x, y) = c.runtime.project(head.position)!;
    await tester.tapAt(Offset(x, y), kind: PointerDeviceKind.mouse, buttons: kPrimaryMouseButton);
    await frames(tester, 3);
    expect(selected, ['head']);
    expect(c.scene!.gizmo?['bone'], 'head', reason: 'the gizmo sits on the selected bone');

    // Drag the X arrow: onBoneMoved reports the bone, its new position and the delta.
    await tester.pumpWidget(host(options(bone: 'head')));
    await frames(tester, 3);
    final model = luminaViewportGizmoModel(c)!;
    final handles = model.handleScreenPositions()!;
    final centre = handles['CENTER']!;
    final tip = handles['X']!;
    final grab = Offset.lerp(centre, tip, 0.7)!;
    final drag = await tester.startGesture(grab, buttons: kPrimaryMouseButton, kind: PointerDeviceKind.mouse);
    final step = (tip - centre) / (tip - centre).distance * 8;
    for (var i = 0; i < 6; i++) {
      await drag.moveBy(step);
      await frames(tester);
    }
    await drag.up();
    await frames(tester, 2);
    expect(moved, isNotEmpty);
    expect(moved.every((m) => m.$1 == 'head'), isTrue);
    final last = moved.last;
    for (var i = 0; i < 3; i++) {
      expect(last.$2[i], closeTo(last.$3[i] + moved.first.$2[i] - moved.first.$3[i], 1e-6), reason: 'new = start + delta');
    }
    expect(last.$3.map((v) => v.abs()).reduce((a, b) => a + b), greaterThan(0.001), reason: 'the bone moved');

    // Ghost skeletons reach the overlay.
    await tester.pumpWidget(host(options(bone: 'head', ghosts: [
      PluginGhostSkeleton(jointLocalPose: const {}, color: const Color(0xFF66CCFF), label: '15'),
    ])));
    await frames(tester, 2);
    final ghosts = c.scene!.skeletonOverlay(node)!['ghosts']! as List;
    expect(ghosts, hasLength(1));
    expect((ghosts.single as Map)['label'], '15');
    await tester.pumpWidget(const SizedBox());
    await frames(tester, 2);
  });
}
