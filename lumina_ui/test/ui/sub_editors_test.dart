import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/static_mesh_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/static_mesh_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/material_sub_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  testWidgets('SubEditor3DViewport should render 3D canvas and HUD controls', (WidgetTester tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SubEditor3DViewport(
            title: 'Test 3D Viewport',
            showShapeSelector: true,
          ),
        ),
      ),
    );

    expect(find.text('Perspective'), findsOneWidget);
    expect(find.text('Reset View'), findsOneWidget);
    expect(find.textContaining('Renderer: Filament C++'), findsOneWidget);
  });

  testWidgets('BlueprintSubEditor should render interactive Node Graph Canvas', (WidgetTester tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: BlueprintSubEditor(
            assetName: 'BP_PlayerCharacter.lmas',
          ),
        ),
      ),
    );

    expect(find.text('BLUEPRINT ACTOR'), findsOneWidget);
    expect(find.text('BP_PlayerCharacter.lmas'), findsOneWidget);
    expect(find.text('Event BeginPlay'), findsOneWidget);
    expect(find.text('Print String'), findsOneWidget);
    expect(find.text('Event Tick'), findsOneWidget);
    expect(find.text('Add Movement Input'), findsOneWidget);
  });

  testWidgets('StaticMeshSubEditor should render 3D viewport', (WidgetTester tester) async {
    final tempDir = Directory.systemTemp.createTempSync('sub_editor_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final file = File('${tempDir.path}/YVO3D_44368.lmas');
    final asset = LuminaAsset(
      assetId: 'YVO3D_44368',
      name: 'YVO3D_44368.lmas',
      type: AssetType.filamesh,
      metadata: {
        'triangle_count': '100',
        'vertex_count': '80',
      },
    );
    file.writeAsBytesSync(asset.toProtoBufferBytes());

    final vm = StaticMeshEditorViewModel(assetPath: file.path, initialAsset: asset);
    await tester.runAsync(() => vm.load());

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: StaticMeshSubEditor(
            assetName: 'YVO3D_44368.lmas',
            assetPath: file.path,
            viewModel: vm,
          ),
        ),
      ),
    );

    expect(find.text('STATIC MESH'), findsOneWidget);
    expect(find.text('YVO3D_44368.lmas'), findsOneWidget);
    expect(find.text('MESH STATISTICS'), findsOneWidget);
  });

  testWidgets('MaterialSubEditor should render GLSL source editor and toolbar', (WidgetTester tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: MaterialSubEditor(
            assetName: 'M_Gold.lmas',
          ),
        ),
      ),
    );

    expect(find.text('FILAMAT'), findsOneWidget);
    expect(find.text('M_Gold.lmas'), findsOneWidget);
    expect(find.text('Compile'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });
}
