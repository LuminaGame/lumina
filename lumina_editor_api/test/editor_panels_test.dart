import 'package:flutter/widgets.dart';
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

  test('a panel shows in the level editor only unless its plugin asks for every editor', () {
    Widget body(BuildContext _) => const SizedBox();
    const icon = IconData(0xe000);
    expect(EditorPanelDescriptor(id: 'a', title: 'A', icon: icon, builder: body).defaultAlwaysVisible, isFalse);
    expect(
      EditorPanelDescriptor(id: 'b', title: 'B', icon: icon, builder: body, defaultDock: PanelDefaultDock.right, defaultAlwaysVisible: true)
          .defaultAlwaysVisible,
      isTrue,
    );
  });
}
