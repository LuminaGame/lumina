import 'dart:convert';

import 'package:lumina_core/lumina_core.dart';
import 'package:test/test.dart';

void main() {
  group('LuminaEditorPanelInfo', () {
    test('parses a right-docked panel and writes it back byte for byte', () {
      const text = '{"title":"Batch Rename","icon":"pencil","dock":"right","capabilities":["level","assets"]}';
      final info = LuminaEditorPanelInfo.fromJson(jsonDecode(text) as Map<String, dynamic>);
      expect(info.title, 'Batch Rename');
      expect(info.icon, 'pencil');
      expect(info.dock, LuminaEditorPanelDock.right);
      expect(info.capabilities, {LuminaEditorPanelCapability.level, LuminaEditorPanelCapability.assets});
      expect(info.minWidth, LuminaEditorPanelInfo.defaultMinSize);
      expect(info.minHeight, LuminaEditorPanelInfo.defaultMinSize);
      expect(info.defaultAlwaysVisible, isFalse);
      expect(info.contentDroppable, isFalse);
      expect(info.contentBrowserOpened, isFalse);
      expect(info.menuPathFor(), 'Window/Editor Panels/Batch Rename');
      expect(info.menuPathFor(pluginFriendlyName: 'Prop Tools'), 'Plugins/Prop Tools/Batch Rename');
      expect(jsonEncode(info.toJson()), text);
    });

    test('every field survives a round trip', () {
      final info = LuminaEditorPanelInfo(
        title: 'Prop Tools',
        icon: 'box',
        dock: LuminaEditorPanelDock.tab,
        defaultAlwaysVisible: true,
        contentDroppable: true,
        contentBrowserOpened: true,
        menuPath: 'Tools/Prop Tools',
        minWidth: 320,
        minHeight: 240,
        capabilities: {LuminaEditorPanelCapability.process, LuminaEditorPanelCapability.mcp},
      );
      final again = LuminaEditorPanelInfo.fromJson(jsonDecode(jsonEncode(info.toJson())) as Map<String, dynamic>);
      expect(again, info);
      expect(again.menuPathFor(pluginFriendlyName: 'X'), 'Tools/Prop Tools');
    });

    test('an unknown dock is an error naming dock', () {
      expect(
        () => LuminaEditorPanelInfo.fromJson({'title': 'A', 'dock': 'floating'}),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('dock'))),
      );
    });

    test('dialog and projectSettings docks parse', () {
      expect(LuminaEditorPanelInfo.fromJson({'title': 'Weights', 'dock': 'dialog'}).dock, LuminaEditorPanelDock.dialog);
      expect(LuminaEditorPanelInfo.fromJson({'title': 'Settings', 'dock': 'projectSettings'}).dock,
          LuminaEditorPanelDock.projectSettings);
      expect(LuminaEditorPanelDock.dialog.listedInMenu, isFalse);
      expect(LuminaEditorPanelDock.right.listedInMenu, isTrue);
    });

    test('an unknown capability is an error naming the capability', () {
      expect(
        () => LuminaEditorPanelInfo.fromJson({
          'title': 'A',
          'dock': 'left',
          'capabilities': ['network'],
        }),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', allOf(contains('capabilities'), contains('network')))),
      );
    });

    test('an empty title is an error naming title', () {
      expect(
        () => LuminaEditorPanelInfo.fromJson({'title': ' ', 'dock': 'left'}),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('title'))),
      );
    });

    test('a widget payload without the block is not an editor panel', () {
      expect(LuminaEditorPanelInfo.ofPayload({'root': <String, dynamic>{}}), isNull);
      expect(LuminaEditorPanelInfo.isEditorPanelPayload({'root': <String, dynamic>{}}), isFalse);
      final payload = {
        'root': <String, dynamic>{},
        LuminaEditorPanelInfo.payloadKey: {'title': 'A', 'dock': 'bottom'},
      };
      expect(LuminaEditorPanelInfo.isEditorPanelPayload(payload), isTrue);
      expect(LuminaEditorPanelInfo.ofPayload(payload)!.dock, LuminaEditorPanelDock.bottom);
    });

    test('the capability hash is stable and grows with the capability list', () {
      final a = LuminaEditorPanelInfo(title: 'A', capabilities: {LuminaEditorPanelCapability.level});
      final b = LuminaEditorPanelInfo(title: 'B', capabilities: {LuminaEditorPanelCapability.level});
      final c = LuminaEditorPanelInfo(
          title: 'A', capabilities: {LuminaEditorPanelCapability.level, LuminaEditorPanelCapability.assets});
      expect(a.capabilityHash, b.capabilityHash);
      expect(a.capabilityHash, isNot(c.capabilityHash));
    });
  });
}
