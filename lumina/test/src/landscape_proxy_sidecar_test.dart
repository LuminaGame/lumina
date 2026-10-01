import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

void main() {
  test('the level-viewport proxy of a landscape whose heights live in the .heights sidecar shows its relief', () async {
    final dir = Directory.systemTemp.createTempSync('landscape_proxy_');
    addTearDown(() => dir.deleteSync(recursive: true));
    // 2049² is over the inline limit: the asset carries only the header,
    // the heights go to the sidecar next to it.
    const n = 2049;
    final data = LandscapeData(gridResolution: n, worldSize: 2000, maxHeight: 120);
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        // A ridge 100 m high along the middle column.
        data.setHeight(c, r, 100 * math.exp(-math.pow((c - n / 2) / (n / 10), 2)));
      }
    }
    expect(data.vertexCount, greaterThan(LandscapeData.maxInlineSamples));
    final path = '${dir.path}/Landscape_Ridge.lmas';
    await data.writeSidecar(File(LandscapeData.sidecarPathFor(path)));
    final asset = LuminaAsset(
      assetId: 'landscape_Ridge',
      name: 'Landscape_Ridge',
      type: AssetType.landscape,
      rawPayload: data.toBytes(inlineSamples: false),
    );
    File(path).writeAsBytesSync(asset.toProtoBufferBytes());

    final mesh = (await LandscapeGlbBuilder.proxyMeshFor(path))!;
    var lo = double.infinity, hi = -double.infinity;
    for (var i = 1; i < mesh.positions.length; i += 3) {
      lo = math.min(lo, mesh.positions[i]);
      hi = math.max(hi, mesh.positions[i]);
    }
    // glTF metres, Y up: the ridge stands ~100 m over the plain.
    expect(hi - lo, greaterThan(90));
  });
}
