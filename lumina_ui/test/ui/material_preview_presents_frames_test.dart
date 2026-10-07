import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart' show FilamentWidget;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_preview_renderer.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/material_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Regression coverage: a material opened from disk reaches the
/// preview only after the first frame (the view model reads and compiles it
/// asynchronously), and the viewport then has to start presenting frames.
void main() {
  testWidgets('an imported material opened from disk gets a preview that reads back frames', (tester) async {
    final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb');
    if (!barrel.existsSync()) return markTestSkipped('test-assets missing');

    final project = Directory.systemTemp.createTempSync('material_preview_frames_');
    addTearDown(() {
      if (project.existsSync()) project.deleteSync(recursive: true);
    });
    Directory('${project.path}/contents').createSync();
    await tester.runAsync(
      () => AssetRepository().importExternalFile(projectPath: project.path, sourceFilePath: barrel.path),
    );
    final material = Directory('${project.path}/contents/materials')
        .listSync(recursive: true)
        .whereType<File>()
        .firstWhere((f) => f.path.endsWith('.lmas'));
    final asset = LuminaAsset.fromBytes(material.readAsBytesSync());
    // The importer writes source only; the editor compiles it on open.
    expect(asset.rawPayload, anyOf(isNull, isEmpty));
    expect(asset.references.map((r) => r.slotName), contains('baseColorMap'));

    // Opened the way the Content Browser opens it: by path, with the editor
    // owning its view model.
    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SizedBox(
            width: 1400,
            height: 820,
            child: MaterialSubEditor(assetName: asset.name, assetPath: material.path),
          ),
        ),
      ),
    );
    // The first frame has nothing compiled to show yet.
    expect(find.byType(FilamentWidget), findsNothing);

    // Let the view model read and compile the asset.
    for (var i = 0; i < 200 && find.byType(FilamentWidget).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    final viewport = tester.widget<SubEditor3DViewport>(find.byType(SubEditor3DViewport));
    expect(MaterialPreviewRenderer.isFilamatPackage(viewport.previewMaterialBytes), isTrue,
        reason: 'the imported material compiles on open');
    expect(find.byType(FilamentWidget), findsOneWidget);

    // The viewport skips pixel readback for a short warm-up (shader
    // compilation) and must then present what it renders. 25 frames at
    // 30 ms each is 750 ms; give it two seconds.
    for (var i = 0; i < 70; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(
      tester.widget<FilamentWidget>(find.byType(FilamentWidget)).skipReadPixels,
      isFalse,
      reason: 'a preview that never reads back its frames shows only the status placeholder',
    );
  });
}
