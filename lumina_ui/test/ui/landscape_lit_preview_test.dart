// ignore_for_file: depend_on_referenced_packages
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_filament/flutter_filament.dart' show FilamentBackend, FilamentEngine;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show LuminaWorld, LuminaWorldType;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/landscape_brush.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/landscape_preview_scene.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/landscape_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/landscape/foliage_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'landscape_editor_test.dart' show RecordingTerrainSink;

/// The preview's sun casts shadows sized for the
/// metre-scaled preview, sculpt uploads keep colours and edge normals fresh,
/// and the Manage panel says what is true.
void main() {
  test('the preview sun casts shadows that cover the whole terrain', () {
    final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    final scene = engine.createScene();
    final world = LuminaWorld(worldType: LuminaWorldType.editor);
    world.initializeNativeContext(engine, scene);
    final preview = LandscapePreviewScene()..attach(world);
    final data = LandscapeData.flat(gridResolution: 129, worldSize: 256.0, maxHeight: 100.0);
    expect(preview.mountPayload(data), isTrue);

    final sun = preview.sun!;
    expect(sun.castShadows, isTrue);
    final options = sun.shadowOptions!;
    final diagonal = 256.0 * math.sqrt2 * LandscapeEditorViewModel.unitsPerMetre;
    expect(options.shadowFar, greaterThanOrEqualTo(diagonal), reason: 'shadows must reach across the terrain');
    expect(options.mapSize, 2048);
    expect(options.shadowCascades, greaterThanOrEqualTo(2));
    expect(sun.lightDirection.y, lessThan(-0.3), reason: 'a sun high enough to light the terrain');
    expect(sun.lightDirection.y, greaterThan(-0.8), reason: 'and low enough for hills to throw readable shadows');

    preview.detach();
    world.cleanup();
    scene.dispose();
    engine.dispose();
  });

  test('a sculpt upload carries colours and reaches one row beyond the edited cells', () {
    final tempDir = Directory.systemTemp.createTempSync('lumina_landscape_lit_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final sink = RecordingTerrainSink();
    final vm = LandscapeEditorViewModel(assetPath: '${tempDir.path}/contents/landscapes/T.lmas', sink: sink)..open();
    vm.setTool(LandscapeTool.sculpt);
    vm.setBrushRadius(6.0);
    vm.setBrushStrength(1.0);
    vm.beginStroke(-30.0, -30.0);
    vm.endStroke();
    expect(sink.updates, isNotEmpty);
    expect(sink.updateColors, everyElement(isNotNull), reason: 'every window carries its albedo');
    // The stamp touched rows around row 49 (z = -30 m, 2 m cells) within 6 m;
    // the upload must start one row above the first edited row.
    final edited = vm.lastStrokeRect!;
    final firstUploadedRow = sink.updates.map((w) => w.firstLocalRow + (w.sectionRow * 64)).reduce(math.min);
    expect(firstUploadedRow, edited.minRow - 1, reason: 'normals one ring outside the edit depend on it');
    vm.dispose();
  });

  testWidgets('the Manage panel no longer blames the missing uv1 and says the terrain is lit', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final tempDir = Directory.systemTemp.createTempSync('lumina_landscape_lit_ui_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: LandscapeFoliageSubEditor(
          assetName: 'Terrain_Main',
          assetPath: '${tempDir.path}/contents/landscapes/Terrain_Main.lmas',
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('uv1'), findsNothing);
    expect(find.textContaining('lit by the preview sun'), findsOneWidget);
  });
}
