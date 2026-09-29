import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/skeletal_mesh_socket.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/viewport_ray.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

/// A rig with an identity-rotation bone (`[0,0,0,±1]`, or the
/// float-noise variants a MetaHuman export writes for `root` and its
/// corrective bones) must draw its bone and socket overlays without ever
/// handing `Canvas` a NaN `Offset`.
///
/// The Metahuman body (`SKM_Metahuman_Body_Cut_Female`, 256 joints) has 31
/// such nodes; `test-assets/mannequin/SKM_Manny_Simple.glb` has none, so the
/// skeleton here is built the way that export lays its bones out: a `root`
/// with `w = -1` (and 8e-8 of noise in x), a 256-bone chain under it with
/// near-identity leaves, and finite rotations in between.
GlbMeshData _metahumanLikeRig() {
  const boneCount = 256;
  final all = <GlbNode>[];
  GlbNode bone(int i, String name, List<double> rotation, List<GlbNode> children) {
    final n = GlbNode(
      index: i,
      name: name,
      type: GlbNodeType.bone,
      translation: [0.0, i == 0 ? 0.0 : 0.02, 0.0],
      rotation: rotation,
      scale: const [1.0, 1.0, 1.0],
      children: children,
    );
    all.add(n);
    return n;
  }

  // Leaves first so each parent can take its children.
  GlbNode? child;
  for (var i = boneCount - 1; i >= 1; i--) {
    final List<double> rotation = switch (i % 4) {
      // MetaHuman `thigh_correctiveRoot_l`: numerically identity.
      0 => const [1.0841178e-08, -1.4435502e-08, 1.396984e-09, 1.0],
      // Exact identity.
      1 => const [0.0, 0.0, 0.0, 1.0],
      // A finite rotation: 30° about Z.
      2 => [0.0, 0.0, math.sin(math.pi / 12), math.cos(math.pi / 12)],
      // A float32 quaternion whose w overshoots 1 (acos would be NaN).
      _ => const [0.0, 0.0, 0.0, 1.0000001],
    };
    child = bone(i, 'bone_$i', rotation, child == null ? const [] : [child]);
  }
  // MetaHuman `root`: [8.146034e-08, 0, 0, -1].
  final root = bone(0, 'root', const [8.146034e-08, 0.0, 0.0, -1.0], [child!]);
  expect(all.length, boneCount);

  // A small body so the viewport frames it; the skeleton is what matters.
  return GlbMeshData(
    positions: const [0.0, 0.0, 0.0, 0.5, 0.0, 0.0, 0.0, 1.8, 0.0],
    indices: const [0, 1, 2],
    minBounds: const [-0.5, 0.0, -0.5],
    maxBounds: const [0.5, 1.8, 0.5],
    rootNodes: [root],
    allNodes: all,
    skeletonJointIndices: {for (var i = 0; i < boneCount; i++) i},
  );
}

void main() {
  testWidgets('bones and sockets overlays on a 256-bone rig with identity-rotation bones throw nothing',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final rig = _metahumanLikeRig();
    final sockets = [
      SkeletalMeshSocket(name: 'root_socket', parentBone: 'root', relativeLocation: [0.1, 0.0, 0.0]),
      SkeletalMeshSocket(name: 'hand_socket', parentBone: 'bone_255', relativeLocation: [0.0, 0.05, 0.0]),
    ];

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SubEditor3DViewport(
            title: 'Metahuman-like rig',
            glbMesh: rig,
            showBones: true,
            showSockets: true,
            sockets: sockets,
            selectedSocket: sockets.last,
            selectedNode: rig.allNodes[3],
          ),
        ),
      ),
    );
    // Several paints: the report was one exception per frame.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull,
          reason: 'frame $i: the bone/socket overlay must not throw "Offset argument contained a NaN value"');
    }
    expect(find.byType(SubEditor3DViewport), findsOneWidget);
  });

  test('projectWorldToViewport never returns a non-finite offset', () {
    Offset? project(Vector3 p) => projectWorldToViewport(
          worldPos: p,
          size: const Size(800, 600),
          yawDeg: 30,
          pitchDeg: 20,
          distance: 300,
          target: Vector3.zero(),
        );
    expect(project(Vector3(double.nan, 0, 0)), isNull);
    expect(project(Vector3(0, double.infinity, 0)), isNull);
    expect(project(Vector3(0, 0, double.negativeInfinity)), isNull);
    final finite = project(Vector3(10, 20, 30));
    expect(finite, isNotNull);
    expect(finite!.dx.isFinite && finite.dy.isFinite, isTrue);
    expect(
      projectWorldToViewport(
        worldPos: Vector3(10, 20, 30),
        size: const Size(800, 600),
        yawDeg: 30,
        pitchDeg: 20,
        distance: double.nan,
        target: Vector3.zero(),
      ),
      isNull,
    );
  });

  testWidgets('SubEditor3DViewport poses skeleton and mesh when jointDeltas change',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final rig = _metahumanLikeRig();
    var jointDeltas = <String, List<double>>{
      'root': [0.0, 0.0, 0.0, 45.0, 0.0, 0.0, 0.0, 0.0, 0.0],
      'bone_1': [0.0, 5.0, 0.0, 0.0, 30.0, 0.0, 0.0, 0.0, 0.0],
    };

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SubEditor3DViewport(
            title: 'Metahuman-like rig',
            glbMesh: rig,
            showBones: true,
            jointDeltas: jointDeltas,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Update joint deltas (simulating slider change)
    jointDeltas = <String, List<double>>{
      'root': [0.0, 0.0, 0.0, 90.0, 0.0, 0.0, 0.0, 0.0, 0.0],
      'bone_1': [0.0, 10.0, 0.0, 0.0, 60.0, 0.0, 0.0, 0.0, 0.0],
    };

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SubEditor3DViewport(
            title: 'Metahuman-like rig',
            glbMesh: rig,
            showBones: true,
            jointDeltas: jointDeltas,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Reset joint deltas to empty
    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SubEditor3DViewport(
            title: 'Metahuman-like rig',
            glbMesh: rig,
            showBones: true,
            jointDeltas: const {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
