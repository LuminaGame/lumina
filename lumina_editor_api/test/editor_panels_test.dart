import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';

/// A plugin opens, closes and observes its panels.
void main() {
  test('a detached EditorPanels shows, toggles and hides, notifying once per change', () {
    final panels = EditorPanels.detached();
    final changes = <bool>[];
    panels.visibility('a').addListener(() => changes.add(panels.visibility('a').value));
    expect(panels.isVisible('a'), isFalse);
    panels.show('a');
    expect(panels.isVisible('a'), isTrue);
    panels.show('a');
    expect(changes, [true], reason: 'showing an open panel is no change');
    panels.toggle('a');
    expect(panels.isVisible('a'), isFalse);
    expect(changes, [true, false]);
    panels.hide('unknown');
    expect(panels.isVisible('unknown'), isFalse);
    expect(identical(panels.visibility('a'), panels.visibility('a')), isTrue, reason: 'one notifier per panel');
  });
}
