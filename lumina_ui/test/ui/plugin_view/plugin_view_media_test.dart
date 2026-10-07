import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/plugin_3d_viewport_container.dart';
import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';
import 'package:lumina_ui/ui/core/widgets/plugin_view/plugin_asset_ref_field_control.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'plugin_view_harness.dart';

const _view = 'media';

/// A real 48×32 PNG: a red-to-blue gradient.
List<int> _png() {
  final image = img.Image(width: 48, height: 32);
  for (var y = 0; y < 32; y++) {
    for (var x = 0; x < 48; x++) {
      image.setPixelRgb(x, y, 255 - x * 5, 40, x * 5);
    }
  }
  return img.encodePng(image);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('lumina_plugin_view_'));
  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  testWidgets('an image loads from a real PNG file and from base64 bytes', (tester) async {
    final bytes = _png();
    final file = File('${root.path}/preview.png')..writeAsBytesSync(bytes);
    final h = PluginViewHarness(PluginViewSpec(id: _view, children: [
      PluginControl(kind: PluginControlKind.image, id: 'file', props: {'path': file.path, 'height': 64}),
      PluginControl(kind: PluginControlKind.image, id: 'inline', props: {'base64': base64Encode(bytes), 'height': 64}),
      PluginControl(kind: PluginControlKind.image, id: 'relative', props: {'path': 'preview.png'}),
      PluginControl(kind: PluginControlKind.image, id: 'missing', props: {'path': '${root.path}/gone.png'}),
    ]));
    await h.pump(tester, projectDir: root.path);
    await _settle(tester);

    for (final id in ['file', 'inline', 'relative']) {
      final image = tester.widget<Image>(find.descendant(of: byControl(_view, id), matching: find.byType(Image)));
      expect((image.image as MemoryImage).bytes, bytes, reason: id);
    }
    expect(find.descendant(of: byControl(_view, 'missing'), matching: find.byType(Image)), findsNothing);
    expect(find.textContaining('cannot read'), findsOneWidget);
  });

  testWidgets('an asset ref field picks from the project assets of its types', (tester) async {
    final dir = '${root.path}/RefGame';
    Directory('$dir/contents/materials').createSync(recursive: true);
    Directory('$dir/contents/textures').createSync(recursive: true);
    for (final m in ['M_Rock', 'M_Moss']) {
      File('$dir/contents/materials/$m.lmas').writeAsBytesSync(LuminaAsset(
        assetId: m,
        name: m,
        type: AssetType.filamat,
        rawMatSource: 'material {\n    name : $m,\n    shadingModel : lit\n}\n',
      ).toProtoBufferBytes());
    }
    File('$dir/contents/textures/T_Noise.lmas')
        .writeAsBytesSync(const LuminaAsset(assetId: 'T_Noise', name: 'T_Noise', type: AssetType.texture).toProtoBufferBytes());

    final h = PluginViewHarness(PluginViewSpec(id: _view, children: [
      PluginControl(kind: PluginControlKind.assetRefField, id: 'material', props: {
        'label': 'Material',
        'value': 'contents/materials/M_Rock.lmas',
        'assetTypes': ['filamat'],
      }),
    ]));
    await h.pump(tester, projectDir: dir);
    await _settle(tester);

    expect(find.descendant(of: byControl(_view, 'material'), matching: find.byType(AssetPickerSelect)), findsOneWidget);
    expect(find.text('M_Rock'), findsOneWidget);

    final prefix = PluginAssetRefFieldControl.pickerPrefix(_view, 'material');
    await tester.tap(find.text('M_Rock'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('${prefix}_item_M_Moss.lmas')), findsOneWidget);
    expect(find.byKey(ValueKey('${prefix}_item_T_Noise.lmas')), findsNothing, reason: 'filtered by assetTypes');
    await tester.tap(find.byKey(ValueKey('${prefix}_item_M_Moss.lmas')));
    await tester.pumpAndSettle();
    expect(find.text('M_Moss'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('${prefix}_reset')));
    await tester.pump();

    expect(h.sent, [
      ('material', 'changed', 'contents/materials/M_Moss.lmas'),
      ('material', 'changed', null),
    ]);
  });

  testWidgets('a 3D preview shows a scene node in the plugin viewport and sends picked', (tester) async {
    final barrel = '${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb';
    final acUnit = '${SmokeArtifacts.testAssetsDir.path}/Props/AC_units/ac_unit_a_300x300.glb';
    if (!File(barrel).existsSync() || !File(acUnit).existsSync()) {
      markTestSkipped('test-assets models are missing');
      return;
    }
    final scene = PluginSceneSpec(cameraDistance: 300, nodes: [
      PluginSceneNode(name: 'Barrel', meshPath: barrel),
      PluginSceneNode(name: 'AC unit', meshPath: acUnit, location: const [200, 0, 0]),
    ]);
    final h = PluginViewHarness(PluginViewSpec(id: _view, children: [
      PluginControl(kind: PluginControlKind.preview3d, id: 'preview', props: {'scene': scene.toJson(), 'height': 200}),
    ]));
    await h.pump(tester);

    Plugin3DViewportContainer viewport() => tester.widget<Plugin3DViewportContainer>(find.byType(Plugin3DViewportContainer));
    expect(viewport().options.meshPath, barrel);
    expect(viewport().options.cameraDistance, 300);
    expect(find.byKey(const ValueKey('$_view/preview/node/Barrel')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('$_view/preview/node/AC unit')));
    await tester.pump();
    expect(viewport().options.meshPath, acUnit);
    expect(h.events, hasLength(1));
    expect((h.events.single.controlId, h.events.single.kind), ('preview', 'picked'));
    expect(h.events.single.value, {'node': 'AC unit'});
  });
}
