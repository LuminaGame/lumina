import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/static_mesh_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/static_mesh_sub_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('sm_lod_ui_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('StaticMeshSubEditor renders LOD tab, Add LOD action, and forced LOD selector', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final assetFile = File('${tempDir.path}/SM_LODWidget.lmas');
    final asset = LuminaAsset(
      assetId: 'SM_LODWidget',
      name: 'SM_LODWidget',
      type: AssetType.filamesh,
      metadata: {
        'triangle_count': '1000',
        'vertex_count': '500',
        'sections': '1',
      },
    );
    assetFile.writeAsBytesSync(asset.toProtoBufferBytes());

    final vm = StaticMeshEditorViewModel(assetPath: assetFile.path, initialAsset: asset);
    await tester.runAsync(() => vm.load());

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: StaticMeshSubEditor(
            assetName: 'SM_LODWidget',
            assetPath: assetFile.path,
            viewModel: vm,
          ),
        ),
      ),
    );

    // Verify LOD tab
    expect(find.text('LODs (1)'), findsOneWidget);
    expect(find.textContaining('Forced LOD'), findsOneWidget);

    // Switch to LODs tab
    await tester.tap(find.text('LODs (1)'));
    await tester.pump();

    expect(find.text('LOD SETTINGS'), findsOneWidget);
    expect(find.text('Add LOD'), findsOneWidget);
    expect(find.text('LOD 0 (Source)'), findsNWidgets(2)); // in LOD panel and in Viewport overlay

    // Add LOD1
    await tester.tap(find.text('Add LOD'));
    await tester.pump();

    expect(vm.lods.length, 2);
    expect(find.textContaining('LOD 1'), findsWidgets);
    expect(find.text('LODs (2)'), findsOneWidget);

    // A screen size set outside the field (MCP
    // `set_static_mesh_lod`, a reload) must reach it.
    String textOf(Finder f) => tester.widget<EditableText>(find.descendant(of: f, matching: find.byType(EditableText))).controller.text;
    final screenSizeField = find.byKey(const ValueKey('static_mesh_lod_screen_size_1'));
    expect(screenSizeField, findsOneWidget);
    expect(textOf(screenSizeField), '0.50');
    expect(vm.setLodScreenSize(1, 0.2), isTrue);
    await tester.pump();
    expect(textOf(screenSizeField), '0.20');
  });
}
