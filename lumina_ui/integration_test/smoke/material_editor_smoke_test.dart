import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show PointerDeviceKind, kSecondaryMouseButton;
import 'package:flutter_filament/flutter_filament.dart' show FilamentWidget;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/material_graph.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_preview_renderer.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/graph_canvas.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/material_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

import '../../test/helpers/cc_body_asset.dart';
import '../../test/helpers/mcp_test_client.dart';

/// Material Editor smoke: a real material is compiled with filamat, opened in
/// the Material Editor and its 3D preview must render a shaded primitive on the
/// GPU (a regression check). Evidence: PNG per preview shape.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Material Editor Smoke: compiled material shades sphere/cube/cylinder previews', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('lumina_smoke_material_');
    final matDir = Directory('${tempDir.path}/contents/materials')..createSync(recursive: true);
    const source = '''material {
    name : "M_SmokeRed",
    parameters : [
        { type : float, name : roughness, default : 0.35 },
        { type : float, name : metallic, default : 0.0 },
        { type : float4, name : baseColor, default : [0.85, 0.15, 0.10, 1.0] }
    ],
}
fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = materialParams.baseColor;
        material.roughness = materialParams.roughness;
        material.metallic = materialParams.metallic;
    }
}''';
    final asset = LuminaAsset(assetId: 'M_SmokeRed', name: 'M_SmokeRed', type: AssetType.filamat, rawMatSource: source);
    final file = File('${matDir.path}/M_SmokeRed.lmas')..writeAsBytesSync(asset.toProtoBufferBytes());

    final vm = MaterialEditorViewModel(assetPath: file.path, initialAsset: asset);
    final compiled = await tester.runAsync(() => vm.compile());
    expect(compiled, isTrue, reason: 'real filamat compile must succeed');
    expect(vm.compiledBytes, isNotNull);
    expect(MaterialPreviewRenderer.isFilamatPackage(vm.compiledBytes!), isTrue);

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: SizedBox(width: 1400, height: 820, child: MaterialSubEditor(assetName: 'M_SmokeRed', viewModel: vm)),
          ),
        ),
      ),
    );

    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));

    // The header's declared red is the colour the panel shows and the preview
    // uses (it used to be read as white).
    await tester.pump(const Duration(milliseconds: 100));
    expect(vm.parameters.firstWhere((p) => p.name == 'baseColor').value, [0.85, 0.15, 0.10, 1.0]);
    expect(find.text('R:0.85 G:0.15 B:0.10'), findsOneWidget);

    /// Orbits the preview camera with a left-button drag across the preview.
    Future<void> orbit(double dx) async {
      final c = tester.getCenter(find.byType(SubEditor3DViewport));
      await rec.drag(c - Offset(dx / 2, 0), c + Offset(dx / 2, 0), steps: 30);
    }

    Future<Uint8List> settleAndCapture(String name) async {
      // Let the native engine warm up and present several frames, on video.
      await rec.hold(const Duration(milliseconds: 1500));
      final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot(name, png);
      // Then look around the shaded primitive.
      await orbit(160);
      await rec.hold(const Duration(milliseconds: 500));
      return png;
    }

    double previewVariance(Uint8List png) {
      final decoded = img.decodePng(png);
      expect(decoded, isNotNull);
      // The preview pane is the left column; sample its centre region.
      final x0 = (decoded!.width * 0.05).round(), x1 = (decoded.width * 0.28).round();
      final y0 = (decoded.height * 0.30).round(), y1 = (decoded.height * 0.75).round();
      var n = 0;
      var sum = 0.0, sumSq = 0.0;
      var reddish = 0;
      for (var y = y0; y < y1; y += 2) {
        for (var x = x0; x < x1; x += 2) {
          final p = decoded.getPixel(x, y);
          final lum = (p.r + p.g + p.b) / 3.0;
          sum += lum;
          sumSq += lum * lum;
          n++;
          if (p.r > p.g + 30 && p.r > p.b + 30) reddish++;
        }
      }
      final mean = sum / n;
      final variance = sumSq / n - mean * mean;
      expect(reddish, greaterThan(n ~/ 40), reason: 'the red material must be visible in the preview region');
      return variance;
    }

    /// Mean luminance of the preview's centre region.
    double previewMean(Uint8List png) {
      final d = img.decodePng(png)!;
      var sum = 0.0;
      var n = 0;
      for (var y = (d.height * 0.30).round(); y < (d.height * 0.75).round(); y += 2) {
        for (var x = (d.width * 0.05).round(); x < (d.width * 0.28).round(); x += 2) {
          final p = d.getPixel(x, y);
          sum += (p.r + p.g + p.b) / 3.0;
          n++;
        }
      }
      return sum / n;
    }

    final spherePng = await settleAndCapture('material_editor_preview_sphere');
    expect(previewVariance(spherePng), greaterThan(50.0), reason: 'a lit sphere is not a flat colour');

    // Switch preview primitives through the real toolbar buttons.
    await tester.tap(find.widgetWithText(SecondaryButton, 'Cube'));
    final cubePng = await settleAndCapture('material_editor_preview_cube');
    expect(previewVariance(cubePng), greaterThan(50.0));

    await tester.tap(find.widgetWithText(SecondaryButton, 'Cylinder'));
    final cylPng = await settleAndCapture('material_editor_preview_cylinder');
    expect(previewVariance(cylPng), greaterThan(50.0));

    // Drag the roughness slider in the parameter panel: the highlight spreads
    // as the surface roughens.
    final roughSlider = find.descendant(
      of: find.ancestor(of: find.text('roughness'), matching: find.byType(Column)).first,
      matching: find.byType(Slider),
    );
    final sr = tester.getRect(roughSlider);
    await rec.drag(Offset(sr.left + sr.width * 0.35, sr.center.dy), Offset(sr.right - 2, sr.center.dy), steps: 30);
    expect((vm.parameters.firstWhere((p) => p.name == 'roughness').value as num).toDouble(), greaterThan(0.6));
    await rec.hold(const Duration(milliseconds: 800));

    // Back to the sphere, then darken the base colour: the preview follows.
    await tester.tap(find.widgetWithText(SecondaryButton, 'Sphere'));
    await rec.hold(const Duration(seconds: 1));
    final litPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    for (var i = 1; i <= 20; i++) {
      final t = 1.0 - 0.95 * i / 20;
      vm.setParam('baseColor', [0.85 * t, 0.15 * t, 0.10 * t, 1.0]);
      await rec.hold(const Duration(milliseconds: 50));
    }
    await rec.hold(const Duration(seconds: 1));
    final darkPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    expect(previewMean(darkPng), lessThan(previewMean(litPng) - 5),
        reason: 'a darker base colour darkens the live preview');
    rec.save('Material Editor Smoke: compiled material shades sphere/cube/cylinder previews');

    tempDir.deleteSync(recursive: true);
  });

  testWidgets('Material Editor Smoke: an imported textured material opened from disk previews with its textures',
      (tester) async {
    // The warm-skin colour checks hold only for the CC body; the
    // AC unit fallback is not warm, so without the body this is skipped.
    final ccBody = CcBodyAsset.resolve(CcBodyAsset.male);
    if (ccBody.file == null) return markTestSkipped('needs the CC body skin: ${ccBody.skipReason}');
    final project = await _importTexturedProject(tester);
    final material = project.bodyMaterial;
    final asset = LuminaAsset.fromBytes(material.readAsBytesSync());
    expect(asset.references.length, greaterThanOrEqualTo(1), reason: 'the import binds its textures');

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(_editorByPath(boundaryKey, asset.name, material.path));
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));

    // Opened by path, as the Content Browser opens it: the first frames have
    // no compiled package, the view model reads and compiles it, and the
    // preview must then start presenting frames.
    for (var i = 0; i < 300 && find.byType(FilamentWidget).evaluate().isEmpty; i++) {
      await rec.hold(const Duration(milliseconds: 100));
    }
    expect(find.byType(FilamentWidget), findsOneWidget, reason: 'the imported material compiles on open');
    await rec.hold(const Duration(milliseconds: 2500));

    final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    SmokeArtifacts.saveScreenshot('material_editor_imported_textured_preview', png, usedAssets: project.sources);
    expect(find.text('Filament 3D Scene Running (60 FPS)'), findsNothing,
        reason: 'the preview shows rendered frames, not flutter_filament\'s status placeholder');
    final stats = _previewStats(tester, png);
    expect(stats.variance, greaterThan(40.0), reason: 'a textured, lit sphere is not a flat fill');
    expect(stats.warm, greaterThan(stats.samples ~/ 20), reason: 'the skin/barrel texture colours the sphere');

    // Look around it and across the preview shapes.
    final c = tester.getCenter(find.byType(FilamentWidget));
    await rec.drag(c - const Offset(90, 0), c + const Offset(90, 0), steps: 45);
    await rec.hold(const Duration(milliseconds: 600));
    for (final shape in ['Cube', 'Cylinder', 'Sphere']) {
      await tester.tap(find.widgetWithText(SecondaryButton, shape));
      await rec.hold(const Duration(milliseconds: 1200));
      expect(find.text('Filament 3D Scene Running (60 FPS)'), findsNothing);
    }

    // A recompile swaps the package under the preview; it keeps presenting.
    await tester.tap(find.widgetWithText(GhostButton, 'Compile'));
    for (var i = 0; i < 40; i++) {
      await rec.hold(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('Compile OK'), findsOneWidget);
    expect(find.text('Filament 3D Scene Running (60 FPS)'), findsNothing);
    await rec.drag(c + const Offset(80, 0), c - const Offset(80, 0), steps: 45);
    await rec.hold(const Duration(milliseconds: 800));
    final after = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    SmokeArtifacts.saveScreenshot('material_editor_imported_textured_preview_after_recompile', after,
        usedAssets: project.sources);
    expect(_previewStats(tester, after).variance, greaterThan(40.0));

    rec.save('Material Editor Smoke: an imported textured material opened from disk previews with its textures',
        usedAssets: project.sources);
  });

  testWidgets('Material Editor Smoke: texture rows name their textures and a reassigned texture reaches the preview',
      (tester) async {
    // The warm-skin colour checks hold only for the CC body; the
    // AC unit fallback is not warm, so without the body this is skipped.
    final ccBody = CcBodyAsset.resolve(CcBodyAsset.male);
    if (ccBody.file == null) return markTestSkipped('needs the CC body skin: ${ccBody.skipReason}');
    final project = await _importTexturedProject(tester);
    final material = project.bodyMaterial;
    final asset = LuminaAsset.fromBytes(material.readAsBytesSync());
    final baseRef = asset.references.firstWhere((r) => r.slotName == 'baseColorMap');

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(_editorByPath(boundaryKey, asset.name, material.path));
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    for (var i = 0; i < 300 && find.byType(FilamentWidget).evaluate().isEmpty; i++) {
      await rec.hold(const Duration(milliseconds: 100));
    }
    await rec.hold(const Duration(milliseconds: 2500));

    // Each sampler row names its texture, with a thumbnail; no UUID anywhere.
    final baseName = baseRef.assetPath.split('/').last.replaceAll('.lmas', '');
    expect(find.text(baseName), findsWidgets);
    expect(find.textContaining(baseRef.assetId), findsNothing);
    expect(find.byKey(const ValueKey('texture_thumbnail_baseColorMap')), findsOneWidget);
    final before = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    SmokeArtifacts.saveScreenshot('material_editor_texture_rows', before, usedAssets: project.sources);
    final warmBefore = _previewStats(tester, before).warm;

    // Rebind Base Color to the red barrel's texture through the row's picker.
    await tester.tap(find.byKey(const ValueKey('texture_picker_baseColorMap')));
    await rec.hold(const Duration(milliseconds: 900));
    const barrelTexture = 'T_fuel_barrel_red_loot_barrel_bc.jpg';
    expect(find.text(barrelTexture), findsWidgets, reason: 'the picker lists the project\'s real textures');
    await tester.tap(find.text(barrelTexture).last);
    await rec.hold(const Duration(milliseconds: 2500));
    expect(find.text(barrelTexture), findsWidgets, reason: 'the row names the new texture');

    final after = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    SmokeArtifacts.saveScreenshot('material_editor_texture_reassigned', after, usedAssets: project.sources);
    final warmAfter = _previewStats(tester, after).warm;
    // The skin is warm; the barrel's texture is grey metal with rust.
    expect(warmAfter, lessThan(warmBefore ~/ 2), reason: 'the preview shows the barrel texture, not the skin');
    // The sphere is a small part of the tall pane, so the mean difference is
    // diluted by the unchanged background around it.
    expect(_previewDifference(tester, before, after), greaterThan(1.5), reason: 'the sphere changed');

    // Orbit to show it, then save; the reference on disk is the real texture.
    final c = tester.getCenter(find.byType(FilamentWidget));
    await rec.drag(c - const Offset(80, 0), c + const Offset(80, 0), steps: 45);
    await tester.tap(find.widgetWithText(PrimaryButton, 'Save'));
    await rec.hold(const Duration(milliseconds: 1500));
    final saved = LuminaAsset.fromBytes(material.readAsBytesSync());
    final ref = saved.references.firstWhere((r) => r.slotName == 'baseColorMap');
    expect(ref.assetPath, endsWith('$barrelTexture.lmas'));
    expect(File('${project.root.path}/${ref.assetPath}').existsSync(), isTrue);

    // The saved barrel texture on every preview shape (the video must
    // show ≥ 10 s of the flow, and these are real steps of it).
    for (final shape in ['Cube', 'Cylinder', 'Sphere']) {
      await tester.tap(find.widgetWithText(SecondaryButton, shape));
      await rec.hold(const Duration(milliseconds: 1200));
      expect(find.text('Filament 3D Scene Running (60 FPS)'), findsNothing,
          reason: 'the $shape preview presents rendered frames');
    }
    expect(find.text(barrelTexture), findsWidgets, reason: 'the row still names the saved texture');

    rec.save('Material Editor Smoke: texture rows name their textures and a reassigned texture reaches the preview',
        usedAssets: project.sources);
  });

  testWidgets('Material Editor Smoke: the material is a node graph, edited on camera, and the source follows',
      (tester) async {
    // A fixed view, as the other smoke scenarios use: the runner window's
    // own size differs per machine, and on Windows it left the graph canvas
    // too small for the nodes this scenario places.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final project = await _importTexturedProject(tester);
    final material = project.bodyMaterial;
    final vm = MaterialEditorViewModel(assetPath: material.path);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: MaterialSubEditor(assetName: 'M_Skin_Body_CCMH', viewModel: vm)),
      ),
    ));
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    await tester.runAsync(vm.load);
    for (var i = 0; i < 300 && find.byType(FilamentWidget).evaluate().isEmpty; i++) {
      await rec.hold(const Duration(milliseconds: 100));
    }
    await rec.hold(const Duration(milliseconds: 1500));
    final before = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));

    // The imported material opens as a graph: TextureSamples into the pins.
    await tester.tap(find.text('Node Graph'));
    await rec.hold(const Duration(milliseconds: 800));
    final graph = vm.graph.graph;
    final out = MaterialNodes.outputNodeId;
    final oldBase = graph.wireInto(out, MaterialNodes.baseColor)!;
    expect(graph.node(oldBase.fromNodeId)!.registryId, MaterialNodes.multiply);
    expect(find.textContaining('Texture Sample · baseColorMap'), findsOneWidget);
    // One Texture Sample per sampler the import wrote: four for
    // the CC body, one for the AC unit this falls back to where the CC body
    // is not on disk (its GLB binds only a base colour map).
    final source = LuminaAsset.fromBytes(material.readAsBytesSync()).rawMatSource;
    final samplers = [for (final m in RegExp(r'type\s*:\s*sampler2d\s*,\s*name\s*:\s*(\w+)').allMatches(source)) m.group(1)!];
    debugPrint('[material_graph_smoke] ${material.path}: samplers $samplers');
    expect(samplers, contains('baseColorMap'));
    expect(graph.nodes.where((n) => n.registryId == MaterialNodes.textureSample), hasLength(samplers.length),
        reason: 'the imported samplers $samplers each read as a Texture Sample');

    // Zoom out so the whole graph is on screen.
    final canvas = find.byType(BlueprintGraphCanvas);
    final canvasRect = tester.getRect(canvas);
    final wheel = TestPointer(77, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(wheel.hover(canvasRect.center));
    for (var i = 0; i < 3; i++) {
      await tester.sendEventToBinding(wheel.scroll(const Offset(0, 40)));
      await rec.hold(const Duration(milliseconds: 250));
    }
    expect(find.text('Zoom 70%'), findsOneWidget);
    final graphPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    SmokeArtifacts.saveScreenshot('material_editor_graph_imported', graphPng, usedAssets: project.sources);

    /// Places [registryId] from the palette opened by a right-click at [at].
    Future<String> place(Offset at, String search, String registryId) async {
      final ids = graph.nodes.map((n) => n.id).toSet();
      await tester.tapAt(at, buttons: kSecondaryMouseButton, kind: PointerDeviceKind.mouse);
      await rec.hold(const Duration(milliseconds: 500));
      await rec.typeText(find.byKey(const ValueKey('palette_search')), search, perCharacter: const Duration(milliseconds: 70));
      await tester.tap(find.byKey(ValueKey('palette_entry_$registryId')));
      await rec.hold(const Duration(milliseconds: 600));
      return vm.graph.graph.nodes.map((n) => n.id).toSet().difference(ids).single;
    }

    // Free spots on the canvas, clear of every node's box — recomputed per
    // placement, so the nodes placed so far are avoided too (Texture Sample
    // nodes are taller for their thumbnail body).
    List<Rect> nodeRects() {
      // Only the graph nodes' own boxes (`node_<id>`), not other `node_…`
      // keys such as a node's texture field.
      final keys = {for (final n in vm.graph.graph.nodes) 'node_${n.id}'};
      return [
        for (final e in find
            .byWidgetPredicate((w) => w.key is ValueKey && keys.contains('${(w.key as ValueKey).value}'))
            .evaluate())
          tester.getRect(find.byWidget(e.widget)),
      ];
    }
    Offset freeSpot(double fx) {
      final rects = nodeRects();
      // Room for the node the palette places at the click (at the 70 % zoom
      // a new node is ~115 × 70 px; keep a margin).
      bool free(Offset p) => !rects.any((r) => r.inflate(10).overlaps(Rect.fromLTWH(p.dx - 6, p.dy - 6, 150, 96)));
      // Below the imported nodes first (where the author works), then above.
      for (final fy in [for (var f = 0.55; f <= 0.86; f += 0.03) f, for (var f = 0.52; f >= 0.12; f -= 0.03) f]) {
        for (var d = 0.0; d <= 0.6; d += 0.03) {
          for (final x in {fx + d, fx - d}) {
            if (x < 0.03 || x > 0.85) continue;
            final p = Offset(canvasRect.left + canvasRect.width * x, canvasRect.top + canvasRect.height * fy);
            if (free(p)) return p;
          }
        }
      }
      fail('no free spot on the graph canvas for a new node: canvas $canvasRect, nodes $rects');
    }

    final tint = await place(freeSpot(0.22), 'Constant3', MaterialNodes.constant3);
    final mask = await place(freeSpot(0.42), 'Mask', MaterialNodes.componentMask);
    final mul = await place(freeSpot(0.62), 'Multiply', MaterialNodes.multiply);

    // Give the tint an orange colour in the Details panel.
    vm.graph.editor.select(tint);
    await rec.hold(const Duration(milliseconds: 400));
    for (final (channel, value) in [(1, '0.45'), (2, '0.25')]) {
      final field = find.descendant(
        of: find.byKey(ValueKey('material_details_${tint}_value_${channel}_0')),
        matching: find.byType(TextField),
      );
      await tester.tap(field.first);
      await rec.typeText(field, value, perCharacter: const Duration(milliseconds: 80));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await rec.hold(const Duration(milliseconds: 400));
    }
    expect(vm.graph.graph.node(tint)!.literals['value'], [1.0, 0.45, 0.25]);

    // Wire: old Base Color × tint, dragging pin to pin.
    Future<void> connect(String from, String to) async {
      final a = tester.getCenter(find.byKey(ValueKey(from)));
      final b = tester.getCenter(find.byKey(ValueKey(to)));
      await rec.drag(a, b, steps: 24);
      await rec.hold(const Duration(milliseconds: 300));
    }

    await connect('pin_${oldBase.fromNodeId}_out_out', 'pin_${mul}_a_in');
    await connect('pin_${tint}_out_out', 'pin_${mul}_b_in');
    // …and the Multiply into Base Color: the checker reports only nodes that
    // reach the Material node (an unwired node compiles to nothing). The
    // imported Base Color is a float4 (Constant4 × RGBA):
    // float4 × float3 is a type error, on the node, the wire and in the log.
    await connect('pin_${mul}_out_out', 'pin_${out}_${MaterialNodes.baseColor}_in');
    expect(vm.graph.analysis.errorNodeIds, {mul});
    const typeError = 'Multiply: arithmetic between float4 and float3 is undefined';
    expect(find.text(typeError), findsWidgets);
    expect(vm.syntaxStatus, contains('Graph Error'));
    await rec.hold(const Duration(milliseconds: 600));
    final errorPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    SmokeArtifacts.saveScreenshot('material_editor_graph_type_error', errorPng, usedAssets: project.sources);
    vm.graph.editor.clearSelection();
    await tester.tap(find.text(typeError).last);
    await rec.hold(const Duration(milliseconds: 600));
    expect(vm.graph.editor.selectedNodeIds, {mul}, reason: 'the log row selects the failing node');

    // Fix it: mask the float4 down to RGB.
    vm.graph.editor.select(mask);
    await rec.hold(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(ValueKey('material_details_${mask}_mask_b')));
    await rec.hold(const Duration(milliseconds: 400));
    expect(MaterialNodes.maskChannels(vm.graph.graph.node(mask)!), 'rgb');
    await connect('pin_${oldBase.fromNodeId}_out_out', 'pin_${mask}_in_in');
    await connect('pin_${mask}_out_out', 'pin_${mul}_a_in');
    final base = vm.graph.graph.wireInto(out, MaterialNodes.baseColor);
    expect(base?.fromNodeId, mul);
    expect(vm.graph.analysis.hasErrors, isFalse, reason: '${vm.graph.analysis.diagnostics}');
    expect(vm.currentCode, contains('vec3(1.0, 0.45, 0.25)'));
    expect(vm.currentCode, contains('.rgb'));

    // Apply: the preview shows the tinted skin.
    await tester.tap(find.widgetWithText(GhostButton, 'Compile'));
    for (var i = 0; i < 30; i++) {
      await rec.hold(const Duration(milliseconds: 100));
    }
    expect(vm.syntaxStatus, startsWith('Compile OK'));
    final edited = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    SmokeArtifacts.saveScreenshot('material_editor_graph_edited', edited, usedAssets: project.sources);
    expect(_previewDifference(tester, before, edited), greaterThan(1.5), reason: 'the tint reaches the preview');

    // The GLSL tab shows the source the graph wrote.
    await tester.tap(find.text('GLSL Source (.mat)'));
    await rec.hold(const Duration(milliseconds: 1500));
    expect(find.textContaining('vec3(1.0, 0.45, 0.25)'), findsWidgets);
    final code = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    SmokeArtifacts.saveScreenshot('material_editor_graph_generated_code', code, usedAssets: project.sources);

    // Back in the graph: undo the last wire (Mask → Multiply.A, which brings
    // the float4 wire and its type error back) and redo it.
    await tester.tap(find.text('Node Graph'));
    await rec.hold(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey('material_graph_undo')));
    await rec.hold(const Duration(milliseconds: 700));
    expect(vm.graph.graph.wireInto(mul, 'a')?.fromNodeId, oldBase.fromNodeId);
    expect(vm.graph.analysis.errorNodeIds, {mul});
    await tester.tap(find.byKey(const ValueKey('material_graph_redo')));
    await rec.hold(const Duration(milliseconds: 700));
    expect(vm.graph.graph.wireInto(mul, 'a')?.fromNodeId, mask);
    expect(vm.graph.analysis.hasErrors, isFalse);
    expect(vm.graph.graph.wireInto(out, MaterialNodes.baseColor)?.fromNodeId, mul);

    // Save: the graph and its layout are in the .lmas next to the source.
    await tester.tap(find.widgetWithText(PrimaryButton, 'Save'));
    await rec.hold(const Duration(milliseconds: 1200));
    final saved = LuminaAsset.fromBytes(material.readAsBytesSync());
    expect(saved.rawMatSource, contains('vec3(1.0, 0.45, 0.25)'));
    expect(saved.metadata['material_graph'], contains(tint));

    rec.save('Material Editor Smoke: the material is a node graph, edited on camera, and the source follows',
        usedAssets: project.sources);
  });

  testWidgets('Material Editor Smoke: the Texture Sample node shows its thumbnail and picks another texture with search',
      (tester) async {
    // The warm-skin colour checks hold only for the CC body; the
    // AC unit fallback is not warm, so without the body this is skipped.
    final ccBody = CcBodyAsset.resolve(CcBodyAsset.male);
    if (ccBody.file == null) return markTestSkipped('needs the CC body skin: ${ccBody.skipReason}');
    final project = await _importTexturedProject(tester);
    final material = project.bodyMaterial;
    final vm = MaterialEditorViewModel(assetPath: material.path);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: MaterialSubEditor(assetName: 'M_Skin_Body_CCMH', viewModel: vm)),
      ),
    ));
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    await tester.runAsync(vm.load);
    for (var i = 0; i < 300 && find.byType(FilamentWidget).evaluate().isEmpty; i++) {
      await rec.hold(const Duration(milliseconds: 100));
    }
    await rec.hold(const Duration(milliseconds: 1500));
    final before = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));

    await tester.tap(find.text('Node Graph'));
    await rec.hold(const Duration(milliseconds: 800));
    final sample = vm.graph.graph.nodes.singleWhere((n) => n.literals['parameter'] == 'baseColorMap');
    final field = find.byKey(ValueKey('node_texture_${sample.id}'));
    expect(field, findsOneWidget);
    final thumb = tester.widget<AssetThumbnail>(find.descendant(of: field, matching: find.byType(AssetThumbnail)));
    expect(thumb.bytes, isNotEmpty, reason: 'the node shows the real texture thumbnail');
    vm.graph.editor.focusNode(sample.id);
    await rec.hold(const Duration(milliseconds: 800));
    final nodePng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    SmokeArtifacts.saveScreenshot('material_editor_node_texture_thumbnail', nodePng, usedAssets: project.sources);

    // Click the thumbnail: a searchable picker with thumbnail rows.
    await tester.tap(field);
    await rec.hold(const Duration(milliseconds: 700));
    expect(find.byKey(const ValueKey('texture_picker_search')), findsOneWidget);
    // One row per project texture, plus the "Recently used" rows on
    // top (the recents live in the editor config, so a texture an earlier
    // scenario of this file picked shows there too). Every row has
    // its thumbnail.
    Finder pickerRows(String kind) => find.descendant(
        of: find.byType(AssetPickerPopup),
        matching: find.byWidgetPredicate(
            (w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('texture_picker_${kind}_')));
    final recentRows = pickerRows('recent').evaluate().map((e) => (e.widget.key as ValueKey<String>).value).toList();
    debugPrint('[material_smoke] picker recents: $recentRows');
    expect(pickerRows('item'), findsNWidgets(vm.availableTextures.length));
    for (final key in recentRows) {
      final file = key.substring('texture_picker_recent_'.length);
      expect(vm.availableTextures.any((t) => t.fileName == file), isTrue, reason: 'a recent row is one of the project textures ($file)');
    }
    expect(find.descendant(of: find.byType(AssetPickerPopup), matching: find.byType(AssetThumbnail)),
        findsNWidgets(vm.availableTextures.length + recentRows.length));
    await rec.typeText(find.byKey(const ValueKey('texture_picker_search')), 'barrel', perCharacter: const Duration(milliseconds: 120));
    const barrelTexture = 'T_fuel_barrel_red_loot_barrel_bc.jpg';
    expect(find.byKey(const ValueKey('texture_picker_item_$barrelTexture.lmas')), findsOneWidget);
    expect(find.descendant(of: find.byType(AssetPickerPopup), matching: find.byType(AssetThumbnail)), findsOneWidget);
    final pickerPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    SmokeArtifacts.saveScreenshot('material_editor_node_texture_picker', pickerPng, usedAssets: project.sources);
    await tester.tap(find.byKey(const ValueKey('texture_picker_item_$barrelTexture.lmas')));
    await rec.hold(const Duration(milliseconds: 1500));

    // The node, the panel and the preview follow.
    expect(find.descendant(of: field, matching: find.text(barrelTexture)), findsOneWidget);
    expect(vm.parameters.firstWhere((p) => p.name == 'baseColorMap').textureRef!.assetPath, endsWith('$barrelTexture.lmas'));
    expect(vm.graph.transactions.undoLabel, 'Undo Set baseColorMap texture');
    await tester.tap(find.text('GLSL Source (.mat)'));
    await rec.hold(const Duration(milliseconds: 2000));
    final after = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    SmokeArtifacts.saveScreenshot('material_editor_node_texture_picked', after, usedAssets: project.sources);
    expect(_previewStats(tester, after).warm, lessThan(_previewStats(tester, before).warm ~/ 2),
        reason: 'the grey barrel texture replaced the skin on the sphere');

    // Undo from the graph toolbar puts the skin back.
    await tester.tap(find.text('Node Graph'));
    await rec.hold(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey('material_graph_undo')));
    await rec.hold(const Duration(milliseconds: 1500));
    expect(vm.parameters.firstWhere((p) => p.name == 'baseColorMap').textureRef!.assetPath, isNot(endsWith('$barrelTexture.lmas')));
    final c = tester.getCenter(find.byType(FilamentWidget));
    await rec.drag(c - const Offset(80, 0), c + const Offset(80, 0), steps: 45);
    await rec.hold(const Duration(milliseconds: 800));

    rec.save('Material Editor Smoke: the Texture Sample node shows its thumbnail and picks another texture with search',
        usedAssets: project.sources);
  });

  const matcScenario = 'Material Editor Smoke: a vertex-block material compiled by matc renders in the preview and in a level';
  testWidgets(matcScenario, (tester) async {
    final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/dented_barrel.glb');
    expect(barrel.existsSync(), isTrue, reason: 'test-assets must hold the dented barrel');
    final usedAssets = [barrel.path];

    // A whole Filament material definition: unlit, fade blending, the vertex
    // block after the fragment, a wave along the normal and a tint handed to
    // the fragment through `variables`, both driven by the frame time.
    const source = '''material {
    name : M_MatcWave,
    shadingModel : unlit,
    blending : fade,
    requires : [ tangents ],
    variables : [ tint ],
    parameters : [
        { type : float, name : amplitude }
    ]
}

fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = vec4(variable_tint.rgb * 0.9, 0.85);
    }
}

vertex {
    void materialVertex(inout MaterialVertexInputs material) {
        float wave = sin(getPosition().y * 14.0 + getUserTime().x * 3.0);
        float scale = length(getWorldFromModelMatrix()[0].xyz);
        material.worldPosition.xyz += material.worldNormal * wave * materialParams.amplitude * scale;
        material.tint = vec4(mix(vec3(0.15, 0.45, 1.0), vec3(1.0, 0.2, 0.85), 0.5 + 0.5 * wave), 1.0);
    }
}
''';

    final root = Directory.systemTemp.createTempSync('lumina_smoke_matc_');
    final projectDir = Directory('${root.path}/MatcWave')..createSync();
    const project = LuminaProject(projectName: 'MatcWave', activeLevel: 'contents/levels/L_Main.lmas');
    File('${projectDir.path}/MatcWave.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    Directory('${projectDir.path}/contents/levels').createSync(recursive: true);
    Directory('${projectDir.path}/lib').createSync(recursive: true);
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    final server = vm.mcpServer;
    expect(await tester.runAsync(() => server.start(port: 0)), isTrue);
    final client = McpTestClient(server.url!, server.token);

    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final boundaryKey = GlobalKey();
    try {
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));

      Future<McpToolReply> call(String tool, [Map<String, Object?> args = const {}]) async {
        McpToolReply? reply;
        Object? error;
        unawaited(client.callTool(tool, args).then((r) => reply = r, onError: (Object e) => error = e));
        while (reply == null && error == null) {
          await rec.hold(const Duration(milliseconds: 66));
        }
        if (error != null) throw error!;
        return reply!;
      }

      Future<Map<String, Object?>> ok(String tool, [Map<String, Object?> args = const {}]) async {
        final reply = await call(tool, args);
        expect(reply.isError, isFalse, reason: '$tool: ${reply.text}');
        return reply.data;
      }

      Future<Uint8List> shot(String name) async {
        await rec.hold(const Duration(milliseconds: 1500));
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot(name, png, usedAssets: usedAssets);
        return png;
      }

      /// Pixels of the tint's magenta end inside [rect] (a capture at ratio 1).
      int magenta(Uint8List png, Rect rect) {
        final d = img.decodePng(png)!;
        var n = 0;
        for (var y = rect.top.round(); y < rect.bottom.round(); y += 2) {
          for (var x = rect.left.round(); x < rect.right.round(); x += 2) {
            final p = d.getPixel(x.clamp(0, d.width - 1), y.clamp(0, d.height - 1));
            if (p.r > p.g + 50 && p.b > p.g + 40) n++;
          }
        }
        return n;
      }

      await tester.runAsync(() => client.handshake(clientName: 'claude-code'));

      // --- The barrel in the level ------------------------------------------------
      final imported = (await ok('import_asset', {'path': barrel.path}))['imported'] as List;
      final mesh = imported.cast<Map>().firstWhere((a) => a['type'] != 'texture' && a['type'] != 'filamat')['path'] as String;
      final spawned = await ok('spawn_actor_from_asset', {'asset': mesh, 'location': [400, 0, 0]});
      final actorId = (spawned['actor'] as Map)['id'] as String;
      await ok('focus_actor', {'id': actorId});
      await ok('set_camera', {'target': [400, 0, 45], 'distance': 330, 'pitch': 15});
      final before = await shot('material_editor_matc_level_before');
      final magentaBefore = magenta(before, Offset.zero & tester.getSize(find.byKey(boundaryKey)));

      // --- The material, through the Material Editor tab ----------------------
      const mat = 'contents/materials/M_MatcWave.lmas';
      await ok('create_asset', {'type': 'filamat', 'name': 'M_MatcWave'});
      await ok('set_material_source', {'asset': mat, 'source': source});
      final compiled = await call('compile_material', {'asset': mat, 'save': true});
      expect(compiled.data['ok'], isTrue, reason: compiled.text);
      await ok('set_material_parameter', {'asset': mat, 'name': 'amplitude', 'value': 0.04});
      await ok('compile_material', {'asset': mat, 'save': true});
      final got = await ok('get_material_source', {'asset': mat});
      expect(got['blending'], 'fade');
      expect(got['shading_model'], 'unlit');
      final editor = vm.editorSessionFor(vm.currentTab.id) as MaterialEditorViewModel;
      expect(editor.compiledBytes, isNotNull);
      final previewRect = tester.getRect(find.byType(FilamentWidget).last);
      final preview = await shot('material_editor_matc_vertex_block_preview');
      final previewMagenta = magenta(preview, previewRect);
      debugPrint('[matc_smoke] preview magenta pixels: $previewMagenta');
      expect(previewMagenta, greaterThan(40), reason: 'the vertex-stage tint shows on the preview');
      await rec.hold(const Duration(seconds: 3));

      // --- On the barrel in the level, in Play ---------------------------------------
      // The mesh's material slot takes the material; Play draws the level with it.
      await ok('set_static_mesh_material_slot', {'asset': mesh, 'slot': 0, 'material': mat});
      await ok('save_static_mesh', {'asset': mesh});
      await ok('start_pie');
      await rec.hold(const Duration(seconds: 2));
      final window = Offset.zero & tester.getSize(find.byKey(boundaryKey));
      final playing = await shot('material_editor_matc_vertex_block_level_play');
      final magentaPlaying = magenta(playing, window);
      debugPrint('[matc_smoke] level magenta pixels: editor before $magentaBefore, in Play $magentaPlaying');
      expect(magentaPlaying, greaterThan(magentaBefore + 40), reason: 'the barrel wears the matc-compiled material in Play');
      final played = await ok('pie_play_for', {'ms': 2000, 'screenshot': true, 'pause_after': false});
      debugPrint('[matc_smoke] pie_play_for: ${played.keys.toList()}');
      final agent = await call('viewport_screenshot', {'max_width': 1280});
      expect(agent.isError, isFalse, reason: agent.text);
      final image = agent.content.firstWhere((c) => c['type'] == 'image');
      SmokeArtifacts.saveScreenshot('material_editor_matc_level_as_the_agent_saw_it', base64Decode(image['data'] as String),
          usedAssets: usedAssets);

      while (rec.recorded < const Duration(milliseconds: 10500)) {
        await rec.hold(const Duration(milliseconds: 500));
      }
      rec.save(matcScenario, usedAssets: usedAssets);
      await ok('stop_pie');
    } finally {
      client.close();
      await tester.runAsync(server.stop);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
      try {
        root.deleteSync(recursive: true);
      } catch (_) {}
    }
  }, timeout: const Timeout(Duration(minutes: 10)));

  const variablesScenario =
      'Material Editor Smoke: a world-height tint passed through a vertex variable colours the preview and the barrel';
  testWidgets(variablesScenario, (tester) async {
    final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/dented_barrel.glb');
    expect(barrel.existsSync(), isTrue, reason: 'test-assets must hold the dented barrel');
    final usedAssets = [barrel.path];

    final root = Directory.systemTemp.createTempSync('lumina_smoke_vvar_');
    final projectDir = Directory('${root.path}/HeightTint')..createSync();
    const project = LuminaProject(projectName: 'HeightTint', activeLevel: 'contents/levels/L_Main.lmas');
    File('${projectDir.path}/HeightTint.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    Directory('${projectDir.path}/contents/levels').createSync(recursive: true);
    Directory('${projectDir.path}/lib').createSync(recursive: true);
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    final server = vm.mcpServer;
    expect(await tester.runAsync(() => server.start(port: 0)), isTrue);
    final client = McpTestClient(server.url!, server.token);

    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final boundaryKey = GlobalKey();
    try {
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));

      Future<McpToolReply> call(String tool, [Map<String, Object?> args = const {}]) async {
        McpToolReply? reply;
        Object? error;
        unawaited(client.callTool(tool, args).then((r) => reply = r, onError: (Object e) => error = e));
        while (reply == null && error == null) {
          await rec.hold(const Duration(milliseconds: 66));
        }
        if (error != null) throw error!;
        return reply!;
      }

      Future<Map<String, Object?>> ok(String tool, [Map<String, Object?> args = const {}]) async {
        final reply = await call(tool, args);
        expect(reply.isError, isFalse, reason: '$tool: ${reply.text}');
        return reply.data;
      }

      Future<Uint8List> shot(String name) async {
        await rec.hold(const Duration(milliseconds: 1500));
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot(name, png, usedAssets: usedAssets);
        return png;
      }

      /// The gradient's blue (low) and orange (high) pixels inside [rect],
      /// with their mean screen heights (a capture at ratio 1). [deep] only
      /// counts the deep blue of the gradient, not a light blue sky.
      ({int blue, int orange, double blueY, double orangeY}) tint(Uint8List png, Rect rect, {bool deep = false}) {
        final d = img.decodePng(png)!;
        var blue = 0, orange = 0;
        var blueY = 0.0, orangeY = 0.0;
        for (var y = rect.top.round(); y < rect.bottom.round(); y += 2) {
          for (var x = rect.left.round(); x < rect.right.round(); x += 2) {
            final p = d.getPixel(x.clamp(0, d.width - 1), y.clamp(0, d.height - 1));
            final isBlue = deep ? p.b > 60 && p.b > 2 * p.r + 10 && p.b > 2 * p.g : p.b > p.r + 30 && p.b > p.g + 10;
            if (isBlue) {
              blue++;
              blueY += y;
            } else if (p.r > p.b + 40 && p.r > p.g + 10) {
              orange++;
              orangeY += y;
            }
          }
        }
        return (blue: blue, orange: orange, blueY: blue == 0 ? 0 : blueY / blue, orangeY: orange == 0 ? 0 : orangeY / orange);
      }

      await tester.runAsync(() => client.handshake(clientName: 'claude-code'));

      // --- The barrel in the level ------------------------------------------------
      final imported = (await ok('import_asset', {'path': barrel.path}))['imported'] as List;
      final mesh = imported.cast<Map>().firstWhere((a) => a['type'] != 'texture' && a['type'] != 'filamat')['path'] as String;
      final spawned = await ok('spawn_actor_from_asset', {'asset': mesh, 'location': [400, 0, 0]});
      final actorId = (spawned['actor'] as Map)['id'] as String;
      await ok('focus_actor', {'id': actorId});
      await ok('set_camera', {'target': [400, 0, 45], 'distance': 330, 'pitch': 15});
      final window = Offset.zero & tester.getSize(find.byKey(boundaryKey));
      final levelBefore = tint(await shot('material_editor_vertex_variable_level_before'), window, deep: true);

      // --- The material, built as nodes by the agent ---------------------------------
      const mat = 'contents/materials/M_HeightTint.lmas';
      await ok('create_asset', {'type': 'filamat', 'name': 'M_HeightTint'});
      final initial = await ok('get_material_graph', {'asset': mat});
      await tester.tap(find.text('Node Graph').last);
      await rec.hold(const Duration(milliseconds: 600));
      await ok('set_material_settings', {'asset': mat, 'shading_model': 'unlit'});

      Future<String> add(String node, double x, double y, [Map<String, Object?>? settings]) async {
        final added = await ok('add_material_node', {'asset': mat, 'node': node, 'x': x, 'y': y, 'settings': ?settings});
        await rec.hold(const Duration(milliseconds: 250));
        return (added['node'] as Map)['id'] as String;
      }

      Future<Map<String, Object?>> connect(String from, String fromPin, String to, String toPin) async {
        final wired = await ok(
            'connect_material_pins', {'asset': mat, 'from_node': from, 'from_pin': fromPin, 'to_node': to, 'to_pin': toPin});
        await rec.hold(const Duration(milliseconds: 250));
        return wired;
      }

      // Vertex stage: world height → 0..1 → a blue-to-orange gradient, handed
      // to the fragment as the interpolant `heightTint`.
      final world = await add('mat_world_position', -1200, 0);
      final height = await add('mat_component_mask', -1000, 0, {'r': false, 'g': true, 'b': false, 'a': false});
      final scale = await add('mat_scalar_parameter', -1000, 120, {'name': 'heightScale', 'default': 0.5});
      final scaled = await add('mat_multiply', -800, 40);
      final offset = await add('mat_scalar_parameter', -800, 160, {'name': 'heightOffset', 'default': 0.5});
      final shifted = await add('mat_add', -650, 40);
      final alpha = await add('mat_clamp', -500, 40);
      // Deep colours: the preview's tone mapping lifts bright ones towards white.
      final low = await add('mat_constant3', -500, 200, {'value': [0.0, 0.04, 0.5]});
      final high = await add('mat_constant3', -500, 320, {'value': [0.5, 0.08, 0.0]});
      final gradient = await add('mat_lerp', -300, 160);
      final setter = await add('mat_set_vertex_variable', -100, 160, {'name': 'heightTint'});
      await connect(world, 'out', height, 'in');
      await connect(height, 'out', scaled, 'a');
      await connect(scale, 'out', scaled, 'b');
      await connect(scaled, 'out', shifted, 'a');
      await connect(offset, 'out', shifted, 'b');
      await connect(shifted, 'out', alpha, 'in');
      await connect(low, 'out', gradient, 'a');
      await connect(high, 'out', gradient, 'b');
      await connect(alpha, 'out', gradient, 'alpha');
      await connect(gradient, 'out', setter, 'value');
      // Fragment: read the interpolant into Base Color.
      final reader = await add('mat_vertex_variable', -100, -120, {'name': 'heightTint'});
      final wired = await connect(reader, 'rgb', 'material_output', 'base_color');
      expect((wired['sync'] as Map)['ahead'], isFalse, reason: '${wired['diagnostics']}');
      final ours = {world, height, scale, offset, scaled, shifted, alpha, low, high, gradient, setter, reader, 'material_output'};
      for (final n in (initial['nodes'] as List).cast<Map>()) {
        if (!ours.contains(n['id'])) await ok('remove_material_node', {'asset': mat, 'node': n['id']});
      }
      await ok('arrange_material_graph', {'asset': mat});
      // Zoom the canvas out so the whole graph, both stages, is on screen.
      final canvasRect = tester.getRect(find.byType(BlueprintGraphCanvas).last);
      final wheel = TestPointer(78, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(wheel.hover(canvasRect.center));
      for (var i = 0; i < 6; i++) {
        await tester.sendEventToBinding(wheel.scroll(const Offset(0, 40)));
        await rec.hold(const Duration(milliseconds: 250));
      }
      // Then centre the view on the graph (both stages).
      final nodes = (vm.editorSessionFor(vm.currentTab.id) as MaterialEditorViewModel).graph.graph.nodes;
      final left = nodes.map((n) => n.x).reduce(math.min);
      final right = nodes.map((n) => n.x + 200).reduce(math.max);
      final top = nodes.map((n) => n.y).reduce(math.min);
      final bottom = nodes.map((n) => n.y + 120).reduce(math.max);
      tester
          .state<BlueprintGraphCanvasState>(find.byType(BlueprintGraphCanvas).last)
          .frameCanvasPoint(Offset((left + right) / 2, (top + bottom) / 2));
      await rec.hold(const Duration(milliseconds: 400));

      final graph = await ok('get_material_graph', {'asset': mat});
      expect(graph['vertex_block'], 'graph');
      expect(graph['variables'], [
        {'name': 'heightTint', 'set_by': [setter], 'read_by': [reader]},
      ]);
      final source = (await ok('get_material_source', {'asset': mat}))['source'] as String;
      debugPrint('[vertex_variable_smoke] generated source:\n$source');
      expect(source, contains('variables : [ heightTint ]'));
      expect(source, contains('void materialVertex(inout MaterialVertexInputs material)'));
      expect(source, contains('variable_heightTint.rgb'));
      final compiled = await call('compile_material', {'asset': mat, 'save': true});
      expect(compiled.data['ok'], isTrue, reason: compiled.text);
      final editor = vm.editorSessionFor(vm.currentTab.id) as MaterialEditorViewModel;
      expect(editor.compiledBytes, isNotNull);

      // The preview sphere: blue at the bottom, orange at the top.
      final previewRect = tester.getRect(find.byType(FilamentWidget).last).deflate(8);
      final preview = tint(await shot('material_editor_vertex_variable_graph_and_preview'), previewRect);
      debugPrint('[vertex_variable_smoke] preview: $preview');
      expect(preview.blue, greaterThan(40), reason: 'the low end of the height gradient shows');
      expect(preview.orange, greaterThan(40), reason: 'the high end of the height gradient shows');
      expect(preview.blueY, greaterThan(preview.orangeY), reason: 'low world height is blue, high is orange');

      // The GLSL tab: the vertex block the graph wrote.
      await tester.tap(find.text('GLSL Source (.mat)').last);
      await rec.hold(const Duration(milliseconds: 600));
      expect(find.textContaining('material.heightTint = vec4('), findsWidgets);
      await shot('material_editor_vertex_variable_generated_source');
      await tester.tap(find.text('Node Graph').last);
      await rec.hold(const Duration(milliseconds: 600));

      // --- On the barrel in the level, in Play ---------------------------------------
      // The level is in centimetres: the gradient spans the barrel's 0–90 cm.
      await ok('set_material_parameter', {'asset': mat, 'name': 'heightScale', 'value': 0.011});
      await ok('set_material_parameter', {'asset': mat, 'name': 'heightOffset', 'value': 0.0});
      final recompiled = await call('compile_material', {'asset': mat, 'save': true});
      expect(recompiled.data['ok'], isTrue, reason: recompiled.text);
      await rec.hold(const Duration(milliseconds: 800));
      await ok('set_static_mesh_material_slot', {'asset': mesh, 'slot': 0, 'material': mat});
      await ok('save_static_mesh', {'asset': mesh});
      await ok('start_pie');
      await rec.hold(const Duration(seconds: 2));
      final playing = tint(await shot('material_editor_vertex_variable_level_play'), window, deep: true);
      debugPrint('[vertex_variable_smoke] level before $levelBefore, in Play $playing');
      expect(playing.blue, greaterThan(levelBefore.blue + 200), reason: 'the foot of the barrel wears the low end');
      expect(playing.orange, greaterThan(200), reason: 'the top of the barrel wears the high end');
      expect(playing.blueY, greaterThan(playing.orangeY), reason: 'low on the barrel is blue, high is orange');
      final agent = await call('viewport_screenshot', {'max_width': 1280});
      expect(agent.isError, isFalse, reason: agent.text);
      final image = agent.content.firstWhere((c) => c['type'] == 'image');
      SmokeArtifacts.saveScreenshot('material_editor_vertex_variable_level_as_the_agent_saw_it',
          base64Decode(image['data'] as String), usedAssets: usedAssets);

      while (rec.recorded < const Duration(milliseconds: 10500)) {
        await rec.hold(const Duration(milliseconds: 500));
      }
      rec.save(variablesScenario, usedAssets: usedAssets);
      await ok('stop_pie');
    } finally {
      client.close();
      await tester.runAsync(server.stop);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
      try {
        root.deleteSync(recursive: true);
      } catch (_) {}
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}

/// A temp project holding real imports: the CC body the user opened
/// (`M_Skin_Body_CCMH_CCMH_Body_Male`, four textures) when [CcBodyAsset]
/// finds it on this machine, else the textured AC unit from test-assets (the
/// node graph scenario holds for any textured material; the warm-skin scenarios skip without the body), plus a red barrel
/// whose texture the reassignment scenarios switch to. Which body was
/// imported, and why, is printed.
class _TexturedProject {
  final Directory root;
  final File bodyMaterial;
  final File barrelMaterial;
  final List<String> sources;
  _TexturedProject(this.root, this.bodyMaterial, this.barrelMaterial, this.sources);
}

Future<_TexturedProject> _importTexturedProject(WidgetTester tester) async {
  final root = Directory.systemTemp.createTempSync('lumina_smoke_material_import_');
  addTearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });
  Directory('${root.path}/contents').createSync();
  final ccBody = CcBodyAsset.resolve(CcBodyAsset.male);
  final prop = File('${SmokeArtifacts.testAssetsDir.path}/Props/AC_units/ac_unit_a_300x300.glb');
  final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb');
  final body = ccBody.file ?? prop;
  debugPrint(ccBody.file != null
      ? '[material_editor_smoke] textured source: the CC body ${body.path}'
      : '[material_editor_smoke] textured source: the AC unit ${prop.path}, because ${ccBody.skipReason}');
  for (final source in [body, barrel]) {
    expect(source.existsSync(), isTrue, reason: '${source.path} is a real source asset');
    await tester.runAsync(
      () => AssetRepository().importExternalFile(projectPath: root.path, sourceFilePath: source.path),
    );
  }
  File materialOf(File source) {
    final stem = source.uri.pathSegments.last.replaceAll(RegExp(r'\.glb$'), '');
    return Directory('${root.path}/contents/materials/$stem')
        .listSync()
        .whereType<File>()
        .firstWhere((f) => f.path.endsWith('.lmas'));
  }

  return _TexturedProject(root, materialOf(body), materialOf(barrel), [body.path, barrel.path]);
}

Widget _editorByPath(GlobalKey boundaryKey, String name, String path) => RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SizedBox(width: 1400, height: 820, child: MaterialSubEditor(assetName: name, assetPath: path)),
        ),
      ),
    );

/// Luminance variance and warm (red-leaning) pixel count inside the preview's
/// `FilamentWidget`, read from a boundary PNG captured at pixel ratio 1.
({double variance, int warm, int samples}) _previewStats(WidgetTester tester, Uint8List png) {
  final decoded = img.decodePng(png)!;
  final rect = tester.getRect(find.byType(FilamentWidget)).deflate(12);
  var n = 0, warm = 0;
  var sum = 0.0, sumSq = 0.0;
  for (var y = rect.top.round(); y < rect.bottom.round(); y += 2) {
    for (var x = rect.left.round(); x < rect.right.round(); x += 2) {
      final p = decoded.getPixel(x.clamp(0, decoded.width - 1), y.clamp(0, decoded.height - 1));
      final lum = (p.r + p.g + p.b) / 3.0;
      sum += lum;
      sumSq += lum * lum;
      n++;
      if (p.r > p.b + 25 && p.r > 60) warm++;
    }
  }
  final mean = sum / n;
  return (variance: sumSq / n - mean * mean, warm: warm, samples: n);
}

/// Mean absolute RGB difference between two captures inside the preview.
double _previewDifference(WidgetTester tester, Uint8List a, Uint8List b) {
  final da = img.decodePng(a)!, db = img.decodePng(b)!;
  final rect = tester.getRect(find.byType(FilamentWidget)).deflate(12);
  var sum = 0.0;
  var n = 0;
  for (var y = rect.top.round(); y < rect.bottom.round(); y += 2) {
    for (var x = rect.left.round(); x < rect.right.round(); x += 2) {
      final p = da.getPixel(x, y), q = db.getPixel(x, y);
      sum += ((p.r - q.r).abs() + (p.g - q.g).abs() + (p.b - q.b).abs()) / 3;
      n++;
    }
  }
  return sum / n;
}
