import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  testWidgets('Content Browser displays real thumbnail preview images for scanned textures and assets', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('cb_thumb_test_');
    final projDir = Directory('${tempDir.path}/ThumbProj')..createSync(recursive: true);
    final texturesDir = Directory('${projDir.path}/contents/textures')..createSync(recursive: true);

    // 1x1 PNG
    final samplePng = Uint8List.fromList([
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0,
      31, 21, 196, 137, 0, 0, 0, 10, 73, 68, 65, 84, 120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180,
      0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130
    ]);

    final texAsset = LuminaAsset(
      assetId: 'tex-man-01',
      name: 'T_Manny_01_BN',
      type: AssetType.texture,
      rawPayload: samplePng,
      thumbnailPng: samplePng,
    );

    final lmasFile = File('${texturesDir.path}/T_Manny_01_BN.lmas');
    lmasFile.writeAsBytesSync(texAsset.toProtoBufferBytes());

    final project = LuminaProject(
      projectName: 'ThumbProj',
      activeLevel: 'contents/levels/L_Main.lmas',
    );

    final vm = EditorViewModel(
      initialProject: project,
      projectLocation: tempDir.path,
      enableTimers: false,
      autoInitAssets: false,
    )..showAllAssets = true; // The root lists its own folder only; Show All lists the project as this test expects.
    addTearDown(vm.dispose);

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: ContentBrowserWidget(
            viewModel: vm,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('T_Manny_01_BN'), findsOneWidget);
    // Find Image widget rendering thumbnailBytes
    expect(find.byType(Image), findsAtLeastNWidgets(1));

    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });
}
