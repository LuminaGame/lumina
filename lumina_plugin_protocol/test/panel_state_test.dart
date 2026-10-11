import 'dart:convert';

import 'package:lumina_plugin_protocol/lumina_plugin_protocol.dart';
import 'package:test/test.dart';

void main() {
  test('host.panelState round-trips through JSON', () {
    const patch = PluginPanelStatePatch('content/EPW_PropTools.lmas', [
      PluginPanelStateOp('StatusText', {'text': 'Ready'}),
      PluginPanelStateOp('Progress', {'percent': 0.5, 'visibility': 'Visible'}),
    ]);
    final wire = jsonDecode(jsonEncode(patch.toJson())) as Map<String, Object?>;
    final back = PluginPanelStatePatch.fromJson(wire)!;
    expect(back.panel, 'content/EPW_PropTools.lmas');
    expect(back.ops.map((o) => o.element), ['StatusText', 'Progress']);
    expect(back.ops.last.set, {'percent': 0.5, 'visibility': 'Visible'});
    expect(jsonEncode(back.toJson()), jsonEncode(patch.toJson()));
    expect(PluginMethods.panelState, 'host.panelState');
  });

  test('unknown keys and malformed ops are ignored', () {
    final back = PluginPanelStatePatch.fromJson({
      'panel': 'EPW_A.lmas',
      'future': 1,
      'ops': [
        {'element': 'StatusText', 'set': {'text': 'Hi'}, 'animate': true},
        {'element': '', 'set': {'text': 'x'}},
        {'set': {'text': 'x'}},
        {'element': 'Bar', 'set': 'not a map'},
        'garbage',
      ],
    })!;
    expect(back.ops, hasLength(1));
    expect(back.ops.single.toJson(), {'element': 'StatusText', 'set': {'text': 'Hi'}});
    expect(PluginPanelStatePatch.fromJson({'ops': const []}), isNull, reason: 'no panel');
  });

  test('merging coalesces a burst per element, later keys winning', () {
    const a = PluginPanelStatePatch('P', [PluginPanelStateOp('S', {'text': '1', 'isEnabled': false})]);
    const b = PluginPanelStatePatch('P', [
      PluginPanelStateOp('S', {'text': '2'}),
      PluginPanelStateOp('Bar', {'percent': 1.0}),
    ]);
    final m = a.merge(b);
    expect(m.ops.map((o) => o.toJson()), [
      {'element': 'S', 'set': {'text': '2', 'isEnabled': false}},
      {'element': 'Bar', 'set': {'percent': 1.0}},
    ]);
  });
}
