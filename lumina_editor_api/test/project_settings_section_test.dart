// The settings handle a plugin's Project Settings page edits.
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';

void main() {
  test('set stores a JSON value, fires changes, and null removes the key', () {
    final handle = MapPluginSettingsHandle({'keep': 1});
    var fired = 0;
    handle.changes.addListener(() => fired++);
    handle.set('defaultMode', 'plan');
    expect(handle.values, {'keep': 1, 'defaultMode': 'plan'});
    expect(handle.get<String>('defaultMode'), 'plan');
    expect(handle.get<int>('defaultMode'), isNull, reason: 'wrong type');
    handle.set('defaultMode', null);
    expect(handle.values, {'keep': 1});
    expect(fired, 2);
  });

  test('secret-looking keys and non-JSON values are refused', () {
    final handle = MapPluginSettingsHandle();
    for (final key in ['apiKey', 'client_secret', 'authToken', 'Password', 'credentials']) {
      expect(() => handle.set(key, 'x'), throwsArgumentError, reason: key);
    }
    expect(() => handle.set('when', DateTime(2026)), throwsArgumentError);
    expect(handle.values, isEmpty);
  });
}
