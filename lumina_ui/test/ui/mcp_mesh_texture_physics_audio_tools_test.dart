import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_service.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_settings.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/audio_editor_state.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_asset_catalog.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_enum_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/texture_editor_view_model.dart';

import '../helpers/mcp_test_client.dart';
import '../helpers/temp_project.dart';

/// The Static Mesh, Texture, Physics Asset, Sound,
/// Enumeration and Blueprint Interface editors as MCP tools, through a real
/// JSON-RPC-over-HTTP client against a real temp project with real imports
/// from test-assets (the red fuel barrel, the Tread Plate normal map, the
/// Manny mannequin) and a real 1 s 440 Hz WAV written by the test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late String projectDir;
  late EditorViewModel vm;
  late McpServerService server;
  late McpTestClient client;

  final assets = '${Directory.current.parent.path}/test-assets';
  const barrel = 'contents/meshes/static/fuel_barrel_red.lmas';
  const manny = 'contents/meshes/skeletal/SKM_Manny_Simple.lmas';
  late String texture;
  late String sound;

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

  LuminaAsset lmas(String relative) => LuminaAsset.fromBytes(File('$projectDir/$relative').readAsBytesSync());

  T session<T>(String relative) => vm.editorSessionFor(vm.realAssets.firstWhere((a) => a.relativePath == relative).lmasPath!) as T;

  /// A real PCM16 RIFF/WAVE file: [seconds] of a 440 Hz sine, stereo.
  String writeWav(String name, {int sampleRate = 48000, double seconds = 1.0}) {
    final frames = (sampleRate * seconds).round();
    const channels = 2;
    final dataSize = frames * channels * 2;
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
    u32(sampleRate);
    u32(sampleRate * channels * 2);
    u16(channels * 2);
    u16(16);
    str('data');
    u32(dataSize);
    final pcm = ByteData(dataSize);
    for (var f = 0; f < frames; f++) {
      final s = (math.sin(2 * math.pi * 440 * f / sampleRate) * 0.5 * 32767).round();
      pcm.setInt16(f * 4, s, Endian.little);
      pcm.setInt16(f * 4 + 2, s, Endian.little);
    }
    out.add(pcm.buffer.asUint8List());
    final file = File('${root.path}/$name')..writeAsBytesSync(out.toBytes());
    return file.path;
  }

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_mcp_mesh_tex_');
    final configDir = Directory('${root.path}/config')..createSync();
    projectDir = '${root.path}/AgentProps';
    Directory(projectDir).createSync();
    const project = LuminaProject(projectName: 'AgentProps', activeLevel: 'contents/levels/L_Main.lmas');
    File('$projectDir/AgentProps.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    Directory('$projectDir/contents/levels').createSync(recursive: true);
    Directory('$projectDir/lib').createSync(recursive: true);
    vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    server = McpServerService(vm, configDir: configDir, settings: McpServerSettings.load(configDir: configDir));
    expect(await server.start(port: 0), isTrue);
    client = McpTestClient(server.url!, server.token);
    await client.handshake();
    await ok('import_asset', {'path': '$assets/Props/Barrels/fuel_barrel_red.glb'});
    await ok('import_asset', {'path': '$assets/mannequin/SKM_Manny_Simple.glb'});
    final png = await ok('import_asset', {'path': '$assets/FBX/TextureFixtures/SM_Slot_Machine/SM_Slot_Machine_T_Tread_Plate_Normal.png'});
    texture = (png['imported'] as List).cast<Map>().firstWhere((a) => a['type'] == 'texture')['path'] as String;
    final wav = await ok('import_asset', {'path': writeWav('Beep440.wav')});
    sound = (wav['imported'] as List).cast<Map>().firstWhere((a) => a['type'] == 'audio')['path'] as String;
    for (final a in [barrel, manny, texture, sound]) {
      expect(File('$projectDir/$a').existsSync(), isTrue, reason: '$a was imported');
    }
  });

  tearDownAll(() async {
    client.close();
    await server.stop();
    await vm.close();
    await deleteTempProject(root);
  });

  group('Static Mesh', () {
    test('LODs, LOD group, convex collision in cm, and a save that keeps the import\'s references', () async {
      final importedMaterials = {
        for (final r in lmas(barrel).references)
          if (r.slotName.startsWith('material_slot_')) r.assetPath,
      };
      expect(importedMaterials, isNotEmpty, reason: 'the import binds the barrel material');
      var mesh = await ok('get_static_mesh', {'asset': barrel});
      expect(mesh['triangles'], greaterThan(0));
      expect(mesh['lods'], hasLength(1));
      expect(mesh['is_dirty'], isFalse);
      await ok('add_static_mesh_lod', {'asset': barrel});
      mesh = await ok('add_static_mesh_lod', {'asset': barrel});
      expect(mesh['lods'], hasLength(3));
      final lod1 = ((mesh['lods'] as List)[1] as Map)['screen_size'] as num;

      final bad = await refused('set_static_mesh_lod', {'asset': barrel, 'level': 2, 'screen_size': 0.9});
      expect(bad, allOf(contains('LOD1'), contains('$lod1')));
      await ok('set_static_mesh_lod', {'asset': barrel, 'level': 2, 'reduction_ratio': 0.3});

      mesh = await ok('set_static_mesh_lod_group', {'asset': barrel, 'group': 'Architecture'});
      expect(((mesh['lods'] as List)[1] as Map)['screen_size'], closeTo(0.7, 1e-9));
      expect(mesh['lod_group'], 'Architecture');
      expect((await ok('set_static_mesh_preview_lod', {'asset': barrel, 'level': 2}))['forced_lod'], 2);
      expect((await ok('set_static_mesh_preview_lod', {'asset': barrel}))['forced_lod'], isNull);

      mesh = await ok('set_static_mesh_collision', {'asset': barrel, 'shape': 'convex', 'mass_kg': 42, 'complexity': 'default'});
      final shapes = mesh['collision_shapes'] as List;
      expect(shapes, hasLength(1));
      final hull = shapes.single as Map;
      expect(hull['type'], 'convex');
      final lo = (mesh['bounds'] as Map)['min_cm'] as List, hi = (mesh['bounds'] as Map)['max_cm'] as List;
      for (final p in (hull['points'] as List).cast<List>()) {
        for (var a = 0; a < 3; a++) {
          expect(p[a] as num, inInclusiveRange((lo[a] as num) - 0.01, (hi[a] as num) + 0.01), reason: 'hull point $p inside $lo…$hi cm');
        }
      }
      expect(mesh['mass_kg'], 42);
      mesh = await ok('set_static_mesh_collision', {'asset': barrel, 'shape': 'none'});
      expect(mesh['collision_shapes'], isEmpty);
      await ok('set_static_mesh_collision', {'asset': barrel, 'shape': 'convex'});
      expect((await ok('get_static_mesh', {'asset': barrel}))['is_dirty'], isTrue);

      await ok('save_static_mesh', {'asset': barrel});
      final saved = lmas(barrel);
      expect(jsonDecode(saved.metadata['lods']!) as List, hasLength(3));
      expect(((jsonDecode(saved.metadata['collision']!) as Map)['shapes'] as List).single, containsPair('type', 'convex'));
      expect(saved.metadata['collision'], contains('"world_units":"cm"'));
      expect({for (final r in saved.references) r.assetPath}, containsAll(importedMaterials),
          reason: 'the import\'s material bindings survive the save');
      expect(saved.hasThumbnail || saved.thumbnailPng != null, isTrue);
    });

    test('material slot: bind a created material, save, clear', () async {
      final created = await ok('create_asset', {'type': 'filamat', 'name': 'M_Agent'});
      final material = created['path'] as String;
      var mesh = await ok('set_static_mesh_material_slot', {'asset': barrel, 'slot': 0, 'material': 'M_Agent'});
      expect(((mesh['material_slots'] as List).first as Map)['material'], material);
      await ok('save_static_mesh', {'asset': barrel});
      expect(lmas(barrel).references.where((r) => r.slotName == 'element_0').single.assetPath, endsWith(material));
      mesh = await ok('set_static_mesh_material_slot', {'asset': barrel, 'slot': 0, 'material': null});
      expect(((mesh['material_slots'] as List).first as Map)['material'], isNull);
      expect(await refused('set_static_mesh_material_slot', {'asset': barrel, 'slot': 99, 'material': 'M_Agent'}), contains('slot'));
    });
  });

  group('Texture', () {
    test('view, settings saved in texture_settings, an unoffered format is a -32602, reimport needs a source', () async {
      var tex = await ok('get_texture', {'asset': texture});
      expect(tex['width'], greaterThan(0));
      expect((tex['mips'] as List).length, greaterThan(2));
      expect(tex['settings'], containsPair('compression', 'KTX2 / Basis Universal'));

      final view = await ok('set_texture_view', {'asset': texture, 'mip': 2, 'r': true, 'g': false, 'b': false});
      expect(view['view'], allOf(containsPair('mip', 2), containsPair('g', false)));
      expect((await ok('get_texture', {'asset': texture}))['is_dirty'], isFalse, reason: 'the view is not the asset');

      String? rejected;
      try {
        await client.callTool('set_texture_settings', {'asset': texture, 'compression': 'BC7'});
      } on McpRpcError catch (e) {
        expect(e.code, -32602);
        rejected = e.message;
      }
      expect(rejected, allOf(contains('KTX2 / Basis Universal'), contains('ASTC'), contains('ETC2'), contains('Uncompressed RGBA8')));

      tex = await ok('set_texture_settings', {
        'asset': texture,
        'srgb': false,
        'group': 'Normalmap',
        'compression': 'ASTC',
        'mip_gen': 'NoMipmaps',
        'filter': 'Trilinear',
        'address_x': 'Clamp',
      });
      expect(tex['is_dirty'], isTrue);
      expect(tex['mips'], hasLength(1));
      await ok('save_texture', {'asset': texture});
      final settings = jsonDecode(lmas(texture).metadata['texture_settings']!) as Map;
      expect(settings, {
        'srgb': false,
        'group': 'Normalmap',
        'format': 'ASTC',
        'quality': 'Default',
        'mip_gen': 'NoMipmaps',
        'filter': 'Trilinear',
        'address_x': 'Clamp',
        'address_y': 'Wrap',
      });

      // The import records the file it came from, so the tab's
      // Reimport (and reimport_texture) re-reads it and redraws the thumbnail.
      final source = File('$assets/FBX/TextureFixtures/SM_Slot_Machine/SM_Slot_Machine_T_Tread_Plate_Normal.png').absolute.uri.toFilePath();
      expect(session<TextureEditorViewModel>(texture).sourceFilePath, source);
      final before = lmas(texture).thumbnailPng;
      final reimported = await ok('reimport_texture', {'asset': texture});
      expect(reimported['reimported'], isTrue);
      final after = lmas(texture);
      expect(after.metadata['source_file'], source);
      expect(after.rawPayload, File(source).readAsBytesSync());
      expect(after.thumbnailPng, isNot(before), reason: 'the reimport redraws the thumbnail');
      expect(jsonDecode(after.metadata['texture_settings']!) as Map, containsPair('group', 'Normalmap'), reason: 'the settings survive');
    });
  });

  group('Physics Asset', () {
    const phys = 'contents/physicsAssets/PHYS_Manny.lmas';

    test('bind Manny, bodies in cm, a clamped constraint, a disabled pair, validation, a typo, save v2', () async {
      expect((await ok('create_asset', {'type': 'physicsAsset', 'name': 'PHYS_Manny'}))['path'], phys);
      var doc = await ok('get_physics_asset', {'asset': phys});
      expect(doc['skeletal_mesh'], isNull);
      doc = await ok('bind_physics_skeletal_mesh', {'asset': phys, 'mesh': manny});
      expect(doc['link_error'], isNull);
      final bones = (doc['bones'] as List).cast<Map>();
      expect(bones.map((b) => b['name']), containsAll(['pelvis', 'spine_01']));
      expect(bones.firstWhere((b) => b['name'] == 'spine_01')['parent'], 'pelvis');

      await ok('add_physics_body', {'asset': phys, 'bone': 'pelvis', 'shape': 'capsule'});
      doc = await ok('add_physics_body', {'asset': phys, 'bone': 'spine_01', 'shape': 'capsule'});
      final bodies = (doc['bodies'] as List).cast<Map>();
      expect(bodies, hasLength(2));
      for (final b in bodies) {
        expect(b['radius_cm'] as num, greaterThan(1), reason: '${b['bone']} is sized in cm');
      }
      expect(await refused('add_physics_body', {'asset': phys, 'bone': 'pelvis', 'shape': 'box'}), contains('replace'));
      doc = await ok('add_physics_body', {'asset': phys, 'bone': 'pelvis', 'shape': 'box', 'replace': true});
      expect((doc['bodies'] as List).cast<Map>().firstWhere((b) => b['bone'] == 'pelvis')['shape'], 'box');
      await ok('add_physics_body', {'asset': phys, 'bone': 'pelvis', 'shape': 'capsule', 'replace': true});
      doc = await ok('set_physics_body', {'asset': phys, 'bone': 'spine_01', 'mass_kg': 12, 'linear_damping': 0.2});
      expect((doc['bodies'] as List).cast<Map>().firstWhere((b) => b['bone'] == 'spine_01')['mass_kg'], 12);

      doc = await ok('add_physics_constraint', {'asset': phys, 'bone_a': 'pelvis', 'bone_b': 'spine_01'});
      final name = ((doc['constraints'] as List).single as Map)['name'] as String;
      doc = await ok('set_physics_constraint', {'asset': phys, 'name': name, 'mode': 'limited', 'swing1_deg': 30, 'twist_deg': 200});
      final c = (doc['constraints'] as List).single as Map;
      expect(c['mode'], 'limited');
      expect(c['swing1_deg'], 30);
      expect(c['twist_deg'], 180, reason: 'clamped as the Details field clamps');

      doc = await ok('set_physics_collision_pair', {'asset': phys, 'bone_a': 'pelvis', 'bone_b': 'spine_01', 'enabled': false});
      expect(doc['disabled_collision_pairs'], [
        ['pelvis', 'spine_01'],
      ]);
      final validation = await ok('validate_physics_asset', {'asset': phys});
      expect(validation['overlaps'], isA<List>());
      expect((validation['overlaps'] as List).cast<Map>().single, containsPair('disabled', true));
      expect(validation['errors'], isEmpty);

      final typo = await refused('add_physics_body', {'asset': phys, 'bone': 'pelvsi', 'shape': 'capsule'});
      expect(typo, contains('pelvis'));
      expect(await refused('set_physics_body', {'asset': phys, 'bone': 'spine_02', 'mass_kg': 1}), contains('no body'));

      await ok('save_physics_asset', {'asset': phys});
      final saved = jsonDecode(lmas(phys).metadata['physics_asset']!) as Map;
      expect(saved['v'], 2);
      expect(saved['world_units'], 'cm');
      expect((saved['bodies'] as List).cast<Map>().map((b) => b['bone']), ['pelvis', 'spine_01']);
      expect(((saved['bodies'] as List).first as Map)['radius'] as num, greaterThan(1));
      expect(lmas(phys).references.where((r) => r.slotName == 'skeletal_mesh').single.assetPath, endsWith(manny));
    });
  });

  group('Audio', () {
    test('the decoded WAV, settings, the gain-at-distance probe, save and reload', () async {
      final info = await ok('get_audio', {'asset': sound});
      expect(info['sample_rate'], 48000);
      expect(info['channels'], 2);
      expect(info['bit_depth'], 16);
      expect(info['duration_s'] as num, closeTo(1.0, 0.01));
      expect(info['frame_count'], 48000);

      await ok('set_audio_settings', {
        'asset': sound,
        'volume': 0.5,
        'sound_class': 'Music',
        'attenuation_model': 'linear',
        'inner_radius_cm': 200,
        'falloff_distance_cm': 800,
        'looping': true,
      });
      final probe = await ok('probe_audio_attenuation', {'asset': sound, 'distance_cm': 600});
      expect(probe['gain'] as num, closeTo(0.5, 0.01));
      expect((await ok('probe_audio_attenuation', {'asset': sound}))['distance_cm'], 1200);
      expect((await ok('get_audio', {'asset': sound}))['is_dirty'], isTrue);

      await ok('save_audio', {'asset': sound});
      final saved = AudioSettings.fromJson(jsonDecode(lmas(sound).metadata['audio_settings']!) as Map<String, dynamic>);
      expect(saved.volumeMultiplier, 0.5);
      expect(saved.soundClass, AudioSoundClass.music);
      expect(saved.looping, isTrue);
      expect(saved.attenuation.innerRadius, 200);
      expect(saved.attenuation.falloffDistance, 800);
      expect(saved.attenuation.model, LuminaAttenuationModel.linear);
    });
  });

  group('Enumeration and Blueprint Interface', () {
    const enumPath = 'contents/enums/E_Weather.lmas';
    const ifacePath = 'contents/interfaces/BPI_Interact.lmas';

    test('an enum: one transaction per edit, scoped undo reverts the rename, save writes the values', () async {
      final created = await ok('create_asset', {'type': 'actor', 'name': 'E_Weather', 'blueprint_kind': 'enum'});
      expect(created['path'], enumPath);
      expect(BlueprintAssetCatalog.readEnum('$projectDir/$enumPath'), isNotNull);
      await ok('add_enum_value', {'asset': enumPath, 'name': 'Sunny'});
      final editor = session<BlueprintEnumViewModel>(enumPath);
      final depth = editor.transactions.history().length;
      await ok('add_enum_value', {'asset': enumPath});
      expect(editor.transactions.history().length, depth + 1);
      final renamed = await ok('rename_enum_value', {'asset': enumPath, 'index': 1, 'name': 'Rain'});
      expect(renamed['values'], ['Sunny', 'Rain']);
      expect(editor.transactions.history().length, depth + 2);
      await ok('undo', {'asset': enumPath, 'scope': 'agent'});
      expect((await ok('get_enum', {'asset': enumPath}))['values'], ['Sunny', 'NewEnumerator1']);
      await ok('redo', {'asset': enumPath});
      final moved = await ok('move_enum_value', {'asset': enumPath, 'from': 1, 'to': 0});
      expect(moved['values'], ['Rain', 'Sunny']);
      expect(editor.transactions.history().length, depth + 3);
      expect(await refused('rename_enum_value', {'asset': enumPath, 'index': 0, 'name': 'Sunny'}), contains('Sunny'));
      await ok('save_enum', {'asset': enumPath});
      expect(BlueprintAssetCatalog.readEnum('$projectDir/$enumPath')!.values, ['Rain', 'Sunny']);
      await ok('remove_enum_value', {'asset': enumPath, 'index': 1});
      expect((await ok('get_enum', {'asset': enumPath}))['is_dirty'], isTrue);
    });

    test('an interface: a function, typed params, save; an unknown type lists the accepted ones', () async {
      final created = await ok('create_asset', {'type': 'actor', 'name': 'BPI_Interact', 'blueprint_kind': 'interface'});
      expect(created['path'], ifacePath);
      expect((await ok('add_interface_function', {'asset': ifacePath, 'name': 'Interact'}))['function'], 'Interact');
      await ok('set_interface_function_params', {
        'asset': ifacePath,
        'function': 'Interact',
        'inputs': [
          {'name': 'Instigator', 'type': 'Actor'},
        ],
        'outputs': [
          {'name': 'Handled', 'type': 'Bool'},
        ],
      });
      final bad = await refused('set_interface_function_params', {
        'asset': ifacePath,
        'function': 'Interact',
        'inputs': [
          {'name': 'X', 'type': 'Banana'},
        ],
      });
      expect(bad, allOf(contains('Banana'), contains('Actor'), contains('Float')));
      await ok('add_interface_function', {'asset': ifacePath, 'name': 'Temp'});
      await ok('rename_interface_function', {'asset': ifacePath, 'function': 'Temp', 'name': 'Temp2'});
      await ok('remove_interface_function', {'asset': ifacePath, 'function': 'Temp2'});
      final iface = await ok('get_interface', {'asset': ifacePath});
      expect((iface['functions'] as List).single, containsPair('name', 'Interact'));
      await ok('save_interface', {'asset': ifacePath});
      final doc = BlueprintAssetCatalog.readInterface('$projectDir/$ifacePath')!;
      final fn = doc.functions.single;
      expect(fn.name, 'Interact');
      expect(fn.inputs.single.name, 'Instigator');
      expect(fn.inputs.single.typeName, 'Actor');
      expect(fn.outputs.single.typeName, 'Bool');
      final undone = await ok('undo', {'asset': ifacePath});
      expect(undone['undone'], contains('MCP'));
    });
  });

  test('tools/list: every mesh, texture, physics and audio tool with a schema, risk and groups; no environment or navigation tool here', () async {
    const byGroup = {
      'landscape': [
        'get_landscape', 'create_landscape', 'import_landscape_heightmap', 'set_landscape_brush', 'set_foliage_brush',
        'sculpt_landscape', 'add_foliage_layer', 'set_foliage_rules', 'remove_foliage_layer', 'paint_foliage', 'save_landscape',
      ],
      'static_mesh': [
        'get_static_mesh', 'add_static_mesh_lod', 'remove_static_mesh_lod', 'set_static_mesh_lod', 'set_static_mesh_lod_group',
        'set_static_mesh_preview_lod', 'set_static_mesh_collision', 'set_static_mesh_material_slot', 'save_static_mesh',
      ],
      'texture': ['get_texture', 'set_texture_settings', 'set_texture_view', 'reimport_texture', 'save_texture'],
      'physics_asset': [
        'get_physics_asset', 'bind_physics_skeletal_mesh', 'add_physics_body', 'set_physics_body', 'remove_physics_body',
        'add_physics_constraint', 'set_physics_constraint', 'remove_physics_constraint', 'set_physics_collision_pair',
        'validate_physics_asset', 'save_physics_asset',
      ],
      'audio': ['get_audio', 'set_audio_settings', 'probe_audio_attenuation', 'save_audio'],
      'blueprint_types': [
        'get_enum', 'add_enum_value', 'rename_enum_value', 'remove_enum_value', 'move_enum_value', 'save_enum', 'get_interface',
        'add_interface_function', 'rename_interface_function', 'remove_interface_function', 'set_interface_function_params',
        'save_interface',
      ],
    };
    final tools = {for (final t in await client.listTools()) t['name'] as String: t};
    final ours = [for (final names in byGroup.values) ...names];
    expect(ours, hasLength(52));
    for (final entry in byGroup.entries) {
      for (final name in entry.value) {
        final tool = tools[name];
        expect(tool, isNotNull, reason: '$name is listed');
        expect((tool!['description'] as String).length, greaterThan(20), reason: name);
        expect((tool['inputSchema'] as Map)['type'], 'object', reason: name);
        final meta = tool['_meta'] as Map;
        expect(meta['lumina/risk'], isNotNull, reason: name);
        expect(meta['lumina/groups'], containsAll([entry.key, 'asset_editors']), reason: name);
      }
    }
    String risk(String name) => (tools[name]!['_meta'] as Map)['lumina/risk'] as String;
    for (final name in ours) {
      if (name.startsWith('get_') || name == 'probe_audio_attenuation' || name == 'validate_physics_asset') {
        expect(risk(name), 'readOnly', reason: name);
      } else if (name.startsWith('remove_') || name == 'create_landscape' || name == 'save_enum') {
        expect(risk(name), 'destructive', reason: name);
      } else if (name == 'set_texture_view' || name == 'set_static_mesh_preview_lod') {
        expect(risk(name), 'editorState', reason: name);
      } else {
        expect(risk(name), 'mutating', reason: name);
      }
    }
    expect(tools.keys.where((n) => RegExp('environment|lighting|navigation|navmesh').hasMatch(n) && ours.contains(n)), isEmpty);
    final screenshotGroups = (tools['asset_editor_screenshot']!['_meta'] as Map)['lumina/groups'] as List;
    expect(screenshotGroups, containsAll([...byGroup.keys, 'asset_editors']));
    expect(await client.listTools(groups: ['asset_editors']), hasLength(52 + 1 + 10), reason: '52 + asset_editor_screenshot + 10 core');
    expect(await client.listTools(groups: ['landscape']), hasLength(11 + 1 + 10));
  });
}
