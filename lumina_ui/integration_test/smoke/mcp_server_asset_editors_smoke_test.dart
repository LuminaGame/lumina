import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/landscape_preview_scene.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/landscape_editor_view_model.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../test/helpers/mcp_test_client.dart';

/// MCP server asset editors smoke (beside `mcp_server_smoke_test.dart`, which is at the
/// 1100-line limit): an MCP client (JSON-RPC over HTTP) on a real temp
/// project creates LS_AgentValley, imports a generated 16-bit radial-hill
/// heightmap, sculpts three strokes and paints a stroke of red fuel barrels
/// — the Landscape tab's lit Filament terrain rises and fills live; gives the
/// imported AC unit two LODs and a convex hull (the collision overlay
/// draws); sets the Tread Plate normal map's texture settings; binds
/// PHYS_Manny to the imported mannequin with bodies on the pelvis, spines
/// and thighs plus a limited constraint (drawn over the mesh); tunes a
/// generated 440 Hz WAV's attenuation and probes it; and authors E_Weather.
/// Each step is a PNG, each editor also as the agent's own
/// asset_editor_screenshot, and the run is a video.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenario = 'MCP Smoke: an agent sculpts a landscape and tunes a mesh, texture, physics asset, sound and enum';
  testWidgets(scenario, (tester) async {
    final assets = SmokeArtifacts.testAssetsDir.path;
    final files = [
      '$assets/Props/Barrels/fuel_barrel_red.glb',
      '$assets/Props/AC_units/ac_unit_a_300x300.glb',
      '$assets/FBX/TextureFixtures/SM_Slot_Machine/SM_Slot_Machine_T_Tread_Plate_Normal.png',
      '$assets/mannequin/SKM_Manny_Simple.glb',
    ];
    for (final f in files) {
      expect(File(f).existsSync(), isTrue, reason: 'test-assets must hold $f');
    }
    final usedAssets = [...files];

    final root = Directory.systemTemp.createTempSync('lumina_smoke_mcp11_');
    final projectDir = '${root.path}/AgentAssets';
    Directory('$projectDir/contents/levels').createSync(recursive: true);
    Directory('$projectDir/lib').createSync(recursive: true);
    const project = LuminaProject(projectName: 'AgentAssets', activeLevel: 'contents/levels/L_Main.lmas');
    File('$projectDir/AgentAssets.lmproject').writeAsStringSync(jsonEncode(project.toMap()));

    // test-assets has no heightmap and no audio: both are generated onto disk.
    final heightmap = img.Image(width: 257, height: 257, numChannels: 1, format: img.Format.uint16);
    for (var y = 0; y < 257; y++) {
      for (var x = 0; x < 257; x++) {
        final r = math.sqrt((x - 128) * (x - 128) + (y - 128) * (y - 128));
        final h = r >= 100 ? 0.0 : 0.5 + 0.5 * math.cos(math.pi * r / 100);
        heightmap.setPixelR(x, y, (h * 65535).round());
      }
    }
    final heightmapPath = '${root.path}/valley_hill_257.png';
    File(heightmapPath).writeAsBytesSync(img.encodePng(heightmap));
    final wavPath = '${root.path}/Beep440.wav';
    File(wavPath).writeAsBytesSync(_wav440());
    // A TGA source (the normal map written as TGA) to reimport.
    final tgaPath = '${root.path}/T_TreadPlate_Tga.tga';
    File(tgaPath).writeAsBytesSync(img.encodeTga(img.decodePng(File(files[2]).readAsBytesSync())!));

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

      Future<void> settle([int frames = 20]) async {
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
        }
      }

      await settle(60);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));

      Future<void> shot(String name) async {
        await rec.hold(const Duration(milliseconds: 400));
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot(name, png, usedAssets: usedAssets);
        await rec.hold(const Duration(milliseconds: 600));
      }

      /// A call the editor answers while the recorder keeps pumping frames.
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

      /// The agent's own screenshot, saved as it received it.
      Future<void> agentShot(String asset, String editor) async {
        final reply = await call('asset_editor_screenshot', {'asset': asset, 'max_width': 1400});
        expect(reply.isError, isFalse, reason: reply.text);
        final image = reply.content.firstWhere((c) => c['type'] == 'image');
        SmokeArtifacts.saveScreenshot('mcp_${editor}_as_the_agent_received_it', base64Decode(image['data'] as String),
            usedAssets: usedAssets);
        debugPrint('[mcp11_smoke] ${reply.text}');
      }

      await tester.runAsync(() => client.handshake(clientName: 'claude-code'));

      // --- The barrel, the AC unit, the normal map, Manny and the WAV ----------
      for (final f in [...files, wavPath, tgaPath]) {
        await ok('import_asset', {'path': f});
      }
      // An image import writes one texture asset, not two.
      expect(vm.realAssets.where((a) => a.type.name == 'texture' && a.relativePath.contains('Tread_Plate')).map((a) => a.relativePath),
          ['contents/textures/SM_Slot_Machine_T_Tread_Plate_Normal.lmas']);
      const barrelMesh = 'contents/meshes/static/fuel_barrel_red.lmas';
      const acUnit = 'contents/meshes/static/ac_unit_a_300x300.lmas';
      const manny = 'contents/meshes/skeletal/SKM_Manny_Simple.lmas';
      String typed(String type, String name) =>
          vm.realAssets.firstWhere((a) => a.type.name == type && a.relativePath.contains(name)).relativePath;
      final texture = typed('texture', 'Tread_Plate');
      final sound = typed('audio', 'Beep440');

      // --- 1. LS_AgentValley: heightmap, three strokes, a stroke of barrels ----
      const ls = 'contents/landscapes/LS_AgentValley.lmas';
      await ok('create_asset', {'type': 'landscape', 'name': 'LS_AgentValley', 'grid_resolution': 257, 'world_size_cm': 25600, 'max_height_cm': 6000});
      await ok('open_asset_editor', {'asset': ls});
      await settle(60);
      await ok('import_landscape_heightmap', {'asset': ls, 'path': heightmapPath});
      await settle(40);
      final landscapeVm = vm.editorSessionFor(vm.currentTab.id) as LandscapeEditorViewModel;
      await shot('mcp11_landscape_heightmap_imported');
      final strokes = [
        {'points': [[-9000, 6000], [-4000, 7000], [0, 8000], [4000, 7000], [9000, 6000]], 'tool': 'sculpt', 'radius_cm': 1800, 'strength': 0.9},
        {'points': [[-8000, -7000], [0, -9000], [8000, -7000]], 'tool': 'sculpt', 'invert': true, 'radius_cm': 1500, 'strength': 0.6},
        {'points': [[3000, 0], [3010, 0]], 'tool': 'flatten', 'radius_cm': 2000, 'strength': 1.0},
      ];
      for (final s in strokes) {
        final r = await ok('sculpt_landscape', {'asset': ls, 'strokes': [s]});
        debugPrint('[mcp11_smoke] stroke ${s['tool']}: ${r['strokes']}');
        await rec.hold(const Duration(milliseconds: 700));
      }
      expect(landscapeVm.undoDepth, 3);
      await shot('mcp11_landscape_three_strokes');
      await ok('add_foliage_layer', {'asset': ls, 'mesh': barrelMesh, 'rules': {'density': 60, 'slope_max_deg': 35, 'min_spacing_cm': 250}});
      await ok('set_foliage_brush', {'asset': ls, 'radius_cm': 1500, 'paint_density': 1.0});
      final painted = await ok('paint_foliage', {
        'asset': ls,
        'layer': 0,
        'strokes': [
          {'points': [[-11000, -11500], [-5000, -11000], [0, -11500], [5000, -11000], [11000, -11500]]},
        ],
      });
      expect(painted['instances_placed'] as int, greaterThan(0));
      await settle(40);
      final preview = landscapeVm.sink as LandscapePreviewScene;
      expect(preview.isAvailable, isTrue, reason: 'the Landscape tab renders the terrain through Filament');
      expect(preview.totalFoliageInstances, greaterThan(0), reason: 'the barrels reached the Filament scene');
      await ok('save_landscape', {'asset': ls});
      await shot('mcp11_landscape_barrels_painted');
      await agentShot(ls, 'landscape');

      // --- 2. The AC unit: two LODs, a convex hull --------------------------------
      await ok('add_static_mesh_lod', {'asset': acUnit});
      await ok('add_static_mesh_lod', {'asset': acUnit});
      await ok('set_static_mesh_lod_group', {'asset': acUnit, 'group': 'LargeProp'});
      final mesh = await ok('set_static_mesh_collision', {'asset': acUnit, 'shape': 'convex', 'mass_kg': 80});
      expect((mesh['collision_shapes'] as List).single, containsPair('type', 'convex'));
      await ok('save_static_mesh', {'asset': acUnit});
      await settle(40);
      // The Mass field follows the agent's mass_kg.
      final massField = find.byKey(const ValueKey('static_mesh_mass_field'));
      expect(massField, findsOneWidget);
      expect(tester.widget<EditableText>(find.descendant(of: massField, matching: find.byType(EditableText))).controller.text, '80.0',
          reason: 'Physics Properties → Mass (Kg) shows the mass the agent set');
      await shot('mcp11_static_mesh_lods_and_convex_collision');
      await agentShot(acUnit, 'static_mesh');
      // The LOD cards' Screen Size fields follow the LargeProp
      // group (LOD2 0.30) and the agent's set_static_mesh_lod (LOD1 0.45).
      await ok('set_static_mesh_lod', {'asset': acUnit, 'level': 1, 'screen_size': 0.45});
      await ok('save_static_mesh', {'asset': acUnit});
      await tester.tap(find.text('LODs (3)'));
      await settle(20);
      String screenSize(int level) => tester
          .widget<EditableText>(find.descendant(
              of: find.byKey(ValueKey('static_mesh_lod_screen_size_$level')), matching: find.byType(EditableText)))
          .controller
          .text;
      expect(screenSize(1), '0.45', reason: 'LOD 1 shows the screen size the agent set');
      expect(screenSize(2), '0.30', reason: 'LOD 2 shows the screen size of the LargeProp group');
      await shot('mcp11_static_mesh_lod_screen_sizes');

      // --- 3. The normal map's settings -----------------------------------------
      await ok('set_texture_view', {'asset': texture, 'mip': 1, 'r': true, 'g': true, 'b': false});
      await ok('set_texture_settings', {
        'asset': texture,
        'group': 'Normalmap',
        'srgb': false,
        'compression': 'ASTC',
        'filter': 'Trilinear',
        'address_x': 'Clamp',
      });
      await ok('save_texture', {'asset': texture});
      // The import recorded the source file, so the tab's Reimport
      // is enabled and the agent's reimport re-reads it.
      final reimportButton = find.ancestor(of: find.text('Reimport'), matching: find.byType(OutlineButton));
      expect(reimportButton, findsOneWidget);
      expect(tester.widget<OutlineButton>(reimportButton).onPressed, isNotNull, reason: 'Reimport is enabled');
      final reimported = await ok('reimport_texture', {'asset': texture});
      expect(reimported['reimported'], isTrue);
      await settle(20);
      await shot('mcp11_texture_normalmap_settings');
      await agentShot(texture, 'texture');
      // The TGA-sourced texture reimports through the import's
      // conversion and stays a PNG.
      final tgaTexture = typed('texture', 'T_TreadPlate_Tga');
      await ok('open_asset_editor', {'asset': tgaTexture});
      await settle(20);
      final tgaReimported = await ok('reimport_texture', {'asset': tgaTexture});
      expect(tgaReimported['reimported'], isTrue);
      final tgaPayload = LuminaAsset.fromBytes(File('$projectDir/$tgaTexture').readAsBytesSync()).rawPayload!;
      expect(EncodedImageFormat.sniff(Uint8List.fromList(tgaPayload)), EncodedImageFormat.png);
      await settle(20);
      await shot('mcp11_texture_tga_reimported');

      // --- 4. PHYS_Manny: bodies on the pelvis, spines and thighs ---------------
      const phys = 'contents/physicsAssets/PHYS_Manny.lmas';
      await ok('create_asset', {'type': 'physicsAsset', 'name': 'PHYS_Manny'});
      final bound = await ok('bind_physics_skeletal_mesh', {'asset': phys, 'mesh': manny});
      final bones = [for (final b in (bound['bones'] as List).cast<Map>()) b['name'] as String];
      final wanted = ['pelvis', 'spine_01', 'spine_02', 'spine_03', 'thigh_l', 'thigh_r'].where(bones.contains).toList();
      expect(wanted, containsAll(['pelvis', 'spine_01', 'thigh_l']));
      for (final bone in wanted) {
        await ok('add_physics_body', {'asset': phys, 'bone': bone, 'shape': 'capsule'});
        await rec.hold(const Duration(milliseconds: 300));
      }
      final c = await ok('add_physics_constraint', {'asset': phys, 'bone_a': 'pelvis', 'bone_b': 'spine_01'});
      final name = ((c['constraints'] as List).single as Map)['name'];
      await ok('set_physics_constraint', {'asset': phys, 'name': name, 'mode': 'limited', 'swing1_deg': 30, 'twist_deg': 20});
      final validation = await ok('validate_physics_asset', {'asset': phys});
      debugPrint('[mcp11_smoke] overlaps: ${validation['overlaps']}');
      await ok('save_physics_asset', {'asset': phys});
      await settle(40);
      await shot('mcp11_physics_bodies_over_manny');
      await agentShot(phys, 'physics_asset');

      // --- 5. The sound's attenuation ---------------------------------------------
      await ok('set_audio_settings', {
        'asset': sound,
        'volume': 0.8,
        'sound_class': 'SFX',
        'attenuation_model': 'linear',
        'inner_radius_cm': 200,
        'falloff_distance_cm': 800,
      });
      final probe = await ok('probe_audio_attenuation', {'asset': sound, 'distance_cm': 600});
      expect(probe['gain'] as num, closeTo(0.5, 0.01));
      await ok('save_audio', {'asset': sound});
      await settle(20);
      await shot('mcp11_audio_attenuation');
      await agentShot(sound, 'audio');

      // --- 6. E_Weather ------------------------------------------------------------
      const weather = 'contents/enums/E_Weather.lmas';
      await ok('create_asset', {'type': 'actor', 'name': 'E_Weather', 'blueprint_kind': 'enum'});
      for (final v in ['Sunny', 'Cloudy', 'Rain', 'Snow']) {
        await ok('add_enum_value', {'asset': weather, 'name': v});
        await rec.hold(const Duration(milliseconds: 250));
      }
      await ok('move_enum_value', {'asset': weather, 'from': 3, 'to': 1});
      await ok('save_enum', {'asset': weather});
      await settle(20);
      await shot('mcp11_enum_weather');
      await agentShot(weather, 'enum');

      // The agent flips between the editors until the video is long enough.
      final tabs = [ls, acUnit, texture, phys, sound, weather];
      for (var i = 0; rec.recorded < const Duration(milliseconds: 10300) && i < 40; i++) {
        await ok('open_asset_editor', {'asset': tabs[i % tabs.length]});
        await rec.hold(const Duration(milliseconds: 700));
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
  }, timeout: const Timeout(Duration(minutes: 20)));
}

/// A real PCM16 RIFF/WAVE file: 1 s of a 440 Hz sine, stereo, 48 kHz.
Uint8List _wav440() {
  const rate = 48000, channels = 2;
  const dataSize = rate * channels * 2;
  final out = BytesBuilder();
  void str(String s) => out.add(ascii.encode(s));
  void u32(int v) => out.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void u16(int v) => out.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());
  str('RIFF');
  u32(36 + dataSize);
  str('WAVE');
  str('fmt ');
  u32(16);
  u16(1);
  u16(channels);
  u32(rate);
  u32(rate * channels * 2);
  u16(channels * 2);
  u16(16);
  str('data');
  u32(dataSize);
  final pcm = ByteData(dataSize);
  for (var f = 0; f < rate; f++) {
    final s = (math.sin(2 * math.pi * 440 * f / rate) * 0.5 * 32767).round();
    pcm.setInt16(f * 4, s, Endian.little);
    pcm.setInt16(f * 4 + 2, s, Endian.little);
  }
  out.add(pcm.buffer.asUint8List());
  return out.toBytes();
}
