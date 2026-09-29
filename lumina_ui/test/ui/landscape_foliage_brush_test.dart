// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/landscape_brush.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/landscape_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/landscape/foliage_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'landscape_editor_test.dart' show RecordingTerrainSink;

/// The foliage brush's own Brush Size, Brush Falloff,
/// Paint Density and Erase Density, applied by the scatter and erase code and
/// persisted per project with the sculpt brush.
final _barrel = '${Directory.current.parent.path}/test-assets/Props/Barrels/fuel_barrel_red.glb';

void main() {
  late Directory tempDir;
  setUp(() => tempDir = Directory.systemTemp.createTempSync('lumina_landscape_foliage_brush_'));
  tearDown(() => tempDir.deleteSync(recursive: true));

  LandscapeEditorViewModel makeVm({int seed = 7}) {
    final vm = LandscapeEditorViewModel(
      assetPath: '${tempDir.path}/contents/landscapes/Terrain.lmas',
      sink: RecordingTerrainSink(),
      randomSeed: seed,
    )..open();
    vm.addFoliageLayer(meshAssetId: 'fuel_barrel_red', meshAssetPath: _barrel, name: 'Barrels');
    vm.setLayerRules(0, const FoliageRules(density: 60.0, minSpacing: 0.3, slopeMaxDegrees: 90.0));
    return vm;
  }

  /// Instances of layer 0 per m² between normalised radii [t0] and [t1] of a
  /// brush of [radius] at the origin.
  double densityIn(LandscapeEditorViewModel vm, double radius, double t0, double t1) {
    final layer = vm.data.layers[0];
    var n = 0;
    for (var i = 0; i < layer.instanceCount; i++) {
      final inst = layer.instanceAt(i);
      final t = math.sqrt(inst.x * inst.x + inst.z * inst.z) / radius;
      if (t >= t0 && t < t1) n++;
    }
    final area = math.pi * radius * radius * (t1 * t1 - t0 * t0);
    return n / area;
  }

  test('scatter thins out across the falloff band', () {
    final soft = makeVm();
    soft.setFoliageBrushRadius(20.0);
    soft.setFoliageBrushFalloff(0.6);
    soft.setPaintDensity(1.0);
    expect(soft.paintFoliage(0.0, 0.0), greaterThan(0));
    final core = densityIn(soft, 20.0, 0.0, 0.4);
    final rim = densityIn(soft, 20.0, 0.8, 1.0);
    expect(core, greaterThan(3 * rim), reason: 'core $core/m² vs rim $rim/m² with falloff 0.6');
    soft.dispose();

    final hard = makeVm();
    hard.setFoliageBrushRadius(20.0);
    hard.setFoliageBrushFalloff(0.0);
    hard.setPaintDensity(1.0);
    hard.paintFoliage(0.0, 0.0);
    final hCore = densityIn(hard, 20.0, 0.0, 0.4);
    final hRim = densityIn(hard, 20.0, 0.8, 1.0);
    expect((hCore - hRim).abs() / hCore, lessThan(0.35), reason: 'a hard brush is uniform: $hCore vs $hRim');
    hard.dispose();
  });

  test('Paint Density scales what one pass lays down', () {
    int placedWith(double density) {
      final vm = makeVm(seed: 11);
      vm.setFoliageBrushRadius(20.0);
      vm.setFoliageBrushFalloff(0.0);
      vm.setPaintDensity(density);
      final n = vm.paintFoliage(0.0, 0.0);
      vm.dispose();
      return n;
    }

    final full = placedWith(1.0);
    final quarter = placedWith(0.25);
    expect(quarter / full, closeTo(0.25, 0.25 * 0.3), reason: '$quarter of $full');
  });

  test('Erase Density 0 clears the core and thins the band; 0.5 keeps about half', () {
    final vm = makeVm();
    vm.setFoliageBrushRadius(20.0);
    vm.setFoliageBrushFalloff(0.0);
    vm.setPaintDensity(1.0);
    vm.paintFoliage(0.0, 0.0);
    final bandBefore = densityIn(vm, 20.0, 0.5, 1.0);

    vm.setFoliageBrushFalloff(0.5);
    vm.setEraseDensity(0.0);
    expect(vm.eraseFoliage(0.0, 0.0), greaterThan(0));
    expect(densityIn(vm, 20.0, 0.0, 0.5), 0.0, reason: 'the full-strength core is cleared');
    final bandAfter = densityIn(vm, 20.0, 0.5, 1.0);
    expect(bandAfter, greaterThan(0.0), reason: 'the falloff band keeps some instances');
    expect(bandAfter, lessThan(bandBefore), reason: 'the falloff band is thinned');
    vm.dispose();

    final half = makeVm(seed: 3);
    half.setFoliageBrushRadius(20.0);
    half.setFoliageBrushFalloff(0.0);
    half.setPaintDensity(1.0);
    half.paintFoliage(0.0, 0.0);
    final before = half.data.layers[0].instanceCount;
    half.setEraseDensity(0.5);
    half.eraseFoliage(0.0, 0.0);
    expect(half.data.layers[0].instanceCount / before, closeTo(0.5, 0.15));
    half.dispose();
  });

  test('scatter uses the foliage brush size, not the sculpt brush', () {
    final vm = makeVm();
    vm.setBrushRadius(120.0);
    vm.setFoliageBrushRadius(6.0);
    vm.setFoliageBrushFalloff(0.0);
    vm.paintFoliage(10.0, -5.0);
    final layer = vm.data.layers[0];
    expect(layer.instanceCount, greaterThan(0));
    for (var i = 0; i < layer.instanceCount; i++) {
      final inst = layer.instanceAt(i);
      final d = math.sqrt((inst.x - 10.0) * (inst.x - 10.0) + (inst.z + 5.0) * (inst.z + 5.0));
      expect(d, lessThanOrEqualTo(6.0 + 1e-9));
    }
    vm.dispose();
  });

  test('both brushes persist per project, in cm, and come back on the next open', () {
    final vm = makeVm();
    vm.setTool(LandscapeTool.smooth);
    vm.setBrushRadius(12.5);
    vm.setBrushStrength(0.3);
    vm.setBrushFalloff(0.7);
    vm.setFalloffType(LandscapeFalloffType.linear);
    vm.setFoliageBrushRadius(8.0);
    vm.setFoliageBrushFalloff(0.35);
    vm.setPaintDensity(0.8);
    vm.setEraseDensity(0.2);
    vm.dispose();

    final file = File('${tempDir.path}/.lumina/landscape_brush.json');
    expect(file.existsSync(), isTrue);
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(json['units'], 'cm');
    expect((json['sculpt'] as Map)['size_cm'], 1250);
    expect((json['foliage'] as Map)['size_cm'], 800);

    final again = LandscapeEditorViewModel(
      assetPath: '${tempDir.path}/contents/landscapes/Other.lmas',
      sink: RecordingTerrainSink(),
    )..open();
    expect(again.tool, LandscapeTool.smooth);
    expect(again.brushRadius, closeTo(12.5, 1e-9));
    expect(again.brushStrength, closeTo(0.3, 1e-9));
    expect(again.brushFalloff, closeTo(0.7, 1e-9));
    expect(again.falloffType, LandscapeFalloffType.linear);
    expect(again.foliageBrushRadius, closeTo(8.0, 1e-9));
    expect(again.foliageBrushFalloff, closeTo(0.35, 1e-9));
    expect(again.paintDensity, closeTo(0.8, 1e-9));
    expect(again.eraseDensity, closeTo(0.2, 1e-9));
    again.dispose();
  });

  testWidgets('the Foliage panel has its own brush section with live values', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
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
    await tester.tap(find.byKey(const ValueKey('landscape_tab_foliage')));
    await tester.pump(const Duration(milliseconds: 200));
    final vm = (tester.state(find.byType(LandscapeFoliageSubEditor)) as dynamic).viewModelForTest as LandscapeEditorViewModel;

    expect(find.text('BRUSH'), findsOneWidget);
    expect(find.textContaining('Brush Size (1000 cm)'), findsOneWidget);
    expect(find.textContaining('Brush Falloff (0.50)'), findsOneWidget);
    expect(find.textContaining('Paint Density (0.50)'), findsOneWidget);
    expect(find.textContaining('Erase Density (0.00)'), findsOneWidget);

    tester.widget<SliderField>(find.byKey(const ValueKey('landscape_foliage_brush_size'))).onCommit(2500.0);
    tester.widget<SliderField>(find.byKey(const ValueKey('landscape_foliage_brush_falloff'))).onCommit(0.25);
    tester.widget<SliderField>(find.byKey(const ValueKey('landscape_foliage_paint_density'))).onCommit(0.9);
    tester.widget<SliderField>(find.byKey(const ValueKey('landscape_foliage_erase_density'))).onCommit(0.4);
    await tester.pump(const Duration(milliseconds: 100));
    expect(vm.foliageBrushRadius, closeTo(25.0, 1e-9));
    expect(vm.foliageBrushFalloff, 0.25);
    expect(vm.paintDensity, 0.9);
    expect(vm.eraseDensity, 0.4);
    expect(find.textContaining('Brush Size (2500 cm)'), findsOneWidget);
  });
}
