import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/skeletal_mesh_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/skeletal_mesh/skeletal_mesh_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('skel_morph_ui_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Uint8List buildGlbWithMorphsAndSkin() {
    final posFloats = Float32List.fromList([
      0.0, 0.0, 0.0,
      1.0, 0.0, 0.0,
      0.0, 1.0, 0.0,
    ]);
    final t0Floats = Float32List.fromList([
      0.0, 0.5, 0.0,
      0.0, 0.0, 0.0,
      0.0, 0.0, 0.0,
    ]);
    final jointsBytes = Uint8List.fromList([
      0, 0, 0, 0,
      1, 0, 0, 0,
      0, 0, 0, 0,
    ]);
    final weightsFloats = Float32List.fromList([
      1.0, 0.0, 0.0, 0.0,
      1.0, 0.0, 0.0, 0.0,
      0.8, 0.0, 0.0, 0.0,
    ]);

    final binBuilder = BytesBuilder();
    binBuilder.add(posFloats.buffer.asUint8List());     // 36 bytes
    binBuilder.add(t0Floats.buffer.asUint8List());      // 36 bytes
    binBuilder.add(jointsBytes);                        // 12 bytes
    binBuilder.add(weightsFloats.buffer.asUint8List()); // 48 bytes
    final binBytes = binBuilder.toBytes();

    final gltf = {
      'asset': {'version': '2.0'},
      'buffers': [
        {'byteLength': binBytes.length}
      ],
      'bufferViews': [
        {'buffer': 0, 'byteOffset': 0, 'byteLength': 36, 'target': 34962},
        {'buffer': 0, 'byteOffset': 36, 'byteLength': 36, 'target': 34962},
        {'buffer': 0, 'byteOffset': 72, 'byteLength': 12, 'target': 34962},
        {'buffer': 0, 'byteOffset': 84, 'byteLength': 48, 'target': 34962},
      ],
      'accessors': [
        {'bufferView': 0, 'byteOffset': 0, 'componentType': 5126, 'count': 3, 'type': 'VEC3'},
        {'bufferView': 1, 'byteOffset': 0, 'componentType': 5126, 'count': 3, 'type': 'VEC3'},
        {'bufferView': 2, 'byteOffset': 0, 'componentType': 5121, 'count': 3, 'type': 'VEC4'},
        {'bufferView': 3, 'byteOffset': 0, 'componentType': 5126, 'count': 3, 'type': 'VEC4'},
      ],
      'meshes': [
        {
          'name': 'HeroMesh',
          'extras': {
            'targetNames': ['smile']
          },
          'primitives': [
            {
              'attributes': {
                'POSITION': 0,
                'JOINTS_0': 2,
                'WEIGHTS_0': 3,
              },
              'targets': [
                {'POSITION': 1}
              ],
            }
          ],
        }
      ],
      'nodes': [
        {'name': 'Armature', 'children': [1]},
        {'name': 'pelvis', 'children': [2]},
        {'name': 'spine_01'},
        {'name': 'MeshNode', 'mesh': 0},
      ],
      'skins': [
        {
          'joints': [1, 2],
        }
      ],
      'scene': 0,
      'scenes': [
        {
          'nodes': [0, 3]
        }
      ],
    };

    final jsonStr = jsonEncode(gltf);
    final jsonBytes = utf8.encode(jsonStr);
    final jsonPaddedLen = (jsonBytes.length + 3) & ~3;
    final binPaddedLen = (binBytes.length + 3) & ~3;

    final totalLen = 12 + 8 + jsonPaddedLen + 8 + binPaddedLen;
    final out = Uint8List(totalLen);
    final bd = ByteData.sublistView(out);

    bd.setUint32(0, 0x46546C67, Endian.little);
    bd.setUint32(4, 2, Endian.little);
    bd.setUint32(8, totalLen, Endian.little);

    bd.setUint32(12, jsonPaddedLen, Endian.little);
    bd.setUint32(16, 0x4E4F534A, Endian.little);
    out.setRange(20, 20 + jsonBytes.length, jsonBytes);
    for (int i = 20 + jsonBytes.length; i < 20 + jsonPaddedLen; i++) {
      out[i] = 0x20;
    }

    final binHeaderOffset = 20 + jsonPaddedLen;
    bd.setUint32(binHeaderOffset, binPaddedLen, Endian.little);
    bd.setUint32(binHeaderOffset + 4, 0x004E4942, Endian.little);
    out.setRange(binHeaderOffset + 8, binHeaderOffset + 8 + binBytes.length, binBytes);

    return out;
  }

  testWidgets('SkeletalMeshSubEditor renders morph targets, heatmap toggle, and vertex inspection', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final glbBytes = buildGlbWithMorphsAndSkin();
    final assetFile = File('${tempDir.path}/SK_Hero.lmas');
    final asset = LuminaAsset(
      assetId: 'SK_Hero',
      name: 'SK_Hero',
      type: AssetType.filamesh,
      rawPayload: glbBytes,
    );
    assetFile.writeAsBytesSync(asset.toProtoBufferBytes());

    final vm = SkeletalMeshEditorViewModel(assetPath: assetFile.path, initialAsset: asset);
    await tester.runAsync(() => vm.load());

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SkeletalMeshSubEditor(
            assetName: 'SK_Hero',
            assetPath: assetFile.path,
            viewModel: vm,
          ),
        ),
      ),
    );

    // Verify Toolbar stats overlay
    expect(find.text('Active Morph Targets: 0'), findsOneWidget);

    // Switch to Morphs tab in Left Panel
    await tester.tap(find.text('Morphs (1)'));
    await tester.pump();

    expect(find.text('MORPH TARGETS'), findsOneWidget);
    expect(find.text('smile'), findsOneWidget);
    expect(find.text('0.00'), findsOneWidget);

    // Change morph weight
    vm.setMorphWeight('smile', 0.85);
    await tester.pump();

    expect(find.text('0.85'), findsOneWidget);
    expect(find.text('Active Morph Targets: 1'), findsOneWidget);

    // The weight slider takes a typed value.
    await typeIntoSliderField(tester, const ValueKey('skeletal_morph_smile'), '0.4');
    expect(vm.morphWeights['smile'], closeTo(0.4, 1e-9));
    vm.setMorphWeight('smile', 0.85);
    await tester.pump();
    expect(vm.isDirty, isTrue);

    final viewport = tester.widget<SubEditor3DViewport>(find.byType(SubEditor3DViewport));
    expect(viewport.morphWeights?['smile'], equals(0.85));

    // Toggle Skin Weight Heatmap button in toolbar
    await tester.tap(find.text('Skin Weight Heatmap'));
    await tester.pump();
    expect(vm.heatmapEnabled, isTrue);

    // Inspect Vertex 0 via ViewModel / UI
    vm.setInspectedVertex(0);
    await tester.pump();

    expect(find.text('Vertex #0'), findsOneWidget);
    expect(find.text('Sum: 1.00'), findsOneWidget);
    expect(find.text('Armature'), findsWidgets);
    expect(find.text('1.000'), findsOneWidget);

    // Inspect Vertex 2 (Non-normalized 0.80)
    vm.setInspectedVertex(2);
    await tester.pump();

    expect(find.text('Vertex #2'), findsOneWidget);
    expect(find.text('Sum: 1.00'), findsOneWidget);
  });
}

/// Types [text] into the number field of the SliderField keyed [key] and
/// commits it with Enter (every property slider takes a typed value).
Future<void> typeIntoSliderField(WidgetTester tester, Key key, String text) async {
  final field = find.descendant(of: find.byKey(key), matching: find.byType(EditableText));
  expect(field, findsOneWidget, reason: 'the slider has an editable number field');
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pump();
  await tester.enterText(field, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}
