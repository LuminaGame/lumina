import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_service.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_settings.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/landscape_asset_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/landscape_brush_preferences.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/landscape_preview_scene.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/landscape_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/landscape/landscape.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show ShadcnApp, Size, SizedBox;

import '../helpers/mcp_test_client.dart';
import '../helpers/temp_project.dart';

/// The Landscape editor as MCP tools, through a real
/// JSON-RPC-over-HTTP client against a real temp project: `create_asset`
/// writes a real flat terrain, a real 16-bit heightmap PNG is imported,
/// stroke lists sculpt and foliate it (the red fuel barrel from test-assets
/// as the foliage mesh), 04's scoped undo reverts the strokes, and the tab's
/// widget adopts the tool's view model and its Filament preview scene.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late String projectDir;
  late EditorViewModel vm;
  late McpServerService server;
  late McpTestClient client;

  final assets = '${Directory.current.parent.path}/test-assets';
  const ls = 'contents/landscapes/LS_Agent.lmas';
  const barrelMesh = 'contents/meshes/static/fuel_barrel_red.lmas';

  Future<Map<String, Object?>> ok(String tool, [Map<String, Object?> args = const {}]) async {
    final reply = await client.callTool(tool, args);
    expect(reply.isError, isFalse, reason: '$tool: ${reply.text}');
    return reply.data;
  }

  /// A refusal: a tool error, or a -32602 for arguments the schema rejects.
  Future<String> refused(String tool, Map<String, Object?> args) async {
    try {
      final reply = await client.callTool(tool, args);
      expect(reply.isError, isTrue, reason: '$tool should refuse: ${reply.text}');
      return reply.text;
    } on McpRpcError catch (e) {
      return e.message;
    }
  }

  Future<int> rpcCode(String tool, Map<String, Object?> args) async {
    try {
      final reply = await client.callTool(tool, args);
      fail('$tool should be a -32602: ${reply.text}');
    } on McpRpcError catch (e) {
      return e.code;
    }
  }

  LandscapeEditorViewModel session() =>
      vm.editorSessionFor(vm.realAssets.firstWhere((a) => a.relativePath == ls).lmasPath!) as LandscapeEditorViewModel;

  /// A real 16-bit grayscale PNG on disk: a radial cosine hill of radius
  /// [hillFraction] × half the side, flat outside.
  String writeHeightmap(String name, int side, {double hillFraction = 0.78}) {
    final image = img.Image(width: side, height: side, numChannels: 1, format: img.Format.uint16);
    final c = (side - 1) / 2;
    final radius = c * hillFraction;
    for (var y = 0; y < side; y++) {
      for (var x = 0; x < side; x++) {
        final r = math.sqrt((x - c) * (x - c) + (y - c) * (y - c));
        final h = r >= radius ? 0.0 : 0.5 + 0.5 * math.cos(math.pi * r / radius);
        image.setPixelR(x, y, (h * 65535).round());
      }
    }
    final file = File('${root.path}/$name')..writeAsBytesSync(img.encodePng(image));
    return file.path;
  }

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_mcp_landscape_');
    final configDir = Directory('${root.path}/config')..createSync();
    projectDir = '${root.path}/AgentLand';
    Directory(projectDir).createSync();
    const project = LuminaProject(projectName: 'AgentLand', activeLevel: 'contents/levels/L_Main.lmas');
    File('$projectDir/AgentLand.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    Directory('$projectDir/contents/levels').createSync(recursive: true);
    Directory('$projectDir/lib').createSync(recursive: true);
    vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    server = McpServerService(vm, configDir: configDir, settings: McpServerSettings.load(configDir: configDir));
    expect(await server.start(port: 0), isTrue);
    client = McpTestClient(server.url!, server.token);
    await client.handshake();
    await ok('import_asset', {'path': '$assets/Props/Barrels/fuel_barrel_red.glb'});
    expect(File('$projectDir/$barrelMesh').existsSync(), isTrue);
  });

  tearDownAll(() async {
    client.close();
    await server.stop();
    await vm.close();
    await deleteTempProject(root);
  });

  test('asset_editor_screenshot with no editor mounted is a tool error', () async {
    await ok('create_asset', {'type': 'landscape', 'name': 'LS_Unshown'});
    final text = await refused('asset_editor_screenshot', {'asset': 'contents/landscapes/LS_Unshown.lmas'});
    expect(text.toLowerCase(), contains('the asset editor is not shown'));
    // The tab it opened would be mounted by the widget tests below.
    vm.closeTab(vm.openTabs.indexWhere((t) => t.asset?.relativePath == 'contents/landscapes/LS_Unshown.lmas'));
  });

  test('create_asset writes a real flat terrain; a resolution that does not tile names the nearest ones', () async {
    final created = await ok('create_asset', {
      'type': 'landscape',
      'name': 'LS_Agent',
      'grid_resolution': 129,
      'world_size_cm': 25600,
      'max_height_cm': 10000,
    });
    expect(created['path'], ls);
    final data = LandscapeAssetService.load('$projectDir/$ls');
    expect(data, isNotNull, reason: 'a LANDSCAPE payload, not the empty .lmas of before');
    expect(data!.gridResolution, 129);
    expect(data.worldSize, closeTo(256, 1e-9));
    expect(data.maxHeight, closeTo(100, 1e-9));
    expect(data.heightMax - data.heightMin, 0, reason: 'flat');

    final bad = await refused('create_asset', {'type': 'landscape', 'name': 'LS_Bad', 'grid_resolution': 100});
    expect(bad, allOf(contains('65'), contains('129')));
    expect(File('$projectDir/contents/landscapes/LS_Bad.lmas').existsSync(), isFalse);
  });

  test('get_landscape reports the terrain in cm, its brushes and its undo', () async {
    final info = await ok('get_landscape', {'asset': ls});
    expect(info['grid_resolution'], 129);
    expect(info['world_size_cm'], closeTo(25600, 1e-6));
    expect(info['max_height_cm'], closeTo(10000, 1e-6));
    expect(info['section_count'], 4);
    expect(info['foliage_layers'], isEmpty);
    expect(info['can_undo'], isFalse);
    expect(info['is_dirty'], isFalse);
    expect((info['sculpt_brush'] as Map).keys, containsAll(['tool', 'radius_cm', 'strength', 'falloff', 'falloff_type']));
    expect((info['foliage_brush'] as Map).keys, containsAll(['radius_cm', 'falloff', 'paint_density', 'erase_density']));
    expect(vm.currentTab.asset?.relativePath, ls, reason: 'the tool opened the landscape tab');
  });

  test('sculpt stroke lists: one undo entry per stroke, invert lowers, scoped undo restores the heights, the brush file is kept', () async {
    final brush = await ok('set_landscape_brush', {'asset': ls, 'tool': 'smooth', 'radius_cm': 3000, 'strength': 0.3, 'falloff': 0.4});
    expect(brush['sculpt_brush'], containsPair('radius_cm', closeTo(3000, 1e-6)));
    // The slider's clamp: 100–20 000 cm.
    expect((await ok('set_landscape_brush', {'asset': ls, 'radius_cm': 50000}))['sculpt_brush'], containsPair('radius_cm', closeTo(20000, 1e-6)));
    await ok('set_landscape_brush', {'asset': ls, 'radius_cm': 3000});
    final brushFile = LandscapeBrushPreferences.fileFor(projectDir);
    expect(brushFile.existsSync(), isTrue);
    final brushBefore = brushFile.readAsStringSync();

    final editor = session();
    final flat = [for (var i = 0; i < editor.data.vertexCount; i++) editor.data.heightAtIndex(i)];
    final levelUndo = vm.transactions.history().length;
    final h0 = editor.data.sampleHeight(20, 0);

    final raised = await ok('sculpt_landscape', {
      'asset': ls,
      'strokes': [
        {
          'points': [[0, 0], [2000, 0], [4000, 0]],
          'tool': 'sculpt',
          'radius_cm': 1500,
          'strength': 0.8,
        },
      ],
    });
    expect(raised['strokes'], hasLength(1));
    final h1 = editor.data.sampleHeight(20, 0);
    expect(h1, greaterThan(h0), reason: 'the stroke at [2000, 0] cm raised terrain metres (20, 0)');
    expect(raised['height_max_cm'], greaterThan(0));
    var info = await ok('get_landscape', {'asset': ls});
    expect(info['can_undo'], isTrue);
    expect(info['undo_label'], 'sculpt stroke');
    expect(info['is_dirty'], isTrue);

    await ok('sculpt_landscape', {
      'asset': ls,
      'strokes': [
        {
          'points': [[0, 0], [2000, 0], [4000, 0]],
          'tool': 'sculpt',
          'invert': true,
          'radius_cm': 1500,
          'strength': 0.8,
        },
      ],
    });
    expect(editor.data.sampleHeight(20, 0), lessThan(h1));
    expect(editor.undoDepth, 2);

    // The per-stroke overrides did not become the brush.
    expect(brushFile.readAsStringSync(), brushBefore);
    info = await ok('get_landscape', {'asset': ls});
    expect(info['sculpt_brush'], allOf(containsPair('tool', 'smooth'), containsPair('radius_cm', closeTo(3000, 1e-6))));

    // Undo scoped to the landscape asset, this agent's steps.
    final state = await ok('undo_state', {'asset': ls});
    expect(state['undo_label'], 'Undo sculpt stroke');
    expect(state['agent_depth'], 2);
    await ok('undo', {'asset': ls, 'scope': 'agent'});
    await ok('undo', {'asset': ls, 'scope': 'agent'});
    for (var i = 0; i < flat.length; i++) {
      if (editor.data.heightAtIndex(i) != flat[i]) fail('height $i is ${editor.data.heightAtIndex(i)} after undo, was ${flat[i]}');
    }
    expect(vm.transactions.history().length, levelUndo, reason: 'the level stack was never touched');
    await ok('redo', {'asset': ls});
    expect(editor.data.sampleHeight(20, 0), closeTo(h1, 1e-9));
    await ok('undo', {'asset': ls});
  });

  test('sculpt_landscape rejects a tool the editor does not have and oversized lists', () async {
    expect(await rpcCode('sculpt_landscape', {
      'asset': ls,
      'strokes': [
        {'points': [[0, 0]], 'tool': 'paint'},
      ],
    }), -32602);
    final text = await refused('sculpt_landscape', {
      'asset': ls,
      'strokes': [
        {'points': [[0, 0]], 'tool': 'paint'},
      ],
    });
    expect(text, allOf(contains('sculpt'), contains('smooth'), contains('flatten'), contains('noise')));
    final many = [
      for (var i = 0; i < 65; i++)
        {'points': [[0, 0]]},
    ];
    expect(await refused('sculpt_landscape', {'asset': ls, 'strokes': many}), contains('64'));
    expect(session().undoDepth, 0, reason: 'nothing was stamped');
  });

  test('import_landscape_heightmap takes a 257² 16-bit PNG; a 300² one names 257 and 321 and leaves the terrain', () async {
    final hill = writeHeightmap('hill257.png', 257);
    final imported = await ok('import_landscape_heightmap', {'asset': ls, 'path': hill, 'world_size_cm': 25600, 'max_height_cm': 10000});
    expect(imported['grid_resolution'], 257);
    final info = await ok('get_landscape', {'asset': ls});
    expect(info['grid_resolution'], 257);
    expect(info['height_max_cm'], greaterThan(5000));

    final wrong = writeHeightmap('wrong300.png', 300);
    final text = await refused('import_landscape_heightmap', {'asset': ls, 'path': wrong});
    expect(text, allOf(contains('257'), contains('321')));
    expect((await ok('get_landscape', {'asset': ls}))['grid_resolution'], 257);
    expect(await refused('import_landscape_heightmap', {'asset': ls, 'path': '${root.path}/missing.png'}), contains('missing.png'));
  });

  test('a flatten stroke over the hill narrows the height range under the brush', () async {
    final editor = session();
    const x = 4000.0, y = 0.0, radius = 1500.0;
    (double, double) range() {
      var lo = double.infinity, hi = -double.infinity;
      final cx = x / 100, cz = -y / 100, r = radius / 100 * 0.5;
      for (var dz = -r; dz <= r; dz += 1) {
        for (var dx = -r; dx <= r; dx += 1) {
          final h = editor.data.sampleHeight(cx + dx, cz + dz);
          lo = math.min(lo, h);
          hi = math.max(hi, h);
        }
      }
      return (lo, hi);
    }

    final (lo0, hi0) = range();
    expect(hi0 - lo0, greaterThan(1), reason: 'the brush sits on the hill\'s slope');
    final flattened = await ok('sculpt_landscape', {
      'asset': ls,
      'strokes': [
        for (var i = 0; i < 3; i++)
          {
            'points': [[x, y], [x + 10, y]],
            'tool': 'flatten',
            'radius_cm': radius,
            'strength': 1.0,
            'falloff': 0.2,
          },
      ],
    });
    expect(flattened['strokes'], hasLength(3));
    expect((flattened['strokes'] as List).first, containsPair('tool', 'flatten'));
    final (lo1, hi1) = range();
    expect(hi1 - lo1, lessThan(hi0 - lo0));
    expect(editor.undoDepth, 3);
  });

  test('foliage: a layer of barrels with rules, a paint stroke inside the terrain, an erase stroke, save and reload', () async {
    final editor = session();
    final layer = await ok('add_foliage_layer', {
      'asset': ls,
      'mesh': barrelMesh,
      'rules': {'density': 80, 'slope_max_deg': 30, 'min_spacing_cm': 150},
    });
    expect(layer['layer'], containsPair('name', 'fuel_barrel_red'));
    expect((layer['layer'] as Map)['rules'], allOf(containsPair('density', 80), containsPair('slope_max_deg', 30), containsPair('min_spacing_cm', closeTo(150, 1e-6))));
    expect(await refused('add_foliage_layer', {'asset': ls, 'mesh': barrelMesh}), contains('already'));
    await ok('set_foliage_brush', {'asset': ls, 'radius_cm': 1500, 'paint_density': 1.0, 'erase_density': 0.0});

    // Along the flat band 110 m from the centre (the hill ends at 100 m).
    const stroke = [[-9000, -11000], [0, -11000], [9000, -11000]];
    final painted = await ok('paint_foliage', {
      'asset': ls,
      'layer': 'fuel_barrel_red',
      'strokes': [
        {'points': stroke},
      ],
    });
    expect(painted['instances_placed'], greaterThan(0));
    final half = editor.data.worldSize / 2;
    final placed = editor.data.layers.single;
    for (var i = 0; i < placed.instanceCount; i++) {
      final inst = placed.instanceAt(i);
      expect(inst.x.abs() <= half && inst.z.abs() <= half, isTrue, reason: 'instance $i at (${inst.x}, ${inst.z}) m');
    }
    final info = await ok('get_landscape', {'asset': ls});
    expect((info['foliage_layers'] as List).single, containsPair('instance_count', placed.instanceCount));
    expect(info['undo_label'], startsWith('foliage'));

    final erased = await ok('paint_foliage', {
      'asset': ls,
      'layer': 0,
      'strokes': [
        {'points': stroke, 'erase': true},
      ],
    });
    expect(erased['instances_erased'], greaterThan(0));

    await ok('set_foliage_rules', {'asset': ls, 'layer': 0, 'rules': {'scale_min': 0.9, 'scale_max': 1.1}});
    expect(placed.rules.scaleMin, closeTo(0.9, 1e-9));
    expect(placed.rules.density, 80, reason: 'rules not given keep their values');
    final repainted = await ok('paint_foliage', {
      'asset': ls,
      'layer': 0,
      'strokes': [
        {'points': stroke},
      ],
    });
    expect(repainted['instances_placed'], greaterThan(0));
    final count = placed.instanceCount;

    await ok('save_landscape', {'asset': ls});
    final reloaded = LandscapeAssetService.load('$projectDir/$ls')!;
    expect(reloaded.gridResolution, 257);
    expect(reloaded.heightMax, greaterThan(50));
    expect(reloaded.layers.single.meshAssetPath, endsWith(barrelMesh));
    expect(reloaded.layers.single.instanceCount, count);
    expect(reloaded.layers.single.rules.slopeMaxDegrees, 30);
    expect((await ok('get_landscape', {'asset': ls}))['is_dirty'], isFalse);
  });

  group('the Landscape tab', () {
    /// The call runs on the real event loop while the test pumps frames.
    Future<McpToolReply> call(WidgetTester tester, String tool, Map<String, Object?> args) async {
      McpToolReply? reply;
      Object? error;
      await tester.runAsync(() async {
        client.callTool(tool, args).then<void>((r) {
          reply = r;
        }, onError: (Object e) {
          error = e;
        });
      });
      for (var i = 0; i < 400 && reply == null && error == null; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      }
      if (error != null) throw error!;
      expect(reply, isNotNull, reason: '$tool did not answer');
      return reply!;
    }

    Future<void> mount(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    testWidgets('adopts the view model and the preview scene the tool created; a later stroke shows in its HUD', (tester) async {
      final agentVm = session();
      expect(agentVm.sink, isA<LandscapePreviewScene>());
      await mount(tester);
      final opened = await call(tester, 'open_asset_editor', {'asset': ls});
      expect(opened.isError, isFalse, reason: opened.text);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final state = tester.state(find.byType(LandscapeFoliageSubEditor)) as dynamic;
      expect(identical(state.viewModelForTest, agentVm), isTrue);
      expect(identical(state.previewSceneForTest, agentVm.sink), isTrue);
      // A fresh flat terrain (the height range only widens while sculpting,
      // and the hill already spans 0 … max).
      final reset = await call(tester, 'create_landscape', {'asset': ls, 'grid_resolution': 129});
      expect(reset.isError, isFalse, reason: reset.text);
      await tester.pump(const Duration(milliseconds: 16));
      final hudBefore = agentVm.hudLabel;
      expect(hudBefore, contains('Height 0–0 cm'));

      final sculpted = await call(tester, 'sculpt_landscape', {
        'asset': ls,
        'strokes': [
          {
            'points': [[0, 0], [2000, 0]],
            'tool': 'sculpt',
            'radius_cm': 3000,
            'strength': 1.0,
          },
        ],
      });
      expect(sculpted.isError, isFalse, reason: sculpted.text);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final hud = (state.viewModelForTest as LandscapeEditorViewModel).hudLabel;
      expect(hud, isNot(hudBefore));
      expect(hud, contains('Height ${LandscapeEditorViewModel.formatCm(agentVm.heightMin)}–'
          '${LandscapeEditorViewModel.formatCm(agentVm.heightMax)} cm'));
      expect(find.textContaining('Height ${LandscapeEditorViewModel.formatCm(agentVm.heightMin)}–'), findsWidgets);
      await drainRealIo(tester);
      await tester.pumpWidget(const SizedBox());
      await drainRealIo(tester);
    });

    testWidgets('asset_editor_screenshot returns the Landscape tab as a real PNG', (tester) async {
      await mount(tester);
      final shot = await call(tester, 'asset_editor_screenshot', {'asset': ls, 'max_width': 700});
      expect(shot.isError, isFalse, reason: shot.text);
      expect(shot.text, contains('PNG of the Landscape editor for $ls'));
      final image = shot.content.firstWhere((c) => c['type'] == 'image');
      expect(image['mimeType'], 'image/png');
      final decoded = img.decodePng(base64Decode(image['data'] as String))!;
      expect(decoded.width, lessThanOrEqualTo(700));
      expect(decoded.width, greaterThan(64));
      final first = decoded.getPixel(0, 0);
      var varied = false;
      for (var y = 0; y < decoded.height && !varied; y += 5) {
        for (var x = 0; x < decoded.width; x += 5) {
          final p = decoded.getPixel(x, y);
          if (p.r != first.r || p.g != first.g || p.b != first.b) {
            varied = true;
            break;
          }
        }
      }
      expect(varied, isTrue, reason: 'the editor frame is not one flat colour');
      await drainRealIo(tester);
      await tester.pumpWidget(const SizedBox());
      await drainRealIo(tester);
    });
  });
}
