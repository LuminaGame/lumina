import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/skeletal_mesh_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/skeletal_mesh/skeletal_mesh_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Quaternion, Vector3;

import '../helpers/temp_project.dart';

/// A socket's Preview Asset is attached in the Skeletal Mesh
/// editor's preview at `entityWorld × G_bone × offset`
/// and picked from the project's meshes, not typed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final assets = '${Directory.current.parent.path}/test-assets';
  final mannyGlb = File('$assets/mannequin/SKM_Manny_Simple.glb');
  final cardGlb = File('$assets/Props/Access_cards/access_card_blue.glb');
  const card = 'contents/meshes/static/access_card_blue.lmas';

  late Directory root;
  late String project;
  late String mannyLmas;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_socket_preview_');
    project = '${root.path}/SocketProject';
    Directory('$project/contents').createSync(recursive: true);
    if (!mannyGlb.existsSync() || !cardGlb.existsSync()) return;
    final repo = AssetRepository();
    final manny = await repo.importExternalFile(projectPath: project, sourceFilePath: mannyGlb.path);
    mannyLmas = manny.lmasPath!;
    final cardInfo = await repo.importExternalFile(projectPath: project, sourceFilePath: cardGlb.path);
    expect(cardInfo.relativePath, card);
  });

  tearDownAll(() => deleteTempProject(root));

  /// `G_hand_r` read straight from the GLB's node TRS, parent to child.
  Matrix4 handGlobalFromGlb() {
    final bytes = mannyGlb.readAsBytesSync();
    final length = ByteData.sublistView(bytes).getUint32(12, Endian.little);
    final gltf = jsonDecode(utf8.decode(bytes.sublist(20, 20 + length))) as Map<String, dynamic>;
    final nodes = (gltf['nodes'] as List).cast<Map<String, dynamic>>();
    final parentOf = <int, int>{};
    for (var i = 0; i < nodes.length; i++) {
      for (final c in (nodes[i]['children'] as List? ?? const [])) {
        parentOf[c as int] = i;
      }
    }
    Matrix4 local(Map<String, dynamic> n) {
      List<double> v(String key, List<double> fallback) => (n[key] as List?)?.map((e) => (e as num).toDouble()).toList() ?? fallback;
      final t = v('translation', [0, 0, 0]);
      final r = v('rotation', [0, 0, 0, 1]);
      final s = v('scale', [1, 1, 1]);
      return Matrix4.compose(Vector3(t[0], t[1], t[2]), Quaternion(r[0], r[1], r[2], r[3])..normalize(), Vector3(s[0], s[1], s[2]));
    }

    var index = nodes.indexWhere((n) => n['name'] == 'hand_r');
    var global = Matrix4.identity();
    while (true) {
      global = local(nodes[index]) * global;
      final parent = parentOf[index];
      if (parent == null) break;
      index = parent;
    }
    return global;
  }

  test('a socket previewing a mesh yields an attachment at entityWorld × G_bone × offset', () async {
    if (!mannyGlb.existsSync()) return markTestSkipped('test-assets missing');
    final vm = SkeletalMeshEditorViewModel(assetPath: mannyLmas);
    addTearDown(vm.dispose);
    await vm.load();
    expect(vm.availablePreviewMeshes.map((a) => a.relativePath), contains(card), reason: 'the picker offers the project\'s meshes');

    expect(vm.addSocket(parentBone: 'hand_r', name: 'hand_r_keycard'), isTrue);
    vm.setSocketTransform('hand_r_keycard', location: [5.0, 0.0, 2.0], rotation: [0.0, 0.0, 90.0]);
    vm.setSocketPreviewAsset('hand_r_keycard', card);
    await vm.loadSocketPreviews();

    final attachment = vm.socketAttachments.single;
    expect(attachment.socketName, 'hand_r_keycard');
    expect(attachment.boneName, 'hand_r');
    expect(attachment.assetPath.replaceAll(r'\', '/'), endsWith(card));
    final cardPayload = LuminaAsset.fromBytes(File('$project/$card').readAsBytesSync()).rawPayload;
    expect(attachment.mesh.rawPayload, cardPayload, reason: 'the attachment draws the picked mesh');

    // Offset: 5 cm / 2 cm in the bone's frame (the GLB is in metres), 90° about Z.
    final offset = Matrix4.identity()
      ..translateByVector3(Vector3(0.05, 0.0, 0.02))
      ..rotateZ(math.pi / 2);
    final expected = handGlobalFromGlb() * offset;
    for (var i = 0; i < 16; i++) {
      expect(attachment.restWorld.storage[i], closeTo(expected.storage[i], 1e-5), reason: 'matrix element $i');
    }
    for (var i = 0; i < 16; i++) {
      expect(attachment.localOffset.storage[i], closeTo(offset.storage[i], 1e-9));
    }
    // The card sits in the right hand, not 5 m away from it.
    final hand = handGlobalFromGlb().getTranslation();
    expect(attachment.restWorld.getTranslation().distanceTo(hand), closeTo(math.sqrt(0.05 * 0.05 + 0.02 * 0.02), 1e-5));
  });

  testWidgets('the Preview Asset is picked from the project\'s meshes', (tester) async {
    if (!mannyGlb.existsSync()) return markTestSkipped('test-assets missing');
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // A skeleton-only asset beside the real meshes keeps the viewport off
    // the native renderer; the picker lists the project's real .lmas.
    final skeleton = File('$project/contents/meshes/skeletal/SK_Rig.lmas')..createSync(recursive: true);
    const rig = LuminaAsset(
      assetId: 'SK_Rig',
      name: 'SK_Rig',
      type: AssetType.filameshSk,
      metadata: {'bone_count': '2', 'bones': 'pelvis,hand_r'},
    );
    skeleton.writeAsBytesSync(rig.toProtoBufferBytes());
    final vm = SkeletalMeshEditorViewModel(assetPath: skeleton.path, initialAsset: rig);
    addTearDown(vm.dispose);
    await tester.runAsync(() => vm.load());
    expect(vm.addSocket(parentBone: 'hand_r', name: 'hand_r_keycard'), isTrue);

    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: SkeletalMeshSubEditor(assetName: 'SK_Rig', assetPath: skeleton.path, viewModel: vm)),
    ));
    await tester.pump();

    final picker = find.byKey(const ValueKey('skeletal_socket_preview_hand_r_keycard'));
    expect(picker, findsOneWidget, reason: 'the socket inspector offers a mesh picker');
    await tester.ensureVisible(picker);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('skeletal_socket_preview_picker_hand_r_keycard_item_access_card_blue.lmas')));
    await tester.pumpAndSettle();

    expect(vm.sockets.single.previewAssetPath, card, reason: 'stored project-relative, as MCP set_skeletal_socket stores it');
    expect(vm.isDirty, isTrue);
    await drainRealIo(tester);
  });
}
