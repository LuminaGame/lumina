import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/data/models/lumina_asset.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/skeletal_mesh_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/skeletal_mesh/skeletal_mesh_sub_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('skel_ui_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('SkeletalMeshSubEditor renders real bone tree and socket interactions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final assetFile = File('${tempDir.path}/SK_Hero.lmas');
    final asset = LuminaAsset(
      assetId: 'SK_Hero',
      name: 'SK_Hero',
      type: AssetType.filamesh,
      metadata: {
        'triangle_count': '3',
        'vertex_count': '3',
        'bone_count': '2',
        'bones': 'pelvis,spine_01',
      },
    );
    assetFile.writeAsBytesSync(asset.toProtoBufferBytes());

    final vm = SkeletalMeshEditorViewModel(assetPath: assetFile.path, initialAsset: asset);
    await tester.runAsync(() => vm.load());

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SkeletalMeshSubEditor(
            assetName: 'SK_Hero',
            assetPath: assetFile.path,
            viewModel: vm,
          ),
        ),
      ),
    );

    // Verify Real Bone Names rendered
    expect(find.text('pelvis'), findsWidgets);
    expect(find.text('spine_01'), findsWidgets);

    // Verify hardcoded fake strings do NOT exist
    expect(find.text('• RootPelvis'), findsNothing);
    expect(find.text('└─ Spine_01'), findsNothing);
    expect(find.text('Neck'), findsNothing);
    expect(find.text('Arm_L'), findsNothing);

    // Verify Bone Count Badge
    expect(find.text('2 Bones'), findsOneWidget);

    // Add Socket via top toolbar button
    await tester.tap(find.text('Add Socket').first);
    await tester.pump();

    expect(vm.sockets.length, 1);
    expect(find.text('pelvis_socket'), findsWidgets);
    expect(find.text('1 Sockets'), findsOneWidget);

    // Select Socket -> Right Inspector shows Socket Details
    expect(find.text('SOCKET DETAILS'), findsOneWidget);
    expect(find.text('Relative Location'), findsOneWidget);

    // A change made outside the fields (MCP set_skeletal_socket,
    // undo) shows in them.
    vm.setSocketTransform('pelvis_socket', location: [5.0, 0.0, 2.0], rotation: [0.0, 0.0, 90.0]);
    vm.setSocketPreviewAsset('pelvis_socket', 'contents/meshes/static/access_card_blue.lmas');
    await tester.pump();
    String textOf(Finder f) => tester.widget<EditableText>(find.descendant(of: f, matching: find.byType(EditableText))).controller.text;
    final fields = find.byType(TextField);
    final texts = [for (var i = 0; i < fields.evaluate().length; i++) textOf(fields.at(i))];
    expect(texts, containsAllInOrder(['5.0', '0.0', '2.0', '0.0', '0.0', '90.0']));
    // The Preview Asset is a mesh picker; it names the asset (in the
    // missing colour here — this temp folder holds no such mesh).
    expect(find.descendant(of: find.byKey(const ValueKey('skeletal_socket_preview_picker_pelvis_socket_value')), matching: find.text('access_card_blue')),
        findsOneWidget);
  });
}
