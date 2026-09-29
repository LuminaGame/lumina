import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/models/lumina_asset.dart';
import 'package:lumina/lumina_runtime.dart';

/// `LuminaAssets.loadPayload`: generated game code, e.g. a
/// UMG image, reads a `.lmas` from the asset bundle and gets its payload,
/// without knowing the `.lmas` format or touching `dart:io`.
void main() {
  // A real 1×1 PNG.
  final png = Uint8List.fromList(const [
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0,
    10, 73, 68, 65, 84, 120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
  ]);
  final lmas = LuminaAsset(assetId: 'tex-crosshair', name: 'T_Crosshair', type: AssetType.texture, rawPayload: png).toProtoBufferBytes();

  tearDown(() => LuminaAssets.defaultProvider = null);

  test('through the default provider: a .lmas yields its payload, any other file its bytes', () async {
    final served = <String>[];
    LuminaAssets.defaultProvider = (path) async {
      served.add(path);
      return path.endsWith('.lmas') ? Uint8List.fromList(lmas) : png;
    };
    expect(await LuminaAssets.loadPayload('contents/textures/T_Crosshair.lmas'), png);
    expect(await LuminaAssets.loadPayload('contents/ui/logo.png'), png);
    expect(served, ['contents/textures/T_Crosshair.lmas', 'contents/ui/logo.png']);
  });

  test('without a provider it reads the disk, as the editor does', () async {
    final dir = Directory.systemTemp.createTempSync('lumina_assets_payload_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/T_Crosshair.lmas')..writeAsBytesSync(lmas);
    expect(await LuminaAssets.loadPayload(file.path), png);
  });
}
