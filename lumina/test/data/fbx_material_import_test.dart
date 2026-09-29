// An FBX import maps every material's FBX values (diffuse,
// emissive, the Phong specular/shininess → PBR approximation) into the payload
// GLB and the `.lmas` material, keeps each mesh section on its own material,
// imports the textures it finds near the FBX (normal maps linear, colour maps
// sRGB) and names the ones it cannot find in the Output Log.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

Directory get _assets {
  final root = Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets';
  return Directory(root);
}

File _fbx(String name) => File('${_assets.path}/FBX/StaticMeshes/$name.FBX');

/// Downscaled copies of the slot machine's textures (test-assets/FBX/README.md).
Directory get _slotTextures => Directory('${_assets.path}/FBX/TextureFixtures/SM_Slot_Machine');

/// The FBX's own Phong exponent (20, the FBX SDK default the exporter leaves) as
/// perceptual roughness: (2 / (n + 2))^¼.
final double _roughness20 = math.pow(2 / 22, 0.25).toDouble();

/// What the raw FBX dump (Blender io_scene_fbx.parse_fbx; flutter_assimp
/// material_details) shows for SM_Slot_Machine, in section order.
const _slotMaterials = <(String, List<double>)>[
  ('M_Plastic_Black_Matte_1', [1.0, 0.989583, 0.989583]),
  ('M_Display_1', [0.02, 0.02, 0.02]),
  ('M_Metal_0_3_Rough', [0.0, 0.0, 0.0]),
  ('M_Light_Top', [0.8, 0.8, 0.8]),
  ('M_Rubber_Foot_Rest', [0.03, 0.03, 0.03]),
  ('M_Neon_Green', [0.8, 0.8, 0.8]),
  ('M_Display_OFF', [0.02, 0.02, 0.02]),
  ('M_Plastic_Black', [0.390625, 0.386556, 0.386556]),
];

List<double> _nums(String csv) => [for (final v in csv.split(',')) double.parse(v)];

LuminaAsset _read(Directory project, String relative) =>
    LuminaAsset.fromBytes(File('${project.path}/$relative').readAsBytesSync());

Directory _project() {
  final dir = Directory.systemTemp.createTempSync('lumina_fbx_materials_');
  Directory('${dir.path}/contents').createSync();
  return dir;
}

Future<RealAssetInfo> _import(Directory project, String fbxPath, {List<String> textureSearchDirs = const []}) =>
    AssetRepository().importExternalFile(
      projectPath: project.path,
      sourceFilePath: fbxPath,
      textureSearchDirs: textureSearchDirs,
    );

/// Asserts [project]'s imported [meshName] binds section i to material i of
/// [expected] (names) in both the `.lmas` references and the payload GLB.
void _expectSectionBinding(Directory project, String meshName, List<String> expected) {
  final mesh = _read(project, 'contents/meshes/static/$meshName.lmas');
  final slots = [for (final r in mesh.references) if (r.slotName.startsWith('material_slot_')) r];
  expect([for (final r in slots) r.slotName], [for (var i = 0; i < expected.length; i++) 'material_slot_$i']);
  expect([for (final r in slots) r.assetPath], [for (final n in expected) 'contents/materials/$meshName/$n.lmas']);
  for (final r in slots) {
    expect(_read(project, r.assetPath).assetId, r.assetId, reason: '${r.slotName} points at the material asset');
  }
  final json = GlbDocument.parse(mesh.rawPayload!).json;
  final names = [for (final m in json['materials'] as List) (m as Map)['name'] as String];
  for (final m in json['meshes'] as List) {
    for (final p in (m as Map)['primitives'] as List) {
      final index = (p as Map)['material'] as int;
      final name = names[index];
      expect(expected[index], name.startsWith('MI_') ? 'M_${name.substring(3)}' : name.startsWith('M_') ? name : 'M_$name');
    }
  }
}

void main() {
  final haveAssets = _fbx('SM_Slot_Machine').existsSync();

  group('FbxMaterialMapper (Phong → metallic/roughness)', () {
    test('shininess maps to perceptual roughness by the Blinn-Phong ↔ GGX match', () {
      expect(FbxMaterialMapper.roughnessFromPhong(shininess: 20, specular: 0.2), closeTo(0.5491, 1e-4));
      expect(FbxMaterialMapper.roughnessFromPhong(shininess: 1000, specular: 1), closeTo(math.pow(2 / 1002, 0.25), 1e-6));
      expect(FbxMaterialMapper.roughnessFromPhong(shininess: 0, specular: 0.5), 1.0);
      expect(FbxMaterialMapper.roughnessFromPhong(shininess: 50, specular: 0), 1.0, reason: 'no highlight at all');
    });
  });

  group('SM_Slot_Machine.FBX', () {
    late Directory project;
    setUp(() => project = _project());
    tearDown(() {
      if (project.existsSync()) project.deleteSync(recursive: true);
    });

    test('without textures: every material keeps its FBX colour, emissive and a Phong-derived roughness; '
        'section i stays on material i; the missing normal map is named in the Output Log', () async {
      if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
      final logStart = EngineLoggerService().logs.length;
      await _import(project, _fbx('SM_Slot_Machine').path);

      _expectSectionBinding(project, 'SM_Slot_Machine', [for (final m in _slotMaterials) m.$1]);
      final mesh = _read(project, 'contents/meshes/static/SM_Slot_Machine.lmas');
      final glbMaterials = (GlbDocument.parse(mesh.rawPayload!).json['materials'] as List).cast<Map>();
      for (var i = 0; i < _slotMaterials.length; i++) {
        final (name, diffuse) = _slotMaterials[i];
        final mat = _read(project, 'contents/materials/SM_Slot_Machine/$name.lmas');
        final base = _nums(mat.metadata['baseColor']!);
        for (var c = 0; c < 3; c++) {
          expect(base[c], closeTo(diffuse[c], 1e-4), reason: '$name base colour');
        }
        expect(double.parse(mat.metadata['roughness']!), closeTo(_roughness20, 1e-4), reason: '$name roughness');
        expect(double.parse(mat.metadata['metallic']!), 0.0, reason: '$name metallic');
        expect(_nums(mat.metadata['emissive']!), [0.0, 0.0, 0.0], reason: '$name emissive');
        expect(mat.rawMatSource, contains('material.roughness = ${_roughness20.toStringAsFixed(3)};'), reason: name);
        expect(mat.rawMatSource, contains('material.metallic = 0.0;'), reason: name);
        expect(mat.references, isEmpty, reason: '$name has no texture');

        // What the viewport draws (gltfio reads the payload GLB).
        final pbr = glbMaterials[i]['pbrMetallicRoughness'] as Map;
        expect((pbr['roughnessFactor'] as num).toDouble(), closeTo(_roughness20, 1e-4), reason: '$name GLB roughness');
        expect((pbr['metallicFactor'] as num).toDouble(), 0.0, reason: '$name GLB metallic');
        expect(glbMaterials[i]['emissiveFactor'] ?? const [0, 0, 0], [0, 0, 0], reason: '$name GLB emissive');
      }

      final warnings = EngineLoggerService().logs.skip(logStart).where((e) => e.level == 'warning').map((e) => e.message);
      expect(
        warnings.where((m) => m.contains('T_Tread_Plate_Normal.png') && m.contains('M_Rubber_Foot_Rest')),
        hasLength(1),
        reason: 'the missing texture is reported by name and material: $warnings',
      );
      expect(Directory('${project.path}/contents/textures/SM_Slot_Machine').existsSync(), isFalse);
      final imported = jsonDecode(mesh.metadata['fbx_missing_texture_details']!) as List;
      expect(imported.single, containsPair('material', 'M_Rubber_Foot_Rest'));
      expect(imported.single, containsPair('slot', 'normalMap'));
    });

    Future<void> expectTexturesBound(Directory project) async {
      final mesh = _read(project, 'contents/meshes/static/SM_Slot_Machine.lmas');
      final expected = <String, (String, String, bool)>{
        // material: (slot, texture asset, sRGB)
        'M_Neon_Green': ('emissiveMap', 'T_Neon_Green_Emissive', true),
        'M_Display_1': ('emissiveMap', 'T_Display_1_Emissive', true),
        'M_Plastic_Black_Matte_1': ('normalMap', 'T_Plastic_Black_Matte_1_Normal', false),
        'M_Rubber_Foot_Rest': ('normalMap', 'T_Tread_Plate_Normal', false),
      };
      for (final (name, diffuse) in _slotMaterials) {
        final mat = _read(project, 'contents/materials/SM_Slot_Machine/$name.lmas');
        final want = expected[name];
        if (want == null) {
          expect(mat.references, isEmpty, reason: '$name matched no texture');
          continue;
        }
        final (slot, texture, srgb) = want;
        final ref = mat.references.single;
        expect(ref.slotName, slot, reason: name);
        expect(ref.assetPath, 'contents/textures/SM_Slot_Machine/$texture.lmas', reason: name);
        final tex = _read(project, ref.assetPath);
        expect(tex.type, AssetType.texture);
        expect(tex.assetId, ref.assetId);
        expect(tex.rawPayload!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47], reason: '$texture holds the PNG');
        final settings = jsonDecode(tex.metadata['texture_settings']!) as Map;
        expect(settings['srgb'], srgb, reason: '$texture colour space');
        expect(settings['group'], srgb ? 'World' : 'Normalmap', reason: texture);
        expect(mat.rawMatSource, contains('materialParams_$slot'), reason: name);
        if (slot == 'emissiveMap') {
          expect(_nums(mat.metadata['emissive']!), [1.0, 1.0, 1.0], reason: '$name: the texture is the emission');
          expect(mat.rawMatSource, contains('texture(materialParams_emissiveMap, getUV0()).rgb * vec3(1.0, 1.0, 1.0), 0.0)'));
        }
        final base = _nums(mat.metadata['baseColor']!);
        expect(base[0], closeTo(diffuse[0], 1e-4), reason: '$name keeps its FBX base colour');
      }

      // The payload GLB samples the same images, in the matching slots.
      final json = GlbDocument.parse(mesh.rawPayload!).json;
      final images = (json['images'] as List).cast<Map>();
      final textures = (json['textures'] as List).cast<Map>();
      String imageOf(Map slot) => images[textures[slot['index'] as int]['source'] as int]['name'] as String;
      final byName = {for (final m in (json['materials'] as List).cast<Map>()) m['name'] as String: m};
      expect(imageOf(byName['MI_Neon_Green']!['emissiveTexture'] as Map), 'T_Neon_Green_Emissive');
      expect(byName['MI_Neon_Green']!['emissiveFactor'], [1, 1, 1]);
      expect(imageOf(byName['MI_Display_1']!['emissiveTexture'] as Map), 'T_Display_1_Emissive');
      expect(imageOf(byName['MI_Plastic_Black_Matte_1']!['normalTexture'] as Map), 'T_Plastic_Black_Matte_1_Normal');
      expect(imageOf(byName['M_Rubber_Foot_Rest']!['normalTexture'] as Map), 'T_Tread_Plate_Normal');
      expect(images.every((i) => i['uri'] == null && i['mimeType'] == 'image/png'), isTrue, reason: 'all embedded');
      expect(mesh.metadata['fbx_missing_textures'], isNull, reason: 'nothing is missing');
      final bound = (jsonDecode(mesh.metadata['fbx_material_textures']!) as List).cast<Map>();
      expect(bound, hasLength(4));
      expect(bound.firstWhere((b) => b['material'] == 'M_Rubber_Foot_Rest')['source'], 'referenced');
      expect(bound.firstWhere((b) => b['material'] == 'M_Neon_Green')['source'], 'matched by name');
    }

    test('textures dropped next to the FBX: the referenced normal map and the name-matched emissive/normal maps '
        'are imported and bound to the right slots with the right colour space', () async {
      if (!haveAssets || !_slotTextures.existsSync()) return markTestSkipped('test-assets/FBX texture fixtures missing');
      final source = Directory.systemTemp.createTempSync('fbx_slot_src_');
      addTearDown(() => source.deleteSync(recursive: true));
      final fbx = _fbx('SM_Slot_Machine').copySync('${source.path}/SM_Slot_Machine.FBX');
      for (final f in _slotTextures.listSync().whereType<File>()) {
        f.copySync('${source.path}/${f.uri.pathSegments.last}');
      }
      await _import(project, fbx.path);
      await expectTexturesBound(project);
    });

    test('textures in a chosen folder (the import option) are found the same way', () async {
      if (!haveAssets || !_slotTextures.existsSync()) return markTestSkipped('test-assets/FBX texture fixtures missing');
      await _import(project, _fbx('SM_Slot_Machine').path, textureSearchDirs: [_slotTextures.path]);
      await expectTexturesBound(project);
    });
  });

  group('the other StaticMeshes FBX keep their FBX values (regression)', () {
    late Directory project;
    setUp(() => project = _project());
    tearDown(() {
      if (project.existsSync()) project.deleteSync(recursive: true);
    });

    // name → (materials in section order with their FBX diffuse, missing textures)
    final cases = <String, (List<(String, List<double>)>, List<String>)>{
      'SM_Casino_Chair': (
        [
          ('M_Leather_Black', [0.8, 0.8, 0.8]),
          ('M_Metal_Brushed_Glossy', [0.0, 0.0, 0.0]),
          ('M_Plastic_Black_Matte', [1.0, 0.989583, 0.989583]),
        ],
        ['T_Leather_Normal.png'],
      ),
      'SM_Counter_1': (
        [
          ('M_Wood_2', [0.8, 0.8, 0.8]),
          ('M_Porcelain_2', [0.8, 0.8, 0.8]),
        ],
        ['Wood051_4K_Color.png', 'Porcelain003_4K_Color.png', 'Porcelain003_4K_Normal.png'],
      ),
      'SM_Laptop': ([('M_Laptop', [0.8, 0.8, 0.8])], ['T_Laptop_BC.png']),
      'SM_Table': ([('M_BoothChairTableTrim', [0.8, 0.8, 0.8])], ['SB_BoothChairsTables_Trim_normal.tga']),
    };
    for (final entry in cases.entries) {
      test('${entry.key}: FBX base colours, Phong roughness, sections bound, missing textures warned', () async {
        final fbx = _fbx(entry.key);
        if (!fbx.existsSync()) return markTestSkipped('test-assets/FBX missing');
        final logStart = EngineLoggerService().logs.length;
        await _import(project, fbx.path);
        final (materials, missing) = entry.value;
        _expectSectionBinding(project, entry.key, [for (final m in materials) m.$1]);
        for (final (name, diffuse) in materials) {
          final mat = _read(project, 'contents/materials/${entry.key}/$name.lmas');
          final base = _nums(mat.metadata['baseColor']!);
          for (var c = 0; c < 3; c++) {
            expect(base[c], closeTo(diffuse[c], 1e-4), reason: '$name base colour');
          }
          expect(double.parse(mat.metadata['roughness']!), closeTo(_roughness20, 1e-4), reason: name);
          expect(double.parse(mat.metadata['metallic']!), 0.0, reason: name);
          expect(_nums(mat.metadata['emissive']!), [0.0, 0.0, 0.0], reason: name);
        }
        final warnings = EngineLoggerService().logs.skip(logStart).where((e) => e.level == 'warning').map((e) => e.message).toList();
        for (final file in missing) {
          expect(warnings.where((m) => m.contains(file)), hasLength(1), reason: '$file is named in the Output Log: $warnings');
        }
      });
    }
  });
}
