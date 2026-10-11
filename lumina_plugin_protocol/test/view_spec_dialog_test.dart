import 'dart:convert';

import 'package:lumina_plugin_protocol/lumina_plugin_protocol.dart';
import 'package:test/test.dart';

/// `host.showDialog` specs and their answers, through JSON text as on the
/// wire.
Map<String, Object?> _wire(Map<String, Object?> json) => (jsonDecode(jsonEncode(json)) as Map).cast();

void main() {
  test('a dialog with a text field, a bool and two actions round-trips', () {
    final spec = PluginDialogSpec(
      id: 'name_dialog',
      title: 'Name the actor',
      body: [
        PluginControl.textField('name', label: 'Name', value: 'Crate'),
        PluginControl.boolField('snap', label: 'Snap to grid', value: true),
      ],
      actions: const [
        PluginDialogAction(id: 'cancel', label: 'Cancel'),
        PluginDialogAction(id: 'accept', label: 'Accept', tone: PluginDialogTone.primary),
      ],
      dismissible: true,
    );
    final back = PluginDialogSpec.fromJson(_wire(spec.toJson()));
    expect(back.toJson(), spec.toJson());
    expect(back.kind, PluginDialogKind.dialog);
    expect(back.body.map((c) => c.kind), [PluginControlKind.textField, PluginControlKind.boolField]);
    expect(back.actions.map((a) => '${a.id}:${a.tone}'), ['cancel:secondary', 'accept:primary']);

    const answer = PluginDialogResult(action: 'accept', values: {'name': 'Barrel', 'snap': false});
    final again = PluginDialogResult.fromJson(_wire(answer.toJson()));
    expect(again.action, 'accept');
    expect(again.values, {'name': 'Barrel', 'snap': false});
    expect(PluginDialogResult.fromJson(_wire(PluginDialogResult.dismissed.toJson())).isDismissed, isTrue);
  });

  test('a confirm with a destructive action round-trips', () {
    final spec = PluginDialogSpec.confirm(
      id: 'delete',
      title: 'Delete the barrels?',
      message: 'Removes 3 actors.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    final back = PluginDialogSpec.fromJson(_wire(spec.toJson()));
    expect(back.kind, PluginDialogKind.confirm);
    expect(back.body.single['value'], 'Removes 3 actors.');
    expect(back.actions.last.id, 'confirm');
    expect(back.actions.last.tone, PluginDialogTone.destructive);
    expect(back.toJson(), spec.toJson());
  });

  test('an unknown kind is a decode error naming the field', () {
    final json = _wire(const PluginDialogSpec(id: 'x', title: 't').toJson())..['kind'] = 'popover';
    expect(
      () => PluginDialogSpec.fromJson(json),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', allOf(contains('"kind"'), contains('popover')))),
    );
  });

  test('the methods are named on the protocol', () {
    expect(PluginMethods.showDialog, 'host.showDialog');
    expect(PluginMethods.closeDialog, 'host.closeDialog');
  });
}
