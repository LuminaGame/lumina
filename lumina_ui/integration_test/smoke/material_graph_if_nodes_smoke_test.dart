import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_filament/flutter_filament.dart' show FilamentWidget;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/material_logic_nodes.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/graph_canvas.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../test/helpers/mcp_test_client.dart';

/// The triplanar material a user wrote by hand (world-space UVs picked by the
/// dominant axis of the geometric normal with an if / else if / else) opens
/// in the Node Graph as Compare, And and If nodes, a Compare's operator is
/// changed on its node, and the regenerated material compiles and shades the
/// small air-conditioner from test-assets in the preview.
const _triplanar = '''material {
    name : "Mobile_Optimized_PBR_Triplanar",
    shadingModel : lit,
    blending : opaque,
    requires : [ tangents ],
    parameters : [
        { type : sampler2d, name : mapColor },
        { type : sampler2d, name : mapNormal },
        { type : sampler2d, name : mapRoughness },
        { type : sampler2d, name : mapAO }
    ]
}

fragment {
    void material(inout MaterialInputs material) {
        vec3 worldPos = getUserWorldPosition();
        vec3 n = abs(getWorldGeometricNormalVector());
        vec2 finalUV;
        if (n.x >= n.y && n.x >= n.z) {
            finalUV = worldPos.yz;
        } else if (n.y >= n.x && n.y >= n.z) {
            finalUV = worldPos.xz;
        } else {
            finalUV = worldPos.xy;
        }
        vec3 albedo = texture(materialParams_mapColor, finalUV).rgb;
        vec3 normal = texture(materialParams_mapNormal, finalUV).rgb;
        float roughness = texture(materialParams_mapRoughness, finalUV).r;
        float ao = texture(materialParams_mapAO, finalUV).r;
        material.normal = normal * 2.0 - 1.0;
        material.ambientOcclusion = ao;
        prepareMaterial(material);
        material.baseColor = vec4(albedo, 1.0);
        material.roughness = roughness;
        material.metallic = 0.0;
    }
}
''';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenario = 'Material Editor Smoke: triplanar material as a graph with if nodes';
  testWidgets(scenario, (tester) async {
    final aircon = File('${SmokeArtifacts.testAssetsDir.path}/Props/AC_units/aircon_small.glb');
    expect(aircon.existsSync(), isTrue, reason: 'test-assets must hold the small air-conditioner');
    final usedAssets = [aircon.path];

    final root = Directory.systemTemp.createTempSync('lumina_smoke_triplanar_');
    final projectDir = Directory('${root.path}/Triplanar')..createSync();
    const project = LuminaProject(projectName: 'Triplanar', activeLevel: 'contents/levels/L_Main.lmas');
    File('${projectDir.path}/Triplanar.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
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

      Future<void> waitFor(Finder finder) async {
        for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
          await rec.hold(const Duration(milliseconds: 66));
        }
        expect(finder, findsWidgets);
      }

      await tester.runAsync(() => client.handshake(clientName: 'claude-code'));

      // --- The air-conditioner and its textures --------------------------------
      final imported = ((await ok('import_asset', {'path': aircon.path}))['imported'] as List).cast<Map>();
      final textures = [for (final a in imported) if (a['type'] == 'texture') a['path'] as String];
      expect(textures, isNotEmpty, reason: 'the air-conditioner brings its textures');
      final mesh = imported.firstWhere((a) => a['type'] != 'texture' && a['type'] != 'filamat')['path'] as String;

      // --- The hand-written triplanar material ----------------------------------
      const mat = 'contents/materials/M_Triplanar.lmas';
      await ok('create_asset', {'type': 'filamat', 'name': 'M_Triplanar'});
      await ok('set_material_source', {'asset': mat, 'source': _triplanar});
      // Compiling reads the header's samplers into the parameters panel.
      final first = await call('compile_material', {'asset': mat, 'save': true});
      expect(first.data['ok'], isTrue, reason: first.text);
      for (final (k, sampler) in ['mapColor', 'mapNormal', 'mapRoughness', 'mapAO'].indexed) {
        final texture = textures.firstWhere((t) => t.toLowerCase().contains(switch (sampler) {
              'mapNormal' => 'normal',
              'mapRoughness' => 'rough',
              'mapAO' => 'occlusion',
              _ => 'color',
            }), orElse: () => textures[k % textures.length]);
        await ok('set_material_texture', {'asset': mat, 'parameter': sampler, 'texture': texture});
      }

      // --- The Node Graph: If, Compare and And nodes, wired ----------------------
      await tester.tap(find.text('Node Graph').last);
      await rec.hold(const Duration(milliseconds: 600));
      final editor = vm.editorSessionFor(vm.currentTab.id) as MaterialEditorViewModel;
      expect(editor.graph.fallbackReason, isNull, reason: 'the if / else chain is nodes, not a Custom (Fragment)');
      final graph = editor.graph.graph;
      List<String> ids(String kind) => [for (final n in graph.nodes) if (n.registryId == kind) n.id];
      final compares = ids(MaterialLogicNodes.compare);
      final ands = ids(MaterialLogicNodes.and);
      final ifs = ids(MaterialLogicNodes.ifNode);
      expect((compares.length, ands.length, ifs.length), (4, 2, 2));
      for (final id in [...compares, ...ands, ...ifs]) {
        expect(find.byKey(ValueKey('node_$id')), findsOneWidget, reason: 'node $id is on the canvas');
        expect(graph.wires.any((w) => w.fromNodeId == id), isTrue, reason: 'node $id feeds something');
      }
      await ok('arrange_material_graph', {'asset': mat});
      final canvasRect = tester.getRect(find.byType(BlueprintGraphCanvas).last);
      final wheel = TestPointer(79, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(wheel.hover(canvasRect.center));
      for (var i = 0; i < 5; i++) {
        await tester.sendEventToBinding(wheel.scroll(const Offset(0, 40)));
        await rec.hold(const Duration(milliseconds: 200));
      }
      final canvas = tester.state<BlueprintGraphCanvasState>(find.byType(BlueprintGraphCanvas).last);
      final left = graph.nodes.map((n) => n.x).reduce(math.min);
      final right = graph.nodes.map((n) => n.x + 200).reduce(math.max);
      final top = graph.nodes.map((n) => n.y).reduce(math.min);
      final bottom = graph.nodes.map((n) => n.y + 120).reduce(math.max);
      canvas.frameCanvasPoint(Offset((left + right) / 2, (top + bottom) / 2));
      await rec.hold(const Duration(milliseconds: 400));
      await shot('material_editor_triplanar_if_nodes_graph');

      // --- A Compare's operator changed on its node -------------------------------
      // The first comparison of the outer If's condition: n.x >= n.y becomes >.
      final outer = ifs.firstWhere((id) => graph.node(graph.wireInto(id, 'else')!.fromNodeId)!.registryId == MaterialLogicNodes.ifNode);
      final outerAnd = graph.wireInto(outer, 'condition')!.fromNodeId;
      final cmp = graph.wireInto(outerAnd, 'a')!.fromNodeId;
      final cmpNode = graph.node(cmp)!;
      // Back to 100 % so the select on the node is a comfortable target.
      for (var i = 0; i < 5; i++) {
        await tester.sendEventToBinding(wheel.scroll(const Offset(0, -40)));
        await rec.hold(const Duration(milliseconds: 150));
      }
      canvas.frameCanvasPoint(Offset(cmpNode.x + 80, cmpNode.y + 40));
      await rec.hold(const Duration(milliseconds: 500));
      final select = find.byKey(ValueKey('node_compare_op_$cmp'));
      await waitFor(select);
      debugPrint('[triplanar_if_smoke] operator select at ${tester.getRect(select)}');
      await tester.tap(select);
      await rec.hold(const Duration(milliseconds: 600));
      final option = find.byKey(const ValueKey('node_compare_op_option_>'));
      debugPrint('[triplanar_if_smoke] options shown: ${option.evaluate().length}');
      await waitFor(option);
      await tester.tap(option.last);
      await rec.hold(const Duration(milliseconds: 600));
      expect(MaterialLogicNodes.operatorOf(editor.graph.graph.node(cmp)!), '>');
      expect(editor.graph.analysis.hasErrors, isFalse, reason: '${editor.graph.analysis.diagnostics}');
      final source = (await ok('get_material_source', {'asset': mat}))['source'] as String;
      debugPrint('[triplanar_if_smoke] generated source:\n$source');
      expect(source, contains('vec2 finalUV = ((('));
      expect(source, contains('(n.r > n.g)'));
      expect(source, isNot(contains('if (')));
      await shot('material_editor_triplanar_if_nodes_compare_changed');

      // --- Compile, preview on the air-conditioner --------------------------------
      final compiled = await call('compile_material', {'asset': mat, 'save': true});
      expect(compiled.data['ok'], isTrue, reason: compiled.text);
      expect(editor.compiledBytes, isNotNull);
      await tester.tap(find.byKey(const ValueKey('material_preview_custom')).last);
      await waitFor(find.byKey(const ValueKey('material_preview_mesh_picker')));
      await tester.tap(find.byKey(const ValueKey('material_preview_mesh_value')).last);
      await rec.hold(const Duration(milliseconds: 500));
      final meshFile = mesh.split('/').last;
      await tester.tap(find.byKey(ValueKey('material_preview_mesh_item_$meshFile')).last);
      await rec.hold(const Duration(seconds: 2));
      final preview = await shot('material_editor_triplanar_if_nodes_preview_aircon');
      final stats = _stats(preview, tester.getRect(find.byType(FilamentWidget).last).deflate(8));
      debugPrint('[triplanar_if_smoke] preview luminance mean ${stats.mean}, deviation ${stats.deviation}');
      expect(stats.deviation, greaterThan(4), reason: 'the textured air-conditioner shades the preview');

      // Orbit the preview while the clip runs to its length.
      final c = tester.getCenter(find.byType(FilamentWidget).last);
      while (rec.recorded < const Duration(milliseconds: 10500)) {
        await rec.drag(c - const Offset(70, 0), c + const Offset(70, 0), steps: 30);
      }
      rec.save(scenario, usedAssets: usedAssets);
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

/// Mean and standard deviation of luminance inside [rect] of a capture at
/// pixel ratio 1.
({double mean, double deviation}) _stats(Uint8List png, Rect rect) {
  final d = img.decodePng(png)!;
  var n = 0;
  var sum = 0.0, sumSq = 0.0;
  for (var y = rect.top.round(); y < rect.bottom.round(); y += 2) {
    for (var x = rect.left.round(); x < rect.right.round(); x += 2) {
      final p = d.getPixel(x.clamp(0, d.width - 1), y.clamp(0, d.height - 1));
      final lum = (p.r + p.g + p.b) / 3.0;
      sum += lum;
      sumSq += lum * lum;
      n++;
    }
  }
  final mean = sum / n;
  return (mean: mean, deviation: math.sqrt(math.max(0, sumSq / n - mean * mean)));
}
