import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/skin_weight_heatmap.dart';

/// The skeletal mesh editor's weight heatmap on the native viewport: an unlit
/// material that reads each vertex's skin joints and weights (so it follows
/// skinning) and colours the weight of one joint, set per renderable as the
/// selected bone's index in that renderable's skin.
void main() {
  test('the heatmap material compiles (unlit, reading the skin joints and weights)', () async {
    final bytes = await SkinWeightHeatmap.material();
    expect(bytes, isNotNull, reason: SkinWeightHeatmap.lastDiagnostics);
    final info = FilamentTools.inspectMaterialJson(bytes!);
    expect(info, contains(SkinWeightHeatmap.materialName));
    expect(SkinWeightHeatmap.materialSource, contains('shadingModel : unlit'));
  });

  test('the selected bone maps to its index in the skin of every renderable (several skins over one skeleton)', () {
    // Nodes: 0 MeshA (skin 0), 1 MeshB (skin 1), 2 jointA, 3 jointB, 4 jointC.
    final glb = _glb({
      'asset': {'version': '2.0'},
      'nodes': [
        {'name': 'MeshA', 'mesh': 0, 'skin': 0},
        {'name': 'MeshB', 'mesh': 0, 'skin': 1},
        {'name': 'jointA'},
        {'name': 'jointB'},
        {'name': 'jointC'},
      ],
      'meshes': [
        {'primitives': <Object>[]},
      ],
      'skins': [
        {
          'joints': [2, 3],
        },
        {
          'joints': [4, 3],
        },
      ],
    });
    expect(SkinWeightHeatmap.jointSlots(glb, 3), [1, 1]);
    expect(SkinWeightHeatmap.jointSlots(glb, 2), [0, -1]);
    expect(SkinWeightHeatmap.jointSlots(glb, 4), [-1, 0]);
    expect(SkinWeightHeatmap.jointSlots(glb, null), [-1, -1]);
  });

  final quinn = File('${LuminaWorkspace.testAssets}/mannequin/exports/SKM_Quinn_Simple.glb');
  test('the Quinn mannequin: the head (node 10) is joint 9 of its skin', () {
    expect(SkinWeightHeatmap.jointSlots(quinn.readAsBytesSync(), 10), [9]);
  }, skip: quinn.existsSync() ? false : 'test-assets/mannequin/exports/SKM_Quinn_Simple.glb is missing');
}

Uint8List _glb(Map<String, Object> json) {
  var bytes = utf8.encode(jsonEncode(json));
  bytes = Uint8List.fromList([...bytes, ...List.filled((4 - bytes.length % 4) % 4, 0x20)]);
  final out = ByteData(20 + bytes.length)
    ..setUint32(0, 0x46546C67, Endian.little)
    ..setUint32(4, 2, Endian.little)
    ..setUint32(8, 20 + bytes.length, Endian.little)
    ..setUint32(12, bytes.length, Endian.little)
    ..setUint32(16, 0x4E4F534A, Endian.little);
  final list = out.buffer.asUint8List()..setRange(20, 20 + bytes.length, bytes);
  return list;
}
