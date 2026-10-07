import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/skeletal_mesh_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/skeletal_mesh/material_slots_panel.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/skeletal_mesh/skeletal_mesh_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// UI coverage for the Skeletal Mesh editor's material slots and textures.
void main() {
  late Directory projectDir;

  setUp(() {
    projectDir = Directory.systemTemp.createTempSync('skel_mat_ui_');
    Directory('${projectDir.path}/contents/materials').createSync(recursive: true);
    Directory('${projectDir.path}/contents/textures').createSync(recursive: true);
    Directory('${projectDir.path}/contents/meshes/skeletal').createSync(recursive: true);
  });

  tearDown(() {
    if (projectDir.existsSync()) projectDir.deleteSync(recursive: true);
  });

  File writeMeshAsset() {
    final file = File('${projectDir.path}/contents/meshes/skeletal/SK_Hero.lmas');
    file.writeAsBytesSync(
      LuminaAsset(
        assetId: 'SK_Hero',
        name: 'SK_Hero',
        type: AssetType.filamesh,
        rawPayload: _twoSectionSkinnedGlb(),
      ).toProtoBufferBytes(),
    );
    return file;
  }

  File writeMaterial(String name) {
    final file = File('${projectDir.path}/contents/materials/$name.lmas');
    file.writeAsBytesSync(
      LuminaAsset(
        assetId: name,
        name: name,
        type: AssetType.filamat,
        rawMatSource: '''
material {
    name : $name,
    parameters : [
        { type : sampler2d, name : baseColorMap }
    ],
    shadingModel : lit
}
''',
      ).toProtoBufferBytes(),
    );
    return file;
  }

  testWidgets('right inspector shows MATERIAL SLOTS above SKIN WEIGHT MAP', (tester) async {
    writeMaterial('M_Skin');
    final meshFile = writeMeshAsset();

    final vm = SkeletalMeshEditorViewModel(assetPath: meshFile.path);
    await tester.runAsync(() => vm.load());

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SkeletalMeshSubEditor(
            assetName: 'SK_Hero',
            assetPath: meshFile.path,
            viewModel: vm,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('MATERIAL SLOTS (2)'), findsOneWidget);
    expect(find.text('Element 0 (element_0)'), findsOneWidget);
    expect(find.text('Element 1 (element_1)'), findsOneWidget);

    final slotsY = tester.getTopLeft(find.text('MATERIAL SLOTS (2)')).dy;
    final weightsY = tester.getTopLeft(find.text('SKIN WEIGHT MAP')).dy;
    expect(slotsY, lessThan(weightsY));
  });

  testWidgets('panel renders no Material widgets (SHADCN_FLUTTER_FIRST)', (tester) async {
    writeMaterial('M_Skin');
    final meshFile = writeMeshAsset();
    final vm = SkeletalMeshEditorViewModel(assetPath: meshFile.path);
    await tester.runAsync(() => vm.load());

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SizedBox(
            width: 320,
            height: 700,
            child: SingleChildScrollView(
              child: SkeletalMaterialSlotsPanel(viewModel: vm),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    const bannedTypes = {
      'MaterialApp',
      'Scaffold_Material',
      'AppBar',
      'ElevatedButton',
      'TextButton',
      'FloatingActionButton',
      'ListTile',
      'DropdownButton',
    };
    final found = <String>{};
    for (final element in tester.allElements) {
      final name = element.widget.runtimeType.toString();
      if (bannedTypes.contains(name)) found.add(name);
    }
    expect(found, isEmpty, reason: 'Material widgets found in the panel: $found');
  });

  testWidgets('an unbound slot names the mesh\'s own material and shows no texture rows', (tester) async {
    writeMaterial('M_Skin');
    final meshFile = writeMeshAsset();
    final vm = SkeletalMeshEditorViewModel(assetPath: meshFile.path);
    await tester.runAsync(() => vm.load());

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SizedBox(
            width: 320,
            height: 700,
            child: SingleChildScrollView(
              child: SkeletalMaterialSlotsPanel(viewModel: vm),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // The section is not blank: it renders with the material the mesh shipped,
    // and the panel has to say which one before offering to override it.
    expect(find.text('From mesh'), findsNWidgets(2));
    expect(find.text('Body'), findsNWidgets(2));
    expect(find.text('Bound'), findsNothing);
    expect(find.text('TEXTURES'), findsNothing);
  });

  testWidgets('binding a material reveals its declared sampler rows', (tester) async {
    final matFile = writeMaterial('M_Skin');
    final meshFile = writeMeshAsset();
    final vm = SkeletalMeshEditorViewModel(assetPath: meshFile.path);
    await tester.runAsync(() => vm.load());

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SizedBox(
            width: 320,
            height: 700,
            child: SingleChildScrollView(
              child: ListenableBuilder(
                listenable: vm,
                builder: (context, _) => SkeletalMaterialSlotsPanel(viewModel: vm),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    vm.assignMaterial(0, materialAssetPath: matFile.path, materialAssetId: 'M_Skin');
    await tester.runAsync(() => vm.refreshSlotSamplers());
    await tester.pump();

    expect(find.text('TEXTURES'), findsOneWidget);
    expect(find.text('baseColorMap'), findsOneWidget);
    expect(find.text('normalMap'), findsNothing);
  });
}

/// Same two-section skinned fixture the view-model tests use.
Uint8List _twoSectionSkinnedGlb() {
  final positions = Float32List.fromList([
    0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, //
    0.0, 0.0, 1.0, 1.0, 0.0, 1.0, 0.0, 1.0, 1.0,
  ]);
  final bin = positions.buffer.asUint8List();

  final gltf = {
    'asset': {'version': '2.0'},
    'nodes': [
      {
        'name': 'Armature',
        'children': [1, 3],
      },
      {
        'name': 'pelvis',
        'children': [2],
      },
      {'name': 'spine_01'},
      {'name': 'CharacterMesh', 'mesh': 0},
    ],
    'scenes': [
      {
        'nodes': [0],
      }
    ],
    'scene': 0,
    'meshes': [
      {
        'name': 'Mesh0',
        'primitives': [
          {
            'attributes': {'POSITION': 0},
            'material': 0,
          },
          {
            'attributes': {'POSITION': 1},
            'material': 1,
          },
        ],
      }
    ],
    'materials': [
      {'name': 'Body'},
      {'name': 'Body'},
    ],
    'accessors': [
      {
        'bufferView': 0,
        'componentType': 5126,
        'count': 3,
        'type': 'VEC3',
        'min': [0.0, 0.0, 0.0],
        'max': [1.0, 1.0, 0.0],
      },
      {
        'bufferView': 1,
        'componentType': 5126,
        'count': 3,
        'type': 'VEC3',
        'min': [0.0, 0.0, 1.0],
        'max': [1.0, 1.0, 1.0],
      },
    ],
    'bufferViews': [
      {'buffer': 0, 'byteOffset': 0, 'byteLength': 36},
      {'buffer': 0, 'byteOffset': 36, 'byteLength': 36},
    ],
    'buffers': [
      {'byteLength': bin.length},
    ],
    'skins': [
      {
        'name': 'ArmatureSkin',
        'joints': [1, 2],
      }
    ],
  };

  final jsonBytes = utf8.encode(jsonEncode(gltf));
  final jsonPadded = (jsonBytes.length + 3) & ~3;
  final jsonChunk = Uint8List(jsonPadded)
    ..fillRange(0, jsonPadded, 0x20)
    ..setRange(0, jsonBytes.length, jsonBytes);

  final binPadded = (bin.length + 3) & ~3;
  final binChunk = Uint8List(binPadded)..setRange(0, bin.length, bin);

  final total = 12 + 8 + jsonPadded + 8 + binPadded;
  final glb = Uint8List(total);
  final bd = ByteData.sublistView(glb);

  bd.setUint32(0, 0x46546C67, Endian.little);
  bd.setUint32(4, 2, Endian.little);
  bd.setUint32(8, total, Endian.little);
  bd.setUint32(12, jsonPadded, Endian.little);
  bd.setUint32(16, 0x4E4F534A, Endian.little);
  glb.setRange(20, 20 + jsonPadded, jsonChunk);

  final binHeader = 20 + jsonPadded;
  bd.setUint32(binHeader, binPadded, Endian.little);
  bd.setUint32(binHeader + 4, 0x004E4942, Endian.little);
  glb.setRange(binHeader + 8, binHeader + 8 + binPadded, binChunk);

  return glb;
}
