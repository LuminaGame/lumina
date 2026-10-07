import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';

/// UMG designer view model: real temp project + real WIDGET `.lmas` on disk.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late String projectDir;
  late String lmasPath;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('umg_vm_test_');
    projectDir = '${tempDir.path}/HudProject';
    Directory('$projectDir/lib').createSync(recursive: true);
    File('$projectDir/HudProject.lmproject').writeAsStringSync(jsonEncode(
      const LuminaProject(projectName: 'HudProject', activeLevel: 'contents/levels/L_Main.lmas').toMap(),
    ));
    await AssetRepository().createAsset(
      projectPath: projectDir,
      subFolder: 'widgets',
      fileName: 'WBP_PlayerHUD.lmas',
      type: AssetType.widget,
    );
    lmasPath = '$projectDir/contents/widgets/WBP_PlayerHUD.lmas';
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('load() of a fresh WIDGET asset yields a root Canvas Panel and drops create positioned slots', () async {
    final vm = UmgEditorViewModel(assetPath: lmasPath);
    await vm.load();
    expect(vm.document.root.type, UmgWidgetType.canvasPanel);
    expect(vm.isDirty, isFalse);

    vm.snapToGrid = false;
    final text = vm.addWidget(UmgWidgetType.text, parentId: vm.document.root.id, canvasPosition: const Offset(123, 45));
    expect(text, isNotNull);
    expect(text!.type, UmgWidgetType.text);
    expect(text.slot.kind, UmgSlotKind.canvas);
    expect(text.slot.position, const Offset(123, 45));
    expect(vm.document.root.children.single.id, text.id);
    expect(vm.selectedId, text.id, reason: 'a dropped widget becomes the selection');
    expect(vm.isDirty, isTrue);

    // Snap-to-grid quantizes to 8 px.
    vm.snapToGrid = true;
    final snapped = vm.addWidget(UmgWidgetType.button, parentId: vm.document.root.id, canvasPosition: const Offset(13, 27));
    expect(snapped!.slot.position, const Offset(16, 24));
  });

  test('dropping onto a leaf is rejected with a reason; box panels take ordered children', () async {
    final vm = UmgEditorViewModel(assetPath: lmasPath);
    await vm.load();
    final root = vm.document.root.id;
    final vbox = vm.addWidget(UmgWidgetType.verticalBox, parentId: root, canvasPosition: Offset.zero)!;
    final a = vm.addWidget(UmgWidgetType.text, parentId: vbox.id)!;
    final b = vm.addWidget(UmgWidgetType.progressBar, parentId: vbox.id)!;
    expect(a.slot.kind, UmgSlotKind.box);
    expect(vm.document.findNode(vbox.id)!.children.map((c) => c.id), [a.id, b.id]);

    final rejected = vm.addWidget(UmgWidgetType.image, parentId: a.id);
    expect(rejected, isNull);
    expect(vm.lastRejectionReason, contains('Text'));

    // Border accepts exactly one child.
    final border = vm.addWidget(UmgWidgetType.border, parentId: root, canvasPosition: Offset.zero)!;
    expect(vm.addWidget(UmgWidgetType.text, parentId: border.id), isNotNull);
    expect(vm.addWidget(UmgWidgetType.text, parentId: border.id), isNull);
    expect(vm.lastRejectionReason, contains('one child'));
  });

  test('round-trip: Canvas→Overlay→Progress Bar + Text survives save() and reopen losslessly', () async {
    final vm = UmgEditorViewModel(assetPath: lmasPath);
    await vm.load();
    final root = vm.document.root.id;
    vm.snapToGrid = false;
    final overlay = vm.addWidget(UmgWidgetType.overlay, parentId: root, canvasPosition: const Offset(40, 60))!;
    vm.rename(overlay.id, 'HUD Overlay');
    vm.setCanvasSize(overlay.id, const Size(400, 120));
    final bar = vm.addWidget(UmgWidgetType.progressBar, parentId: overlay.id)!;
    vm.rename(bar.id, 'HealthBar Progress');
    vm.setProp(bar.id, 'percent', 0.75);
    vm.setProp(bar.id, 'color', '#22C55E');
    final text = vm.addWidget(UmgWidgetType.text, parentId: root, canvasPosition: const Offset(10, 20))!;
    vm.setProp(text.id, 'text', 'Player One');
    vm.applyAnchorPreset(text.id, UmgAnchorPreset.bottomRight);
    vm.setZOrder(text.id, 5);
    expect(vm.addEvent(bar.id, 'OnValueChanged'), isFalse, reason: 'a Progress Bar offers no events');
    final slider = vm.addWidget(UmgWidgetType.slider, parentId: overlay.id)!;
    expect(vm.addEvent(slider.id, 'OnValueChanged'), isTrue);

    expect(await vm.save(), isTrue);
    expect(vm.isDirty, isFalse);

    final onDisk = LuminaAsset.fromBytes(File(lmasPath).readAsBytesSync());
    expect(onDisk.type, AssetType.widget);
    expect(onDisk.rawPayload, isNotNull);

    final reopened = UmgEditorViewModel(assetPath: lmasPath);
    await reopened.load();
    expect(reopened.document.toJson(), vm.document.toJson());
    final reBar = reopened.document.findNode(bar.id)!;
    expect(reBar.name, 'HealthBar Progress');
    expect(reBar.fieldName, 'healthBarProgress');
    expect(reBar.props['percent'], 0.75);
    expect(reBar.props['color'], '#22C55E');
    expect(reBar.events, isEmpty);
    expect(reopened.document.findNode(slider.id)!.events.single.name, 'OnValueChanged');
    expect(reopened.document.findNode(slider.id)!.events.single.handler, 'onValueChangedSlider');
    final reText = reopened.document.findNode(text.id)!;
    expect(reText.slot.anchorMin, const Offset(1, 1));
    expect(reText.slot.zOrder, 5);
    expect(reopened.document.findNode(overlay.id)!.children.map((c) => c.id), [bar.id, slider.id]);
  });

  test('anchors: Bottom-Right preset keeps the element pinned to the corner across resolutions', () async {
    final vm = UmgEditorViewModel(assetPath: lmasPath);
    await vm.load();
    vm.snapToGrid = false;
    final root = vm.document.root.id;
    // Designed at 1920x1080: a 200x40 element whose bottom-right corner sits 20 px from the corner.
    final node = vm.addWidget(UmgWidgetType.text, parentId: root, canvasPosition: const Offset(1700, 1020))!;
    vm.setCanvasSize(node.id, const Size(200, 40));
    final before = UmgLayout.resolveCanvasRect(vm.document.findNode(node.id)!.slot, const Size(1920, 1080));
    expect(before, const Rect.fromLTWH(1700, 1020, 200, 40));

    vm.applyAnchorPreset(node.id, UmgAnchorPreset.bottomRight);
    final slot = vm.document.findNode(node.id)!.slot;
    expect(slot.anchorMin, const Offset(1, 1));
    expect(slot.anchorMax, const Offset(1, 1));
    expect(slot.alignment, const Offset(1, 1));
    // Applying a preset never moves the element at the design resolution.
    expect(UmgLayout.resolveCanvasRect(slot, const Size(1920, 1080)), before);

    final hd = UmgLayout.resolveCanvasRect(slot, const Size(1920, 1080));
    expect(hd.right, 1900);
    expect(hd.bottom, 1060);
    vm.setResolution(UmgResolution.presets.firstWhere((p) => p.width == 393));
    expect(vm.resolution.height, 852);
    final mobile = UmgLayout.resolveCanvasRect(slot, vm.logicalSize);
    expect(mobile.right, 373, reason: 'still 20 px from the right edge on a 393 px wide screen');
    expect(mobile.bottom, 832);
    expect(mobile.width, 200);

    // Stretch preset: element fills the parent minus its margins at any size.
    vm.setResolution(UmgResolution.presets.first);
    vm.applyAnchorPreset(node.id, UmgAnchorPreset.fullStretch);
    final stretched = vm.document.findNode(node.id)!.slot;
    expect(stretched.anchorMin, Offset.zero);
    expect(stretched.anchorMax, const Offset(1, 1));
    expect(UmgLayout.resolveCanvasRect(stretched, const Size(1920, 1080)), before, reason: 'preset preserves the rect');
    final r2 = UmgLayout.resolveCanvasRect(stretched, const Size(2400, 1200));
    expect(r2.left, 1700, reason: 'left margin is kept');
    expect(r2.right, 2400 - 20, reason: 'right margin is kept, so the element grew with the screen');
    expect(r2.bottom, 1200 - 20);
  });

  test('hierarchy ops: Wrap With Border keeps the slot, Replace With keeps children, bad renames are rejected', () async {
    final vm = UmgEditorViewModel(assetPath: lmasPath);
    await vm.load();
    vm.snapToGrid = false;
    final root = vm.document.root.id;
    final overlay = vm.addWidget(UmgWidgetType.overlay, parentId: root, canvasPosition: const Offset(100, 200))!;
    vm.setCanvasSize(overlay.id, const Size(300, 150));
    final text = vm.addWidget(UmgWidgetType.text, parentId: overlay.id)!;
    final bar = vm.addWidget(UmgWidgetType.progressBar, parentId: overlay.id)!;

    // Wrap With Border: the border takes the overlay's canvas slot; the overlay becomes its child.
    final border = vm.wrapWith(overlay.id, UmgWidgetType.border)!;
    expect(border.type, UmgWidgetType.border);
    expect(border.slot.kind, UmgSlotKind.canvas);
    expect(border.slot.position, const Offset(100, 200));
    expect(border.slot.size, const Size(300, 150));
    expect(vm.document.root.children.single.id, border.id);
    expect(border.children.single.id, overlay.id);
    expect(vm.document.findNode(overlay.id)!.slot.kind, UmgSlotKind.single);

    // Replace With Vertical Box keeps the children (their slots become box slots).
    final vbox = vm.replaceWith(overlay.id, UmgWidgetType.verticalBox)!;
    expect(vbox.id, overlay.id, reason: 'identity is kept so references stay valid');
    expect(vbox.type, UmgWidgetType.verticalBox);
    expect(vbox.children.map((c) => c.id), [text.id, bar.id]);
    expect(vbox.children.first.slot.kind, UmgSlotKind.box);

    // Replace With a leaf is refused when the node has children.
    expect(vm.replaceWith(vbox.id, UmgWidgetType.text), isNull);
    expect(vm.lastRejectionReason, isNotEmpty);

    // Rename rules: unique Dart identifiers.
    expect(vm.rename(text.id, 'Score Label'), isTrue);
    expect(vm.document.findNode(text.id)!.fieldName, 'scoreLabel');
    expect(vm.rename(bar.id, 'Score Label'), isFalse, reason: 'duplicate field name');
    expect(vm.rename(bar.id, '123'), isFalse, reason: 'not an identifier');
    expect(vm.rename(bar.id, ''), isFalse);
    expect(vm.document.findNode(bar.id)!.name, isNot('123'));

    // Delete removes the subtree and clears the selection.
    vm.select(text.id);
    expect(vm.deleteNode(vbox.id), isTrue);
    expect(vm.document.findNode(text.id), isNull);
    expect(vm.selectedId, isNot(text.id));
    expect(vm.deleteNode(root), isFalse, reason: 'the root can never be deleted');
  });

  test('every mutation is undoable through the transaction stack', () async {
    final vm = UmgEditorViewModel(assetPath: lmasPath);
    await vm.load();
    final root = vm.document.root.id;
    final text = vm.addWidget(UmgWidgetType.text, parentId: root, canvasPosition: const Offset(8, 8))!;
    expect(vm.transactions.canUndo, isTrue);
    vm.setProp(text.id, 'text', 'Hello');
    vm.undo();
    expect(vm.document.findNode(text.id)!.props['text'], isNot('Hello'));
    vm.undo();
    expect(vm.document.findNode(text.id), isNull);
    vm.redo();
    expect(vm.document.findNode(text.id), isNotNull);
    vm.redo();
    expect(vm.document.findNode(text.id)!.props['text'], 'Hello');

    // Interactive drags coalesce into one transaction.
    final undoDepthBefore = vm.transactions.canUndo;
    expect(undoDepthBefore, isTrue);
    vm.beginInteraction('Move Text');
    for (var i = 1; i <= 20; i++) {
      vm.previewCanvasPosition(text.id, Offset(8.0 * i, 8));
    }
    vm.endInteraction();
    expect(vm.document.findNode(text.id)!.slot.position, const Offset(160, 8));
    vm.undo();
    expect(vm.document.findNode(text.id)!.slot.position, const Offset(8, 8), reason: 'one undo reverts the whole drag');
  });

  test('image brush: binding a real TEXTURE .lmas records an AssetReference and exposes its bytes', () async {
    final pngBytes = List<int>.generate(64, (i) => i);
    final texAsset = LuminaAsset(
      assetId: 'tex-1',
      name: 'T_Crosshair',
      type: AssetType.texture,
      rawPayload: Uint8List.fromList(pngBytes),
    );
    final texDir = Directory('$projectDir/contents/textures')..createSync(recursive: true);
    File('${texDir.path}/T_Crosshair.lmas').writeAsBytesSync(texAsset.toProtoBufferBytes());

    final vm = UmgEditorViewModel(assetPath: lmasPath);
    await vm.load();
    final textures = vm.textureAssets;
    expect(textures.map((t) => t.fileName), contains('T_Crosshair.lmas'));

    final image = vm.addWidget(UmgWidgetType.image, parentId: vm.document.root.id, canvasPosition: Offset.zero)!;
    vm.bindTexture(image.id, textures.firstWhere((t) => t.fileName == 'T_Crosshair.lmas'));
    expect(vm.document.findNode(image.id)!.props['texture'], 'contents/textures/T_Crosshair.lmas');
    expect(vm.textureBytesFor(image.id), isNotNull);
    expect(vm.textureBytesFor(image.id)!.length, 64);

    await vm.save();
    final onDisk = LuminaAsset.fromBytes(File(lmasPath).readAsBytesSync());
    expect(onDisk.references.length, 1);
    expect(onDisk.references.single.assetPath, 'contents/textures/T_Crosshair.lmas');
    expect(onDisk.references.single.assetId, 'tex-1');
    expect(onDisk.references.single.slotName, contains(image.fieldName));
  });

  test('compile() writes the generated Flutter widget into the project lib/widgets/', () async {
    final vm = UmgEditorViewModel(assetPath: lmasPath);
    await vm.load();
    final bar = vm.addWidget(UmgWidgetType.progressBar, parentId: vm.document.root.id, canvasPosition: Offset.zero)!;
    vm.rename(bar.id, 'HealthBar Progress');
    final result = await vm.compile();
    expect(result.written, isTrue);
    final file = File('$projectDir/lib/widgets/wbp_player_hud.dart');
    expect(file.existsSync(), isTrue);
    expect(file.readAsStringSync(), contains('class WbpPlayerHUD'));
    expect(vm.isDirty, isFalse, reason: 'compile saves first');
    expect(vm.generatedSource, file.readAsStringSync());
  });
}
